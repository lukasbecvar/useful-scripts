#!/bin/python3
import os
import re

# script for validate and sort xs data storage

# path to the storage folder
STORAGE_PATH = '/data/storage'

# define color codes
RED = '\033[91m'
GREEN = '\033[92m'
YELLOW = '\033[93m'
CYAN = '\033[96m'
RESET = '\033[0m'

# function to check if the root directory contains only folders
def check_root_directory(path):
    for item in os.listdir(path):
        item_path = os.path.join(path, item)
        if os.path.isfile(item_path):
            print(f"{RED}Error: File '{item}' detected in the root of storage. Cannot proceed.{RESET}")
            return False
    return True

# function to validate if a file name matches the expected format
def is_valid_file_name(folder_name, file_name):
    match = re.match(rf'^{re.escape(folder_name)}_(\d+)\.[a-zA-Z0-9]+$', file_name)
    return bool(match)

# function to validate files in a folder
def validate_folder(folder_path):
    folder_name = os.path.basename(folder_path)
    files = [f for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f))]

    for file in files:
        # check if the file starts with a dot or ends with '~'
        if file.startswith('.'):
            print(f"{RED}Error: File '{file}' in folder '{folder_name}' is hidden (starts with a dot). Hidden files are not allowed.{RESET}")
            return False
        if file.endswith('~'):
            print(f"{RED}Error: File '{file}' in folder '{folder_name}' ends with '~'. Files ending with '~' are not allowed.{RESET}")
            return False
        if ' ' in file:
            print(f"{RED}Error: File '{file}' in folder '{folder_name}' contains a space. Files cannot contain spaces.{RESET}")
            return False
        # check file format
        if not is_valid_file_name(folder_name, file):
            print(f"{RED}Error: File '{file}' in folder '{folder_name}' does not have the correct format. Expected format is '{folder_name}_number.format'.{RESET}")
            return False

    return True

# function to rename files in a folder only if numbers are missing in the sequence
def rename_files_in_folder_if_needed(folder_path):
    folder_name = os.path.basename(folder_path)
    files = sorted([f for f in os.listdir(folder_path) if os.path.isfile(os.path.join(folder_path, f)) and not f.startswith('.') and not f.endswith('~')])

    file_numbers = []
    file_extensions = {}

    for file in files:
        match = re.match(rf'{re.escape(folder_name)}_(\d+)\.([a-zA-Z0-9]+)$', file)
        if match:
            file_number = int(match.group(1))
            file_extension = match.group(2)
            file_numbers.append(file_number)
            file_extensions[file_number] = file_extension

    expected_numbers = list(range(1, len(file_numbers) + 1))
    if file_numbers == expected_numbers:
        print(f"{GREEN}All files in folder '{folder_name}' are in order. No renaming needed.{RESET}")
        return False

    # rename files if any number is missing
    missing_files = False
    for expected_number in expected_numbers:
        if expected_number not in file_numbers:
            missing_files = True
            break

    if missing_files:
        expected_number = 1
        for file_number in sorted(file_numbers):
            if file_number != expected_number:
                old_file = f"{folder_name}_{file_number}.{file_extensions[file_number]}"
                new_file = f"{folder_name}_{expected_number}.{file_extensions[file_number]}"
                old_file_path = os.path.join(folder_path, old_file)
                new_file_path = os.path.join(folder_path, new_file)
                print(f"{YELLOW}Renaming file: {old_file} -> {new_file}{RESET}")
                os.rename(old_file_path, new_file_path)
            expected_number += 1
        return True
    return False

# function to validate the entire storage
def validate_storage(path):
    if not check_root_directory(path):
        return False

    folders = [d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d))]
    
    for folder in folders:
        # ignore the folder named '1mix'
        if folder == '1mix':
            print(f"{CYAN}Folder '1mix' will be ignored.{RESET}")
            continue

        folder_path = os.path.join(path, folder)

        # check for spaces in folder names
        if ' ' in folder:
            print(f"{RED}Error: Folder '{folder}' contains a space.{RESET}")
            return False

        # validate files in the folder
        if not validate_folder(folder_path):
            return False

    return True

# main function
def main(path):
    print(f"{GREEN}Validating storage...{RESET}")
    if validate_storage(path):
        print(f"{GREEN}Validation successful. Checking and possibly renaming files...{RESET}")
        folders = [d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d))]
        renamed_files = False
        for folder in folders:
            # ignore the folder named '1mix' during renaming
            if folder == '1mix':
                continue
            if rename_files_in_folder_if_needed(os.path.join(path, folder)):
                renamed_files = True
        if not renamed_files:
            print(f"{GREEN}All files are in order. No renaming needed.{RESET}")
    else:
        print(f"{RED}Storage is not valid. Renaming will not be performed.{RESET}")

# run validator process
main(STORAGE_PATH)
