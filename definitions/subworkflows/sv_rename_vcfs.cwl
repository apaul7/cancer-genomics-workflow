#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "sv caller vcf sample and file renamer, to be used in future merging step"
inputs:
    vcf:
        type: File
        secondaryFiles: [.tbi]
    sv_caller:
        type: string
    sample:
        type: string
outputs:
    renamed_vcf:
        outputSource: index/indexed_vcf
        type: File
        secondaryFiles: [.tbi]
steps:
    rename_sample:
        run: ../tools/bcftools_reheader_unsafe.cwl
        in:
            input_vcf: vcf
            sample_name: sample
            output_type:
                default: "z"
            output_vcf_name:
                source: [sv_caller, sample]
                valueFrom: |
                  ${
                    var caller = self[0];
                    var sample = self[1];
                    return sample + "-" + caller + ".vcf.gz";
                  }
        out:
            [renamed_vcf]
    index:
        run: ../tools/index_vcf.cwl
        in:
            vcf: rename_sample/renamed_vcf
        out:
            [indexed_vcf]
