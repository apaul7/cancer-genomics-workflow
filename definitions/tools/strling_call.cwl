#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "runs strling call to generate per sample str calls"

baseCommand: ["/opt/bin/strling", "call"]
requirements:
    - class: ResourceRequirement
      ramMin: 10000
    - class: DockerRequirement
      dockerPull: "apaul7/analysis:1.0.0"

inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            position: -3
            prefix: "--fasta"
    output_prefix:
        type: string
        inputBinding:
            position: -2
            prefix: "--output-prefix"
        doc: "Prefix for the output file"
    joint_bounds:
        type: File?
        inputBinding:
            position: -1
            prefix: "--bounds"
        doc: "STRling -bounds.txt file (usually produced by strling merge) specifying additional STR loci to genotype."
    bam:
        type: File
        secondaryFiles: [^.bai]
        inputBinding:
            position: 1
        doc: "BAM/CRAM file with aligned reads"
    bin:
        type: File
        inputBinding:
            position: 2
        doc: "in file previously created by `strling extract`"

outputs:
    genotype:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix)-genotype.txt"
    bounds:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix)-bounds.txt"
    unplaced:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix)-unplaced.txt"
