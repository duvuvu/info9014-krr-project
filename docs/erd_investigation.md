# ERD Investigation — Official IMDb Migration

> **Status:** active — opened 2026-05-04. Working document for Phase 2 of the migration plan.
> **Owner task:** MIG-02 in `docs/plan.md` §4 Phase 2.
> **Goal:** decide what the migrated SQL schema and ontology should look like, *before* any DDL or mapping edits.
>
> **Note (2026-05-05):** Layer-by-layer realisation entries below reference the originally-planned three-file split (`01_canonical_tables.sql`, `02_etl.sql`, `03_indexes.sql`). After all decisions were implemented, those three files were merged into a single `database/imdb-schema.sql` (phases 0–6). Decision content is preserved as historical record; for the executable schema, see `database/imdb-schema.sql`.

This document is a **structured agenda for team discussion**. Every open question (ERD-Q##) carries the relevant data evidence, the candidate options, and a status field. Decisions are logged in §1; the rest of the document holds the discussion threads.

---

## 0. Inputs

| Input | What it gives us |
|-------|------------------|
| `docs/plan.md` | Migration plan (D-01..D-10, MIG-01..MIG-22, §4a Phase-1 outcomes, §4b report narrative) |
| `docs/tsv_inspection.md` | Slice-level (N=2,500) data analysis — what we actually have to load |
| `docs/raw_imdb_analysis.md` | Full-IMDb data analysis — what the schema must accommodate at scale |
| `docs/db_reference.md` | Current (northCoder) schema, scale, and design decisions |
| `docs/ontology_reference.md` | Current ontology classes, properties, and axioms |
| `docs/mapping_reference.md` | Current R2RML mapping triple maps |
| `notebooks/01_imdb_raw_analysis.py` + `notebooks/02_column_distinct.py` | Source for the analysis numbers |

---

## 1. Decisions log

Updated as we work through the questions. `Status` is one of `To discuss → Decided → Implemented`.

| ID | Topic | Decision | Status | Date |
|----|-------|----------|--------|------|
| ERD-Q01 | Role vs profession (entity vs relationship) | **Two-axis model.** `Person --hasProfession--> Profession` from `name.basics.primaryProfession`; `Participation --hasRole--> Role` from `title.principals.category`. Shared 12-value vocabulary; `self` Participation-only; 34 department-level labels Person-only. | **Decided** | 2026-05-04 |
| ERD-Q02 | Person subclasses — extend with `casting_director`, `archive_footage`, `archive_sound`? | **5 Person OWL subclasses, non-disjoint** (matches original M3 set, with `actor`+`actress` collapsed to `:Actor`): `:Actor, :Director, :Writer, :Editor, :Composer`. **No new Person subclasses.** Role at the Participation level becomes a `:hasRole xsd:string` datatype property (no Role class hierarchy). M3's `:actedIn / :directed / :wrote / :edited / :composedFor` direct properties retained. Categories outside the 5 (`producer`, `cinematographer`, `production_designer`, `casting_director`, `self`, `archive_footage`, `archive_sound`) get only string-level `:hasRole` treatment. | **Decided (revised)** | 2026-05-04 |
| ERD-Q03 | `Adult` genre — keep or drop? | **Drop `Adult` from the genre vocabulary.** Keep `is_adult` as a boolean attribute on `Title` (already in `title.basics.isAdult`). 27 atomic genres in the lookup; "is this adult?" is answered by `is_adult` instead. | **Decided** | 2026-05-04 |
| ERD-Q04 | `title.crew` vs `title.principals` — single source for director/writer? | **`title.principals` only** for director/writer. All 13 IMDb categories (incl. director, writer) flow through the `Participation` weak entity. `title.crew` is loaded into a staging table and **dropped** with the rest of staging — never read by the canonical-schema population. Reason: consistency with the rest of the model (Q01/Q02), preserves `job` and `ordering` per-credit metadata, simpler mapping. | **Decided (revised)** | 2026-05-04 |
| ERD-Q05 | `characters` JSON modelling — explode, or treat as opaque? | **Multi-valued attribute on `Participation`.** ER: double-circle `character_name` on Participation. Relational reduction: junction `participation_character(TITLE_ID, ORDERING, CHARACTER_NAME)`, composite PK, FK `(TITLE_ID, ORDERING)` → `participation`. Populated by `JSON_TABLE` exploding `characters` in ETL. | **Decided** | 2026-05-04 |
| ERD-Q06 | `title.ratings` — add to schema/ontology? | Yes — composite attribute `rating = {average_rating, num_votes}` on `Title`. Renders as two extra columns on the `Title` relation; **no `Rating` relation** in the schema. Two `xsd` datatype properties on `:CreativeWork`; no `Rating` class. | **Decided** | 2026-05-04 |
| ERD-Q07 | `title.akas` — keep or simplify the current `aka`/`title_type` design? | **Keep `types` and `attributes` as plain VARCHARs on `TitleAKA`** (no junction, no `AkaType` entity). Drop the `title_aka_title_type` junction. Three relations: weak entity `TitleAKA(tconst, ordering, title, region, language, is_original_title, types, attributes)`, lookups `Language` and `Region`. | **Decided (revised)** | 2026-05-04 |
| ERD-Q08 | `knownForTitles` — drop, soft-FK, or condition on slice? | **Keep `knownForTitles` as a multi-valued attribute on `Person`, filtered to slice tconsts at ETL load (option c).** Junction `person_known_for(TALENT_ID, TITLE_ID)` with composite PK; FK `TITLE_ID` → `title.TITLE_ID` enforced. Persons end up with 0–4 surviving refs depending on whether their famous works are in our slice. | **Decided** | 2026-05-04 |
| ERD-Q09 | NULL handling at scale — does R2RML strategy still work? | **Yes.** R2RML's automatic NULL-column skip is the right behaviour. Existing M3 cardinality axioms (`min 0`) accommodate the much higher full-IMDb NULL rates without change. No schema or ontology changes needed. | **Decided** | 2026-05-04 |
| ERD-Q10 | Rare `titleType` / `category` values — include or exclude? | **Option (b) — only values present in the loaded slice.** All lookup tables (`title_type`, `role`, `genre`, `language`, `region`, `profession`) populated dynamically via `INSERT INTO … SELECT DISTINCT` during ETL. **No hard-coded `INSERT VALUES` in the schema DDL.** Schema reflects exactly what the slice contains. | **Decided** | 2026-05-04 |
| ERD-Q11 | AKA `types` malformed concatenations — VARCHAR vs enum? | **Subsumed by Q07.** `types` is a plain `VARCHAR` column on `title_aka` with no CHECK / enum enforcement. Malformed concatenations (`imdbDisplaydvd`, etc., ~430 rows in full IMDb) are accepted as-is. Matches IMDb's own behaviour. | **Decided** | 2026-05-04 |
| ERD-Q12 | `job` free text — schema treatment | **Option (a).** `job` is a single `VARCHAR` column on `participation`, mapped to `:job xsd:string` datatype property. NULL when absent (~81 % of rows). 47 K distinct values across full IMDb — too many to enumerate. | **Decided** | 2026-05-04 |
| ERD-Q13 | Episode / Series coverage — thin in slice, what to do? | **Option (a) — accept thin Episode coverage.** Schema and ontology fully support Episode/Series (per F-02); the slice happens to have only 21 episodes attached to 6 series, and that's what we load. The report acknowledges this honestly rather than augmenting or stratifying the slice. | **Decided** | 2026-05-04 |
| ERD-Q14 | Slice criterion already in D-02 — anything to revisit? | **Option (a) — no change now.** Stay at N=2,500, `numVotes DESC`. If the migrated KG turns out to be too sparse for the demonstrator after MIG-14, rerun the ETL with N=5,000 (a `docker compose down -v && up && load.sh 5000` sequence; D-02 already supports the parameter). No upfront change. | **Decided** | 2026-05-04 |

Rule of thumb: a decision is `Decided` only when it has a written rationale tied to data evidence, *and* the schema/ontology/mapping impact is named.

---

## 1.5. Foundational assertions (agreed, not under discussion)

These are the load-bearing ERD assumptions we agree on going in. They constrain the open questions in §2 — every option in §2 must be consistent with these.

### F-01 — Two strong entity sets: `Title` and `Person`

| Entity | Primary key | IMDb-side source | Notes |
|--------|------------|-------------------|-------|
| **`Title`** | `tconst` (`tt\d+`) | `title.basics.tconst` | Independent existence. All title-related tables (`title.akas`, `title.crew`, `title.episode`, `title.principals`, `title.ratings`) FK into here. |
| **`Person`** | `nconst` (`nm\d+`) | `name.basics.nconst` | Independent existence. `title.principals.nconst`, `title.crew.{directors,writers}` (CSV-list), `name.basics.knownForTitles` (CSV-list, soft FK) all reference here. |

**What this excludes.** Other concepts in the model are deliberately *not* strong entities:

| Concept | Why not a strong entity |
|---|---|
| `Series`, `Episode` | Subtypes of `Title`; still identified by `tconst`. The supertype/subtype distinction is a discriminator (`titleType`), not a separate identifier. |
| `Genre`, `Region`, `Language`, `Role/Profession` | Closed (or near-closed) enums; typically modelled as lookup tables / value-sets / OWL classes — not on the same level as `Title`/`Person`. |
| `Aka` | Weak entity — has no identifier without `Title` (`PK = (titleId, ordering)`). |
| `Rating` | 1-to-1 attribute set on `Title`; no separate identifier of its own. |
| `Participation` | n-ary association. Can be **promoted** to a weak entity (existence-dependent on Title and Person), as the current M3 ontology does. Not a strong entity. |

Status: **Agreed 2026-05-04.**

---

### F-02 — Film / Series / Episode subtype structure

`Title` has a partial, disjoint IS-A specialisation into **three subtypes**: `Film`, `Series`, `Episode` — matching the existing M3 ontology where `:Film, :Series, :Episode` are the three disjoint subclasses of `:CreativeWork` (declared via `owl:AllDisjointClasses`). All three subtypes inherit `tconst` as their PK. The discriminator is `Title.title_type_id` — a FK to the `title_type` lookup entity.

```
                    Title  (PK = tconst, FK title_type_id)
                      △
                    is-a (0,1)            ← partial / disjoint
                  /     |     \
              Film    Series  Episode
              (—)     (—)     (PK=tconst, attrs: parent_tconst,
                                                  season_number, episode_number)
                                              |
                              +---(0,N)---hasEpisode---(1,1)---+
                              |
                            Series
```

| Element | Spec | Evidence |
|---------|------|----------|
| IS-A from `Title` to `{Film, Series, Episode}` | **Partial, disjoint** (`(0,1)`). `title_type_id` (FK to `title_type` lookup) is the discriminator. `Film` ⇐ `'movie'`; `Series` ⇐ `'tvSeries' / 'tvMiniSeries' / 'tvPilot'`; `Episode` ⇐ `'tvEpisode'`. | `title.basics.titleType` has 11 disjoint values; the remaining 6 (`short`, `video`, `tvMovie`, `tvSpecial`, `videoGame`, `tvShort`) are not modelled as subtypes and remain plain `Title` rows. The IS-A is *partial* in that sense. |
| Subtype keys | Inherit `tconst` from `Title` (no new identifier). | Confirmed — `title_episode.tconst = title.tconst`; `Film` and `Series` have no separate tables. |
| `Series --(0,N)-- hasEpisode --(1,1)-- Episode` | **Episode side `(1,1)`**: every Episode has exactly one parent Series. **Series side `(0,N)`**: a Series can have 0 to N Episodes — chosen `(0,N)` rather than the conceptual `(1,N)` for honesty about the slice. | `title.episode.parentTconst` has 0 NULL in full IMDb. The slice has only 21 episodes for 285 series, so 279 series will have empty `hasEpisode`. We use `(0,N)` to match the data we actually load, consistent with Q04's choice of `(0,N)` on Title side for `direct`/`write` (44 % / 49 % NULL). |
| `Episode` attributes | `parent_tconst` (FK to `title.tconst`), `season_number`, `episode_number` (both nullable, ~21 % NULL in IMDb). | Direct columns on `title_episode`. |

Notes:
- `season_number` / `episode_number` could equivalently be modelled as attributes on the `hasEpisode` relationship (since `hasEpisode` is 1:N, relationship attributes can sit on the many side). Putting them on `Episode` matches IMDb's source layout.
- **`Film` is kept as a third sibling** to match the M3 ontology's `:Film` class (sibling of `:Series` and `:Episode` under `:CreativeWork`, mutually disjoint via `owl:AllDisjointClasses`). `Film` ⇐ `title_type_id = 'movie'` only; the other "non-series, non-episode" titleTypes (`short`, `video`, `tvMovie`, etc.) are not Film — they remain plain Title rows. This aligns the schema with the existing OWL ontology and preserves SPARQL queries that reference `?f a :Film`.
- `Title_Type` *is* a separate lookup entity, consistent with `Role`, `Profession`, `Language`, `Region` — all five bounded label sets are modelled as entity sets per the 2026-05-04 decision to use entity sets uniformly for lookups (with the exception of Genre and Character, which are multi-valued attributes per the value-vs-entity-set discussion). This is distinct from `TitleAKA.types` (a different concept entirely: per-AKA classification of localised titles, plain VARCHAR on the weak entity, per Q07).

Status: **Agreed 2026-05-04.** What remains is *Q13 — coverage* (do we accept thin episode data, augment, or stratify?), not *modelling structure*.

---

## 1.7. Naming conventions (followed throughout)

Two distinct levels of representation, two distinct conventions. Anchored to the existing northCoder schema in `docs/db_reference.md`.

### ERD-level (conceptual model)

| Element | Convention | Examples |
|---------|-----------|----------|
| Strong entity set | **PascalCase**, acronyms stay all-caps | `Title`, `Person`, `TitleAKA`, `Region`, `Language`, `Genre`, `Role`, `Profession` |
| Subtype (under IS-A) | PascalCase | `Film`, `Series`, `Episode` (per F-02; matches M3 ontology) |
| Weak entity set | **PascalCase with underscore** between word groups | `Title_Genre`, `Person_Profession`, `Participation` (latter has its own name; junctions get `_`) |
| Relationship | **camelCase** (verb or verb-noun) | `hasEpisode`, `direct`, `write`, `hasGenre`, `participatesIn`, `actsIn`, `hasProfession`, `hasRole` |
| Attribute | **snake_case lowercase** | `tconst`, `nconst`, `primary_title`, `birth_year`, `is_adult`, `season_number`, `average_rating` |

### SQL-level (relational schema, in `01_canonical_tables.sql` / `02_etl.sql`)

Matches the existing northCoder convention so reviewers familiar with the M1 work can read the new schema fluently.

| Element | Convention | Examples |
|---------|-----------|----------|
| Table name | **lowercase, snake_case** | `title`, `person`, `title_aka`, `title_genre`, `participation`, `language`, `region`, `category`, `role`, `profession`, `person_profession`, `episode`, `genre` |
| Column name | **UPPER_SNAKE_CASE** | `TITLE_ID` (= `tconst`), `TALENT_ID` (= `nconst`), `PRIMARY_TITLE`, `BIRTH_YEAR`, `IS_ADULT`, `AVERAGE_RATING`, `NUM_VOTES`, `SEASON_NUMBER`, `EPISODE_NUMBER` |
| Constraint name | UPPER_SNAKE | `PK_TITLE`, `FK_PARTICIPATION_TITLE` |

### Cross-level mapping (ERD attribute → SQL column)

A few ERD-attribute → SQL-column renames that match the northCoder convention:

| ERD attribute | SQL column |
|---------------|-----------|
| `tconst` | `TITLE_ID` |
| `nconst` | `TALENT_ID` |
| `primary_title` | `PRIMARY_TITLE` |
| `is_adult` | `IS_ADULT` |
| `start_year` | `START_YEAR` |
| `runtime_minutes` | `RUNTIME_MINUTES` |
| `genre_id`, `genre_name` | `GENRE_ID`, `GENRE_NAME` |
| `language_id`, `region_id` | `LANGUAGE_ID`, `REGION_ID` |
| `birth_year`, `death_year` | `BIRTH_YEAR`, `DEATH_YEAR` |
| `average_rating`, `num_votes` | `AVERAGE_RATING`, `NUM_VOTES` |
| `season_number`, `episode_number` | `SEASON_NUMBER`, `EPISODE_NUMBER` |

### Note on previously-decided entries

- ERD-Q06 / Q07 / F-01 / F-02 decisions are written in **ERD-level** notation (`Title(tconst, …)`, `TitleAKA(tconst, ordering, title, …)`). That's the right register for those passages — they describe the conceptual model.
- §1.6 below shows the **SQL-level** canonical schema, so it uses `lowercase` table names and `UPPER_SNAKE` column names.
- When writing prose, default to ERD-level notation (it's more readable and matches the report's §3 ERD section). Drop into SQL-level only when discussing the actual `.sql` files.

---

## 1.6. Data-flow architecture (textbook ERD → relational model → ingest)

The migrated database follows the standard textbook flow. This diagram pins the architecture in one place so every Q## decision in §2 is consistent with it.

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. SOURCE FILES                                                    │
│     database/sources/imdb-official/raw/*.tsv.gz                     │
│     (7 IMDb TSVs, 1.6 GB compressed; downloaded by Phase 1)         │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │  bash filter_top_n.sh
                                  │  (top 2,500 tconsts by numVotes)
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. FILTERED TSVs                                                   │
│     database/sources/imdb-official/filtered/*.tsv  (~13 MB)         │
│     Same IMDb shape, just sliced.                                   │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │  LOAD DATA INFILE
                                  │  (02_etl.sql step (i)+(ii))
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. STAGING TABLES (transient, MySQL)                               │
│     title_basics_staging, title_akas_staging,                       │
│     title_principals_staging, title_ratings_staging,                │
│     name_basics_staging, title_episode_staging                      │
│     (and title_crew_staging if we keep loading it — see Q04)        │
│                                                                     │
│   • One staging table per filtered TSV file                         │
│   • Mirror IMDb's TSV column shape exactly                          │
│   • Just landing zones — no FKs, no canonical-schema concepts       │
│   • Exist for ~30 seconds during ETL                                │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │  INSERT INTO canonical
                                  │    SELECT … FROM staging
                                  │    (with JSON_TABLE explosions,
                                  │     JSON unwraps, JOINs, lookup
                                  │     population)
                                  │  (02_etl.sql step (iii))
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. CANONICAL SCHEMA (the ERD reduced to relations)                 │
│     CREATE TABLE in 01_canonical_tables.sql                         │
│     SQL convention: lowercase tables, UPPER_SNAKE columns (per §1.7)│
│                                                                     │
│     title             (TITLE_ID PK, PRIMARY_TITLE, ORIGINAL_TITLE,  │
│                        IS_ADULT, START_YEAR, END_YEAR,              │
│                        RUNTIME_MINUTES, AVERAGE_RATING,             │
│                        NUM_VOTES)                  ← Q06, Q03        │
│     person            (TALENT_ID PK, PRIMARY_NAME, BIRTH_YEAR,      │
│                        DEATH_YEAR)                                  │
│     participation     (TITLE_ID, ORDERING — composite PK;           │
│                        TALENT_ID, ROLE_ID, JOB, CHARACTER_NAME)     │
│                                                    ← Q01, Q05       │
│     title_aka         (TITLE_ID, ORDERING — composite PK; TITLE,    │
│                        REGION_ID, LANGUAGE_ID, IS_ORIGINAL_TITLE,   │
│                        TYPES, ATTRIBUTES)          ← Q07            │
│     genre             (GENRE_ID PK, GENRE_NAME)    ← 27 values, Q03 │
│     title_genre       (TITLE_ID, GENRE_ID — composite PK; ORD)      │
│     role              (ROLE_ID PK, ROLE_NAME)      ← 12 values, Q02 │
│     profession        (PROFESSION_ID PK, PROFESSION_NAME)           │
│                                                    ← 46 values, Q01 │
│     person_profession (TALENT_ID, PROFESSION_ID — composite PK; ORD)│
│                                                    ← Q01            │
│     language          (LANGUAGE_ID PK, LANGUAGE_NAME)               │
│     region            (REGION_ID PK, REGION_NAME)                   │
│     title_episode     (TITLE_ID PK + FK; PARENT_TITLE_ID FK,        │
│                        SEASON_NUMBER, EPISODE_NUMBER) ← F-02        │
│                                                                     │
│   • This is what the ERD diagram shows (in ERD-level notation:      │
│     Title, Person, TitleAKA, …, with snake_case attributes)         │
│   • SQL DDL renames per §1.7: TITLE_ID = tconst, TALENT_ID = nconst │
│   • This is what the report describes as "the schema"               │
│   • R2RML reads from here                                           │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │  DROP TABLE *_staging
                                  │  (02_etl.sql step (iv))
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  5. ADD FKs + INDEXES on canonical tables                           │
│     03_indexes.sql                                                  │
│   • After population, for fast LOAD                                 │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  │  java -jar r2rml.jar
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│  6. KNOWLEDGE GRAPH (RDF)                                           │
│     output/cineexplorer_kg.ttl                                      │
└─────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼   loaded into Apache Fuseki
                              SPARQL endpoint, Bacon number, SHACL …
```

### Why staging tables (not "raw + views")?

A previous draft of D-03 (in `docs/plan.md`) used persistent raw tables + SQL views. That was justified by "preserves the existing R2RML mapping unchanged". Phase 2 (Q01 / Q02 / Q04) is rewriting the mapping anyway, so the original justification no longer applies. The staging-tables architecture is now cleaner because:

1. Final DB matches the ERD exactly — no "raw layer" sitting underneath.
2. Standard textbook ETL pattern (also matches the northCoder precedent for `title_principal_raw`).
3. Single source of truth for the report: the canonical tables in `01_canonical_tables.sql`.

### Where each Q## decision lives in this flow

| Decision | Layer affected |
|---|---|
| F-01, F-02 | Canonical schema (`title`, `person`, `episode`, `series` subtype) |
| Q01 | Canonical schema (`participation.role_id`, `person_profession`); ontology axes |
| Q02 | Ontology classes (Person subclasses + Role subclasses); `role` lookup table |
| Q03 | `genre` lookup (27 values, no `Adult`); `title.is_adult` Boolean |
| Q04 | `participation` rows for director/writer come from `title_principals_staging`, not `title_crew_staging` |
| Q06 | `title.average_rating`, `title.num_votes` columns (composite attribute, no separate `Rating` relation) |
| Q07 | `aka` schema (8 columns, no `title_aka_title_type` junction) |
| Q13 | `episode` table + `hasEpisode` relationship (subset of `title`) |

---

## 2. Open questions

Each question is independent. Discuss in any order. When a decision is reached, summarise it under "Decision" and update §1.

---

### ERD-Q01 — Role vs Profession (entity vs relationship)

**The question.** `title.principals.category` and `name.basics.primaryProfession` share most of their vocabulary but model two different things. Do we (a) model them as one concept, or (b) keep them separate?

**Evidence.** From `docs/raw_imdb_analysis.md` §12.1:
- 13 distinct `category` values, 46 distinct `primaryProfession` values.
- 12 values in both; `self` only in `category`; 34 only in `primaryProfession` (mostly department-level / off-screen).
- Concrete: Christopher Nolan's `primaryProfession = director, writer, producer`; on *Inception* he has **three** principal rows (one per category). Same vocabulary, two different facts.

**Options.**
- **(a) Two-axis model — RECOMMENDED.** `Participation hasRole Role` from `category`; `Person hasProfession Profession` from `primaryProfession`. Shared 12-value `Role` taxonomy; `self` Participation-only; 34 department professions Person-only.
- **(b) Single source — Person typed by `primaryProfession`.** Simpler. `category` becomes a free string on Participation.
- **(c) Single source — Person typed by `category` (current behaviour).** Simplest. Loses career-vs-credit distinction.
- **(d) Drop department-level professions.** Smaller vocabulary, loses off-screen-only persons.

**Schema impact.** Option (a) needs `Person ↔ Profession` junction + `Participation.role` attribute (or class). Options (b)/(c) leave one column free-text.

**Ontology impact.** Option (a) splits current `Actor`/`Director`/`Writer` etc. usage: per-credit goes through Participation, career goes through Person.

**Mapping impact.** Currently `Person rdf:type :Actor` is generated from `category='actor'` — that becomes `Participation hasRole :Actor` under (a). This is a real mapping change.

**Decision (2026-05-04).** **Option (a) — two-axis model.**

The data evidence is decisive (gathered 2026-05-04, full IMDb):

| Evidence | What it proves |
|---|---|
| 4,675,376 (Title, Person) pairs have ≥ 2 categories | `category` is per-credit, not per-person identity |
| Of 7.06 M credited persons, 1.66 M span ≥ 2 distinct categories; 21 span 11 | `primaryProfession` is genuinely career-level |
| `self` is 100 % populated for `category=self` and 0 of those rows fall in any `primaryProfession` value | `self` is per-credit only (Participation-only) |
| 12 shared values + 1 category-only (`self`) + 34 profession-only (department-level labels) | Two distinct vocabularies that overlap only on the 12 "real professions" |

### Two axes of typing

```
Person --(0,N)--hasProfession--(0,N)-- Profession   ← from name.basics.primaryProfession
                                                       (max 3 per person)

Participation --(1,1)--hasRole--(0,N)-- Role        ← from title.principals.category
                                                       (exactly 1 per credit)
```

- **Person side**: a person has 0–3 career professions (IMDb caps `primaryProfession` at 3). A profession is held by many persons.
- **Participation side**: a credit has exactly 1 role (single `category` value per row). A role is held by many participations.

### Layer-by-layer realisation

| Layer | Change |
|-------|--------|
| Conceptual ERD | Two binary relationships from the typing axes. `Person → Profession` (M:N, max 3 per person); `Participation → Role` (N:1, exactly 1 per credit). |
| Relational schema | Junction `person_profession(nconst, profession_id)` (composite PK). `participation.role_id` as a single FK column. Two lookup tables: `profession`, `role`. |
| Raw load | `name.basics.primaryProfession` exploded to junction rows during view; `title.principals.category` is per-row. |
| Ontology | New properties `:hasProfession` (Person → Profession), `:hasRole` (Participation → Role). Shared vocabulary on the 12 overlapping values; both Profession and Role carry the same 12 named instances (or matched class hierarchies). |
| Mapping | `Person rdf:type :Actor` (from `category='actor'`) **becomes** `Participation rdf:type :ActingRole`. Person typing comes from `primaryProfession` instead. Real mapping change documented in Q02. |

### Note for the report

Two sentences for §6 Ontology / §7 Mapping:

> "On 4.67 million (Title, Person) pairs in IMDb, the same person is credited under ≥ 2 categories on the same title — direct evidence that `category` is a per-credit fact, not a person-level identity. We model the per-credit role on the Participation entity (`:hasRole`) and the career-level profession on the Person entity (`:hasProfession`)."

> "1.66 million IMDb persons hold credits under ≥ 2 distinct categories during their career; 21 persons span 11. Person subclasses in our ontology are therefore *not* `owl:disjointWith` — a disjointness axiom would falsify the data."

Owner: MIG-15 / MIG-16. Detailed taxonomy reference in `docs/raw_imdb_analysis.md` §12.1 and `docs/erd_investigation.md` Q02.

---

### ERD-Q02 — Person subclasses: extend?

**The question.** Current ontology has 5 `Person` subclasses: `Actor, Director, Writer, Editor, Composer`. IMDb has additional first-class categories: `casting_director`, `archive_footage`, `archive_sound`, plus `producer`, `cinematographer`, `production_designer`. Do we extend?

**Evidence.** Full-IMDb category counts (`docs/raw_imdb_analysis.md` §7.3):
- `producer` 7.4 M, `cinematographer` 4.0 M, `production_designer` 1.2 M — currently unmodelled but very common.
- `casting_director` 1.1 M — unmodelled.
- `archive_footage` 634 K, `archive_sound` 13 K — unmodelled.
- `self` 15 M — special (see Q01).

**Options.**
- (a) Add only `Producer, Cinematographer, ProductionDesigner, CastingDirector`. Skip `archive_*` (they're "person who appears via re-used clip" — not a profession).
- (b) Add all 7 missing categories as subclasses.
- (c) Stop modelling Person subclasses; rely on `Participation hasRole Role` (Q01 option a) and let queries derive type.

**Schema impact.** None if decided in ontology only. Some if we add a `Profession` lookup table.

**Ontology impact.** New OWL classes; possibly new disjointness axioms (or explicitly *not* disjoint, since person can be Actor *and* Director).

**Mapping impact.** New triple maps if subclasses are added.

**Decision (2026-05-04, revised).** **Minimal: 5 Person subclasses (matches original M3 set), `actor + actress` collapsed to `:Actor`, non-disjoint. No Role OWL class hierarchy — `:hasRole` is a datatype property.**

The earlier draft of this decision proposed 9 Person subclasses (adding `:Producer, :Cinematographer, :ProductionDesigner, :CastingDirector`). For a course project of this scope, that adds OWL surface area without proportional value. Reverting to the M3 set keeps the ontology compact and matches what `docs/ontology_reference.md` already documents.

### Person subclasses (5, non-disjoint)

| OWL class | Sourced from `primaryProfession` value(s) |
|---|---|
| `:Actor` | `actor`, `actress` (collapsed — see note below) |
| `:Director` | `director` |
| `:Writer` | `writer` |
| `:Editor` | `editor` |
| `:Composer` | `composer` |

**No `owl:disjointWith` axioms** between any pair — 1.66 M IMDb persons span ≥ 2 categories. Disjointness would falsify the data.

### Categories outside the 5 Person subclasses

The 7 remaining IMDb category values (`producer`, `cinematographer`, `production_designer`, `casting_director`, `self`, `archive_footage`, `archive_sound`) — and the 33 department-level `primaryProfession` values that aren't in `category` — are still preserved in the data but **don't get OWL Person-subclass typings**. They're represented via:

- `:hasProfession xsd:string` datatype property on `Person` (career level, sourced from `primaryProfession`).
- `:hasRole xsd:string` datatype property on `Participation` (per-credit role, sourced from `category`).

Both are ontologically "thin" — string labels rather than typed individuals. Sufficient for our SPARQL queries (which mostly distinguish actor / director / writer at the OWL-class level via existing M3 direct properties).

### Participation Role — datatype property, not class hierarchy

For consistency with the minimal-Person-subclasses scope, **no `:Role` class hierarchy is added** in the ontology. The `role` SQL lookup table exists (12 rows after Q10's slice-only filtering — every category except `archive_sound`), but:

- `Participation hasRole "actor"` (xsd:string) — datatype assertion.
- `Participation rdf:type :Participation` — no further class typing.

M3's existing direct properties (`:actedIn` / `:hasActor`, `:directed` / `:directedBy`, `:wrote` / `:writtenBy`, `:edited` / `:editedBy`, `:composedFor` / `:composedBy`) remain as the ontology-level shortcuts for the 5 most-queried roles. Other categories (`producer`, `cinematographer`, etc.) only have the `:hasRole` datatype assertion — no direct `Person → Title` shortcut.

### `actor` + `actress` collapse (sub-decision, unchanged)

The IMDb-side data carries `actor` and `actress` as distinct categorical strings (≈ 23.5 M and 17.7 M credits respectively). We collapse them to a single `:Actor` class because the actor/actress distinction is purely a label in IMDb's vintage taxonomy — it does not encode any modelling fact our queries need.

The original IMDb category string (`actor` / `actress`) remains visible in the data via `:hasRole "actor"` or `:hasRole "actress"` if the team wants to preserve the distinction at the data level. The ontology layer treats them as one.

### Layer-by-layer realisation

| Layer | Change |
|-------|--------|
| Ontology | **No new classes added.** Keep existing `:Actor, :Director, :Writer, :Editor, :Composer` (5 subclasses of `:Person`, non-disjoint). New datatype properties: `:hasProfession xsd:string` on `Person`, `:hasRole xsd:string` on `Participation`. |
| Schema | Lookup tables `profession` (sized to slice per Q10), `role` (sized to slice per Q10) for FK integrity in SQL. |
| Mapping | Person typing rules read from `primaryProfession` and emit `Person rdf:type :Actor` / `:Director` / `:Writer` / `:Editor` / `:Composer` only. The other 41 profession values produce only `:hasProfession "name"` datatype triples. Participation gets `:hasRole "category"` always. |
| Junction tables | `person_profession(TALENT_ID, PROFESSION_ID)` populated from `primaryProfession` CSV split. |

### What we lose, what we gain

**Lose** vs the 9-subclass version:
- Querying "all `:Producer` instances" requires `?p :hasProfession "producer"` (string match) instead of `?p a :Producer`.
- No fine-grained class hierarchy for off-screen roles.

**Gain**:
- Smaller ontology, less to defend in the report.
- Matches existing M3 reference doc (`docs/ontology_reference.md`).
- Less mapping code.
- Future extensibility — adding a 6th Person subclass later is one line of OWL + one mapping rule.

### Not added as Person subclasses

| Value | Why not |
|---|---|
| `self` | Per-credit-only label (see Q01); never appears in `primaryProfession`. Belongs only on Participation. |
| `archive_footage`, `archive_sound` | These describe how a Participation appears (re-used clip), not what the person is. Belongs only on Participation. |
| 34 department-level / off-screen labels (`miscellaneous`, `camera_department`, …, `accountant`, `electrical_department`) | Too granular and too numerous (34 classes) for the OWL vocabulary. Captured as **values of `:hasProfession`** — i.e. as instances of a `:Profession` lookup, not as OWL classes. |

### Note for the report

A sentence in §6 Ontology:

> "We retain the original M3 set of five `Person` subclasses (`:Actor, :Director, :Writer, :Editor, :Composer`, all non-disjoint), with `actor` and `actress` from IMDb's `category` collapsed into a single `:Actor` class. Other IMDb category values (producer, cinematographer, casting_director, etc.) are preserved at the data level via the `:hasRole` datatype property on `Participation` and the `:hasProfession` datatype property on `Person`, but do not receive their own OWL class typings — keeping the ontology compact for the scope of this course project."

Owner: MIG-15 / MIG-16.

---

### ERD-Q03 — `Adult` genre

**The question.** The slice has `isAdult = 0` everywhere (filtered out). Full IMDb has 407 K Adult titles. Do we keep `Adult` in the genre vocabulary?

**Evidence.** `docs/raw_imdb_analysis.md` §3.3:
- 28 IMDb genres total; `Adult` is one.
- Even non-`isAdult=1` titles can have `genres = "Adult"` apparently (small overlap in the data).
- Slice covers 22 genres; `Adult` is among the 6 missing.

**Options.**
- (a) Include `Adult` in the genre lookup, even though zero rows in the migrated KG will use it.
- (b) Drop `Adult` from the genre lookup (smaller table, but fragile if we ever reslice without `isAdult` filtering).
- (c) Keep `Adult` and add a SHACL shape forbidding it on titles where `isAdult=0`.

**Schema impact.** Lookup-table size (28 vs 27 rows). Negligible.

**Ontology impact.** Whether `:AdultGenre` exists.

**Mapping impact.** None if we just include the lookup row.

**Decision (2026-05-04).** **Option (b) — drop `Adult` from the genre vocabulary; rely on `Title.is_adult` as the single signal.**

Rationale:

| Argument | Detail |
|---|---|
| Two ways to answer "is this adult?" is one too many | IMDb has both `title.basics.isAdult` (boolean per Title) and `genres = "Adult"` (a tag among up to 3). Of the 407 K Adult-tagged titles in full IMDb, the vast majority also have `isAdult=1`. The boolean is the canonical signal. |
| Our slice excludes Adult titles by construction | The slice filter is `numVotes DESC` top-2,500. All 2,500 have `isAdult=0`, so no genre row in the migrated KG would carry `Adult` anyway. |
| Keeping a never-populated lookup row is noise | A `genre.name = 'Adult'` row that no Title ever references through `title_genre` is dead weight in the ontology and the report. |
| The `is_adult` column is the right tool | A Boolean / xsd:boolean datatype property on `:CreativeWork` answers any "filter out adult" or "show only adult" question without involving the Genre vocabulary at all. |

**Schema realisation.**

| Layer | Change |
|---|---|
| Conceptual ERD | `Title` retains the `is_adult` attribute (single Boolean). The `Genre` lookup has **27 values**, not 28. No `:AdultGenre`. |
| Relational schema | `title.is_adult TINYINT NOT NULL DEFAULT 0`. `genre` lookup populated with 27 IMDb-canonical names (all of `Drama, Comedy, Talk-Show, Short, News, Documentary, Romance, Family, Reality-TV, Animation, Crime, Action, Adventure, Game-Show, Music, Sport, Fantasy, Horror, Mystery, Thriller, History, Biography, Sci-Fi, Musical, War, Western, Film-Noir`). |
| Ontology | Existing `:hasGenre` / `:isGenreOf` properties unchanged. New `:isAdult xsd:boolean` datatype property on `:CreativeWork`. **No `:AdultGenre` class or instance.** |
| Mapping | Triple map for `:isAdult` reads `title.basics.isAdult`. Triple map for `:hasGenre` skips any row with `genre = 'Adult'` (defensive — though our slice never has any). |

**Future-proofing note.** If a future reslice includes adult titles (`isAdult=1`), R2RML will silently skip rows whose `genres` token is `Adult` because the lookup doesn't contain that value. To re-introduce, add one row to the `genre` lookup and (optionally) one OWL instance. No schema redesign needed.

**Note for the report.** Worth one sentence in §6 Ontology / §2 Database explaining the choice:

> "The migrated schema treats adult content via a single `:isAdult` Boolean property on `:CreativeWork`, rather than via the `Adult` genre tag that also appears in IMDb. The two carry redundant information, and the Boolean is the canonical signal; our slice contains no adult titles by construction (`numVotes DESC` filter does not include them)."

Owner: MIG-15.

---

### ERD-Q04 — `title.crew` vs `title.principals` for director/writer

**The question.** IMDb stores director/writer info twice:
- `title.principals` rows with `category in ('director','writer')` — top-billed credits, max ~4 per title.
- `title.crew.directors` / `.writers` — exhaustive CSV nconst lists, max **528** / **1,393** per tconst.

For a movie they roughly agree; for TV series they diverge by orders of magnitude. Pick one source for the migrated KG, or model both?

**Evidence.** `docs/raw_imdb_analysis.md` §5: max director count 528, max writer count 1,393. `title_crew` requires a junction table at this scale (CSV column impossible).

**Options.**
- (a) **Use `title.principals` only** (top-billed). Loses the long tail. Best for collaboration-graph (Bacon-number) since hubs don't dominate.
- (b) **Use `title.crew` only** (exhaustive). Includes the long tail. Bacon-number degree distribution becomes extreme.
- (c) **Use both, with a flag** distinguishing top-billed vs aggregated. Most expressive, most complex.
- (d) **Use `title.principals` for principals + `title.crew` for `directedBy/wroteBy` roles only**, treating them as semantically different.

**Schema impact.** Option (a) is the simplest; (c) needs an extra Boolean column on Participation.

**Ontology impact.** Affects `:directed`, `:directedBy`, `:wrote`, `:writtenBy` definitions — what counts as "directed"?

**Mapping impact.** Choice of input table for the directing/writing triple maps.

**Decision (2026-05-04, revised).** **Option (a) — `title.principals` only.**

All 13 IMDb principal categories (including `director` and `writer`) flow through the **Participation** weak entity (Q01 / Q05). `title.crew` is loaded into `title_crew_staging` for symmetry of the ETL (every IMDb file gets a staging table) but **never read** by the `INSERT INTO canonical` step — it is dropped together with the rest of the staging tables.

**Why we revised from the earlier "use `title.crew`" position.**

| Argument | Detail |
|---|---|
| Consistency with the rest of the model | All other categories (actor, producer, composer, editor, cinematographer, casting_director, …) flow through Participation. Carving out a special-case path for director/writer would create a uniform-versus-special-case asymmetry. With `title.principals` only, every category is handled the same way. |
| Preserves `job` and `ordering` per-credit metadata | `title.principals` carries `job` (`written by`, `screenplay`, `creator`, `novel`, `story`, `head writer`, `dialogue`, …, ~47 K distinct values) and `ordering` (1..N billing rank). `title.crew` collapses these into one undifferentiated "everyone who directed/wrote" list. |
| The "exhaustive coverage" advantage of `title.crew` is mostly hypothetical for our slice | `title.crew` carries 884 K extra director-pairs across all of IMDb, but those extra credits are concentrated on **obscure long-running TV** that our `numVotes DESC` slice excludes. The popular bridge-persons we actually care about (Brad Pitt, Hans Zimmer, Robert De Niro, …) are perfectly captured by `title.principals`. |
| Simpler mapping | One source, one path. No CSV explosion of `directors`/`writers`. The mapping for `:directed` / `:wrote` looks identical in shape to `:actedIn` / `:produced`. |
| Aligns with Q01 / Q02 architecture | We already decided that Participation is the locus of per-credit roles, and the 12 Participation Role classes include `:DirectingRole` and `:WritingRole`. Sourcing them from `title.principals` makes those classes populate uniformly with the others. |

**Cardinality (verified 2026-05-04).** With `title.principals` as the source, the cardinality on the Title side becomes `(0,N)` for the same data-quality reason as before, just measured slightly differently. From `title.principals`:

| Category | Distinct Titles with ≥ 1 such credit |
|---|---:|
| `director` | ~6.97 M (55.9 % — the rest are TV episodes with no per-episode director-credit row) |
| `writer` | ~6.35 M (50.9 %) |

So `Participation --hasRole--> :DirectingRole`-style modelling has the same `(0,N)` Title-side cardinality. **Modelling-wise, nothing changes from what was previously argued — we just source the rows from `title.principals` instead of `title.crew`.**

**Layer-by-layer realisation.**

| Layer | Change |
|-------|--------|
| Conceptual ERD | No new relationships beyond the existing `participatesIn` (Person → Participation → Title) chain established in Q01/Q05. The `direct` and `write` relationships from earlier drafts are absorbed into `Participation hasRole {DirectingRole, WritingRole}`. |
| Relational schema (canonical) | Director/writer credits live as rows in `participation` with `ROLE_ID` matching the lookup row for `Director` / `Writer`. **No separate `directed_by` / `written_by` junction tables.** |
| Staging tables (transient) | `title_principals_staging` is loaded; `INSERT INTO participation SELECT … FROM title_principals_staging` populates director/writer rows alongside all other categories. `title_crew_staging` is **loaded for symmetry but never read**, then dropped. |
| Ontology | Existing properties `:directed` / `:directedBy` / `:wrote` / `:writtenBy` keep their semantics. Their *instances* are derived via Participation: `Person → Participation (hasRole :DirectingRole) → CreativeWork`. Cardinality axioms must use `min 0` (already the case). |
| Mapping | Triple maps for `:directed` / `:wrote` flow through the Participation triple-map family. **No separate triple maps from `title.crew`** (would double-count if added). |

**What we lose (and why it's acceptable).**

- The 884 K (director) + 2.9 M (writer) extra `(tconst, nconst)` pairs that exist in `title.crew` but not in `title.principals`. Mostly long-tail TV directors / ghost-writers on obscure soap operas. **None of them are in our slice** (filtered out by `numVotes DESC`).
- The team can revisit if a future demonstrator or report claim specifically needs this exhaustive coverage — `title_crew_staging` exists during ETL and could be wired in. But the default migrated KG does not include them.

**Note for the report.**

The 44 %/49 % NULL pattern on `title.crew.directors`/`writers` is non-obvious and deserves a sentence in the report. Suggested phrasing for §2 Database (or wherever cardinality choices are justified):

> "Cardinality on the `direct` and `write` relationships is `(0,N)` on the Title side — not `(1,N)` — because IMDb's `title.crew` has NULL `directors` for 44.1 % of all Titles and NULL `writers` for 49.1 %. Both NULL populations are dominated by TV episodes, which conventionally inherit their crew credits from the parent series rather than carrying per-episode credits. Modelling the relationship as `(1,N)` would falsely require every work to have a director credited, which contradicts ~5.5 M IMDb rows."

Owner: MIG-15 (§2 Database update). Will be picked up when §2 of the report is rewritten.

**Implication for the Bacon-number demonstrator (note for §10).** Using `title.crew` (exhaustive) rather than `title.principals` (top-billed) inflates the collaboration graph for long-running TV: a soap opera with 96 directors becomes a 96-clique, contributing ~4,500 edges from one node. This *helps* connectivity (more bridge persons) but skews degree distribution. Worth a brief note in §10 alongside the slice's actual numbers.

---

### ERD-Q05 — `characters` JSON modelling

**The question.** `title.principals.characters` is a JSON array of strings. 99.99999 % single-element; 6 multi-element rows in all of IMDb. How do we model it?

**Evidence.** `docs/raw_imdb_analysis.md` §7: 48,449,556 single-element entries; 6 two-element entries.

**Options.**
- (a) **JSON_TABLE during ETL**, materialise into a junction table. Produces 1 row almost always, 2 rows in 6 cases. Schema-clean.
- (b) **Treat `characters` as a single VARCHAR** (the JSON text is opaque). Multi-element rows become "the JSON looks like `[\"A\",\"B\"]`" — survives but is ugly.
- (c) **Strip `[" ... "]` wrapping in ETL, expose as a single VARCHAR per row.** Loses the 6 multi-element cases or corrupts them.

**Schema impact.** (a) introduces one junction table; (b) replaces it with a column on Participation.

**Ontology impact.** `:participationRole` (or equivalent) datatype property semantics.

**Mapping impact.** (a) is closest to the current M3 design (which already has `principal_role`).

**Decision (2026-05-04).** **Option (a) — `JSON_TABLE` exploding into a junction table; `characters` is a multi-valued attribute on `Participation`.**

### Modelling

```
Participation (weak entity, PK = (tconst, ordering))
   │
   │ multi-valued attribute (Chen double-circle notation)
   ▼
character_name  ←  values from JSON_TABLE explosion
```

After relational reduction:

```
participation_character(TITLE_ID, ORDERING, CHARACTER_NAME)
   composite PK = all three columns
   FK (TITLE_ID, ORDERING) → participation
```

### Why this option

| Argument | Detail |
|---|---|
| 1NF correctness | Multi-valued attributes must be normalised into a separate relation. The data has 6 multi-valued cases out of 99 M; even if rare, the schema must handle them. |
| Future-proof | A future re-load (or future IMDb data shape change) could increase the multi-element rate. The junction handles any cardinality. |
| Matches northCoder pattern | northCoder's `principal_role` table has the same shape (junction with `CHARACTER_NAME` as part of PK). Our `participation_character` is the equivalent for the migrated schema, simplified (no redundant `TALENT_ID` since `(TITLE_ID, ORDERING)` already identifies a Participation). |
| Single-element common case is cheap | 99.99999 % of credits produce one row in the junction. Disk and query cost are dominated by `actor`/`actress`/`self` rows that all have one `character_name` entry — efficient. |

### Cardinality (verified at full IMDb scale)

| Items in JSON array | Credits | Junction rows produced |
|---:|---:|---:|
| 1 | 48,449,556 | 48,449,556 |
| 2 | 6 | 12 |
| **Total junction rows** | **48,449,562** | |

Plus, 51 % of `title.principals` rows have NULL `characters` (overwhelmingly the non-acting categories), so they produce zero junction rows. The 48.4 M figure above is for the `characters IS NOT NULL` subset.

### Layer-by-layer realisation

| Layer | Change |
|-------|--------|
| Conceptual ERD | Multi-valued attribute `character_name` on `Participation` (Chen double-circle). |
| Relational schema (canonical) | New table `participation_character(TITLE_ID, ORDERING, CHARACTER_NAME)`, composite PK, FK to `participation`. |
| Staging tables (transient) | `title_principals_staging.characters` carries the raw JSON string. |
| ETL | `INSERT INTO participation_character (TITLE_ID, ORDERING, CHARACTER_NAME) SELECT p.tconst, p.ordering, TRIM(BOTH '"' FROM j.value) FROM title_principals_staging p, JSON_TABLE(p.characters, '$[*]' COLUMNS (value VARCHAR(500) PATH '$')) j WHERE p.characters IS NOT NULL;` |
| Ontology | Existing `:characterName` (or equivalent) datatype property attached to `:Participation`. The current M3 ontology has `principal_role`-related vocabulary that maps cleanly. |
| Mapping | Triple maps for `:characterName` read from `participation_character`. One triple per junction row. |

### Note for the report

> "The `characters` field is functionally single-valued in IMDb (only 6 multi-element entries in 99 M rows, and all 6 appear to be export-bug artefacts where a single character name containing a comma was incorrectly split). We model `character_name` as a multi-valued attribute on `Participation` for 1NF correctness and to match the northCoder `principal_role` precedent — even though the resulting junction table almost always has exactly one row per credit."

Owner: MIG-15 (§2 Database) and MIG-16 (§7 Mapping) where `participation_character` is described.

---

### ERD-Q06 — `title.ratings`

**The question.** Universally populated (zero NULL), no equivalent in current schema or ontology. Add it?

**Evidence.** `docs/raw_imdb_analysis.md` §8:
- 1.67 M titles have ratings (only 13 % of all IMDb titles).
- All 2,500 titles in our slice have ratings (100 %, since we *selected* by `numVotes DESC`).
- `averageRating` 1.0–10.0; `numVotes` 5 – 3,185,031.

**Options.**
- (a) **Add `rating` table + `:averageRating` and `:numVotes` datatype properties on `:CreativeWork`.** Cheap. Enables Q11 SPARQL queries ("films rated > 8 in Drama").
- (b) **Add `rating` table without ontology surface** (load it but don't map to RDF). Wasted disk + irrelevant for the KG.
- (c) **Skip ratings entirely.** Loses the slice criterion's data; ratings aren't queryable.

**Schema impact.** (a) adds one table.

**Ontology impact.** (a) adds two datatype properties on `:CreativeWork`. No new classes.

**Mapping impact.** (a) adds one or two TermMaps.

**Decision (2026-05-04).** **Option (a), modelled as a composite attribute on `Title`.**

Rationale:
- `title.ratings` is 1-to-1 with `title.basics.tconst`; the table's PK *is* the FK to Title (no rating identifier of its own → no entity).
- `averageRating` and `numVotes` always co-occur (zero NULL when the row exists, per `docs/raw_imdb_analysis.md` §8). Classic ERD composite-attribute pattern (analogous to `Address = {street, city, postcode}` on a `Person`).
- Two attributes about the same Title, grouped because they share a domain (popularity / quality).

Layer-by-layer realisation:

| Layer | Change |
|-------|--------|
| Conceptual ERD | Composite attribute `rating = {average_rating, num_votes}` on `Title`. **No separate `Rating` entity box** on the diagram. |
| Relational schema (canonical) | Composite attribute renders as **two columns on the `Title` relation**: `Title(tconst, …, average_rating, num_votes)`. **No `Rating` relation in the schema.** |
| Staging tables (transient — exist briefly during `02_etl.sql`, then dropped) | `title_basics_staging` and `title_ratings_staging` mirror their TSV files. The ETL `INSERT INTO title (tconst, …, average_rating, num_votes) SELECT b.tconst, …, r.averageRating, r.numVotes FROM title_basics_staging b LEFT JOIN title_ratings_staging r ON r.tconst = b.tconst` populates the composite attribute. |
| Ontology | Two datatype properties on `:CreativeWork`: `ce:averageRating` (`xsd:decimal`) and `ce:numVotes` (`xsd:nonNegativeInteger`). **No new class.** |
| R2RML mapping | One TermMap on the `:CreativeWork` triple-map family emitting both predicates. ~10 lines added. Reads from the canonical `title` table. |

Optional SHACL refinement: a shape can express the "both-or-none" co-occurrence — `sh:and` of the two `sh:property` constraints, conditionally activated. Defer to SHACL phase.

Downstream value: enables Q-rating SPARQL queries (e.g., "highest-rated Drama films", "films with > 1M votes"), and gives the report a concrete handle for the slice-criterion narrative ("our slice is the top 0.15 % of titles by `numVotes`").

---

### ERD-Q07 — `title.akas`

**The question.** The current schema models AKAs with a junction table + `title_aka_title_type` for type tags. Official IMDb provides `region`, `language`, `types`, `attributes` directly on each aka row. Keep current shape, or simplify?

**Evidence.** `docs/raw_imdb_analysis.md` §4:
- 252 regions, 111 languages, 24 types (incl. malformed concatenations), 185 attributes (free text).
- `types` is single-valued in practice (despite IMDb spec saying multiset).
- `attributes` is 95 % NULL.

**Options.**
- (a) **Keep current schema** (`title_aka` + `title_aka_title_type` junction). Mapping unchanged.
- (b) **Simplify** — collapse `title_aka_title_type` into a `types` VARCHAR column on `title_aka`. Removes one table; mapping simpler.
- (c) **Drop `attributes`** — 95 % NULL, mostly metadata noise.
- (d) **Drop both `types` and `attributes`** — and drop the `title_aka_title_type` junction entirely.

**Schema impact.** (b) drops one table; (c) drops one column; (d) drops one table + two columns.

**Ontology impact.** Minimal — this is mostly a SQL-level decision.

**Mapping impact.** (a) zero change; (b) updates one TermMap; (c) drops one TermMap; (d) drops several.

**Decision (2026-05-04, revised).** **Option (b) — keep `types` and `attributes` as plain VARCHARs on `TitleAKA`; drop the `title_aka_title_type` junction.**

The original draft of this decision (option d, drop both columns) was reconsidered: the real complaint was about the *junction-table modelling*, not the columns themselves. As plain VARCHARs they cost two mostly-NULL columns and preserve all IMDb-side information.

### Three relations

| # | Relation | Type | Attributes / keys |
|---|---|---|---|
| 1 | `TitleAKA` | Weak entity of `Title` | `(tconst, ordering, title, region, language, is_original_title, types, attributes)` <br> PK = `(tconst, ordering)` ; FK `tconst → Title.tconst` ; FK `region → Region.region_id` (nullable) ; FK `language → Language.language_id` (nullable) |
| 2 | `Language` | Strong entity (lookup, ~110 ISO 639 codes) | `(language_id, language_name)` ; PK = `language_id` |
| 3 | `Region` | Strong entity (lookup, ~252 ISO 3166 codes incl. historical like `XWW`) | `(region_id, region_name)` ; PK = `region_id` |

### ER relationships

```
Title --(0,N)-- hasAKA --(1,1)-- TitleAKA
TitleAKA --(0,1)-- akaInLanguage --(0,N)-- Language
TitleAKA --(0,1)-- akaInRegion   --(0,N)-- Region
```

- `Title.hasAKA` is `(0,N)` rather than `(1,N)` because ~4,500 IMDb titles have zero aka rows (corner case but observed).
- `(0,1)` on the TitleAKA side of `akaInLanguage` reflects 70 % NULL `language` in the raw data; on `akaInRegion` it reflects 1.7 % NULL.

### Why "keep as plain VARCHARs" beats "drop entirely"

| Aspect | Drop both (originally chosen) | Keep as plain VARCHARs (final) |
|---|---|---|
| Information preserved | No — working titles, DVD/festival tags, attribute strings all gone | **Yes — every IMDb fact stays in the schema** |
| `title_aka_title_type` junction needed? | No (gone) | **No (just plain columns on `TitleAKA`)** |
| ETL splitting / normalization needed? | No | **No (malformed `imdbDisplaydvd` is just a string)** |
| Ontology surface | Nothing exposed | Optional — can map or not |
| Schema columns | 6 | 8 |
| Mapping complexity | Less | Slightly more if we choose to expose `types` / `attributes` |

The previous "drop" rationale was driven by:
- mostly-NULL columns
- redundancy of `types='original'` with `isOriginalTitle`
- malformed concatenations
- removing the `title_aka_title_type` junction

Of those, only the junction-removal genuinely simplifies the schema. The columns themselves cost almost nothing as plain VARCHARs, and they preserve the working-title / DVD-alternate facts that we may want for niche queries later.

### Lookup-table population (operational note)

`language_name` and `region_name` are **not in the IMDb dump** — `title.akas` only carries the codes. Two viable approaches:

| Approach | How |
|---|---|
| Hard-coded `UPDATE` statements (matches northCoder) | A block of `UPDATE language SET language_name='English' WHERE language_id='en';` lines in the schema setup. The northCoder schema already has these working. |
| Leave names NULL | Schema accepts NULL on `language_name` / `region_name`; only codes are mandatory. Loses display strings but keeps the migration smaller. |

Reusing the northCoder `UPDATE` blocks is essentially free; recommend that.

### Layer-by-layer realisation

| Layer | Change |
|-------|--------|
| Conceptual ERD | Three entities for the AKA cluster: `TitleAKA` (weak), `Language` (strong/lookup), `Region` (strong/lookup). **No `AkaType` entity.** |
| Relational schema | `title_aka` table has 8 columns (incl. `types`, `attributes`). **`title_aka_title_type` table dropped entirely.** `language` and `region` lookup tables retained from northCoder, populated via `UPDATE`. |
| Staging tables (transient) | `title_akas_staging` mirrors all 8 IMDb columns; the ETL `INSERT INTO title_aka SELECT … FROM title_akas_staging` passes them all through (no transformation needed beyond column renames). |
| Ontology | Decide at mapping time whether to expose `types`/`attributes` as datatype properties (e.g. `ce:akaType`, `ce:akaAttributes`). Likely keep them ungraphed unless a query needs them. **`:AkaType` class can be removed** (no longer needed even if we expose `types` as a string property). |
| Mapping | Drop the triple-map(s) for `title_aka_title_type`. Optionally add simple `:akaType`, `:akaAttributes` datatype-property emissions on the `title_aka` triple-map. |
| Lookup table | `title_type` lookup table (8 canonical values + ~4 malformed) **gone**. |

This is still a **net simplification** versus the current northCoder schema (one fewer table, no junction), while preserving every column from the IMDb source.

---

### ERD-Q08 — `knownForTitles`

**The question.** `name.basics.knownForTitles` is a CSV of up to 4 tconsts per person. References can point to titles outside our slice (full IMDb has 12 M titles; our slice keeps 2,500). What do we do with the references that fall outside?

**Evidence.** `docs/raw_imdb_analysis.md` §9 and slice findings:
- 11.9 % NULL across full IMDb.
- 6.3 M distinct CSV combinations.
- Refs that don't resolve to slice titles are "soft FK violations" — the tconst is valid in IMDb but absent in our DB.

**Options.**
- (a) **Drop the column / property.** Cleanest. Loses the "knownFor" relationship.
- (b) **Soft FK.** Keep all 4 references per person. Some will dangle — schema doesn't enforce, mapping silently skips dangling.
- (c) **Filter to slice tconsts at load time.** Each person ends up with 0–4 surviving knownFor refs. Schema is FK-clean.
- (d) **Conditional ontology assertion** — only emit `:knownFor` triple if the target tconst is in the slice (R2RML R2 conditions).

**Schema impact.** (b) requires no FK constraint; (c) requires filtering during ETL.

**Ontology impact.** `:knownFor` already exists. Just affects whether triples are emitted.

**Mapping impact.** (c) is cleanest in mapping (no broken refs); (d) needs conditional logic.

**Decision (2026-05-04).** **Option (c) — keep `knownForTitles`, filter to slice tconsts at ETL load.**

### Modelling

```
Person --(0,4)-- knownFor --(0,N)-- Title
```

- **Person side `(0,4)`**: each Person can be known for 0 to 4 Titles (IMDb caps at 4).
- **Title side `(0,N)`**: a Title can be in many Persons' knownFor sets.
- M:N relationship → reduces to junction table.

### Relational reduction

```
person_known_for(TALENT_ID, TITLE_ID)
   composite PK = both columns
   FK TALENT_ID → person.TALENT_ID
   FK TITLE_ID  → title.TITLE_ID    (enforced — see filtering below)
```

### Filtering at ETL load

The ETL `INSERT … SELECT` joins `name.basics.knownForTitles` (CSV-exploded via `JSON_TABLE`) against the canonical `title` table. Rows where the referenced `TITLE_ID` is **not in our slice** are silently filtered out by the JOIN.

```sql
INSERT INTO person_known_for (TALENT_ID, TITLE_ID)
SELECT n.nconst,
       j.value
FROM   name_basics_staging n
JOIN   JSON_TABLE(
         CONCAT('["', REPLACE(n.knownForTitles, ',', '","'), '"]'),
         '$[*]' COLUMNS (value VARCHAR(20) PATH '$')
       ) j
JOIN   title t ON t.TITLE_ID = j.value      -- this JOIN drops dangling refs
WHERE  n.knownForTitles IS NOT NULL;
```

The `JOIN title` discards any `knownForTitles` reference whose tconst isn't in our slice.

### Cardinality observed in our slice (estimated)

For our 21,077 persons, each with up to 4 `knownForTitles`:
- Roughly 60–80 % of references resolve to slice titles (because popular persons have popular known-for films, which are likely already in our top-2,500).
- Net: ~50,000 surviving (TALENT_ID, TITLE_ID) pairs in `person_known_for` (rough estimate; actual number measured at MIG-08).

### Why option (c) over (b)

| | (b) Soft FK / dangling | (c) Filter at load |
|---|---|---|
| FK constraints honored | No | **Yes** |
| Persons with dangling refs in SQL | many (~40 % of references) | none — only valid refs survive |
| RDF triples about non-slice titles | yes (KG has dangling URIs) | no |
| ETL complexity | trivial (no filter) | one extra JOIN |
| Schema cleanness | weakened FKs | clean FKs |
| Defensibility in report | "we accept dangling refs" | "FK-clean by construction" |

(c) is cleaner. The "lost data" (40 % of references that don't resolve) refers to non-slice titles that aren't in our DB anyway — losing the knownFor link to them costs nothing meaningful for any SPARQL query.

### Layer-by-layer realisation

| Layer | Change |
|-------|--------|
| Conceptual ERD | M:N relationship `knownFor` between `Person` and `Title`. `(0,4)` on the Person side; `(0,N)` on the Title side. |
| Relational schema | New junction `person_known_for(TALENT_ID, TITLE_ID)` with composite PK and both FKs enforced. |
| Staging tables (transient) | `name_basics_staging.knownForTitles` carries the raw CSV. |
| ETL | INSERT shown above — JSON_TABLE explosion + JOIN against `title` to filter dangling refs. |
| Ontology | Existing `:knownFor` property kept. |
| Mapping | Triple map reads from `person_known_for`; one `:knownFor` triple per junction row. |

### Note for the report

> "Each person's `knownForTitles` list (up to 4 IMDb tconsts) is loaded with referential-integrity filtering at ETL time. References pointing to titles outside our slice are silently dropped by the load step, leaving each Person with 0–4 surviving `knownFor` references. This keeps the schema FK-clean without sacrificing more than non-popular-title references that we wouldn't have data for anyway."

Owner: MIG-15.

---

### ERD-Q09 — NULL handling at scale

**The question.** R2RML automatically skips NULL columns when generating triples. Does this still produce a clean KG given full-IMDb's NULL profile? E.g., 95.6 % of persons have no `birthYear`.

**Evidence.** Full-IMDb NULL rates from `docs/raw_imdb_analysis.md`:
- `name.basics.birthYear` 95.6 %, `deathYear` 98.3 %.
- `title.basics.runtimeMinutes` ~50 %.
- `title.principals.job` 80.9 %, `characters` 51.2 %.

**Options.**
- (a) **Confirm R2RML's behaviour is what we want** — yes, NULL columns generate no triple. Already validated in M3 fixes.
- (b) Materialise placeholder values. Worse — adds noise.

**Schema impact.** None.

**Ontology impact.** Cardinality axioms must use `min 0`-style (no minimum). Already true in current ontology.

**Mapping impact.** Already handled.

**Decision (2026-05-04).** **Option (a) — confirmed.** R2RML's automatic NULL-column skipping is the correct strategy at the new scale; no schema or ontology changes required.

### What this confirms

R2RML's documented behaviour: when a TermMap's column is NULL, **no triple is emitted** for that subject-predicate combination. (See R2RML spec §10.2.) The KG silently omits the assertion, which is the correct semantics for OWL's Open World Assumption — "we don't know X's `birthYear`" is correctly represented as the absence of any `:birthYear` triple, not as a placeholder.

### NULL rates this protects us from (full IMDb)

| Column | NULL % | Effect with R2RML's skip-on-NULL |
|---|---:|---|
| `name.basics.birthYear` | 95.6 % | Most persons get no `:birthYear` triple — correct |
| `name.basics.deathYear` | 98.3 % | Most persons get no `:deathYear` triple — correct |
| `name.basics.primaryProfession` | 20.1 % | Person → Profession junction has no row for unprofessional persons (correct) |
| `name.basics.knownForTitles` | 11.9 % | No `:knownFor` triple for those persons (correct) |
| `title.basics.runtimeMinutes` | ~50 % | No `:runtimeMinutes` triple for half of titles (correct — runtime genuinely unknown) |
| `title.basics.endYear` | very high | Only series carry `endYear` — correctly absent on movies |
| `title.principals.job` | 80.9 % | No `:job` triple for ~81 % of credits (correct — `job` is optional refinement on `category`) |
| `title.principals.characters` | 51.2 % | No row in `participation_character` for non-acting credits (correct) |
| `title.akas.region` | 1.7 % | No `:region` triple for ~1.7 % of akas (correct — region genuinely unknown) |
| `title.akas.language` | 70 % | No `:language` triple for most akas (correct) |

### What's already in place (no change needed)

- **Cardinality axioms** in the M3 ontology already use `min 0` (no minimum) for all attributes that can be NULL. This was a deliberate choice per FIX-06 and confirmed in `docs/ontology_reference.md`.
- **R2RML mapping** already lacks `rr:logicalTable.rr:sqlQuery COALESCE(...)` patterns — there's no placeholder-materialisation logic to remove.
- **SHACL shapes** in `sparql/cineexplorer_shapes.ttl` use `sh:minCount 1` only on attributes that are observably never NULL (`tconst`, `nconst`, `primaryName`, etc.). The high-NULL columns (`birthYear`, `runtimeMinutes`, etc.) are correctly outside any `sh:minCount 1` constraint.

### Layer-by-layer realisation

| Layer | Change |
|-------|--------|
| Conceptual ERD | None. |
| Relational schema | None. Existing nullability of columns (per CREATE TABLE in `01_canonical_tables.sql`) is correct. |
| ETL | None. |
| Ontology | None — `min 0` cardinality axioms already in place. |
| Mapping | None — R2RML's default null-skip is what we want. |

### Note for the report

> "All R2RML triple maps rely on R2RML's documented behaviour of emitting no triple when the source column is NULL. This is the correct semantics for OWL's Open World Assumption: an absent triple represents 'unknown', not 'false'. The much higher NULL rates at full IMDb scale (e.g. 95.6 % NULL on `birthYear`, 50 % on `runtimeMinutes`) are handled transparently — the KG silently omits the corresponding triples for those rows."

This sentence belongs in §7 Mapping or §6 Ontology depending on emphasis. Owner: MIG-15 / MIG-16.

---

### ERD-Q10 — Rare `titleType` / `category` values

**The question.** Some IMDb categorical values exist in the dump but are absent from our 2,500-title slice:
- `titleType`: `tvPilot` (1 row in all of IMDb!), `tvShort` (11 K), `tvSpecial` (58 K), `videoGame` (49 K), `tvMovie` (155 K), `video` (325 K), `short` (1.1 M).
- `category`: `archive_sound` (13 K).

Do we plan for them?

**Options.**
- (a) Include all 11 `titleType` values + 13 `category` values in the relevant lookup tables, even when not present in the loaded data. Future-proof.
- (b) Only include values actually present in the loaded slice. Smaller; brittle to reslicing.
- (c) Include the canonical IMDb 11/13 explicitly, regardless of slice contents.

**Schema impact.** Lookup tables are tiny; (a)=(c) safer.

**Ontology impact.** Whether the ontology has e.g. `:VideoGame` as a class.

**Mapping impact.** None on the lookups; affects whether typing rules apply.

**Decision (2026-05-04).** **Option (b) — only include values actually present in the loaded slice.** No hard-coded `INSERT VALUES` statements in the schema DDL.

### How it's implemented

The ETL `02_etl.sql` populates lookup tables dynamically from the staging data:

```sql
INSERT IGNORE INTO genre (GENRE_ID, GENRE_NAME)
SELECT TRIM(j.value), TRIM(j.value)
FROM   title_basics_staging b,
       JSON_TABLE(
         CONCAT('["', REPLACE(b.genres, ',', '","'), '"]'),
         '$[*]' COLUMNS (value VARCHAR(64) PATH '$')
       ) j
WHERE  b.genres IS NOT NULL
  AND  TRIM(j.value) <> 'Adult';     -- per Q03

INSERT INTO title_type (TITLE_TYPE_ID, TITLE_TYPE_NAME)
SELECT DISTINCT titleType, titleType
FROM   title_basics_staging
WHERE  titleType IS NOT NULL;

INSERT INTO role (ROLE_ID, ROLE_NAME)
SELECT DISTINCT
       CASE WHEN category IN ('actor','actress') THEN 'actor' ELSE category END,
       CASE WHEN category IN ('actor','actress') THEN 'actor' ELSE category END
FROM   title_principals_staging
WHERE  category IS NOT NULL;

-- … similar for language, region, profession
```

(Sketches — exact SQL written in MIG-04.)

### Resulting lookup sizes (estimated from Phase 1 slice analysis)

| Lookup | Rows in slice (Q10 b) | IMDb canonical (would be Q10 a/c) |
|---|---:|---:|
| `title_type` | 4 (`movie`, `tvSeries`, `tvMiniSeries`, `tvEpisode`) | 11 |
| `genre` | ~22 | 27 (after Q03 drops `Adult`) |
| `role` | 12 (everything except `archive_sound`) | 13 (after `actor`+`actress` collapse) |
| `language` | ~110 | 110 |
| `region` | ~252 | 252 |
| `profession` | ~26 | 46 |

### Trade-offs accepted

| Aspect | Cost / benefit |
|---|---|
| Schema is honest about loaded data | ✓ benefit — no empty lookup rows for `tvPilot`, `archive_sound`, etc. |
| Reslice friendliness | ✗ cost — a future N=10,000 reslice that introduces a new `titleType` or `category` value would FK-error during load |
| DDL cleanliness | ✓ benefit — `01_canonical_tables.sql` doesn't carry hard-coded `INSERT VALUES (…)` blocks |
| "Course project" minimal scope | ✓ benefit — schema reflects exactly the slice, defensible in the report |

### Note for the report

> "Lookup tables (`title_type`, `genre`, `role`, `language`, `region`, `profession`) are populated dynamically during ETL from the loaded slice's distinct values, rather than pre-loaded with IMDb's canonical taxonomy. This keeps the schema honest about what we have data for; a future re-slice with different parameters would simply re-populate the lookups from the new data."

Owner: MIG-15.

---

### ERD-Q11 — AKA `types` malformed concatenations

**The question.** ~400 rows in `title.akas.types` have values like `imdbDisplaydvd`, `alternativetv`. Real data, not delimiter accidents. How does the schema handle them?

**Options.**
- (a) Treat `types` as VARCHAR with no enforcement. Matches IMDb's own behaviour.
- (b) Add a CHECK constraint on the canonical 8 values; reject malformed rows on LOAD. Loses ~400 rows.
- (c) Normalize during ETL — split malformed concatenations heuristically into the constituent types.

**Schema impact.** (b) requires CHECK on load; (c) requires ETL logic.

**Ontology impact.** Affects whether `:AkaType` enum closes over a fixed set or accepts any string.

**Mapping impact.** Affects whether mapping emits a `Type` instance for the malformed rows.

**Decision (2026-05-04).** **Option (a) — VARCHAR with no enforcement. Subsumed by Q07.**

The Q07 decision already keeps `types` as a plain `VARCHAR` column on `title_aka`. No CHECK constraint, no normalisation in ETL. Malformed concatenations (`imdbDisplaydvd`, `alternativetv`, etc., ~430 rows in full IMDb, fewer in our slice) are accepted as-is — matching IMDb's own behaviour and avoiding fragile heuristic splitting.

No separate work for Q11 beyond what Q07 already specified.

---

### ERD-Q12 — `job` free text

**The question.** `title.principals.job` has 47,126 distinct values across IMDb. Cannot be enumerated. Confirm it's treated as free text.

**Options.**
- (a) `job` as `xsd:string` datatype property on Participation. NULL when absent.
- (b) Try to normalize the top 50 values into a `Job` lookup, leave others as free text. Hybrid model.
- (c) Drop `job` entirely — only keep `category`.

**Schema impact.** (a) adds one VARCHAR column.

**Ontology impact.** (a) one new datatype property; (b) class hierarchy.

**Mapping impact.** Trivial.

**Decision (2026-05-04).** **Option (a) — `job` as `xsd:string` datatype property on `Participation`.** NULL when absent.

### Why option (a)

| Argument | Detail |
|---|---|
| 47,126 distinct values | Far too many to enumerate as a closed enum or as OWL classes. Trying would create a tax that nothing in our SPARQL set benefits from. |
| 80.9 % NULL across IMDb | Only ~19 % of credits even have a `job` value to record. The bulk of value sits in the top 30 strings (`producer`, `writer`, `director`, `written by`, `creator`, `screenplay`, `head writer`, etc.). |
| Course-project scope | Hybrid options like "normalize the top 50 into a lookup" add complexity without proportional value. KISS. |

### Layer-by-layer realisation

| Layer | Change |
|-------|--------|
| Conceptual ERD | `Participation` gets a `job` attribute (single-valued, nullable). |
| Relational schema | Column `JOB VARCHAR(500) NULL` on `participation` — mirrors IMDb's source. |
| Staging | `title_principals_staging.job` carries the raw text. |
| ETL | `INSERT INTO participation (… JOB …) SELECT … job FROM title_principals_staging`. |
| Ontology | Datatype property `:job xsd:string` on `:Participation`. No new class. |
| Mapping | One TermMap on the Participation triple-map family. R2RML's null-skip (Q09) handles the 81 % NULL automatically. |

### Note for the report

> "The IMDb `job` column carries free-text refinements of `category` (47 K distinct values across all of IMDb, including `written by`, `screenplay`, `creator`, `head writer`, `director of photography`, `novel`, etc.). We model it as a single optional `xsd:string` datatype property on Participation, since enumerating it would be intractable and most of the 47 K values are long-tail noise irrelevant to our queries."

Owner: MIG-15 / MIG-16.

---

### ERD-Q13 — Episode / Series coverage

**The question.** The slice has 285 series titles but only 21 episodes (across 6 series). Most series have no per-episode data in our KG. What posture do we take?

**Evidence.** `docs/plan.md` §4a observation 1; `docs/raw_imdb_analysis.md` §6 — full IMDb has 9.6 M episodes attached to 235,869 distinct parents.

**Options.**
- (a) **Accept thin Episode coverage.** Most series have empty `hasEpisode`. Honest in the report.
- (b) **Augment slice with episodes from popular series.** When a series is in the slice, add (say) its top-50 episodes regardless of `numVotes`. Adds ~10 K episodes.
- (c) **Drop Episode/Series from the migrated KG.** Movies-only ontology / mapping subset.
- (d) **Stratified slice.** Top-N movies + top-M series + their full episode lists. More complex ETL.

**Schema impact.** (b) and (d) change the filter logic. (c) drops two tables.

**Ontology impact.** (c) removes `:Episode`, `:Series`, `:partOfSeries`, `:hasEpisode`.

**Mapping impact.** (c) drops several triple maps.

**Decision (2026-05-04).** **Option (a) — accept thin Episode coverage.**

The schema and ontology fully support the Episode/Series structure (per F-02): both subtypes exist, the `hasEpisode` relationship is modelled, `season_number` and `episode_number` are attributes of `Episode`. The slice happens to contain 21 episodes attached to 6 series — that's what gets loaded. No augmentation, no stratified slice, no schema simplification.

### What this means in practice

| Aspect | Outcome |
|---|---|
| Series in the migrated KG | 285 (matches Phase 1) — all `tvSeries` and `tvMiniSeries` titles in the slice |
| Episodes in the migrated KG | 21 — only those individually highly-voted enough to make the top-2,500 |
| Series with non-empty `hasEpisode` | 6 (Game of Thrones, Breaking Bad, Better Call Saul, Stranger Things, The Last of Us, one other) |
| Series with empty `hasEpisode` | 279 — known to the KG but no per-episode data attached |
| SPARQL queries on Series/Episode | Work, but most series have empty `hasEpisode` results |

### Layer-by-layer realisation

No schema or ontology change relative to F-02. The `title_episode` table is loaded with whatever `title_episode_staging` rows survive the slice's tconst filter (≈ 21 rows in our case).

### Why option (a) over (b), (c), (d)

- **(b) Augment slice with episodes** would change the filter logic (re-add per-episode rows from popular series), diluting the "top-2,500 by numVotes" criterion that we already explained to the professor in our email.
- **(c) Drop Episode/Series** is rejected per F-02 — the structure is part of our agreed model, not negotiable.
- **(d) Stratified slice** complicates the ETL and the report narrative for marginal benefit.

### Note for the report (§2 Database or §10 Demonstrator)

> "The migrated slice contains 285 series and 21 episodes (21 individual episodes that were highly-voted enough to make the top-2,500 by `numVotes`). The Episode-to-Series relationship is fully modelled in the ontology, but most series have an empty `hasEpisode` set in the KG — IMDb's per-episode data is sparse for less-followed series, and the slice criterion (`numVotes DESC`) is per-title rather than stratified. We acknowledge this limitation honestly rather than augmenting the slice to inflate Episode coverage."

Owner: MIG-15 / MIG-16.

---

### ERD-Q14 — Slice criterion (revisit?)

**The question.** D-02 already chose `numVotes DESC` top-2,500. Phase-1 confirmed connectivity (35 % bridge persons). Anything still to revisit given full-IMDb findings?

**Evidence.** Slice is in the top **0.15 %** of IMDb titles by popularity. Median IMDb title has 27 votes; our slice's minimum is 123,883.

**Options.**
- (a) **No change.** Already validated by Phase-1 connectivity diagnostic.
- (b) Add a *secondary* filter (e.g., re-add some top series episodes) per Q13.
- (c) Increase N — Phase 1 was strong PASS at N=2,500; could go to 5,000 if we want more variety.

**Decision (2026-05-04).** **Option (a) — no change now. Reslice with N=5,000 *if* the migrated KG turns out to be too sparse for the demonstrator after MIG-14.**

### What this means

- Stay at N=2,500, ranked by `numVotes DESC`. The choice is locked in D-02 and validated by Phase 1's connectivity diagnostic (35 % bridge persons, well above the 100-person threshold).
- Defer any reslicing decision until **after** MIG-14 (Bacon-number verification on the new KG). If the demonstrator works at N=2,500, we ship at that size.
- If MIG-14 reveals issues (e.g., Bacon-number 2-hop result is still degenerate, or some SPARQL query is too sparse), the recovery path is mechanical:

```bash
docker compose down -v
bash database/etl/filter_top_n.sh 5000
docker compose up -d
bash database/etl/load.sh
java -jar tools/r2rml/r2rml.jar mapping/mapping.properties
# re-run MIG-12 (SPARQL queries), MIG-13 (SHACL), MIG-14 (Bacon)
```

D-02 already supports the parameter; nothing in our schema, ontology, mapping, or ETL is hard-coded to 2,500. So the cost of "we changed our mind later" is a single rebuild — not a redesign.

### Layer-by-layer realisation

No layer change. This is a deferred-decision marker, not a structural change. The `.n_${N}` sentinel mechanism in `filter_top_n.sh` already handles re-runs cleanly.

### Note for the report

The slice-criterion narrative (§2 Database) already explains `numVotes DESC` and N=2,500 (per D-02 / §4b). No additional report wording needed unless we actually do reslice — in which case the §2 numbers change but the narrative is the same.

Owner: post-MIG-14 review (no upfront work).

---

### ERD-Q15 — `title.akas.types` as entity set (revisit Q07/Q11)

**The question.** Q07 and Q11 both decided to keep `types` as a plain `VARCHAR(64)` column on `title_aka`, accepting IMDb's `\002`-concatenated multi-values as-is (e.g., `imdbDisplaydvd`). After the M4 SHACL run surfaced the value of attaching descriptions to bounded vocabularies, and after the report-review noticed the asymmetry (`Title_Type`, `Role`, `Profession`, `Language`, `Region` are all entity sets but `aka_type` is a flat string), we revisited the decision.

**Evidence (from the populated DB at N=5,000).** `title.akas.types` has exactly the 8 IMDb-documented values: `imdbDisplay`, `original`, `alternative`, `tv`, `dvd`, `video`, `festival`, `working`. The "concatenated" rows we saw in Q11 are not malformed — they are *legitimately multi-valued*: IMDb's TSV separates multiple type assignments to one AKA row using byte `\x02` (Start-of-Text). MySQL's `LOAD DATA INFILE` with `ESCAPED BY ''` preserves the byte; the human-readable concatenation is a display artefact of the `mysql` client, not a data corruption. So `types` is a clean bounded multi-valued attribute, not the messy free-text we previously assumed.

**Options.**
- (a) **Pure multi-valued attribute** (Genre-style) — `Title_AKA_Type(tconst, ordering, type_value)` with `type_value` as a plain string PK component. No lookup table.
- (b) **Lookup entity + M:N junction** — `AKA_Type(aka_type_id, aka_type_name, aka_type_description)` (8-row seed) plus `Title_AKA_Type(tconst, ordering, aka_type_id)` junction. Description column carries human-readable text.
- (c) **Status quo** — keep as flat `VARCHAR(64)` on `title_aka` (Q07 / Q11 decision).

**Discriminator.** Same test as the rest of the schema: are the codes self-describing, and would a description column add value? The codes are not self-describing (`imdbDisplay`, `dvd`, `working` need explanation), and the 8-value vocabulary is closed and stable. Description column is genuinely useful.

**Decision (2026-05-05).** **Option (b) — lookup entity + M:N junction.**

This brings the schema to **16 relations** (was 14): `AKA_Type` becomes the 6th lookup entity (alongside `Title_Type`, `Role`, `Profession`, `Language`, `Region`), and `Title_AKA_Type` becomes the 5th multi-valued/junction reduction. The schema becomes uniform — all bounded label sets are entity sets — and a future ontology mapping (currently AKAs are not surfaced in RDF) can map `AKA_Type` instances cleanly with `rdfs:label` and `rdfs:comment` from the `aka_type_name` and `aka_type_description` columns.

Q07 / Q11 are **superseded** by Q15. The phrase "types live directly on title_aka as a plain VARCHAR" in the §3.1 weak-entity description is removed; in its place, §4.10 documents the `isOfType` M:N relationship.

### Layer-by-layer realisation

- **SQL schema (`01_canonical_tables.sql`).** Add `aka_type` lookup; add `title_aka_type` junction; remove `TYPES` column from `title_aka`.
- **ETL (`02_etl.sql`).** Seed `aka_type` with 8 hard-coded rows (codes + names + descriptions). Replace the line `INSERT INTO title_aka (..., types, ...) SELECT ..., types, ...` with `INSERT INTO title_aka (...) SELECT ...` (no types). Add `INSERT INTO title_aka_type ... JSON_TABLE(types, '$[*]') JOIN aka_type ...` splitting on `CHAR(2 USING utf8mb4)` (the IMDb separator byte).
- **FKs (`03_indexes.sql`).** `title_aka_type.(tconst, ordering)` → `title_aka`; `title_aka_type.aka_type_id` → `aka_type`. Index on `aka_type_id`.
- **R2RML mapping.** No change required — the existing mapping does not reference `title_aka.types`. AKAs are not surfaced as RDF entities; only `language_id` and `region_id` from `title_aka` are read for `ce:language` / `ce:region` enrichment.
- **Ontology.** No change required (no `ce:TitleAKA` class currently). Future work: map `aka_type` to a `ce:AKAType` class, expose `Title_AKA` as `ce:TitleAKA` instances, and emit `ce:isOfType` triples.
- **ERD diagram.** Add `AKA_Type` lookup and `Title_AKA_Type` junction. Cardinalities: `TitleAKA --(0,N)-- isOfType --(0,N)-- AKA_Type`.
- **Report.** Update §3 (relation counts: 6 lookups, 5 junctions, 16 total), §4 (mention 8-row seed and `\x02` split), Appendix B (relation listing, attribute domains).

### Verification (after applying)

At N=5,000 the migrated schema produces:
- `aka_type`: 8 rows (the seed).
- `title_aka_type`: 232,494 rows over 232,477 distinct AKAs (gap = 17 = number of multi-typed AKAs in the slice — matches the count of "concatenated" rows reported in Q11).
- Type breakdown: `imdbDisplay` 215,847; `alternative` 6,519; `original` 5,000 (= titles in slice, every title has one canonical "original" AKA); `working` 2,459; `tv` 986; `dvd` 969; `video` 428; `festival` 286.

Owner: implementer (this commit).

---

### ERD-Q16 — Rename SQL/ERD entity to `Principal` (keep `Participation` at ontology layer)

**The question.** The reified n-ary relationship between `Person`, `Title`, and `Role` was originally named `Participation` everywhere — ERD entity, SQL table, OWL class. During the M4 review the team noted that this name is the team's abstraction; IMDb's source vocabulary calls it `principal` (the file is `title.principals.tsv`, each row is a "principal credit"). Should the SQL/ERD layer mirror the source vocabulary while the ontology layer keeps the abstraction?

**Options.**
- (a) **Rename everything to `Principal`** — uniform naming, source-faithful, but loses the abstraction signal at the ontology layer (the OWL class no longer reads as a reified relationship).
- (b) **Keep everything as `Participation`** — abstraction-faithful at every layer, but creates friction when cross-referencing IMDb's docs.
- (c) **Two-layer naming**: `Principal` at ERD/relational/SQL layer (matching IMDb); `Participation` at ontology/RDF layer (matching the reified-relationship convention). The R2RML mapping bridges the two via comments and the table-name reference.

**Discussion.** Option (c) follows the same general rule we already used implicitly elsewhere in the schema: when the source field is a literal label (e.g., `tconst`, `nconst`, `title_aka`, `title_episode`) we keep IMDb's term; when it's a richer concept (`category` → `Role`, `principal` credit → `Participation` reified relationship) we rename at the ontology layer to a more abstract noun. By making `Principal` the SQL/ERD-layer name and `ce:Participation` the ontology-layer name, we apply that rule consistently — both layers get a name appropriate to their purpose.

The R2RML mapping already supports two-layer naming naturally: `rr:logicalTable [ rr:tableName "principal" ]` reads from the SQL table, while `rr:class ce:Participation` and the IRI template `.../data/participation/{TCONST}/{ORDERING}` set up the ontology-layer instances. The bridge is a one-line documentation note, not a structural change.

**Decision (2026-05-05).** **Option (c) — two-layer naming.**

`Principal` (SQL/ERD/relational) + `ce:Participation` (ontology/RDF/SPARQL/SHACL). The split is documented at the top of `docs/erd_specification.md` under "Naming-layer note", and inline in the R2RML mapping comments for §10.

This decision **supersedes** the implicit naming choice from Q01 (which used `Participation` at every layer). Q01's substantive content -- that the n-ary relationship is reified into a weak entity with PK `(tconst, ordering)` -- is unchanged; only the entity name at the SQL/ERD layer differs.

### Layer-by-layer realisation

- **SQL schema (`01_canonical_tables.sql`).** Rename `participation` → `principal`; rename `participation_character` → `principal_character`.
- **ETL (`02_etl.sql`).** Update `INSERT INTO participation` → `INSERT INTO principal`; `INSERT INTO participation_character` → `INSERT INTO principal_character`.
- **FKs and indexes (`03_indexes.sql`).** Rename FK constraint names (`fk_participation_*` → `fk_principal_*`) and index names (`idx_participation_*` → `idx_principal_*`).
- **R2RML mapping.** Update `rr:tableName "participation"` → `rr:tableName "principal"` and `rr:tableName "participation_character"` → `rr:tableName "principal_character"`. Update `FROM participation p` → `FROM principal p` in `rr:sqlQuery` blocks. Keep `rr:class ce:Participation`, `ce:participatesIn`, `ce:participationRole`, IRI templates, and all ontology-layer references.
- **Ontology / SHACL / SPARQL.** No change. `ce:Participation`, `ParticipationShape`, `?par a ce:Participation` etc. all remain as-is.
- **ERD spec, ERD investigation log, runbook, report §3 / §4 / §7-mapping-SQL-side / Appendix B.** Update entity name to `Principal`; update relationship names `hasParticipation`/`participatedBy` → `hasPrincipal`/`creditedAs`; update all SQL-table references.
- **Live database.** `ALTER TABLE … RENAME TO …` and FK rename; KG re-generated by R2RML, no change to triple count or RDF content.

### Note for the report

The report's §3 (Information System) and §4 (SQL Implementation) describe the SQL/ERD layer and use `Principal`. §5 (Ontology), §8 (SPARQL), §9 (Demonstrator) describe the ontology/RDF layer and use `Participation`. §7 (Mapping) explicitly bridges the two and so contains both names with the bridge documented in prose.

Owner: implementer (this commit).

---

## 3. Working ERD draft

_(to be filled in once Q01–Q13 are decided)_

This section will hold either:
- A note "no change to current ERD — view layer bridges all gaps" (if decisions trend conservative), or
- A new ERD diagram with renamed/added/removed entities (if decisions trend toward redesign).

Either way, it will reference `docs/figs/ERD.png` (regenerated at MIG-02c).

---

## 4. Schema/ontology/mapping change checklist

_(pre-flight checklist before MIG-03 begins)_

For each layer, list the concrete changes implied by the decisions in §1.

| Layer | File(s) | Changes (filled in after §2 decisions) |
|-------|---------|-----------------------------------------|
| SQL schema | `database/schema/01_tables.sql` | _(pending)_ |
| SQL views | `database/schema/02_views.sql` | _(pending)_ |
| Ontology | `ontology/cineexplorer_ontology.ttl` | _(pending)_ |
| Mapping | `mapping/cineexplorer_mapping.ttl` | _(pending)_ |
| Lookup data | embedded in `01_tables.sql` | _(pending)_ |
| ERD diagram | `docs/ERD.drawio` + `docs/figs/ERD.png` | _(pending)_ |

This checklist is the deliverable that gates the transition from Phase 2 to Phase 3.
