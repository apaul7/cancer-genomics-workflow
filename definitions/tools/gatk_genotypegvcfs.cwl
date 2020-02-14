#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "GATK HaplotypeCaller"
baseCommand: ["/usr/bin/java", "-Xmx8g", "-jar", "/opt/GenomeAnalysisTK.jar", "-T", "GenotypeGVCFs"]
requirements:
    - class: ResourceRequirement
      ramMin: 9000
    - class: InlineJavascriptRequirement
    - class: DockerRequirement
      dockerPull: "mgibio/gatk-cwl:3.5.0"
arguments:
    ["-o", 'genotype.vcf.gz']
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            prefix: "-R"
            position: 1
    gvcfs:
        type:
            type: array
            items: File
            inputBinding:
                prefix: "--variant"
        inputBinding:
            position: 2
    standard_call_confidence:
        type: int?
        inputBinding:
            prefix: "--standard_min_confidence_threshold_for_calling"
    standard_emit_confidence:
        type: int?
        inputBinding:
            prefix: "--standard_min_confidence_threshold_for_emitting"
    pedigree:
        type: File?
        inputBinding:
            prefix: "--pedigree"
    pedigree_validation_type:
        type:
            - "null"
            - type: enum
              symbols: ["STRICT", "SILENT"]
        inputBinding:
            prefix: "--pedigreeValidationType"
outputs:
    genotype_vcf:
        type: File
        outputBinding:
            glob: "genotype.vcf.gz"
        secondaryFiles: [.tbi]
