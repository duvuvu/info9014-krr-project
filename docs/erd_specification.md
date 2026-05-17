# ERD Specification — Migrated CineExplorer Schema

> **Status:** drafted 2026-05-04, revised 2026-05-05 to add `AKA_Type` entity. Derived from `docs/erd_investigation.md` (all 14 numbered decisions + 2 foundational assertions resolved + Q15 added for AKA_Type).
> **Purpose:** Single canonical reference for the migrated database. Source for the report's §2 (Database) and §3 (ERD appendix). The SQL DDL in §6 is implemented in `database/imdb-schema.sql` (all-in-one schema + ETL + FKs/indexes).
> **Naming conventions** per `docs/erd_investigation.md` §1.7: ERD entities `PascalCase`, weak entities `Word_Word`, relationships `camelCase`, attributes `snake_case`; SQL tables `lowercase`, columns `UPPER_SNAKE_CASE`.

---

## 0. Top-down picture

The migrated database has **2 strong top-level entities** (`Title`, `Person`), **6 lookup entities** (`Title_Type`, `Role`, `Profession`, `Language`, `Region`, `AKA_Type`), **2 weak entities** (`TitleAKA`, `Principal`) and **3 subtypes of `Title`** (`Film`, `Series`, `Episode`) — matching the M3 OWL ontology's `:Film` / `:Series` / `:Episode` triad. `Genre` and `Character` are multi-valued attributes (not entities) — they reduce to attribute tables that store the value name directly. `Title_AKA_Type` is an M:N junction between `TitleAKA` and the `AKA_Type` lookup (Q15).

