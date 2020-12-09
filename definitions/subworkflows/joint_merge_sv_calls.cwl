#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: Workflow
label: "subworkflow for merging sv events from multiple callers"
requirements:
    - class: SubworkflowFeatureRequirement
    - class: ScatterFeatureRequirement
inputs:
    vcfs:
        type: File[]
        secondaryFiles: [.tbi]
    survivor_max_distance:
        type: int
    survivor_min_calls:
        type: int
    survivor_same_type:
        type: boolean
    survivor_same_strand:
        type: boolean
    survivor_estimate_distance:
        type: boolean
    survivor_min_size:
        type: int
outputs:
    survivor:
        type: File
        outputSource: survivor_bgzip/bgzipped_file
    bcftools:
        type: File
        outputSource: bcftools_merge/merged_sv_vcf
# tbi?
steps:
    survivor_merge:
        run: ../tools/survivor.cwl
        in:
            vcfs:
                source: [vcfs]
                valueFrom: | #grouped by samples smoove,manta,cnvnator,cnvkit calls
                    ${
                        return self.sort(function(a, b){return a.basename > b.basename}).reverse()
                    }
            max_distance_to_merge: survivor_max_distance
            minimum_sv_calls: survivor_min_calls
            same_type: survivor_same_type
            same_strand: survivor_same_strand
            estimate_sv_distance: survivor_estimate_distance
            minimum_sv_size: survivor_min_size
            output_name:
                default: "survivor-merged.vcf"
        out:
            [merged_vcf]
    survivor_bgzip:
        run: ../tools/bgzip.cwl
        in:
            file: survivor_merge/merged_vcf
        out:
            [bgzipped_file]
    bcftools_merge:
        run: ../tools/bcftools_merge.cwl
        in:
            merge_method:
                default: "none"
            output_type:
                default: "z"
            output_vcf_name:
                default: "bcftools-merged.vcf.gz"
            vcfs:
                source: [vcfs]
                valueFrom: | #grouped by samples smoove,manta,cnvnator,cnvkit calls
                    ${
                        return self.sort(function(a, b){return a.basename > b.basename}).reverse()
                    }
        out:
            [merged_sv_vcf]
    
