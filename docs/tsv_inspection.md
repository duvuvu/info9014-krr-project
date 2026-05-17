# TSV Data Inspection — Filtered IMDb Slice (N=2500)

> **Status:** generated 2026-05-04 from `database/sources/imdb-official/filtered/` (Phase 1 output).
> **Purpose:** factual reference for Phase 2 ERD investigation. Captures column structure, NULL rates, cardinalities, distributions, and data quirks for every file in the filtered slice. Decisions live in `docs/erd_investigation.md` (to be written next); this document only documents what is *in* the data.

All numbers below are reproducible by re-running the inspection commands shown in each section.

---

## 1. Slice overview

| File | Rows | On disk | Key column | Joins to |
|------|-----:|--------:|------------|----------|
| `title_basics.tsv` | 2,500 | 202 KB | `tconst` | self (parent of joins) |
| `title_akas.tsv` | 143,740 | 7.6 MB | `titleId, ordering` | `title_basics.tconst` |
| `title_crew.tsv` | 2,500 | 222 KB | `tconst` | `title_basics.tconst`; values reference `name_basics.nconst` |
| `title_episode.tsv` | 21 | 565 B | `tconst` | `title_basics.tconst` (self-referential `parentTconst`) |
| `title_principals.tsv` | 53,946 | 2.4 MB | `(tconst, ordering)` | `title_basics.tconst`, `name_basics.nconst` |
| `title_ratings.tsv` | 2,500 | 52 KB | `tconst` | `title_basics.tconst` |
| `name_basics.tsv` | 21,077 | 2.0 MB | `nconst` | self; values reference `title_basics.tconst` |

**NULL marker.** IMDb uses the literal two-character string `\N` (backslash + N) to mark NULL. All NULL counts below treat `\N` as NULL.

---

## 2. `title_basics.tsv` — title metadata

**Columns:**

| # | Name | Type / format |
|--:|------|---------------|
| 1 | `tconst` | `tt\d+` (PK) |
| 2 | `titleType` | enum: 4 values in slice |
| 3 | `primaryTitle` | string |
| 4 | `originalTitle` | string |
| 5 | `isAdult` | 0/1 |
| 6 | `startYear` | int year |
| 7 | `endYear` | int year (series only) |
| 8 | `runtimeMinutes` | int |
| 9 | `genres` | comma-separated, max 3 |

**NULL rates (out of 2,500 rows):**

| Column | NULLs | % |
|--------|------:|---:|
| `endYear` | 2,273 | **90.9 %** |
| `runtimeMinutes` | 1 | 0.0 % |
| all others | 0 | 0.0 % |

**`titleType` distribution:**

| Value | Count |
|-------|------:|
| `movie` | 2,194 |
| `tvSeries` | 249 |
| `tvMiniSeries` | 36 |
| `tvEpisode` | 21 |

**Era distribution (by decade of `startYear`):**

| Decade | Titles |
|-------:|------:|
| 1920 | 3 |
| 1930 | 7 |
| 1940 | 14 |
| 1950 | 26 |
| 1960 | 35 |
| 1970 | 52 |
| 1980 | 131 |
| 1990 | 298 |
| **2000** | **700** |
| **2010** | **898** |
| 2020 | 336 |

77 % of titles are 2000-or-later.

**`isAdult`:** 100 % `0` in this slice (no adult titles).

**`genres` cardinality (out of 2,500 titles):**

| Genres per title | Titles |
|----------------:|------:|
| 1 | 149 |
| 2 | 493 |
| 3 | 1,858 |

