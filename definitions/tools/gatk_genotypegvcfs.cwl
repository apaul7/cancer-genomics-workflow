#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "GATK GenotypeGVCFs"
baseCommand: ["/usr/bin/java", "-Xmx8g", "-jar", "/opt/GenomeAnalysisTK.jar", "-T", "GenotypeGVCFs"]
requirements:
    - class: ResourceRequirement
      ramMin: 16000
    - class: InlineJavascriptRequirement
    - class: DockerRequirement
      dockerPull: "mgibio/gatk-cwl:3.5.0"
arguments:
    ["-o", "genotype.vcf.gz"]
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
        type: File
        inputBinding:
            position: 2
            prefix: "--variant"
    intervals:
        type:
            type: array
            items: string
            inputBinding:
                prefix: "-L"
        inputBinding:
            position: 3
    min_conf_emit_threshold:
        type: int?
        doc: 'The minimum phred-scaled confidence threshold at which variants should be emitted(and filtered with LowQual if less than the calling threshold)'
        inputBinding:
            prefix: '--standard_min_confidence_threshold_for_emitting'
            position: 4
    min_conf_call_threshold:
        type: int?
        doc: 'The minimum phred-scaled confidence threshold at which variants should be called'
        inputBinding:
            prefix: '--standard_min_confidence_threshold_for_calling'
            position: 5
outputs:
    genotype_vcf:
        type: File
        outputBinding:
            glob: "genotype.vcf.gz"
        secondaryFiles: [.tbi]
