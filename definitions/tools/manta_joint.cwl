#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "Set up and execute manta in joint run mode"

requirements:
    - class: DockerRequirement
      dockerPull: mgibio/manta_somatic-cwl:1.5.0
    - class: InlineJavascriptRequirement
    - class: ShellCommandRequirement
    - class: ResourceRequirement
      coresMin: 12
      ramMin: 24000
      tmpdirMin: 10000
baseCommand: ["/usr/bin/python", "/usr/bin/manta/bin/configManta.py"]
arguments: [
    { position: -1, valueFrom: $(runtime.outdir), prefix: "--runDir" },
    { shellQuote: false, valueFrom: "&&" },
    "/usr/bin/python", "runWorkflow.py", "-m", "local",
    { position: 1, valueFrom: $(runtime.cores), prefix: "-j" }
]
inputs:
    bams:
        type: 
            type: array
            items: File
            inputBinding:
                position: -2
                prefix: "--bam="
                separate: false
        secondaryFiles: ${if (self.nameext === ".bam") {return self.basename + ".bai"} else {return self.basename + ".crai"}}
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            position: -3
            prefix: "--referenceFasta"
    call_regions:
        type: File?
        inputBinding:
            position: -4
            prefix: "--callRegions"
        secondaryFiles: [.tbi]
        doc: bgzip-compressed, tabix-indexed BED file specifiying regions to which variant analysis will be restricted
    output_contigs:
        type: boolean?
        inputBinding:
            position: -5
            prefix: "--outputContig"
        doc: if true, outputs assembled contig sequences in final VCF files, in the INFO field CONTIG
outputs:
    diploid_variants:
        type: File
        outputBinding:
            glob: results/variants/diploidSV.vcf.gz
        secondaryFiles: [.tbi]
    all_candidates:
        type: File
        outputBinding:
            glob: results/variants/candidateSV.vcf.gz
        secondaryFiles: [.tbi]
    small_candidates:
        type: File
        outputBinding:
            glob: results/variants/candidateSmallIndels.vcf.gz
        secondaryFiles: [.tbi]