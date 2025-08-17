#!/bin/python3
import os
import re
import sys

# script for sorting and validation media files storage structure

# default path to data storage (if no path argument is given)
STORAGE_PATH = '/data/storage'

# bash color codes
RED = '\033[91m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
CYAN = '\033[96m'
RESET = '\033[0m'

def two_phase_rename(directory, renames):
    """Perform renaming in two phases to avoid collisions."""
    temp_prefix = "tmp_renaming_"
    intermediate_names = {}
    for old, final in renames:
        intermediate = temp_prefix + final
        intermediate_names[old] = (intermediate, final)
    for old, (intermediate, final) in intermediate_names.items():
        os.rename(os.path.join(directory, old), os.path.join(directory, intermediate))
    for old, (intermediate, final) in intermediate_names.items():
        os.rename(os.path.join(directory, intermediate), os.path.join(directory, final))

def check_folder_format(directory):
    """Ensure all files match expected format and base name matches folder name."""
    expected_base = os.path.basename(os.path.normpath(directory))
    pattern = re.compile(r'^(?P<base>.+)_(?P<num>\d+)(-(?P<tempSuffix>\d+))?\.(?P<ext>.+)$')

    for f in os.listdir(directory):
        if f.startswith("tmp_renaming_"):
            continue
        m = pattern.match(f)
        if m:
            base = m.group('base')
            if base != expected_base:
                print(f"{RED}Error: '{f}' does not match folder base '{expected_base}'. Aborting.{RESET}")
                sys.exit(1)
        else:
            print(f"{RED}Error: '{f}' does not match expected pattern. Aborting.{RESET}")
            sys.exit(1)

def process_full_sort(directory):
    """Sort files in folder, ensuring unique consecutive numbering."""
    pattern = re.compile(r'^(?P<base>.+)_(?P<num>\d+)(-(?P<tempSuffix>\d+))?\.(?P<ext>.+)$')
    files = os.listdir(directory)
    groups = {}

    for f in files:
        m = pattern.match(f)
        if not m:
            continue
        base = m.group('base')
        num = int(m.group('num'))
        ext = m.group('ext')
        tempSuffix = m.group('tempSuffix')
        if base not in groups:
            groups[base] = []
        sort_key = (num, 0, 0) if tempSuffix is None else (num, 1, int(tempSuffix))
        groups[base].append((f, sort_key, ext))

    renames = []
    for base, entries in groups.items():
        entries_sorted = sorted(entries, key=lambda x: x[1])
        new_number = 1
        for old_filename, sort_key, ext in entries_sorted:
            new_name = f"{base}_{new_number}.{ext}"
            if old_filename != new_name:
                print(f"{YELLOW}Renaming: {old_filename} -> {new_name}{RESET}")
                renames.append((old_filename, new_name))
            new_number += 1

    return renames

def validate_storage(path):
    """Check if all directories and files conform to naming rules."""
    if not os.path.isdir(path):
        print(f"{RED}Error: '{path}' is not a valid directory.{RESET}")
        return False

    for folder in os.listdir(path):
        # exclude 1mix directory from validation
        if folder == '1mix':
            print(f"{CYAN}Folder '1mix' will be ignored in validation.{RESET}")
            continue
        folder_path = os.path.join(path, folder)
        if not os.path.isdir(folder_path):
            print(f"{RED}Error: File '{folder}' found in root directory. Aborting.{RESET}")
            return False
        if ' ' in folder:
            print(f"{RED}Error: Folder '{folder}' contains spaces. Aborting.{RESET}")
            return False
        check_folder_format(folder_path)
    return True

def main(path):
    """Main function to validate and sort storage."""
    print(f"{GREEN}Validating storage...{RESET}")
    if validate_storage(path):
        print(f"{GREEN}Validation successful. Sorting files...{RESET}")
        changes_made = False
        for folder in os.listdir(path):
            # exclude 1mix directory from storage sorting
            if folder == '1mix':
                print(f"{CYAN}Folder '1mix' will be ignored in sorting.{RESET}")
                continue
            folder_path = os.path.join(path, folder)
            if os.path.isdir(folder_path):
                renames = process_full_sort(folder_path)
                if renames:
                    two_phase_rename(folder_path, renames)
                    changes_made = True
        if not changes_made:
            print(f"{GREEN}No renaming needed in any folder.{RESET}")
    else:
        print(f"{RED}Storage validation failed. Sorting will not be performed.{RESET}")

if __name__ == '__main__':
    # if path argument provided, use it; otherwise fall back to default STORAGE_PATH
    if len(sys.argv) > 1:
        path = sys.argv[1]
    else:
        path = STORAGE_PATH
    main(path)
