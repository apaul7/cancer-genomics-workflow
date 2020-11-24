#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "runs strling extract for STR calls"

baseCommand: ["/opt/bin/strling", "extract"]
requirements:
    - class: ResourceRequirement
      ramMin: 10000
    - class: DockerRequirement
      dockerPull: "apaul7/analysis:1.0.0"

arguments: [{ position: 1, valueFrom: "$(inputs.output_prefix).bin"}]
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            position: -3
            prefix: "--fasta"
    strling_reference:
        type: File
        inputBinding:
            position: -2
            prefix: "--genome-repeats"
    bam:
        type: File
        secondaryFiles: [^.bai]
        inputBinding:
            position: -1
        doc: "BAM/CRAM file with aligned reads"
    output_prefix:
        type: string
        doc: "Prefix for the output file"

outputs:
    bin:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix).bin"
