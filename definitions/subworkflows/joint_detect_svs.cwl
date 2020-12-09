#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "jointly run sv callers"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    sample_names:
        type: string[]
    bams:
        type: File[]
        secondaryFiles: [^.bai]
    cohort_name:
        type: string?
    snps_vcf:
        type: File
        secondaryFiles: [.tbi]
    sv_exclude_regions:
        type: File
    cnvkit_reference_cnn:
        type: File
        doc: "can be a flat reference or reference based on a set of panel of normals"
    filter_del_depth:
        type: double?
        doc: ""
    filter_dup_depth:
        type: double?
        doc: ""
    filter_paired_count:
        type: int?
        doc: ""
    filter_split_count:
        type: int?
        doc: ""
    filter_alt_abundance_percentage:
        type: double?
        doc: ""

    survivor_max_distance:
        type: int
        doc: ""
    survivor_min_calls:
        type: int
        doc: ""
    survivor_same_type:
        type: boolean
        doc: ""
    survivor_same_strand:
        type: boolean
        doc: ""
    survivor_estimate_distance:
        type: boolean
        doc: ""
    survivor_min_size:
        type: int
        doc: ""
    genome_build:
        type: string
    annotsv_annotations:
        type:
            - string
            - Directory

outputs:
    gathered_results:
        type: Directory
        outputSource: gather_all/gathered_directory

steps:
# step: calling SVs
    smoove:
        run: smoove.cwl
        in:
            bams: bams
            cohort_name: cohort_name
            reference: reference
            exclude_regions: sv_exclude_regions
        out:
            [vcf]
    manta:
        run: ../tools/manta.cwl
        in:
            bams: bams
            reference: reference
            output_contigs:
                default: true
        out:
            [diploid_variants, all_candidates, small_candidates, stats]
    cnvkit:
        run: joint_cnvkit.cwl
        in:
            bams: bams
            sample_names: sample_names
            reference_cnn: cnvkit_reference_cnn
            method:
                default: "wgs"
            target_average_size:
                default: 1000
            segment_filter:
                default: "cn"
        out:
            [vcf, cns, cnr]
    cnvnator:
        run: joint_cnvnator.cwl
        in:
            bams: bams
            reference: reference
            sample_names: sample_names 
        out:
            [vcf, root_file, cn_file]

# step: filtering calls
    filter_smoove:
        run: sv_joint_read_caller_filter.cwl
        in:
            reference: reference
            sample_names: sample_names
            bams: bams
            snps_vcf: snps_vcf
            filter_del_depth: filter_del_depth
            filter_dup_depth: filter_dup_depth
            filter_paired_count: filter_paired_count
            filter_split_count: filter_split_count
            filter_alt_abundance_percentage: filter_alt_abundance_percentage
            sv_vcf: smoove/vcf
            vcf_source:
                default: "smoove"
        out:
            [vcf]
    filter_manta:
        run: sv_joint_read_caller_filter.cwl
        in:
            reference: reference
            sample_names: sample_names
            bams: bams
            snps_vcf: snps_vcf
            filter_del_depth: filter_del_depth
            filter_dup_depth: filter_dup_depth
            filter_paired_count: filter_paired_count
            filter_split_count: filter_split_count
            filter_alt_abundance_percentage: filter_alt_abundance_percentage
            sv_vcf: manta/diploid_variants
            vcf_source:
                default: "manta"
        out:
            [vcf]
    filter_cnvkit:
        scatter: [bam, output_vcf_name, sample_name, sv_vcf]
        scatterMethod: dotproduct
        run: sv_joint_depth_caller_filter.cwl
        in:
            bam: bams
            deletion_depth: filter_del_depth
            duplication_depth: filter_dup_depth
            min_sv_size:
                default: 1
            output_vcf_name:
                source: [sample_names]
                valueFrom: |
                    ${
                      var sample = inputs.sample_name;
                      var caller = inputs.vcf_source;
                      var vcf_name = sample + "-" + caller  + ".vcf";
                      return vcf_name;
                    }
            reference: reference
            sample_name: sample_names
            snps_vcf: snps_vcf
            sv_vcf: cnvkit/vcf
            vcf_source:
                default: "cnvkit"
        out:
            [vcf]
    filter_cnvnator:
        scatter: [bam, output_vcf_name, sample_name, sv_vcf]
        scatterMethod: dotproduct
        run: sv_joint_depth_caller_filter.cwl
        in:
            bam: bams
            deletion_depth: filter_del_depth
            duplication_depth: filter_dup_depth
            min_sv_size:
                default: 1
            output_vcf_name:
                source: [sample_names]
                valueFrom: |
                    ${
                      var sample = inputs.sample_name;
                      var caller = inputs.vcf_source;
                      var vcf_name = sample + "-" + caller + ".vcf";
                      return vcf_name;
                    }
            reference: reference
            sample_name: sample_names
            snps_vcf: snps_vcf
            sv_vcf: cnvnator/vcf
            vcf_source:
                default: "cnvnator"
        out:
            [vcf]

