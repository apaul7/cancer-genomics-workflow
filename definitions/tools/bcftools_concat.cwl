#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

baseCommand: ["/opt/bcftools/bin/bcftools", "concat"]

requirements:
    - class: ResourceRequirement
      ramMin: 4000
    - class: DockerRequirement
      dockerPull: "mgibio/bcftools-cwl:1.9"

inputs:
    output_type:
        type:
            type: enum
            symbols: ["b", "u", "z", "v"]
        default: "z"
        inputBinding:
            position: 1
            prefix: "--output-type"
        doc: "output file format"
    output_vcf_name:
        type: string?
        default: "bcftools_concat.vcf.gz"
        inputBinding:
            position: 2
            prefix: "--output"
        doc: "output vcf file name"
    vcfs:
        type: File[]
        inputBinding:
            position: 3
        doc: "input bgzipped tabix indexed vcfs to merge"

outputs:
    concat_vcf:
        type: File
        outputBinding:
            glob: $(inputs.output_vcf_name)

