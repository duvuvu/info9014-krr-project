# ---
# jupyter:
#   jupytext:
#     formats: ipynb,py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#       format_version: '1.3'
#       jupytext_version: 1.19.1
#   kernelspec:
#     display_name: Python 3
#     language: python
#     name: python3
# ---

# %% [markdown]
# # Raw IMDb Dataset Analysis
#
# **Purpose.** Characterise the *full* official IMDb non-commercial dataset
# (~10M titles, ~14M persons, ~85M principal credits) so the migrated CineExplorer
# schema can be designed against the *full* design space — not just the 2,500-title
# slice we currently work with.
#
# This complements `docs/tsv_inspection.md` (which analyses only the filtered slice).
# Findings here drive `docs/raw_imdb_analysis.md` and feed the Phase-2 ERD investigation
# (`docs/erd_investigation.md`).
#
# Tooling: **polars** for the heavy lifting (lazy / streaming, much smaller memory
# footprint than pandas on the 85M-row `title.principals` file).
#
# IMDb file specs: <https://developer.imdb.com/non-commercial-datasets/>

# %% [markdown]
# ## Setup

# %%
import json
import os
import sys
from pathlib import Path

import polars as pl

pl.Config.set_tbl_rows(40)
pl.Config.set_tbl_cols(20)

NB_DIR = Path(__file__).parent if "__file__" in globals() else Path.cwd()
RAW = NB_DIR / ".." / "database" / "sources" / "imdb-official" / "raw"
OUT = NB_DIR / "output"
OUT.mkdir(exist_ok=True)

# IMDb's null marker is the literal two-character string "\N"
NULL = ["\\N"]

print("polars:", pl.__version__)
print("RAW dir:", RAW.resolve())
print("OUT dir:", OUT.resolve())

# %% [markdown]
# ## File overview

# %%
files = [
    "title.basics.tsv.gz",
    "title.akas.tsv.gz",
    "title.crew.tsv.gz",
    "title.episode.tsv.gz",
    "title.principals.tsv.gz",
    "title.ratings.tsv.gz",
    "name.basics.tsv.gz",
]

overview = []
for f in files:
    p = RAW / f
    if p.exists():
        overview.append({
            "file": f,
            "size_mb": round(p.stat().st_size / 1024**2, 1),
        })
    else:
        overview.append({"file": f, "size_mb": None})

overview_df = pl.DataFrame(overview)
print(overview_df)

# %% [markdown]
# ## Helper: NULL / cardinality / distribution

# %%
def null_rates(lf: pl.LazyFrame) -> pl.DataFrame:
    """Compute null rate per column (treating IMDb's '\\N' as null is handled at read time)."""
    schema = lf.collect_schema()
    cols = schema.names()
    total = lf.select(pl.len()).collect().item()
    out = []
    for c in cols:
        n_null = lf.select(pl.col(c).is_null().sum()).collect().item()
        out.append({"column": c, "null": n_null, "null_pct": round(100 * n_null / total, 2)})
    return pl.DataFrame(out)


def csv_cardinality(lf: pl.LazyFrame, col: str) -> pl.DataFrame:
    """Count distribution of comma-separated values per row in a single column."""
    return (
        lf.select(
            pl.col(col).str.split(",").list.len().alias("items_per_row")
        )
        .group_by("items_per_row")
        .len()
        .sort("items_per_row")
        .collect()
    )

# %% [markdown]
# ## 1. `title.basics.tsv.gz` — title metadata
#
# Schema: `tconst, titleType, primaryTitle, originalTitle, isAdult, startYear, endYear, runtimeMinutes, genres`

# %%
basics = pl.scan_csv(
    RAW / "title.basics.tsv.gz",
    separator="\t",
    null_values=NULL,
    schema_overrides={
        "isAdult": pl.Int8,
        "startYear": pl.Int32,
        "endYear": pl.Int32,
        "runtimeMinutes": pl.Int32,
    },
    quote_char=None,  # IMDb does not quote fields
)

basics_total = basics.select(pl.len()).collect().item()
print(f"Total rows: {basics_total:,}")

# %%
print("=== First 10 rows ===")
print(basics.head(10).collect())

# %%
print("=== titleType distribution (full IMDb) ===")
titletype_dist = (
    basics.group_by("titleType")
    .len()
    .sort("len", descending=True)
    .collect()
)
print(titletype_dist)
titletype_dist.write_csv(OUT / "01_titletype_distribution.csv")

