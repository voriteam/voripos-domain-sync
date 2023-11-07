#!/bin/bash

set -e
set +v
set +x

Normal='\033[0m'
Underline='\033[4m'

# Regular Colors
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'


echo "Started sync.sh"

if [ -z "$LITEFS_CLOUD_TOKEN" ]
then
  echo -e "${Red}${Underline}The LITEFS_CLOUD_TOKEN environment variable is not set! Make sure it is present in user defaults, and Bash can access them.$Normal"
fi

# NOTE (clintonb): This is a hack, but it works!
# I tried lsyncd + rsync, but the changes were never properly reflected on the
# host without reloading the entire database with `.load`. Also, lsyncd uses inotify
# events, which don't work with LiteFS + FUSE. This solution works because we
# execute `.restore` to properly update the DB.
sync_database() {
  name="$1"
  path="$LITEFS_DB_DIRECTORY/$name"

  echo "Attempting to sync $path..."

  if test -f $path; then
    sourcePath="$LITEFS_DB_DIRECTORY/$name"
    destPath="/host-data/$(date +"%s")-$name"

    stat "$sourcePath"

    if test -s $sourcePath; then
      # NOTE: We execute the restore in the container since it is more performant than restoring on a host volume.
      echo -e "${Yellow}Copying $sourcePath to $destPath...${Normal}"
      time cp $sourcePath $destPath

      echo -e "${Green}Successfully copied ${name} to ${destPath}$Normal"
      sqlite3 $destPath ".mode table" "SELECT * FROM metadata;"
      sqlite3 $destPath "SELECT COUNT(*) || ' departments' FROM departments;"
      sqlite3 $destPath "SELECT COUNT(*) || ' tax rates' FROM tax_rates;"
      sqlite3 $destPath "SELECT COUNT(*) || ' products' FROM products;"
      sqlite3 $destPath "SELECT COUNT(*) || ' product barcodes' FROM product_barcodes;"
      sqlite3 $destPath "SELECT COUNT(*) || ' promotions' FROM promotions;"
      sqlite3 $destPath "SELECT COUNT(*) || ' offers' FROM offers;"
      sqlite3 $destPath "SELECT COUNT(*) || ' offer benefits' FROM offer_benefits;"
      sqlite3 $destPath "SELECT COUNT(*) || ' offer conditions' FROM offer_conditions;"
      sqlite3 $destPath "SELECT COUNT(*) || ' product ranges' FROM product_ranges;"
      sqlite3 $destPath ".mode table" "ANALYZE; SELECT * FROM sqlite_stat1;"

      echo -e "${Yellow}Deleting all but the latest ${FILE_RETENTION_COUNT} files from /host-data$Normal"
      tailNum=$(( $FILE_RETENTION_COUNT + 1 ))
      cd /host-data
      # Source: https://stackoverflow.com/a/34862475/592820
      ls -tp | grep -v '/$' | tail -n +${tailNum} | xargs -I {} rm -- {}
    else
      echo -e "$Red$sourcePath has not been fully replicated from LiteFS Cloud$Normal"
    fi
  else
    echo -e "$Red$path does not yet exist$Normal"
  fi
}

sync_databases() {
  sync_database $DOMAIN_DB_NAME
}

sync_databases;

# NOTE: We watch the internal data directory because the DB directory uses FUSE,
# and cannot be easily monitored with fswatch.
watched_path="$LITEFS_INTERNAL_DATA_DIRECTORY/dbs/$DOMAIN_DB_NAME/database"
echo "Running fswatch for $watched_path"
fswatch -or "$watched_path"  | while read f; do echo "Change detected in $f files" && sync_databases; done
