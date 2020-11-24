#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "runs strling merge for STR bins"

baseCommand: ["/opt/bin/strling", "merge"]
requirements:
    - class: ResourceRequirement
      ramMin: 10000
    - class: DockerRequirement
      dockerPull: "apaul7/analysis:1.0.0"

arguments: ["--output-prefix", "joint"]
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            position: 1
            prefix: "--fasta"
    bins:
        type: File[]
        inputBinding:
            position: 2
        doc: ""

outputs:
    joint_bounds:
        type: File
        outputBinding:
            glob: "joint-bounds.txt"