# %%
print("=== NULL rates ===")
basics_nulls = null_rates(basics)
print(basics_nulls)
basics_nulls.write_csv(OUT / "02_basics_null_rates.csv")

# %%
print("=== isAdult distribution ===")
adult_dist = basics.group_by("isAdult").len().sort("isAdult").collect()
print(adult_dist)

# %%
print("=== startYear range ===")
year_stats = basics.select([
    pl.col("startYear").min().alias("min"),
    pl.col("startYear").max().alias("max"),
    pl.col("startYear").is_null().sum().alias("null_count"),
]).collect()
print(year_stats)

# %%
print("=== Genres: distinct values across full IMDb ===")
genres_distinct = (
    basics.select(pl.col("genres").str.split(",").alias("g"))
    .explode("g")
    .filter(pl.col("g").is_not_null())
    .group_by("g")
    .len()
    .sort("len", descending=True)
    .collect()
)
print(f"Distinct genres: {genres_distinct.height}")
print(genres_distinct)
genres_distinct.write_csv(OUT / "03_distinct_genres.csv")

# %%
print("=== Genres per title cardinality (max items in CSV) ===")
genres_card = csv_cardinality(basics.filter(pl.col("genres").is_not_null()), "genres")
print(genres_card)

# %% [markdown]
# ## 2. `title.akas.tsv.gz` — alternative / localized titles
#
# Schema: `titleId, ordering, title, region, language, types, attributes, isOriginalTitle`

# %%
akas = pl.scan_csv(
    RAW / "title.akas.tsv.gz",
    separator="\t",
    null_values=NULL,
    schema_overrides={"ordering": pl.Int32, "isOriginalTitle": pl.Int8},
    quote_char=None,
)
akas_total = akas.select(pl.len()).collect().item()
print(f"Total rows: {akas_total:,}")

# %%
print("=== First 10 rows ===")
print(akas.head(10).collect())

# %%
print("=== NULL rates ===")
akas_nulls = null_rates(akas)
print(akas_nulls)
akas_nulls.write_csv(OUT / "04_akas_null_rates.csv")

# %%
print("=== Top 20 regions ===")
top_regions = (
    akas.filter(pl.col("region").is_not_null())
    .group_by("region")
    .len()
    .sort("len", descending=True)
    .head(20)
    .collect()
)
print(top_regions)

# %%
print("=== Distinct region count ===")
n_regions = (
    akas.filter(pl.col("region").is_not_null())
    .select(pl.col("region").n_unique())
    .collect()
    .item()
)
print(f"Distinct region codes: {n_regions}")

# %%
print("=== Top 20 languages ===")
top_langs = (
    akas.filter(pl.col("language").is_not_null())
    .group_by("language")
    .len()
    .sort("len", descending=True)
    .head(20)
    .collect()
)
print(top_langs)

n_langs = (
    akas.filter(pl.col("language").is_not_null())
    .select(pl.col("language").n_unique())
    .collect()
    .item()
)
print(f"Distinct language codes: {n_langs}")

# %%
print("=== AKA `types` — full distribution (IMDb says space-separated multiset) ===")
types_dist = (
    akas.filter(pl.col("types").is_not_null())
    .group_by("types")
    .len()
    .sort("len", descending=True)
    .head(40)
    .collect()
)
print(types_dist)
types_dist.write_csv(OUT / "05_akas_types_distribution.csv")

# %%
print("=== AKAs per title (cardinality at scale) ===")
akas_per_title = (
    akas.group_by("titleId")
    .len()
    .select(pl.col("len").alias("akas"))
)
stats = akas_per_title.select([
    pl.col("akas").min().alias("min"),
    pl.col("akas").max().alias("max"),
    pl.col("akas").mean().alias("mean"),
    pl.col("akas").median().alias("median"),
    pl.col("akas").quantile(0.95).alias("p95"),
    pl.col("akas").quantile(0.99).alias("p99"),
]).collect()
print(stats)

# %% [markdown]
# ## 3. `title.crew.tsv.gz` — directors + writers (CSV nconst lists)

# %%
crew = pl.scan_csv(
    RAW / "title.crew.tsv.gz",
    separator="\t",
    null_values=NULL,
    quote_char=None,
)
crew_total = crew.select(pl.len()).collect().item()
print(f"Total rows: {crew_total:,}")

# %%
print("=== First 10 rows ===")
print(crew.head(10).collect())

# %%
print("=== NULL rates ===")
crew_nulls = null_rates(crew)
print(crew_nulls)
crew_nulls.write_csv(OUT / "06_crew_null_rates.csv")

