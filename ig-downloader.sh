#!/bin/bash

# check if command is bash
if [ -z "$BASH_VERSION" ]; then
    echo "\e[31mPlease run this script with bash command.\e[0m"
    exit 1
fi

# list of usernames to download
usernames=(
    "profile_1"
    "profile_2"
)

# download process
for profile in "${usernames[@]}"; do
    echo -e "\e[34mDownloading data from profile: \e[1m$profile\e[0m"
    instaloader --no-videos --no-video-thumbnails --no-captions \
                --no-metadata-json --no-compress-json --fast-update "$profile"
    echo -e "\e[32mFinished downloading: \e[1m$profile\e[0m"
done

# final message
echo -e "\e[35mAll downloads completed.\e[0m"
