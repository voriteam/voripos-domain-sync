#!/bin/bash

set -e
set +v
set +x

Color_Off='\033[0m'       # Text Reset

# Regular Colors
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow


echo "Started sync.sh"

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
    destPath="/host-data/$name"

    stat "$sourcePath"

    if test -s $sourcePath; then
      # NOTE: We execute the restore in the container since it is more performant than restoring on a host volume.
      echo -e "${Yellow}Copying+restoring $sourcePath to $destPath...${Color_Off}"
      time sqlite3 $destPath ".restore $sourcePath"

      echo -e "${Green}Successfully synced ${name} to host$Color_Off"
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
    else
      echo -e "$Red$sourcePath has not been fully replicated from LiteFS Cloud$Color_Off"
    fi
  else
    echo -e "$Red$path does not yet exist$Color_Off"
  fi
}

sync_databases() {
  sync_database $DOMAIN_DB_NAME
}

sync_databases;

# NOTE: We watch the internal data directory because the DB directory uses FUSE,
# and cannot be easily monitored with fswatch.
watched_path="$LITEFS_INTERNAL_DATA_DIRECTORY/dbs/$DOMAIN_DB_NAME"
echo "Running fswatch for $watched_path"
fswatch -or "$watched_path"  | while read f; do echo "Change detected in $f files" && sync_databases; done