# %%
print("=== Directors per title (CSV cardinality) ===")
dir_card = csv_cardinality(crew.filter(pl.col("directors").is_not_null()), "directors")
# show distribution buckets
dir_buckets = (
    dir_card.with_columns(
        pl.when(pl.col("items_per_row") == 1).then(pl.lit("1"))
        .when(pl.col("items_per_row") <= 5).then(pl.lit("2-5"))
        .when(pl.col("items_per_row") <= 20).then(pl.lit("6-20"))
        .when(pl.col("items_per_row") <= 100).then(pl.lit("21-100"))
        .otherwise(pl.lit("100+"))
        .alias("bucket")
    )
    .group_by("bucket")
    .agg(pl.col("len").sum())
    .sort("bucket")
)
print(dir_buckets)
print(f"Max directors on a single tconst: {dir_card['items_per_row'].max()}")

# %%
print("=== Writers per title (CSV cardinality) ===")
wri_card = csv_cardinality(crew.filter(pl.col("writers").is_not_null()), "writers")
print(f"Max writers on a single tconst: {wri_card['items_per_row'].max()}")

wri_buckets = (
    wri_card.with_columns(
        pl.when(pl.col("items_per_row") == 1).then(pl.lit("1"))
        .when(pl.col("items_per_row") <= 5).then(pl.lit("2-5"))
        .when(pl.col("items_per_row") <= 20).then(pl.lit("6-20"))
        .when(pl.col("items_per_row") <= 100).then(pl.lit("21-100"))
        .otherwise(pl.lit("100+"))
        .alias("bucket")
    )
    .group_by("bucket")
    .agg(pl.col("len").sum())
    .sort("bucket")
)
print(wri_buckets)

# %% [markdown]
# ## 4. `title.episode.tsv.gz`

# %%
episode = pl.scan_csv(
    RAW / "title.episode.tsv.gz",
    separator="\t",
    null_values=NULL,
    schema_overrides={"seasonNumber": pl.Int32, "episodeNumber": pl.Int32},
    quote_char=None,
)
ep_total = episode.select(pl.len()).collect().item()
print(f"Total rows: {ep_total:,}")

# %%
print("=== First 10 rows ===")
print(episode.head(10).collect())

# %%
print("=== NULL rates ===")
print(null_rates(episode))

# %%
print("=== Episodes per parent series (max + percentiles) ===")
ep_per_series = (
    episode.group_by("parentTconst")
    .len()
    .select(pl.col("len").alias("episodes"))
)
print(ep_per_series.select([
    pl.col("episodes").min().alias("min"),
    pl.col("episodes").max().alias("max"),
    pl.col("episodes").mean().alias("mean"),
    pl.col("episodes").median().alias("median"),
    pl.col("episodes").quantile(0.95).alias("p95"),
    pl.col("episodes").quantile(0.99).alias("p99"),
]).collect())

# %%
print("=== Distinct parent series count ===")
n_series = episode.select(pl.col("parentTconst").n_unique()).collect().item()
print(f"Distinct parents: {n_series:,}")

# %% [markdown]
# ## 5. `title.principals.tsv.gz` — per-credit cast/crew (largest file: ~85M rows)

# %%
principals = pl.scan_csv(
    RAW / "title.principals.tsv.gz",
    separator="\t",
    null_values=NULL,
    schema_overrides={"ordering": pl.Int32},
    quote_char=None,
)
prin_total = principals.select(pl.len()).collect().item()
print(f"Total rows: {prin_total:,}")

# %%
print("=== First 10 rows ===")
print(principals.head(10).collect())

# %%
print("=== NULL rates ===")
prin_nulls = null_rates(principals)
print(prin_nulls)
prin_nulls.write_csv(OUT / "07_principals_null_rates.csv")

# %%
print("=== category distribution (full IMDb) ===")
cat_dist = (
    principals.group_by("category")
    .len()
    .sort("len", descending=True)
    .collect()
)
print(cat_dist)
cat_dist.write_csv(OUT / "08_principals_category_distribution.csv")

# %%
print("=== Distinct `job` values count ===")
n_jobs = principals.filter(pl.col("job").is_not_null()).select(pl.col("job").n_unique()).collect().item()
print(f"Distinct job free-text values: {n_jobs:,}")

