# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#   kernelspec:
#     display_name: Python 3
#     language: python
#     name: python3
# ---

# %% [markdown]
# # Per-column distinct counts + sample values
#
# Companion script to `01_imdb_raw_analysis.py`. For every column in every
# raw IMDb file, computes (a) `n_unique` and (b) the top 5 most frequent
# non-null values. Output drives the "Distinct" / "Examples" columns added
# to the schema tables in `docs/raw_imdb_analysis.md`.

# %%
from pathlib import Path
import polars as pl

RAW = (Path(__file__).parent / ".." / "database" / "sources" / "imdb-official" / "raw")
NULL = ["\\N"]

FILES = {
    "title.basics": dict(
        path=RAW / "title.basics.tsv.gz",
        schema_overrides={"isAdult": pl.Int8, "startYear": pl.Int32,
                          "endYear": pl.Int32, "runtimeMinutes": pl.Int32},
    ),
    "title.akas": dict(
        path=RAW / "title.akas.tsv.gz",
        schema_overrides={"ordering": pl.Int32, "isOriginalTitle": pl.Int8},
    ),
    "title.crew": dict(path=RAW / "title.crew.tsv.gz", schema_overrides={}),
    "title.episode": dict(
        path=RAW / "title.episode.tsv.gz",
        schema_overrides={"seasonNumber": pl.Int32, "episodeNumber": pl.Int32},
    ),
    "title.principals": dict(
        path=RAW / "title.principals.tsv.gz",
        schema_overrides={"ordering": pl.Int32},
    ),
    "title.ratings": dict(
        path=RAW / "title.ratings.tsv.gz",
        schema_overrides={"averageRating": pl.Float32, "numVotes": pl.Int64},
    ),
    "name.basics": dict(
        path=RAW / "name.basics.tsv.gz",
        schema_overrides={"birthYear": pl.Int32, "deathYear": pl.Int32},
    ),
}


def analyze(name: str, conf: dict, sample_k: int = 5):
    print(f"\n=== {name} ===")
    lf = pl.scan_csv(
        conf["path"], separator="\t", null_values=NULL,
        schema_overrides=conf["schema_overrides"], quote_char=None,
    )
    cols = lf.collect_schema().names()
    for c in cols:
        n_unique = lf.select(pl.col(c).n_unique()).collect().item()
        # top samples (most frequent non-null values)
        top = (
            lf.filter(pl.col(c).is_not_null())
            .group_by(c)
            .len()
            .sort("len", descending=True)
            .head(sample_k)
            .collect()
        )
        examples = ", ".join(
            f"{row[c]} ({row['len']:,})" if isinstance(row[c], str) and len(str(row[c])) <= 40
            else f"{repr(row[c])[:40]}{'…' if len(repr(row[c]))>40 else ''} ({row['len']:,})"
            for row in top.iter_rows(named=True)
        )
        # min/max for numeric columns
        try:
            mm = lf.select([pl.col(c).min().alias("min"), pl.col(c).max().alias("max")]).collect()
            mn, mx = mm["min"].item(), mm["max"].item()
            range_str = f"  range: {mn} – {mx}"
        except Exception:
            range_str = ""
        print(f"  {c}: n_unique={n_unique:,}{range_str}")
        print(f"    top: {examples}")


for name, conf in FILES.items():
    analyze(name, conf)
