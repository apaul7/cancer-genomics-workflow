#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

baseCommand: ["/bin/bash", "merge.sh"]
requirements:
    - class: ResourceRequirement
      ramMin: 4000
    - class: DockerRequirement
      dockerPull: "mgibio/bcftools-cwl:1.9"
    - class: InitialWorkDirRequirement
      listing:
      - entryname: "merge.sh"
        entry: |
          #!/bin/bash
          set -eou pipefail
          # merge, rename REF field (which contains reference copy number), output vcf.gz not default bcf format
          /opt/bcftools/bin/bcftools merge "$@" | sed -e '/#CHROM/!s/\([;=[:space:]]\)REF\([,;=[:space:]]\)/\1REF_CN\2/' | /opt/bcftools/bin/bcftools view -O z -o merged.ExpansionHunter.vcf.gz
inputs:
    vcfs:
        type: File[]
        inputBinding:
            position: 1
        doc: "input bgzipped tabix indexed vcfs to merge"
outputs:
    merged_vcf:
        type: File
        outputBinding:
            glob: "merged.ExpansionHunter.vcf.gz"

