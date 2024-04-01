#!/bin/bash

# This script clones all GitHub repositories for a user, zips them individually, and then deletes the directories

# GitHub username and personal access token
github_username="lordbecvold"
github_token=""

# Output directory for cloned repositories
output_directory="./github-repositories"

# GitHub API URL to fetch user repositories
api_url="https://api.github.com/user/repos"

# Fetch repositories using GitHub API and clone them
repositories=$(curl -s -H "Authorization: token ${github_token}" ${api_url}?per_page=100 | jq -r '.[].ssh_url')

green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

# Counter for total repositories
total_repositories=$(echo "${repositories}" | wc -l)
# Counter for cloned and zipped repositories
cloned_zipped_counter=0

# Loop through repositories, clone them, zip them, and then delete the directory
for repo_url in ${repositories}; do
    repo_name=$(basename ${repo_url} .git)
    repo_path="${output_directory}/${repo_name}"

    # Clone the repository with SSH URL and use SSH agent
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git clone ${repo_url} ${repo_path}

    # Display success or failure message for cloning
    if [ $? -eq 0 ]; then
        echo "${green}Repository ${repo_name} cloned successfully.${reset}"
    else
        echo "${red}Failed to clone repository ${repo_name}.${reset}"
        continue
    fi

    # Zip the cloned repository directly into the output directory
    zip -r "${output_directory}/${repo_name}.zip" "${repo_path}"

    # Display success or failure message for zipping
    if [ $? -eq 0 ]; then
        echo "${green}Repository ${repo_name} zipped successfully.${reset}"
        cloned_zipped_counter=$((cloned_zipped_counter + 1))
    else
        echo "${red}Failed to zip repository ${repo_name}.${reset}"
    fi

    # Remove the cloned directory
    rm -rf ${repo_path}

    # Display success or failure message for directory removal
    if [ $? -eq 0 ]; then
        echo "${green}Repository directory ${repo_name} removed successfully.${reset}"
    else
        echo "${red}Failed to remove repository directory ${repo_name}.${reset}"
    fi
done

# Check if all repositories were cloned and zipped
if [ ${cloned_zipped_counter} -eq ${total_repositories} ]; then
    echo "${green}All repositories were successfully cloned and zipped.${reset}"
else
    echo "${red}Some repositories were not cloned or zipped.${reset}"
fi
