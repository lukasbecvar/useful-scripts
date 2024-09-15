#!/bin/bash

# colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# vps connection properties
server_user="serveruser"
server_ip="89.168.77.11"
remote_backup_path="/services/vps-backup.tar.gz"

# backup dir format
backup_root="/media/lukas/external-drive/backups"
year=$(date +"%Y")
date_format=$(date +"%d_%m_%Y")
backup_dest="$backup_root/$year/$date_format"

# create backup directory
mkdir -p "$backup_dest"

# notify that the backup script is starting on the server
echo "${CYAN}Starting backup script on the server ${BLUE}$server_user@$server_ip${CYAN}${NC}"

# run the clean process
ssh ${server_user}@${server_ip} "sh /services/x-panel.sh b"

# run data backup on the server
ssh ${server_user}@${server_ip} "sh /services/x-panel.sh d"

# check if the backup file exists on the remote server
if ssh ${server_user}@${server_ip} "[ -f ${remote_backup_path} ]"; then
    echo "${GREEN}Backup completed. Downloading the file ${YELLOW}$remote_backup_path${GREEN}${NC}"
    
    # download the backup file from the remote server
    scp ${server_user}@${server_ip}:${remote_backup_path} ${backup_dest}
    
    # notify that the backup has been downloaded
    echo "${GREEN}Backup successfully downloaded to ${YELLOW}$backup_dest/vps-backup.tar.gz${NC}"
    
    # remove the backup file from the remote server after download
    ssh ${server_user}@${server_ip} "rm -rf ${remote_backup_path}"
else
    # notify if the backup file was not found
    echo "${RED}File ${YELLOW}$remote_backup_path${RED} not found on the server. Backup may have failed.${NC}"
fi

# run the final process on the server (cleanup or exit)
ssh ${server_user}@${server_ip} "sh /services/x-panel.sh 99"
