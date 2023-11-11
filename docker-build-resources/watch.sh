#!/bin/bash

# This script watches the LiteFS directory for changes to trigger
# copying the synced database to the host machine.

set -e
set +v
set +x

Normal='\033[0m'
Underline='\033[4m'
Red='\033[0;31m'

echo "Started watch.sh"

if [ -z "$LITEFS_CLOUD_TOKEN" ]
then
  echo -e "${Red}${Underline}The LITEFS_CLOUD_TOKEN environment variable is not set! Make sure it is present in user defaults, and Bash can access them.$Normal"
fi

# Perform an initial copy attempt
bash copy-database.sh "$DOMAIN_DB_NAME"

# NOTE: We watch the internal data directory because the DB directory uses FUSE,
# and cannot be easily monitored with fswatch.
watched_path="$LITEFS_INTERNAL_DATA_DIRECTORY/dbs/$DOMAIN_DB_NAME/database"
echo "Running fswatch for $watched_path"
fswatch -or "$watched_path"  | while read f; do echo "Change detected in $f files" && bash copy-database.sh "$DOMAIN_DB_NAME"; done