# %%
print("=== Top 30 `job` values ===")
top_jobs = (
    principals.filter(pl.col("job").is_not_null())
    .group_by("job")
    .len()
    .sort("len", descending=True)
    .head(30)
    .collect()
)
print(top_jobs)
top_jobs.write_csv(OUT / "09_principals_top_jobs.csv")

# %%
print("=== Characters JSON cardinality (count of '\",\"' separators per non-null value) ===")
# An entry like ["A","B","C"] has two `","` separators → 3 elements.
chars_card = (
    principals.filter(pl.col("characters").is_not_null())
    .select(
        (pl.col("characters").str.count_matches('","') + 1).alias("char_count")
    )
    .group_by("char_count")
    .len()
    .sort("char_count")
    .collect()
)
print(chars_card)
chars_card.write_csv(OUT / "10_characters_cardinality.csv")
print(f"Max characters in a single credit: {chars_card['char_count'].max()}")

# %%
print("=== Principals per title (mean / max / percentiles, full IMDb) ===")
prin_per_title = (
    principals.group_by("tconst")
    .len()
    .select(pl.col("len").alias("principals"))
)
print(prin_per_title.select([
    pl.col("principals").min().alias("min"),
    pl.col("principals").max().alias("max"),
    pl.col("principals").mean().alias("mean"),
    pl.col("principals").median().alias("median"),
    pl.col("principals").quantile(0.95).alias("p95"),
    pl.col("principals").quantile(0.99).alias("p99"),
]).collect())

# %%
print("=== Credits per person (mean / max / percentiles, full IMDb) ===")
credits_per_person = (
    principals.group_by("nconst")
    .len()
    .select(pl.col("len").alias("credits"))
)
print(credits_per_person.select([
    pl.col("credits").min().alias("min"),
    pl.col("credits").max().alias("max"),
    pl.col("credits").mean().alias("mean"),
    pl.col("credits").median().alias("median"),
    pl.col("credits").quantile(0.95).alias("p95"),
    pl.col("credits").quantile(0.99).alias("p99"),
]).collect())

# %% [markdown]
# ## 6. `title.ratings.tsv.gz`

# %%
ratings = pl.scan_csv(
    RAW / "title.ratings.tsv.gz",
    separator="\t",
    null_values=NULL,
    schema_overrides={"averageRating": pl.Float32, "numVotes": pl.Int64},
    quote_char=None,
)
print(f"Total rows: {ratings.select(pl.len()).collect().item():,}")

# %%
print("=== First 10 rows ===")
print(ratings.head(10).collect())

# %%
print("=== NULL rates ===")
print(null_rates(ratings))
print("=== Stats ===")
print(ratings.select([
    pl.col("averageRating").min().alias("rat_min"),
    pl.col("averageRating").max().alias("rat_max"),
    pl.col("averageRating").mean().alias("rat_mean"),
    pl.col("numVotes").min().alias("votes_min"),
    pl.col("numVotes").max().alias("votes_max"),
    pl.col("numVotes").mean().alias("votes_mean"),
    pl.col("numVotes").median().alias("votes_median"),
]).collect())

# %% [markdown]
# ## 7. `name.basics.tsv.gz`

# %%
names = pl.scan_csv(
    RAW / "name.basics.tsv.gz",
    separator="\t",
    null_values=NULL,
    schema_overrides={"birthYear": pl.Int32, "deathYear": pl.Int32},
    quote_char=None,
)
names_total = names.select(pl.len()).collect().item()
print(f"Total rows: {names_total:,}")

# %%
print("=== First 10 rows ===")
print(names.head(10).collect())

# %%
print("=== NULL rates ===")
names_nulls = null_rates(names)
print(names_nulls)
names_nulls.write_csv(OUT / "11_names_null_rates.csv")

# %%
print("=== Distinct primaryProfession values across full IMDb ===")
prof_distinct = (
    names.filter(pl.col("primaryProfession").is_not_null())
    .select(pl.col("primaryProfession").str.split(",").alias("p"))
    .explode("p")
    .group_by("p")
    .len()
    .sort("len", descending=True)
    .collect()
)
print(f"Distinct professions: {prof_distinct.height}")
print(prof_distinct)
prof_distinct.write_csv(OUT / "12_distinct_professions.csv")

# %%
print("=== primaryProfession cardinality (CSV items per row) ===")
prof_card = csv_cardinality(names.filter(pl.col("primaryProfession").is_not_null()), "primaryProfession")
print(prof_card)
print(f"Max primaryProfession items: {prof_card['items_per_row'].max()}")

