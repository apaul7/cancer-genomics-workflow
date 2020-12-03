#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

baseCommand: ["/bin/bash", "run_custom_merge.sh"]

requirements:
    - class: ResourceRequirement
      ramMin: 4000
    - class: DockerRequirement
      dockerPull: "mgibio/bcftools-cwl:1.9"
    - class: InitialWorkDirRequirement
      listing:
      - entryname: "run_custom_merge.sh"
        entry: |
          #!/bin/bash
         
          set -eou pipefail

          # set vars
          VCFS="$@"

          # merges input VCFS, changes tag `REF` to `REF_CN` allowing field to be used in output TSV in future steps
          /opt/bcftools/bin/bcftools merge \
          $VCFS \
          --merge all | \
          sed -e 's/##INFO=<ID=REF,Number=1,Type=Integer,Description="Reference copy number">/##INFO=<ID=REF_CN,Number=1,Type=Integer,Description="Reference copy number">/' \
          -e "s/\(.*;\)\(REF\)\(=[[:digit:]].*\)/\1REF_CN\3/" | \
          /opt/bcftools/bin/bcftools view -O z -o merged.expansion_hunter.vcf.gz

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
            glob: "merged.expansion_hunter.vcf.gz"
