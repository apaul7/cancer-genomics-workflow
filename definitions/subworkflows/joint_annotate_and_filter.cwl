#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "variant annotation and filtering"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: SchemaDefRequirement
      types:
          - $import: ../types/vep_custom_annotation.yml
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
inputs:
    vcf:
        type: File
        secondaryFiles: [.tbi]
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    vep_cache_dir:
        type:
            - string
            - Directory
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
        default: [Downstream, Wildtype]
    synonyms_file:
        type: File?
    annotate_coding_only:
        type: boolean?
    vep_custom_annotations:
        type: ../types/vep_custom_annotation.yml#vep_custom_annotation[]
        doc: "custom type, check types directory for input format"
    variants_to_table_fields:
        type: string[]?
        default: ['CHROM','POS','ID','REF','ALT']
    variants_to_table_genotype_fields:
        type: string[]?
    vep_to_table_fields:
        type: string[]?
    filter_gnomAD_maximum_population_allele_frequency:
        type: float
        default: 0.05
outputs:
    annotated_vcf:
        type: File
        outputSource: bgzip_index_annotated_vcf/indexed_vcf
        secondaryFiles: [.tbi]
    vep_summary:
        type: File
        outputSource: annotate_variants/vep_summary
    filtered_vcf:
        type: File
        outputSource: bgzip_index_filtered_vcf/indexed_vcf
        secondaryFiles: [.tbi]
    filtered_tsv:
        type: File
        outputSource: set_filtered_tsv_name/replacement
steps:
    annotate_variants:
        run: ../tools/vep.cwl
        in:
            vcf: vcf
            cache_dir: vep_cache_dir
            ensembl_assembly: vep_ensembl_assembly
            ensembl_version: vep_ensembl_version
            ensembl_species: vep_ensembl_species
            synonyms_file: synonyms_file
            coding_only: annotate_coding_only
            reference: reference
            custom_annotations: vep_custom_annotations
            plugins: vep_plugins
        out:
            [annotated_vcf, vep_summary]
    bgzip_index_annotated_vcf:
        run: bgzip_and_index.cwl
        in:
            vcf: annotate_variants/annotated_vcf
        out:
            [indexed_vcf]
    gnomad_filter:
        run: ../tools/filter_vcf_custom_allele_freq.cwl
        in:
            vcf: bgzip_index_annotated_vcf/indexed_vcf
            maximum_population_allele_frequency: filter_gnomAD_maximum_population_allele_frequency
            field_name:
               source: vep_custom_annotations
               valueFrom: |
                 ${
                    if(self){
                         for(var i=0; i<self.length; i++){
                             if(self[i].annotation.gnomad_filter){
                                 return(self[i].annotation.name + '_AF');
                             }
                         }
                     }
                     return('gnomAD_AF');
                 }
        out:
            [filtered_vcf]
    set_filtered_vcf_name:
        run: ../tools/staged_rename.cwl
        in:
            original: gnomad_filter/filtered_vcf
            name:
                valueFrom: 'annotated.filtered.vcf'
        out:
            [replacement]
    bgzip_index_filtered_vcf:
        run: bgzip_and_index.cwl
        in:
            vcf: set_filtered_vcf_name/replacement
        out:
            [indexed_vcf]



    filtered_variants_to_table:
        run: ../tools/variants_to_table.cwl
        in:
            reference: reference
            vcf: bgzip_index_filtered_vcf/indexed_vcf
            fields: variants_to_table_fields
            genotype_fields: variants_to_table_genotype_fields
        out:
            [variants_tsv]
    filtered_add_vep_fields_to_table:
        run: ../tools/add_vep_fields_to_table.cwl
        in:
            vcf: bgzip_index_filtered_vcf/indexed_vcf
            vep_fields: vep_to_table_fields
            tsv: filtered_variants_to_table/variants_tsv
        out:
            [annotated_variants_tsv]
    set_filtered_tsv_name:
        run: ../tools/staged_rename.cwl
        in:
            original: filtered_add_vep_fields_to_table/annotated_variants_tsv
            name:
                valueFrom: 'annotated.filtered.tsv'
        out:
             [replacement]
