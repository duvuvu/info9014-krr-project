# CineExplorer — Official IMDb Migration Plan

> **Status:** active — Phase 1 complete (2026-05-04). Phase 2 (ERD investigation) starts next.
> **Phase 1 result:** N=2500 slice yields 21,077 persons / 53,946 principals; 7,386 bridge persons (35.0%) — connectivity diagnostic PASS. See `database/sources/imdb-official/filtered/connectivity_report.txt`.
> **Predecessor:** `docs/archive/2026-05_m1-m3-fixes-and-m4-roadmap.md` (M2/M3 fix cycle + M4 roadmap, all Solved).
>
> **Note (2026-05-05):** the three-file split planned below (`01_canonical_tables.sql`, `02_etl.sql`, `03_indexes.sql`) was later consolidated into a single all-in-one `database/imdb-schema.sql` (with phases 0–6 inside). References below to the split files describe the planning intent at the time; the executable lives in `database/imdb-schema.sql`.

---

## 1. Goal & Motivation

**Why migrate.** Our current source data (northCoder IMDb sample, 174 titles, 1,441 persons, 587 principal credits) has a structural property that breaks the Bacon-number demonstrator: **no person in the sample has credits on more than one title**. The collaboration graph is a disjoint union of per-title cliques, so multi-hop traversal `(ce:workedFor/ce:employed){1,2}` collapses to the 1-hop neighbourhood. The query is correct; the dataset is too sparse for the demonstration to be meaningful.

