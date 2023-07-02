#!/bin/bash

# get input arguments
input_dir=$1
output_dir=$2
compression_type=$3
num_jobs=$4  # number of parallel jobs

# ensure output directory exists
mkdir -p $output_dir

# select compression option based on user input
if [ $compression_type = "zstd" ]; then
    compression='*,32015,3'
elif [ $compression_type = "lz4" ]; then
    compression='*,32004,0'
else
    echo "Unsupported compression type. Please use 'zstd' or 'lz4'."
    exit 1
fi

# parallel or serial processing based on user input
if [ $num_jobs -gt 1 ]; then
    echo "Processing in parallel with $num_jobs jobs..."
    ls $input_dir/*.nc | parallel -j $num_jobs 'nccopy -4 -F '"$compression"' {} '"$output_dir"'/'{/.}'.nc '&&' 'ncdump -h '"$output_dir"'/'{/.}'.nc '>/dev/null 2>&1 || echo "The file '"$output_dir"'/'{/.}'.nc is corrupted."'
else
    echo "Processing serially..."
    for input_file in $input_dir/*.nc
    do
        # extract base file name
        base_file=$(basename $input_file)
        # construct output file path
        output_file="$output_dir/$base_file"

        echo "Compressing $input_file into $output_file with $compression_type compression..."

        # run nccopy with the specified compression
        nccopy -4 -F $compression "$input_file" "$output_file"

        # check the integrity of the compressed file using ncdump
        echo "Checking the integrity of the compressed file..."
        if ncdump -h "$output_file" > /dev/null 2>&1; then
            echo "The file $output_file is not corrupted."
        else
            echo "The file $output_file is corrupted."
            exit 1
        fi

        # get the file sizes in gigabytes and calculate the ratio
        size_input=$(du -b $input_file | awk '{print $1/1073741824}')  # 1GB = 1073741824 bytes
        size_output=$(du -b $output_file | awk '{print $1/1073741824}')
        ratio=$(echo "scale=2; $size_output / $size_input" | bc -l)  # scale=2 for 2 decimal places

        echo "Input file size: $size_input GB"
        echo "Output file size: $size_output GB"
        echo "Compression ratio: $ratio"
    done
fi

# check if all files from input have their counterparts in the output
for input_file in $input_dir/*.nc
do
    base_file=$(basename "$input_file")
    if [ ! -f "$output_dir/$base_file" ]; then
        echo "The file $base_file does not have a counterpart in the output directory."
        exit 1
    fi
done

echo "Compression completed successfully!"

