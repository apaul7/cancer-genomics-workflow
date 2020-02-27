#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

baseCommand: ["/opt/bcftools/bin/bcftools", "view"]

requirements:
    - class: ResourceRequirement
      ramMin: 4000
    - class: DockerRequirement
      dockerPull: "mgibio/bcftools-cwl:1.9"

inputs:
    sample:
        type: string
        inputBinding:
            position: 2
            prefix: "--samples"
        doc: "what sample to pull out"
    output_type:
        type:
            type: enum
            symbols: ["b", "u", "z", "v"]
        default: "z"
        inputBinding:
            position: 4
            prefix: "--output-type"
        doc: "output file format"
    output_vcf_name:
        type: string?
        default: "bcftools.sample.split.vcf.gz"
        inputBinding:
            position: 5
            prefix: "--output-file"
        doc: "output vcf file name"
    vcf:
        type: File
        inputBinding:
            position: 6
        doc: "input bgzipped tabix indexed vcf"

outputs:
    single_sample_vcf:
        type: File
        outputBinding:
            glob: $(inputs.output_vcf_name)

