#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "Exome QC workflow"
requirements:
    - class: SchemaDefRequirement
      types:
          - $import: ../types/labelled_file.yml
    - class: StepInputExpressionRequirement
    - class: SubworkflowFeatureRequirement
inputs:
    bam:
        type: File
        secondaryFiles: [^.bai]
    sample_name:
        type: string?
        default: 'final'
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    bait_intervals:
        type: File
    target_intervals:
        type: File
    omni_vcf:
        type: File
        secondaryFiles: [.tbi]
    picard_metric_accumulation_level:
        type: string
        default: ALL_READS
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
    verify_bam_id_metrics:
        type: File
        outputSource: verify_bam_id/verify_bam_id_metrics
    gathered_results:
        type: Directory
        outputSource: gather_qc/gathered_directory
steps:
    collect_insert_size_metrics:
        run: ../tools/collect_insert_size_metrics.cwl
        in:
            bam: bam
            reference: reference
            metric_accumulation_level: picard_metric_accumulation_level
        out:
            [insert_size_metrics, insert_size_histogram]
    collect_alignment_summary_metrics:
        run: ../tools/collect_alignment_summary_metrics.cwl
        in:
            bam: bam
            reference: reference
            metric_accumulation_level: picard_metric_accumulation_level
        out:
            [alignment_summary_metrics]
    collect_roi_hs_metrics:
        run: ../tools/collect_hs_metrics.cwl
        in:
            bam: bam
            reference: reference
            metric_accumulation_level:
                valueFrom: "ALL_READS"
            bait_intervals: bait_intervals
            target_intervals: target_intervals
            per_target_coverage:
                default: false
            per_base_coverage:
                default: false
            output_prefix:
                valueFrom: "roi"
            minimum_mapping_quality: minimum_mapping_quality
            minimum_base_quality: minimum_base_quality
        out:
            [hs_metrics]
    collect_detailed_hs_metrics:
        run: hs_metrics.cwl
        in:
            bam: bam
            minimum_mapping_quality: minimum_mapping_quality
            minimum_base_quality: minimum_base_quality
            per_base_intervals: per_base_intervals
            per_target_intervals: per_target_intervals
            reference: reference
            summary_intervals: summary_intervals
        out:
            [per_base_coverage_metrics, per_base_hs_metrics, per_target_coverage_metrics, per_target_hs_metrics, summary_hs_metrics]
    samtools_flagstat:
        run: ../tools/samtools_flagstat.cwl
        in:
            bam: bam
        out: [flagstats]
    select_variants:
        run: ../tools/select_variants.cwl
        in:
            reference: reference
            vcf: omni_vcf
            interval_list: target_intervals
        out:
            [filtered_vcf]
    verify_bam_id:
        run: ../tools/verify_bam_id.cwl
        in:
            bam: bam
            vcf: select_variants/filtered_vcf
        out:
            [verify_bam_id_metrics, verify_bam_id_depth]

    gather_qc:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                source: [sample_name]
                valueFrom: "$(self)-qc"
            files:
                source: [collect_insert_size_metrics/insert_size_metrics, collect_insert_size_metrics/insert_size_histogram, collect_alignment_summary_metrics/alignment_summary_metrics, collect_roi_hs_metrics/hs_metrics, collect_detailed_hs_metrics/per_target_coverage_metrics, collect_detailed_hs_metrics/per_target_hs_metrics, collect_detailed_hs_metrics/per_base_coverage_metrics, collect_detailed_hs_metrics/per_base_hs_metrics, collect_detailed_hs_metrics/summary_hs_metrics, samtools_flagstat/flagstats, verify_bam_id/verify_bam_id_metrics, verify_bam_id/verify_bam_id_depth]
                valueFrom: |
                    ${
                        var results = [];
                        for(var i=0; i<self.length; i++){
                            if(Array.isArray(self[i])){
                                for(var j=0; j<self[i].length; j++){
                                    results.push(self[i][j]);
                                }
                            } else {
                                results.push(self[i]);
                            }
                        }
                        return results;
                    }
        out:
            [gathered_directory]
