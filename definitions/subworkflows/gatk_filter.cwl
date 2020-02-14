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
            select_type:
                default: ["INDEL", "SNP", "SYMBOLIC"]
        out:
            [filtered_vcf]
    run_filter:
        scatter: [vcf, filter_expression, filter_name]
        scatterMethod: dotproduct
        run: ../tools/filter_variants.cwl
        in:
            vcf: run_split_vcf/filtered_vcf
            reference: reference
            filter_expression:
                default: ["QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0", "QD < 2.0 || FS > 60.0 || MQ < 40.0 || MQRankSum < -12.5 || ReadPosRankSum < -8.0", "QD < 2.0 || FS > 200.0 || ReadPosRankSum < -20.0"]
            filter_name:
                default: ["INDEL_filter_GATK_recommendations", "SNP_filter_GATK_recommendations", "INDEL_filter_GATK_recommendations"]
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
