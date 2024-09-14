#!/bin/bash

# backup data folder to external drive

# source local directory
source_dir="/home/lukas/data"

# backup dir
backup_root="/media/lukas/external-drive/backups"

# echo functions
yellow_echo () { echo "\033[33m\033[1m$1\033[0m"; }
red_echo () { echo "\033[31m\033[1m$1\033[0m"; }

# backup dir format
year=$(date +"%Y")
date_format=$(date +"%d_%m_%Y")
backup_dest="$backup_root/$year/$date_format"

# create backup directory
mkdir -p "$backup_dest"

# copy all files to backup
rsync -auv --delete --progress "$source_dir" "$backup_dest"

# print final output
if [ $? -eq 0 ]; then
    yellow_echo "Backup: $date_format successful created in $backup_dest"
else
    red_echo "Backup error: $date_format error"
fi