# %%
print("=== knownForTitles cardinality ===")
kft_card = csv_cardinality(names.filter(pl.col("knownForTitles").is_not_null()), "knownForTitles")
print(kft_card)
print(f"Max knownForTitles items: {kft_card['items_per_row'].max()}")

# %% [markdown]
# ## 8. Cross-file integrity at full scale
#
# All checks are lazy — polars streams them efficiently.

# %%
print("=== title.principals.tconst → title.basics.tconst ===")
basics_tconsts = basics.select("tconst").rename({"tconst": "tconst_b"})
prin_tconsts = principals.select("tconst").unique()

orphan_prin_titles = (
    prin_tconsts.join(basics_tconsts, left_on="tconst", right_on="tconst_b", how="anti")
    .select(pl.len())
    .collect()
    .item()
)
total_prin_titles = prin_tconsts.select(pl.len()).collect().item()
print(f"  principals references {total_prin_titles:,} distinct tconsts; "
      f"{orphan_prin_titles:,} are missing from title.basics ({100*orphan_prin_titles/max(total_prin_titles,1):.2f}%)")

# %%
print("=== title.principals.nconst → name.basics.nconst ===")
names_nconsts = names.select("nconst").rename({"nconst": "nconst_n"})
prin_nconsts = principals.select("nconst").unique()
orphan_prin_persons = (
    prin_nconsts.join(names_nconsts, left_on="nconst", right_on="nconst_n", how="anti")
    .select(pl.len())
    .collect()
    .item()
)
total_prin_persons = prin_nconsts.select(pl.len()).collect().item()
print(f"  principals references {total_prin_persons:,} distinct nconsts; "
      f"{orphan_prin_persons:,} are missing from name.basics "
      f"({100*orphan_prin_persons/max(total_prin_persons,1):.2f}%)")

# %%
print("=== title.episode.parentTconst → title.basics.tconst ===")
ep_parents = episode.select("parentTconst").unique()
orphan_parents = (
    ep_parents.join(basics_tconsts, left_on="parentTconst", right_on="tconst_b", how="anti")
    .select(pl.len())
    .collect()
    .item()
)
total_parents = ep_parents.select(pl.len()).collect().item()
print(f"  episode references {total_parents:,} distinct parents; "
      f"{orphan_parents:,} are missing from title.basics "
      f"({100*orphan_parents/max(total_parents,1):.2f}%)")

# %%
print("=== title.akas.titleId → title.basics.tconst ===")
akas_titles = akas.select("titleId").unique()
orphan_akas = (
    akas_titles.join(basics_tconsts, left_on="titleId", right_on="tconst_b", how="anti")
    .select(pl.len())
    .collect()
    .item()
)
total_akas_titles = akas_titles.select(pl.len()).collect().item()
print(f"  akas references {total_akas_titles:,} distinct titleIds; "
      f"{orphan_akas:,} are missing from title.basics "
      f"({100*orphan_akas/max(total_akas_titles,1):.2f}%)")

# %% [markdown]
# ## Summary
#
# Save a compact JSON of the headline numbers for cross-reference from the markdown report.

# %%
summary = {
    "row_counts": {
        "title.basics": basics_total,
        "title.akas": akas_total,
        "title.crew": crew_total,
        "title.episode": ep_total,
        "title.principals": prin_total,
        "name.basics": names_total,
    },
    "fk_orphans": {
        "principals.tconst_orphans": orphan_prin_titles,
        "principals.nconst_orphans": orphan_prin_persons,
        "episode.parent_orphans": orphan_parents,
        "akas.titleId_orphans": orphan_akas,
    },
    "max_cardinalities": {
        "directors_per_tconst": int(dir_card["items_per_row"].max()),
        "writers_per_tconst": int(wri_card["items_per_row"].max()),
        "characters_per_credit": int(chars_card["char_count"].max()),
        "primaryProfession_per_nconst": int(prof_card["items_per_row"].max()),
        "knownForTitles_per_nconst": int(kft_card["items_per_row"].max()),
        "akas_per_title": int(stats["max"].item()),
    },
    "distinct_taxonomies": {
        "genres": genres_distinct.height,
        "professions": prof_distinct.height,
        "categories": int(cat_dist.height),
        "regions": int(n_regions),
        "languages": int(n_langs),
    },
}

with open(OUT / "summary.json", "w") as f:
    json.dump(summary, f, indent=2)

print(json.dumps(summary, indent=2))
print(f"\nWrote {OUT/'summary.json'} and 12 supporting CSVs to {OUT}/")
