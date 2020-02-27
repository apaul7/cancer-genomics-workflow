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
    - class: InlineJavascriptRequirement
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
    expansion_hunter_catalog:
        type: File
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
    cnvkit_diagram:
        type: boolean?
    cnvkit_drop_low_coverage:
        type: boolean?
    cnvkit_method:
        type: string?
    cnvkit_scatter_plot:
        type: boolean?

    sv_merge_max_distance:
        type: int
    sv_merge_min_svs:
        type: int
    sv_merge_same_type:
        type: boolean
    sv_merge_same_strand:
        type: boolean
    sv_merge_estimate_sv_distance:
        type: boolean
    sv_merge_min_sv_size:
        type: int
    sv_exclude_regions:
        type: File?
    genome_build:
        type: string
    sv_alt_abundance_percentage:
        type: double?
    sv_paired_count:
        type: int?
    sv_split_count:
        type: int?
    cnv_deletion_depth:
        type: double?
    cnv_duplication_depth:
        type: double?
    cnv_filter_min_size:
        type: int?
outputs:
    per_sample_outs:
        type: Directory[]
        outputSource: per_sample_outputs/gathered_files
    snps_vcf:
        type: File
        outputSource: gatk_filter_vcf/filtered_vcf
        secondaryFiles: [.tbi]
    smoove_vcf:
        type: File
        outputSource: joint_detect_svs/smoove_vcf
        secondaryFiles: [.tbi]
    manta_diploid_vcf:
        type: File
        outputSource: joint_detect_svs/manta_diploid_vcf
        secondaryFiles: [.tbi]
    manta_small_candidates:
        type: File
        outputSource: joint_detect_svs/manta_small_candidates
        secondaryFiles: [.tbi]
    manta_all_candidates:
        type: File
        outputSource: joint_detect_svs/manta_all_candidates
        secondaryFiles: [.tbi]
    bcftools_sv_vcf:
        type: File
        outputSource: joint_detect_svs/bcftools_sv_vcf
    bcftools_annotated_tsv:
        type: File
        outputSource: joint_detect_svs/bcftools_annotated_tsv
    bcftools_annotated_tsv_filtered:
        type: File
        outputSource: joint_detect_svs/bcftools_annotated_tsv_filtered
    bcftools_annotated_tsv_filtered_no_cds:
        type: File
        outputSource: joint_detect_svs/bcftools_annotated_tsv_filtered_no_cds
    survivor_sv_vcf:
        type: File
        outputSource: joint_detect_svs/survivor_sv_vcf
    survivor_annotated_tsv:
        type: File
        outputSource: joint_detect_svs/survivor_annotated_tsv
    survivor_annotated_tsv_filtered:
        type: File
        outputSource: joint_detect_svs/survivor_annotated_tsv_filtered
    survivor_annotated_tsv_filtered_no_cds:
        type: File
        outputSource: joint_detect_svs/survivor_annotated_tsv_filtered_no_cds
    expansion_hunter_vcf:
        type: File
        outputSource: run_expansion_hunter/merged_expansion_hunter_vcf
        secondaryFiles: [.tbi]
    expansion_hunter_tsv:
        type: File
        outputSource: run_expansion_hunter/merged_expansion_hunter_tsv
