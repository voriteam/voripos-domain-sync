#!/bin/bash

# This script copies a synced database to the host and emits an Otel signal.

set -e
set +v
set +x

# OpenTelemetry setup
export OTEL_EXPORTER_OTEL_ENDPOINT="http://host.docker.internal:4318"
export OTEL_SH_LIB_PATH="opentelemetry-shell/library"
# shellcheck disable=SC2034
service_version=$OTEL_SERVICE_VERSION
. opentelemetry-shell/library/otel_traces.sh

Normal='\033[0m'
Red='\033[0;31m'
Green='\033[0;32m'
Yellow='\033[0;33m'

name="$1"
path="$LITEFS_DB_DIRECTORY/$name"

echo "Attempting to copy $path..."

if test -f "$path"; then
  sourcePath="$LITEFS_DB_DIRECTORY/$name"
  destPath="/host-data/$(date +"%s")-$name"

  stat "$sourcePath"

  if test -s "$sourcePath"; then
    # NOTE: We execute the restore in the container since it is more performant than restoring on a host volume.
    echo -e "${Yellow}Copying $sourcePath to $destPath...${Normal}"

    # Create an Otel span
    generatedAt=$(sqlite3 "$sourcePath" "SELECT generated_at FROM metadata;")
    schemaVersion=$(sqlite3 "$sourcePath" "SELECT schema_version FROM metadata;")
    # shellcheck disable=SC2034
    span_name="Copy domain data to host"
    # shellcheck disable=SC2034
    custom_resource_attributes=(
      "domain_data_generated_at:$generatedAt"
      "domain_data_schema_version:$schemaVersion"
    )
    linkedTraceId=$(sqlite3 "$sourcePath" "SELECT linked_trace_id FROM metadata;")
    linkedTraceState=$(sqlite3 "$sourcePath" "SELECT linked_trace_state FROM metadata;")
    linkedSpanId=$(sqlite3 "$sourcePath" "SELECT linked_span_id FROM metadata;")
    echo "[Linked Span Data] linkedTraceId: $linkedTraceId, linkedTraceState: $linkedTraceState, linkedSpanId: $linkedSpanId"
    # shellcheck disable=SC2034
    linked_span=("$linkedTraceId" "$linkedSpanId" "$linkedTraceState")
    otel_trace_start_parent_span cp "$sourcePath" "$destPath"

    echo -e "${Green}Successfully copied ${name} to ${destPath}$Normal"
    sqlite3 "$destPath" ".mode table" "SELECT * FROM metadata;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' departments' FROM departments;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' tax rates' FROM tax_rates;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' products' FROM products;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' product barcodes' FROM product_barcodes;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' promotions' FROM promotions;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' offers' FROM offers;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' offer benefits' FROM offer_benefits;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' offer conditions' FROM offer_conditions;"
    sqlite3 "$destPath" "SELECT COUNT(*) || ' product ranges' FROM product_ranges;"
    sqlite3 "$destPath" ".mode table" "ANALYZE; SELECT * FROM sqlite_stat1;"

    echo -e "${Yellow}Deleting all but the latest ${FILE_RETENTION_COUNT} files from /host-data$Normal"
    tailNum=$(( FILE_RETENTION_COUNT + 1 ))
    cd /host-data
    # Source: https://stackoverflow.com/a/34862475/592820
    ls -tp | grep -v '/$' | tail -n +${tailNum} | xargs -I {} rm -- {}
  else
    echo -e "$Red$sourcePath has not been fully replicated from LiteFS Cloud$Normal"
  fi
else
  echo -e "$Red$path does not yet exist$Normal"
fi
