# ETL Runbook — CineExplorer Source Database

This folder contains the data-ingestion pipeline that builds the MySQL source database
from the IMDb non-commercial dataset.

---

## Big picture

```
Step 1                                   Step 4 (Docker)
─────────────────────────────            ─────────────────────────────────────────
Source files (gzipped TSVs)              Filtered TSVs are mounted into the MySQL
   ↓ download.sh                         container so LOAD DATA INFILE can read them.
Raw .tsv.gz on disk                         ↓
   ↓ filter_top_n.sh                     (i)  CREATE staging tables (mirror IMDb shape)
Filtered .tsv files                      (ii) LOAD DATA INFILE — staging from filtered TSVs
   ↓ connectivity_diagnostic.sh         (iii) INSERT INTO canonical SELECT … FROM staging
Connectivity PASS verdict                      (JSON_TABLE explosions, JOINs, lookup
                                               population, actor+actress collapse,
                                               Adult-genre exclusion, etc.)
                                         (iv) DROP staging tables
                                              ↓
                                         Canonical relational schema, ready for R2RML
```

---

## Step 1 — Download

```bash
bash database/etl/download.sh
```

- Downloads 7 files (`title.basics`, `title.akas`, `title.crew`, `title.episode`,
  `title.principals`, `title.ratings`, `name.basics`) from `https://datasets.imdbws.com/`.
- Total size: ~1.6 GB compressed.
- Time: ~3–5 min on home broadband.
- **Idempotent**: re-running skips files that are already present.
- Output: `database/sources/imdb-official/raw/*.tsv.gz`.

---

## Step 2 — Filter to top-N titles

```bash
bash database/etl/filter_top_n.sh           # default N=5000
bash database/etl/filter_top_n.sh 10000     # or override
```

- Picks the top-N tconsts by `numVotes DESC` (global ranking across all title types).
- Filters every title-keyed TSV to those tconsts.
- Filters `name.basics` to only the nconsts referenced in the surviving principals.
- Time: ~30–60 sec. Disk peak: ~50 MB at N=5000.
- Output: `database/sources/imdb-official/filtered/*.tsv` plus `tconsts.txt`,
  `nconsts.txt`, and a `.n_${N}` sentinel.
- Streaming via `<(zcat ...)`: no on-disk decompression of raw files.

---

## Step 3 — Connectivity diagnostic

```bash
bash database/etl/connectivity_diagnostic.sh
```

- Verifies that the filtered slice has the bridge persons required for
  Bacon-number traversal across the collaboration graph.
- Time: <1 sec.
- Output: stdout report + `database/sources/imdb-official/filtered/connectivity_report.txt`.

**Verdict thresholds:**

| Bridge persons (in ≥ 2 titles) | Verdict | Action |
|---|---|---|
| ≥ 100 | PASS | Proceed to Step 4 |
| 20–99 | MARGINAL | Consider higher N |
| < 20 | FAIL | Re-run filter with higher N |

---

## Step 4 — Start the MySQL container

```bash
cd database
docker compose up -d
```

- Spins up `imdb-mysql` (MySQL 8.0, port 3307) and `imdb-phpmyadmin` (port 8080).
- `database/sources/imdb-official/filtered/` is mounted to `/var/lib/mysql-files/`
  inside the container so `LOAD DATA INFILE` can read the filtered TSVs.
- An empty `imdb` database is created via the `MYSQL_DATABASE` env var.

Wait for MySQL to be healthy before proceeding (~10 sec):

```bash
until docker exec imdb-mysql mysqladmin ping -h localhost -uroot -proot --silent; do sleep 2; done
```

---

## Step 5 — Build the schema and load data

```bash
docker exec -i imdb-mysql mysql -uroot -proot < database/imdb-schema.sql
```

A single all-in-one script (`database/imdb-schema.sql`) runs the full build in seven
phases inside one MySQL session:

| Phase | What it does |
|------|--------------|
| 0. Clean slate | `DROP TABLE IF EXISTS` for all canonical and staging tables, with `FOREIGN_KEY_CHECKS = 0`. Makes the script idempotent — you can re-run it on a populated DB. |
| 1. Canonical tables | `CREATE TABLE` for the 16 canonical tables (no FKs, no indexes yet). |
| 2. Staging tables | 6 `CREATE TABLE *_staging` mirroring IMDb's TSV column shape. |
| 3. LOAD DATA INFILE | Reads each filtered TSV from `/var/lib/mysql-files/<file>.tsv` into its staging table. IMDb's `\N` null marker is converted to SQL `NULL` via `NULLIF`. |
| 4. INSERT-SELECT | Populates the canonical tables from staging, including JSON_TABLE explosions, lookup population, `actor`+`actress` collapse, `Adult` genre exclusion, byte-`0x02` split for AKA types, and FK-closure on `person_known_for` via INNER JOIN. |
| 5. Drop staging | 6 `DROP TABLE` statements. Final DB has only canonical tables. |
| 6. FKs and indexes | 17 FK constraints and supporting indexes, added after population for faster INSERTs. |

End-to-end runtime is ~40–50 seconds at N=5,000.

**Approximate row counts after a successful run at N=5,000:**

