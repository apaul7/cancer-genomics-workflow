#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "Filter single sample sv vcf from depth callers(cnvkit/cnvnator)"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: StepInputExpressionRequirement
    - class: InlineJavascriptRequirement
inputs:
    bam:
        type: File
        secondaryFiles: [^.bai]
    deletion_depth:
        type: double?
    duplication_depth:
        type: double?
    min_sv_size:
        type: int?
    output_vcf_name:
        type: string?
    reference:
        type:
            - string
            - File
        secondaryFiles: [.fai, ^.dict]
    sample_name:
        type: string
    snps_vcf:
        type: File
        secondaryFiles: [.tbi]
    sv_vcf:
        type: File
    vcf_source:
        type:
          - type: enum
            symbols: ["cnvkit", "cnvnator"]
outputs:
    vcf:
        type: File
        outputSource: bgzip_and_index/indexed_vcf
        secondaryFiles: [.tbi]
steps:
# rename?
    merge_calls:
        run: ../tools/custom_merge_sv_records.cwl
        in:
            input_vcf: sv_vcf
            distance:
                default: 1000
        out:
            [vcf]
    size_filter:
        run: ../tools/filter_sv_vcf_size.cwl
        in:
            input_vcf: merge_calls/vcf
            size_method:
                default: "min_len"
            sv_size: min_sv_size
        out:
            [filtered_sv_vcf]
    duphold:
        run: ../tools/duphold.cwl
        in:
            bam: bam
            reference: reference
            snps_vcf: snps_vcf
            sv_vcf: size_filter/filtered_sv_vcf
        out:
            [annotated_sv_vcf] 
    depth_filter:
        run: ../tools/filter_sv_vcf_depth.cwl
        in:
            input_vcf: duphold/annotated_sv_vcf
            deletion_depth: deletion_depth
            duplication_depth: duplication_depth
            output_vcf_name: output_vcf_name
            vcf_source:
                default: "duphold"
        out:
            [vcf]
    rename:
        run: ../tools/replace_vcf_sample_name.cwl
        in:
            input_vcf: depth_filter/vcf
            sample_to_replace: sample_name
            vcf_source: vcf_source
            new_sample_name:
                source: [sample_name]
                valueFrom: |
                    ${
                      var sample = self;
                      var caller = inputs.vcf_source;
                      var result = sample + "-" + caller;
                      return result;
                    }
        out:
            [renamed_vcf]
    bgzip_and_index:
        run: bgzip_and_index.cwl
        in:
            vcf: rename/renamed_vcf
        out: [indexed_vcf]
