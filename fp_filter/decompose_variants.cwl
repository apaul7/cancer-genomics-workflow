#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "Decompose variants by splitting multi-allelic sites"
baseCommand: ["vt", "decompose"]
requirements:
    - class: ResourceRequirement
      ramMin: 8000
arguments:
    ["-s",
     "-o", { valueFrom: $(runtime.outdir)/decomposed.vcf.gz }]
inputs:
    vcf:
        type: File
        inputBinding:
            position: 1
        secondaryFiles: [".tbi"]
outputs:
    decomposed_vcf:
        type: File
        outputBinding:
            glob: "decomposed.vcf.gz"
