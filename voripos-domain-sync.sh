#!/bin/bash

set -e
set +v
set +x

# This is needed to locate the Docker executable in /usr/local/bin.
# The Homebrew path is a workaround for local development where we use docker-credential-gcloud to push images.
# Docker will attempt to authenticate despite the image being public. docker-credential-gcloud must be locatable;
# otherwise, the script will fail. This is not an issue on POS machines where Docker authentication is not configured.
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

export VORIPOS_DOMAIN_SYNC_VERSION=0.4.1

# NOTE: Bash must be given Full Disk Access in order to read the user defaults.
#   See https://www.kith.org/jed/2022/02/15/launchctl-scheduling-shell-scripts-on-macos-and-full-disk-access/.
LITEFS_CLOUD_TOKEN=$(defaults read com.vori.VoriPOS provisioned_litefsCloudToken)
export LITEFS_CLOUD_TOKEN
export VORIPOS_DATA_DIR="$HOME/Library/Containers/com.vori.VoriPOS/Data/Library/Application Support/Domain"

# Keep the most-recent 100 files to ensure we (a) don't fill the disk while
# and (b) don't delete a database that may be in use.
export FILE_RETENTION_COUNT=100

# The directory must exist for bind mounts to work
mkdir -p "$VORIPOS_DATA_DIR"
echo "Data will be replicated to $VORIPOS_DATA_DIR"
echo "Current contents of $VORIPOS_DATA_DIR:"
ls -al "$VORIPOS_DATA_DIR"

docker compose -f $( dirname -- "$0"; )/docker-compose.yml pull
docker compose -f $( dirname -- "$0"; )/docker-compose.yml down
docker compose -f $( dirname -- "$0"; )/docker-compose.yml up
