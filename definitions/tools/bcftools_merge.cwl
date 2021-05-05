#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "custom bcftools, merges if multiple inputs, otherwise pass out same vcf"
baseCommand: ["/bin/bash", "run_merge.sh"]

requirements:
    - class: ResourceRequirement
      ramMin: 4000
    - class: DockerRequirement
      dockerPull: "mgibio/bcftools-cwl:1.12"
    - class: InitialWorkDirRequirement
      listing:
      - entryname: "run_merge.sh"
        entry: |-
          #!/bin/bash
          set -eou pipefail
          inputs=\$@
          vcfs=\$(echo \$inputs | tr ' ' '\\n' | grep 'vcf.gz$')
          count=\$(echo \$vcfs | tr ' ' '\\n' | wc -l)
          output_vcf=\$(echo \$vcfs | tr ' ' '\\n' | head -1)
          last_vcf=\$(echo \$vcfs | tr ' ' '\\n' | tail -1)
          if [ \$count == 2 ]; then
              # 1 vcf is output file, 1 vcf input.
              # bcftools merge complains if only 1 sample input. pass input vcf to output vcf
              cp \$last_vcf \$output_vcf
          else
              /opt/bcftools/bin/bcftools merge \$inputs
          fi
          exit 0


inputs:
    force_merge:
        type: boolean?
        default: true
        inputBinding:
            position: 1
            prefix: "--force-samples"
        doc: "resolve duplicate sample names"
    merge_method:
        type:
            type: enum
            symbols: ["none", "snps", "indels", "both", "all", "id"]
        default: "none"
        inputBinding:
            position: 2
            prefix: "--merge"
        doc: "method used to merge allow multiallelic indels/snps"
    missing_ref:
        type: boolean?
        default: false
        inputBinding:
            position: 3
            prefix: "--missing-to-ref"
        doc: "assume genotypes at missing sites are 0/0"
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
        default: "bcftools_merged.vcf.gz"
        inputBinding:
            position: 5
            prefix: "--output"
        doc: "output vcf file name"
    vcfs:
        type: File[]
        inputBinding:
            position: 6
        doc: "input bgzipped tabix indexed vcfs to merge"

outputs:
    merged_sv_vcf:
        type: File
        outputBinding:
            glob: $(inputs.output_vcf_name)

