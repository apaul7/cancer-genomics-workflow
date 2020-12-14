#!/usr/bin/env cwl-runner

cwlVersion: v1.0
class: CommandLineTool
label: "adds a column per sample sv call counts for AnnotSV tsv output"

baseCommand: ["python3", "annotsv_add_per_sample_counts.py"]

requirements:
    - class: DockerRequirement
      dockerPull: "python:3"
    - class: ResourceRequirement
      ramMin: 4000
    - class: InitialWorkDirRequirement
      listing:
      - entryname: "annotsv_add_per_sample_counts.py"
        entry: |
            import argparse
            import csv
            import sys
            
            def move_header_column(new_index, list, column_name):
                old_index = list.index(column_name)
                list = move_column(new_index, list, old_index)
                delta = (new_index, old_index)
                return list,delta
            def move_column(new_index, list, old_index):
                move_value = list.pop(old_index)
                list.insert(new_index, move_value)
                delta = (new_index, old_index)
                return list
            
            parser = argparse.ArgumentParser()
            parser.add_argument('--input', '-i', dest="input", help='input AnnotSV tsv file', required=True, action="store")
            parser.add_argument('--output', '-o', dest="output", help='output tsv file name', required=True, action="store")
            parser.add_argument('--sample_count', dest="sample_count", help="number of samples in tsv input", action="store", type=int)
            parser.add_argument('--caller_count', dest="caller_count", help="number of callers per sample in tsv input", action="store", type=int)
            
            args = parser.parse_args()
            input_file_name  = args.input
            output_file_name = args.output
            sample_count = args.sample_count
            caller_count = args.caller_count
            
            # get new order:
            file_in = open(input_file_name, 'r')
            file_in_reader = csv.DictReader(file_in, delimiter='\t')
            in_column_names = file_in_reader.fieldnames
            filter_index = in_column_names.index("FILTER") + 1
            
            caller_names = []
            sample_names = []
            
            # column names for callers currently follow $CALLER-$SAMPLE format
            for x in range(filter_index+2, filter_index+2 + sample_count*caller_count):
                name = in_column_names[x]
                split_array = name.split("-")
                num_elements = len(split_array)
                caller = split_array[num_elements-1] # last element

                if not(caller in caller_names):
                    caller_names.append(caller)

                sample = "-".join(split_array[0:(num_elements-1)])
                if not(sample in sample_names):
                    sample_names.append(sample)

            print(caller_names)
            print(sample_names)
            
            # confirm values match expected!
            if(len(caller_names) != caller_count):
                sys.exit("**ERROR** The parsed list of SV callers does not match input value of caller count, {} != {}".format(len(caller_names),caller_count))
            if(len(sample_names) != sample_count):
                sys.exit("**ERROR** The parsed list of unique samples does not match input value of sample count, {} != {}".format(len(sample_names),sample_count))
            
            # add SUPP VEC and sample count columns
            in_column_names.insert(filter_index,"SUPP_VEC")
            in_column_names.insert(filter_index+1,"total_count")
            for sample_index in range(0, sample_count):
                in_column_names.insert(filter_index+2+sample_index, sample_names[sample_index] + "-count")
            for sample_index in range(0, sample_count):
                in_column_names.insert(filter_index+2+sample_index+sample_count, sample_names[sample_index] + "-SUPP_VEC")
            out_column_names = in_column_names
            file_in.close()
            
            with open(input_file_name, 'r') as file_in, open(output_file_name, 'w') as file_out:
                writer = csv.DictWriter(file_out, fieldnames=out_column_names,  delimiter='\t')
                writer.writeheader()
                for row in csv.DictReader(file_in, delimiter='\t'):
                    INFO = row['INFO']
                    INFO_split = INFO.split(";")
                    INFO_dict = {}
                    for field in INFO_split:
                        s = field.split("=")
                        INFO_dict[s[0]] = field.replace(s[0]+"=","")
                    SUPP_VEC = INFO_dict['SUPP_VEC']
                    row['SUPP_VEC'] = "'" + SUPP_VEC + "'"
                    SUPP_VEC_SAMPLES = [(SUPP_VEC[i:i+caller_count]) for i in range(0, len(SUPP_VEC), caller_count)]
                    TOTAL_COUNT = 0
                    for index in range(0, sample_count):
                        supp = SUPP_VEC_SAMPLES[index]
                        row[sample_names[index] + "-SUPP_VEC"] = "'" + supp + "'"
                        # converts string characters to ints, makes a list, sums over that list
                        count = sum(list(map(int, supp)))
                        row[sample_names[index] + "-count"] = count
                        TOTAL_COUNT = TOTAL_COUNT + count
                    row["total_count"] = TOTAL_COUNT
                    writer.writerow(row)
                file_in.close()
                file_out.close()
            print("finished")


inputs:
    sample_count:
        type: int
        inputBinding:
            position: 1
            prefix: "--sample_count"
    caller_count:
        type: int
        inputBinding:
            position: 2
            prefix: "--caller_count"
    annotsv_tsv:
        type: File
        inputBinding:
            position: 2
            prefix: "--input"
    output_name:
        type: string?
        default: "AnnotSV.sample_counts.tsv"
        inputBinding:
            position: 5
            prefix: "--output"

outputs:
    tsv:
        type: File
        outputBinding:
            glob: $(inputs.output_name)
