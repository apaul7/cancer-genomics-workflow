#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "filter for rare indels"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
    - class: SchemaDefRequirement
      types:
          - $import: ../types/vep_custom_annotation.yml
inputs:
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    in_vcf:
        type: File
        secondaryFiles: [.tbi]
    vep_cache_dir:
        type:
            - string
            - Directory
    synonyms_file:
        type: File?
    vep_custom_annotations:
        type: ../types/vep_custom_annotation.yml#vep_custom_annotation[]
        doc: "custom type, check types directory for input format"
    vep_ensembl_assembly:
        type: string
        doc: "genome assembly to use in vep. Examples: GRCh38 or GRCm38"
    vep_ensembl_version:
        type: string
        doc: "ensembl version - Must be present in the cache directory. Example: 95"
    vep_ensembl_species:
        type: string
        doc: "ensembl species - Must be present in the cache directory. Examples: homo_sapiens or mus_musculus"
    vep_plugins:
        type: string[]
    vep_tsv_fields:
        type: string[]

outputs:
    vcf:
        type: File
        secondaryFiles: [.tbi]
        outputSource: bgzip_index_filter/indexed_vcf
    tsv:
        type: File
        outputSource: add_vep_fields/annotated_variants_tsv

steps:
    get_indels:
        run: ../tools/bcftools_view.cwl
        in:
            output_vcf_name:
                default: "indels.vcf.gz"
            variant_type:
                default: "indels"
            in_vcf: in_vcf
        out:
            [vcf]
    annotate:
        run: ../tools/vep.cwl
        in:
           vcf: get_indels/vcf
           cache_dir: vep_cache_dir
           synonyms_file: synonyms_file
           pick:
               default: "flag_pick"
           custom_annotations: vep_custom_annotations
           reference: reference
           plugins: vep_plugins
           ensembl_assembly: vep_ensembl_assembly
           ensembl_version: vep_ensembl_version
           ensembl_species: vep_ensembl_species
        out:
            [annotated_vcf, vep_summary]
    bgzip_index:
        run: bgzip_and_index.cwl
        in:
            vcf: annotate/annotated_vcf
        out:
            [indexed_vcf]
    filter:
        run: ../tools/filter_vcf_splice_indels.cwl
        in:
            vcf: bgzip_index/indexed_vcf
            filtering_frequency:
                default: "0.01"
            field_name:
                default: "gnomADw_AF"
        out:
            [filtered_vcf]
    bgzip_index_filter:
        run: bgzip_and_index.cwl
        in:
            vcf: filter/filtered_vcf
        out:
            [indexed_vcf]
    make_tsv:
        run: ../tools/variants_to_table.cwl
        in:
            reference: reference
            vcf: bgzip_index_filter/indexed_vcf
            fields:
                default: ["CHROM", "POS", "ID", "REF", "ALT"]
            genotype_fields:
                default: ["GT", "AD", "DP"]
        out:
            [variants_tsv]
    add_vep_fields:
        run: ../tools/add_vep_fields_to_table.cwl
        in:
            vcf: bgzip_index_filter/indexed_vcf
            vep_fields: vep_tsv_fields
            tsv: make_tsv/variants_tsv
            prefix:
                default: "indels.annotated.filtered.tsv"
        out:
            [annotated_variants_tsv]
