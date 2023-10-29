#!/bin/bash

# This is needed to locate the Docker executable
export PATH="/usr/local/bin:$PATH"

# NOTE: Bash must be given Full Disk Access in order to read the user defaults.
#   See https://www.kith.org/jed/2022/02/15/launchctl-scheduling-shell-scripts-on-macos-and-full-disk-access/.
export LITEFS_CLOUD_TOKEN=$(defaults read com.vori.VoriPOS litefsCloudToken)
export VORIPOS_DATA_DIR="~/Library/Containers/com.vori.VoriPOS/Data/Library/Application Support"
docker compose -f $( dirname -- "$0"; )/docker-compose.yml down
docker compose -f $( dirname -- "$0"; )/docker-compose.yml up