# step: merging calls
    merge_calls:
        run: joint_merge_sv_calls.cwl
        in:
            vcfs:
                source: [filter_manta/vcf, filter_smoove/vcf, filter_cnvkit/vcf, filter_cnvnator/vcf]
                linkMerge: merge_flattened
            survivor_max_distance: survivor_max_distance
            survivor_min_calls: survivor_min_calls
            survivor_same_type: survivor_same_type
            survivor_same_strand: survivor_same_strand
            survivor_estimate_distance: survivor_estimate_distance
            survivor_min_size: survivor_min_size
        out:
            [survivor, bcftools]
# add family/cohort name to output vcf names?

# step: annotating, filtering, tsv generation
    annotate_survivor:
        run: sv_annotation_and_filter.cwl
        in:
            sv_vcf: merge_calls/survivor
            snps_vcf: snps_vcf
            tsv_base:
                source: [cohort_name]
                valueFrom: "$(self)-survivor-merged"
            genome_build: genome_build
            annotsv_annotations: annotsv_annotations
        out:
            [tsv, unannotated_tsv, filtered_tsv, filtered_tsv_no_CDS]
    annotate_bcftools:
        run: sv_annotation_and_filter.cwl
        in:
            sv_vcf: merge_calls/bcftools
            snps_vcf: snps_vcf
            tsv_base:
                default: "bcftools-merged"
## add family/cohort name?
            genome_build: genome_build
            annotsv_annotations: annotsv_annotations
        out:
            [tsv, unannotated_tsv, filtered_tsv, filtered_tsv_no_CDS]
    gather_smoove:
        run: ../tools/gather_to_sub_directory.cwl
        in:
            outdir:
                default: "smoove"
            file: smoove/vcf
        out:
            [gathered_directory]
    gather_manta:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "manta"
            files:
                source: [manta/diploid_variants, manta/all_candidates, manta/small_candidates]
                linkMerge: merge_flattened
            directory: manta/stats
        out:
            [gathered_directory]
    gather_cnvkit:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "cnvkit"
            files:
                source: [cnvkit/vcf, cnvkit/cns, cnvkit/cnr]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
    gather_cnvnator:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "cnvnator"
            files:
                source: [cnvnator/vcf, cnvnator/root_file, cnvnator/cn_file]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
    gather_raw:
        run: ../tools/gather_to_sub_directory_dirs.cwl
        in:
            outdir:
                default: "raw"
            directories: 
                source: [gather_smoove/gathered_directory, gather_manta/gathered_directory, gather_cnvnator/gathered_directory, gather_cnvkit/gathered_directory]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
    gather_filtered:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "filtered"
            files:
                source: [filter_smoove/vcf, filter_manta/vcf, filter_cnvkit/vcf, filter_cnvnator/vcf]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
    gather_merged:
        run: ../tools/gather_to_sub_directory_files.cwl
        in:
            outdir:
                default: "merged"
            files:
                source: [merge_calls/survivor, merge_calls/bcftools, annotate_survivor/tsv, annotate_survivor/unannotated_tsv, annotate_survivor/filtered_tsv, annotate_survivor/filtered_tsv_no_CDS, annotate_bcftools/tsv, annotate_bcftools/unannotated_tsv, annotate_bcftools/filtered_tsv, annotate_bcftools/filtered_tsv_no_CDS]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
    gather_all:
        run: ../tools/gather_to_sub_directory_dirs.cwl
        in:
            outdir:
                default: "SV_pipeline"
            directories:
                source: [gather_raw/gathered_directory, gather_filtered/gathered_directory, gather_merged/gathered_directory]
                linkMerge: merge_flattened
        out:
            [gathered_directory]
