#!/bin/bash

# update discord app without official package

# check if discord is already running
if pgrep -x "Discord" > /dev/null; then
    echo "Discord is currently running. Please close it before updating."
    exit 1
fi

# get current installed version
get_installed_version() {
    local installed_version=$(dpkg-query -W -f='${Version}\n' discord 2>/dev/null)
    echo $installed_version
}

# get latest version from api
get_latest_version() {
    local latest_version_url="https://discord.com/api/download/stable?platform=linux&format=deb"
    local download_url=$(curl -sI $latest_version_url | grep -i '^location' | awk '{print $2}' | tr -d '\r\n')
    echo $download_url
}

# update discord
update_discord() {
    local download_url=$1
    local temp_dir=$(mktemp -d)
    local filename=$(basename $download_url)
    local download_path="$temp_dir/$filename"

    echo "$temp_dir tmp dir"
    echo "$download_path path"

    echo "Download the latest version of Discord..."
    curl -# -L -o $download_path $download_url

    # check if download was successful
    if [ -f $download_path ]; then
        echo "Installing the new version of Discord..."
        sudo dpkg -i $download_path
        rm $download_path

        # print status message
        echo "Discord has been successfully updated!"
    else
        echo "Failed to download the latest version of Discord."
    fi

    # remove temp dir with downloaded installer
    rm -rf $temp_dir
}

installed_version=$(get_installed_version)
latest_version_url=$(get_latest_version)

# check if discord is installed
if [ -z "$installed_version" ]; then
    echo "Discord is not installed on this system."
    echo "Download and install the latest version of Discord..."
    update_discord $latest_version_url
    exit
fi

# check if update is available
if [ -n "$latest_version_url" ]; then
    latest_version=$(echo "$latest_version_url" | cut -d '/' -f 6)
    if [[ "$installed_version" != "$latest_version" ]]; then
        echo "A new version of Discord is available. Update in progress..."
        update_discord $latest_version_url
    else
        echo "The currently installed version of Discord is already up to date."
    fi
else
    echo "Unable to get the latest version of Discord from the API."
fi

# start discor after update
/usr/share/discord/Discord