steps:
    alignment_and_qc:
        scatter: [sequence, sample_name]
        scatterMethod: dotproduct
        run: alignment_wgs.cwl
        in:
            reference: reference
            sequence: sequence
            sample_name: sample_name
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
            [bam, mark_duplicates_metrics, insert_size_metrics, insert_size_histogram, alignment_summary_metrics, gc_bias_metrics, gc_bias_metrics_chart, gc_bias_metrics_summary, wgs_metrics, flagstats, verify_bam_id_metrics, verify_bam_id_depth]
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
    run_joint_gatk:
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
            standard_call_confidence:
                default: 30
            standard_emit_confidence:
                default: 10
        out:
            [genotype_vcf]
    run_vt:
        run: ../subworkflows/vt.cwl
        in:
            vcf: run_joint_gatk/genotype_vcf
            reference: reference
        out:
            [vt_vcf]
    index_vt_vcf:
        run: ../tools/index_vcf.cwl
        in:
            vcf: run_vt/vt_vcf
        out:
            [indexed_vcf]
    gatk_filter_vcf:
        run: ../subworkflows/gatk_filter.cwl
        in:
            vcf: index_vt_vcf/indexed_vcf
            reference: reference
        out:
            [filtered_vcf]
    joint_detect_svs:
        run: ../subworkflows/joint_sv_callers.cwl
        in:
            bams: alignment_and_qc/bam
            sample_names: sample_name
            reference: reference
            cnvkit_diagram: cnvkit_diagram
            cnvkit_drop_low_coverage: cnvkit_drop_low_coverage
            cnvkit_method: cnvkit_method
            cnvkit_scatter_plot: cnvkit_scatter_plot
            manta_output_contigs:
                default: true
            merge_max_distance: sv_merge_max_distance
            merge_min_svs: sv_merge_min_svs
            merge_same_type: sv_merge_same_type
            merge_same_strand: sv_merge_same_strand
            merge_estimate_sv_distance: sv_merge_estimate_sv_distance
            merge_min_sv_size: sv_merge_min_sv_size
            smoove_exclude_regions: sv_exclude_regions
            snps_vcf: run_joint_gatk/genotype_vcf
            genome_build: genome_build
            sv_paired_count: sv_paired_count
            sv_split_count: sv_split_count
            cnv_deletion_depth: cnv_deletion_depth
            cnv_duplication_depth: cnv_duplication_depth
            cnv_filter_min_size: cnv_filter_min_size
        out:
            [smoove_vcf, manta_diploid_vcf, manta_small_candidates, manta_all_candidates, cnvnator_vcfs, cnvnator_roots, cnvnator_cn_files, cnvkit_vcfs, filtered_cnvnator_vcfs, filtered_cnvkit_vcfs, filtered_manta_vcfs, filtered_smoove_vcfs, bcftools_sv_vcf, bcftools_annotated_tsv, bcftools_annotated_tsv_filtered, bcftools_annotated_tsv_filtered_no_cds, survivor_sv_vcf, survivor_annotated_tsv, survivor_annotated_tsv_filtered, survivor_annotated_tsv_filtered_no_cds]
    run_expansion_hunter:
        run: ../subworkflows/joint_str.cwl
        in:
            bams: alignment_and_qc/bam
            reference: reference
            variant_catalog: expansion_hunter_catalog
            sample_names: sample_name
        out:
            [merged_expansion_hunter_vcf, merged_expansion_hunter_tsv, expansion_hunter_vcfs]
    per_sample_outputs:
        scatter: [output_dir]
        scatterMethod: dotproduct
        run: ../tools/gatherer.cwl
        in:
            sample_name: sample_name
            output_dir:
                source: sample_name
                valueFrom: |
                  ${
                    return self + "-outs";
                  }
            all_files:
                source: [alignment_and_qc/mark_duplicates_metrics, alignment_and_qc/insert_size_metrics, alignment_and_qc/insert_size_histogram, alignment_and_qc/alignment_summary_metrics, alignment_and_qc/gc_bias_metrics, alignment_and_qc/gc_bias_metrics_chart, alignment_and_qc/gc_bias_metrics_summary, alignment_and_qc/wgs_metrics, alignment_and_qc/flagstats, alignment_and_qc/verify_bam_id_metrics, alignment_and_qc/verify_bam_id_depth, index_cram/indexed_cram, joint_detect_svs/cnvnator_vcfs, joint_detect_svs/cnvnator_roots, joint_detect_svs/cnvnator_cn_files, joint_detect_svs/cnvkit_vcfs, joint_detect_svs/filtered_cnvnator_vcfs, joint_detect_svs/filtered_cnvkit_vcfs, joint_detect_svs/filtered_manta_vcfs, joint_detect_svs/filtered_smoove_vcfs]
                valueFrom: |
                  ${
                    var sample_index = inputs.sample_name.indexOf(inputs.output_dir.replace("-outs",""));
                    var input_length = self[0].length;
                    var sample_files = [];
                    for(var i=0; i<input_length; i++){
                      sample_files.push(self[i][sample_index]);
                    }
                    return sample_files;
                  }
        out:
            [gathered_files]
