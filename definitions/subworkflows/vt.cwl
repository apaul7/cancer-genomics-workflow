#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "Run vt decompose, normlaize and uniq"
requirements:
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
    vt_vcf:
        type: File
        outputSource: run_uniq/uniq_vcf
steps:
    run_decompose:
        run: ../tools/vt_decompose.cwl
        in:
            vcf: vcf
        out:
            [decomposed_vcf]
    index_decompose:
        run: ../tools/index_vcf.cwl
        in:
            vcf: run_decompose/decomposed_vcf
        out:
            [indexed_vcf]
    run_normalize:
        run: ../tools/vt_normalize.cwl
        in:
            vcf: index_decompose/indexed_vcf
            reference: reference
        out:
            [normalized_vcf]
    index_normalize:
        run: ../tools/index_vcf.cwl
        in:
            vcf: run_normalize/normalized_vcf
        out:
            [indexed_vcf]
    run_uniq:
        run: ../tools/vt_uniq.cwl
        in:
            vcf: index_normalize/indexed_vcf
        out:
            [uniq_vcf]
