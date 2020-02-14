#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "run vt uniq"
baseCommand: ["vt", "uniq"]
requirements:
    - class: DockerRequirement
      dockerPull: quay.io/biocontainers/vt:0.57721--hf74b74d_1
    - class: ResourceRequirement
      ramMin: 4000
arguments:
    ["-o", { valueFrom: $(runtime.outdir)/vt.uniq.vcf.gz }]
inputs:
    vcf:
        type: File
        inputBinding:
            position: 1
        secondaryFiles: [".tbi"]
outputs:
    uniq_vcf:
        type: File
        outputBinding:
            glob: "vt.uniq.vcf.gz"
