#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run expansion hunter denovo for STR calls"
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
    min_anchor_mapq:
        type: int
    max_irr_mapq:
        type: int

outputs:
    ehdn_profiles:
        type: File[]
        outputSource: make_profiles/json_profile

steps:
    make_profiles:
        scatter: [bam, output_prefix]
        scatterMethod: dotproduct
        run: ../tools/expansion_hunter_denovo.cwl
        in:
            bam: bams
            reference: reference
            output_prefix: sample_names
            min_anchor_mapq: min_anchor_mapq
            max_irr_mapq: max_irr_mapq
        out:
            [json_profile]
# merge

# call case-control motif
# call case-control locus

# call outlier motif
# call outlier locus
