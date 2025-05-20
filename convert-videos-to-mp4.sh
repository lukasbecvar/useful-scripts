#!/bin/bash

# folder with videos
INPUT_DIR="./"

# output folder (can be same as input)
OUTPUT_DIR="./converted"
mkdir -p "$OUTPUT_DIR"

# loop over all video files
for file in "$INPUT_DIR"/*.{mkv,mov,avi,flv,wmv}; do
    [ -e "$file" ] || continue

    filename=$(basename -- "$file")
    name="${filename%.*}"
    output="$OUTPUT_DIR/$name.mp4"

    echo "▶️ Converting: $file → $output"

    ffmpeg -i "$file" \
        -map 0 \
        -c:v copy \
        -c:a copy \
        -c:s mov_text \
        "$output"
done

echo "✅ All done!"
