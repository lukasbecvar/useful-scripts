#!/bin/python3
import os
import re
import sys

def rename_files(directory):
    files = os.listdir(directory)
    pattern = re.compile(r'_(\d+)\.')

    # find files that match the pattern
    numbered_files = []
    for file in files:
        match = pattern.search(file)
        if match:
            numbered_files.append((int(match.group(1)), file))
    
    # sort files based on their numbers
    numbered_files.sort()
    
    # rename files to fill gaps
    for index, (_, file) in enumerate(numbered_files):
        new_number = index + 1
        new_name = pattern.sub(f'_{new_number}.', file)
        old_path = os.path.join(directory, file)
        new_path = os.path.join(directory, new_name)
        
        if old_path != new_path:
            os.rename(old_path, new_path)
            print(f"Renamed: {old_path} -> {new_path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python dir-struct.py <directory>")
        sys.exit(1)
    
    directory = sys.argv[1]    
    rename_files(directory)
