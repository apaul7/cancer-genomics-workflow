#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "run vt"
baseCommand: ["/bin/bash", "run_vt_normalize.sh"]
requirements:
    - class: DockerRequirement
      dockerPull: quay.io/biocontainers/vt:0.57721--hf74b74d_1
    - class: ResourceRequirement
      ramMin: 4000
    - class: InitialWorkDirRequirement
      listing:
      - entryname: "run_vt_normalize.sh"
        entry: |
          #!/bin/bash
          set -eou pipefail

          VCF="$1"
          REF="$2"
          vt decompose -s $VCF | vt normalize -r $REF - | vt uniq - > combined.all.gt.vt.vcf

inputs:
    vcf:
        type: File
        inputBinding:
            position: 1
        secondaryFiles: [".tbi"]
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai]
        inputBinding:
            position: 2
outputs:
    normalized_vcf:
        type: File
        outputBinding:
            glob: "combined.all.gt.vt.vcf"
