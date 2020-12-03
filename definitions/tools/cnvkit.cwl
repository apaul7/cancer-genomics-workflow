#! /usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
baseCommand: ["/bin/bash", "run_cnvkit.sh"]
requirements:
    - class: DockerRequirement
      dockerPull: "etal/cnvkit:0.9.5"
    - class: ResourceRequirement
      coresMin: 1
      ramMin: 4000
      tmpdirMin: 10000
    - class: InitialWorkDirRequirement
      listing:
      - entryname: "run_cnvkit.sh"
        entry: |
          #!/bin/bash
          set -eou pipefail

          # set vars
          BAM="$1"
          SAMPLE="$2"
          REFERENCE_CNN="$3"
          METHOD="$4"
          FILTER="$5"
          IN_BASENAME="$(basename $BAM)"
          BASE="$(IN_BASENAME%.*)"

          /usr/bin/python /usr/local/bin/cnvkit.py \
          batch $BAM \
          -m $METHOD \
          --reference $REFERENCE_CNN

          /usr/bin/python /usr/local/bin/cnvkit.py call \
          $BASE.cns -o $SAMPLE.call.cns \
          --filter $FILTER

          /usr/bin/python /usr/local/bin/cnvkit.py export vcf \
          $SAMPLE.call.cns -i $SAMPLE \
          -o $SAMPLE.cnvkit.vcf


inputs:
    bam:
        type: File
        inputBinding:
            position: 1
    sample:
        type: string
        inputBinding:
            position: 2
    reference_cnn:
        type: File
        inputBinding:
            position: 3
        doc: "can be a flat reference or  based on a set of panel of normals"
    method:
        type:
            type: enum
            symbols: ["hybrid", "amplicon", "wgs"]
        inputBinding:
            position: 4
        doc: "Sequencing protocol used for input data"
    segment_filter:
        type:
            type: enum
            symbols: ["ampdel", "ci", "cn", "sem"]
        inputBinding:
            position: 5
outputs:
    vcf:
        type: File
        outputBinding:
            glob: "$(inputs.sample).cnvkit.vcf"
    cns:
        type: File
        outputBinding:
            glob: "$(inputs.sample).call.cns"
    cnr:
        type: File
        outputBinding:
            glob: "$(inputs.sample).cnr"
