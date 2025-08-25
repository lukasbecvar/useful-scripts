#!/bin/bash

# check for input directory parameter
if [ -z "$1" ]; then
    echo "❌ Please provide the input directory with videos."
    echo "Usage: bash convert.sh /path/to/input"
    exit 1
fi

# remove trailing slash from input dir if present
INPUT_DIR="${1%/}"

# create output directory inside input directory
OUTPUT_DIR="$INPUT_DIR/converted"
mkdir -p "$OUTPUT_DIR"

# loop over all video files
shopt -s nullglob
for file in "$INPUT_DIR"/*.{mkv,mov,avi,flv,wmv}; do
    filename=$(basename -- "$file")
    name="${filename%.*}"
    output="$OUTPUT_DIR/$name.mp4"

    # print status msg
    echo "▶️ Converting: $file → $output"

    # use ffmpeg to convert video file
    ffmpeg -i "$file" \
        -map 0 \
        -c:v copy \
        -c:a copy \
        -c:s mov_text \
        "$output"
done
shopt -u nullglob
echo "✅ All done!"
