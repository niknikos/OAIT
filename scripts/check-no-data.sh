#!/bin/sh
#
# Refuse to commit anything that looks like data.
#
# OAIT holds instructions only. .gitignore already blocks data extensions, but
# `git add -f` bypasses it. This check is the second net: it inspects what is
# actually staged (pre-commit) or what a branch adds (CI) and fails on
#
#   * a file with a data / figure / container extension,
#   * a file under a data-like directory,
#   * a file larger than MAX_KB (instructions are small; data is not).
#
# Usage:
#   scripts/check-no-data.sh                 # check the staged index (pre-commit)
#   scripts/check-no-data.sh <base-ref>      # check files changed since <base-ref> (CI)
#   scripts/check-no-data.sh --all           # check every tracked file (first push, audits)
#
# Legitimate exceptions (e.g. a small logo) go in .data-guard-allow, one path per line.
set -e

MAX_KB=${OAIT_MAX_KB:-300}
repo_root=$(git rev-parse --show-toplevel)
allow_file="$repo_root/.data-guard-allow"

if [ "$1" = "--all" ]; then
  files=$(git ls-files)
elif [ -n "$1" ]; then
  files=$(git diff --name-only --diff-filter=AM "$1"...HEAD)
else
  files=$(git diff --cached --name-only --diff-filter=AM)
fi

[ -z "$files" ] && exit 0

pattern='\.(hex|dat|bl|hdr|mrk|xmlcon|con|psa|cnv|btl|ros|asc|000|001|002|pd0|enr|ens|enx|sta|lta|n1r|n2r|nms|vmo|mmt|whp|toa5|tob1|log|nc|nc4|cdf|h5|hdf5|mat|odv|rds|rda|rdata|duckdb|wal|sqlite|db|xml|xlsx|xls|ods|csv|tsv|parquet|feather|arrow|png|jpe?g|pdf|svg|tiff?|kml|kmz|gpx|shp|gpkg|geojson)$'
dir_pattern='(^|/)(data|raw|store|cache|registry|outputs?|results|private|scratch)/'

status=0
for f in $files; do
  if [ -f "$allow_file" ] && grep -qxF "$f" "$allow_file"; then
    continue
  fi
  lower=$(printf '%s' "$f" | tr '[:upper:]' '[:lower:]')
  if printf '%s' "$lower" | grep -Eq "$pattern"; then
    echo "check-no-data: refusing '$f' (data/figure/container extension)" >&2
    status=1
    continue
  fi
  if printf '%s' "$lower" | grep -Eq "$dir_pattern"; then
    echo "check-no-data: refusing '$f' (inside a data-like directory)" >&2
    status=1
    continue
  fi
  if [ -f "$repo_root/$f" ]; then
    size_kb=$(( $(wc -c < "$repo_root/$f") / 1024 ))
    if [ "$size_kb" -gt "$MAX_KB" ]; then
      echo "check-no-data: refusing '$f' (${size_kb} KB > ${MAX_KB} KB; instructions are small)" >&2
      status=1
    fi
  fi
done

if [ "$status" -ne 0 ]; then
  cat >&2 <<'EOF'

OAIT holds instructions only — never data. Remove the file(s) above from the commit
(git restore --staged <file>, or git rm --cached <file> before the first commit). If a file
is a genuine non-data asset, add its path to .data-guard-allow and explain why in the commit
message.
EOF
fi
exit $status
