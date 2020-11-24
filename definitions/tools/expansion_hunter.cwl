#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "runs expansion hunter for STR calls"

baseCommand: ["/opt/ExpansionHunter"]
requirements:
    - class: ResourceRequirement
      ramMin: 4000
    - class: DockerRequirement
      dockerPull: "apaul7/docker-expansion-hunter:v3.1.2"

inputs:
    bam:
        type: File
        secondaryFiles: [^.bai]
        inputBinding:
            position: 1
            prefix: "--reads"
        doc: "BAM/CRAM file with aligned reads"
    output_prefix:
        type: string
        inputBinding:
            position: 2
            prefix: "--output-prefix"
        doc: "Prefix for the output files"
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            position: 3
            prefix: "--reference"
        doc: "FASTA file with reference genome"
    variant_catalog:
        type: File
        inputBinding:
            position: 4
            prefix: "--variant-catalog"
        doc: "JSON file with variants to genotype"

outputs:
    vcf:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix).vcf"
    json:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix).json"
    realigned_bam:
        type: File
        outputBinding:
            glob: "$(inputs.output_prefix)_realigned.bam"
