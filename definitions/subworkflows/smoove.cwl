#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run smoove for sv calls"
inputs:
    bams:
        type: File[]
        secondaryFiles: [^.bai]
    cohort_name:
        type: string?
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    exclude_regions:
        type: File
        doc: ""
outputs:
    vcf:
        type: File
        outputSource: index/indexed_vcf
        secondaryFiles: [.tbi]
steps:
    smoove:
        run: ../tools/smoove.cwl
        in:
            bams: bams
            cohort_name: cohort_name
            reference: reference
            exclude_regions: exclude_regions
        out:
            [vcf]
    index:
        run: ../tools/index_vcf.cwl
        in:
            vcf: smoove/vcf
        out:
            [indexed_vcf]
