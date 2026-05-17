# Information System Reference — CineExplorer (IMDb Sample)

> **Status: GOOD — accepted at M1**
> Source: IMDb non-commercial datasets. Engine: MySQL 8, InnoDB, utf8mb4. Port **3307**.

---

## Entity-Relationship Summary

The schema models the IMDb domain: audiovisual works (`title`) produced by people (`talent`),
categorized by genre, content type, region, and language, with normalized credits and episode hierarchy.

### Core Entities
| Entity | Table | PK type | Rows |
|--------|-------|---------|------|
| Audiovisual Work | `title` | `TITLE_ID` (IMDb tconst) | 174 |
| Person / Talent | `talent` | `TALENT_ID` (IMDb nconst) | 1,441 |
| Genre | `genre` | `GENRE_ID` INT | 28 |
| Language | `language` | `LANGUAGE_ID` ISO 639 | 102 |
| Region | `region` | `REGION_ID` ISO 3166 | 246 |
| Content Type | `content_type` | `CONTENT_TYPE_ID` INT | 10 |
| Credit Category | `category` | `CATEGORY_ID` INT | 12 |
| Career Role | `role` | `ROLE_ID` INT | 40 |
| Title Type (AKA) | `title_type` | `TITLE_TYPE_ID` INT | 8 |

### Association / Derived Entities
| Relationship | Table | PK | Rows |
|-------------|-------|----|------|
| Episode-of-Series | `title_episode` | `TITLE_ID` (→ `title`) | 74 |
| Credit (person × title) | `title_principal` | `(TITLE_ID, TALENT_ID, ORD)` | 587 |
| Character name (normalized) | `principal_role` | `(TITLE_ID, TALENT_ID, ORD, ROLE_NAME)` | ~N |
| Career profession (person × role) | `talent_role` | `(TALENT_ID, ROLE_ID)` | 2,590 |
| "Known for" (person × title) | `talent_title` | `(TALENT_ID, TITLE_ID)` | 918 |
| Genre assignment | `title_genre` | `(TITLE_ID, GENRE_ID)` | 152 |
| Alternative title | `title_aka` | `(TITLE_ID, ORD)` | 359 |
| AKA type tag | `title_aka_title_type` | `(TITLE_ID, ORD, TITLE_TYPE_ID)` | 55 |

---

## Relational Schema (DDL Summary)

### Lookup Tables

```sql
CREATE TABLE category (
  CATEGORY_ID   INT         NOT NULL PRIMARY KEY,
  CATEGORY_NAME VARCHAR(100) NOT NULL
);
-- Values: self(1), director(2), cinematographer(3), composer(4), producer(5),
--         editor(6), actor(7), actress(8), writer(9), production_designer(10),
--         archive_footage(11), archive_sound(12)

CREATE TABLE content_type (
  CONTENT_TYPE_ID   INT         NOT NULL PRIMARY KEY,
  CONTENT_TYPE_NAME VARCHAR(100) NOT NULL
);
-- Values: short(1), movie(2), TV Movie(3), TV Series(4), TV Episode(5),
--         TV Short(6), TV MiniSeries(7), TV Special(8), video(9), videoGame(10)

CREATE TABLE genre (
  GENRE_ID   INT         NOT NULL PRIMARY KEY,
  GENRE_NAME VARCHAR(100) NOT NULL
);
-- 28 rows: Documentary(1)…Adult(28)

CREATE TABLE language (
  LANGUAGE_ID   VARCHAR(10) NOT NULL PRIMARY KEY,  -- ISO 639
  LANGUAGE_NAME VARCHAR(100)                        -- filled via UPDATE
);

CREATE TABLE region (
  REGION_ID   VARCHAR(10) NOT NULL PRIMARY KEY,  -- ISO 3166 alpha-2
  REGION_NAME VARCHAR(100)                        -- filled via UPDATE
);

CREATE TABLE role (
  ROLE_ID   INT         NOT NULL PRIMARY KEY,
  ROLE_NAME VARCHAR(100) NOT NULL
);
-- 40 values: actor, actress, director, writer, composer, editor, producer,
--            cinematographer, make up department, stunts, visual effects, …

CREATE TABLE title_type (
  TITLE_TYPE_ID   INT         NOT NULL PRIMARY KEY,
  TITLE_TYPE_NAME VARCHAR(100) NOT NULL
);
-- Values: imdbDisplay(1), original(2), alternative(3), dvd(4),
--         festival(5), working(6), tv(7), video(8)
```

### Core Entity Tables

