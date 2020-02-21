#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "Run gatk best practices filtering"
requirements:
    - class: ScatterFeatureRequirement
    - class: SubworkflowFeatureRequirement
inputs:
    vcf:
        type: File
        secondaryFiles: [.tbi]
    reference: 
        type:
            - string
            - File
        secondaryFiles: [.fai]
    filter_variant_type:
        type:
            type: array
            items:
              - "null"
              - type: enum
                symbols: ["INDEL", "SNP", "MIXED", "MNP", "SYMBOLIC", "NO_VARIATION"]
        default: ["INDEL", "SNP", "SYMBOLIC"]
    filter_expression:
        type: string[]?
        default: ["QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0", "QD < 2.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0", "QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0"]
    filter_name:
        type: string[]?
        default: ["INDEL_filter_GATK_recommendations", "SNP_filter_GATK_recommendations", "INDEL_filter_GATK_recommendations"]
outputs:
    filtered_vcf:
        type: File
        secondaryFiles: [.tbi]
        outputSource: run_index_concat_vcf/indexed_vcf
steps:
    run_split_vcf:
        scatter: [select_type]
        scatterMethod: dotproduct 
        run: ../tools/select_variants.cwl
        in:
            vcf: vcf
            reference: reference
            select_type: filter_variant_type
        out:
            [filtered_vcf]
    run_filter:
        scatter: [filter_expression, filter_name, vcf]
        scatterMethod: dotproduct
        run: ../tools/filter_variants.cwl
        in:
            vcf: run_split_vcf/filtered_vcf
            reference: reference
            filter_expression: filter_expression
            filter_name: filter_name
        out:
            [filtered_vcf]
    run_index_vcf:
        scatter: [vcf]
        scatterMethod: dotproduct
        run: ../tools/index_vcf.cwl
        in:
            vcf: run_filter/filtered_vcf
        out:
            [indexed_vcf]
    run_concat:
        run: ../tools/bcftools_concat.cwl
        in:
            vcfs: run_index_vcf/indexed_vcf
            output_vcf_name:
                default: "combined.all.gt.vt.filtered.vcf.gz"
            output_type:
                default: "z"
        out:
            [concat_vcf]
    run_index_concat_vcf:
        run: ../tools/index_vcf.cwl
        in:
            vcf: run_concat/concat_vcf
        out:
            [indexed_vcf]
