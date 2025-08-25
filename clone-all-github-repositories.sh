#!/bin/bash

# This script clones all GitHub repositories for a user, zips them individually, and then deletes the directories

# github username and personal access token
github_username="lukasbecvar"
github_token="api-token"

# output directory for cloned repositories
output_directory="./github-repositories"

# bash color codes
green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

# delete output directory if it already exists
rm -rf ${output_directory}

# create the output directory if it doesn't exist
mkdir -p ${output_directory}

# github API URL to fetch user repositories
api_url="https://api.github.com/user/repos"

# fetch repositories using GitHub API and clone them
repositories=$(curl -s -H "Authorization: token ${github_token}" ${api_url}?per_page=100 | jq -r '.[].ssh_url')

# counter for total repositories
total_repositories=$(echo "${repositories}" | wc -l)
# counter for cloned and zipped repositories
cloned_zipped_counter=0

# loop through repositories, clone them, zip them, and then delete the directory
for repo_url in ${repositories}; do
    repo_name=$(basename ${repo_url} .git)
    repo_path="${output_directory}/${repo_name}"

    # clone the repository with SSH URL and use SSH agent
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git clone ${repo_url} ${repo_path}

    # display success or failure message for cloning
    if [ $? -eq 0 ]; then
        echo "${green}Repository ${repo_name} cloned successfully.${reset}"
    else
        echo "${red}Failed to clone repository ${repo_name}.${reset}"
        continue
    fi

    # change directory to the output directory and zip the cloned repository folder
    (cd ${output_directory} && zip -r "${repo_name}.zip" "${repo_name}")

    # display success or failure message for zipping
    if [ $? -eq 0 ]; then
        echo "${green}Repository ${repo_name} zipped successfully.${reset}"
        cloned_zipped_counter=$((cloned_zipped_counter + 1))
    else
        echo "${red}Failed to zip repository ${repo_name}.${reset}"
    fi

    # remove the cloned directory
    rm -rf ${repo_path}

    # display success or failure message for directory removal
    if [ $? -eq 0 ]; then
        echo "${green}Repository directory ${repo_name} removed successfully.${reset}"
    else
        echo "${red}Failed to remove repository directory ${repo_name}.${reset}"
    fi
done

# check if all repositories were cloned and zipped
if [ ${cloned_zipped_counter} -eq ${total_repositories} ]; then
    echo "${green}All repositories were successfully cloned and zipped.${reset}"
else
    echo "${red}Some repositories were not cloned or zipped.${reset}"
fi
