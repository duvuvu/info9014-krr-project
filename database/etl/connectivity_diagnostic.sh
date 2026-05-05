#!/usr/bin/env bash
# database/etl/connectivity_diagnostic.sh
# Connectivity diagnostic on the filtered slice.
# Verifies that the slice has the bridge persons required for Bacon-number
# traversal across the collaboration graph. Operates on the filtered TSVs
# only — no MySQL involvement.
#
# Usage:  bash database/etl/connectivity_diagnostic.sh
# Output: stdout report; saves a copy to filtered/connectivity_report.txt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/../sources/imdb-official/filtered"
REPORT="$OUT/connectivity_report.txt"

if [[ ! -f "$OUT/title_principals.tsv" ]]; then
  echo "ERROR: $OUT/title_principals.tsv not found — run filter_top_n.sh first" >&2
  exit 1
fi

# Run the report and capture to both stdout and file
exec > >(tee "$REPORT") 2>&1

echo "=== Connectivity Diagnostic on filtered IMDb slice ==="
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

TOTAL_TITLES=$(($(wc -l < "$OUT/title_basics.tsv") - 1))
TOTAL_NAMES=$(($(wc -l < "$OUT/name_basics.tsv") - 1))
TOTAL_PRINCIPALS=$(($(wc -l < "$OUT/title_principals.tsv") - 1))
echo "Slice size:"
printf "  titles      : %d\n" "$TOTAL_TITLES"
printf "  persons     : %d\n" "$TOTAL_NAMES"
printf "  principals  : %d\n" "$TOTAL_PRINCIPALS"
echo

# Distribution: how many distinct titles does each person appear in?
echo "Distribution of titles per person"
echo "(target: many persons should appear in >1 title — these are the 'bridge persons'"
echo " required for Bacon-number traversal across cliques)"
echo
tail -n +2 "$OUT/title_principals.tsv" \
  | cut -f1,3 \
  | sort -u \
  | cut -f2 \
  | sort \
  | uniq -c \
  | awk '{print $1}' \
  | sort -n \
  | uniq -c \
  | awk '{printf "  %4d persons appear in %s titles\n", $1, $2}'
echo

# Top 20 most-credited persons in the slice
echo "Top 20 persons by # of distinct titles in the slice:"
echo
tail -n +2 "$OUT/title_principals.tsv" \
  | cut -f1,3 \
  | sort -u \
  | cut -f2 \
  | sort \
  | uniq -c \
  | sort -rn \
  | awk 'NR<=20' \
  | while read count nconst; do
      name=$(awk -F'\t' -v n="$nconst" '$1==n{print $2; exit}' "$OUT/name_basics.tsv")
      printf "  %4d titles  %-12s  %s\n" "$count" "$nconst" "${name:-(unknown)}"
    done
echo

# Bridge-person count
BRIDGE_COUNT=$(tail -n +2 "$OUT/title_principals.tsv" \
  | cut -f1,3 | sort -u | cut -f2 | sort | uniq -c \
  | awk '$1 >= 2' | wc -l)

PCT=$(awk -v b="$BRIDGE_COUNT" -v t="$TOTAL_NAMES" 'BEGIN { if (t>0) printf "%.1f", 100*b/t; else printf "0" }')

echo "=== Verdict ==="
echo "Bridge persons (in >= 2 titles): $BRIDGE_COUNT of $TOTAL_NAMES persons (${PCT}%)"
if [[ "$BRIDGE_COUNT" -ge 100 ]]; then
  echo "PASS: slice has sufficient connectivity for Bacon-number traversal."
elif [[ "$BRIDGE_COUNT" -ge 20 ]]; then
  echo "MARGINAL: slice has some bridge persons but may be sparse."
  echo "          Consider running with a larger N (e.g. filter_top_n.sh 5000)."
else
  echo "FAIL: slice is too sparse — collaboration graph likely still disconnected."
  echo "      Re-run filter_top_n.sh with a larger N."
fi
