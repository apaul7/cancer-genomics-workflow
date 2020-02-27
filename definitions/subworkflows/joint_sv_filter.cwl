#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "Subworkflow to use filter svs called in the joint subworkflow"

requirements:
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
    - class: SubworkflowFeatureRequirement
    - class: InlineJavascriptRequirement
inputs:
    smoove_vcf:
        type: File
        secondaryFiles: [.tbi]
    manta_vcf:
        type: File
        secondaryFiles: [.tbi]
    cnvkit_vcfs:
        type: File[]
        secondaryFiles: [.tbi]
    cnvnator_vcfs:
        type: File[]
        secondaryFiles: [.tbi]
    bams:
        type: File[]
        secondaryFiles: [.bai,^.bai]
    sample_names:
        type: string[]
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]

    snps_vcf:
        type: File?
    genome_build:
        type: string
    sv_alt_abundance_percentage:
        type: double?
    sv_paired_count:
        type: int?
    sv_split_count:
        type: int?
    cnv_deletion_depth:
        type: double?
    cnv_duplication_depth:
        type: double?
    cnv_filter_min_size:
        type: int?

outputs:
    filtered_cnvnator:
        type: File[]
        outputSource: cnvnator_rename/renamed_vcf
    filtered_cnvkit:
        type: File[]
        outputSource: cnvkit_rename/renamed_vcf
    filtered_manta:
        type: File[]
        outputSource: manta_rename/renamed_vcf
    filtered_smoove:
        type: File[]
        outputSource: smoove_rename/renamed_vcf
steps:
# filter manta/smoove, read pair support
    manta_read_filter:
        run: ../tools/filter_sv_vcf_read_support.cwl
        in:
            input_vcf: manta_vcf
            vcf_source:
                default: "manta"
        out:
            [filtered_sv_vcf]
    smoove_read_filter:
        run: ../tools/filter_sv_vcf_read_support.cwl
        in:
            input_vcf: smoove_vcf
            vcf_source:
                default: "smoove"
        out:
            [filtered_sv_vcf]
# split manta/smoove by sample
    manta_sample_split:
        scatter: [sample]
        scatterMethod: dotproduct
        run: ../tools/bcftools_sample_split.cwl
        in:
            sample: sample_names
            vcf: manta_read_filter/filtered_sv_vcf
        out:
            [single_sample_vcf]
    smoove_sample_split:
        scatter: [sample]
        scatterMethod: dotproduct
        run: ../tools/bcftools_sample_split.cwl
        in:
            sample: sample_names
            vcf: smoove_read_filter/filtered_sv_vcf
        out:
            [single_sample_vcf]
# manta/smoove duphold annotate then read depth filter
    manta_duphold:
        scatter: [bam, sv_vcf]
        scatterMethod: dotproduct
        run: ../tools/duphold.cwl
        in:
            bam: bams
            reference: reference
            sv_vcf: manta_sample_split/single_sample_vcf
        out:
            [annotated_sv_vcf]
    smoove_duphold:
        scatter: [bam, sv_vcf]
        scatterMethod: dotproduct
        run: ../tools/duphold.cwl
        in:
            bam: bams
            reference: reference
            sv_vcf: smoove_sample_split/single_sample_vcf
        out:
            [annotated_sv_vcf]
# manta/smoove depth filter
    manta_depth_filter:
        scatter: [input_vcf]
        scatterMethod: dotproduct
        run: ../tools/filter_sv_vcf_depth.cwl
        in:
            input_vcf: manta_duphold/annotated_sv_vcf
            vcf_source:
                default: "duphold"
        out:
            [filtered_sv_vcf]
    smoove_depth_filter:
        scatter: [input_vcf]
        scatterMethod: dotproduct
        run: ../tools/filter_sv_vcf_depth.cwl
        in:
            input_vcf: smoove_duphold/annotated_sv_vcf
            vcf_source:
                default: "duphold"
        out:
            [filtered_sv_vcf]
# compress/index single sample smoove/manta filtered vcfs
    manta_bgzip_and_index:
        scatter: [vcf]
        scatterMethod: dotproduct
        run: bgzip_and_index.cwl
        in:
            vcf: manta_depth_filter/filtered_sv_vcf
        out:
            [indexed_vcf]
    smoove_bgzip_and_index:
        scatter: [vcf]
        scatterMethod: dotproduct
        run: bgzip_and_index.cwl
        in:
            vcf: smoove_depth_filter/filtered_sv_vcf
        out:
            [indexed_vcf]
# rename manta/smoove
    manta_rename:
        scatter: [vcf, sample]
        scatterMethod: dotproduct
        run: sv_rename_vcfs.cwl
        in:
            vcf: manta_bgzip_and_index/indexed_vcf
            sv_caller:
                default: 'manta'
            sample: sample_names
        out:
            [renamed_vcf]
    smoove_rename:
        scatter: [vcf, sample]
        scatterMethod: dotproduct
        run: sv_rename_vcfs.cwl
        in:
            vcf: smoove_bgzip_and_index/indexed_vcf
            sv_caller:
                default: 'smoove'
            sample: sample_names
        out:
            [renamed_vcf]
# cnvkit/cnvnaator depth filter
    cnvkit_depth_filter:
        scatter: [input_vcf]
        scatterMethod: dotproduct
        run: ../tools/filter_sv_vcf_depth.cwl
        in:
            input_vcf: cnvkit_vcfs
            vcf_source:
                default: "cnvkit"
        out:
            [filtered_sv_vcf]
    cnvnator_depth_filter:
        scatter: [input_vcf]
        scatterMethod: dotproduct
        run: ../tools/filter_sv_vcf_depth.cwl
        in:
            input_vcf: cnvnator_vcfs
            vcf_source:
                default: "cnvnator"
        out:
            [filtered_sv_vcf]
# rename samples and files for merging
    cnvkit_rename:
        scatter: [vcf, sample]
        scatterMethod: dotproduct
        run: sv_rename_vcfs.cwl
        in:
            vcf: cnvkit_depth_filter/filtered_sv_vcf
            sv_caller:
                default: 'cnvkit'
            sample: sample_names
        out:
            [renamed_vcf]
    cnvnator_rename:
        scatter: [vcf, sample]
        scatterMethod: dotproduct
        run: sv_rename_vcfs.cwl
        in:
            vcf: cnvnator_depth_filter/filtered_sv_vcf
            sv_caller:
                default: 'cnvnator'
            sample: sample_names
        out:
            [renamed_vcf]

