#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run gatk"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
    - class: SchemaDefRequirement
      types:
          - $import: ../types/vep_custom_annotation.yml
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    sample_names:
        type: string[]
    bams:
        type: File[]
        secondaryFiles: [^.bai]
    cohort_name:
        type: string?

    emit_reference_confidence:
        type:
            type: enum
            symbols: ['NONE', 'BP_RESOLUTION', 'GVCF']
    gvcf_gq_bands:
        type: string[]
    intervals:
        type:
            type: array
            items:
                type: array
                items: string

    synonyms_file:
        type: File?
    vep_cache_dir:
        type:
            - string
            - Directory
    vep_ensembl_assembly:
        type: string
        doc: "genome assembly to use in vep. Examples: GRCh38 or GRCm38"
    vep_ensembl_version:
        type: string
        doc: "ensembl version - Must be present in the cache directory. Example: 95"
    vep_ensembl_species:
        type: string
        doc: "ensembl species - Must be present in the cache directory. Examples: homo_sapiens or mus_musculus"
    indel_vep_custom_annotations:
        type: ../types/vep_custom_annotation.yml#vep_custom_annotation[]
        doc: "custom type, check types directory for input format"
    indel_vep_plugins:
        type: string[]
    indel_vep_tsv_fields:
        type: string[]
    contamination_fraction:
        type: string[]

outputs:
    gathered_results:
        type: Directory
        outputSource: stage_all/gathered_directory
    raw_vcf:
        type: File
        outputSource: bgzip_index/indexed_vcf
        secondaryFiles: [.tbi]
    filtered_vcf:
        type: File
        outputSource: filter/filtered_vcf
        secondaryFiles: [.tbi]

steps:
    make_gvcf:
        scatter: [bam, contamination_fraction, sample_name]
        #scatter: [bam, sample_name]
        scatterMethod: dotproduct
        run: gatk_haplotypecaller_iterator.cwl
        in:
            reference: reference
            bam: bams
            sample_name: sample_names
            emit_reference_confidence: emit_reference_confidence
            gvcf_gq_bands: gvcf_gq_bands
            intervals: intervals
            contamination_fraction: contamination_fraction
        out:
            [gvcf, staged_gvcf]
    combine_gvcf:
        scatter: [intervals]
        run: ../tools/gatk_combinegvcfs.cwl
        in:
            reference: reference
            gvcfs:
                source: [make_gvcf/gvcf]
                valueFrom: |
                    ${
                       var sample_count = self.length
                       var index = -1
                       var key = inputs.intervals.toString() //array like [chr1] or [chr2,chr3], should be post scattered values
                       var interval_length = inputs.all_intervals.length // size of first outer array [[chr1], [chr2,chr3]] == 2
                       for(var i=0; i<interval_length; i++) {
                           if(inputs.all_intervals[i].toString() == key){
                               index = i
                           }
                       }
                       var results = []
                       for(var s=0; s<sample_count; s++) {
                           results.push(self[s][index])
                       }
                       return results;
                    }
            intervals: intervals
            all_intervals: intervals
        out:
            [merged_gvcf]
    genotype_gvcf:
        scatter: [intervals, gvcfs]
        scatterMethod: dotproduct
        run: ../tools/gatk_genotypegvcfs.cwl
        in:
            reference: reference
            gvcfs: combine_gvcf/merged_gvcf
            intervals: intervals
            min_conf_emit_threshold:
                default: 10
            min_conf_call_threshold:
                default: 30
        out:
            [genotype_vcf]
    concat_vcf:
        run: ../tools/bcftools_concat.cwl
        in:
            output_vcf_name:
                default: "combined.all.gt.vcf.gz"
            vcfs: genotype_gvcf/genotype_vcf
        out:
            [concat_vcf]
    sort_vcf:
        run: ../tools/sort_vcf.cwl
        in:
            vcf: concat_vcf/concat_vcf
        out:
            [sorted_vcf]
    bgzip_index_sorted:
        run: bgzip_and_index.cwl
        in:
            vcf: sort_vcf/sorted_vcf
        out:
            [indexed_vcf]
    normalize_vcf:
        run: ../tools/vt_script.cwl
        in:
            vcf: bgzip_index_sorted/indexed_vcf
            reference: reference
        out:
            [normalized_vcf]
    bgzip_index:
        run: bgzip_and_index.cwl
        in:
            vcf: normalize_vcf/normalized_vcf
        out:
            [indexed_vcf]
    filter:
        run: gatk_filter.cwl
        in:
            vcf: bgzip_index/indexed_vcf
            reference: reference
        out:
            [filtered_vcf]

    rare_indels:
        run: filter_rare_indels.cwl
        in:
            reference: reference
            in_vcf: filter/filtered_vcf
            vep_cache_dir: vep_cache_dir
            synonyms_file: synonyms_file
            vep_custom_annotations: indel_vep_custom_annotations
            vep_ensembl_assembly: vep_ensembl_assembly
            vep_ensembl_version: vep_ensembl_version
            vep_ensembl_species: vep_ensembl_species
            vep_plugins: indel_vep_plugins
            vep_tsv_fields: indel_vep_tsv_fields
        out:
            [vcf, tsv]
    stage_gatk:
        run: ../tools/gather_to_sub_directory.cwl
        in:
            outdir:
                default: "gatk"
            files:
                source: [bgzip_index/indexed_vcf, filter/filtered_vcf, rare_indels/vcf, rare_indels/tsv]
                #source: [bgzip_index/indexed_vcf, filter/filtered_vcf]
                #linkMerge: merge_flattened
            directories: make_gvcf/staged_gvcf
        out:
            [gathered_directory]
    stage_all:
        run: ../tools/gather_to_sub_directory.cwl
        in:
            outdir:
                default: "SNP_pipeline"
            #directories: stage_gvcfs/gathered_directory
            directory: stage_gatk/gathered_directory
        out:
            [gathered_directory]
