#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "Subworkflow to use different STR callers"

requirements:
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
    - class: SubworkflowFeatureRequirement

inputs:
    bams:
        type: File[]
        secondaryFiles: [.bai,^.bai]
    sample_names:
        type: string[]
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    variant_catalog:
        type: File
outputs:
    merged_expansion_hunter_vcf:
        type: File
        outputSource: index_merged_vcf/indexed_vcf
        secondaryFiles: [.tbi]
    merged_expansion_hunter_tsv:
        type: File
        outputSource: rename_tsv/replacement
    expansion_hunter_vcfs:
        type: File[]
        outputSource: bgzip_and_index/indexed_vcf
        secondaryFiles: [.tbi]
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
            [out_vcf]
    bgzip_and_index:
        scatter: [vcf]
        scatterMethod: dotproduct
        run: bgzip_and_index.cwl
        in:
            vcf: expansion_hunter/out_vcf
        out:
            [indexed_vcf]
    bcftools_merge:
        run: ../tools/bcftools_merge_expansion_hunter.cwl
        in:
            vcfs: bgzip_and_index/indexed_vcf
        out:
            [merged_vcf]
    index_merged_vcf:
        run: ../tools/index_vcf.cwl
        in:
            vcf: bcftools_merge/merged_vcf
        out:
            [indexed_vcf]
    to_tsv:
        run: ../tools/variants_to_table.cwl
        in:
            reference: reference
            vcf: index_merged_vcf/indexed_vcf
            fields:
                default: ['CHROM', 'POS', 'ID', 'REF_CN', 'ALT', 'VARID', 'RL', 'REPID']
            genotype_fields:
                default: ['GT', 'REPCN', 'REPCI', 'LC']
        out:
            [variants_tsv]
    rename_tsv:
        run: ../tools/rename.cwl
        in:
            original: to_tsv/variants_tsv
            name:
                default: 'expansion_hunter.tsv'
        out:
            [replacement]
