#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "joint exome alignment and germline variant detection"
requirements:
    - class: SchemaDefRequirement
      types:
          - $import: ../types/labelled_file.yml
          - $import: ../types/sequence_data.yml
          - $import: ../types/trimming_options.yml
          - $import: ../types/vep_custom_annotation.yml
    - class: SubworkflowFeatureRequirement
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict, .amb, .ann, .bwt, .pac, .sa]
    sequences:
        type:
            type: array
            items:
                type: array
                items: ../types/sequence_data.yml#sequence_data
    sample_names:
        type: string[]
    cohort_name:
        type: string
    trimming:
        type:
            - ../types/trimming_options.yml#trimming_options
            - "null"
    bqsr_known_sites:
        type: File[]
        secondaryFiles: [.tbi]
        doc: "One or more databases of known polymorphic sites used to exclude regions around known polymorphisms from analysis."
    bqsr_intervals:
        type: string[]?
    bait_intervals:
        type: File
    target_intervals:
        type: File
    per_base_intervals:
        type: ../types/labelled_file.yml#labelled_file[]
    per_target_intervals:
        type: ../types/labelled_file.yml#labelled_file[]
    summary_intervals:
        type: ../types/labelled_file.yml#labelled_file[]
    omni_vcf:
        type: File
        secondaryFiles: [.tbi]
    picard_metric_accumulation_level:
        type: string
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

    synonyms_file:
        type: File?
    qc_minimum_mapping_quality:
        type: int?
    qc_minimum_base_quality:
        type: int?

    vep_plugins:
        type: string[]
        default: [Downstream, Wildtype]
    annotate_coding_only:
        type: boolean?
    vep_custom_annotations:
        type: ../types/vep_custom_annotation.yml#vep_custom_annotation[]
        doc: "custom type, check types directory for input format"
    variants_to_table_fields:
        type: string[]?
        default: ['CHROM','POS','ID','REF','ALT']
    variants_to_table_genotype_fields:
        type: string[]?
    vep_to_table_fields:
        type: string[]?
    filter_gnomAD_maximum_population_allele_frequency:
        type: float
        default: 0.05

outputs:
    alignments:
        type: Directory
        outputSource: alignment_and_qc/gathered_results
    snps:
        type: Directory
        outputSource: detect_variants/gathered_results
    annotated_vcf:
        type: File
        outputSource: annotate_and_gnomad_filter/annotated_vcf
        secondaryFiles: [.tbi]
    vep_summary:
        type: File
        outputSource: annotate_and_gnomad_filter/vep_summary
    filtered_vcf:
        type: File
        outputSource: annotate_and_gnomad_filter/filtered_vcf
        secondaryFiles: [.tbi]
    filtered_tsv:
        type: File
        outputSource: annotate_and_gnomad_filter/filtered_tsv
steps:
    alignment_and_qc:
        run: ../subworkflows/joint_alignment_exome.cwl
        in:
            reference: reference
            sequences: sequences
            sample_names: sample_names
            trimming: trimming
            bqsr_known_sites: bqsr_known_sites
            bqsr_intervals: bqsr_intervals
            bait_intervals: bait_intervals
            target_intervals: target_intervals
            per_base_intervals: per_base_intervals
            per_target_intervals: per_target_intervals
            summary_intervals: summary_intervals
            omni_vcf: omni_vcf
            picard_metric_accumulation_level: picard_metric_accumulation_level   
            qc_minimum_mapping_quality: qc_minimum_mapping_quality
            qc_minimum_base_quality: qc_minimum_base_quality
        out:
            [bams, verify_bam_id_metrics, gathered_results]
    extract_freemix:
        scatter: [verify_bam_id_metrics]
        in:
            verify_bam_id_metrics: alignment_and_qc/verify_bam_id_metrics
        out:
            [freemix_score]
        run:
            class: ExpressionTool
            requirements:
                - class: InlineJavascriptRequirement
            inputs:
                verify_bam_id_metrics:
                    type: File
                    inputBinding:
                        loadContents: true
            outputs:
                freemix_score:
                    type: string
            expression: |
                        ${
                            var metrics = inputs.verify_bam_id_metrics.contents.split("\n");
                            if ( metrics[0].split("\t")[6] == 'FREEMIX' ) {
                                return {'freemix_score': metrics[1].split("\t")[6]};
                            } else {
                                return {'freemix_score': -1 };
                            }
                        }
    detect_variants:
        run: ../subworkflows/joint_detect_snps.cwl
        in:
            reference: reference
            bams: alignment_and_qc/bams
            sample_names: sample_names
            cohort_name: cohort_name
            emit_reference_confidence: emit_reference_confidence
            gvcf_gq_bands: gvcf_gq_bands
            intervals: intervals
            contamination_fraction: extract_freemix/freemix_score
            vep_cache_dir: vep_cache_dir
            synonyms_file: synonyms_file
            vep_ensembl_assembly: vep_ensembl_assembly
            vep_ensembl_version: vep_ensembl_version
            vep_ensembl_species: vep_ensembl_species
            indel_vep_custom_annotations: indel_vep_custom_annotations
            indel_vep_plugins: indel_vep_plugins
            indel_vep_tsv_fields: indel_vep_tsv_fields
        out:
            [gathered_results, raw_vcf, filtered_vcf]
    annotate_and_gnomad_filter:
        run: ../subworkflows/joint_annotate_and_filter.cwl
        in:
            vcf: detect_variants/filtered_vcf
            reference: reference
            vep_cache_dir: vep_cache_dir
            vep_ensembl_assembly: vep_ensembl_assembly
            vep_ensembl_version: vep_ensembl_version
            vep_ensembl_species: vep_ensembl_species
            vep_plugins: vep_plugins
            annotate_coding_only: annotate_coding_only
            vep_custom_annotations: vep_custom_annotations
            variants_to_table_fields: variants_to_table_fields
            variants_to_table_genotype_fields: variants_to_table_genotype_fields
            vep_to_table_fields: vep_to_table_fields
            filter_gnomAD_maximum_population_allele_frequency: filter_gnomAD_maximum_population_allele_frequency
        out:
            [annotated_vcf, vep_summary, filtered_vcf, filtered_tsv]