| Table | Rows |
|-------|------|
| `title_type` | 9 |
| `role` | 11 |
| `profession` | ~32 |
| `language` | ~92 |
| `region` | ~244 |
| `aka_type` | 8 (seeded) |
| `title` | 5,000 |
| `person` | 38,067 |
| `title_episode` | 139 |
| `title_aka` | 256,858 |
| `principal` | 105,964 |
| `title_genre` | 13,394 |
| `person_profession` | ~80,000 |
| `person_known_for` | ~76,000 |
| `principal_character` | ~53,000 |
| `title_aka_type` | 232,494 |

---

## Step 6 — Sanity-check

```bash
docker exec imdb-mysql mysql -uroot -proot imdb -e "
SELECT 'title_type' AS t, COUNT(*) AS cnt FROM title_type
UNION ALL SELECT 'role',                COUNT(*) FROM role
UNION ALL SELECT 'profession',          COUNT(*) FROM profession
UNION ALL SELECT 'language',            COUNT(*) FROM language
UNION ALL SELECT 'region',              COUNT(*) FROM region
UNION ALL SELECT 'title',               COUNT(*) FROM title
UNION ALL SELECT 'person',              COUNT(*) FROM person
UNION ALL SELECT 'title_episode',       COUNT(*) FROM title_episode
UNION ALL SELECT 'title_aka',           COUNT(*) FROM title_aka
UNION ALL SELECT 'principal',           COUNT(*) FROM principal
UNION ALL SELECT 'title_genre',         COUNT(*) FROM title_genre
UNION ALL SELECT 'person_profession',   COUNT(*) FROM person_profession
UNION ALL SELECT 'person_known_for',    COUNT(*) FROM person_known_for
UNION ALL SELECT 'principal_character', COUNT(*) FROM principal_character;
"
```

---

## Connecting to the database

| Tool | How |
|------|-----|
| MySQL CLI inside container | `docker exec -it imdb-mysql mysql -uimdb_user -pimdb_pass imdb` |
| MySQL CLI from host | `mysql -h localhost -P3307 -uimdb_user -pimdb_pass imdb` |
| phpMyAdmin | http://localhost:8080 (user `imdb_user`, password `imdb_pass`) |

---

## Re-running

| Scenario | What to do | Time |
|---|---|---|
| Re-slice to a different N | `bash database/etl/filter_top_n.sh <N>` then connectivity diagnostic, then re-run Step 5 | ~3 min total |
| Schema bug fix | Edit `database/imdb-schema.sql`, then re-run Step 5 (Phase 0 drops and rebuilds — no need to recreate the container) | ~50 sec |
| Raw files corrupted or partially downloaded | Delete `database/sources/imdb-official/raw/*.tsv.gz` and re-run `download.sh` | ~5 min |
| IMDb published a fresh dump | Delete the raw files and re-run `download.sh` for the latest | ~5 min |

---

## Files in this folder

| File | Purpose |
|------|---------|
| `download.sh` | Curl the 7 official IMDb `.tsv.gz` files. Idempotent. |
| `filter_top_n.sh` | Filter raw dump to top-N tconsts by numVotes. |
| `connectivity_diagnostic.sh` | Validate that the slice has sufficient bridge persons for graph traversal. |
| `../imdb-schema.sql` | All-in-one schema build (canonical + staging + LOAD + INSERT-SELECT + DROP staging + FKs/indexes). Idempotent. |

---

## Disk footprint

After a complete run at N=5,000:

```
database/sources/imdb-official/
├── raw/             ~1.6 GB  (7 .tsv.gz, gitignored)
└── filtered/        ~50 MB   (7 .tsv + working files)

database/imdb-schema.sql       ~21 KB  (all-in-one schema)

MySQL container volume:
  ~150 MB (canonical tables + InnoDB overhead)
```

The raw `.tsv.gz` files can be deleted any time after Step 2 succeeds — `download.sh`
will fetch them again if needed.

---

## Implementation notes

1. **`set -o pipefail` + `head -n` is a SIGPIPE trap.** The filter scripts use
   `awk 'NR<=N'` instead of `| head -n N` in certain places to avoid SIGPIPE
   propagating as exit 141.

2. **MySQL reserved words in column aliases.** Avoid `rows`, `type`, `order` as
   alias names in `SELECT`. Column names like `TITLE_TYPE_ID` (not `TYPE`)
   deliberately steer around this.

3. **`LOAD DATA INFILE` paths inside the container.** The container reads from
   `/var/lib/mysql-files/`, mounted from `database/sources/imdb-official/filtered/`
   on the host. If you change the mount, update the `LOAD DATA INFILE` paths in
   `imdb-schema.sql`.

4. **`secure_file_priv`** is restricted to `/var/lib/mysql-files/`. The compose
   file sets this explicitly via the `command:` override.

5. **NULL marker.** IMDb uses the literal two-character string `\N` for nulls in TSV.
   `LOAD DATA INFILE` reads it as `\\N`; we convert to SQL `NULL` via
   `NULLIF(@col, '\\N')`.

6. **`actor` + `actress` collapse** happens at two places: (a) in the role-lookup
   population, where `CASE WHEN category IN ('actor','actress') THEN 'actor'` ensures
   one row in `role`; (b) in the principal INSERT where the same `CASE` resolves to
   the collapsed `role.ROLE_ID`.

7. **`Adult` genre exclusion** in the `title_genre` INSERT via
   `WHERE TRIM(j.value) <> 'Adult'`. The `is_adult` boolean column on `title`
   already carries that information.

8. **`person_known_for` dangling-FK filter** uses `JOIN title ON t.TCONST = j.value`
   to drop references to titles outside the slice.
