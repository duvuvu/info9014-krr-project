-- =================================================================
-- imdb-schema.sql
-- CineExplorer migrated database — all-in-one schema script.
--
-- Builds the relational source for the CineExplorer KG from the
-- filtered IMDb TSVs. Six phases run in order in a single MySQL
-- session:
--
--   1. Canonical tables  (no FKs, no indexes yet)
--   2. Staging tables    (mirror IMDb's filtered TSV shape)
--   3. LOAD DATA INFILE  (TSV  -> staging)
--   4. INSERT-SELECT     (staging -> canonical)
--   5. Drop staging      (final DB has only canonical tables)
--   6. Foreign keys & indexes
--
-- Pre-conditions:
--   * Filtered TSVs are mounted at /var/lib/mysql-files/<file>.tsv
--     inside the MySQL container.
--   * The MySQL service has --local-infile=1 enabled.
-- =================================================================

USE `imdb`;

SET NAMES utf8mb4;
SET sql_mode = 'STRICT_TRANS_TABLES';


-- =================================================================
-- 0. CLEAN SLATE (idempotent re-runs)
-- FK checks disabled so the drop order does not have to follow
-- the FK dependency graph.
-- =================================================================

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS title_aka_type;
DROP TABLE IF EXISTS principal_character;
DROP TABLE IF EXISTS person_known_for;
DROP TABLE IF EXISTS person_profession;
DROP TABLE IF EXISTS title_genre;
DROP TABLE IF EXISTS principal;
DROP TABLE IF EXISTS title_aka;
DROP TABLE IF EXISTS title_episode;
DROP TABLE IF EXISTS title;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS aka_type;
DROP TABLE IF EXISTS region;
DROP TABLE IF EXISTS language;
DROP TABLE IF EXISTS profession;
DROP TABLE IF EXISTS role;
DROP TABLE IF EXISTS title_type;

-- Staging tables (in case a previous run aborted before phase 5).
DROP TABLE IF EXISTS title_basics_staging;
DROP TABLE IF EXISTS title_akas_staging;
DROP TABLE IF EXISTS title_episode_staging;
DROP TABLE IF EXISTS title_principals_staging;
DROP TABLE IF EXISTS title_ratings_staging;
DROP TABLE IF EXISTS name_basics_staging;

SET FOREIGN_KEY_CHECKS = 1;


-- =================================================================
-- 1. CANONICAL TABLES
-- =================================================================

-- Lookup entities ----------------------------------------------------

CREATE TABLE title_type (
    TITLE_TYPE_ID    VARCHAR(20)  NOT NULL,
    TITLE_TYPE_NAME  VARCHAR(100) NULL,
    PRIMARY KEY (TITLE_TYPE_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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

CREATE TABLE aka_type (
    AKA_TYPE_ID           VARCHAR(20)  NOT NULL,
    AKA_TYPE_NAME         VARCHAR(100) NOT NULL,
    AKA_TYPE_DESCRIPTION  VARCHAR(500) NULL,
    PRIMARY KEY (AKA_TYPE_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Strong entities ----------------------------------------------------

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

-- IS-A subtype with extra attributes --------------------------------

CREATE TABLE title_episode (
    TCONST          VARCHAR(20)  NOT NULL,
    PARENT_TCONST   VARCHAR(20)  NOT NULL,
    SEASON_NUMBER   INT          NULL,
    EPISODE_NUMBER  INT          NULL,
    PRIMARY KEY (TCONST)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Weak entities -----------------------------------------------------

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

CREATE TABLE principal (
    TCONST     VARCHAR(20)   NOT NULL,
    ORDERING   INT           NOT NULL,
    NCONST     VARCHAR(20)   NOT NULL,
    ROLE_ID    INT           NOT NULL,
    JOB        VARCHAR(500)  NULL,
    PRIMARY KEY (TCONST, ORDERING)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Multi-valued attributes and junctions -----------------------------

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

CREATE TABLE title_aka_type (
    TCONST       VARCHAR(20)  NOT NULL,
    ORDERING     INT          NOT NULL,
    AKA_TYPE_ID  VARCHAR(20)  NOT NULL,
    PRIMARY KEY (TCONST, ORDERING, AKA_TYPE_ID)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =================================================================
-- 2. STAGING TABLES
-- =================================================================

CREATE TABLE title_basics_staging (
    tconst           VARCHAR(20),
    titleType        VARCHAR(32),
    primaryTitle     VARCHAR(500),
    originalTitle    VARCHAR(500),
    isAdult          TINYINT(1),
    startYear        INT,
    endYear          INT,
    runtimeMinutes   INT,
    genres           VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE title_akas_staging (
    titleId          VARCHAR(20),
    ordering         INT,
    title            VARCHAR(500),
    region           VARCHAR(10),
    language         VARCHAR(10),
    types            VARCHAR(64),
    attributes       VARCHAR(500),
    isOriginalTitle  TINYINT(1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE title_episode_staging (
    tconst         VARCHAR(20),
    parentTconst   VARCHAR(20),
    seasonNumber   INT,
    episodeNumber  INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE title_principals_staging (
    tconst       VARCHAR(20),
    ordering     INT,
    nconst       VARCHAR(20),
    category     VARCHAR(64),
    job          VARCHAR(500),
    characters   TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE title_ratings_staging (
    tconst         VARCHAR(20),
    averageRating  DECIMAL(3,1),
    numVotes       INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE name_basics_staging (
    nconst             VARCHAR(20),
    primaryName        VARCHAR(500),
    birthYear          INT,
    deathYear          INT,
    primaryProfession  VARCHAR(255),
    knownForTitles     VARCHAR(255)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- =================================================================
-- 3. LOAD DATA INFILE
-- IMDb's NULL marker is the literal two-character string '\N'; we
-- load it verbatim and convert to SQL NULL via NULLIF below.
-- =================================================================

LOAD DATA INFILE '/var/lib/mysql-files/title_basics.tsv'
    INTO TABLE title_basics_staging
    FIELDS TERMINATED BY '\t' ESCAPED BY ''
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (tconst, titleType, primaryTitle, originalTitle,
     @isAdult, @startYear, @endYear, @runtimeMinutes, @genres)
    SET isAdult        = NULLIF(@isAdult, '\\N'),
        startYear      = NULLIF(@startYear, '\\N'),
        endYear        = NULLIF(@endYear, '\\N'),
        runtimeMinutes = NULLIF(@runtimeMinutes, '\\N'),
        genres         = NULLIF(@genres, '\\N');

LOAD DATA INFILE '/var/lib/mysql-files/title_akas.tsv'
    INTO TABLE title_akas_staging
    FIELDS TERMINATED BY '\t' ESCAPED BY ''
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (titleId, ordering, title,
     @region, @language, @types, @attributes, @isOriginalTitle)
    SET region          = NULLIF(@region, '\\N'),
        language        = NULLIF(@language, '\\N'),
        types           = NULLIF(@types, '\\N'),
        attributes      = NULLIF(@attributes, '\\N'),
        isOriginalTitle = NULLIF(@isOriginalTitle, '\\N');

LOAD DATA INFILE '/var/lib/mysql-files/title_episode.tsv'
    INTO TABLE title_episode_staging
    FIELDS TERMINATED BY '\t' ESCAPED BY ''
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (tconst, parentTconst, @seasonNumber, @episodeNumber)
    SET seasonNumber  = NULLIF(@seasonNumber, '\\N'),
        episodeNumber = NULLIF(@episodeNumber, '\\N');

LOAD DATA INFILE '/var/lib/mysql-files/title_principals.tsv'
    INTO TABLE title_principals_staging
    FIELDS TERMINATED BY '\t' ESCAPED BY ''
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (tconst, ordering, nconst, category, @job, @characters)
    SET job        = NULLIF(@job, '\\N'),
        characters = NULLIF(@characters, '\\N');

LOAD DATA INFILE '/var/lib/mysql-files/title_ratings.tsv'
    INTO TABLE title_ratings_staging
    FIELDS TERMINATED BY '\t' ESCAPED BY ''
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (tconst, averageRating, numVotes);

LOAD DATA INFILE '/var/lib/mysql-files/name_basics.tsv'
    INTO TABLE name_basics_staging
    FIELDS TERMINATED BY '\t' ESCAPED BY ''
    LINES TERMINATED BY '\n'
    IGNORE 1 LINES
    (nconst, primaryName,
     @birthYear, @deathYear, @primaryProfession, @knownForTitles)
    SET birthYear         = NULLIF(@birthYear, '\\N'),
        deathYear         = NULLIF(@deathYear, '\\N'),
        primaryProfession = NULLIF(@primaryProfession, '\\N'),
        knownForTitles    = NULLIF(@knownForTitles, '\\N');


-- =================================================================
-- 4. POPULATE CANONICAL TABLES FROM STAGING
-- =================================================================

-- Lookups (dynamic from staging, except aka_type which is seeded). --

INSERT INTO title_type (TITLE_TYPE_ID, TITLE_TYPE_NAME)
    SELECT DISTINCT titleType, titleType
    FROM   title_basics_staging
    WHERE  titleType IS NOT NULL;

-- 'actor' and 'actress' are collapsed to a single 'actor' role.
INSERT IGNORE INTO role (ROLE_NAME)
    SELECT DISTINCT
           CASE WHEN category IN ('actor','actress') THEN 'actor'
                ELSE category
           END
    FROM   title_principals_staging
    WHERE  category IS NOT NULL;

INSERT IGNORE INTO profession (PROFESSION_NAME)
    SELECT DISTINCT TRIM(j.value)
    FROM   name_basics_staging n,
           JSON_TABLE(
               CONCAT('["', REPLACE(n.primaryProfession, ',', '","'), '"]'),
               '$[*]' COLUMNS (value VARCHAR(64) PATH '$')
           ) j
    WHERE  n.primaryProfession IS NOT NULL;

INSERT IGNORE INTO language (LANGUAGE_ID)
    SELECT DISTINCT language
    FROM   title_akas_staging
    WHERE  language IS NOT NULL;

INSERT IGNORE INTO region (REGION_ID)
    SELECT DISTINCT region
    FROM   title_akas_staging
    WHERE  region IS NOT NULL;

-- aka_type is the only seeded lookup: IMDb's title.akas.types
-- vocabulary is a closed 8-value set, and the codes are not
-- self-describing, so we attach a description column.
INSERT INTO aka_type (AKA_TYPE_ID, AKA_TYPE_NAME, AKA_TYPE_DESCRIPTION) VALUES
  ('imdbDisplay', 'IMDb display title',  'Title used by IMDb''s UI for this locale.'),
  ('original',    'Original title',      'Title in the original production language at first release.'),
  ('alternative', 'Alternative title',   'Generic alternate variant of the title.'),
  ('tv',          'TV title',            'Title used in TV broadcast.'),
  ('dvd',         'DVD title',           'Title used on DVD packaging or release.'),
  ('video',       'Video title',         'Title used for home-video release.'),
  ('festival',    'Festival title',      'Title used at film festivals.'),
  ('working',     'Working title',       'Production working title used before release.');

-- Strong entities ---------------------------------------------------

INSERT INTO title (TCONST, PRIMARY_TITLE, ORIGINAL_TITLE, IS_ADULT,
                   START_YEAR, END_YEAR, RUNTIME_MINUTES,
                   AVERAGE_RATING, NUM_VOTES, TITLE_TYPE_ID)
    SELECT b.tconst,
           b.primaryTitle,
           b.originalTitle,
           COALESCE(b.isAdult, 0),
           b.startYear,
           b.endYear,
           b.runtimeMinutes,
           r.averageRating,
           r.numVotes,
           b.titleType
    FROM   title_basics_staging b
    LEFT   JOIN title_ratings_staging r ON r.tconst = b.tconst;

INSERT INTO person (NCONST, PRIMARY_NAME, BIRTH_YEAR, DEATH_YEAR)
    SELECT nconst, primaryName, birthYear, deathYear
    FROM   name_basics_staging;

-- IS-A subtype ------------------------------------------------------

INSERT INTO title_episode (TCONST, PARENT_TCONST, SEASON_NUMBER, EPISODE_NUMBER)
    SELECT tconst, parentTconst, seasonNumber, episodeNumber
    FROM   title_episode_staging;

-- Weak entities -----------------------------------------------------

INSERT INTO title_aka (TCONST, ORDERING, TITLE, REGION_ID, LANGUAGE_ID,
                       IS_ORIGINAL_TITLE, ATTRIBUTES)
    SELECT titleId,
           ordering,
           title,
           region,
           language,
           COALESCE(isOriginalTitle, 0),
           attributes
    FROM   title_akas_staging;

INSERT INTO principal (TCONST, ORDERING, NCONST, ROLE_ID, JOB)
    SELECT p.tconst,
           p.ordering,
           p.nconst,
           r.ROLE_ID,
           p.job
    FROM   title_principals_staging p
    JOIN   role r
        ON r.ROLE_NAME = CASE WHEN p.category IN ('actor','actress') THEN 'actor'
                              ELSE p.category
                         END
    WHERE  p.category IS NOT NULL;

-- Multi-valued attributes and junctions -----------------------------

-- 'Adult' is excluded from the genre vocabulary: title.is_adult
-- already carries that information.
INSERT INTO title_genre (TCONST, GENRE_NAME)
    SELECT DISTINCT
           b.tconst,
           TRIM(j.value)
    FROM   title_basics_staging b,
           JSON_TABLE(
               CONCAT('["', REPLACE(b.genres, ',', '","'), '"]'),
               '$[*]' COLUMNS (value VARCHAR(64) PATH '$')
           ) j
    WHERE  b.genres IS NOT NULL
      AND  TRIM(j.value) <> 'Adult'
      AND  TRIM(j.value) <> '';

INSERT INTO person_profession (NCONST, PROFESSION_ID)
    SELECT DISTINCT
           n.nconst,
           p.PROFESSION_ID
    FROM   name_basics_staging n,
           JSON_TABLE(
               CONCAT('["', REPLACE(n.primaryProfession, ',', '","'), '"]'),
               '$[*]' COLUMNS (value VARCHAR(64) PATH '$')
           ) j
    JOIN   profession p ON p.PROFESSION_NAME = TRIM(j.value)
    WHERE  n.primaryProfession IS NOT NULL;

-- The INNER JOIN to `title` drops knownFor refs that point outside
-- the slice — a known-for title we did not retain cannot be
-- referenced by a clean FK.
INSERT INTO person_known_for (NCONST, TCONST)
    SELECT DISTINCT
           n.nconst,
           j.value
    FROM   name_basics_staging n,
           JSON_TABLE(
               CONCAT('["', REPLACE(n.knownForTitles, ',', '","'), '"]'),
               '$[*]' COLUMNS (value VARCHAR(20) PATH '$')
           ) j
    JOIN   title t ON t.TCONST = j.value
    WHERE  n.knownForTitles IS NOT NULL;

INSERT INTO principal_character (TCONST, ORDERING, CHARACTER_NAME)
    SELECT p.tconst,
           p.ordering,
           TRIM(BOTH '"' FROM TRIM(j.value))
    FROM   title_principals_staging p,
           JSON_TABLE(
               p.characters,
               '$[*]' COLUMNS (value VARCHAR(500) PATH '$')
           ) j
    WHERE  p.characters IS NOT NULL
      AND  TRIM(j.value) <> '';

-- title_aka_type splits the byte-0x02-separated multi-valued
-- title.akas.types attribute. The JOIN to aka_type filters to the
-- closed 8-value vocabulary.
INSERT INTO title_aka_type (TCONST, ORDERING, AKA_TYPE_ID)
    SELECT DISTINCT
           a.titleId,
           a.ordering,
           t.AKA_TYPE_ID
    FROM   title_akas_staging a,
           JSON_TABLE(
               CONCAT('["',
                      REPLACE(a.types, CHAR(2 USING utf8mb4), '","'),
                      '"]'),
               '$[*]' COLUMNS (value VARCHAR(64) PATH '$')
           ) j
    JOIN   aka_type t ON t.AKA_TYPE_ID = TRIM(j.value)
    WHERE  a.types IS NOT NULL
      AND  TRIM(j.value) <> '';


-- =================================================================
-- 5. DROP STAGING
-- =================================================================

DROP TABLE title_basics_staging;
DROP TABLE title_akas_staging;
DROP TABLE title_episode_staging;
DROP TABLE title_principals_staging;
DROP TABLE title_ratings_staging;
DROP TABLE name_basics_staging;


-- =================================================================
-- 6. FOREIGN KEYS AND INDEXES
-- Added after population so InnoDB does not validate constraints
-- during the INSERT-SELECT phase.
-- =================================================================

ALTER TABLE title
  ADD CONSTRAINT fk_title_type
    FOREIGN KEY (TITLE_TYPE_ID) REFERENCES title_type(TITLE_TYPE_ID);
CREATE INDEX idx_title_type ON title(TITLE_TYPE_ID);

ALTER TABLE title_episode
  ADD CONSTRAINT fk_title_episode_self
    FOREIGN KEY (TCONST) REFERENCES title(TCONST),
  ADD CONSTRAINT fk_title_episode_parent
    FOREIGN KEY (PARENT_TCONST) REFERENCES title(TCONST);
CREATE INDEX idx_title_episode_parent ON title_episode(PARENT_TCONST);

ALTER TABLE title_aka
  ADD CONSTRAINT fk_title_aka_title
    FOREIGN KEY (TCONST) REFERENCES title(TCONST),
  ADD CONSTRAINT fk_title_aka_region
    FOREIGN KEY (REGION_ID) REFERENCES region(REGION_ID),
  ADD CONSTRAINT fk_title_aka_language
    FOREIGN KEY (LANGUAGE_ID) REFERENCES language(LANGUAGE_ID);
CREATE INDEX idx_title_aka_region   ON title_aka(REGION_ID);
CREATE INDEX idx_title_aka_language ON title_aka(LANGUAGE_ID);

ALTER TABLE principal
  ADD CONSTRAINT fk_principal_title
    FOREIGN KEY (TCONST) REFERENCES title(TCONST),
  ADD CONSTRAINT fk_principal_person
    FOREIGN KEY (NCONST) REFERENCES person(NCONST),
  ADD CONSTRAINT fk_principal_role
    FOREIGN KEY (ROLE_ID) REFERENCES role(ROLE_ID);
CREATE INDEX idx_principal_nconst ON principal(NCONST);
CREATE INDEX idx_principal_role   ON principal(ROLE_ID);

ALTER TABLE title_genre
  ADD CONSTRAINT fk_title_genre_title
    FOREIGN KEY (TCONST) REFERENCES title(TCONST);
CREATE INDEX idx_title_genre_name ON title_genre(GENRE_NAME);

ALTER TABLE person_profession
  ADD CONSTRAINT fk_pp_person
    FOREIGN KEY (NCONST) REFERENCES person(NCONST),
  ADD CONSTRAINT fk_pp_profession
    FOREIGN KEY (PROFESSION_ID) REFERENCES profession(PROFESSION_ID);
CREATE INDEX idx_pp_profession ON person_profession(PROFESSION_ID);

ALTER TABLE person_known_for
  ADD CONSTRAINT fk_pkf_person
    FOREIGN KEY (NCONST) REFERENCES person(NCONST),
  ADD CONSTRAINT fk_pkf_title
    FOREIGN KEY (TCONST) REFERENCES title(TCONST);
CREATE INDEX idx_pkf_title ON person_known_for(TCONST);

ALTER TABLE principal_character
  ADD CONSTRAINT fk_pc_principal
    FOREIGN KEY (TCONST, ORDERING) REFERENCES principal(TCONST, ORDERING);

ALTER TABLE title_aka_type
  ADD CONSTRAINT fk_tat_aka
    FOREIGN KEY (TCONST, ORDERING) REFERENCES title_aka(TCONST, ORDERING),
  ADD CONSTRAINT fk_tat_type
    FOREIGN KEY (AKA_TYPE_ID) REFERENCES aka_type(AKA_TYPE_ID);
CREATE INDEX idx_tat_type ON title_aka_type(AKA_TYPE_ID);
