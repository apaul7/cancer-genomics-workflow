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
          LEN="${#@}"
          # if more than 1 vcf merge, then change tag `REF` to `REF_CN` allowing field to be used in output TSV in future steps
          if [ $LEN == "1" ]; then
              /opt/bcftools/bin/bcftools view $VCFS | \
              sed -e 's/##INFO=<ID=REF,Number=1,Type=Integer,Description="Reference copy number">/##INFO=<ID=REF_CN,Number=1,Type=Integer,Description="Reference copy number">/' \
              -e "s/\(.*;\)\(REF\)\(=[[:digit:]].*\)/\1REF_CN\3/" | \
              /opt/bcftools/bin/bcftools view -O z -o merged.expansion_hunter.vcf.gz
          else
              /opt/bcftools/bin/bcftools merge $VCFS --merge all | \
              sed -e 's/##INFO=<ID=REF,Number=1,Type=Integer,Description="Reference copy number">/##INFO=<ID=REF_CN,Number=1,Type=Integer,Description="Reference copy number">/' \
              -e "s/\(.*;\)\(REF\)\(=[[:digit:]].*\)/\1REF_CN\3/" | \
              /opt/bcftools/bin/bcftools view -O z -o merged.expansion_hunter.vcf.gz
          fi

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
