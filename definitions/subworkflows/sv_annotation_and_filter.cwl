#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "run annotsv for annotation and filter resulting tsv"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: MultipleInputFeatureRequirement
    - class: ScatterFeatureRequirement
inputs:
    sv_vcf:
        type: File
    snps_vcf:
        type: File?
        secondaryFiles: [.tbi]
    tsv_base:
        type: string
    genome_build:
        type: string
    annotsv_annotations:
        type:
            - string
            - Directory
    survivor_merged:
        type: boolean
        default: false
outputs:
    tsv:
        type: File
        outputSource: annotsv/annotated_tsv
    unannotated_tsv:
        type: File
        outputSource: annotsv/unannotated_tsv
    filtered_tsv:
        type: File
        outputSource: filter/filtered_tsv
    filtered_tsv_no_CDS: 
        type: File
        outputSource: filter_no_CDS/filtered_tsv
steps:
    annotsv:
        run: ../tools/annotsv.cwl
        in:
            genome_build: genome_build
            input_vcf: sv_vcf
            output_base:
                source: tsv_base
                valueFrom: "$(self + '.AnnotSV')"
            snps_vcf: snps_vcf
            annotations: annotsv_annotations
        out:
            [annotated_tsv, unannotated_tsv]
    filter_no_CDS:
        run: ../tools/annotsv_filter.cwl
        in:
            all_CDS:
                default: true
            annotsv_tsv: annotsv/annotated_tsv
            filtering_frequency:
                default: 0.05
            output_tsv_name:
                source: tsv_base
                valueFrom: "$(self + '.filtered-noCDS.AnnotSV.tsv')"
            survivor_merged: survivor_merged
        out:
            [filtered_tsv]
    filter:
        run: ../tools/annotsv_filter.cwl
        in:
            all_CDS:
                default: false
            annotsv_tsv: annotsv/annotated_tsv
            filtering_frequency:
                default: 0.05
            output_tsv_name:
                source: tsv_base
                valueFrom: "$(self + '.filtered.AnnotSV.tsv')"
            survivor_merged: survivor_merged
        out:
            [filtered_tsv]

