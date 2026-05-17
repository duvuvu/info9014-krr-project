# Raw IMDb Dataset Analysis

> **Status:** generated 2026-05-04 from the official IMDb non-commercial dump (`database/sources/imdb-official/raw/*.tsv.gz`).
> **Scope:** the *entire* IMDb dataset (~12.5 M titles, ~15.3 M persons, ~99 M principal credits) — not the filtered slice. This document complements `docs/tsv_inspection.md` (slice-level) by characterising the *full design space* the migrated CineExplorer schema must accommodate.
> **Source notebook:** `notebooks/01_imdb_raw_analysis.py` (jupytext, runnable via UV — see `notebooks/README.md`). Raw outputs in `notebooks/output/*.csv` + `summary.json`.

This document is a Phase-2 input. ERD decisions live in `docs/erd_investigation.md`.

---

## 1. Why analyse the raw data, not just the slice?

The 2,500-title slice is filtered by `numVotes DESC` — it is biased toward popular, well-cast, mainly post-2000 cinema. Designing a schema only from the slice risks missing:

- **Categorical values** that exist in IMDb but happen not to appear in the popular subset (e.g., the `Adult` genre, the `tvPilot` titleType, six malformed AKA `types`, certain rare `category` values).
- **Cardinality maxima** at scale (e.g., a tconst can have 528 directors in IMDb's full dump; the slice tops out at 97).
- **NULL patterns** that are different at scale (e.g., `birthYear` is NULL for 95.6 % of *all* persons, but only 35.5 % of persons in the slice).
- **Edge cases** like multi-character JSON arrays in `title.principals.characters` (extremely rare — 6 cases out of 99 M — but they exist and the schema must not crash on them).

A schema that assumes "max 4 directors" would be wrong; one that assumes "characters is always a single string" would corrupt data on those 6 rows; one that drops `Adult` because "we don't see it" would silently re-introduce it later if anyone reslices.

---

## 2. Headline numbers (full IMDb)

| File | Rows | Compressed |
|------|----:|----:|
| `title.basics` | **12,478,987** | 211 MB |
| `title.akas` | **57,013,962** | 472 MB |
| `title.crew` | 12,478,987 | 78 MB |
| `title.episode` | 9,637,883 | 51 MB |
| `title.principals` | **99,275,168** | 729 MB |
| `title.ratings` | 1,668,663 | 8 MB |
| `name.basics` | **15,297,466** | 289 MB |

Per-row uncompressed sizes are roughly 5×.

---

## 3. `title.basics` — title metadata

### Columns

| # | Name | Type | Distinct | Examples (top occurrences, full IMDb) | Role |
|--:|------|------|---------:|----------------------------------------|------|
| 1 | `tconst` | `tt\d+` | 12,478,987 | `tt0000001`, `tt0000002`, … (every value unique) | **PK** |
| 2 | `titleType` | enum | 11 | `tvEpisode` (9.6 M), `short` (1.1 M), `movie` (745 K), `video` (325 K), `tvSeries` (299 K) | classifies the title — full enumeration in §3.1 below |
| 3 | `primaryTitle` | string | 5,581,214 | top values are generic episode titles: `Episode #1.1` (59 K), `Episode #1.2` (54 K), `Episode #1.3` (51 K) — TV repeats the same title across shows | display title |
| 4 | `originalTitle` | string | 5,609,128 | same generic-episode pattern; original-language form when different from `primaryTitle` | production-language title |
| 5 | `isAdult` | 0 / 1 | **2** | `0` (12,071,620), `1` (407,367) | adult flag |
| 6 | `startYear` | int (YYYY) | 155, range **1874 – 2115** | `2021` (528 K), `2022` (516 K), `2023` (487 K), `2018` (472 K) | release year |
| 7 | `endYear` | int (YYYY) | 100, range **1928 – 2035** | `2019` (7.8 K), `2018` (7.7 K), `2020` (7.7 K) — typically series finales | series end (NULL for non-series) |
| 8 | `runtimeMinutes` | int | 1,018, range **0 – 3,692,080** | `30` (500 K — TV slot), `60` (358 K), `22` (226 K — sitcom slot), `45` (197 K), `15` (124 K) | running time. Max ≈ 6.8 years — data bug in IMDb |
| 9 | `genres` | CSV (max 3) | 2,392 combinations / 28 atomic genres | `Drama` (1.4 M), `Comedy` (794 K), `Talk-Show` (775 K), `News` (723 K), `Documentary` (598 K) — full taxonomy in §3.3 below | genre tags |

### titleType taxonomy (11 values)

| titleType | Count | Notes |
|-----------|----:|---|
| `tvEpisode` | 9,637,883 | dominant — most rows in IMDb are episodes |
| `short` | 1,128,967 | |
| `movie` | 745,163 | |
| `video` | 325,414 | direct-to-video releases |
| `tvSeries` | 298,867 | |
| `tvMovie` | 154,790 | |
| `tvMiniSeries` | 69,997 | |
| `tvSpecial` | 57,910 | |
| `videoGame` | 49,008 | |
| `tvShort` | 10,987 | |
| `tvPilot` | **1** | one pilot in all of IMDb |

> Note. The slice contains only 4 titleTypes (movie / tvSeries / tvMiniSeries / tvEpisode). The other 7 are absent because they have low `numVotes`. The schema should still tolerate them.

### NULL rates (out of 12.5 M)

| Column | NULL % | Comment |
|--------|---:|---|
| `endYear` | very high | only series have it |
| `runtimeMinutes` | high | ~50 % missing across full IMDb (vs 0 % in slice) |
| `genres` | moderate | many obscure titles unclassified |
| all others | ~0 % | tconst / titleType / primaryTitle / startYear are essentially complete |

### Genres taxonomy (28 distinct — matches IMDb canonical)

| Genre | Titles |
|-------|---:|
| Drama | 3,482,552 |
| Comedy | 2,407,401 |
| Talk-Show | 1,550,033 |
| Short | 1,324,418 |
| News | 1,257,417 |
| Documentary | 1,187,166 |
| Romance | 1,148,792 |
| Family | 915,307 |
| Reality-TV | 701,059 |
| Animation | 623,395 |
| Crime | 527,324 |
| Action | 526,635 |
| Adventure | 484,833 |
| Game-Show | 478,483 |
| Music | 451,823 |
| **Adult** | **407,237** | absent from slice (`isAdult` filtered) |
| Sport | 325,253 |
| Fantasy | 280,567 |
| Horror | 269,981 |
| Mystery | 269,820 |
| Thriller | 207,039 |
| History | 183,644 |
| Biography | 131,795 |
| Sci-Fi | 126,503 |
| Musical | 99,172 |
| War | 42,674 |
| Western | 31,576 |
| Film-Noir | 876 |

The slice covered **22 of these 28**; the missing 6 (`Adult`, `Talk-Show`, `News`, `Reality-TV`, `Game-Show`, `Short`) reappear at scale.

> Cardinality: `genres` is capped at 3 items per title (matches IMDb spec).

---

## 4. `title.akas` — alternative titles

### Columns

| # | Name | Type | Distinct | Examples (top occurrences, full IMDb) | Role |
|--:|------|------|---------:|----------------------------------------|------|
| 1 | `titleId` | `tt\d+` | 12,474,477 | `tt0168366` (313 akas), `tt0088814` (251), `tt0407304` (192) — most-translated titles | **FK** → `title.basics.tconst`. Note: **not** named `tconst` here |
| 2 | `ordering` | int | 313, range **1 – 313** | `1` (12,474,477 — every title has one), `2` (8.9 M), `3` (5.95 M), `4` (5.67 M), `5` (5.59 M) | sequence within a title; with `titleId` forms the **PK** |
| 3 | `title` | string | 7,884,662 | generic episode pattern in many languages: `Episodio #1.1` (117 K), `Episodio #1.2` (107 K), `Episodio #1.3` (101 K) | the alternative / localized title |
| 4 | `region` | ISO 3166 α-2 | **252** | `IN` (5.57 M), `DE` (5.50 M), `JP` (5.48 M), `FR` (5.46 M), `ES` (5.37 M) | country / region |
| 5 | `language` | ISO 639 | **111** | `ja` (5.31 M), `fr` (5.25 M), `hi` (5.22 M), `es` (5.19 M), `de` (5.18 M) | language of this aka |
| 6 | `types` | enum-ish | **24** (incl. ~6 malformed concatenations) | `original` (12.5 M), `imdbDisplay` (5.47 M), `alternative` (162 K), `working` (61 K), `video` (23 K) — full distribution in §4.4 below | aka kind |
| 7 | `attributes` | free text | 185 | `transliterated title` (31 K), `alternative spelling` (24 K), `literal English title` (20 K), `complete title` (19 K), `new title` (17 K) | extra qualifiers (mostly NULL) |
| 8 | `isOriginalTitle` | 0 / 1 | **2** | `0` (44,539,489), `1` (12,474,473 — one per title) | flags the canonical original |

### NULL rates (out of 57 M)

| Column | NULL % |
|--------|---:|
| `region` | low |
| `language` | very high (~70 %) |
| `types` | moderate |
| `attributes` | very high (~95 %) |

### Distinct dimensions

| Dimension | Distinct values |
|-----------|---:|
| Region (ISO 3166) | **251** |
| Language (ISO 639) | **110** |
| AKA `types` value | small enum + ~6 malformed concatenations (~400 rows total) |

### Top regions (full)

`US, IN, CA, ES, JP, GR, DE, GB, FI, FR, BR, PL, MX, UA, IT, RU, AR, KR, TR, NL, …`

### `types` values (most common)

| Value | Count | Note |
|-------|---:|------|
| `original` | 12,474,473 | one per title (every title has its canonical "original") |
| `imdbDisplay` | 5,469,788 | the title shown on IMDb's UI |
| `alternative` | 162,349 | |
| `working` | 61,144 | |
| `video` | 22,984 | |
| `dvd` | 22,592 | |
| `festival` | 22,123 | |
| `tv` | 19,752 | |
| `imdbDisplaydvd`, `imdbDisplaytv`, etc. | ~400 total | **malformed concatenations** — data bugs in the official dump |

> Note. IMDb's documentation says `types` is a comma-separated multiset, but in practice every value is a single token. The malformed entries are not delimited differently — they really are a single concatenated word (e.g., `imdbDisplaydvd`). The schema can treat `types` as a single string.

### AKAs per title (cardinality at scale)

- Mean: ~22 (much lower than slice's 57 — popular titles get many more akas)
- p95: not measured precisely but ~100
- **Maximum observed: 313** (full IMDb) vs 192 in slice
- Heavy long tail; the schema must allow at least **400 akas per title** with comfort.

---

## 5. `title.crew` — directors + writers

`title.crew` aggregates *all* directors and writers ever credited on a tconst, as a comma-separated nconst list. It overlaps with `title.principals.category in ('director','writer')` but goes much deeper for series.

### Columns

| # | Name | Type | Distinct | Examples (top occurrences, full IMDb) | Role |
|--:|------|------|---------:|----------------------------------------|------|
| 1 | `tconst` | `tt\d+` | 12,478,987 | `tt0000001`, `tt0000002`, … (one row per title) | **PK** + **FK** → `title.basics.tconst` |
| 2 | `directors` | CSV nconsts | 1,010,078 distinct CSV strings | top single-nconst values: `nm1203430` (11 K titles), `nm1409127` (10 K), `nm12930298` (8.1 K) — prolific TV directors | every director ever credited (max length: **528** nconsts) |
| 3 | `writers` | CSV nconsts | 1,499,829 distinct CSV strings | `nm6352729` (15.8 K titles), `nm0596393` (12.9 K), `nm7370686` (11.5 K) | every writer ever credited (max length: **1,393** nconsts) |

### Cardinality at scale

For each title in `title.crew`, count how many nconsts appear in the `directors` (resp. `writers`) comma-separated list. Group those counts into ranges — that is what **"Bucket"** means below. **"Title count"** is how many titles in all of IMDb fall into that range.

So the row `directors / 2-5 / 1,340,642` reads: *1.34 M titles have between 2 and 5 directors credited (inclusive)*. The row `directors / 100+ / max 528` reads: *some titles have more than 100 directors; the largest single value seen anywhere in IMDb is 528*.

| | Bucket (count of nconsts in the CSV list) | Title count |
|---|---|---:|
| **directors** | exactly 1 | 9,090,326 |
| | 2 – 5 | 1,340,642 |
| | 6 – 20 | 45,854 |
| | 21 – 100 | 2,211 |
| | 101 + | long tail; max value seen = **528** |
| **writers** | exactly 1 | 3,116,094 |
| | 2 – 5 | 2,772,751 |
| | 6 – 20 | 455,786 |
| | 21 – 100 | 7,393 |
| | 101 + | 266 titles; max value seen = **1,393** |

Reading: 73 % of titles have exactly 1 director; ~11 % have 2–5; the remaining ~0.4 % spread out into the heavy tail that culminates in titles with hundreds of directors. The writer distribution is shifted right (most titles have 2-5 writers).

> 528 directors on a single tconst — and 1,393 writers — are the worst-case bounds. They occur on multi-decade soap operas / news shows where every contributor over the run is aggregated. Any schema choice here matters: a normalised junction table is unavoidable (a CSV column or a fixed-width design would be wrong).

---

## 6. `title.episode` — episode-to-series links

### Columns

| # | Name | Type | Distinct | Examples (top occurrences, full IMDb) | Role |
|--:|------|------|---------:|----------------------------------------|------|
| 1 | `tconst` | `tt\d+` | 9,637,883 | each value unique (PK) | **PK** + **FK** → `title.basics.tconst` (the episode) |
| 2 | `parentTconst` | `tt\d+` | **235,869** | top parents: `tt5955216` (26,422 episodes), `tt12164062` (18,593), `tt0058796` (15,366) — long-running soaps / news shows | **FK** → `title.basics.tconst` (the series) |
| 3 | `seasonNumber` | int | 334, range **1 – 2024** | `1` (4.85 M), `2` (725 K), `3` (412 K), `4` (282 K), `5` (207 K) — extreme values are data bugs | season; NULL ~21 % |
| 4 | `episodeNumber` | int | 15,980, range **0 – 91,334** | `1` (350 K), `2` (315 K), `3` (300 K), `4` (281 K), `5` (260 K) — long tail is daily soaps | episode within season; NULL ~21 % |

### Aggregate stats

| Total rows | 9,637,883 |
|---|---:|
| Distinct parent series | **235,869** |
| `seasonNumber` NULL | 20.7 % |
| `episodeNumber` NULL | 20.7 % |

### Episodes per series

| Statistic | Value |
|-----------|---:|
| min | 1 |
| median | 8 |
| mean | 41 |
| p95 | 135 |
| p99 | 574 |
| **max** | **26,422** |

> 26k episodes for a single parent series is not a typo — it's a long-running soap or news program. Realistic upper bound for the schema's Series → Episode cardinality.

> The slice contains only 21 episodes attached to 6 series. The skew is severe.

---

## 7. `title.principals` — per-credit cast/crew (99 M rows)

### Columns

| # | Name | Type | Distinct | Examples (top occurrences, full IMDb) | Role |
|--:|------|------|---------:|----------------------------------------|------|
| 1 | `tconst` | `tt\d+` | 11,285,867 | most-credited titles: `tt0398022` (75 principals), `tt5659710` (69), `tt1438495` (66) | part of **PK** (`tconst, ordering`); **FK** → `title.basics.tconst` |
| 2 | `ordering` | int | **75**, range **1 – 75** | `1` (11.3 M — every title has one), `2` (10.2 M), `3` (9.3 M), `4` (8.5 M), `5` (7.7 M) | other half of **PK**; sequences a title's credits |
| 3 | `nconst` | `nm\d+` | 7,062,893 | most-credited persons: `nm0438471` (39,463 credits), `nm0438506` (32,258), `nm7370686` (31,884) | **FK** → `name.basics.nconst`. **Not part of the PK** — a person can appear multiple times on the same title (e.g. director-who-also-acts) and is disambiguated by different `ordering` values |
| 4 | `category` | enum | **13** | `actor` (23.5 M), `actress` (17.7 M), `self` (15.0 M), `writer` (11.9 M), `director` (8.5 M) — full taxonomy in §7.3 below | per-credit role kind |
| 5 | `job` | free text | **47,126** | `producer` (7.2 M), `writer` (1.84 M), `director` (1.00 M), `written by` (784 K), `creator` (679 K) | refinement of `category`; NULL ~81 % |
| 6 | `characters` | JSON array of strings | 4,493,431 | `["Self"]` (6.27 M), `["Self - Host"]` (2.32 M), `["Self - Guest"]` (444 K), `["Self - Contestant"]` (431 K), `["Self - Presenter"]` (407 K) | character(s) played; almost always one element; NULL ~51 % |

### NULL rates

| Column | NULL % |
|--------|---:|
| `job` | 80.9 % |
| `characters` | 51.2 % |
| `tconst, ordering, nconst, category` | 0 % |

### `category` taxonomy — **13 values** (slice has 12)

| category | Count | Note |
|----------|---:|------|
| `actor` | 23,457,533 | |
| `actress` | 17,732,782 | |
| `self` | 14,971,060 | persons appearing as themselves (talk shows, news) |
| `writer` | 11,888,962 | |
| `director` | 8,451,762 | |
| `producer` | 7,379,486 | |
| `editor` | 5,218,239 | |
| `cinematographer` | 4,010,468 | |
| `composer` | 3,191,150 | |
| `production_designer` | 1,182,366 | |
| `casting_director` | 1,144,162 | first-class IMDb category |
| `archive_footage` | 633,910 | |
| `archive_sound` | **13,288** | absent from slice; 13th category |

### `job` is high-cardinality free text

- **47,125 distinct `job` values across full IMDb.** Cannot be enumerated.
- Top values are still recognisable: `producer` (7.2 M), `writer`, `director`, `written by`, `creator`, `editor`, `composer`, `created by`, `director of photography`, `cinematographer`, `screenplay`, `story`, `head writer`, `casting_director`, `executive producer`, `dialogue`, `production_designer`, `adaptation`, …
- `job` should be modelled as a free-text VARCHAR / xsd:string, **not** an enum.

### `characters` JSON cardinality

| Items in JSON array | Credits |
|--------------------:|---:|
| 1 | 48,449,556 |
| **2** | **6** |

Across all of IMDb (99 M rows, 48 M with non-null characters), only **6 entries** have 2 character names. Functionally always single-valued, but the schema **must not break on the 6 multi-element cases**. Either explode via `JSON_TABLE` (cleanest), or accept the JSON wrapper as opaque text.

### Per-title and per-person credits

| Statistic | Principals/title | Credits/person |
|-----------|---:|---:|
| min | 1 | 1 |
| median | 8 | 1 |
| mean | 8.8 | 14 |
| p95 | 20 | 39 |
| p99 | 25 | 225 |
| **max** | **75** | **39,463** |

> 39,463 credits for a single person is real (a long-time TV cinematographer or post-production professional). The collaboration graph data structure must handle this in O(degree) operations, not O(n²).

---

## 8. `title.ratings`

### Columns

| # | Name | Type | Distinct | Examples (top occurrences, full IMDb) | Role |
|--:|------|------|---------:|----------------------------------------|------|
| 1 | `tconst` | `tt\d+` | 1,668,663 | each value unique (PK); only the ~13 % of titles that have any votes appear here | **PK** + **FK** → `title.basics.tconst` |
| 2 | `averageRating` | decimal(3,1) | **91**, range **1.0 – 10.0** | `7.2` (61 K), `7.6` (60 K), `7.4` (60 K), `7.8` (59 K), `7.0` (55 K) — distribution skews toward 7-ish | weighted average of user ratings |
| 3 | `numVotes` | int | 24,456, range **5 – 3,185,031** | `8` (65 K titles), `7` (64 K), `9` (62 K), `10` (58 K), `6` (54 K) — most rated titles have <100 votes | count of ratings; our slice criterion |

### Aggregate stats

| | Value |
|---|---:|
| Total rows | 1,668,663 |
| NULL rates | 0 across all columns |
| `averageRating` range | 1.0 – 10.0 |
| `averageRating` mean | 6.96 |
| `numVotes` range | 5 – 3,185,031 |
| `numVotes` mean | 1,037 |
| `numVotes` median | **27** |

> Most of IMDb is in the long tail: median title has 27 votes. Our slice criterion (`numVotes DESC` top-2,500) selects from the upper end where every title has 100,000+ votes. The slice is in the top **0.15 %** of titles by popularity.

---

## 9. `name.basics` — persons (15.3 M rows)

### Columns

| # | Name | Type | Distinct | Examples (top occurrences, full IMDb) | Role |
|--:|------|------|---------:|----------------------------------------|------|
| 1 | `nconst` | `nm\d+` | 15,297,466 | each value unique (PK) | **PK** |
| 2 | `primaryName` | string | 11,661,217 | most repeated names: `Alex` (593 persons), `Michael` (497), `David` (496), `Chris` (486), `David Smith` (478) | display name |
| 3 | `birthYear` | int (YYYY) | 562, range **4 – 2026** | `1980` (10.6 K), `1981` (10.3 K), `1982` (10.2 K), `1979` (10.2 K), `1978` (10.0 K) — extremes are data bugs; NULL ~96 % | birth year |
| 4 | `deathYear` | int (YYYY) | 510, range **17 – 2026** | `2021` (7.9 K), `2022` (7.5 K), `2020` (7.5 K), `2023` (7.4 K), `2025` (7.1 K); NULL ~98 % | death year (most are alive) |
| 5 | `primaryProfession` | CSV (max 3) | 26,069 distinct CSV combinations / **46 atomic values** | top atomic: `actor` (3.50 M), `actress` (2.11 M), `producer` (1.34 M), `miscellaneous` (1.22 M), `writer` (1.01 M) — full list in §9.3 below | career-level profession labels |
| 6 | `knownForTitles` | CSV tconsts (max 4) | 6,298,173 distinct CSV combinations | top single tconsts: `tt0123338` (8.3 K), `tt4202558` (7.8 K), `tt22014400` (7.5 K), `tt6168110` (6.3 K), `tt11874658` (5.3 K) | **soft FK** → `title.basics.tconst` (may reference titles outside our slice) |

### NULL rates

| Column | NULL % |
|--------|---:|
| `birthYear` | **95.6 %** |
| `deathYear` | **98.3 %** |
| `primaryProfession` | 20.1 % |
| `knownForTitles` | 11.9 % |
| `nconst, primaryName` | ~0 % |

> Compare to slice: `birthYear` 35.5 % null, `primaryProfession` 0 % null. **Selecting popular titles selects well-documented people.** The full data is much sparser.

### `primaryProfession` taxonomy — **46 distinct values**

(slice has 26)

Top: `actor` (3.5 M), `actress` (2.1 M), `producer` (1.3 M), `miscellaneous` (1.2 M), `writer` (1.0 M), `camera_department` (894 K), `director` (826 K), `production_department` (601 K), `art_department` (476 K), `cinematographer` (443 K), `sound_department` (434 K), `editor` (405 K), `composer` (384 K), …

Long tail includes: `visual_effects`, `make_up_department`, `animation_department`, `archive_footage`, `production_manager`, `script_department`, `location_management`, `production_designer`, `costume_designer`, `special_effects`, `casting_department`, `set_decorator`, `executive`, `casting_director`, `manager`, `talent_agent`, `archive_sound`, `music_artist`, `legal`, `publicist`, `assistant`, `choreographer`, `podcaster`, `accountant`, `electrical_department`, …

### Cardinality

| Field | Items per row | Capped at |
|-------|---|---:|
| `primaryProfession` | 1 / 2 / 3 only | **3** (matches IMDb spec) |
| `knownForTitles` | 1 / 2 / 3 / 4 only | **4** (matches IMDb spec) |

---

## 10. Cross-file referential integrity at full scale

| Edge | Distinct values | Orphans (in left, missing in right) | Orphan % |
|------|---:|---:|---:|
| `title.principals.tconst` → `title.basics.tconst` | 11,285,867 | **0** | 0.00 % |
| `title.principals.nconst` → `name.basics.nconst` | 7,062,893 | 1,667 | 0.02 % |
| `title.episode.parentTconst` → `title.basics.tconst` | 235,869 | 2 | 0.00 % |
| `title.akas.titleId` → `title.basics.tconst` | 12,474,477 | 56 | 0.00 % |

**Verdict.** The official dump is essentially FK-clean. The handful of orphans (a few thousand at most) are real data bugs in IMDb's own export and can be ignored or filtered during ETL — they will not require relaxed FK constraints in our schema.

---

## 11. Slice vs full data — comparison summary

| Metric | Filtered slice (N=2,500) | Full IMDb |
|--------|---:|---:|
| Titles | 2,500 | 12,478,987 |
| Persons | 21,077 | 15,297,466 |
| Principals | 53,946 | 99,275,168 |
| `titleType` distinct | 4 | 11 |
| Genres distinct | 22 | 28 |
| Categories distinct | 12 | 13 |
| Professions distinct | 26 | 46 |
| Regions distinct | many (top 15 listed) | 251 |
| Languages distinct | many (top 10 listed) | 110 |
| Max directors per tconst (`title.crew`) | 97 | 528 |
| Max writers per tconst (`title.crew`) | (large) | 1,393 |
| Max episodes per series | (small in slice) | 26,422 |
| Max akas per title | 192 | 313 |
| Max characters per credit | 1 | **2** (6 cases) |
| Max credits per person | (≤90 in slice) | 39,463 |
| `birthYear` NULL | 35.5 % | **95.6 %** |
| `deathYear` NULL | 85.4 % | 98.3 % |

---

## 12. Implications for the migrated ERD

These are **observations**, not decisions. Decisions go in `docs/erd_investigation.md` after team discussion.

1. **`category` and `primaryProfession` look similar but model two different concepts** — schema must keep them separate.

   |   | `title.principals.category` | `name.basics.primaryProfession` |
   |---|---|---|
   | Granularity | per-credit (per Participation) | per-person (per Person), career summary |
   | Cardinality per source row | 1 | up to 3 (CSV) |
   | Distinct values (full IMDb) | **13** | **46** |
   | ER role | attribute of the Person-Title *relationship* | attribute of the Person *entity* |

   Concrete contrast: Christopher Nolan has `primaryProfession = director, writer, producer` (career identity) and on *Inception* he appears as **three** rows in `title.principals` with `category` ∈ {`director`, `writer`, `producer`} (per-credit roles, distinguished by different `ordering`). Same vocabulary, two different facts.

   **Vocabulary overlap (full IMDb):**

   | Bucket | Count | Values |
   |---|---:|---|
   | In both `category` *and* `primaryProfession` | 12 | `actor, actress, writer, director, producer, editor, cinematographer, composer, production_designer, casting_director, archive_footage, archive_sound` |
   | Only in `category` | 1 | `self` — per-credit "appeared as themselves" (talk shows, news); not a profession |
   | Only in `primaryProfession` | 34 | `miscellaneous, camera_department, production_department, art_department, sound_department, music_department, assistant_director, visual_effects, make_up_department, animation_department, production_manager, script_department, location_management, costume_designer, special_effects, casting_department, set_decorator, executive, manager, talent_agent, music_artist, legal, publicist, assistant, choreographer, podcaster, accountant, electrical_department, …` (mostly department-level / off-screen) |

   **Why the current ontology conflates them.** `mapping/cineexplorer_mapping.ttl` currently types `Person rdf:type :Actor` from `title_principal.category = 'actor'` — i.e. a Person becomes an `Actor` because they had one acting credit on some title. That's defensible in spirit but loses the per-credit-vs-career distinction. A query like "directors who also acted" can't be answered cleanly because the two facts are merged.

   **Options for `docs/erd_investigation.md`:**
   - (a) **Two-axis model (recommended).** Keep `category` on `Participation` (per-credit role label) and surface `primaryProfession` on `Person` (career profession set). The 12 shared values become a single `Role` lookup; `self` is Participation-only; the 34 department-level professions are Person-only.
   - (b) **Single source.** Type Person *only* from `primaryProfession` (canonical careers); attach `category` as a free string on Participation. Simpler but throws away the precise per-credit category structure.
   - (c) **Single source, the other way.** Keep current behaviour (type Person from `category`). Simplest but conflates the concepts.
   - (d) **Drop department-level professions** as out-of-scope for the CineExplorer KG. Reduces vocabulary but loses information about persons who only do off-screen work.

   The KRR-honest answer is (a): two axes, two relations, one shared `Role` taxonomy for the 12 overlapping values.

2. **`casting_director` and `archive_footage` / `archive_sound` are first-class IMDb categories** but absent from the current ontology. Trivial to add as `Person` subclasses.

3. **`Adult` genre exists** (407 K titles). Even with `isAdult` filtering, the genre tag itself appears on non-adult titles too. Schema must include it in the `genre` enum.

4. **`title.crew` directors/writers are unbounded by IMDb** (max 528 / 1,393 in practice). A junction table is mandatory. The earlier idea of comma-separating in a `VARCHAR` would fail on a Long-running soap.

5. **`characters` is JSON; 99.99999 % single-element but the schema must not crash on the 6 multi-element rows.** `JSON_TABLE` exploding into a junction table is the right move; it produces 1 row almost always and 2 rows in 6 cases.

6. **`title.ratings` is universally populated** and **has no equivalent in the current schema**. Adding a `rating` table costs nothing and enables Q-rating SPARQL queries. Decision needed.

7. **`title.akas` is rich.** 251 regions × 110 languages × ~7 type values × free-text attributes. Worth having a dedicated `aka` table with FKs to `region` and `language` lookups (matches current schema's design).

8. **`name.basics.knownForTitles`** can reference titles that are filtered out (since the slice keeps only popular titles). FK is "soft" — the schema should not enforce it, or should allow it to be NULL when the referenced tconst isn't in the slice.

9. **NULL handling at scale is much sparser than the slice suggests.** `runtimeMinutes` ~50 % NULL across full IMDb (essentially complete in slice); `birthYear` ~95 % NULL. Mapping should use R2RML's automatic NULL skipping (already in current design — confirmed in M3 fixes).

10. **`tvPilot` (titleType, 1 row in all IMDb) and `archive_sound` (category, 13 K) are real** but absent from slice. Schema enums must include them or accept that we exclude them deliberately.

11. **AKA `types` malformed concatenations (~400 rows)** — `imdbDisplaydvd`, `alternativetv`, etc. — are real data, not delimited. The schema can treat `types` as `VARCHAR` with no enforcement; doing the same as IMDb itself.

12. **`job` is unbounded free text** (47 K distinct values). Cannot be enumerated; must be `VARCHAR`/`xsd:string`.

---

## 13. How to regenerate this report

1. Ensure raw files are downloaded (`bash database/etl/download.sh`).
2. From `notebooks/`:

   ```bash
   uv sync
   uv run python 01_imdb_raw_analysis.py
   ```

3. Outputs land in `notebooks/output/` (CSVs + `summary.json`). This document was hand-written from the script's run output; numbers above match `summary.json` (which is regenerable).

A re-run after a future IMDb refresh will produce slightly different absolute counts but the same orders of magnitude and design implications.
