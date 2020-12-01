#! /usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
baseCommand: ["/bin/bash","directory_gatherer.sh"]

requirements:
    - class: DockerRequirement
      dockerPull: "ubuntu:xenial"
    - class: ResourceRequirement
      ramMin: 1000
    - class: InitialWorkDirRequirement
      listing:
      - entryname: 'directory_gatherer.sh'
        entry: |
            set -eou pipefail

            outdir="$1"
            files="${@:2}"
            mkdir $outdir
            chmod -R 777 $outdir
            cp --recursive --preserve --target-directory $outdir $files

            exit 0

inputs:
    outdir:
        type: string
        inputBinding:
            position: 1
    files:
        type: File[]?
        inputBinding:
            position: 2
    directories:
        type: Directory[]?
        inputBinding:
            position: 3
    directory:
        type: Directory?
        inputBinding:
            position: 4
    file:
        type: File?
        inputBinding:
            position: 5
outputs:
    gathered_directory:
        type: Directory
        outputBinding:
            glob: "$(inputs.outdir)"

