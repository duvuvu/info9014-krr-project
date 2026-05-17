#!/usr/bin/env python3
"""Iterate Q4 across path-length bounds to compute pairwise Bacon distance.

For each (source, target) pair, runs ASK queries at k = 1, 2, 3, ... and
reports the smallest k that returns true. SPARQL 1.1 has no shortest-path
operator; this is the standard iterated-reachability pattern.

Outputs sparql/results/q4_pairwise_bacon.csv with one row per ASK run:
source_name, source_nconst, target_name, target_nconst, k, answer, elapsed_s.
"""
from __future__ import annotations

import csv
import json
import sys
import time
import urllib.parse
import urllib.request

ENDPOINT = "http://localhost:3030/cineexplorer/query"
SOURCE = ("nm0000102", "Kevin Bacon")
TARGETS = [
    ("nm0000158", "Tom Hanks"),         # expected d=1 (Apollo 13)
    ("nm0000056", "Paul Newman"),       # expected d=2
    ("nm0000075", "Spencer Tracy"),     # expected d=3
    ("nm0000070", "Max Steiner"),       # expected d=3
    ("nm0000050", "Groucho Marx"),      # d>=4 — query times out
]
PERSON_BASE = "http://cineexplorer.local/data/person/"
MAX_K = 3
PER_QUERY_TIMEOUT_S = 60.0


def ask(source_iri: str, target_iri: str, k: int) -> tuple[bool | None, float]:
    """Returns (answer, elapsed_seconds). answer=None on timeout."""
    query = (
        "PREFIX ce: <http://cineexplorer.local/ontology#>\n"
        "ASK {\n"
        f"  <{source_iri}> (ce:workedFor/ce:employed){{{k},{k}}} <{target_iri}> .\n"
        f"  FILTER(<{source_iri}> != <{target_iri}>)\n"
        "}\n"
    )
    req = urllib.request.Request(
        ENDPOINT,
        data=query.encode("utf-8"),
        headers={
            "Accept": "application/sparql-results+json",
            "Content-Type": "application/sparql-query",
        },
        method="POST",
    )
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=PER_QUERY_TIMEOUT_S) as resp:
            body = json.loads(resp.read())
        return bool(body["boolean"]), time.monotonic() - t0
    except Exception:
        return None, time.monotonic() - t0


def main() -> int:
    rows = []  # list of (source_name, source_nconst, target_name, target_nconst, k, answer, elapsed)
    src_nconst, src_name = SOURCE
    src_iri = PERSON_BASE + src_nconst
    for tgt_nconst, tgt_name in TARGETS:
        tgt_iri = PERSON_BASE + tgt_nconst
        for k in range(1, MAX_K + 1):
            ans, elapsed = ask(src_iri, tgt_iri, k)
            answer_str = "TRUE" if ans is True else ("FALSE" if ans is False else "TIMEOUT")
            rows.append((src_name, src_nconst, tgt_name, tgt_nconst, k, answer_str, elapsed))
            print(f"{tgt_name} (k={k}): {answer_str} [{elapsed:.2f}s]", file=sys.stderr)
            if ans is True or ans is None:
                break

    out_path = "sparql/results/q4_pairwise_bacon.csv"
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["source_name", "source_nconst", "target_name", "target_nconst",
                    "k", "answer", "elapsed_s"])
        for row in rows:
            w.writerow([row[0], row[1], row[2], row[3], row[4], row[5], f"{row[6]:.2f}"])
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
