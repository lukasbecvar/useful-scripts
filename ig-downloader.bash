#!/bin/bash

# usage: bash ig-downloader.bash --full (full flag = download stories, highlights & tagged)

# check if command is bash
if [ -z "$BASH_VERSION" ]; then
    echo -e "\e[31mPlease run this script with bash command.\e[0m"
    exit 1
fi

# extra flags for --full download mode
EXTRA_FLAGS=""
if [[ "$1" == "--full" ]]; then
    EXTRA_FLAGS="--highlights --stories --tagged"
fi

# list of usernames to download
usernames=(
    "username1"
    "username2"
    "username3"
    "username4"
)

# download process
for profile in "${usernames[@]}"; do
    echo -e "\e[34mDownloading data from profile: \e[1m$profile\e[0m"
    instaloader --no-videos --no-video-thumbnails --no-captions --no-metadata-json --no-compress-json \
                --fast-update --load-cookies=firefox $EXTRA_FLAGS "$profile"
    echo -e "\e[32mFinished downloading: \e[1m$profile\e[0m"
done

# final message
echo -e "\e[35mAll downloads completed.\e[0m"
