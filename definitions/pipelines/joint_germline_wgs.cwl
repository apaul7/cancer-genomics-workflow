#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "joint wgs alignment and germline variant detection"
requirements:
    - class: SchemaDefRequirement
      types:
          - $import: ../types/labelled_file.yml
          - $import: ../types/sequence_data.yml
          - $import: ../types/trimming_options.yml
          - $import: ../types/vep_custom_annotation.yml
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: ScatterFeatureRequirement
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
    ploidy:
        type: int?
    qc_intervals:
        type: File
    synonyms_file:
        type: File?
    annotate_coding_only:
        type: boolean?
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


    sv_exclude_regions:
        type: File
    cnvkit_reference_cnn:
        type: File
        doc: "can be a flat reference or reference based on a set of panel of normals"
    sv_filter_del_depth:
        type: double?
        doc: ""
    sv_filter_dup_depth:
        type: double?
        doc: ""
    sv_filter_paired_count:
        type: int?
        doc: ""
    sv_filter_split_count:
        type: int?
        doc: ""
    sv_filter_alt_abundance_percentage:
        type: double?
        doc: ""
    sv_survivor_max_distance:
        type: int
        doc: ""
    sv_survivor_min_calls:
        type: int
        doc: ""
    sv_survivor_same_type:
        type: boolean
        doc: ""
    sv_survivor_same_strand:
        type: boolean
        doc: ""
    sv_survivor_estimate_distance:
        type: boolean
        doc: ""
    sv_survivor_min_size:
        type: int
        doc: ""
    sv_annotsv_annotations:
        type:
            - string
            - Directory

    str_expansion_hunter_variant_catalog:
        type: File
        doc: ""
    str_ehdn_min_anchor_mapq:
        type: int
        doc: ""
    str_ehdn_max_irr_mapq:
        type: int
        doc: ""
    str_strling_reference:
        type: File
        doc: ""

outputs:
    alignments:
        type: Directory
        outputSource: alignment_and_qc/gathered_results
    snps_results:
        type: Directory
        outputSource: joint_detect_variants/snps_results
    sv_results:
        type: Directory
        outputSource: joint_detect_variants/sv_results
    str_results:
        type: Directory
        outputSource: joint_detect_variants/str_results
steps:
    alignment_and_qc:
        run: ../subworkflows/joint_alignment_wgs.cwl
        in:
            reference: reference
            sequences: sequences
            sample_names: sample_names
            trimming: trimming
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
                                return {'freemix_score:': -1 };
                            }
                        }
    joint_detect_variants:
        run: ../subworkflows/joint_detect_variants.cwl
        in:
            reference: reference
            sample_names: sample_names
            bams: alignment_and_qc/bams
            cohort_name: cohort_name
            contamination_fraction: extract_freemix/freemix_score
            emit_reference_confidence: emit_reference_confidence
            gvcf_gq_bands: gvcf_gq_bands
            scatter_intervals: intervals
            synonyms_file: synonyms_file
            vep_cache_dir: vep_cache_dir
            vep_ensembl_assembly: vep_ensembl_assembly
            vep_ensembl_version: vep_ensembl_version
            vep_ensembl_species: vep_ensembl_species
            indel_vep_custom_annotations: indel_vep_custom_annotations
            indel_vep_plugins: indel_vep_plugins
            indel_vep_tsv_fields: indel_vep_tsv_fields
            sv_exclude_regions: sv_exclude_regions
            cnvkit_reference_cnn: cnvkit_reference_cnn
            sv_filter_del_depth: sv_filter_del_depth
            sv_filter_dup_depth: sv_filter_dup_depth
            sv_filter_paired_count: sv_filter_paired_count
            sv_filter_split_count: sv_filter_split_count
            sv_filter_alt_abundance_percentage: sv_filter_alt_abundance_percentage
            sv_survivor_max_distance: sv_survivor_max_distance
            sv_survivor_min_calls: sv_survivor_min_calls
            sv_survivor_same_type: sv_survivor_same_type
            sv_survivor_same_strand: sv_survivor_same_strand
            sv_survivor_estimate_distance: sv_survivor_estimate_distance
            sv_survivor_min_size: sv_survivor_min_size
            sv_annotsv_annotations: sv_annotsv_annotations
            str_expansion_hunter_variant_catalog: str_expansion_hunter_variant_catalog
            str_ehdn_min_anchor_mapq: str_ehdn_min_anchor_mapq
            str_ehdn_max_irr_mapq: str_ehdn_max_irr_mapq
            str_strling_reference: str_strling_reference
        out:
            [snps_results, sv_results, str_results]


