#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run str callers"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: ScatterFeatureRequirement
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
    expansion_hunter_variant_catalog:
        type: File
        doc: ""

    ehdn_min_anchor_mapq:
        type: int
        doc: ""
    ehdn_max_irr_mapq:
        type: int
        doc: ""

    strling_reference:
        type: File
        doc: ""

outputs:
    gathered_results:
        type: Directory
        outputSource: gather_all/gathered_directory

steps:
    expansion_hunter:
        run: joint_expansion_hunter.cwl
        in:
            reference: reference
            sample_names: sample_names
            bams: bams
            cohort_name: cohort_name
            variant_catalog: expansion_hunter_variant_catalog
        out:
            [vcfs, jsons, realigned_bams, merged_vcf, merged_tsv]
    expansion_hunter_denovo:
        run: joint_expansion_hunter_denovo.cwl
        in:
           reference: reference
           sample_names: sample_names
           bams: bams
           cohort_name: cohort_name
           min_anchor_mapq: ehdn_min_anchor_mapq
           max_irr_mapq: ehdn_max_irr_mapq
        out:
            [ehdn_profiles]
    strling:
        run: joint_strling.cwl
        in:
            reference: reference
            sample_names: sample_names
            bams: bams
            strling_reference: strling_reference
            cohort_name: cohort_name
        out:
            [bins, joint_bounds, calls, bounds, unplaced]

    gather_individual_expansion_hunter:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "individual"
            files:
                source: [expansion_hunter/vcfs, expansion_hunter/jsons, expansion_hunter/realigned_bams]
                linkMerge: merge_flattened
        out:
            [gathered_directory]

    gather_expansion_hunter:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "expansion_hunter"
            files:
                source: [expansion_hunter/merged_vcf, expansion_hunter/merged_tsv]
                linkMerge: merge_flattened
            directory: gather_individual_expansion_hunter/gathered_directory
        out:
            [gathered_directory]
    gather_expansion_hunter_denovo:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "ehdn"
            files:
                source: [expansion_hunter_denovo/ehdn_profiles]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
    gather_strling:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "strling"
            files:
                source: [strling/bins, strling/calls, strling/bounds, strling/unplaced]
                linkMerge: merge_flattened
            file1: strling/joint_bounds
        out:
            [gathered_directory]
    gather_all:
        run: ../tools/gather_to_sub_directory_dirs.cwl
        in:
            outdir:
                default: "STR_pipeline"
            directories:
                source: [gather_expansion_hunter/gathered_directory, gather_expansion_hunter_denovo/gathered_directory, gather_strling/gathered_directory]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
