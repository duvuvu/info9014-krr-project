# Database Reference — CineExplorer (IMDb Sample)

> **Status: GOOD — accepted at M1**
> Source: IMDb non-commercial datasets, adapted via northCoder transformation.
> Engine: MySQL 8, InnoDB, utf8mb4. Deployed via Docker on port **3307**.

---

## Quick Stats

| Metric | Value |
|--------|-------|
| Total tables | 16 (+ 1 staging table dropped after load) |
| Titles | 174 |
| Persons (talent) | 1,441 |
| Principal credits | 587 |
| Episodes | 74 |
| Series | ~80 (content_type 4 or 7) |
| Genres | 28 |
| AKA titles | 359 |
| Talent-role links | 2,590 |
| Known-for links | 918 |

---

## Table Catalogue

### Lookup / Enum Tables

#### `category` (12 rows)
Credit category used in `title_principal` (per-title, per-person credit type).
```
CATEGORY_ID  INT  PK
CATEGORY_NAME  VARCHAR(100)
```
Values: self(1), director(2), cinematographer(3), composer(4), producer(5), editor(6),
actor(7), actress(8), writer(9), production_designer(10), archive_footage(11), archive_sound(12)

> **Distinction:** `category` = credit for a specific title; `role` = career profession of a person.

#### `content_type` (10 rows)
```
CONTENT_TYPE_ID  INT  PK
CONTENT_TYPE_NAME  VARCHAR(100)
```
Values: short(1), movie(2), TV Movie(3), TV Series(4), TV Episode(5), TV Short(6),
TV MiniSeries(7), TV Special(8), video(9), videoGame(10)

> Used to distinguish Film vs Series in R2RML mapping:
> Film  = content_type_id IN (1,2,3,6,8,9) AND NOT IN title_episode
> Series = content_type_id IN (4,7) AND NOT IN title_episode

#### `genre` (28 rows)
```
GENRE_ID  INT  PK
GENRE_NAME  VARCHAR(100)
```
Values: Documentary(1), Short(2), Animation(3), Comedy(4), Romance(5), Sport(6),
Action(7), News(8), Drama(9), Fantasy(10), Horror(11), Biography(12), Music(13),
War(14), Crime(15), Western(16), Family(17), Adventure(18), History(19), Mystery(20),
Sci-Fi(21), Thriller(22), Musical(23), Film-Noir(24), Game-Show(25), Talk-Show(26),
Reality-TV(27), Adult(28)

#### `language` (102 rows)
```
LANGUAGE_ID  VARCHAR(10)  PK  -- ISO 639 code (e.g. 'en', 'fr', 'cmn')
LANGUAGE_NAME  VARCHAR(100)   -- null in CSV, filled via UPDATE in schema
```

#### `region` (246 rows)
```
REGION_ID  VARCHAR(10)  PK  -- ISO 3166 alpha-2 (e.g. 'US', 'FR') + historical codes
REGION_NAME  VARCHAR(100)   -- null in CSV, filled via UPDATE in schema
```

