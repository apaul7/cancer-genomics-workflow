#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

baseCommand: ["/bin/bash", "reheader.sh"]
requirements:
    - class: ResourceRequirement
      ramMin: 4000
    - class: DockerRequirement
      dockerPull: "mgibio/bcftools-cwl:1.9"
    - class: InitialWorkDirRequirement
      listing:
      - entryname: "new_sample.txt"
        entry: $(inputs.sample_name)
      - entryname: "reheader.sh"
        entry: |
          #!/bin/bash
          #set up the environment
          set -eou pipefail

          VCF="$1"
          OUTPUT_TYPE="$2"
          OUTPUT_NAME="$3"

          /opt/bcftools/bin/bcftools reheader --samples new_sample.txt "$VCF" | /opt/bcftools/bin/bcftools view --output-type "$OUTPUT_TYPE" --output-file "$OUTPUT_NAME"
inputs:
    sample_name:
        type: string
    input_vcf:
        type: File
        inputBinding:
            position: 1
        doc: "input bgzipped tabix indexed vcfs"
    output_type:
        type:
            type: enum
            symbols: ["b", "u", "z", "v"]
        default: "z"
        inputBinding:
            position: 2
        doc: "output file format"
    output_vcf_name:
        type: string
        inputBinding:
            position: 3
        doc: "output vcf file name"
outputs:
    renamed_vcf:
        type: File
        outputBinding:
            glob: $(inputs.output_vcf_name)