**What changes.** Replace the source data with a curated slice of the official IMDb non-commercial dataset (https://developer.imdb.com/non-commercial-datasets/), large enough that bridge persons exist and multi-hop traversal expands. Target: top **2,500** titles selected by `numVotes DESC`, with all dependent rows (principals, akas, crew, episode, names) filtered to maintain referential integrity. Slice size is parameterizable; 2,500 is the recommended starting point with 5k / 10k as fallbacks if the demonstration needs more density.

**What does not change.** Ontology and R2RML mapping are preserved. The schema-difference impact is absorbed by a SQL view layer (raw IMDb tables → views named to match current mapping column names). The KRR contributions (ontology design, R2RML methodology, SPARQL queries, SHACL shapes, demonstrator) all carry over.

**Honest scope statement (for professor).** This is "ingesting more data" *plus* a thin SQL adaptation layer to bridge minor column-name differences between the northCoder sample and the official IMDb dump. The ontology and mapping are not redesigned.

---

## 2. Decisions

Status values: `Pending` (not yet ratified) → `Solved` (confirmed and acted on, or no longer relevant).

| # | Decision | Rationale | Unblocked by | Status |
|---|----------|-----------|--------------|--------|
| D-01 | Source: official IMDb non-commercial datasets (7 TSVs) | Authoritative, reproducible, well-documented | Professor confirmation (O-01) | Pending |
| D-02 | Slice: top 2,500 titles by `numVotes DESC` (parameterizable; 5k / 10k as fallback) | Popular titles share casts → dense collaboration graph → meaningful Bacon number | Professor confirmation (O-03) | Pending |
| D-03 | Schema strategy: **staging tables** loaded by `LOAD DATA INFILE`, transformed into **canonical tables** via `INSERT … SELECT`, staging dropped after load. Final DB has only the canonical tables (matching the ERD). | Textbook ERD → relational model → CREATE TABLE → ingest flow. Final DB = canonical tables only. Avoids the "two-layer DB" of a persistent raw+views architecture. | Internal — revised after Phase 2 mapping rewrite (Q01, Q02, Q04) made the original "preserve mapping" justification obsolete | **Decided (revised 2026-05-04)** |
| D-04 | Comma-separated fields (`genres`, `directors`, `writers`, `primaryProfession`, `knownForTitles`) exploded into rows during the staging-to-canonical `INSERT … SELECT` step (using MySQL 8 `JSON_TABLE`). | Keeps transformation in SQL; staging mirrors IMDb's CSV-list shape, canonical normalises into junction tables | Internal — confirmed at MIG-04 implementation | Pending |
| D-05 | Raw TSVs gitignored; ETL script reproduces them | Full IMDb dump ~5 GB compressed, infeasible to commit | Internal | Pending |
| D-06 | Filtered TSVs: commit if <100 MB, else gitignore + rely on deterministic ETL | Reproducibility vs repo size tradeoff | Professor confirmation (O-04) + actual file size after MIG-06 | Pending |
| D-07 | KG output (`output/cineexplorer_kg.ttl`): gitignore the full file, commit a 100-title sample under `output/sample/` | Full KG likely ~100 MB Turtle | Actual KG size after MIG-11 | Pending |
| D-08 | Migration on a fresh feature branch (`feature/imdb-official` off `feature/draft-m4`) | Clean fallback; one cleanup commit at end removes northCoder data | Internal — team decision | Pending |
| D-09 | Non-trivial demonstrator: keep Bacon number after migration | Will produce meaningful results once graph is connected | Professor confirmation (O-02) + MIG-14 verification | Pending |
| D-10 | Filter strategy: **bash + awk pre-filter** (default), with three documented alternatives (Pure SQL, Python/pandas, Hybrid SQL+bash) | Fastest under our `docker compose down -v && up` workflow; no extra deps; ~1.5 min cold start vs ~45 min for Pure SQL | Internal — team decision | Pending |

---

### D-01 · Source — official IMDb non-commercial datasets

**Decision:** Replace the northCoder sample with the seven TSV files published at https://developer.imdb.com/non-commercial-datasets/ (`title.basics`, `title.akas`, `title.crew`, `title.episode`, `title.principals`, `title.ratings`, `name.basics`).

**Why this option:**
- **Identifier compatibility.** Both datasets use `tconst` / `nconst` — no IRI scheme change required (`http://cineexplorer.local/data/title/tt…` and `…/person/nm…` continue to work).
- **Authoritative source.** It is *the* IMDb dump, refreshed daily, used widely in academic work. Easy to cite.
- **Free for non-commercial / academic use.** License explicitly permits research use with attribution.
- **Comprehensive coverage.** Tens of millions of titles and persons, so even a 2.5k-title slice has dense intra-slice connectivity.

**Alternatives considered and rejected:**
- *Stay with northCoder sample* — exactly the problem we are solving (sparse collaboration graph).
- *TMDb / OMDb APIs* — rate-limited, would force online ETL during builds; identifier scheme differs from current IRIs.
- *MovieLens benchmark* — ratings-centric, lacks principal cast/crew breakdown needed for Bacon-number traversal.
- *Wikidata SPARQL endpoint as source* — would conflate "data source" with "federated target" and complicate the demonstrator narrative.

**Consequences:** Schema layout in `database/sources/imdb-official/` and ETL scripts in `database/etl/`. Triggers MIG-03..MIG-08.

**Unblocking criterion:** Professor confirms migration is acceptable for M4 scope (O-01).

---

### D-02 · Slice — top 2,500 titles by `numVotes DESC`

**Decision:** From `title.ratings.tsv`, take the **2,500** `tconst`s with the highest `numVotes`. Keep all rows of dependent files (`title.principals`, `title.akas`, `title.crew`, `title.episode`, `name.basics`) that reference any of those tconsts. Persons are then the union of nconsts referenced by the kept principal/crew rows. The slice size `N` is exposed as a `--n` flag on the ETL script; 2,500 is the default, 5,000 and 10,000 are documented fallbacks.

**Why 2,500 and not 10,000:**
- **Connectivity is solved well below 10k.** Top-1k by numVotes already covers franchise cinema (Marvel, Star Wars, LOTR, etc.) where actors recur heavily; 2-hop strictly exceeds 1-hop reachability at this scale.
- **Pipeline iteration speed.** R2RML extraction, Fuseki load, and SHACL validation all scale roughly linearly with KG size. At ~2,500 titles the full pipeline turns around in minutes; at 10k it climbs to tens of minutes — material when debugging.
- **Filtered slice fits under git's comfort zone.** ~2.5k titles → ~25 MB filtered TSVs (well under the 100 MB threshold in D-06), making D-06's "commit filtered slice" path viable. At 10k the filtered set is closer to the threshold.
- **Demo-readability.** SPARQL queries against a 2,500-title KG run in sub-second; reviewers can poke around interactively.

**Rough scaling estimates** (extrapolating with denser principal lists than the northCoder sample):

| Slice | Triples (est.) | Principal credits | Unique persons | KG file size |
|-------|----------------|-------------------|----------------|--------------|
| 1,000 | ~150k | ~10k | ~6k | ~15 MB |
| 2,500 | ~400k | ~25k | ~15k | ~40 MB |
| 5,000 | ~800k | ~50k | ~30k | ~80 MB |
| 10,000 | ~1.5M | ~100k | ~60k | ~150 MB |

**Why this option overall:**
- **Connectivity.** High-vote titles are mainstream films and TV; their casts overlap heavily (working actors accumulate dozens of credits across popular productions). This is exactly what Bacon-number traversal needs.
- **Reproducible.** `numVotes DESC` is deterministic; anyone running our ETL gets the same slice (modulo IMDb's daily refresh).

**Alternatives considered and rejected:**
- *Random sample of N titles* — most randomly selected titles are obscure with thin cast data; Bacon-number problem persists.
- *Stratified by year or genre* — adds complexity; offers no clear advantage for collaboration-graph density.
- *Sequential first N by `tconst`* — IMDb's earliest tconsts are 1890s silent shorts with no cast data; degenerate.
- *Full dataset (~10M titles)* — KG would exceed Fuseki/Brwsr comfort zone on the deployment laptop; unnecessary for the demonstrator.
- *N = 1,000* — marginal speed gain over 2.5k at the cost of a thinner connectivity safety margin.
- *N = 10,000* — original proposal; rejected as overkill (see scaling table) and slower iteration.

**Consequences:** Slice criterion lives in `database/etl/filter_top_n.sh` (N defaults to 2,500). Slice size is parameterizable in case the prof prefers a different number. (Implementation strategy — bash vs SQL vs Python — is covered separately by D-10.)

**Measured outcome (Phase 1, 2026-05-04):** N=2,500 produced 21,077 unique persons and 53,946 principal credits — about 40 % more persons than the rough estimate in the scaling table (which predicted ~15k). 7,386 persons (35.0 %) span ≥ 2 titles, so the connectivity threshold is comfortably exceeded. Total filtered size 13 MB, well under the 100 MB commit threshold from D-06.

**Unblocking criterion:** Professor confirms 2,500 is appropriate (O-03). If "too small", bump to 5,000 or 10,000 by passing the new value as the first argument to `filter_top_n.sh` — no code change needed. Phase 1 already shows N=2,500 is sufficient; bumping N is no longer expected.

---

### D-03 · Schema strategy — staging tables, transformed via SQL, dropped after load

**Decision (revised 2026-05-04).** Standard textbook flow:

```
ERD  →  Relational model  →  CREATE TABLE (canonical schema)  →  ingest data  →  R2RML reads canonical
```

Mechanism for "ingest data":

1. `LOAD DATA INFILE` writes filtered TSVs into **staging tables** that mirror IMDb's TSV shape (one staging table per filtered TSV file).
2. `INSERT INTO canonical SELECT … FROM staging` (with all the transformations: CSV explode via `JSON_TABLE`, JSON unwrap on `characters`, ratings JOIN onto Title, lookup-table population, etc.) — this is `02_etl.sql`.
3. `DROP TABLE` for each staging table after ETL completes.

**Final state of MySQL** = only the canonical tables (matching the ERD diagram and the report). Staging tables exist for ~30 seconds during the load phase, then are gone.

**Why this revision (vs the original "raw tables + views" design):**

- The original D-03 was justified by "preserves mapping unchanged" — i.e., we'd reuse the existing northCoder R2RML mapping. **Phase 2 (Q01 / Q02 / Q04) is rewriting the mapping anyway** (new Person typing, new Participation Role classes, switched director/writer source). The "preserve mapping" justification no longer applies.
- Without that constraint, the textbook flow is cleaner: the ERD reduces to relational model → CREATE TABLE → INSERT data. Staging tables are an *implementation detail* of the load step; they don't survive in the schema and don't appear in the ERD diagram or the report.
- Matches the northCoder precedent (`title_principal_raw` → INSERT-SELECT → DROP).

**Alternatives considered and rejected (re-evaluated 2026-05-04):**

| Option | Verdict |
|---|---|
| (α) ETL in bash/Python pre-loads canonical-shape data | More code in bash/Python; loses SQL-only transformation discipline |
| **(β) Staging tables, dropped after load** | **Chosen.** Textbook ETL, SQL-only transformation, final DB = canonical only |
| (γ) Persistent raw tables + SQL views (original D-03) | Final DB has two layers; raw tables are dead weight after migration |

**Consequences:**

- `database/schema/01_canonical_tables.sql` defines the canonical schema (the ERD reduced to relational model). This is what the report describes as "the schema".
- `database/schema/02_etl.sql` contains: (i) staging-table CREATE TABLEs, (ii) `LOAD DATA INFILE` for each filtered TSV, (iii) `INSERT INTO canonical SELECT … FROM staging` for each canonical table, (iv) `DROP TABLE` for each staging table.
- `database/schema/03_indexes.sql` adds FKs and indexes after population.

**Unblocking criterion:** Phase 2 finalises the canonical schema (`erd_investigation.md`); then `01_canonical_tables.sql` and `02_etl.sql` can be written.

---

### D-04 · Comma-separated fields exploded via `JSON_TABLE`

**Decision:** For the official IMDb fields stored as comma-separated strings (`title_basics.genres`, `title_crew.directors`, `title_crew.writers`, `name_basics.primaryProfession`, `name_basics.knownForTitles`), the `INSERT … SELECT` step in `02_etl.sql` explodes each comma-separated value into one row using MySQL 8's `JSON_TABLE`:

```sql
INSERT INTO title_genre (tconst, genre_id)
SELECT b.tconst,
       g.genre_id
FROM   title_basics_staging b
JOIN   JSON_TABLE(
         CONCAT('["', REPLACE(b.genres, ',', '","'), '"]'),
         '$[*]' COLUMNS (value VARCHAR(64) PATH '$')
       ) j
JOIN   genre g ON g.genre_name = TRIM(j.value)
WHERE  b.genres IS NOT NULL;
```

**Why this option:**
- **Native to MySQL 8** (already our DB version). No extension, no UDF.
- **Pure SQL.** Lives inside `02_etl.sql` alongside all other transformations. Consistent with D-03 (staging-tables architecture).
- **Deterministic + indexable** if performance becomes an issue.

**Alternatives considered and rejected:**
- *Pre-process during ETL into separate tables* — splits the projection across Python and SQL, harder to review.
- *Recursive CTE / `STRING_SPLIT`* — `STRING_SPLIT` is SQL Server, not MySQL; recursive CTEs work but are clunkier than `JSON_TABLE`.
- *Add a `genres_normalized` table to the raw layer* — duplicates information; the view approach has zero materialization cost.

**Consequences:** `02_views.sql` will contain ~5 `JSON_TABLE` views (one per comma-separated field). Performance on 100k+ rows is acceptable but should be checked at MIG-08; if slow, materialize as a real table during load.

**Unblocking criterion:** MIG-08 smoke test confirms acceptable wall-clock to materialize the views during R2RML extraction.

---

### D-05 · Raw TSVs gitignored

**Decision:** `database/sources/imdb-official/raw/*.tsv.gz` is gitignored. The ETL script `database/etl/download.sh` curls them from `https://datasets.imdbws.com/`. README documents the download step.

**Why this option:**
- **Size.** The full IMDb dump is ~5 GB compressed, ~25 GB uncompressed. Not feasible for git, even with LFS.
- **Reproducibility preserved.** The dump is publicly hosted, daily-refreshed, and the URLs are stable; `download.sh` is fully deterministic.
- **Licence-friendly.** Avoids redistributing IMDb data through our repository, which their non-commercial licence does not unambiguously permit.

**Alternatives considered and rejected:**
- *Commit raw* — repository bloat.
- *Git LFS* — adds infrastructure overhead for a freely-downloadable file.
- *Internal mirror* — overkill for a course project.

**Consequences:** `.gitignore` line for `database/sources/imdb-official/raw/`. README step 1 = "run `bash database/etl/download.sh`".

**Unblocking criterion:** None — operational decision.

---

### D-06 · Filtered TSVs — conditional commit

**Decision:** After `filter_top_n.sh` produces the slice, measure total size of `database/sources/imdb-official/filtered/`. If <100 MB, commit it. Otherwise gitignore it and treat the ETL as the source of truth.

**Measured outcome (Phase 1, 2026-05-04):** Filtered set at N=2,500 is **13 MB total** (largest single file: `title_akas.tsv` at 7.6 MB). Well under the 100 MB threshold → **filtered slice will be committed**. The `.gitignore` in `database/sources/imdb-official/` ignores `raw/` but tracks `filtered/`.

**Why this option:**
- **Reproducibility for reviewers.** A committed filtered set lets the prof / TA reproduce our results without running the full download + filter pipeline.
- **Repo health.** A 100 MB threshold is conservative; standard advice is to keep individual files under 50 MB and total repo under a few hundred MB.
- **Defensive against IMDb refresh drift.** If we commit the filtered TSVs, our reported numbers are reproducible even after IMDb pushes a new daily dump that would otherwise change `numVotes` orderings.

**Alternatives considered and rejected:**
- *Always commit* — risks bloat if the slice grows.
- *Never commit* — forces every reviewer through the ETL.
- *LFS for filtered/* — possible but adds infrastructure for marginal benefit.

**Consequences:** Need an explicit check after MIG-06 to size the slice and decide. README must document either path.

**Unblocking criterion:** Professor confirms preferred reproducibility model (O-04) and actual filtered size after MIG-06.

---

### D-07 · KG output policy

**Decision:** `output/cineexplorer_kg.ttl` (the full generated KG) is gitignored. A 100-title sample slice is committed under `output/sample/cineexplorer_kg_sample.ttl`. README documents how to regenerate the full KG via the R2RML pipeline.

**Why this option:**
- **Size.** Even at 2,500 titles the KG may approach 40 MB Turtle; at 10k fallback it is well over 100 MB. Gitignoring the full KG keeps the policy stable across slice sizes.
- **Reviewer ergonomics.** A small committed sample lets the prof open the KG in Protégé / a text editor to inspect structure without running anything.
- **Reproducibility.** R2RML pipeline is deterministic; rerunning produces the same output up to triple ordering.

**Alternatives considered and rejected:**
- *Commit full KG* — repo bloat.
- *Gitignore everything* — reviewer has to run the full pipeline to see any KG.
- *Single tiny inline example in the report* — already done in §7; the sample file is for end-to-end inspection.

**Consequences:** `.gitignore` line for `output/cineexplorer_kg.ttl`. New `output/sample/` folder + a small generator script (or a manual subset of the full KG).

**Unblocking criterion:** Actual KG size after MIG-11 confirms the threshold is binding.

---

### D-08 · Migration on a fresh feature branch

**Decision:** Branch `feature/imdb-official` off `feature/draft-m4`. All migration commits land on this branch. A single final commit removes the northCoder data. Merge to `feature/draft-m4` (or `develop`) only after MIG-14 verification passes.

**Why this option:**
- **Clean rollback.** If migration stalls, `feature/draft-m4` remains a fully working M4 system.
- **Reviewable diff.** The migration is a single PR, easy for teammates and the prof to inspect.
- **Atomic cleanup.** Removing northCoder data in a dedicated commit makes the deletion legible in `git log`.

**Alternatives considered and rejected:**
- *Commit directly on `feature/draft-m4`* — mixes migration with any other M4 polishing work; harder to revert.
- *Commit to `develop`* — same problem, plus pollutes the integration branch with WIP.
- *Multiple short-lived branches per task* — unnecessary overhead for a focused migration.

**Consequences:** All migration tasks (MIG-01..MIG-22) are committed on `feature/imdb-official`.

**Unblocking criterion:** None — internal team decision.

---

### D-09 · Non-trivial demonstrator — keep Bacon number after migration

**Decision:** Continue to use Bacon-number / collaboration-graph traversal as the non-trivial demonstrator. SHACL stays as the second demonstrator (Demonstrator B in `docs/demonstrator_reference.md`).

**Why this option:**
- **Marginal cost.** The query already works; only the dataset is changing. After migration, MIG-14 verifies that 2-hop reachability strictly exceeds 1-hop, finally giving the demonstrator real meaning.
- **Continuity.** Report §10, demonstrator reference, and SPARQL queries Q6/Q6b are already written. No new conceptual work.
- **Course fit.** Property paths + reachability analysis is squarely on-syllabus (L05).

**Alternatives considered and rejected (suggested by professor on 2026-05-04):**
- *Advanced SHACL / ShEx exercises* — interesting, but our SHACL section is already non-trivial (OWA-vs-CWA contrast). Marginal addition.
- *FacadeX (declarative integration)* — would mean adding a second integration approach on top of R2RML; large scope expansion.
- *Graph embeddings for concept similarity* — requires the deep-learning course, which not all team members have taken.
- *LangChain + LLM over the KG* — interesting but pulls focus away from KRR fundamentals.

**Consequences:** Bacon-number queries Q6/Q6b stay; Q6b's `{1,2}` quantifier is replaced with a SPARQL 1.1-portable union form (already noted in `docs/demonstrator_reference.md` review).

**Unblocking criterion:** Professor confirms direction (O-02). MIG-14 confirms multi-hop expansion is observable on the new dataset. If either fails, fall back to one of the alternatives — likely advanced SHACL since it has the lowest setup cost.

---

### D-10 · Filter strategy — bash pre-filter (default), three documented alternatives

**Decision:** Filter the official IMDb TSVs *before* loading them into MySQL, using a small `bash + awk` script (`database/etl/filter_top_n.sh`). The `LOAD DATA INFILE` step then ingests only the ~25 MB filtered slice, so a full `docker compose down -v && up && load.sh` cycle completes in ~1.5 minutes after the one-time download + `gunzip`.

**Workflow assumption.** Our normal iteration is `docker compose down -v && docker compose up -d && bash database/etl/load.sh`. Each iteration starts from an empty MySQL volume, so the LOAD step's cost is paid every time. This makes the cost of loading the *full* IMDb dump (≈45 minutes) prohibitive; we want the LOAD to be fast.

**Why bash specifically:**
- **Smallest tool surface.** `bash`, `awk`, `gzip`, `sort`, `head` — all POSIX-standard, present on every dev machine.
- **No Python dependency.** Avoids `requirements.txt`, virtualenv setup, and version coordination across the team.
- **Streaming, low-memory.** `awk 'NR==FNR{k[$1]=1;next} k[$1]'` is the canonical "filter file 2 by keys in file 1" idiom; runs in ~10 MB of memory regardless of input size.
- **Iteration speed.** Re-slicing (e.g. N=2.5k → N=5k) takes ~30 seconds.
- **Slice criterion is grep-able.** `head -n "$N"` after a `sort -k3 -n -r` is one line; the prof can read it.

**Sketch of `filter_top_n.sh`:**
```bash
#!/usr/bin/env bash
set -euo pipefail
N="${1:-2500}"
RAW=database/sources/imdb-official/raw
OUT=database/sources/imdb-official/filtered
mkdir -p "$OUT"

# Step 1: top-N tconsts by numVotes
tail -n +2 "$RAW/title.ratings.tsv" \
  | sort -t$'\t' -k3 -n -r | head -n "$N" | cut -f1 > "$OUT/tconsts.txt"

# Step 2: filter each title-keyed TSV by tconsts.txt
for f in title.basics title.akas title.crew title.episode title.principals title.ratings; do
  ( head -n 1 "$RAW/$f.tsv"
    awk -F'\t' 'NR==FNR{k[$1]=1;next} k[$1]' "$OUT/tconsts.txt" "$RAW/$f.tsv"
  ) > "$OUT/${f//./_}.tsv"
done

# Step 3: collect surviving nconsts and filter name.basics
cut -f3 "$OUT/title_principals.tsv" | tail -n +2 | sort -u > "$OUT/nconsts.txt"
( head -n 1 "$RAW/name.basics.tsv"
  awk -F'\t' 'NR==FNR{k[$1]=1;next} k[$1]' "$OUT/nconsts.txt" "$RAW/name.basics.tsv"
) > "$OUT/name_basics.tsv"
```

#### Alternatives considered

We evaluated four approaches end-to-end. The detailed comparison is preserved here so future readers (and the professor) can see the trade-off.

##### Alternative A — Pure SQL (load full dump, filter in SQL)

- **Files:** `database/etl/{download.sh,load.sh}` + `database/schema/{01_raw_tables.sql, 02_load_full.sql, 03_filter.sql, 04_views.sql, 05_indexes.sql}` (5 schema files).
- **Filtering logic:** `LOAD DATA INFILE` ingests all 7.6 GB. `03_filter.sql` then runs `CREATE TABLE … AS SELECT … WHERE tconst IN (SELECT … FROM title_ratings_raw ORDER BY numVotes DESC LIMIT 2500)` for each table, then `DROP TABLE …_raw`.
- **Cold-start time:** **~35–60 min** (dominated by the 30–50 min full `LOAD DATA INFILE`).
- **Re-slice time under our workflow:** **same as cold start** — `down -v` discards the raw tables, so every rebuild reloads 7.6 GB.
- **Disk peak:** ~20 GB (raw `.tsv` on disk + raw tables inside MySQL).
- **Pros:** Most declarative; slice criterion is a clean SQL `LIMIT`; matches the prof's "ingest more data into the existing database" framing most literally.
- **Cons:** The 45-minute LOAD penalty hits every `docker compose down -v && up`, which is our default workflow. Iteration is impractical.
- **Rejected because:** Iteration cost is incompatible with our docker-rebuild workflow. Would only be acceptable if we kept the raw tables loaded permanently (~12 GB inside MySQL) and used Cycle B (in-place re-ingest) instead.

##### Alternative B — Python (pandas)

- **Files:** `database/etl/{download.sh, filter_top_n.py, requirements.txt, load.sh}` + `database/schema/{01_tables.sql, 02_views.sql, 03_indexes.sql}` (3 schema files).
- **Filtering logic:** ~40 lines of pandas; reads each `.tsv` into a DataFrame, filters with `.isin()`, writes filtered output.
- **Cold-start time:** **~2.5 min post-setup** (pandas is ~1 min slower than awk because it loads `title.principals` ~85M rows into a ~3 GB DataFrame).
- **Re-slice time:** ~2 min.
- **Disk peak:** same as bash (~9 GB during raw, drops to ~1.5 GB after).
- **Pros:** Pandas joins are familiar to anyone with Python data-science background; type handling is more explicit.
- **Cons:** Adds Python + pandas as a project-wide dependency for a feature that bash does in fewer lines; ~3 GB memory footprint on `title.principals`; `requirements.txt` to maintain across teammates.
- **Rejected because:** Strictly worse than bash for this project — same architecture, same speed class, but with more deps and more memory. Would only be preferred if we already had Python tooling elsewhere in the project (we don't).

##### Alternative C — Hybrid (SQL picks slice, bash filters TSVs)

- **Files:** `database/etl/{download.sh, pick_tconsts.sh, filter_by_tconsts.sh, load.sh}` + `database/schema/{00_ratings_only.sql, 01_pick_slice.sql, 02_tables.sql, 03_views.sql, 04_indexes.sql}` (5 schema files).
- **Filtering logic:** Load only `title.ratings.tsv` (~25 MB) into a temporary MySQL table. Run `SELECT tconst … ORDER BY numVotes DESC LIMIT 2500 INTO OUTFILE '/var/lib/mysql-files/tconsts.txt'`. Copy the file out of the container. Run the same awk filter as the bash approach to slice the other 6 TSVs by those tconsts.
- **Cold-start time:** **~1.5 min post-setup** (same as bash; the extra ratings load is ~5 sec).
- **Re-slice time:** ~1 min.
- **Disk peak:** same as bash.
- **Pros:** Slice criterion lives in clean SQL (`LIMIT 2500`) — best for the report / prof framing. Filter execution is still streaming-fast.
- **Cons:** 5 schema files instead of 3; orchestration crosses two languages; one extra `docker cp` to extract the tconsts file from the container.
- **Considered as a fallback:** If the prof specifically asks "show me the slice criterion in SQL", we can switch to this with low effort — the awk filter logic is identical.

##### Alternative D — Bash pre-filter — **CHOSEN**

(See main text above.)

#### End-to-end timing summary

| Approach | Cold start (post-setup) | Re-slice (our workflow) | Disk peak | New deps |
|---|---|---|---|---|
| A — Pure SQL | 30–60 min | **30–60 min** (every rebuild) | ~20 GB | none |
| B — Python | ~2.5 min | ~2 min | ~9 GB | Python + pandas |
| C — Hybrid | ~1.5 min | ~1 min | ~9 GB | none |
| **D — Bash (chosen)** | **~1.5 min** | **~1 min** | **~9 GB** | **none** |

(One-time setup — download + `gunzip` — is ~5–7 min, paid once per machine.)

**Consequences for the plan:**
- §3 folder structure: `database/etl/filter_top_n.sh` (bash), schema files for the staging-tables architecture (`01_canonical_tables.sql`, `02_etl.sql`, `03_indexes.sql`) per D-03.
- MIG-06 writes the bash filter; the alternatives stay documented here as fallback paths.
- No `scripts/` folder, no `requirements.txt`. The only Python dependency in the project remains `pyshacl` (CLI tool, not a script we write).

**Unblocking criterion:** Internal team decision. Switchable to Hybrid (Alternative C) at low cost if prof feedback specifically asks for SQL-declared slice criterion.

---

## 3. Target Folder Structure

(Marks: NEW, CHANGED, UNCHANGED, REMOVED.)

```
info9014-krr-project/
├── database/                                CHANGED (restructured)
│   ├── docker-compose.yml                   UNCHANGED
│   ├── README.md                            CHANGED — describes official IMDb workflow
│   ├── schema/                              NEW (D-03 staging-tables architecture)
│   │   ├── 01_canonical_tables.sql          NEW — CREATE TABLE for the canonical schema
│   │   │                                          (the ERD reduced to relational model;
│   │   │                                          this is what the report describes).
│   │   │                                          Decided by Phase 2 ERD investigation
│   │   │                                          (see MIG-02 / MIG-02c).
│   │   ├── 02_etl.sql                       NEW — (i) staging-table CREATE TABLEs
│   │   │                                          (mirror IMDb TSV shape),
│   │   │                                          (ii) LOAD DATA INFILE for each filtered
│   │   │                                          TSV → staging,
│   │   │                                          (iii) INSERT INTO canonical
│   │   │                                          SELECT … FROM staging (with all
│   │   │                                          transformations: CSV explode,
│   │   │                                          JSON unwrap, ratings JOIN, …),
│   │   │                                          (iv) DROP TABLE for each staging table.
│   │   └── 03_indexes.sql                   NEW — FKs + indexes on canonical tables
│   │                                              (after population, for fast LOAD).
│   ├── sources/                             NEW
│   │   └── imdb-official/
│   │       ├── README.md                    NEW
│   │       ├── raw/                         NEW (gitignored)
│   │       └── filtered/                    NEW (gitignored or LFS)
│   ├── etl/                                 NEW
│   │   ├── download.sh                      NEW
│   │   ├── filter_top_n.sh                  NEW — bash + awk pre-filter (default N=2500;
│   │   │                                          first positional arg overrides)
│   │   └── load.sh                          NEW
│   ├── csv-data/                            REMOVED (cleanup commit)
│   └── imdb-schema.sql                      REMOVED (cleanup commit)
├── ontology/                                UNCHANGED
├── mapping/                                 UNCHANGED
├── tools/r2rml/                             UNCHANGED
├── output/
│   ├── cineexplorer_kg.ttl                  regenerated (gitignored)
│   └── sample/                              NEW — 100-title slice for reviewers
├── sparql/                                  UNCHANGED files; results regenerated
├── deployment/                              UNCHANGED
├── report/                                  CHANGED — numbers in §2, §10
└── docs/                                    CHANGED — see migration tasks
```

---

## 4. Migration Tasks

Status values: `Pending` → `In progress` → `Done`. Tasks are organised into five phases with explicit checkpoints. Within each phase, tasks are ordered by dependency.

**Why phased.** The KRR project workflow is *conceptual schema (ERD) → relational model (SQL DDL) → R2RML mapping*. Designing the SQL schema or auditing the mapping before inspecting the actual official-IMDb data would mean making schema decisions in a vacuum. Phase 1 produces the filtered slice; Phase 2 inspects it and decides the new ERD; only then does Phase 3 build the schema and reconcile the mapping.

### Phase 1 — Filtered data ready (proceed now)

Goal: produce filtered TSVs and confirm the slice solves the connectivity problem. No MySQL work, no schema decisions.

| Task | Description | Depends on | Status |
|------|-------------|------------|--------|
| MIG-05 | Write `database/etl/download.sh` (curl 7 `.tsv.gz` from datasets.imdbws.com; D-05 says no `gunzip`) | — | **Done** (2026-05-04, ~1.8 GB downloaded) |
| MIG-06 | Write `database/etl/filter_top_n.sh` (bash + awk pre-filter per D-10; `zcat` streams from `.tsv.gz`; default N=2500, first positional arg overrides) | MIG-05 | **Done** (2026-05-04, N=2500 → 2500 titles, 21,077 persons, 53,946 principals, 13 MB filtered) |
| MIG-07a | Connectivity diagnostic on the filtered TSVs — script `database/etl/connectivity_diagnostic.sh`. **Gates Phase 2.** | MIG-06 | **Done** (2026-05-04, **PASS**: 7,386 bridge persons / 35.0% — well above the 100-person threshold; top recurring: Francine Maisler 90 titles, Hans Zimmer 66, Brad Pitt 41, Robert De Niro 38) |

### Phase 2 — ERD investigation + new schema decisions (after Phase 1)

Goal: inspect the official IMDb data structure, decide what the new ERD should look like, then reconcile the existing mapping.

| Task | Description | Depends on | Status |
|------|-------------|------------|--------|
| MIG-02 | Write `docs/erd_investigation.md` — column-by-column comparison (current schema columns ↔ official IMDb TSV columns), list of structural differences, and a recommendation: keep current schema shape (views bridge gaps) vs. redesign ERD. **Inputs:** `docs/tsv_inspection.md` (slice-level), `docs/raw_imdb_analysis.md` (full-data design space, including 13 categories / 46 professions / 28 genres / 528-director worst case / multi-element JSON `characters` / 39k credits per person), and the six Phase-1 observations in §4a. | MIG-07a | Pending |
| MIG-02b | Decide whether to add new ontology / mapping concepts for fields not previously captured (e.g. `ce:averageRating`, `ce:numVotes`). Output: a written decision in `docs/erd_investigation.md` §"Ontology impact". | MIG-02 | Pending |
| MIG-02c | Draft new ERD if MIG-02 recommends redesign. Updates `docs/ERD.drawio`, exports new `docs/figs/ERD.png`. **Gates Phase 3.** | MIG-02 | Pending |
| MIG-01 | **Mapping reconciliation** (renamed from "inventory"): given the new schema decided in MIG-02, classify every `rr:tableName` / `rr:column` reference in `mapping/cineexplorer_mapping.ttl` as: (a) unchanged — view bridges, (b) needs view + small triple-map tweak, (c) needs full triple-map rewrite. Output: a checklist that drives MIG-04 and a possible MIG-04b for mapping edits. | MIG-02, MIG-02c | Pending |

### Phase 3 — Schema + load (after Phase 2)

Goal: implement the canonical schema decided in Phase 2, ingest the filtered data via staging tables (per D-03 staging-tables architecture), drop staging, add indexes.

| Task | Description | Depends on | Status |
|------|-------------|------------|--------|
| MIG-03 | Write `database/schema/01_canonical_tables.sql` — `CREATE TABLE` for the canonical schema (the ERD reduced to relational model). One CREATE per relation in `erd_investigation.md`'s decided model. | MIG-02c | Pending |
| MIG-04 | Write `database/schema/02_etl.sql` — staging-table CREATE TABLEs (mirror IMDb TSV shape), `LOAD DATA INFILE` per filtered TSV, `INSERT INTO canonical SELECT … FROM staging` per canonical relation (with `JSON_TABLE` explosions for CSV columns, JSON unwrap for `characters`, ratings JOIN for Title's composite rating attribute, lookup-table population), and `DROP TABLE` per staging table. | MIG-01, MIG-03 | Pending |
| MIG-04b | Update `mapping/cineexplorer_mapping.ttl` per Q01 / Q02 / Q04 / Q06 / Q07 decisions (Person typing from `primaryProfession`, new Participation Role classes, switched director/writer source, composite rating attribute, dropped `title_aka_title_type` junction). | MIG-01 | Pending |
| MIG-07 | Write `database/etl/load.sh` — orchestrator: runs `01_canonical_tables.sql`, then `02_etl.sql`, then `03_indexes.sql` against the running MySQL container. Uses `.n_${N}` sentinel to avoid re-filtering when `N` hasn't changed. | MIG-03, MIG-04, MIG-06 | Pending |
| MIG-08 | End-to-end smoke test: `docker compose down -v && up && load.sh` → row counts in canonical tables match expectations (`title` = 2,500, `participation` ≈ 53,946, etc.); verify staging tables are dropped. | MIG-07 | Pending |
| MIG-09 | Spot-check 5 mapping triple maps by hand against canonical tables. Verify the columns referenced by each `rr:column` exist in the canonical schema. | MIG-04b, MIG-08 | Pending |
| MIG-10 | Write `database/schema/03_indexes.sql` (FKs + indexes added on canonical tables AFTER `02_etl.sql` populates them — adding indexes after load is faster than maintaining them during INSERT). | MIG-08 | Pending |

### Phase 4 — Deployment + SPARQL + SHACL + Demonstrator

Goal: regenerate KG (already done at N=2500), deploy to Fuseki + Brwsr, re-run SPARQL/SHACL, build the non-trivial demonstrator suite. **Revised 2026-05-05** to incorporate the professor's feedback (email of 2026-05-04) suggesting deeper SHACL, FacadeX, graph embeddings, or LangChain as candidate non-trivial demonstrators.

#### Demonstrator suite (decision)

The professor's email reframed Bacon-number as "merely a recursive graph query with aggregates", so we need **at least one more** non-trivial demonstrator. Final choice:

| ID | Demonstrator | Source artefact | Effort |
|---|---|---|---|
| **A** | Bacon-number / collaboration graph (property paths, reachability sets) | `sparql/q06*.sparql` | re-run on new KG |
| **B** | SHACL validation (with vs without RDFS inference; OWA/CWA contrast). Extended for new schema. | `sparql/cineexplorer_shapes.ttl` | extend with shapes for `:averageRating` / `:numVotes` / `:hasProfession` |
| **C** | Wikidata federation (SPARQL `SERVICE` aligning IMDb persons with Wikidata via P345) | `sparql/q07_wikidata_federation.sparql` | re-test on new KG |
| **D** *(stretch)* | LangChain natural-language interface to the KG | new `notebooks/03_langchain_kg.ipynb` | 5–10 hours; defer if time-constrained |

A + B + C cover the rubric cleanly: graph traversal (A), declarative constraint reasoning (B), federated reasoning (C). D is a stretch goal that addresses the prof's #4 suggestion if we have time.

#### Tasks

| Task | Description | Depends on | Status |
|------|-------------|------------|--------|
| MIG-11 | Run `r2rml.jar` against new MySQL state; record new triple count, subject count | MIG-09, MIG-10 | **Done** (2026-05-05; 845,195 triples at N=2500; rebuild at N=5000 in progress) |
| MIG-12 | Re-run all 10 SPARQL queries against new KG; capture new result CSVs into `sparql/results/` | MIG-11 | Pending |
| MIG-13 | Re-run + extend SHACL validation. Add shapes for new datatype properties (`:averageRating`, `:numVotes`, `:hasProfession`). Run with vs without RDFS inference; document the OWA/CWA contrast. | MIG-11 | Pending |
| MIG-14 | Re-run Bacon-number queries Q6 / Q6b on new KG; verify 2-hop neighbourhood strictly larger than 1-hop. **Demonstrator A.** | MIG-11 | Pending |
| MIG-14b | **NEW**: Deploy KG to Fuseki + Brwsr (`deployment/docker-compose.yml` already configured). Load new KG via `curl -u admin:admin -X POST http://localhost:3030/cineexplorer/data --data-binary @output/cineexplorer_kg.ttl -H "Content-Type: text/turtle"`. | MIG-11 | Pending |
| MIG-14c | **NEW**: Wikidata federation re-test (Q7) on new KG. Confirm `SERVICE` query still returns Wikidata enrichment. **Demonstrator C.** | MIG-12 | Pending |
| MIG-14d | **NEW (stretch)**: LangChain demo notebook — natural-language → SPARQL → KG → answer. Showcases prof's suggestion #4. **Demonstrator D.** | MIG-14b | Stretch goal |

### Phase 5 — Report + cleanup

Goal: update report (§2/§3/§6/§7/§8/§9/§10 + Appendix D), archive predecessor docs, merge.

| Task | Description | Depends on | Status |
|------|-------------|------------|--------|
| MIG-15 | Update `report/sec/02_database.tex`: N=5000 (or N=2500) numbers, migration paragraph forward-pointing to Appendix D, slice-criterion sentence | MIG-12 | Pending |
| MIG-15b | Write Appendix D — *Original (northCoder) Dataset*: D.1 overview, D.2 connectivity diagnostic, D.3 schema diff, D.4 original ERD figure | MIG-12, MIG-14 | Pending |
| MIG-16 | Update `report/sec/10_demonstrator.tex`: enriched narrative covering Demonstrators A (Bacon), B (SHACL), C (Wikidata federation), D (LangChain if implemented). Connect to prof's feedback in §10's intro. | MIG-14, MIG-14c | Pending |
| MIG-16b | **NEW**: Update `report/sec/06_ontology.tex`: note the 3 added datatype properties (`:averageRating`, `:numVotes`, `:hasProfession`); explain the two-axis Q01 model | MIG-11 | Pending |
| MIG-16c | **NEW**: Update `report/sec/07_mapping.tex`: describe the migrated mapping (column renames, switched Person typing source from `category` to `primaryProfession`, removed `title_aka_title_type` junction, added rating/numVotes/hasProfession triple maps) | MIG-11 | Pending |
| MIG-16d | **NEW**: Update `report/sec/08_deployment.tex`: Fuseki + Brwsr setup; new KG size; loading procedure | MIG-14b | Pending |
| MIG-16e | **NEW**: Update `report/sec/09_sparql.tex`: refresh all 10 query result CSVs and screenshots; note new dataset scale impact | MIG-12 | Pending |
| MIG-17 | Archive existing `docs/db_reference.md` → `docs/archive/2026-05_db_reference_northcoder.md`; write new `docs/db_reference.md` for migrated schema | MIG-11, MIG-15b | Pending |
| MIG-18 | Same for `docs/is_reference.md` (ERD redrawn over migrated schema) | MIG-11, MIG-15b | Pending |
| MIG-19 | Update `docs/sparql_reference.md`, `docs/demonstrator_reference.md` with new result counts | MIG-12, MIG-14 | Pending |
| MIG-20 | Update `CLAUDE.md` Database Quick Reference + Repository Layout | MIG-17 | Pending |
| MIG-21 | Cleanup commit on the migration branch: remove `database/csv-data/`, `database/imdb-schema.sql` | all of the above | Pending |
| MIG-22 | Merge `feature/imdb-official` into `feature/draft-m4` (or `develop`) | MIG-21 | Pending |

---

## 4a. Phase 1 Outcomes (2026-05-04)

Phase 1 ran successfully on `feature/imdb-official` branched off `feature/draft-m4`. All three tasks (MIG-05, MIG-06, MIG-07a) are Done.

### Quantitative results

| Metric | Value | vs estimate |
|---|---|---|
| Slice (N) | 2,500 titles | as planned |
| Unique persons in slice | 21,077 | ~40 % more than the ~15k estimate |
| Principal credits | 53,946 | ~2× the ~25k estimate |
| Bridge persons (≥ 2 titles) | **7,386 (35.0 %)** | ≫ 100-person PASS threshold |
| Filtered slice on disk | 13 MB total | well under 100 MB commit threshold (D-06) |
| Raw downloaded | 1.8 GB compressed | as expected |
| Total wall-clock for Phase 1 | ~5 min download + 30 sec filter + 1 sec diagnostic | matches Approach 2 estimate from D-10 |

### Qualitative observations (inputs to Phase 2)

1. **`title_episode.tsv` is essentially empty (565 bytes ≈ header + a handful of rows).** The top-2,500-by-numVotes slice is overwhelmingly films, with very few TV episodes. Phase-2 ERD investigation must decide: (a) accept thin Episode/Series data and let those parts of the ontology degrade gracefully, (b) augment the slice with TV episodes from highly-voted series, or (c) drop Episode/Series from the migrated KG and explain in the report why. Affects ontology-coverage claims in §6 and §7 of the report.

2. **`title_akas.tsv` is the largest filtered file (7.6 MB).** International title variants are rich. This enables stronger SPARQL queries on regional / language alternate titles than the northCoder sample supported.

3. **Top recurring persons are casting directors and composers, not actors.** The list is led by Francine Maisler (90 titles), Mary Vernieu (83), Sarah Finn (76), Hans Zimmer (66), James Newton Howard (50), John Williams (48). The first acting-only entry is Brad Pitt at 41 titles. This is interesting for the report: the collaboration graph's hubs are *crew* roles, not the cast. The Bacon-number narrative still works — Brad Pitt and Robert De Niro are in the top 20 — but it is honest to note this in §10.

4. **`title.principals.characters` is a JSON array** (e.g., `["John Doe","Jane Smith"]`), not the comma-separated list the northCoder schema's `principal_role` table assumed. Phase-2 ERD investigation must propose either: (a) `JSON_TABLE` to explode at view time, (b) reshape the view, or (c) restructure `principal_role`. Flagged in MIG-02.

5. **`title.crew` provides directors/writers as comma-separated nconst lists** in addition to the per-credit `category` in `title.principals`. Two redundant-ish representations of the same fact, which sometimes disagree in IMDb. Phase-2 must decide which to consume.

6. **`title.ratings` (`averageRating`, `numVotes`) has no equivalent in the current schema or ontology.** Loading it costs nothing (we already use it for the slice criterion). Phase-2 D-02b decides whether to surface it as `ce:averageRating` / `ce:numVotes`.

### Implementation notes worth carrying forward

- `set -o pipefail` + `head -n` is a SIGPIPE trap. Both the rating-sort step in `filter_top_n.sh` and the Top-20 list in `connectivity_diagnostic.sh` initially failed with exit 141. Fix: sort to a temp file then `head` from it (filter), or replace `| head -n N` with `| awk 'NR<=N'` (diagnostic). Worth keeping in mind for any later bash that pipes into `head`.
- The `awk 'NR==FNR{k[$1]=1; next} FNR==1{print; next} k[$1]'` idiom emits the header and filters rows in a single pass, avoiding a second `zcat` for the header.

### Phase 1 deliverables on disk

```
database/etl/                            (committable)
├── README.md                            Phase-1 runbook
├── download.sh                          MIG-05
├── filter_top_n.sh                      MIG-06
└── connectivity_diagnostic.sh           MIG-07a

database/sources/imdb-official/
├── .gitignore                           ignores raw/, tracks filtered/
├── raw/                                 1.8 GB, gitignored
└── filtered/                            13 MB, committable
    ├── title_basics.tsv                 (202 KB, 2,500 rows + header)
    ├── title_akas.tsv                   (7.6 MB)
    ├── title_crew.tsv                   (222 KB)
    ├── title_episode.tsv                (565 B — nearly empty)
    ├── title_principals.tsv             (2.4 MB, 53,946 rows)
    ├── title_ratings.tsv                (52 KB, 2,500 rows)
    └── name_basics.tsv                  (2.0 MB, 21,077 rows)
```

---

## 4b. Report Narrative Strategy

The dataset migration must be documented in the report itself, not just in the codebase. The strategy is to **mention the migration once prominently in the main body and preserve the original dataset's evidence in an appendix**, so the report shows critical reflection ("we found a structural limitation, diagnosed it, fixed it") rather than ad-hoc revision.

### Main body — minimal, single-mention

| Section | What to add | Length |
|---------|-------------|--------|
| §2 Database (top of section) | One paragraph: original sample → diagnostic finding → migration → forward-pointer to Appendix D. State that ontology and mapping are unchanged. All scale numbers below refer to the migrated dataset. | ~150 words |
| §2 Database (slice-criterion note) | One sentence justifying `numVotes DESC` over chronological / random / rating-based ranking. See note below. | ~1 sentence |
| §10 Demonstrator (start of Bacon-number subsection) | One paragraph: initial Bacon attempt on northCoder sample → connectivity diagnostic → migration motivation → forward-pointer to §2 / Appendix D. | ~80 words |
| Everywhere else | Just update the numbers. No dual-version sentences. | — |

> **Note on slice-criterion justification (D-02).** The choice to rank by `numVotes DESC` rather than `tconst` order, random sampling, or `averageRating` is non-obvious and must be defended in the report — otherwise a reader will reasonably ask "why not just take the first N titles?". A single sentence in §2 Database is enough; the candidate phrasing is:
>
> > "The slice is ranked by `numVotes` (descending) rather than chronological order or random sampling because high-vote titles concentrate working actors across multiple productions, producing the densely-connected collaboration graph the Bacon-number demonstrator requires; chronological ordering would land in 1890s silent shorts with the same disconnected-cliques structure as the original sample."
>
> Owned by MIG-15. The detailed rationale (alternatives considered, bias caveat about Hollywood-centric coverage) lives in D-02 of this plan and need not be reproduced in the report.

> **Note on `title.crew` cardinality (ERD-Q04).** The migrated schema models `direct` and `write` as `Title --(0,N)-- … --(0,N)-- Person`, *not* `(1,N)`. The reason is data: 44.1 % of IMDb Titles have NULL `directors` in `title.crew` and 49.1 % have NULL `writers` (verified at full IMDb scale), overwhelmingly because TV episodes inherit their crew credits from the parent series. A reader looking at our cardinality choice will reasonably ask "why not (1,N)?" — so this should be addressed in §2 Database or §6 Ontology with a sentence like:
>
> > "Cardinality on the `direct` and `write` relationships is `(0,N)` on the Title side because 44 % of IMDb's `title.crew.directors` and 49 % of `title.crew.writers` are NULL — overwhelmingly TV episodes that inherit per-series rather than per-episode credits. A `(1,N)` cardinality would contradict ~5.5 million IMDb rows."
>
> Also worth a one-sentence flag in §10 Demonstrator: choosing `title.crew` (exhaustive) over `title.principals` (top-billed) for these two predicates inflates the collaboration graph for long-running TV (e.g. a soap with 96 directors contributes a 96-clique = ~4,500 edges), which helps connectivity but skews the degree distribution.
>
> Owned by MIG-15 (§2 Database) and MIG-16 (§10 Demonstrator). Detailed rationale in `docs/erd_investigation.md` ERD-Q04.

### Appendix D — Original (northCoder) Dataset

Owned by MIG-15b. ~3–4 pages.

| Subsection | Content |
|------------|---------|
| D.1 Overview | One paragraph describing the northCoder sample (provenance, scale: 174 titles / 1,441 persons / 587 principal credits / 74 episodes / 28 genres) and why it was chosen for M1. |
| D.2 Connectivity diagnostic | The actual SPARQL queries that exposed the disconnected-cliques structure: (a) `HAVING (COUNT(DISTINCT ?title) > 1)` returning 0 rows, (b) cluster-size distribution table (10·1 + 6·2 + 11·3 + 4·4 + 5·5 + 1·6 + 8·7 + 5·8 + 2·9 + 37·10 = 586 of 1,441 persons across 89 cliques). This is the *evidence* justifying the migration. |
| D.3 Schema diff | Column-level comparison table: northCoder schema → official IMDb columns. Demonstrates the migration was a thin projection layer rather than a redesign. References `database/schema/02_views.sql` as the live artefact. |
| D.4 Original ERD | The pre-migration ERD figure (preserved from `docs/figs/ERD.png`). The post-migration ERD lives in §2 as before. |

### Source material for Appendix D

Appendix D is written from artefacts that already exist:

- **D.1 Overview + D.3 Schema diff** ← current `docs/db_reference.md` (will be archived to `docs/archive/2026-05_db_reference_northcoder.md` by MIG-17, *after* MIG-15b consumes it).
- **D.4 Original ERD** ← current `docs/figs/ERD.png` and `docs/ERD.drawio` (the post-migration ERD will replace these in §2; MIG-18 archives them as part of `2026-05_is_reference_northcoder.md`).
- **D.2 Connectivity diagnostic** ← already documented in `docs/demonstrator_reference.md` (the "0 results" `HAVING` query and cluster-size table); just transposed into LaTeX.

So the appendix work is mostly extraction-and-formatting, not new analysis.

### What does *not* go into the appendix

- **Ontology** — unchanged across migration; no appendix entry.
- **R2RML mapping** — unchanged thanks to the view layer (D-03); no appendix entry.
- **SPARQL queries** — same files; only result CSVs change.
- **SHACL shapes** — unchanged.

Rationale for these omissions: an appendix should contain artefacts that would otherwise be lost. The ontology, mapping, queries, and shapes are unchanged, so the main body already documents the only version that exists.

---

## 5. Open Questions for Professor (Thursday meeting)

| # | Question |
|---|----------|
| O-01 | Confirm migration to official IMDb non-commercial dataset is acceptable for M4 |
| O-02 | Confirm Bacon number remains an acceptable non-trivial demonstrator on a denser dataset, or whether we should switch to one of his suggested alternatives (advanced SHACL/ShEx, FacadeX, graph embeddings, LangChain + KG) |
| O-03 | Acceptable size for the slice — we propose **2,500 titles** as default, with 5k / 10k as fallbacks. Too small / too large? |
| O-04 | Is committing the filtered TSVs to git acceptable, or should we rely entirely on the ETL for reproducibility? |

---

## 6. Risks & Rollback

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Schema differences turn out to be deeper than minor column renames | Medium | MIG-01 + MIG-02 surface this before any DDL is written; if deep, abandon migration and pick demonstrator from prof's alternatives list |
| Filtering by numVotes still leaves a sparse collaboration graph | Low | Verify after MIG-06 by running the "person → distinct title count" diagnostic query before MIG-11 |
| KG file size makes Fuseki load slow / breaks Brwsr | Low | Drop to 5k titles; document the choice |
| pyshacl runtime explodes on larger KG | Low | Limit shape evaluation scope or use Jena SHACL CLI as fallback |
| Migration stalls mid-way | — | All work on `feature/imdb-official`; `feature/draft-m4` remains a fully working M4 system |

---

## 7. Non-Migration Worklist (from professor's Thursday email)

These are not part of this migration but should be tracked:

- Consider deeper SHACL / ShEx exercises as a stronger non-trivial demo
- FacadeX (declarative integration)
- Graph embeddings for concept similarity (requires deep-learning background)
- LangChain + LLM over the KG

Decision on whether to add any of these alongside or in place of Bacon number is captured in O-02.
