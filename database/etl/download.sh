#!/usr/bin/env bash
# database/etl/download.sh
# Download the official IMDb non-commercial dataset.
# Idempotent: skips files that are already present.
#
# Usage:  bash database/etl/download.sh
# Output: database/sources/imdb-official/raw/*.tsv.gz   (~1.6 GB total)

set -euo pipefail

BASE_URL="https://datasets.imdbws.com"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW_DIR="$SCRIPT_DIR/../sources/imdb-official/raw"

FILES=(
  title.basics.tsv.gz
  title.akas.tsv.gz
  title.crew.tsv.gz
  title.episode.tsv.gz
  title.principals.tsv.gz
  title.ratings.tsv.gz
  name.basics.tsv.gz
)

mkdir -p "$RAW_DIR"
echo "Target directory: $RAW_DIR"
echo

for f in "${FILES[@]}"; do
  if [[ -f "$RAW_DIR/$f" ]]; then
    echo "[skip]     $f  ($(du -h "$RAW_DIR/$f" | cut -f1))"
    continue
  fi
  echo "[download] $f"
  curl -fsSL --progress-bar "$BASE_URL/$f" -o "$RAW_DIR/$f.tmp"
  mv "$RAW_DIR/$f.tmp" "$RAW_DIR/$f"
  echo "[done]     $f  ($(du -h "$RAW_DIR/$f" | cut -f1))"
done

echo
echo "All raw files present:"
ls -lh "$RAW_DIR"/*.tsv.gz | awk '{printf "  %s  %s\n", $5, $9}'
echo
echo "Total: $(du -sh "$RAW_DIR" | cut -f1)"
