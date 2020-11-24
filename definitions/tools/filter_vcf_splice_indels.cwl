#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: ""
baseCommand: ["/usr/bin/perl", "/opt/vep/src/ensembl-vep/filter_vep"]
requirements:
    - class: InlineJavascriptRequirement
    - class: DockerRequirement
      dockerPull: "mgibio/vep_helper-cwl:1.1.0"
    - class: ResourceRequirement
      ramMin: 4000
    - class: StepInputExpressionRequirement

arguments:
    ["--format", "vcf",
    "-o", { valueFrom: $(runtime.outdir)/indels.annotated.filtered.vcf }]
inputs:
    vcf:
        type: File
        inputBinding:
            prefix: "-i"
            position: 1
    filtering_frequency:
        type: float
        inputBinding:
            valueFrom: |
                ${
                    return [
                        "--filter",
                        [
                            "(Consequence matches splice) and (", inputs.field_name, "<", inputs.filtering_frequency,
                            "or not", inputs.field_name , ")"
                        ].join(" ")
                    ]
                }
            position: 2
    field_name:
        type: string
outputs:
    filtered_vcf:
        type: File
        outputBinding:
            glob: "indels.annotated.filtered.vcf"
