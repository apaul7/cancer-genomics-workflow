#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run expansion hunter for STR calls"
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
    variant_catalog:
        type: File

outputs:
    vcfs:
        type: File[]
        secondaryFiles: [.tbi]
        outputSource: bgzip_index/indexed_vcf
    jsons:
        type: File[]
        outputSource: expansion_hunter/json
    realigned_bams:
        type: File[]
        outputSource: expansion_hunter/realigned_bam
    merged_vcf:
        type: File
        secondaryFiles: [.tbi]
        outputSource: index/indexed_vcf
    merged_tsv:
        type: File
        outputSource: rename_tsv/replacement

steps:
    expansion_hunter:
        scatter: [bam, output_prefix]
        scatterMethod: dotproduct
        run: ../tools/expansion_hunter.cwl
        in:
            bam: bams
            output_prefix: sample_names
            reference: reference
            variant_catalog: variant_catalog
        out:
            [vcf, json, realigned_bam]
    bgzip_index:
        scatter: [vcf]
        scatterMethod: dotproduct
        run: bgzip_and_index.cwl
        in:
            vcf: expansion_hunter/vcf
        out:
            [indexed_vcf]
    merge:
        run: ../tools/bcftools_merge_custom_str.cwl
        in:
            vcfs: bgzip_index/indexed_vcf
        out:
            [merged_vcf]
    index:
        run: ../tools/index_vcf.cwl
        in:
            vcf: merge/merged_vcf
        out:
            [indexed_vcf]
    tsv:
        run: ../tools/variants_to_table.cwl
        in:
            reference: reference
            vcf: index/indexed_vcf
            fields:
                default: ["CHROM", "POS", "ID", "REF_CN", "ALT", "VARID", "RL", "REPID"]
            genotype_fields:
                default: ["GT", "REPCN", "REPCI", "LC"]
        out:
            [variants_tsv]
    rename_tsv:
        run: ../tools/staged_rename.cwl
        in:
            original: tsv/variants_tsv
            name:
                source: cohort_name
                valueFrom: |
                    ${
                        return self + "-expansion_hunter.tsv";
                    }
        out:
            [replacement]
