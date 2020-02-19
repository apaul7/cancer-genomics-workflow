#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "Subworkflow to use different SV callers in joint/single mode depending on the tool called"

requirements:
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
    - class: SubworkflowFeatureRequirement

inputs:
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

    cnvkit_diagram:
        type: boolean?
    cnvkit_drop_low_coverage:
        type: boolean?
    cnvkit_method:
        type: string?
    cnvkit_reference_cnn:
        type: File
    cnvkit_scatter_plot:
        type: boolean?
    cnvkit_male_reference:
        type: boolean?
    cnvkit_vcf_name:
        type: string?

    manta_call_regions:
        type: File?
        secondaryFiles: [.tbi]
    manta_output_contigs:
        type: boolean?
        default: true

    merge_max_distance:
        type: int
    merge_min_svs:
        type: int
    merge_same_type:
        type: boolean
    merge_same_strand:
        type: boolean
    merge_estimate_sv_distance:
        type: boolean
    merge_min_sv_size:
        type: int

    smoove_exclude_regions:
        type: File?
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

outputs: []
steps:
    run_joint_smoove:
        run: ../tools/smoove.cwl
        in:
            bams: bams
            exclude_regions: smoove_exclude_regions
            reference: reference
        out:
            [output_vcf]
    run_joint_manta:
        run: ../tools/manta_joint.cwl
        in:
            bams: bams
            reference: reference
            output_contigs: manta_output_contigs
        out:
            [diploid_variants, all_candidates, small_candidates]
    run_cnvnator:
        scatter: [bam, sample_name]
        scatterMethod: dotproduct
        run: ../tools/cnvnator.cwl
        in:
            bam: bams
            reference: reference
            sample_name:
                source: sample_names
                valueFrom: |
                  ${
                    return self + "-cnvnator";
                  }
        out:
            [vcf, root_file, cn_file]