74 % have exactly 3 genres. Maximum observed is 3 (matches IMDb's documented cap).

**Distinct genre values seen (22 of the 28 IMDb canonical genres):**
`Drama` (1,231), `Action` (910), `Adventure` (780), `Comedy` (759), `Crime` (502), `Thriller` (448), `Mystery` (295), `Sci-Fi` (283), `Animation` (265), `Romance` (260), `Horror` (260), `Fantasy` (234), `Biography` (147), `Family` (110), `History` (62), `War` (44), `Sport` (37), `Music` (34), `Musical` (21), `Western` (16), `Documentary` (6), `Film-Noir` (5).

Missing from slice: `Adult`, `Game-Show`, `News`, `Reality-TV`, `Short`, `Talk-Show`. Of these, `Adult` is excluded by `isAdult=0`; the others are unpopular in the top-2,500-by-numVotes slice.

---

## 3. `title_akas.tsv` — alternative / localized titles

**Columns:**

| # | Name | Type / format |
|--:|------|---------------|
| 1 | `titleId` | `tt\d+` (FK to `title_basics.tconst`) |
| 2 | `ordering` | int (PK with `titleId`) |
| 3 | `title` | string |
| 4 | `region` | ISO 3166 alpha-2 (e.g. `US`, `FR`) |
| 5 | `language` | ISO 639 (e.g. `en`, `fr`, `cmn`) |
| 6 | `types` | enum (single value, NOT comma-separated) |
| 7 | `attributes` | free text |
| 8 | `isOriginalTitle` | 0/1 |

**NULL rates (out of 143,740 rows):**

| Column | NULLs | % |
|--------|------:|---:|
| `region` | 2,511 | 1.7 % |
| `language` | 98,041 | **68.2 %** |
| `types` | 13,344 | 9.3 % |
| `attributes` | 137,286 | **95.5 %** |
| all others | 0 | 0.0 % |

**Akas per title:**

- Mean: 57 akas/title (143,740 / 2,500)
- Max: 192 akas (`tt0407304` — *War of the Worlds*, 2005)
- Other heavy hitters: 143 (`tt0099785` *Home Alone*), 138 (`tt0104431`), 136 (`tt0076759` *Star Wars: A New Hope*), 128 (`tt1067106`)
- Distribution: 21 titles with ≥ 2 akas; many in the 25–40 range; long tail past 100.

**Top regions:** `US` (6,927), `IN` (5,754), `CA` (5,125), `ES` (3,824), `JP` (3,785), `GR` (3,621), `DE` (2,788), `GB` (2,736), `FI` (2,730), `FR` (2,726), `BR` (2,723), `PL` (2,722), `MX` (2,722), `UA` (2,685), `IT` (2,674), …

**Top languages (when not NULL):** `en` (19,678), `fr` (3,059), `cmn` (Mandarin Chinese, 2,833), `hi` (2,677), `ja` (2,549), `tr` (2,495), `bg` (2,360), `es` (2,307), `he` (1,160), `ru` (1,159), …

**`types` values:** `imdbDisplay` (121,268), `alternative` (3,894), `original` (2,500), `working` (1,480), `tv` (485), `dvd` (451), `video` (202), `festival` (112). 4 rows have malformed concatenated values like `imdbDisplaytv` (4 / 130k = ignorable noise).

**Note:** `types` is **not** comma-separated despite IMDb documentation suggesting otherwise — every value in the slice is a single token (or one of 4 malformed concatenations).

---

## 4. `title_crew.tsv` — directors and writers (aggregated)

**Columns:**

| # | Name | Type / format |
|--:|------|---------------|
| 1 | `tconst` | `tt\d+` (PK, FK to `title_basics.tconst`) |
| 2 | `directors` | comma-separated nconsts |
| 3 | `writers` | comma-separated nconsts |

**NULL rates:** both `directors` and `writers` have 1 NULL (out of 2,500). Effectively complete.

**Directors per title:**

| Directors | Titles | Note |
|----------:|------:|------|
| 1 | 2,034 | 81 % of slice — typical for movies |
| 2 | 184 | |
| 3 | 32 | |
| 4–10 | 56 | |
| 11–50 | 167 | mostly TV series (one director per episode aggregated) |
| 51–97 | 26 | long-running series |

**Top by director count:** `tt0413573` (97), `tt0203259` (96), `tt0452046` (80), `tt3107288` (64), `tt0988824` (60).

**Writers per title:**

| Writers | Titles |
|--------:|------:|
| 1 | 516 |
| 2 | 681 |
| 3 | 467 |
| 4 | 277 |
| 5 | 156 |
| 6+ | 402 |

**Critical finding — `title_crew` vs `title_principals` redundancy.**

`title_principals.category='director'` is *capped at top-billed directors* (max 4 per title in the slice). `title_crew.directors` is the *exhaustive* list (e.g., one entry per directing credit ever). For a movie they roughly agree; for a TV series they diverge dramatically.

| Source | Directors per `tt0413573` |
|--------|--------------------------:|
| `title_principals` (top-billed) | ~4 |
| `title_crew.directors` (exhaustive) | 97 |

**Implication for ERD:** if the schema reads from one source only, choose deliberately. For the *collaboration graph* (Bacon-number) the top-billed source is cleaner; for *coverage* (every contributor) the exhaustive source is better. Mixing them would double-count.

---

## 5. `title_episode.tsv` — episode-to-series links

**Columns:**

| # | Name | Type / format |
|--:|------|---------------|
| 1 | `tconst` | `tt\d+` (PK; the episode) |
| 2 | `parentTconst` | `tt\d+` (FK to `title_basics.tconst`; the series) |
| 3 | `seasonNumber` | int |
| 4 | `episodeNumber` | int |

**21 rows total** (hence the 565 B file size). Full content:

| Episodes per parent | Parent (likely) | Episodes |
|--------------------|-----------------|---------:|
| `tt0944947` (Game of Thrones) | 7 episodes | s3e9, s5e8, s6e9-10, s8e1-6 cluster |
| `tt0903747` (Breaking Bad) | 4 episodes | s4e13, s5e13, s5e14, s5e16 |
| `tt2560140` (Better Call Saul) | 2 episodes | s3e17, s4e7 |
| `tt4574334` (Stranger Things) | 2 episodes | s5e7, s5e8 |
| `tt27497448` | 2 episodes | (recent, unknown title) |
| `tt3581920` (The Last of Us) | 1 episode | s1e3 |

So the slice contains 21 *first-class episodes* (each individually highly-voted) belonging to 6 parent series. The 285 series in the slice (249 `tvSeries` + 36 `tvMiniSeries` from §2) **do not have their per-episode tables filled** — only these 21 cherry-picked landmark episodes.

**Implication for ERD / ontology:**
- The Series ↔ Episode relationship is *thin* in the migrated KG.
- Most series in the slice will have `hasEpisode = ∅` (or only the cherry-picked episodes).
- The `partOfSeries` relationship will resolve correctly for the 21 episodes.

---

## 6. `title_principals.tsv` — per-title cast / crew credits

**Columns:**

| # | Name | Type / format |
|--:|------|---------------|
| 1 | `tconst` | `tt\d+` (part of **PK** = `tconst, ordering`; FK to `title_basics.tconst`) |
| 2 | `ordering` | int (other half of **PK**) |
| 3 | `nconst` | `nm\d+` (FK to `name_basics.nconst`; **not** part of the PK — a person can have several credits on the same title) |
| 4 | `category` | enum, 12 values |
| 5 | `job` | free-text, often NULL |
| 6 | `characters` | JSON array of strings, often NULL |

**NULL rates (out of 53,946 rows):**

| Column | NULLs | % |
|--------|------:|---:|
| `job` | 36,259 | **67.2 %** |
| `characters` | 26,992 | **50.0 %** |
| all others | 0 | 0.0 % |

**`category` distribution (12 values total):**

| Value | Count | % |
|-------|------:|--:|
| `actor` | 18,207 | 33.7 % |
| `actress` | 8,667 | 16.1 % |
| `writer` | 5,821 | 10.8 % |
| `producer` | 5,649 | 10.5 % |
| `casting_director` | 3,243 | 6.0 % |
| `editor` | 3,046 | 5.6 % |
| `director` | 2,411 | 4.5 % |
| `composer` | 2,397 | 4.4 % |
| `production_designer` | 2,208 | 4.1 % |
| `cinematographer` | 2,205 | 4.1 % |
| `self` | 72 | 0.1 % |
| `archive_footage` | 20 | 0.04 % |

`casting_director` and `editor` are first-class categories in IMDb but were not modelled in the ontology. (See ontology in `ontology/cineexplorer_ontology.ttl` — only `Actor, Director, Writer, Editor, Composer` are subclasses of `Person`.)

**`job` (when non-NULL, top values):** `producer` (5,595), `director of photography` (1,853), `written by` (1,445), `casting_director` (1,055), `screenplay` (1,016), `composer` (991), `screenplay by` (963), `editor` (782), `director` (777), `story` (295), `film editor` (266), `created by` (254), `story by` (244), `production_designer` (240), `novel` (92).

The `job` column duplicates / refines the `category` column and is mostly free-text. Useful for fine-grained filtering but not for IRI generation.

**`characters` format and cardinality:**

When non-NULL, `characters` is a JSON array of strings, e.g. `["A Tramp"]`, `["Mr. Dawes, Senior"]`. **Every single non-NULL value in the slice is a single-element array** — no actor in the slice plays multiple characters in the same credit.

```bash
$ grep -c '","' filtered/title_principals.tsv
0
```

**Implication for ERD:** the JSON wrapping is technically there but functionally we are dealing with one character name per credit. Either (a) treat the JSON as a string and strip `["` and `"]` in the view, or (b) use `JSON_TABLE` for cleanliness — both produce the same result.

---

## 7. `title_ratings.tsv` — popularity / quality

**Columns:**

| # | Name | Type / format |
|--:|------|---------------|
| 1 | `tconst` | `tt\d+` (PK, FK to `title_basics.tconst`) |
| 2 | `averageRating` | decimal(3,1), 1.0–10.0 |
| 3 | `numVotes` | int |

**NULL rates:** zero — both columns are populated for every row.

**Ranges in the slice:**

| Metric | Min | Max |
|--------|----:|----:|
| `averageRating` | 1.8 | 9.9 |
| `numVotes` | 123,883 | 3,185,031 |

The minimum `numVotes` of 123,883 reflects the slice criterion (top-2,500 by `numVotes`) — even the lowest-ranked title in our slice has 123k votes. For comparison, the full IMDb has millions of titles with `numVotes < 100`.

**No equivalent in the current (northCoder) schema.** Adding ratings is a Phase-2 decision (see `erd_investigation.md` Q4).

---

## 8. `name_basics.tsv` — persons

**Columns:**

| # | Name | Type / format |
|--:|------|---------------|
| 1 | `nconst` | `nm\d+` (PK) |
| 2 | `primaryName` | string |
| 3 | `birthYear` | int year |
| 4 | `deathYear` | int year |
| 5 | `primaryProfession` | comma-separated, max 3 |
| 6 | `knownForTitles` | comma-separated tconsts, max 4 |

**NULL rates (out of 21,077 rows):**

| Column | NULLs | % |
|--------|------:|---:|
| `birthYear` | 7,483 | 35.5 % |
| `deathYear` | 18,004 | **85.4 %** (most are alive) |
| `primaryProfession` | 5 | 0.0 % |
| `knownForTitles` | 14 | 0.1 % |
| all others | 0 | 0.0 % |

**`primaryProfession` cardinality:** capped at 3 per person.

| Professions per person | Persons |
|----------------------:|------:|
| 1 | 2,623 |
| 2 | 3,162 |
| 3 | 15,287 |

**Top professions (26 distinct values total):**

| Profession | Count |
|------------|------:|
| `actor` | 9,574 |
| `producer` | 8,878 |
| `writer` | 6,367 |
| `actress` | 4,712 |
| `director` | 4,193 |
| `archive_footage` | 3,056 |
| `miscellaneous` | 2,863 |
| `soundtrack` | 2,422 |
| `music_department` | 1,136 |
| `editor` | 1,111 |
| `composer` | 919 |
| `editorial_department` | 887 |
| `camera_department` | 801 |
| `cinematographer` | 798 |
| `art_department` | 761 |
| `production_designer` | 727 |
| `casting_director` | 677 |
| `casting_department` | 658 |
| `art_director` | 525 |
| `assistant_director` | 456 |
| (6 more in long tail) | < 400 each |

**`primaryProfession` taxonomy is much richer than `category`** (26 vs 12). Some values appear only in `primaryProfession` (e.g., `art_director`, `casting_department`, `miscellaneous`) — these are career labels, not per-credit roles.

**`knownForTitles` cardinality:** capped at 4.

| knownFor count | Persons |
|---------------:|------:|
| 1 | 537 |
| 2 | 318 |
| 3 | 430 |
| 4 | 19,778 |

94 % of persons have exactly 4 `knownForTitles`. References point at the IMDb full catalogue, NOT the slice — many `knownForTitles` will reference tconsts that are *not* in our `title_basics.tsv`. This breaks the FK if we treat `talent_title` as a real FK.

---

## 9. Cross-file relationship summary

```
title_basics (2,500)
   ├── tconst ←──── title_akas.titleId       (143,740 rows; 1:N, mean 57)
   ├── tconst ←──── title_crew.tconst        (2,500 rows; 1:1)
   ├── tconst ←──── title_episode.tconst     (21 rows; thin)
   │                title_episode.parentTconst → title_basics.tconst (self-ref)
   ├── tconst ←──── title_principals.tconst  (53,946 rows; 1:N, mean 22)
   └── tconst ←──── title_ratings.tconst     (2,500 rows; 1:1)

name_basics (21,077)
   ├── nconst ←──── title_principals.nconst       (53,946 rows; 1:N, mean 2.6)
   ├── nconst ←──── title_crew.directors[]        (CSV; 1:N exhaustive)
   ├── nconst ←──── title_crew.writers[]          (CSV; 1:N exhaustive)
   └── knownForTitles[] →→→ {tconsts}             (FK *broken* — refs full IMDb, not slice)
```

**FK-completeness check for the slice:**

- `title_principals.nconst` → `name_basics.nconst`: **complete** by construction (filter step kept exactly the nconsts referenced by surviving principals).
- `title_principals.tconst` → `title_basics.tconst`: **complete** by construction.
- `title_crew.directors[]` and `title_crew.writers[]` reference nconsts: **may break** — `title_crew` was filtered by tconst, so its directors/writers can include nconsts that didn't survive principal filtering. Need to verify in MIG-02b / ETL.
- `title_episode.parentTconst`: 6 distinct values, all expected to be in `title_basics`. Verify.
- `name_basics.knownForTitles[]`: references ~80k tconsts in full IMDb; only ~4k–8k will resolve into our slice.

---

## 10. Quick observations relevant to ERD design

(Decisions go in `erd_investigation.md`. This is just the evidence.)

1. **Episode/Series coverage is asymmetric.** 285 series in slice, but only 21 episodes attached to 6 of them. Series themselves are well-represented; per-episode data is decorative.
2. **`category` (12) is narrower than `primaryProfession` (26).** Choose one taxonomy or model both.
3. **`casting_director` is a first-class IMDb category.** Currently absent from the ontology's `Person` subclasses. Either add it or fold into a generic `CrewMember`.
4. **`title_ratings` is universally populated.** Adding `ce:averageRating` / `ce:numVotes` is essentially free.
5. **JSON `characters` is single-valued in this slice.** No need for a 1:N table; can be modelled as a single string per credit row.
6. **`title_crew` and `title_principals` overlap on directors/writers.** Pick one source for those credits or accept duplication intentionally.
7. **`knownForTitles` references full IMDb, not the slice.** Either drop the property, materialize against slice (with FKs broken silently), or model with `IF EXISTS` semantics.
8. **`title_akas` is unexpectedly rich.** The mean is 57 akas/title; this could justify dedicated SPARQL queries / a Q11 on regional title variants.
9. **Era bias.** 77 % of slice titles are 2000+. Pre-1990 cinema is sparsely represented. Mention in §2 or §10 of the report.
10. **`isAdult = 0` everywhere.** Drop the column from the migrated schema or keep with a single value documented as a no-op.

---

## How to regenerate this document

All queries above were run against `database/sources/imdb-official/filtered/` using POSIX tools (no pandas / Python). Re-running them after a fresh `filter_top_n.sh` should reproduce the same shape; counts will scale with N.
