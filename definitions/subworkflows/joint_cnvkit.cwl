#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run cnvkit for sv calls"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: ScatterFeatureRequirement
inputs:
    sample_names:
        type: string[]
    bams:
        type: File[]
        secondaryFiles: [^.bai]
    reference_cnn:
        type: File
        doc: "can be a flat reference or reference based on a set of panel of normals"
outputs:
    vcf:
        type: File[]
        outputSource: bgzip_cnvkit/indexed_vcf
        secondaryFiles: [.tbi]
    cns:
        type: File[]
        outputSource: cnvkit/cns
    cnr:
        type: File[]
        outputSource: cnvkit/cnr
steps:
    cnvkit:
        scatter: [bam, sample]
        scatterMethod: dotproduct
        run: ../tools/cnvkit.cwl
        in:
            bam: bams
            sample: sample_names
            reference_cnn: reference_cnn
            method:
                default: "wgs"
            target_average_size:
                default: 1000
            segment_filter:
                default: "cn"
        out:
            [vcf, cns, cnr]
    bgzip_cnvkit:
        scatter: [vcf]
        run: bgzip_and_index.cwl
        in:
            vcf: cnvkit/vcf
        out:
            [indexed_vcf]