#### `role` (40 rows)
Career professions of a person (from IMDb's `name.basics.primaryProfession`).
```
ROLE_ID  INT  PK
ROLE_NAME  VARCHAR(100)
```
Values include: actor, actress, director, writer, composer, editor, producer,
cinematographer, make up department, stunts, visual effects, …

#### `title_type` (8 rows)
Type of an AKA entry.
```
TITLE_TYPE_ID  INT  PK
TITLE_TYPE_NAME  VARCHAR(100)
```
Values: imdbDisplay(1), original(2), alternative(3), dvd(4), festival(5), working(6), tv(7), video(8)

---

### Core Entity Tables

#### `title` (174 rows)
Central entity — one row per audiovisual work.
```
TITLE_ID        VARCHAR(20)  PK  -- IMDb tconst, e.g. 'tt0000001'
CONTENT_TYPE_ID INT          FK → content_type
PRIMARY_TITLE   VARCHAR(500) NOT NULL
ORIGINAL_TITLE  VARCHAR(500) NULLABLE
IS_ADULT        INT          -- 0 or 1
START_YEAR      INT          NULLABLE
END_YEAR        INT          NULLABLE  -- only for series
RUNTIME_MINUTES INT          NULLABLE
```

Content distribution:
- TV Episodes (type 5): ~100 rows (episodes of various series)
- TV Series (type 4): ~55 rows
- Movie (type 2): ~13 rows
- Short (type 1): ~8 rows
- TV MiniSeries (type 7): ~3 rows
- Other: TV Movie, video, etc.

#### `talent` (1,441 rows)
Persons involved in productions.
```
TALENT_ID    VARCHAR(20)  PK  -- IMDb nconst, e.g. 'nm0000001'
TALENT_NAME  VARCHAR(500) NOT NULL
BIRTH_YEAR   INT          NULLABLE
DEATH_YEAR   INT          NULLABLE
```
Notable: Orson Welles(nm0000080), Russell Crowe(nm0000128), Helena Bonham Carter(nm0000307),
Werner Herzog(nm0001348)

---

### Association / Junction Tables

#### `title_episode` (74 rows)
Series-episode hierarchy. Self-referential FK on `title`.
```
TITLE_ID        VARCHAR(20)  PK FK → title  -- the episode
PARENT_TITLE_ID VARCHAR(20)  FK → title     -- the parent series (NULLABLE)
SEASON_NUMBER   INT          NULLABLE
EPISODE_NUMBER  INT          NULLABLE
INDEX: ttl_epi_par_idx ON (PARENT_TITLE_ID)
```

#### `title_principal` (587 rows)
Per-title, per-person credit. Primary credit table.
```
TITLE_ID     VARCHAR(20)  PK FK → title
TALENT_ID    VARCHAR(20)  PK FK → talent
ORD          INT          PK  -- credit order
CATEGORY_ID  INT          FK → category
JOB          VARCHAR(1000)   NULLABLE  -- free-text job description
INDEX: ttl_prin_tal_id_idx ON (TALENT_ID)
INDEX: ttl_prin_cat_id_idx ON (CATEGORY_ID)
```

#### `principal_role` (derived during load)
Character names normalized from comma-separated strings in `title_principal_raw.ROLE_NAMES`.
```
TITLE_ID   VARCHAR(20)  PK FK → title_principal(TITLE_ID,TALENT_ID,ORD)
TALENT_ID  VARCHAR(20)  PK
ORD        INT          PK
ROLE_NAME  VARCHAR(255) PK  -- one character name per row
```
Up to 10 character names per credit row (numbers-table split). `title_principal_raw` is dropped after load.

#### `talent_role` (2,590 rows)
A person's known career professions (from IMDb `primaryProfession`).
```
TALENT_ID  VARCHAR(20)  PK FK → talent
ROLE_ID    INT          PK FK → role
ORD        INT          -- profession ordering
```

#### `talent_title` (918 rows)
IMDb "known for" titles associated with a person.
```
TALENT_ID  VARCHAR(20)  PK FK → talent
TITLE_ID   VARCHAR(20)  PK FK → title
INDEX: tal_ttl_title_id_idx ON (TITLE_ID)
```

#### `title_genre` (152 rows)
Many-to-many genre assignments per title.
```
TITLE_ID  VARCHAR(20)  PK FK → title
GENRE_ID  INT          PK FK → genre
ORD       INT          -- genre ordering within a title (up to 3)
```

#### `title_aka` (359 rows)
Alternative and localized titles. Weak entity identified by (TITLE_ID, ORD).
```
TITLE_ID          VARCHAR(20)  PK FK → title
ORD               INT          PK
AKA_TITLE         VARCHAR(500) NOT NULL
REGION_ID         VARCHAR(10)  NULLABLE FK → region
LANGUAGE_ID       VARCHAR(10)  NULLABLE FK → language
ADDITIONAL_ATTRS  VARCHAR(500) NULLABLE
IS_ORIGINAL_TITLE INT          -- 1 if this is the canonical original
```

#### `title_aka_title_type` (55 rows)
AKA type tags.
```
TITLE_ID      VARCHAR(20)  PK FK → title_aka(TITLE_ID, ORD)
TITLE_TYPE_ID INT          PK FK → title_type
ORD           INT          PK
```

---

## Key Design Decisions

1. **Dual role system:** `category` (12 values, per-credit in `title_principal`) vs `role`
   (40 values, per-person career in `talent_role`). These are different concepts.

2. **1NF normalization of character names:** The raw `ROLE_NAMES` column was a comma-separated
   list in the original IMDb data. The schema splits it into `principal_role` using a
   numbers-table trick during load. `title_principal_raw` is the staging table, dropped after.

3. **Self-referential FK:** `title_episode.PARENT_TITLE_ID → title.TITLE_ID` is the only
   self-reference in the schema. Enables the Series-Episode hierarchy.

4. **Missing data handling:** `START_YEAR`, `END_YEAR`, `RUNTIME_MINUTES`, `BIRTH_YEAR`,
   `DEATH_YEAR`, `REGION_ID`, `LANGUAGE_ID`, `SEASON_NUMBER`, `EPISODE_NUMBER` are all
   nullable. R2RML skips NULL columns automatically.

5. **Referential integrity fix:** Some `title_principal` rows referenced `TALENT_ID` values
   not present in `talent`. These orphan rows were deleted before adding the FK constraint.

---

## How to Run

```bash
# Start
cd IMDB && docker-compose up -d
# MySQL
docker exec -it imdb-mysql mysql -u imdb_user -pimdb_pass imdb
# phpMyAdmin: http://localhost:8080 (imdb_user / imdb_pass)
# Stop
docker-compose down
# Full reset
docker-compose down -v
```
