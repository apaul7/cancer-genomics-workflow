#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run deepvariant"
requirements:
    - class: ScatterFeatureRequirement
inputs:
    bams:
        type: File[]
        secondaryFiles: [^.bai]
    sample_names:
        type: string[]
    cohort_name:
        type: string
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    deepvariant_model_type:
        type:
            type: enum
            symbols: ['gatk', 'gatk_unfiltered', 'xAtlas', 'xAtlas_unfiltered', 'weCall', 'weCall_unfiltered', 'DeepVariant', 'DeepVariantWGS', 'DeepVariantWES', 'DeepVariant_unfiltered', 'Strelka2']
    merge_config:
        type:
            type: enum
            symbols: ['WGS', 'WES', 'PACBIO', 'HYBRID_PACBIO_ILLUMINA']
outputs:
    merged_vcf:
        type: File
        outputSource: index_merged/indexed_vcf
        secondaryFiles: [.tbi]
    deepvariant_vcfs:
        type: File[]
        outputSource: index/indexed_vcf
        secondaryFiles: [.tbi]
    deepvariant_gvcfs:
        type: File[]
        outputSource: deepvariant/gvcf
steps:
    deepvariant:
        scatter: [bam, output_base]
        scatterMethod: dotproduct
        run: ../tools/deepvariant.cwl
        in:
            bam: bams
            model_type: deepvariant_model_type
            reference: reference
            output_base: 
                source: [sample_names]
                valueFrom: "$(self).deepvariant"
        out:
            [gvcf, vcf]
    index:
        scatter: [vcf]
        run: ../tools/index_vcf.cwl
        in:
            vcf: deepvariant/vcf
        out:
            [indexed_vcf]
    deepvariant_merge:
        run: ../tools/deepvariant_merge.cwl
        in:
            gvcfs: deepvariant/gvcf
            config: merge_config
            output_name:
                source: [cohort_name]
                valueFrom: '$(self).merged.deepvariant.vcf.gz'
        out:
            [vcf]
    index_merged:
        run: ../tools/index_vcf.cwl
        in:
            vcf: deepvariant_merge/vcf
        out:
            [indexed_vcf]
