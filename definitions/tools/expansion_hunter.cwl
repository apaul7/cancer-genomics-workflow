#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

baseCommand: ["/opt/ExpansionHunter"]
requirements:
    - class: ResourceRequirement
      ramMin: 10000
    - class: DockerRequirement
      dockerPull: "apaul7/docker-expansion-hunter:v3.1.2"

inputs:
    bam:
        type: File
        inputBinding:
            position: 1
            prefix: "--reads"
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            position: 2
            prefix: "--reference"
    variant_catalog:
        type: File
        inputBinding:
            position: 3
            prefix: "--variant-catalog"
    output_prefix:
        type: string
        inputBinding:
            position: 4
            prefix: "--output-prefix"

outputs:
    out_vcf:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix).vcf"
