#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "GATK CombineGVCFs"
baseCommand: ["/usr/bin/java", "-Xmx10g", "-jar", "/opt/GenomeAnalysisTK.jar", "-T", "CombineGVCFs"]
requirements:
    - class: ResourceRequirement
      ramMin: 12000
    - class: InlineJavascriptRequirement
    - class: DockerRequirement
      dockerPull: "mgibio/gatk-cwl:3.5.0" 
arguments:
    ["-o", "merged.g.vcf.gz"]
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            prefix: "-R"
            position: 1
    intervals:
        type:
            type: array
            items: string
            inputBinding:
                prefix: "-L"
        inputBinding:
            position: 2
    gvcfs:
        type:
            type: array
            items: File
            inputBinding:
                prefix: "--variant"
        inputBinding:
            position: 3
outputs:
    merged_gvcf:
        type: File
        outputBinding:
            glob: "merged.g.vcf.gz"
        secondaryFiles: [.tbi]
