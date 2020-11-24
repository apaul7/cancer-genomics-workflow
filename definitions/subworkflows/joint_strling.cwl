#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run strling for STR calls"
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
    strling_reference:
        type: File
    cohort_name:
        type: string

outputs:
    bins:
        type: File[]
        outputSource: extract/bin
    joint_bounds:
        type: File
        outputSource: merge/joint_bounds
    calls:
        type: File[]
        outputSource: call/genotype
    bounds:
        type: File[]
        outputSource: call/bounds
    unplaced:
        type: File[]
        outputSource: call/unplaced

steps:
    extract:
        scatter: [bam, output_prefix]
        scatterMethod: dotproduct
        run: ../tools/strling_extract.cwl
        in:
            reference: reference
            strling_reference: strling_reference
            bam: bams
            output_prefix: sample_names
        out:
            [bin]
    merge:
        run: ../tools/strling_merge.cwl
        in:
            reference: reference
            bins: extract/bin
        out:
            [joint_bounds]
    call:
        scatter: [output_prefix, bam, bin]
        scatterMethod: dotproduct
        run: ../tools/strling_call.cwl
        in:
            reference: reference
            output_prefix: sample_names
            joint_bounds: merge/joint_bounds
            bam: bams
            bin: extract/bin
        out:
            [genotype, bounds, unplaced]
