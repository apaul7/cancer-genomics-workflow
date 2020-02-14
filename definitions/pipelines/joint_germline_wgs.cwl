#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "joint wgs alignment and germline variant detection"
requirements:
    - class: ScatterFeatureRequirement
    - class: SchemaDefRequirement
      types:
          - $import: ../types/labelled_file.yml
          - $import: ../types/sequence_data.yml
          - $import: ../types/vep_custom_annotation.yml
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: MultipleInputFeatureRequirement
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict, .amb, .ann, .bwt, .pac, .sa]
    sequence:
        type: 
            type: array
            items:
                type: array
                items: ../types/sequence_data.yml#sequence_data
    sample_name:
        type: string[]
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
    qc_intervals:
        type: File
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
    per_sample_outs:
        type: Directory[]
        outputSource: per_sample_outputs/gathered_files
    vcf:
        type: File
        outputSource: joint_gatk/genotype_vcf
steps:
    alignment_and_qc:
        scatter: [sequence]
        scatterMethod: dotproduct
        run: alignment_wgs.cwl
        in:
            reference: reference
            sequence: sequence
            mills: mills
            known_indels: known_indels
            dbsnp_vcf: dbsnp_vcf
            omni_vcf: omni_vcf
            intervals: qc_intervals
            picard_metric_accumulation_level: picard_metric_accumulation_level
            bqsr_intervals: bqsr_intervals
            minimum_mapping_quality: minimum_mapping_quality
            minimum_base_quality: minimum_base_quality
            per_base_intervals: per_base_intervals
            per_target_intervals: per_target_intervals
            summary_intervals: summary_intervals
        out:
            [bam, mark_duplicates_metrics, insert_size_metrics, insert_size_histogram, alignment_summary_metrics, gc_bias_metrics, gc_bias_metrics_chart, gc_bias_metrics_summary, wgs_metrics, flagstats, verify_bam_id_metrics, verify_bam_id_depth, per_base_coverage_metrics, per_base_hs_metrics, per_target_coverage_metrics, per_target_hs_metrics, summary_hs_metrics]
    bam_to_cram:
        scatter: [bam]
        scatterMethod: dotproduct
        run: ../tools/bam_to_cram.cwl
        in:
            bam: alignment_and_qc/bam
            reference: reference
        out:
            [cram]
    index_cram:
        scatter: [cram]
        scatterMethod: dotproduct
        run: ../tools/index_cram.cwl
        in:
            cram: bam_to_cram/cram
        out:
            [indexed_cram]
    extract_freemix:
        scatter: [verify_bam_id_metrics]
        scatterMethod: dotproduct
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
                    type: string?
            expression: |
                        ${
                            var metrics = inputs.verify_bam_id_metrics.contents.split("\n");
                            if ( metrics[0].split("\t")[6] == 'FREEMIX' ) {
                                return {'freemix_score': metrics[1].split("\t")[6]};
                            } else {
                                return {'freemix_score:': null };
                            }
                        }
    haplotype_caller:
        scatter: [bam, contamination_fraction]
        scatterMethod: dotproduct
        run: ../subworkflows/gatk_haplotypecaller_iterator.cwl
        in:
            reference: reference
            bam: alignment_and_qc/bam
            emit_reference_confidence: emit_reference_confidence
            gvcf_gq_bands: gvcf_gq_bands
            intervals: intervals
            contamination_fraction: extract_freemix/freemix_score
        out:
            [gvcf]
    joint_gatk:
        run: ../tools/gatk_genotypegvcfs.cwl
        in:
            reference: reference
            gvcfs: 
                source: haplotype_caller/gvcf
                # linkMerge: xyz does not seem to be working...
                valueFrom: |
                           ${
                               var files = [];
                               var len = self.length;
                               for (var i = 0; i < len; i++) {
                                   var len2 = self[i].length;
                                   for (var j = 0; j < len2; j++) {
                                       files.push(self[i][j]);
                                   }
                               }
                               return files;
                           }
        out:
            [genotype_vcf]
    per_sample_outputs:
        scatter: [output_dir, all_files]
        scatterMethod: dotproduct
        run: ../tools/gatherer.cwl
        in:
            output_dir:
                source: sample_name
                valueFrom: |
                  ${
                    return self + "-outs";
                  }
            all_files:
                source: [alignment_and_qc/mark_duplicates_metrics, alignment_and_qc/insert_size_metrics, alignment_and_qc/insert_size_histogram, alignment_and_qc/alignment_summary_metrics, alignment_and_qc/gc_bias_metrics, alignment_and_qc/gc_bias_metrics_chart, alignment_and_qc/gc_bias_metrics_summary, alignment_and_qc/wgs_metrics, alignment_and_qc/flagstats, alignment_and_qc/verify_bam_id_metrics, alignment_and_qc/verify_bam_id_depth, alignment_and_qc/per_base_coverage_metrics, alignment_and_qc/per_base_hs_metrics, alignment_and_qc/per_target_coverage_metrics, alignment_and_qc/per_target_hs_metrics, alignment_and_qc/summary_hs_metrics, index_cram/indexed_cram, haplotype_caller/gvcf]
        #        linkMerge: merge_flattened
                valueFrom: |
                           ${
                               var files = [];
                               var len = self.length;
                               for (var i = 0; i < len; i++) {
                                   var len2 = self[i].length;
                                   for (var j = 0; j < len2; j++) {
                                       files.push(self[i][j]);
                                   }
                               }
                               return files;
                           }
        out: [gathered_files]
