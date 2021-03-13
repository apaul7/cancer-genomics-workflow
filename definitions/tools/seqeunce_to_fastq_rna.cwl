#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool
label: "Picard: BAM to FASTQ"
baseCommand: ["/bin/bash makefastqs.sh"]
requirements:
    - class: ResourceRequirement
      coresMin: 1
      ramMin: 6000
      tmpdirMin: 25000
    - class: DockerRequirement
      dockerPull: "mgibio/rnaseq:1.0.0"
    - entryname: 'makefastqs.sh'
        entry: |
            set -o pipefail
            set -o errexit
            set -o nounset
            while getopts "b:?1:?2:n" opt; do
                case "$opt" in
                    b)
                        BAM="$OPTARG"
                        ;;
                    1)
                        FASTQ1="$OPTARG"
                        ;;
                    2)  
                        FASTQ2="$OPTARG"
                        ;;
                    n)
                        OUTDIR="$OPTARG"
                        ;;
        if [[ "$BAM" == 'null' ]]; then #must be fastq input
			cp $FASTQ1 $OUTDIR/read.1.fastq.gz
			cp $FASTQ1 $OUTDIR/read.2.fastq.gz
		else; # then
			##run samtofastq here, dumping to the same filenames
			## input file is $BAM
            /usr/bin/java -Xmx4g -jar /opt/picard/picard.jar SamToFastq I="$BAM" INCLUDE_NON_PF_READS=true F=$OUTDIR/read.1.fastq.gz F2=$OUTDIR/read.2.fastq.gz VALIDATION_STRINGENCY=SILENT
		fi
arguments: [
    "-t", "$(runtime.cores)",
    "-b", {valueFrom: "$(self.sequence.hasOwnProperty('bam')? self.sequence.bam : null)"},
    "-1", {valueFrom: "$(self.sequence.hasOwnProperty('fastq1')? self.sequence.fastq1 : null)"},
    "-2", {valueFrom: "$(self.sequence.hasOwnProperty('fastq2')? self.sequence.fastq2 : null)"}
]
inputs:
    sequence:
        type: ../types/sequence_data.yml#sequence_data
        doc: "the unaligned sequence data with readgroup information"
outputs:
    fastq1:
        type: File
        outputBinding:
            glob: "read.1.fastq.gz"
    fastq2:
        type: File
        outputBinding:
            glob: "read.2.fastq.gz"