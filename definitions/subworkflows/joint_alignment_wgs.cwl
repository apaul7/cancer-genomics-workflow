#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "joint wgs alignment with qc"
requirements:
    - class: SchemaDefRequirement
      types:
          - $import: ../types/labelled_file.yml
          - $import: ../types/sequence_data.yml
          - $import: ../types/trimming_options.yml
    - class: SubworkflowFeatureRequirement
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
    - class: StepInputExpressionRequirement
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
    trimming:
        type:
            - ../types/trimming_options.yml#trimming_options
            - "null"
    mills:
        type: File
        secondaryFiles: [.tbi]
    known_indels:
        type: File
        secondaryFiles: [.tbi]
    dbsnp_vcf:
        type: File
        secondaryFiles: [.tbi]
    omni_vcf:
        type: File
        secondaryFiles: [.tbi]
    intervals:
        type: File
    picard_metric_accumulation_level:
        type: string
    bqsr_intervals:
        type: string[]?
    minimum_mapping_quality:
        type: int?
    minimum_base_quality:
        type: int?
    per_base_intervals:
        type: ../types/labelled_file.yml#labelled_file[]
    per_target_intervals:
        type: ../types/labelled_file.yml#labelled_file[]
    summary_intervals:
        type: ../types/labelled_file.yml#labelled_file[]
outputs:
    bams:
        type: File[]
        outputSource: alignment/final_bam
    verify_bam_id_metrics:
        type: File[]
        outputSource: qc/verify_bam_id_metrics
    gathered_results:
        type: Directory
        outputSource: gather_all/gathered_directory
steps:
    alignment:
        scatter: [unaligned]
        run: ../subworkflows/sequence_to_bqsr.cwl
        in:
            reference: reference
            unaligned: sequences
            trimming: trimming
            mills: mills
            known_indels: known_indels
            dbsnp_vcf: dbsnp_vcf
            bqsr_intervals: bqsr_intervals
        out: [final_bam,mark_duplicates_metrics_file]
    qc:
        scatter: [bam, sample_name]
        scatterMethod: dotproduct
        run: ../subworkflows/gathered_qc_wgs.cwl
        in:
            bam: alignment/final_bam
            sample_name: sample_names
            reference: reference
            omni_vcf: omni_vcf
            intervals: intervals
            picard_metric_accumulation_level: picard_metric_accumulation_level
            minimum_mapping_quality: minimum_mapping_quality
            minimum_base_quality: minimum_base_quality
            per_base_intervals: per_base_intervals
            per_target_intervals: per_target_intervals
            summary_intervals: summary_intervals
        out: [verify_bam_id_metrics, gathered_results]

    bam_to_cram:
        scatter: [bam]
        run: ../tools/bam_to_cram.cwl
        in:
            bam: alignment/final_bam
            reference: reference
        out:
            [cram]
    index_cram:
         scatter: [cram]
         run: ../tools/index_cram.cwl
         in:
            cram: bam_to_cram/cram
         out:
            [indexed_cram]
    get_indices:
        in:
            samples: sample_names
        out:
            [sample_indices]
        run:
            class: ExpressionTool
            requirements:
                - class: InlineJavascriptRequirement
            inputs:
                samples:
                    type: string[]
            outputs:
                sample_indices:
                    type: string[]
            expression: |
                ${
                    var results = [];
                    for(var i=0; i<inputs.samples.length; i++){
                        results.push(i);
                    }
                    return {'sample_indices': results };
                }
    gather_alignment:
        scatter: [outdir, sample_index]
        scatterMethod: dotproduct
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            sample_index: get_indices/sample_indices
            outdir:
                source: [sample_names]
                valueFrom: "$(self)-alignments"
            files:
                source: [index_cram/indexed_cram, alignment/mark_duplicates_metrics_file]
                valueFrom: |
                    ${
                        var results = [];
                        for(var i=0; i<self.length; i++){
                            results.push(self[i][inputs.sample_index]);
                        }
                        return results;
                    }
        out:
            [gathered_directory]
    gather_all:
        run: ../tools/gather_to_sub_directory_dirs.cwl
        in:
            outdir:
                default: "alignment_pipeline"
            directories:
                source: [gather_alignment/gathered_directory, qc/gathered_results]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
