#!/bin/bash

# define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # no Color

# check if command is bash
if [ -z "$BASH_VERSION" ]; then
    echo "${RED}Please run this script with bash command.${NC}"
    exit 1
fi

# instagram login
LOGIN="ig_username"

# list of public profiles
public_profiles=(
    "public_profile"
)

# list of private profiles
private_profiles=(
    "private_profile"
)

# function to download profile
download_profile() {
    local profile=$1
    local is_private=$2
    if [ "$is_private" == "true" ]; then
        echo -e "${YELLOW}Downloading private profile: ${profile}${NC}"
        instaloader --login="$LOGIN" --tagged --no-videos --no-video-thumbnails --no-captions --no-metadata-json --no-compress-json --fast-update "$profile"
    else
        echo -e "${GREEN}Downloading public profile: ${profile}${NC}"
        instaloader --tagged --no-videos --no-video-thumbnails --no-captions --no-metadata-json --no-compress-json --fast-update --load-cookies="Chrome" "$profile"
    fi
}

# download public profiles
echo -e "${GREEN}Starting download of public profiles...${NC}"
for profile in "${public_profiles[@]}"; do
    download_profile "$profile" false
done

# download private profiles
echo -e "${RED}Starting download of private profiles...${NC}"
for profile in "${private_profiles[@]}"; do
    download_profile "$profile" true
done

echo -e "${GREEN}All downloads complete!${NC}"
