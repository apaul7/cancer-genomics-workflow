#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "Sort VCF"

baseCommand: ["/usr/bin/java", "-Xmx16g", "-jar", "/opt/picard/picard.jar", "SortVcf"]
requirements:
    - class: ResourceRequirement
      ramMin: 18000
    - class: DockerRequirement
      dockerPull: "broadinstitute/picard:2.23.6"
inputs:
    vcf:
        type: File
        inputBinding:
            prefix: "I="
    reference_dict:
        type: File?
        inputBinding:
            prefix: "SEQUENCE_DICTIONARY="
    output_vcf_name:
        type: string?
        inputBinding:
            prefix: "O="
        default: "sorted.vcf"
outputs:
    sorted_vcf:
        type: File
        outputBinding:
            glob: $(inputs.output_vcf_name)
