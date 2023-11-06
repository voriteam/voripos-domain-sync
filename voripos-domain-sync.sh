#!/bin/bash

# This is needed to locate the Docker executable
export PATH="/usr/local/bin:$PATH"

# NOTE: Bash must be given Full Disk Access in order to read the user defaults.
#   See https://www.kith.org/jed/2022/02/15/launchctl-scheduling-shell-scripts-on-macos-and-full-disk-access/.
export LITEFS_CLOUD_TOKEN=$(defaults read com.vori.VoriPOS provisioned_litefsCloudToken)
export VORIPOS_DATA_DIR="$HOME/Library/Containers/com.vori.VoriPOS/Data/Library/Application Support/Domain"

# Keep the most-recent 100 files to ensure we (a) don't fill the disk while
# and (b) don't delete a database that may be in use.
export FILE_RETENTION_COUNT=100

# The directory must exist for bind mounts to work
mkdir -p "$VORIPOS_DATA_DIR"
echo "Data will be replicated to $VORIPOS_DATA_DIR"
echo "Current contents of $VORIPOS_DATA_DIR:"
ls -al "$VORIPOS_DATA_DIR"

docker compose -f $( dirname -- "$0"; )/docker-compose.yml down
docker compose -f $( dirname -- "$0"; )/docker-compose.yml up
