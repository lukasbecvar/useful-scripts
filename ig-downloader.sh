#!/bin/bash

# instagram login
INSTAGRAM_USERNAME="username"

# profiles list to download
profiles=(
    "lordbecvold"
)

# colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # no color

# fancy separator
separator() {
    echo -e "${CYAN}=======================================================================================${NC}"
}

# download user data
for username in "${profiles[@]}"; do
    separator
    echo -e "${BLUE}📥 Downloading data from ${YELLOW}$username${NC}..."

    # execute instaloader
    instaloader --login="$INSTAGRAM_USERNAME" --tagged --no-videos --no-video-thumbnails --no-captions --no-metadata-json --no-compress-json --fast-update "$username"

    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error: Failed to download data from $username${NC}"
    else
        echo -e "${GREEN}✅ Success: Data downloaded from $username${NC}"
    fi
done

separator
echo -e "${CYAN}🎉 Download complete.${NC}"