```sql
CREATE TABLE title (
  TITLE_ID         VARCHAR(20)  NOT NULL PRIMARY KEY,  -- tconst e.g. 'tt0000001'
  CONTENT_TYPE_ID  INT          NOT NULL,
  PRIMARY_TITLE    VARCHAR(500) NOT NULL,
  ORIGINAL_TITLE   VARCHAR(500),
  IS_ADULT         INT,                                 -- 0 or 1
  START_YEAR       INT,
  END_YEAR         INT,
  RUNTIME_MINUTES  INT,
  FOREIGN KEY (CONTENT_TYPE_ID) REFERENCES content_type(CONTENT_TYPE_ID)
);
-- 174 rows; content distribution:
--   TV Episode (5): ~100  TV Series (4): ~55  Movie (2): ~13
--   Short (1): ~8         TV MiniSeries (7): ~3

CREATE TABLE talent (
  TALENT_ID   VARCHAR(20)  NOT NULL PRIMARY KEY,  -- nconst e.g. 'nm0000001'
  TALENT_NAME VARCHAR(500) NOT NULL,
  BIRTH_YEAR  INT,
  DEATH_YEAR  INT
);
-- 1,441 rows
-- Notable: Orson Welles (nm0000080), Russell Crowe (nm0000128),
--          Helena Bonham Carter (nm0000307), Werner Herzog (nm0001348)
```

### Association Tables

```sql
-- Series → Episode hierarchy (self-referential FK on title)
CREATE TABLE title_episode (
  TITLE_ID        VARCHAR(20) NOT NULL PRIMARY KEY,  -- the episode
  PARENT_TITLE_ID VARCHAR(20),                        -- the parent series (nullable)
  SEASON_NUMBER   INT,
  EPISODE_NUMBER  INT,
  FOREIGN KEY (TITLE_ID) REFERENCES title(TITLE_ID),
  FOREIGN KEY (PARENT_TITLE_ID) REFERENCES title(TITLE_ID),
  INDEX ttl_epi_par_idx (PARENT_TITLE_ID)
);

-- Per-title, per-person credit
CREATE TABLE title_principal (
  TITLE_ID    VARCHAR(20)   NOT NULL,
  TALENT_ID   VARCHAR(20)   NOT NULL,
  ORD         INT           NOT NULL,
  CATEGORY_ID INT,
  JOB         VARCHAR(1000),                   -- free-text job description
  PRIMARY KEY (TITLE_ID, TALENT_ID, ORD),
  FOREIGN KEY (TITLE_ID)    REFERENCES title(TITLE_ID),
  FOREIGN KEY (TALENT_ID)   REFERENCES talent(TALENT_ID),
  FOREIGN KEY (CATEGORY_ID) REFERENCES category(CATEGORY_ID),
  INDEX ttl_prin_tal_id_idx (TALENT_ID),
  INDEX ttl_prin_cat_id_idx (CATEGORY_ID)
);
-- 587 rows. NOTE: orphan TALENT_IDs were deleted before FK was added.

-- Character names (1NF normalization of comma-separated role_names)
CREATE TABLE principal_role (
  TITLE_ID  VARCHAR(20)  NOT NULL,
  TALENT_ID VARCHAR(20)  NOT NULL,
  ORD       INT          NOT NULL,
  ROLE_NAME VARCHAR(255) NOT NULL,
  PRIMARY KEY (TITLE_ID, TALENT_ID, ORD, ROLE_NAME),
  FOREIGN KEY (TITLE_ID, TALENT_ID, ORD)
    REFERENCES title_principal(TITLE_ID, TALENT_ID, ORD)
);
-- Derived during load from title_principal_raw.ROLE_NAMES (comma-separated).
-- title_principal_raw (staging table) is DROPPED after load.

-- Career professions (from IMDb primaryProfession)
CREATE TABLE talent_role (
  TALENT_ID VARCHAR(20) NOT NULL,
  ROLE_ID   INT         NOT NULL,
  ORD       INT,
  PRIMARY KEY (TALENT_ID, ROLE_ID),
  FOREIGN KEY (TALENT_ID) REFERENCES talent(TALENT_ID),
  FOREIGN KEY (ROLE_ID)   REFERENCES role(ROLE_ID)
);
-- 2,590 rows

-- IMDb "known for" titles
CREATE TABLE talent_title (
  TALENT_ID VARCHAR(20) NOT NULL,
  TITLE_ID  VARCHAR(20) NOT NULL,
  PRIMARY KEY (TALENT_ID, TITLE_ID),
  FOREIGN KEY (TALENT_ID) REFERENCES talent(TALENT_ID),
  FOREIGN KEY (TITLE_ID)  REFERENCES title(TITLE_ID),
  INDEX tal_ttl_title_id_idx (TITLE_ID)
);
-- 918 rows

-- Genre assignment (up to 3 per title, ordered)
CREATE TABLE title_genre (
  TITLE_ID VARCHAR(20) NOT NULL,
  GENRE_ID INT         NOT NULL,
  ORD      INT,
  PRIMARY KEY (TITLE_ID, GENRE_ID),
  FOREIGN KEY (TITLE_ID) REFERENCES title(TITLE_ID),
  FOREIGN KEY (GENRE_ID) REFERENCES genre(GENRE_ID)
);
-- 152 rows

-- Alternative / localized titles
CREATE TABLE title_aka (
  TITLE_ID         VARCHAR(20)  NOT NULL,
  ORD              INT          NOT NULL,
  AKA_TITLE        VARCHAR(500) NOT NULL,
  REGION_ID        VARCHAR(10),
  LANGUAGE_ID      VARCHAR(10),
  ADDITIONAL_ATTRS VARCHAR(500),
  IS_ORIGINAL_TITLE INT,
  PRIMARY KEY (TITLE_ID, ORD),
  FOREIGN KEY (TITLE_ID)    REFERENCES title(TITLE_ID),
  FOREIGN KEY (REGION_ID)   REFERENCES region(REGION_ID),
  FOREIGN KEY (LANGUAGE_ID) REFERENCES language(LANGUAGE_ID)
);
-- 359 rows

-- AKA type tags
CREATE TABLE title_aka_title_type (
  TITLE_ID      VARCHAR(20) NOT NULL,
  TITLE_TYPE_ID INT         NOT NULL,
  ORD           INT         NOT NULL,
  PRIMARY KEY (TITLE_ID, TITLE_TYPE_ID, ORD),
  FOREIGN KEY (TITLE_ID, ORD) REFERENCES title_aka(TITLE_ID, ORD),
  FOREIGN KEY (TITLE_TYPE_ID) REFERENCES title_type(TITLE_TYPE_ID)
);
-- 55 rows
```

