#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "runs expansion hunter denovo to generate STR profiles"

baseCommand: ["/opt/ExpansionHunterDenovo/bin/ExpansionHunterDenovo", "profile"]
requirements:
    - class: ResourceRequirement
      ramMin: 4000
    - class: DockerRequirement
      dockerPull: "apaul7/docker-expansion-hunter-denovo:v0.9.0"

inputs:
    bam:
        type: File
        secondaryFiles: [^.bai]
        inputBinding:
            position: 1
            prefix: "--reads"
        doc: "BAM/CRAM file with aligned reads"
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            position: 2
            prefix: "--reference"
        doc: "FASTA file with reference genome"
    output_prefix:
        type: string
        inputBinding:
            position: 3
            prefix: "--output-prefix"
        doc: "Prefix for the output files"
    min_anchor_mapq:
        type: int
        default: 50
        inputBinding:
            position: 4
            prefix: "--min-anchor-mapq"
        doc: ""
    max_irr_mapq:
        type: int
        default: 50
        inputBinding:
            position: 4
            prefix: "--max-irr-mapq"
        doc: ""
outputs:
    json_profile:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix).str_profile.json"
