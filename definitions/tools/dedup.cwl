#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "runs dedup reads from umitools"

baseCommand: ["/usr/local/bin/umi_tools", "dedup"]

requirements:
    - class: ResourceRequirement
      ramMin: 50000
    - class: DockerRequirement
      dockerPull: "apaul7/analysis:1.1.0"

arguments: ["-S", "final.dedup.bam", "--output-stats", "dedup"]

inputs:
    bam:
        type: File
        secondaryFiles: ${if (self.nameext === ".bam") {return self.basename + ".bai"} else {return self.basename + ".crai"}}
        inputBinding:
            position: 1
            prefix: "-I"
        doc: "indexed input bam/cram file"
    umi_separator:
        type: string
        inputBinding:
            position: 2
            prefix: "--umi-separator"
        doc: "separator between read id and UMI"
    umi_source: 
        type: string
        inputBinding:
            position: 3
            prefix: "--extract-umi-method"
        doc: "how is the read UMI +/ cell barcode encoded?"

outputs:
    stats_edit_distance:
        type: File
        outputBinding:
            glob: "dedup_edit_distance.tsv"
    stats_per_umi:
        type: File
        outputBinding:
            glob: "dedup_per_umi.tsv"
    stats_per_umi_per_position:
        type: File
        outputBinding:
            glob: "dedup_per_umi_per_position.tsv"
    dedup_bam:
        type: File
        outputBinding:
            glob: "final.dedup.bam"