---

## Key Design Decisions

### 1. IMDb Identifiers as Primary Keys
`TITLE_ID` uses IMDb `tconst` format (e.g., `tt0000001`) and `TALENT_ID` uses `nconst` (e.g., `nm0000001`).
These are globally stable, externally recognized identifiers — directly reused as the basis for IRIs in the KG.

### 2. Two Distinct Role Systems
- **`category`** (12 values) — credit type for a specific title-person pair in `title_principal`
  (e.g., actor, director, composer for that film)
- **`role`** (40 values) — career profession of a person from `talent_role`
  (e.g., "this person's career includes acting, directing")

These are different concepts and must not be confused.

### 3. 1NF Normalization of Character Names
The raw IMDb data (`title_principal_raw.ROLE_NAMES`) stored comma-separated character names.
This was split into one row per character using a numbers-table trick during load, producing `principal_role`.
The staging table `title_principal_raw` is dropped after load.

### 4. Self-Referential FK for Episode Hierarchy
`title_episode.PARENT_TITLE_ID → title.TITLE_ID` is the only self-reference.
Enables the Series → Episode hierarchy queried in the KG with `ce:partOfSeries` / `ce:hasEpisode`.

### 5. Content Type Determines KG Class
- Film = `CONTENT_TYPE_ID IN (1,2,3,6,8,9)` AND `NOT IN title_episode`
- Series = `CONTENT_TYPE_ID IN (4,7)` AND `NOT IN title_episode`
- Episode = `IN title_episode` AND `PARENT_TITLE_ID IS NOT NULL`

### 6. Nullable Columns
`START_YEAR`, `END_YEAR`, `RUNTIME_MINUTES`, `BIRTH_YEAR`, `DEATH_YEAR`, `REGION_ID`,
`LANGUAGE_ID`, `SEASON_NUMBER`, `EPISODE_NUMBER` are all nullable.
R2RML processor skips NULL columns automatically — no triples generated for nulls.

### 7. FK Integrity Fix
Some `title_principal` rows referenced `TALENT_ID` values absent from `talent`.
Orphan rows were deleted before adding the FK constraint.

---

## Docker Commands

```bash
cd IMDB && docker-compose up -d                                  # start
docker exec -it imdb-mysql mysql -u imdb_user -pimdb_pass imdb  # MySQL shell
# phpMyAdmin: http://localhost:8080 (imdb_user / imdb_pass)
docker-compose down                                              # stop
docker-compose down -v                                           # full reset
```
