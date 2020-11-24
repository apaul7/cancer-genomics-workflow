#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run detect_snps, detect_svs, and detect_strs subworkflows"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
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
        type: string

    contamination_fraction:
        type: string[]

    emit_reference_confidence:
        type:
            type: enum
            symbols: ['NONE', 'BP_RESOLUTION', 'GVCF']
    gvcf_gq_bands:
        type: string[]
    scatter_intervals:
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
    snps_results:
        type: Directory
        outputSource: joint_snps/gathered_results
    sv_results:
        type: Directory
        outputSource: joint_svs/gathered_results
    str_results:
        type: Directory
        outputSource: joint_strs/gathered_results

steps:
    joint_snps:
        run: joint_detect_snps.cwl
        in:
            reference: reference
            sample_names: sample_names
            bams: bams
            cohort_name: cohort_name
            emit_reference_confidence: emit_reference_confidence
            gvcf_gq_bands: gvcf_gq_bands
            intervals: scatter_intervals
            synonyms_file: synonyms_file
            vep_cache_dir: vep_cache_dir
            vep_ensembl_assembly: vep_ensembl_assembly
            vep_ensembl_version: vep_ensembl_version
            vep_ensembl_species: vep_ensembl_species
            indel_vep_custom_annotations: indel_vep_custom_annotations
            indel_vep_plugins: indel_vep_plugins
            indel_vep_tsv_fields: indel_vep_tsv_fields
            contamination_fraction: contamination_fraction
        out:
            [gathered_results, raw_vcf, filtered_vcf]
    joint_svs:
        run: joint_detect_svs.cwl
        in:
            reference: reference
            sample_names: sample_names
            bams: bams
            cohort_name: cohort_name
            snps_vcf: joint_snps/filtered_vcf
            sv_exclude_regions: sv_exclude_regions
            cnvkit_reference_cnn: cnvkit_reference_cnn
            filter_del_depth: sv_filter_del_depth
            filter_dup_depth: sv_filter_dup_depth
            filter_paired_count: sv_filter_paired_count
            filter_split_count: sv_filter_split_count
            filter_alt_abundance_percentage: sv_filter_alt_abundance_percentage
            survivor_max_distance: sv_survivor_max_distance
            survivor_min_calls: sv_survivor_min_calls
            survivor_same_type: sv_survivor_same_type
            survivor_same_strand: sv_survivor_same_strand
            survivor_estimate_distance: sv_survivor_estimate_distance
            survivor_min_size: sv_survivor_min_size
            genome_build: vep_ensembl_assembly
            annotsv_annotations: sv_annotsv_annotations
        out:
            [gathered_results]

    joint_strs:
        run: joint_detect_strs.cwl
        in:
            reference: reference
            sample_names: sample_names
            bams: bams
            cohort_name: cohort_name
            expansion_hunter_variant_catalog: str_expansion_hunter_variant_catalog
            ehdn_min_anchor_mapq: str_ehdn_min_anchor_mapq
            ehdn_max_irr_mapq: str_ehdn_max_irr_mapq
            strling_reference: str_strling_reference
        out:
            [gathered_results]