> **Naming-layer note.** This document is the canonical reference for the *ERD / relational / SQL layer*, where the per-credit weak entity is named `Principal` (matching IMDb's source vocabulary in `title.principals.tsv`). At the *ontology / RDF layer* the same concept is named `ce:Participation` (the abstract reified relationship between Person, Title, and Role). The R2RML mapping bridges the two: it reads the SQL `principal` table and emits `ce:Participation` instances. The mapping comments make the bridge explicit.

```
                                ┌──────────────┐
                                │  Title_Type  │ (lookup, dynamic)
                                └──────┬───────┘
                                       │ (1,1) classifies (0,N)
                                       ▼
                                ┌──────────────┐
                                │    Title     │ (strong; PK = tconst)
                                └────┬─┬─┬─────┘
                                     │ │ │
                  ┌──────────────────┘ │ └────────────────────┐
                  │                    │                      │
                  ▼                    ▼                      ▼
            ┌──────────┐         ┌────────────────┐      ┌──────────┐
            │ Title_   │ M:N     │     Genre      │      │ Title_AKA│ (weak;
            │  Genre   │◀───────▶│ (lookup, dyn.) │      │ PK=(tcon,│  PK=(t,o))
            └──────────┘         └────────────────┘      │ ord))    │
                                                         └────┬─┬───┘
                              IS-A (partial,                  │ │
                              disjoint;                       ▼ ▼
                              discriminator =          ┌─────────┐
                              title_type_id FK)        │Language │
                                  △                    │ Region  │
                                  │                    │(lookups)│
                                  ├─────────┐          └─────────┘
                              ┌───┴───┐ ┌───┴─────┐
                              │Series │ │ Episode │ (subtype of Title;
                              └───┬───┘ │ PK=tcon │  extra attrs:
                                  │     └─────────┘  parent_tconst,
                                  │ (1,N)            season_number,
                                  └─── hasEpisode    episode_number)

                  ┌──────────────────┐                    ┌─────────────────┐
                  │      Person      │ (strong;           │   Profession    │ (lookup,
                  │   PK = nconst    │  PK=nconst)        │ dynamic from    │  dynamic)
                  └────────┬─┬─┬─────┘                    │ primaryProf)    │
                           │ │ │                          └────────┬────────┘
                           │ │ └────────── M:N person_profession ──┘
                           │ │
                           │ └──────────── M:N person_known_for (4-cap) ───── Title
                           │
                           ▼ (1,1) plays-role-in (0,N)
                    ┌──────────────────┐
                    │    Principal     │ (weak; PK=(tconst, ordering);
                    │                  │  links Person → Title)
                    └────┬─────────┬───┘
                         │ (1,1)   │ multi-valued
                         ▼         ▼
                    ┌────────┐  ┌────────────────────┐
                    │  Role  │  │  Principal_        │
                    │(lookup)│  │    Character       │
                    └────────┘  │  (junction;        │
                                │   PK=(t,o,name))   │
                                └────────────────────┘
```

**Note on `Title_Type`.** Modelled as a lookup entity for consistency with the other 5 bounded label sets (`Genre`, `Role`, `Profession`, `Language`, `Region`). `Title.title_type_id` is a FK to `title_type.title_type_id`. The IMDb code (`movie`, `tvSeries`, `tvEpisode`, etc.) serves as the natural primary key. For `Series` / `Episode` IS-A subtype membership, the discriminator condition is `title_type_id IN ('tvSeries', 'tvMiniSeries', 'tvPilot')` and `title_type_id = 'tvEpisode'` respectively.

**Note on `Film`.** `Film`, `Series`, and `Episode` are all IS-A subtypes of `Title`, matching the existing M3 ontology where `:Film`, `:Series`, `:Episode` are the three disjoint subclasses of `:CreativeWork`. `Film` and `Series` have no extra attributes (the IS-A is captured by the `title_type_id` discriminator alone); only `Episode` has its own table due to extra attributes (`parent_tconst`, `season_number`, `episode_number`). Other titleTypes that don't fit `{Film, Series, Episode}` (e.g., `tvMovie`, `short`, `video`, `tvSpecial`, `videoGame`, `tvShort`) remain plain `Title` rows with their `title_type_id` value preserved but no IS-A typing.

---

## 1. Strong entity sets

### 1.1 `Title` — every audiovisual work

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `tconst` | `varchar(20)` | NOT NULL | **PK**. IMDb tconst, e.g. `tt0111161`. Pattern `tt\d+`. |
| `primary_title` | `varchar(500)` | NOT NULL | Display title (IMDb's UI). |
| `original_title` | `varchar(500)` | NULL | Title in original language at production. |
| `is_adult` | `tinyint(1)` | NOT NULL DEFAULT 0 | Adult flag. (Q03) |
| `start_year` | `int` | NULL | Release / first-aired year. |
| `end_year` | `int` | NULL | Series end year (NULL for non-series). |
| `runtime_minutes` | `int` | NULL | Running time. |
| `average_rating` | `decimal(3,1)` | NULL | Composite-attribute member. (Q06) |
| `num_votes` | `int` | NULL | Composite-attribute member. (Q06) |
| `title_type_id` | `varchar(20)` | NOT NULL | **FK** → `title_type.title_type_id`. Carries IMDb's `titleType` value (`movie`, `tvSeries`, `tvEpisode`, `short`, `video`, `tvMovie`, `tvSpecial`, `videoGame`, `tvShort`, `tvMiniSeries`, `tvPilot`). Serves as the IS-A discriminator (§2). |

Composite attribute `rating = {average_rating, num_votes}` (Q06) renders as two flat columns; no separate `Rating` relation.

### 1.2 `Person` — every person credited

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `nconst` | `varchar(20)` | NOT NULL | **PK**. IMDb nconst, e.g. `nm0000158`. Pattern `nm\d+`. |
| `primary_name` | `varchar(500)` | NOT NULL | Display name. |
| `birth_year` | `int` | NULL | (~96 % NULL at full-IMDb scale; ~36 % NULL in slice.) |
| `death_year` | `int` | NULL | (~98 % NULL; most are alive.) |

The 5 OWL Person subclasses (`:Actor, :Director, :Writer, :Editor, :Composer`) are derived from `primaryProfession` at mapping time; they're not separate SQL relations. (Q01, Q02)

### 1.3 Lookup entities

Five thin strong entities for value-set integrity. Populated dynamically from slice data (Q10).

| Entity | PK | Attribute | Type | Source |
|--------|------|-----------|------|--------|
| `Title_Type` | `title_type_id` | `title_type_name` | `varchar(100)` NULL | distinct values of `title.basics.titleType` |
| `Role` | `role_id` (auto) | `role_name` | `varchar(64)` UNIQUE NOT NULL | distinct values of `title.principals.category` (with `actor`+`actress` collapsed to `actor`, Q02) |
| `Profession` | `profession_id` (auto) | `profession_name` | `varchar(64)` UNIQUE NOT NULL | distinct values exploded from `name.basics.primaryProfession` |
| `Language` | `language_id` | `language_name` | `varchar(100)` NULL | distinct values of `title.akas.language` |
| `Region` | `region_id` | `region_name` | `varchar(100)` NULL | distinct values of `title.akas.region` |
| `AKA_Type` | `aka_type_id` | `aka_type_name`, `aka_type_description` | `varchar(100)` NOT NULL, `varchar(500)` NULL | seeded with the 8 IMDb-documented `title.akas.types` codes (`imdbDisplay`, `original`, `alternative`, `tv`, `dvd`, `video`, `festival`, `working`); see Q15. |

For the lookups whose key is an IMDb code (`title_type`, `language`, `region`, `aka_type`), `*_id` is `varchar` matching the code; for the synthetic-key lookups (`role`, `profession`), `*_id` is `int auto_increment`. Names (`*_name`) are populated where derivable; for `language` and `region`, an optional `UPDATE` block in the ETL fills ISO 639 / ISO 3166 names. `aka_type` is the only lookup that is **seeded** rather than derived — its 8-value vocabulary is documented and stable, so seeding lets us attach a description to each code.

**`Genre` is not a lookup entity.** Genre is a multi-valued attribute on `Title`, reducing to `title_genre(TCONST, GENRE_NAME)` — the genre name string is stored directly without a surrogate ID. See §4.1.

---

## 2. IS-A specialisation (subtypes of `Title`)

Per **F-02**, `Title` has a partial, disjoint specialisation into **three subtypes**: `Film`, `Series`, `Episode` — matching the M3 OWL ontology's `:Film` / `:Series` / `:Episode` triad. The discriminator is the `title_type_id` FK on `Title`.

```
                    Title  (PK = tconst, FK title_type_id)
                      △
                    is-a (0,1)  ← partial / disjoint
                  /     |     \
              Film    Series  Episode
              (—)     (—)    (extra attrs:
                              parent_tconst,
                              season_number,
                              episode_number)
```

| Subtype | Discriminator (`title.title_type_id`) | Extra attributes | Stored as |
|---------|---------------------------------------|-------------------|-----------|
| `Film` | `'movie'` | none | `title` table only — no separate `film` table |
| `Series` | `'tvSeries'`, `'tvMiniSeries'`, `'tvPilot'` (subset present in slice) | none | `title` table only — no separate `series` table |
| `Episode` | `'tvEpisode'` | `parent_tconst` (FK to title), `season_number`, `episode_number` | separate `title_episode` table joined 1:1 to `title` on `tconst` |

**Other titleTypes** (`short`, `video`, `tvMovie`, `tvSpecial`, `videoGame`, `tvShort`) are **not subtypes** in the IS-A — they're plain `Title` rows whose `title_type_id` FK references the corresponding `title_type` lookup row but receive no specialised OWL typing. (None of these appear in our N=2,500 slice anyway, but the slot is left open for future re-slices that could include them.)

**Why `Film` and `Series` don't get separate tables.** Neither has extra attributes beyond what's already on `Title`. The IS-A relationship is captured by the `title_type_id` discriminator alone for both. Adding empty subtype tables would be pure overhead.

**Why `Episode` does get a separate table.** `parent_tconst`, `season_number`, `episode_number` only exist for episodes — putting them on `Title` directly would mean ~99.8 % of `title` rows have NULL on those columns. Cleaner to factor them into `title_episode` joined 1:1 with `title` on the episode's tconst.

**Film discriminator scope.** `Film` covers exactly `title_type_id = 'movie'`. The other "non-series, non-episode" titleTypes (`short`, `video`, `tvMovie`, `tvSpecial`, `videoGame`, `tvShort`) are deliberately excluded from the `Film` subtype — they're documentary shorts, direct-to-video releases, made-for-TV movies, etc., which are different enough from theatrical features that lumping them as "Film" would lose information. Each remains a plain `Title` row with its `title_type_id` value preserved.

---

## 3. Weak entity sets

### 3.1 `TitleAKA` — alternate / localised titles (Q07)

Weak entity dependent on `Title`. PK is composite.

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `tconst` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `title.tconst`. |
| `ordering` | `int` | NOT NULL | Part of **PK**. Sequence within a title's akas. |
| `title` | `varchar(500)` | NOT NULL | The alternate / localised title text. |
| `region_id` | `varchar(10)` | NULL | **FK** → `region.region_id`. |
| `language_id` | `varchar(10)` | NULL | **FK** → `language.language_id`. |
| `is_original_title` | `tinyint(1)` | NOT NULL DEFAULT 0 | Flags the canonical original. |
| `attributes` | `varchar(500)` | NULL | Free-text qualifiers. ~95 % NULL across full IMDb. |

**PK** = `(tconst, ordering)`.

The IMDb `title.akas.types` column is **not** stored on `title_aka` directly. It is split into the `Title_AKA_Type` junction (§4.10, Q15), since it is a bounded multi-valued attribute whose 8-value vocabulary benefits from a description column attached to each code.

### 3.2 `Principal` — per-credit cast/crew involvement (Q01, Q05, Q12)

Weak entity dependent on both `Title` and `Person`. The locus of all per-credit attributes: role, job, characters. Named `Principal` to mirror IMDb's source vocabulary (`title.principals.tsv`); the corresponding ontology class is `ce:Participation` (the abstract reified-relationship name).

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `tconst` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `title.tconst`. |
| `ordering` | `int` | NOT NULL | Part of **PK**. Sequence within a title's principal credits. |
| `nconst` | `varchar(20)` | NOT NULL | **FK** → `person.nconst`. **Not** part of PK — a person can hold multiple credits on the same title (different orderings). |
| `role_id` | `int` | NOT NULL | **FK** → `role.role_id`. Resolves to the IMDb `category` value with `actor` + `actress` collapsed to `'actor'` (Q02). 12 distinct values in the slice. |
| `job` | `varchar(500)` | NULL | Free-text refinement of `role`. ~81 % NULL across full IMDb. (Q12) |

**PK** = `(tconst, ordering)`.

Multi-valued attribute `character_name` reduces to a separate junction (§4.4 below).

---

## 4. Relationships and reductions

### 4.1 `Title.genre` — multi-valued attribute

`Genre` is a multi-valued attribute on `Title` (a title can have up to 3 genres). It is **not** a separate entity set; values are stored as plain strings.

Reduces to attribute relation `title_genre`:

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `tconst` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `title.tconst`. |
| `genre_name` | `varchar(64)` | NOT NULL | Part of **PK**. The genre name string (e.g. `'Drama'`, `'Comedy'`). No FK target — there is no `genre` entity. |

**PK** = `(tconst, genre_name)`.

Pure attribute reduction — the genre name is part of the PK encoding the multi-valued attribute. Excludes `Adult` per Q03. The IMDb-side ordering of genres on a title (1st–3rd genre) is not preserved; queries don't rely on it.

### 4.2 `hasAKA` — `Title` ↔ `TitleAKA`

Already encoded by the weak-entity FK; `TitleAKA.tconst` references `title.tconst`. Cardinality `Title --(0,N)-- hasAKA --(1,1)-- TitleAKA`.

### 4.3 `hasPrincipal` / `creditedAs` — `Title` ↔ `Principal` ↔ `Person`

n-ary association promoted to weak entity (Q01). Encoded by `Principal.tconst` and `Principal.nconst` FKs. Cardinality `Title --(0,N)-- hasPrincipal --(1,1)-- Principal` and `Person --(0,N)-- creditedAs --(1,1)-- Principal`.

### 4.4 `Principal` multi-valued attribute `character_name` (Q05)

```
Principal --(0,N)-- hasCharacter --(0,1)-- (string)
```

Single-valued in 99.99999 % of rows; modelled as multi-valued for 1NF correctness. Reduces to junction `principal_character`:

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `tconst` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `principal` (composite). |
| `ordering` | `int` | NOT NULL | Part of **PK**. **FK** → `principal` (composite). |
| `character_name` | `varchar(500)` | NOT NULL | Part of **PK**. The character name (after JSON-array unwrap). |

**PK** = `(tconst, ordering, character_name)`.

Populated by `JSON_TABLE` exploding `title.principals.characters` during the ETL phase of `database/imdb-schema.sql`.

### 4.5 `hasRole` — `Principal` ↔ `Role`

```
Principal --(1,1)-- hasRole --(0,N)-- Role
```

Each Principal has exactly one Role; a Role is held by 0..N Principals. Encoded by `Principal.role_id` FK referencing `role.role_id`. 12 distinct values in the slice (after `actor`+`actress` collapse, Q02).

### 4.6 `hasProfession` — `Person` ↔ `Profession`

```
Person --(0,3)-- hasProfession --(0,N)-- Profession
```

M:N (capped at 3 per Person per IMDb). Reduces to junction `person_profession`:

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `nconst` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `person.nconst`. |
| `profession_id` | `int` | NOT NULL | Part of **PK**. **FK** → `profession.profession_id`. |

**PK** = `(nconst, profession_id)`.

Pure junction — no extra attributes. The IMDb-side ordering of professions for a person (1st–3rd profession) is not preserved; queries don't rely on it.

### 4.7 `knownFor` — `Person` ↔ `Title` (Q08)

```
Person --(0,4)-- knownFor --(0,N)-- Title
```

M:N (capped at 4 per Person per IMDb). Filtered to slice tconsts at ETL load (Q08 option c) so the FK is clean. Reduces to junction `person_known_for`:

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `nconst` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `person.nconst`. |
| `tconst` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `title.tconst`. |

**PK** = `(nconst, tconst)`.

### 4.8 `hasEpisode` / `partOfSeries` — `Series` ↔ `Episode` (F-02)

```
Series --(0,N)-- hasEpisode --(1,1)-- Episode
```

Encoded by `title_episode.parent_tconst` FK referencing `title.tconst` (the parent series). Cardinality `(1,1)` on the Episode side because `parent_tconst` is NOT NULL.

### 4.9 `akaInLanguage`, `akaInRegion` — `TitleAKA` ↔ `Language` / `Region` (Q07)

```
TitleAKA --(0,1)-- akaInLanguage --(0,N)-- Language
TitleAKA --(0,1)-- akaInRegion   --(0,N)-- Region
```

Encoded by FKs `title_aka.language_id` and `title_aka.region_id`. Both nullable (~70 % NULL on language, ~1.7 % on region).

### 4.10 `isOfType` — `TitleAKA` ↔ `AKA_Type` (Q15)

```
TitleAKA --(0,N)-- isOfType --(0,N)-- AKA_Type
```

M:N. One AKA row may carry several types: IMDb's `title.akas.types` column is byte-`\x02`-separated (e.g., `imdbDisplay\x02dvd`); each piece becomes a separate junction row. Reduces to junction `title_aka_type`:

| Attribute | Type | NULL | Notes |
|-----------|------|:----:|-------|
| `tconst` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `title_aka` (composite). |
| `ordering` | `int` | NOT NULL | Part of **PK**. **FK** → `title_aka` (composite). |
| `aka_type_id` | `varchar(20)` | NOT NULL | Part of **PK**. **FK** → `aka_type.aka_type_id`. |

**PK** = `(tconst, ordering, aka_type_id)`.

Populated by `JSON_TABLE` exploding `title.akas.types` on `CHAR(2 USING utf8mb4)` during the ETL phase of `database/imdb-schema.sql`. At N=5,000 the slice produces 232,494 junction rows over 232,477 distinct AKAs (the gap of 17 is the small set of multi-typed AKAs).

**AKA-type counts in the slice (for reference):**

| `aka_type_id` | rows |
|---|---:|
| `imdbDisplay` | 215,847 |
| `alternative` | 6,519 |
| `original` | 5,000 |
| `working` | 2,459 |
| `tv` | 986 |
| `dvd` | 969 |
| `video` | 428 |
| `festival` | 286 |

`original` is exactly 5,000 — every retained title has one canonical "original" AKA row.

---

## 5. Reduction to relational model — full listing

### Strong entities (8 relations)

```
Title(tconst, primary_title, original_title, is_adult,
      start_year, end_year, runtime_minutes,
      average_rating, num_votes,
      title_type_id)

Person(nconst, primary_name, birth_year, death_year)

Title_Type(title_type_id, title_type_name)
Role(role_id, role_name)
Profession(profession_id, profession_name)
Language(language_id, language_name)
Region(region_id, region_name)
AKA_Type(aka_type_id, aka_type_name, aka_type_description)
```

(`Title_Type`, `Role`, `Profession`, `Language`, `Region`, `AKA_Type` are the 6 lookup relations.)

### IS-A subtype with extra attributes (1 relation)

```
Title_Episode(tconst, parent_tconst, season_number, episode_number)
```

### Weak entities (2 relations)

```
Title_AKA(tconst, ordering, title, region_id, language_id,
          is_original_title, attributes)

Principal(tconst, ordering, nconst, role_id, job)
```

(`Title_AKA.types` is split out into the `Title_AKA_Type` junction below; see Q15.)

### Multi-valued attributes / junctions (5 relations)

```
Title_Genre(tconst, genre_name)                             ← multi-valued attribute
Principal_Character(tconst, ordering, character_name)        ← multi-valued attribute
Person_Profession(nconst, profession_id)                     ← M:N junction (Profession is an entity)
Person_Known_For(nconst, tconst)                             ← M:N junction (both ends are entities)
Title_AKA_Type(tconst, ordering, aka_type_id)                ← M:N junction (AKA_Type is an entity)
```

`Title_Genre` and `Principal_Character` encode multi-valued attributes — the attribute value is part of the PK. `Person_Profession`, `Person_Known_For`, and `Title_AKA_Type` are true M:N junctions whose ends are both entities (the FK target carries its own attributes).

### Total

**16 relations**: 8 strong (Title, Person, 6 lookups) + 1 IS-A subtype (Title_Episode) + 2 weak (Title_AKA, Principal) + 5 multi-valued/junction reductions (Title_Genre, Person_Profession, Person_Known_For, Principal_Character, Title_AKA_Type).

---

## 6. SQL DDL (canonical schema)

Implemented as Phase 1 of `database/imdb-schema.sql`. MySQL 8, InnoDB, `utf8mb4`. The full file additionally bundles the staging tables, `LOAD DATA INFILE`, the staging-to-canonical INSERTs, the staging drops, and the FKs/indexes; what follows is just the canonical-table portion.

```sql
-- =================================================================
-- imdb-schema.sql -- Phase 1: Canonical tables
-- (excerpt; the full all-in-one script is database/imdb-schema.sql)
-- =================================================================

SET NAMES utf8mb4;
SET sql_mode = 'STRICT_TRANS_TABLES';

-- ----- Lookup tables -----

CREATE TABLE title_type (
    TITLE_TYPE_ID    VARCHAR(20)  NOT NULL,
    TITLE_TYPE_NAME  VARCHAR(100) NULL,
    PRIMARY KEY (TITLE_TYPE_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- (No `genre` lookup entity — Genre is a multi-valued attribute on Title,
--  stored directly in title_genre.GENRE_NAME. See §1.3.)

CREATE TABLE role (
    ROLE_ID    INT          NOT NULL AUTO_INCREMENT,
    ROLE_NAME  VARCHAR(64)  NOT NULL,
    PRIMARY KEY (ROLE_ID),
    UNIQUE KEY uq_role_name (ROLE_NAME)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE profession (
    PROFESSION_ID    INT          NOT NULL AUTO_INCREMENT,
    PROFESSION_NAME  VARCHAR(64)  NOT NULL,
    PRIMARY KEY (PROFESSION_ID),
    UNIQUE KEY uq_profession_name (PROFESSION_NAME)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE language (
    LANGUAGE_ID    VARCHAR(10)  NOT NULL,
    LANGUAGE_NAME  VARCHAR(100) NULL,
    PRIMARY KEY (LANGUAGE_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE region (
    REGION_ID    VARCHAR(10)  NOT NULL,
    REGION_NAME  VARCHAR(100) NULL,
    PRIMARY KEY (REGION_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- aka_type — 6th lookup entity (Q15). Seeded with IMDb's 8 documented codes.
CREATE TABLE aka_type (
    AKA_TYPE_ID           VARCHAR(20)  NOT NULL,
    AKA_TYPE_NAME         VARCHAR(100) NOT NULL,
    AKA_TYPE_DESCRIPTION  VARCHAR(500) NULL,
    PRIMARY KEY (AKA_TYPE_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----- Top-level strong entities -----

CREATE TABLE title (
    TCONST           VARCHAR(20)   NOT NULL,
    PRIMARY_TITLE    VARCHAR(500)  NOT NULL,
    ORIGINAL_TITLE   VARCHAR(500)  NULL,
    IS_ADULT         TINYINT(1)    NOT NULL DEFAULT 0,
    START_YEAR       INT           NULL,
    END_YEAR         INT           NULL,
    RUNTIME_MINUTES  INT           NULL,
    AVERAGE_RATING   DECIMAL(3,1)  NULL,
    NUM_VOTES        INT           NULL,
    TITLE_TYPE_ID    VARCHAR(20)   NOT NULL,
    PRIMARY KEY (TCONST)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE person (
    NCONST        VARCHAR(20)   NOT NULL,
    PRIMARY_NAME  VARCHAR(500)  NOT NULL,
    BIRTH_YEAR    INT           NULL,
    DEATH_YEAR    INT           NULL,
    PRIMARY KEY (NCONST)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----- IS-A subtype with extra attributes -----

CREATE TABLE title_episode (
    TCONST          VARCHAR(20)  NOT NULL,
    PARENT_TCONST   VARCHAR(20)  NOT NULL,
    SEASON_NUMBER   INT          NULL,
    EPISODE_NUMBER  INT          NULL,
    PRIMARY KEY (TCONST)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----- Weak entities -----

CREATE TABLE title_aka (
    TCONST             VARCHAR(20)   NOT NULL,
    ORDERING           INT           NOT NULL,
    TITLE              VARCHAR(500)  NOT NULL,
    REGION_ID          VARCHAR(10)   NULL,
    LANGUAGE_ID        VARCHAR(10)   NULL,
    IS_ORIGINAL_TITLE  TINYINT(1)    NOT NULL DEFAULT 0,
    ATTRIBUTES         VARCHAR(500)  NULL,
    PRIMARY KEY (TCONST, ORDERING)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
-- TYPES split out into title_aka_type junction (Q15).

CREATE TABLE principal (
    TCONST     VARCHAR(20)   NOT NULL,
    ORDERING   INT           NOT NULL,
    NCONST     VARCHAR(20)   NOT NULL,
    ROLE_ID    INT           NOT NULL,
    JOB        VARCHAR(500)  NULL,
    PRIMARY KEY (TCONST, ORDERING)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ----- Junctions / multi-valued reductions -----

CREATE TABLE title_genre (
    TCONST      VARCHAR(20)  NOT NULL,
    GENRE_NAME  VARCHAR(64)  NOT NULL,
    PRIMARY KEY (TCONST, GENRE_NAME)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE person_profession (
    NCONST         VARCHAR(20)  NOT NULL,
    PROFESSION_ID  INT          NOT NULL,
    PRIMARY KEY (NCONST, PROFESSION_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE person_known_for (
    NCONST  VARCHAR(20)  NOT NULL,
    TCONST  VARCHAR(20)  NOT NULL,
    PRIMARY KEY (NCONST, TCONST)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE principal_character (
    TCONST          VARCHAR(20)   NOT NULL,
    ORDERING        INT           NOT NULL,
    CHARACTER_NAME  VARCHAR(500)  NOT NULL,
    PRIMARY KEY (TCONST, ORDERING, CHARACTER_NAME)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- title_aka_type — M:N junction Title_AKA × AKA_Type (Q15).
CREATE TABLE title_aka_type (
    TCONST       VARCHAR(20)  NOT NULL,
    ORDERING     INT          NOT NULL,
    AKA_TYPE_ID  VARCHAR(20)  NOT NULL,
    PRIMARY KEY (TCONST, ORDERING, AKA_TYPE_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 7. Foreign keys and indexes (deferred)

Per **D-03** (staging-tables architecture), FKs and indexes are added **after** the canonical tables are populated, in Phase 6 of `database/imdb-schema.sql`. This avoids the cost of FK validation during `INSERT INTO canonical SELECT … FROM staging` and lets the LOAD complete faster.

The deferred FK and index set:

```sql
-- =================================================================
-- imdb-schema.sql -- Phase 6: Foreign keys and indexes
-- =================================================================

-- ----- title -----
ALTER TABLE title
  ADD CONSTRAINT fk_title_type
    FOREIGN KEY (TITLE_TYPE_ID) REFERENCES title_type(TITLE_TYPE_ID);

CREATE INDEX idx_title_type ON title(TITLE_TYPE_ID);

-- ----- title_episode (subtype + parent reference) -----
ALTER TABLE title_episode
  ADD CONSTRAINT fk_title_episode_self
    FOREIGN KEY (TCONST) REFERENCES title(TCONST),
  ADD CONSTRAINT fk_title_episode_parent
    FOREIGN KEY (PARENT_TCONST) REFERENCES title(TCONST);
CREATE INDEX idx_title_episode_parent ON title_episode(PARENT_TCONST);

-- ----- title_aka -----
ALTER TABLE title_aka
  ADD CONSTRAINT fk_title_aka_title
    FOREIGN KEY (TCONST) REFERENCES title(TCONST),
  ADD CONSTRAINT fk_title_aka_region
    FOREIGN KEY (REGION_ID) REFERENCES region(REGION_ID),
  ADD CONSTRAINT fk_title_aka_language
    FOREIGN KEY (LANGUAGE_ID) REFERENCES language(LANGUAGE_ID);
CREATE INDEX idx_title_aka_region ON title_aka(REGION_ID);
CREATE INDEX idx_title_aka_language ON title_aka(LANGUAGE_ID);

-- ----- principal -----
ALTER TABLE principal
  ADD CONSTRAINT fk_principal_title
    FOREIGN KEY (TCONST) REFERENCES title(TCONST),
  ADD CONSTRAINT fk_principal_person
    FOREIGN KEY (NCONST) REFERENCES person(NCONST),
  ADD CONSTRAINT fk_principal_role
    FOREIGN KEY (ROLE_ID) REFERENCES role(ROLE_ID);
CREATE INDEX idx_principal_nconst ON principal(NCONST);
CREATE INDEX idx_principal_role ON principal(ROLE_ID);

-- ----- title_genre (multi-valued attribute, not a junction to a Genre entity) -----
ALTER TABLE title_genre
  ADD CONSTRAINT fk_title_genre_title
    FOREIGN KEY (TCONST) REFERENCES title(TCONST);
-- (No FK on GENRE_NAME — Genre is a multi-valued attribute, not an entity set.)
CREATE INDEX idx_title_genre_name ON title_genre(GENRE_NAME);

-- ----- person_profession -----
ALTER TABLE person_profession
  ADD CONSTRAINT fk_pp_person
    FOREIGN KEY (NCONST) REFERENCES person(NCONST),
  ADD CONSTRAINT fk_pp_profession
    FOREIGN KEY (PROFESSION_ID) REFERENCES profession(PROFESSION_ID);
CREATE INDEX idx_pp_profession ON person_profession(PROFESSION_ID);

-- ----- person_known_for -----
ALTER TABLE person_known_for
  ADD CONSTRAINT fk_pkf_person
    FOREIGN KEY (NCONST) REFERENCES person(NCONST),
  ADD CONSTRAINT fk_pkf_title
    FOREIGN KEY (TCONST) REFERENCES title(TCONST);
CREATE INDEX idx_pkf_title ON person_known_for(TCONST);

-- ----- principal_character -----
ALTER TABLE principal_character
  ADD CONSTRAINT fk_pc_principal
    FOREIGN KEY (TCONST, ORDERING) REFERENCES principal(TCONST, ORDERING);

-- ----- title_aka_type (Q15) -----
ALTER TABLE title_aka_type
  ADD CONSTRAINT fk_tat_aka
    FOREIGN KEY (TCONST, ORDERING) REFERENCES title_aka(TCONST, ORDERING),
  ADD CONSTRAINT fk_tat_type
    FOREIGN KEY (AKA_TYPE_ID) REFERENCES aka_type(AKA_TYPE_ID);
CREATE INDEX idx_tat_type ON title_aka_type(AKA_TYPE_ID);
```

---

## 8. ETL flow (sketch)

The canonical tables are populated from staging tables in Phases 2–5 of `database/imdb-schema.sql`. The high-level pattern (per D-03):

1. CREATE TABLE for each staging table (mirroring IMDb TSV shape).
2. `LOAD DATA INFILE 'filtered/<file>.tsv' INTO TABLE <staging_table>` for each filtered TSV.
3. `INSERT INTO title_type/role/profession/language/region SELECT DISTINCT … FROM staging` to populate the 5 lookup entities (Q10 — dynamic, no hard-coded values). No `genre` lookup — Genre is modelled as a multi-valued attribute, with the genre name stored directly in `title_genre.GENRE_NAME`.
4. `INSERT INTO title SELECT b.tconst, b.primaryTitle, …, r.averageRating, r.numVotes, b.titleType FROM title_basics_staging b LEFT JOIN title_ratings_staging r ON r.tconst = b.tconst` to populate `title` (composite rating attribute, Q06; `title_type_id` resolved as the same string from the lookup).
5. `INSERT INTO person … FROM name_basics_staging`.
6. `INSERT INTO title_episode … FROM title_episode_staging`.
7. `INSERT INTO title_aka … FROM title_akas_staging` (7 columns; `types` is split out into `title_aka_type` in step 13.5, Q15).
8. `INSERT INTO principal … FROM title_principals_staging` with role_id resolved via JOIN to `role` (collapsing actor/actress to actor at this step, Q02).
9. `INSERT INTO principal_character … JSON_TABLE(characters, …)` to explode the JSON arrays (Q05).
10. `INSERT INTO title_genre … JSON_TABLE(genres, …)` to explode CSV genres (excluding `Adult`, Q03).
11. `INSERT INTO person_profession … JSON_TABLE(primaryProfession, …)` to explode CSV professions.
12. `INSERT INTO person_known_for … JSON_TABLE(knownForTitles, …) JOIN title` to explode + filter (Q08).
13. `INSERT INTO aka_type VALUES …` to seed the 8-row lookup with descriptions (Q15).
13.5. `INSERT INTO title_aka_type … JSON_TABLE(types, …)` splitting on byte `\x02` and filtering by `JOIN aka_type` (Q15).
14. `DROP TABLE` for each staging table.

Then Phase 6 of `database/imdb-schema.sql` runs to add FKs and indexes. (`title_crew` is loaded by Phase 1 of the runbook into the filtered TSV directory but is **not** loaded into a staging table — it has been dropped from the SQL pipeline since director/writer credits flow through `principal` instead, per Q04 revised.)

---

## 9. Cardinality summary table (for §3 of the report)

| Relationship | From | To | Cardinality | Notes |
|--------------|------|------|------------:|-------|
| `Title.genre` (multi-valued attribute) | Title | (string) | (0,3) ↔ — | reduces to `title_genre(TCONST, GENRE_NAME)`; max 3 genres per title |
| `hasAKA` | Title | TitleAKA | (0,N) ↔ (1,1) | weak FK |
| `hasPrincipal` | Title | Principal | (0,N) ↔ (1,1) | weak FK |
| `creditedAs` | Person | Principal | (0,N) ↔ (1,1) | weak FK |
| `hasRole` | Principal | Role | (1,1) ↔ (0,N) | every Principal has exactly 1 role; FK `principal.role_id` → `role.role_id` |
| `hasProfession` | Person | Profession | M:N (0,3) ↔ (0,N) | junction; capped at 3 per person per IMDb |
| `knownFor` | Person | Title | M:N (0,4) ↔ (0,N) | junction `person_known_for`; capped at 4; filtered to slice tconsts |
| `hasEpisode` | Series | Episode | (0,N) ↔ (1,1) | F-02; honest to slice — only 6 of 285 series have any episode though data is sparse |
| `partOfSeries` | Episode | Series | (1,1) ↔ (0,N) | inverse of hasEpisode |
| `akaInLanguage` | TitleAKA | Language | (0,1) ↔ (0,N) | nullable FK |
| `akaInRegion` | TitleAKA | Region | (0,1) ↔ (0,N) | nullable FK |
| `hasCharacter` | Principal | (multi-valued attribute) | (0,N) ↔ — | reduces to junction `principal_character` |
| (IS-A) | Film, Series, Episode | Title | partial, disjoint | discriminator = `title.title_type_id` (FK to `title_type` lookup); matches M3 ontology's `:Film` / `:Series` / `:Episode` |

---

## 10. Decision provenance

Every entity, attribute, and relationship in this document traces back to a recorded decision in `docs/erd_investigation.md`:

| Entity / element | Decisions consulted |
|---|---|
| `Title` | F-01, Q06 (rating composite), Q03 (is_adult) |
| `Title` IS-A `{Film, Series, Episode}` (matches M3 ontology) | F-02 |
| `Title.title_type_id` FK to `title_type` lookup (entity-set form) | F-02 (revised), Q10 |
| `Title_Episode` extra attributes | F-02 |
| `Person` | F-01 |
| Person OWL subclasses (5) | Q01, Q02 (revised) |
| `Title_Genre` (multi-valued attribute, not an entity); `Adult` excluded | Q03 |
| `Title_AKA` 8 attributes incl. types/attributes; junction dropped | Q07, Q11 |
| `Language` / `Region` lookups | Q07, Q10 |
| `Principal` weak entity, PK = (tconst, ordering) | Q01, Q05 |
| `Principal.role_id` (FK to `Role` entity set) | Q02 (revised) |
| `Principal.job` free text | Q12 |
| `Principal_Character` multi-valued junction | Q05 |
| `Person_Profession` junction | Q01 |
| `Person_Known_For` filtered junction | Q08 |
| Director/writer routed through `Principal` only | Q04 (revised) |
| Lookups populated from data, no hard-coded values | Q10 |
| NULL handling via R2RML's auto-skip | Q09 |
| Slice criterion (N=2,500 by numVotes DESC) | D-02, Q14 |

---

## 11. Appendix — for the report's ERD section

This section gives the team material that can be lifted nearly verbatim into the report's §3 (ERD) appendix.

### Suggested figure caption

> "Migrated CineExplorer ERD. Two strong entity sets (`Title`, `Person`), six lookup entities (`Title_Type`, `Role`, `Profession`, `Language`, `Region`, `AKA_Type`), two weak entities (`TitleAKA`, `Principal`), and a partial-disjoint IS-A specialisation of `Title` into `Film`, `Series`, `Episode` (matching the M3 ontology). `Genre` and `Character` are multi-valued attributes (not entities), reduced to attribute tables that store the value name directly. `Principal` is named after IMDb's source vocabulary (`title.principals.tsv`); the corresponding ontology class is `ce:Participation` (the abstract reified-relationship name). The slice corresponds to the top 5,000 IMDb titles by `numVotes` (descending), per D-02 of the migration plan."

### One-paragraph summary of each entity

- **Title** — every audiovisual work in the slice (movies, series, episodes, shorts, etc.). Identified by the IMDb `tconst`. Carries the composite rating attribute `(average_rating, num_votes)` directly (no separate Rating relation, per ERD-Q06), the `is_adult` flag (per ERD-Q03), and the `title_type_id` FK (per F-02 revised — points at the `title_type` lookup entity).
- **Person** — every person credited on a title in the slice. Identified by IMDb `nconst`. Career-level professions are tracked via the `Person ↔ Profession` M:N relationship (per ERD-Q01).
- **Film, Series, Episode** — IS-A subtypes of Title (matching the M3 ontology), discriminated by `title_type_id`. `Film` covers `title_type_id = 'movie'`; `Series` covers `'tvSeries'`/`'tvMiniSeries'`/`'tvPilot'`; `Episode` covers `'tvEpisode'`. Only `Episode` carries extra attributes (`parent_tconst`, `season_number`, `episode_number`) and gets its own `title_episode` table; `Film` and `Series` are pure discriminator-based subtypes with no separate tables. Other titleTypes (`short`, `video`, `tvMovie`, etc.) are not modelled as subtypes — they remain plain Title rows.
- **TitleAKA** — alternate / localised titles (weak entity dependent on Title). Carries `region_id`, `language_id`, `is_original_title`, `attributes`. The IMDb `types` column is split into the `Title_AKA_Type` M:N junction (ERD-Q15).
- **Principal** — per-credit cast/crew involvement (weak entity dependent on Title and Person). Carries `role_id`, `job`, and the multi-valued `character_name` (reduced to a junction). Director and writer credits are routed through Principal rather than via separate `direct`/`write` relationships, matching the rest of the per-credit categories (ERD-Q04 revised). At the ontology layer this becomes `ce:Participation`.

### Schema-design highlights worth one paragraph in §2 Database

- **Slice criterion**: top-2,500 IMDb titles by `numVotes` (descending), per D-02. The slice covers ≈ 0.15 % of all IMDb titles by popularity but contains the bridge persons required for the Bacon-number demonstrator.
- **Composite attribute**: `rating` on Title rendered as two columns rather than a separate Rating relation (ERD-Q06).
- **Multi-valued attribute**: `character_name` on Principal reduced to the `principal_character` junction (ERD-Q05).
- **NULL semantics**: per ERD-Q09, R2RML's automatic skip-on-NULL is the correct mapping behaviour at the much higher full-IMDb NULL rates (e.g. 96 % NULL on `birth_year`, 50 % on `runtime_minutes`).
- **Lookup tables** (`title_type`, `role`, `profession`, `language`, `region`, `aka_type`) are populated from the slice (the first five dynamically; `aka_type` is seeded with the 8 IMDb-documented codes plus descriptions, ERD-Q15). `Genre` and `Character` are *not* lookup entities; they're multi-valued attributes whose values are stored directly in their respective attribute tables (`title_genre.GENRE_NAME`, `principal_character.CHARACTER_NAME`).

### Acknowledged limitations (for §10 Demonstrator or §11 Discussion)

- **Episode coverage is thin in our slice** (21 episodes attached to 6 series; 279 of 285 series have empty `hasEpisode`). The structure is fully modelled; the data is honestly sparse (ERD-Q13).
- **`title.crew` is loaded but unused** for director/writer credits — those flow through `Principal` from `title.principals` for consistency with the rest of the per-credit categories (ERD-Q04 revised). The 884 K extra director-pairs and 2.9 M extra writer-pairs in `title.crew` (concentrated on long-tail TV that's outside our slice anyway) are not captured.
- **`actor` and `actress` are collapsed** to a single `:Actor` class / `actor` role-name in the migrated KG (ERD-Q02). The original IMDb categorical strings are preserved at the data level (in `role.role_name`) if a future query needs them.
