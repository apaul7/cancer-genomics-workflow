#! /usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool

requirements:
    - class: ShellCommandRequirement
    - class: DockerRequirement
      dockerPull: "ubuntu:xenial"
    - class: ResourceRequirement
      ramMin: 4000

arguments: ["mkdir", "$(inputs.output_dir)", { shellQuote: false, valueFrom: "&&" }, "/bin/cp", "--archive", "--target-directory"]

inputs:
    output_dir:
        type: string
        inputBinding:
            position: 1
    all_files:
        type: File[]
        inputBinding:
            position: 2
    all_array_files:
        type:
            - 'null'
            - type: array
              items:
                  type: array
                  items: File
        inputBinding:
            position: 3
    all_directories:
        type: Directory[]?
        inputBinding:
            position: 4
outputs:
    gathered_files:
        type: Directory
        outputBinding:
            glob: "$(inputs.output_dir)"
