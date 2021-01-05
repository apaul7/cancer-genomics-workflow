#!/usr/bin/env cwl-runner
 
cwlVersion: v1.0
class: CommandLineTool
label: "Adds an INFO tag (CLE_VALIDATED) flagging variants in the pipeline vcf present in a cle vcf file"

requirements:
    - class: DockerRequirement
      dockerPull: "mgibio/bcftools-cwl:1.9"
    - class: ResourceRequirement
      ramMin: 8000
    - class: InitialWorkDirRequirement
      listing:
      - entryname: 'annotate.sh'
        entry: |
            set -eou pipefail

            PIPELINE_VCF="$1"

            if [ "$#" -eq 2 ]; then
                CLE_VCF="$2"
                /opt/bcftools/bin/bcftools view -f PASS -Oz -o pass_filtered_cle_variants.vcf.gz $CLE_VCF
                /opt/bcftools/bin/bcftools index -t pass_filtered_cle_variants.vcf.gz
                /opt/bcftools/bin/bcftools annotate -Oz -o cle_annotated_pipeline_variants.vcf.gz -a pass_filtered_cle_variants.vcf.gz -m 'CLE_VALIDATED' $PIPELINE_VCF
                /opt/bcftools/bin/bcftools index -t cle_annotated_pipeline_variants.vcf.gz
            elif [ "$#" -eq 1 ]; then
                cp $PIPELINE_VCF cle_annotated_pipeline_variants.vcf.gz
                cp $PIPELINE_VCF.tbi cle_annotated_pipeline_variants.vcf.gz.tbi
            else
                exit 1
            fi

baseCommand: ["/bin/bash", "annotate.sh"]

inputs:
    vcf:
        type: File
        secondaryFiles: [.tbi]
        inputBinding:
            position: 1
        doc: "Each variant in this file that is also in the cle vcf file (if supplied) will be marked with a CLE_VALIDATED flag in its INFO field"
    cle_variants:
        type: File?
        secondaryFiles: [.tbi]
        inputBinding:
            position: 2
        doc: "A vcf of previously discovered variants to be marked in the pipeline vcf; if not provided, this tool does nothing but rename the input vcf"

outputs:
    cle_annotated_vcf:
        type: File
        outputBinding:
            glob: "cle_annotated_pipeline_variants.vcf.gz"
        secondaryFiles: [.tbi]
