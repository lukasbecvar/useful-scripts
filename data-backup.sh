#!/bin/bash

# This is a backup script for a complete backup of my computer, VPS server, and GitHub repositories to the current directory. 
# This script is intended to be run on an external drive so that the data is downloaded to offline storage.

# color echo functions
echo_red() { echo "\033[0;31m$1\033[0m"; }
echo_yellow() { echo "\033[1;33m$1\033[0m"; }
echo_blue() { echo "\033[0;34m$1\033[0m"; }
echo_green() { echo "\033[0;32m$1\033[0m"; }
echo_orange() { echo "\033[0;33m$1\033[0m"; }
echo_cyan() { echo "\033[0;36m$1\033[0m"; }

# PATH AND PROPERTIES CONFIG ######################################################################
# local data to backup path
directory_to_backup="/home/lukas/data"

# vps connection properties (backup server data)
server_user="server-user"
server_ip="server-ip"
server_backup_path="/services/vps-backup.tar.gz"

# github auth token for backup github repositories
github_username="lordbecvold"
github_token="github-token"

# github repositories backup path
github_repositories_path="./projects/github-repositories"

# github API url to fetch user repositories
api_url="https://api.github.com/user/repos"
###################################################################################################

# build backup path
year=$(date +"%Y")
date=$(date +"%d_%m_%Y")
backup_path="./backups/$year/$date"

# create backup directory if not exists
if [ ! -d $backup_path ]
then
    mkdir -p $backup_path
    echo_cyan "Backup directory created: $backup_path"
else
    echo_yellow "Backup directory already exists"
fi

# sync source to backup directory #################################################################
rsync -auv --delete --progress "$directory_to_backup" "$backup_path"

# print backup output status
if [ $? -eq 0 ]; then
    echo_green "Backup: $date successful created in $backup_path"
else
    echo_red "Backup error: $date error"
    exit 1
fi

# backup server data ##############################################################################
echo_cyan "Starting backup script on the server $server_user@$server_ip"

# run cleanup script process on the server
ssh ${server_user}@${server_ip} "sh /services/x-panel.sh b"

# run backup script process on the server
ssh ${server_user}@${server_ip} "sh /services/x-panel.sh d"

# check if backup is created on the remote server
if ssh ${server_user}@${server_ip} "[ -f ${server_backup_path} ]"; then
    echo_green "Backup completed. Downloading the file $server_backup_path"
    
    # download the backup file from the remote server
    scp ${server_user}@${server_ip}:${server_backup_path} ${backup_path}
    
    # notify that the backup has been downloaded
    echo_green "Backup successfully downloaded to $backup_path/vps-backup.tar.gz"
    
    # delete backup archive from the remote server after download
    ssh ${server_user}@${server_ip} "rm -rf ${server_backup_path}"
else
    echo_red "File $server_backup_path not found on the server. Backup may have failed."
    exit 1
fi

# check service status on the server after complete backup
ssh ${server_user}@${server_ip} "sh /services/x-panel.sh 99"

# BACKUP GITHUB REPOSITORIES ######################################################################
# delete old github repositories backup directory
if [ -d $github_repositories_path ]
then
    rm -rf $github_repositories_path
    echo_cyan "Old github repositories backup directory deleted"
fi

# create github repositories backup directory
mkdir -p ${github_repositories_path}

# fetch repositories using GitHub API and clone them
repositories=$(curl -s -H "Authorization: token ${github_token}" ${api_url}?per_page=100 | jq -r '.[].ssh_url')

# counter for total repositories
total_repositories=$(echo "${repositories}" | wc -l)

# counter for cloned and zipped repositories
cloned_zipped_counter=0

# loop through repositories, clone them, zip them, and then delete the directory
for repo_url in ${repositories}; do
    repo_name=$(basename ${repo_url} .git)
    repo_path="${github_repositories_path}/${repo_name}"

    # clone the repository with SSH URL and use SSH agent
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git clone ${repo_url} ${repo_path}

    # display success or failure message for cloning
    if [ $? -eq 0 ]; then
        echo_green "Repository ${repo_name} cloned successfully."
    else
        echo_red "Failed to clone repository ${repo_name}."
        continue
    fi

    # change directory to the output directory and zip the cloned repository folder
    (cd ${github_repositories_path} && zip -r "${repo_name}.zip" "${repo_name}")

    # display success or failure message for zipping
    if [ $? -eq 0 ]; then
        echo_green "Repository ${repo_name} zipped successfully."
        cloned_zipped_counter=$((cloned_zipped_counter + 1))
    else
        echo_red "Failed to zip repository ${repo_name}."
    fi

    # remove the cloned directory
    rm -rf ${repo_path}

    # display success or failure message for directory removal
    if [ $? -eq 0 ]; then
        echo_green "Repository directory ${repo_name} removed successfully."
    else
        echo_red "Failed to remove repository directory ${repo_name}."
    fi
done

# check if all repositories were cloned and zipped
if [ ${cloned_zipped_counter} -eq ${total_repositories} ]; then
    echo_green "All repositories were successfully cloned and zipped."
else
    echo_red "Some repositories were not cloned or zipped."
fi
