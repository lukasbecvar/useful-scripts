#!/bin/bash

# This script clones all GitHub repositories for a user

# gitHub username and personal access token
github_username="github_username"
github_token="api_token"

# output directory for cloned repositories
output_directory="./github-repositories"

# gitHub API URL to fetch user repositories
api_url="https://api.github.com/user/repos"

# fetch repositories using GitHub API and clone them
repositories=$(curl -s -H "Authorization: token ${github_token}" ${api_url} | jq -r '.[].ssh_url')

green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

# loop through repositories and clone them
for repo_url in ${repositories}; do
    repo_name=$(basename ${repo_url} .git)
    repo_path="${output_directory}/${repo_name}"

    # clone the repository with SSH URL and use SSH agent
    GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git clone ${repo_url} ${repo_path}

    # display success or failure message
    if [ $? -eq 0 ]; then
        echo "${green}Repository ${repo_name} cloned successfully.${reset}"
    else
        echo "${red}Failed to clone repository ${repo_name}.${reset}"
    fi
done
