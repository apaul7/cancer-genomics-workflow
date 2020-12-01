#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "runs deepvariant merge from multiple gvcf files, producing a compressed vcf"

baseCommand: ["/usr/local/bin/glnexus_cli", "--threads", "$(runtime.cores)"]
requirements:
    - class: ResourceRequirement
      ramMin: 10000
    - class: DockerRequirement
      dockerPull: "quay.io/mlin/glnexus:v1.2.7"

arguments: [{ shellQuote: false, valueFrom: "|" }, "/usr/bin/bcftools", "view", "-", { shellQuote: false, valueFrom: "|" }, "/usr/bin/bgzip", "-c"]

stdout: "$(inputs.output_name)"
inputs:
    gvcfs:
        type: File[]
        inputBinding:
            position: -1
    config:
        type:
            type: enum
            symbols: ['gatk', 'gatk_unfiltered', 'xAtlas', 'xAtlas_unfiltered', 'weCall', 'weCall_unfiltered', 'DeepVariant', 'DeepVariantWGS', 'DeepVariantWES', 'DeepVariant_unfiltered', 'Strelka2']
        inputBinding:
            position: -2
            prefix: "--config"
    output_name:
        type: string?
        default: "cohort.deepvariant.vcf.gz"
outputs:
    vcf:
        type: stdout
