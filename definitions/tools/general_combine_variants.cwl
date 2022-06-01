#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "CombineVariants (GATK 3.6)"
baseCommand: ["/usr/bin/java", "-Xmx8g", "-jar", "/opt/GenomeAnalysisTK.jar", "-T", "CombineVariants"]
requirements:
    - class: ResourceRequirement
      ramMin: 9000
      tmpdirMin: 25000
    - class: DockerRequirement
      dockerPull: mgibio/gatk-cwl:3.6.0
arguments:
    ["-genotypeMergeOptions", "PRIORITIZE",
     "-o", { valueFrom: $(runtime.outdir)/combined.vcf.gz }]
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            prefix: "-R"
            position: 1
    rod_priority_list:
        type: string[]
        inputBinding:
            prefix: "--rod_priority_list"
            itemSeparator: ","
            position: 2
    mutect_vcf:
        type: File?
        inputBinding:
            prefix: "--variant:mutect"
            position: 3
        secondaryFiles: [.tbi]
    varscan_vcf:
        type: File?
        inputBinding:
            prefix: "--variant:varscan"
            position: 4
        secondaryFiles: [.tbi]
    strelka_vcf:
        type: File?
        inputBinding:
            prefix: "--variant:strelka"
            position: 5
        secondaryFiles: [.tbi]
    pindel_vcf:
        type: File?
        inputBinding:
            prefix: "--variant:pindel"
            position: 6
        secondaryFiles: [.tbi]
    docm_vcf:
        type: File?
        inputBinding:
            prefix: "--variant:docm"
            position: 7
        secondaryFiles: [.tbi]
outputs:
    combined_vcf:
        type: File
        outputBinding:
            glob: "combined.vcf.gz"

