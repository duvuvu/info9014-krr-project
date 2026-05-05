#!/usr/bin/env bash
# database/etl/filter_top_n.sh
# Filter the official IMDb dataset to the top-N tconsts by numVotes DESC.
#
# Reads from .tsv.gz directly via zcat (no on-disk decompression).
# All title-keyed files are filtered by tconst; name.basics is filtered by the
# nconsts that survive in the filtered title.principals.
#
# Usage:  bash database/etl/filter_top_n.sh [N]
# Output: database/sources/imdb-official/filtered/*.tsv (~50 MB at N=5000)

set -euo pipefail

N="${1:-5000}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW="$SCRIPT_DIR/../sources/imdb-official/raw"
OUT="$SCRIPT_DIR/../sources/imdb-official/filtered"

mkdir -p "$OUT"

echo "Filter parameters:"
echo "  N        = $N"
echo "  RAW dir  = $RAW"
echo "  OUT dir  = $OUT"
echo

# Sanity check: raw files present
for f in title.basics title.akas title.crew title.episode title.principals title.ratings name.basics; do
  if [[ ! -f "$RAW/$f.tsv.gz" ]]; then
    echo "ERROR: missing $RAW/$f.tsv.gz — run download.sh first" >&2
    exit 1
  fi
done

# ----------------------------------------------------------------------
# Step 1: pick top-N tconsts by numVotes (column 3 of title.ratings.tsv)
# Sort to a temp file first so `head` can truncate without triggering
# SIGPIPE-on-sort (which `set -o pipefail` would otherwise propagate).
# ----------------------------------------------------------------------
echo "[1/4] Picking top $N tconsts by numVotes..."
zcat "$RAW/title.ratings.tsv.gz" \
  | tail -n +2 \
  | sort -t $'\t' -k3,3 -n -r \
  > "$OUT/.ratings_sorted.tmp"
head -n "$N" "$OUT/.ratings_sorted.tmp" | cut -f1 > "$OUT/tconsts.txt"
rm "$OUT/.ratings_sorted.tmp"
echo "       wrote $OUT/tconsts.txt ($(wc -l < "$OUT/tconsts.txt") tconsts)"
echo

# ----------------------------------------------------------------------
# Step 2: filter every title-keyed file (column 1 in all six)
# title.basics.tsv     col1 = tconst
# title.akas.tsv       col1 = titleId   (= tconst)
# title.crew.tsv       col1 = tconst
# title.episode.tsv    col1 = tconst
# title.principals.tsv col1 = tconst
# title.ratings.tsv    col1 = tconst
# Header is preserved by emitting the first line before awk-filtering.
# ----------------------------------------------------------------------
echo "[2/4] Filtering title-keyed TSVs..."
for f in title.basics title.akas title.crew title.episode title.principals title.ratings; do
  out="${f//./_}.tsv"
  echo "       $f.tsv.gz -> $out"
  awk -F'\t' '
    NR==FNR { k[$1]=1; next }
    FNR==1  { print; next }
    k[$1]
  ' "$OUT/tconsts.txt" <(zcat "$RAW/$f.tsv.gz") > "$OUT/$out"
done
echo

# ----------------------------------------------------------------------
# Step 3: collect surviving nconsts from filtered principals (column 3)
# ----------------------------------------------------------------------
echo "[3/4] Extracting surviving nconsts from filtered title.principals..."
tail -n +2 "$OUT/title_principals.tsv" \
  | cut -f3 \
  | sort -u \
  > "$OUT/nconsts.txt"
echo "       wrote $OUT/nconsts.txt ($(wc -l < "$OUT/nconsts.txt") nconsts)"
echo

# ----------------------------------------------------------------------
# Step 4: filter name.basics by nconsts (column 1 = nconst)
# ----------------------------------------------------------------------
echo "[4/4] Filtering name.basics..."
awk -F'\t' '
  NR==FNR { k[$1]=1; next }
  FNR==1  { print; next }
  k[$1]
' "$OUT/nconsts.txt" <(zcat "$RAW/name.basics.tsv.gz") > "$OUT/name_basics.tsv"
echo "       wrote $OUT/name_basics.tsv ($(($(wc -l < "$OUT/name_basics.tsv") - 1)) names)"
echo

# ----------------------------------------------------------------------
# Sentinel for re-run detection (load.sh checks .n_${N} to decide whether
# to re-filter on rebuilds)
# ----------------------------------------------------------------------
rm -f "$OUT"/.n_*
touch "$OUT/.n_${N}"

echo "=== Filter complete ==="
echo
echo "Filtered file sizes:"
ls -lh "$OUT"/*.tsv | awk '{printf "  %s  %s\n", $5, $9}'
echo
echo "Total filtered size: $(du -sh "$OUT" | cut -f1)"
