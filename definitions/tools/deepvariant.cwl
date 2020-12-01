#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "runs deepvariant"

baseCommand: ["/opt/deepvariant/bin/run_deepvariant", "--num_shards=$(runtime.cores)"]
requirements:
    - class: ResourceRequirement
      ramMin: 10000
    - class: DockerRequirement
      dockerPull: "google/deepvariant:1.0.0"

arguments: ["--output_gvcf", "$(output_base).g.vcf.gz", "--output_vcf", "$(output_base).vcf.gz"]
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
        inputBinding:
            position: 1
            prefix: "--ref"
        doc: "Genome reference to use. Must have an associated FAI index as well. Supports text or gzipped references. Should match the reference used to align the BAM file provided to --reads."
    bam:
        type: File
        secondaryFiles: [^.bai]
        inputBinding:
            position: 2
            prefix: "--reads"
        doc: "Required. Aligned, sorted, indexed BAM file containing the reads we want to call. Should be aligned to a reference genome compatible with --ref."
    model_type:
        type:
            type: enum
            symbols: ['WGS', 'WES', 'PACBIO', 'HYBRID_PACBIO_ILLUMINA']
        inputBinding:
            position: 3
            prefix: "--model_type"
        doc: "<WGS|WES|PACBIO|HYBRID_PACBIO_ILLUMINA>: Required. Type of model to use for variant calling. Each model_type has an associated default model, which can be overridden by the --customized_model flag"
    output_base:
        type: string?

outputs:
    gvcf:
        type: File
        outputBinding:
            glob: "$(inputs.output_base).g.vcf.gz"
    vcf:
        type: File
        outputBinding:
            glob: "$(inputs.output_base).vcf.gz"
