#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "Subworkflow to use different SV callers in joint/single mode depending on the tool called"

requirements:
    - class: ScatterFeatureRequirement
    - class: MultipleInputFeatureRequirement
    - class: SubworkflowFeatureRequirement
    - class: InlineJavascriptRequirement
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
    smoove:
        run: ../tools/smoove.cwl
        in:
            bams: bams
            exclude_regions: smoove_exclude_regions
            reference: reference
        out:
            [output_vcf]
    index_smoove:
        run: ../tools/index_vcf.cwl
        in:
            vcf: smoove/output_vcf
        out:
            [indexed_vcf]
    manta:
        run: ../tools/manta_joint.cwl
        in:
            bams: bams
            reference: reference
            output_contigs: manta_output_contigs
        out:
            [diploid_variants, all_candidates, small_candidates]
    cnvnator:
        scatter: [bam, sample_name]
        scatterMethod: dotproduct
        run: ../tools/cnvnator.cwl
        in:
            bam: bams
            reference: reference
            sample_name: sample_names
        out:
            [vcf, root_file, cn_file]
    cnvkit:
        scatter: [tumor_bam]
        scatterMethod: dotproduct
        run: ../tools/cnvkit_batch.cwl
        in:
            tumor_bam: bams
            target_average_size:
              default: 1000
            method:
              default: 'wgs'
            reference:
              source: reference
              valueFrom: |
                   ${
                     return {'fasta_file': self};
                   }
        out: [tumor_segmented_ratios]
    cnvkit_export:
        scatter: [cns_file, sample_name]
        scatterMethod: dotproduct
        run: ../tools/cnvkit_vcf_export.cwl
        in:
            cns_file: cnvkit/tumor_segmented_ratios
            sample_name: sample_names
            output_name:
                valueFrom: |
                   ${
                     return inputs.sample_name + "-cnvkit.vcf";
                   }
        out: [cnvkit_vcf]
# compress cnvkit/cnvnator
    cnvkit_bgzip_and_index:
        scatter: [vcf]
        scatterMethod: dotproduct
        run: bgzip_and_index.cwl
        in:
            vcf: cnvkit_export/cnvkit_vcf
        out:
            [indexed_vcf]
    cnvnator_bgzip_and_index:
        scatter: [vcf]
        scatterMethod: dotproduct
        run: bgzip_and_index.cwl
        in:
            vcf: cnvnator/vcf
        out:
            [indexed_vcf]
## call filtering subworkflow!
    filter:
        run: joint_sv_filter.cwl
        in:
            smoove_vcf: index_smoove/indexed_vcf
            manta_vcf: manta/diploid_variants
            cnvkit_vcfs: cnvkit_bgzip_and_index/indexed_vcf
            cnvnator_vcfs: cnvnator_bgzip_and_index/indexed_vcf
            bams: bams
            sample_names: sample_names
            reference: reference
            snps_vcf: snps_vcf
            genome_build: genome_build
            sv_alt_abundance_percentage: sv_alt_abundance_percentage
            sv_paired_count: sv_paired_count
            sv_split_count: sv_split_count
            cnv_deletion_depth: cnv_deletion_depth
            cnv_duplication_depth: cnv_duplication_depth
            cnv_filter_min_size: cnv_filter_min_size
        out:
            [filtered_cnvnator, filtered_cnvkit, filtered_manta, filtered_smoove]
    merge:
        run: merge_svs.cwl
        in:
            estimate_sv_distance: merge_estimate_sv_distance
            genome_build: genome_build
            max_distance_to_merge: merge_max_distance
            minimum_sv_calls: merge_min_svs
            minimum_sv_size: merge_min_sv_size
            same_strand: merge_same_strand
            same_type: merge_same_type
            snps_vcf: snps_vcf
            sv_vcfs:
                source: [filter/filtered_cnvnator, filter/filtered_cnvkit, filter/filtered_manta, filter/filtered_smoove]
                linkMerge: merge_flattened
        out:
            [bcftools_sv_vcf, bcftools_annotated_tsv, bcftools_annotated_tsv_filtered, bcftools_annotated_tsv_filtered_no_cds, survivor_sv_vcf, survivor_annotated_tsv, survivor_annotated_tsv_filtered, survivor_annotated_tsv_filtered_no_cds]
