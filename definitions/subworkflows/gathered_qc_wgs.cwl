#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "WGS QC workflow"
requirements:
    - class: SchemaDefRequirement
      types:
          - $import: ../types/labelled_file.yml
    - class: SubworkflowFeatureRequirement
inputs:
    sample_name:
        type: string?
        default: 'final'
    bam:
        type: File
        secondaryFiles: [^.bai]
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    intervals:
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
    collect_gc_bias_metrics:
        run: ../tools/collect_gc_bias_metrics.cwl
        in:
            sample_name: sample_name
            bam: bam
            reference: reference
            metric_accumulation_level: picard_metric_accumulation_level
        out:
            [gc_bias_metrics, gc_bias_metrics_chart, gc_bias_metrics_summary]
    collect_wgs_metrics:
        run: ../tools/collect_wgs_metrics.cwl
        in:
            sample_name: sample_name
            bam: bam
            reference: reference
            intervals: intervals
        out:
            [wgs_metrics]
    samtools_flagstat:
        run: ../tools/samtools_flagstat.cwl
        in:
            bam: bam
        out: [flagstats]
    verify_bam_id:
        run: ../tools/verify_bam_id.cwl
        in:
            bam: bam
            vcf: omni_vcf
        out:
            [verify_bam_id_metrics, verify_bam_id_depth]
    collect_hs_metrics:
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
    gather_qc:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                source: [sample_name]
                valueFrom: "$(self)-qc"
            files:
                source: [collect_insert_size_metrics/insert_size_metrics, collect_insert_size_metrics/insert_size_histogram, collect_alignment_summary_metrics/alignment_summary_metrics, collect_gc_bias_metrics/gc_bias_metrics, collect_gc_bias_metrics/gc_bias_metrics_chart, collect_gc_bias_metrics/gc_bias_metrics_summary, collect_wgs_metrics/wgs_metrics, samtools_flagstat/flagstats, verify_bam_id/verify_bam_id_metrics, verify_bam_id/verify_bam_id_depth, collect_hs_metrics/per_base_coverage_metrics, collect_hs_metrics/per_base_hs_metrics, collect_hs_metrics/per_target_coverage_metrics, collect_hs_metrics/per_target_hs_metrics, collect_hs_metrics/summary_hs_metrics]
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
