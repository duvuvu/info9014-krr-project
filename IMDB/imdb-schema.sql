USE `imdb`;

--
-- WARNINGS - you may need the following permission
-- to be granted, to be able to run LOAD DATA commands:
--
--   grant file on *.* to imdb_user@localhost identified by 'imdb_user';
--
-- Replace 'imdb_user' with your user ID, as needed.
--
-- CSV files are expected to be found in the secure 
-- file upload directory. See the output from the following:
--
--   SHOW VARIABLES LIKE "secure_file_priv";
--
-- But note that the path separator is '/' not '\', even on
-- Windows.
--

-- -----------------------------------------------

DROP TABLE IF EXISTS `title_episode`;
DROP TABLE IF EXISTS `title_aka_title_type`;
DROP TABLE IF EXISTS `principal_role`;
DROP TABLE IF EXISTS `title_principal`;
DROP TABLE IF EXISTS `title_principal_raw`;
DROP TABLE IF EXISTS `title_genre`;
DROP TABLE IF EXISTS `title_aka`;
DROP TABLE IF EXISTS `talent_title`;
DROP TABLE IF EXISTS `talent_role`;
DROP TABLE IF EXISTS `talent`;
DROP TABLE IF EXISTS `title`;
DROP TABLE IF EXISTS `title_type`;
DROP TABLE IF EXISTS `role`;
DROP TABLE IF EXISTS `region`;
DROP TABLE IF EXISTS `language`;
DROP TABLE IF EXISTS `genre`;
DROP TABLE IF EXISTS `content_type`;
DROP TABLE IF EXISTS `category`;

-- -----------------------------------------------

CREATE TABLE IF NOT EXISTS `category` (
  `CATEGORY_ID` INT NOT NULL,
  `CATEGORY_NAME` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`CATEGORY_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/category.csv'
INTO TABLE `category`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @CATEGORY_ID, @CATEGORY_NAME
)
SET
  `CATEGORY_ID` = NULLIF(@CATEGORY_ID, ''),
  `CATEGORY_NAME` = NULLIF(@CATEGORY_NAME, '');

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `content_type` (
  `CONTENT_TYPE_ID` INT NOT NULL,
  `CONTENT_TYPE_NAME` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`CONTENT_TYPE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/content_type.csv'
INTO TABLE `content_type`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @CONTENT_TYPE_ID, @CONTENT_TYPE_NAME
)
SET
  `CONTENT_TYPE_ID` = NULLIF(@CONTENT_TYPE_ID, ''),
  `CONTENT_TYPE_NAME` = NULLIF(@CONTENT_TYPE_NAME, '');

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `genre` (
  `GENRE_ID` INT NOT NULL,
  `GENRE_NAME` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`GENRE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/genre.csv'
INTO TABLE `genre`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @GENRE_ID, @GENRE_NAME
)
SET
  `GENRE_ID` = NULLIF(@GENRE_ID, ''),
  `GENRE_NAME` = NULLIF(@GENRE_NAME, '');

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `language` (
  `LANGUAGE_ID` VARCHAR(10) NOT NULL,
  `LANGUAGE_NAME` VARCHAR(100),
  PRIMARY KEY (`LANGUAGE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/language.csv'
INTO TABLE `language`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @LANGUAGE_ID, @LANGUAGE_NAME
)
SET
  `LANGUAGE_ID` = NULLIF(@LANGUAGE_ID, ''),
  `LANGUAGE_NAME` = NULLIF(@LANGUAGE_NAME, '');

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `region` (
  `REGION_ID` VARCHAR(10) NOT NULL,
  `REGION_NAME` VARCHAR(100),
  PRIMARY KEY (`REGION_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/region.csv'
INTO TABLE `region`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @REGION_ID, @REGION_NAME
)
SET
  `REGION_ID` = NULLIF(@REGION_ID, ''),
  `REGION_NAME` = NULLIF(@REGION_NAME, '');

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `role` (
  `ROLE_ID` INT NOT NULL,
  `ROLE_NAME` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`ROLE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/role.csv'
INTO TABLE `role`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @ROLE_ID, @ROLE_NAME
)
SET
  `ROLE_ID` = NULLIF(@ROLE_ID, ''),
  `ROLE_NAME` = NULLIF(@ROLE_NAME, '');

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `title_type` (
  `TITLE_TYPE_ID` INT NOT NULL,
  `TITLE_TYPE_NAME` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`TITLE_TYPE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/title_type.csv'
INTO TABLE `title_type`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TITLE_TYPE_ID, @TITLE_TYPE_NAME
)
SET
  `TITLE_TYPE_ID` = NULLIF(@TITLE_TYPE_ID, ''),
  `TITLE_TYPE_NAME` = NULLIF(@TITLE_TYPE_NAME, '');

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `title` (
  `TITLE_ID` VARCHAR(20) NOT NULL,
  `CONTENT_TYPE_ID` INT NOT NULL,
  `PRIMARY_TITLE` VARCHAR(500) NOT NULL,
  `ORIGINAL_TITLE` VARCHAR(500),
  `IS_ADULT` INT,
  `START_YEAR` INT,
  `END_YEAR` INT,
  `RUNTIME_MINUTES` INT,
  PRIMARY KEY (`TITLE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/title.csv'
INTO TABLE `title`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TITLE_ID, @CONTENT_TYPE_ID, @PRIMARY_TITLE, @ORIGINAL_TITLE,
  @IS_ADULT, @START_YEAR, @END_YEAR, @RUNTIME_MINUTES
)
SET
  `TITLE_ID` = NULLIF(@TITLE_ID, ''),
  `CONTENT_TYPE_ID` = NULLIF(@CONTENT_TYPE_ID, ''),
  `PRIMARY_TITLE` = NULLIF(@PRIMARY_TITLE, ''),
  `ORIGINAL_TITLE` = NULLIF(@ORIGINAL_TITLE, ''),
  `IS_ADULT` = NULLIF(@IS_ADULT, ''),
  `START_YEAR` = NULLIF(@START_YEAR, ''),
  `END_YEAR` = NULLIF(@END_YEAR, ''),
  `RUNTIME_MINUTES` = NULLIF(@RUNTIME_MINUTES, '');

ALTER TABLE `title`
ADD FOREIGN KEY (`CONTENT_TYPE_ID`)
REFERENCES `content_type`(`CONTENT_TYPE_ID`);

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `talent` (
  `TALENT_ID` VARCHAR(20) NOT NULL,
  `TALENT_NAME` VARCHAR(500) NOT NULL,
  `BIRTH_YEAR` INT,
  `DEATH_YEAR` INT,
  PRIMARY KEY (`TALENT_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/talent.csv'
INTO TABLE `talent`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TALENT_ID, @TALENT_NAME, @BIRTH_YEAR, @DEATH_YEAR
)
SET
  `TALENT_ID` = NULLIF(@TALENT_ID, ''),
  `TALENT_NAME` = NULLIF(@TALENT_NAME, ''),
  `BIRTH_YEAR` = NULLIF(@BIRTH_YEAR, ''),
  `DEATH_YEAR` = NULLIF(@DEATH_YEAR, '');

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `talent_role` (
  `TALENT_ID` VARCHAR(20) NOT NULL,
  `ROLE_ID` INT NOT NULL,
  `ORD` INT NOT NULL,
  PRIMARY KEY (`TALENT_ID`, `ROLE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/talent_role.csv'
INTO TABLE `talent_role`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TALENT_ID, @ROLE_ID, @ORD
)
SET
  `TALENT_ID` = NULLIF(@TALENT_ID, ''),
  `ROLE_ID` = NULLIF(@ROLE_ID, ''),
  `ORD` = NULLIF(@ORD, '');

ALTER TABLE `talent_role`
ADD FOREIGN KEY (`TALENT_ID`)
REFERENCES `talent`(`TALENT_ID`);

ALTER TABLE `talent_role`
ADD FOREIGN KEY (`ROLE_ID`)
REFERENCES `role`(`ROLE_ID`);

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `talent_title` (
  `TALENT_ID` VARCHAR(20) NOT NULL,
  `TITLE_ID` VARCHAR(20) NOT NULL,
  PRIMARY KEY (`TALENT_ID`, `TITLE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/talent_title.csv'
INTO TABLE `talent_title`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TALENT_ID, @TITLE_ID
)
SET
  `TALENT_ID` = NULLIF(@TALENT_ID, ''),
  `TITLE_ID` = NULLIF(@TITLE_ID, '');

ALTER TABLE `talent_title`
ADD FOREIGN KEY (`TALENT_ID`)
REFERENCES `talent`(`TALENT_ID`);

ALTER TABLE `talent_title`
ADD FOREIGN KEY (`TITLE_ID`)
REFERENCES `title`(`TITLE_ID`);

CREATE INDEX `tal_ttl_title_id_idx` ON `talent_title`(`TITLE_ID`);

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `title_aka` (
  `TITLE_ID` VARCHAR(20) NOT NULL,
  `ORD` INT NOT NULL,
  `AKA_TITLE` VARCHAR(500) NOT NULL,
  `REGION_ID` VARCHAR(10),
  `LANGUAGE_ID` VARCHAR(10),
  `ADDITIONAL_ATTRS` VARCHAR(500),
  `IS_ORIGINAL_TITLE` INT,
  PRIMARY KEY (`TITLE_ID`, `ORD`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/title_aka.csv'
INTO TABLE `title_aka`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TITLE_ID, @ORD, @AKA_TITLE, @REGION_ID,
  @LANGUAGE_ID, @ADDITIONAL_ATTRS, @IS_ORIGINAL_TITLE
)
SET
  `TITLE_ID` = NULLIF(@TITLE_ID, ''),
  `ORD` = NULLIF(@ORD, ''),
  `AKA_TITLE` = NULLIF(@AKA_TITLE, ''),
  `REGION_ID` = NULLIF(@REGION_ID, ''),
  `LANGUAGE_ID` = NULLIF(@LANGUAGE_ID, ''),
  `ADDITIONAL_ATTRS` = NULLIF(@ADDITIONAL_ATTRS, ''),
  `IS_ORIGINAL_TITLE` = NULLIF(@IS_ORIGINAL_TITLE, '');

ALTER TABLE `title_aka`
ADD FOREIGN KEY (`REGION_ID`)
REFERENCES `region`(`REGION_ID`);

ALTER TABLE `title_aka`
ADD FOREIGN KEY (`LANGUAGE_ID`)
REFERENCES `language`(`LANGUAGE_ID`);

ALTER TABLE `title_aka`
ADD FOREIGN KEY (`TITLE_ID`)
REFERENCES `title`(`TITLE_ID`);

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `title_genre` (
  `TITLE_ID` VARCHAR(20) NOT NULL,
  `GENRE_ID` INT NOT NULL,
  `ORD` INT NOT NULL,
  PRIMARY KEY (`TITLE_ID`, `GENRE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/title_genre.csv'
INTO TABLE `title_genre`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TITLE_ID, @GENRE_ID, @ORD
)
SET
  `TITLE_ID` = NULLIF(@TITLE_ID, ''),
  `GENRE_ID` = NULLIF(@GENRE_ID, ''),
  `ORD` = NULLIF(@ORD, '');

ALTER TABLE `title_genre`
ADD FOREIGN KEY (`TITLE_ID`)
REFERENCES `title`(`TITLE_ID`);

ALTER TABLE `title_genre`
ADD FOREIGN KEY (`GENRE_ID`)
REFERENCES `genre`(`GENRE_ID`);

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `title_principal_raw` (
  `TITLE_ID` VARCHAR(20) NOT NULL,
  `TALENT_ID` VARCHAR(20) NOT NULL,
  `ORD` INT NOT NULL,
  `CATEGORY_ID` INT NOT NULL,
  `JOB` VARCHAR(1000),
  `ROLE_NAMES` VARCHAR(2000),
  PRIMARY KEY (`TITLE_ID`, `TALENT_ID`, `ORD`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/title_principal.csv'
INTO TABLE `title_principal_raw`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TITLE_ID, @TALENT_ID, @ORD, @CATEGORY_ID, @JOB, @ROLE_NAMES
)
SET
  `TITLE_ID` = NULLIF(@TITLE_ID, ''),
  `TALENT_ID` = NULLIF(@TALENT_ID, ''),
  `ORD` = NULLIF(@ORD, ''),
  `CATEGORY_ID` = NULLIF(@CATEGORY_ID, ''),
  `JOB` = NULLIF(@JOB, ''),
  `ROLE_NAMES` = NULLIF(@ROLE_NAMES, '');

CREATE TABLE IF NOT EXISTS `title_principal` (
  `TITLE_ID` VARCHAR(20) NOT NULL,
  `TALENT_ID` VARCHAR(20) NOT NULL,
  `ORD` INT NOT NULL,
  `CATEGORY_ID` INT NOT NULL,
  `JOB` VARCHAR(1000),
  PRIMARY KEY (`TITLE_ID`, `TALENT_ID`, `ORD`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `title_principal` (`TITLE_ID`, `TALENT_ID`, `ORD`, `CATEGORY_ID`, `JOB`)
SELECT `TITLE_ID`, `TALENT_ID`, `ORD`, `CATEGORY_ID`, `JOB`
FROM `title_principal_raw`;

CREATE INDEX `ttl_prin_tal_id_idx` ON `title_principal`(`TALENT_ID`);
CREATE INDEX `ttl_prin_cat_id_idx` ON `title_principal`(`CATEGORY_ID`);

-- remove any rows where the title or talent is missing
DELETE tp
FROM `title_principal` tp
LEFT JOIN `talent` t
  ON tp.`TALENT_ID` = t.`TALENT_ID`
WHERE t.`TALENT_ID` IS NULL;

ALTER TABLE `title_principal`
ADD FOREIGN KEY (`TITLE_ID`)
REFERENCES `title`(`TITLE_ID`);

ALTER TABLE `title_principal`
ADD FOREIGN KEY (`TALENT_ID`)
REFERENCES `talent`(`TALENT_ID`);

ALTER TABLE `title_principal`
ADD FOREIGN KEY (`CATEGORY_ID`)
REFERENCES `category`(`CATEGORY_ID`);

CREATE TABLE IF NOT EXISTS `principal_role` (
  `TITLE_ID` VARCHAR(20) NOT NULL,
  `TALENT_ID` VARCHAR(20) NOT NULL,
  `ORD` INT NOT NULL,
  `ROLE_NAME` VARCHAR(255) NOT NULL,
  PRIMARY KEY (`TITLE_ID`, `TALENT_ID`, `ORD`, `ROLE_NAME`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `principal_role` (`TITLE_ID`, `TALENT_ID`, `ORD`, `ROLE_NAME`)
SELECT DISTINCT
  r.`TITLE_ID`,
  r.`TALENT_ID`,
  r.`ORD`,
  TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(r.`ROLE_NAMES`, ',', numbers.n), ',', -1)) AS `ROLE_NAME`
FROM `title_principal_raw` r
JOIN `title_principal` tp
  ON r.`TITLE_ID` = tp.`TITLE_ID`
 AND r.`TALENT_ID` = tp.`TALENT_ID`
 AND r.`ORD` = tp.`ORD`
JOIN (
  SELECT 1 AS n UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
  UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
) numbers
  ON CHAR_LENGTH(r.`ROLE_NAMES`) - CHAR_LENGTH(REPLACE(r.`ROLE_NAMES`, ',', '')) >= numbers.n - 1
WHERE r.`ROLE_NAMES` IS NOT NULL
  AND TRIM(r.`ROLE_NAMES`) <> ''
  AND TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(r.`ROLE_NAMES`, ',', numbers.n), ',', -1)) <> '';

ALTER TABLE `principal_role`
ADD FOREIGN KEY (`TITLE_ID`, `TALENT_ID`, `ORD`)
REFERENCES `title_principal`(`TITLE_ID`, `TALENT_ID`, `ORD`);

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `title_aka_title_type` (
  `TITLE_ID` VARCHAR(20) NOT NULL,
  `TITLE_TYPE_ID` INT NOT NULL,
  `ORD` INT NOT NULL,
  PRIMARY KEY (`TITLE_ID`, `TITLE_TYPE_ID`, `ORD`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/title_aka_title_type.csv'
INTO TABLE `title_aka_title_type`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TITLE_ID, @TITLE_TYPE_ID, @ORD
)
SET
  `TITLE_ID` = NULLIF(@TITLE_ID, ''),
  `TITLE_TYPE_ID` = NULLIF(@TITLE_TYPE_ID, ''),
  `ORD` = NULLIF(@ORD, '');

ALTER TABLE `title_aka_title_type`
ADD FOREIGN KEY (`TITLE_TYPE_ID`)
REFERENCES `title_type`(`TITLE_TYPE_ID`);

ALTER TABLE `title_aka_title_type`
ADD FOREIGN KEY (`TITLE_ID`, `ORD`)
REFERENCES `title_aka`(`TITLE_ID`, `ORD`);

-- ------------------------------------------------

CREATE TABLE IF NOT EXISTS `title_episode` (
  `TITLE_ID` VARCHAR(20) NOT NULL,
  `PARENT_TITLE_ID` VARCHAR(20),
  `SEASON_NUMBER` INT,
  `EPISODE_NUMBER` INT,
  PRIMARY KEY (`TITLE_ID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

LOAD DATA INFILE '/var/lib/mysql-files/title_episode.csv'
INTO TABLE `title_episode`
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
  @TITLE_ID, @PARENT_TITLE_ID, @SEASON_NUMBER, @EPISODE_NUMBER
)
SET
  `TITLE_ID` = NULLIF(@TITLE_ID, ''),
  `PARENT_TITLE_ID` = NULLIF(@PARENT_TITLE_ID, ''),
  `SEASON_NUMBER` = NULLIF(@SEASON_NUMBER, ''),
  `EPISODE_NUMBER` = NULLIF(@EPISODE_NUMBER, '');

ALTER TABLE `title_episode`
ADD FOREIGN KEY (`TITLE_ID`)
REFERENCES `title`(`TITLE_ID`);

ALTER TABLE `title_episode`
ADD FOREIGN KEY (`PARENT_TITLE_ID`)
REFERENCES `title`(`TITLE_ID`);

CREATE INDEX `ttl_epi_par_idx` ON `title_episode`(`PARENT_TITLE_ID`);

-- ------------------------------------------------

-- fill in some gaps not provided in the source data. These
-- are rough mappings and may not be 100% accurate. Suitable
-- only for demos and testing, NOT for production use.

UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Basque' WHERE `LANGUAGE_ID` = 'eu';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Kurdish' WHERE `LANGUAGE_ID` = 'ku';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Sindhi' WHERE `LANGUAGE_ID` = 'sd';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Erzya' WHERE `LANGUAGE_ID` = 'myv';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'private usage' WHERE `LANGUAGE_ID` = 'qbp';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Zulu' WHERE `LANGUAGE_ID` = 'zu';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Punjabi' WHERE `LANGUAGE_ID` = 'pa';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Latin' WHERE `LANGUAGE_ID` = 'la';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Italian' WHERE `LANGUAGE_ID` = 'it';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Yiddish' WHERE `LANGUAGE_ID` = 'yi';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Armenian' WHERE `LANGUAGE_ID` = 'hy';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Mongolian' WHERE `LANGUAGE_ID` = 'mn';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Malay' WHERE `LANGUAGE_ID` = 'ms';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Estonian' WHERE `LANGUAGE_ID` = 'et';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Welsh' WHERE `LANGUAGE_ID` = 'cy';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Kannada' WHERE `LANGUAGE_ID` = 'kn';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Chinese' WHERE `LANGUAGE_ID` = 'zh';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Cree' WHERE `LANGUAGE_ID` = 'cr';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Hawaiian' WHERE `LANGUAGE_ID` = 'haw';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Croatian' WHERE `LANGUAGE_ID` = 'hr';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Azerbaijani' WHERE `LANGUAGE_ID` = 'az';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Inuktitut' WHERE `LANGUAGE_ID` = 'iu';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Tamil' WHERE `LANGUAGE_ID` = 'ta';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Catalan' WHERE `LANGUAGE_ID` = 'ca';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Macedonian' WHERE `LANGUAGE_ID` = 'mk';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Sesotho' WHERE `LANGUAGE_ID` = 'st';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Burmese' WHERE `LANGUAGE_ID` = 'my';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Albanian' WHERE `LANGUAGE_ID` = 'sq';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Hungarian' WHERE `LANGUAGE_ID` = 'hu';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Wolof' WHERE `LANGUAGE_ID` = 'wo';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Danish' WHERE `LANGUAGE_ID` = 'da';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Gujarati' WHERE `LANGUAGE_ID` = 'gu';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Swedish' WHERE `LANGUAGE_ID` = 'sv';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Georgian' WHERE `LANGUAGE_ID` = 'ka';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Icelandic' WHERE `LANGUAGE_ID` = 'is';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Byelorussian' WHERE `LANGUAGE_ID` = 'be';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Turkish' WHERE `LANGUAGE_ID` = 'tr';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Russian' WHERE `LANGUAGE_ID` = 'ru';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Mandarin Chinese' WHERE `LANGUAGE_ID` = 'cmn';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'French' WHERE `LANGUAGE_ID` = 'fr';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Malayalam' WHERE `LANGUAGE_ID` = 'ml';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Thai' WHERE `LANGUAGE_ID` = 'th';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Tajik' WHERE `LANGUAGE_ID` = 'tg';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Norwegian' WHERE `LANGUAGE_ID` = 'no';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Latvian, Lettish' WHERE `LANGUAGE_ID` = 'lv';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Spanish' WHERE `LANGUAGE_ID` = 'es';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Korean' WHERE `LANGUAGE_ID` = 'ko';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Lithuanian' WHERE `LANGUAGE_ID` = 'lt';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Serbian' WHERE `LANGUAGE_ID` = 'sr';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Rhaeto-Romance' WHERE `LANGUAGE_ID` = 'rm';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Galician' WHERE `LANGUAGE_ID` = 'gl';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Dutch' WHERE `LANGUAGE_ID` = 'nl';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Czech' WHERE `LANGUAGE_ID` = 'cs';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Laothian' WHERE `LANGUAGE_ID` = 'lo';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Kazakh' WHERE `LANGUAGE_ID` = 'kk';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Japanese' WHERE `LANGUAGE_ID` = 'ja';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Persian' WHERE `LANGUAGE_ID` = 'fa';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Pashto, Pushto' WHERE `LANGUAGE_ID` = 'ps';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Swiss German' WHERE `LANGUAGE_ID` = 'gsw';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Tegulu' WHERE `LANGUAGE_ID` = 'te';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Xhosa' WHERE `LANGUAGE_ID` = 'xh';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Bengali, Bangla' WHERE `LANGUAGE_ID` = 'bn';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Gaelic' WHERE `LANGUAGE_ID` = 'gd';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Dari' WHERE `LANGUAGE_ID` = 'prs';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Urdu' WHERE `LANGUAGE_ID` = 'ur';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Greek' WHERE `LANGUAGE_ID` = 'el';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Afrikaans' WHERE `LANGUAGE_ID` = 'af';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Finnish' WHERE `LANGUAGE_ID` = 'fi';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'private usage' WHERE `LANGUAGE_ID` = 'qac';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Kirghiz' WHERE `LANGUAGE_ID` = 'ky';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Slovenian' WHERE `LANGUAGE_ID` = 'sl';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Hindi' WHERE `LANGUAGE_ID` = 'hi';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'N''Ko' WHERE `LANGUAGE_ID` = 'nqo';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Uzbek' WHERE `LANGUAGE_ID` = 'uz';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'German' WHERE `LANGUAGE_ID` = 'de';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Hebrew' WHERE `LANGUAGE_ID` = 'he';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Marathi' WHERE `LANGUAGE_ID` = 'mr';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Polish' WHERE `LANGUAGE_ID` = 'pl';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Arabic' WHERE `LANGUAGE_ID` = 'ar';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Setswana' WHERE `LANGUAGE_ID` = 'tn';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Cantonese' WHERE `LANGUAGE_ID` = 'yue';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Bosnian' WHERE `LANGUAGE_ID` = 'bs';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Irish' WHERE `LANGUAGE_ID` = 'ga';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Maori' WHERE `LANGUAGE_ID` = 'mi';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Amharic' WHERE `LANGUAGE_ID` = 'am';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Portuguese' WHERE `LANGUAGE_ID` = 'pt';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Ukrainian' WHERE `LANGUAGE_ID` = 'uk';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Kirundi' WHERE `LANGUAGE_ID` = 'rn';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Tagalog' WHERE `LANGUAGE_ID` = 'tl';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'English' WHERE `LANGUAGE_ID` = 'en';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Indonesian' WHERE `LANGUAGE_ID` = 'id';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'private usage' WHERE `LANGUAGE_ID` = 'qal';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Old French' WHERE `LANGUAGE_ID` = 'fro';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Old High German' WHERE `LANGUAGE_ID` = 'goh';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Bulgarian' WHERE `LANGUAGE_ID` = 'bg';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'private usage' WHERE `LANGUAGE_ID` = 'qbn';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'private usage' WHERE `LANGUAGE_ID` = 'qbo';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Romanian' WHERE `LANGUAGE_ID` = 'ro';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Vietnamese' WHERE `LANGUAGE_ID` = 'vi';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Nepali' WHERE `LANGUAGE_ID` = 'ne';
UPDATE `imdb`.`language` SET `LANGUAGE_NAME` = 'Slovak' WHERE `LANGUAGE_ID` = 'sk';

-- ------------------------------------------------

UPDATE `imdb`.`region` SET `REGION_NAME` = 'United Kingdom' WHERE `REGION_ID` = 'GB';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Bhutan' WHERE `REGION_ID` = 'BT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Iran' WHERE `REGION_ID` = 'IR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Cyprus' WHERE `REGION_ID` = 'CY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Benin' WHERE `REGION_ID` = 'BJ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Malta' WHERE `REGION_ID` = 'MT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Bermuda' WHERE `REGION_ID` = 'BM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Pakistan' WHERE `REGION_ID` = 'PK';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Gambia' WHERE `REGION_ID` = 'GM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Belize' WHERE `REGION_ID` = 'BZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'United Arab Emirates' WHERE `REGION_ID` = 'AE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Madagascar' WHERE `REGION_ID` = 'MG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Peru' WHERE `REGION_ID` = 'PE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Moldova' WHERE `REGION_ID` = 'MD';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Slovenia' WHERE `REGION_ID` = 'SI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XSA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Côte d''Ivoire' WHERE `REGION_ID` = 'CI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Rwanda' WHERE `REGION_ID` = 'RW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Canada' WHERE `REGION_ID` = 'CA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Congo' WHERE `REGION_ID` = 'CG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Bolivia' WHERE `REGION_ID` = 'BO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Kuwait' WHERE `REGION_ID` = 'KW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XWW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Syrian Arab Republic' WHERE `REGION_ID` = 'SY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Northern Mariana Islands' WHERE `REGION_ID` = 'MP';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Equatorial Guinea' WHERE `REGION_ID` = 'GQ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Iceland' WHERE `REGION_ID` = 'IS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Switzerland' WHERE `REGION_ID` = 'CH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Republic of North Macedonia' WHERE `REGION_ID` = 'MK';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Honduras' WHERE `REGION_ID` = 'HN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Guam' WHERE `REGION_ID` = 'GU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'China' WHERE `REGION_ID` = 'CN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Eswatini' WHERE `REGION_ID` = 'SZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Comoros' WHERE `REGION_ID` = 'KM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Palau' WHERE `REGION_ID` = 'PW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Uruguay' WHERE `REGION_ID` = 'UY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Morocco' WHERE `REGION_ID` = 'MA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Senegal' WHERE `REGION_ID` = 'SN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Croatia' WHERE `REGION_ID` = 'HR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Argentina' WHERE `REGION_ID` = 'AR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Niger' WHERE `REGION_ID` = 'NE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Niue' WHERE `REGION_ID` = 'NU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Zimbabwe' WHERE `REGION_ID` = 'ZW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Montserrat' WHERE `REGION_ID` = 'MS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'United States of America' WHERE `REGION_ID` = 'US';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XKV';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Vanuatu' WHERE `REGION_ID` = 'VU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Zambia' WHERE `REGION_ID` = 'ZM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Cayman Islands' WHERE `REGION_ID` = 'KY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Macao' WHERE `REGION_ID` = 'MO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Eritrea' WHERE `REGION_ID` = 'ER';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Marshall Islands' WHERE `REGION_ID` = 'MH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Thailand' WHERE `REGION_ID` = 'TH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Sao Tome and Principe' WHERE `REGION_ID` = 'ST';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Gabon' WHERE `REGION_ID` = 'GA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Austria' WHERE `REGION_ID` = 'AT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Djibouti' WHERE `REGION_ID` = 'DJ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Germany' WHERE `REGION_ID` = 'DE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Palestine' WHERE `REGION_ID` = 'PS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Venezuela' WHERE `REGION_ID` = 'VE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Finland' WHERE `REGION_ID` = 'FI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Japan' WHERE `REGION_ID` = 'JP';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'SUHH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Hong Kong' WHERE `REGION_ID` = 'HK';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Greenland' WHERE `REGION_ID` = 'GL';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Seychelles' WHERE `REGION_ID` = 'SC';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Nepal' WHERE `REGION_ID` = 'NP';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'American Samoa' WHERE `REGION_ID` = 'AS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Virgin Islands (U.K.)' WHERE `REGION_ID` = 'VG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XAU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Tuvalu' WHERE `REGION_ID` = 'TV';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Guatemala' WHERE `REGION_ID` = 'GT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XSI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Myanmar' WHERE `REGION_ID` = 'MM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Solomon Islands' WHERE `REGION_ID` = 'SB';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Guinea' WHERE `REGION_ID` = 'GN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Russian Federation' WHERE `REGION_ID` = 'RU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Tajikistan' WHERE `REGION_ID` = 'TJ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Algeria' WHERE `REGION_ID` = 'DZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Cook Islands' WHERE `REGION_ID` = 'CK';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Kiribati' WHERE `REGION_ID` = 'KI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Indonesia' WHERE `REGION_ID` = 'ID';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'North Korea' WHERE `REGION_ID` = 'KP';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Grenada' WHERE `REGION_ID` = 'GD';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Gibraltar' WHERE `REGION_ID` = 'GI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Bosnia and Herzegovina' WHERE `REGION_ID` = 'BA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Cuba' WHERE `REGION_ID` = 'CU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Sri Lanka' WHERE `REGION_ID` = 'LK';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Wallis and Futuna' WHERE `REGION_ID` = 'WF';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Bahamas' WHERE `REGION_ID` = 'BS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XAS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Liechtenstein' WHERE `REGION_ID` = 'LI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Cabo Verde' WHERE `REGION_ID` = 'CV';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Timor-Leste' WHERE `REGION_ID` = 'TL';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XWG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Kyrgyzstan' WHERE `REGION_ID` = 'KG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Trinidad and Tobago' WHERE `REGION_ID` = 'TT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Mozambique' WHERE `REGION_ID` = 'MZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Saint Vincent and the Grenadines' WHERE `REGION_ID` = 'VC';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Ethiopia' WHERE `REGION_ID` = 'ET';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Bulgaria' WHERE `REGION_ID` = 'BG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Australia' WHERE `REGION_ID` = 'AU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Haiti' WHERE `REGION_ID` = 'HT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Papua New Guinea' WHERE `REGION_ID` = 'PG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Botswana' WHERE `REGION_ID` = 'BW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Ecuador' WHERE `REGION_ID` = 'EC';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Monaco' WHERE `REGION_ID` = 'MC';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Guinea-Bissau' WHERE `REGION_ID` = 'GW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Mali' WHERE `REGION_ID` = 'ML';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'South Korea' WHERE `REGION_ID` = 'KR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'VDVN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Oman' WHERE `REGION_ID` = 'OM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'ZRCD';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Aruba' WHERE `REGION_ID` = 'AW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'New Caledonia' WHERE `REGION_ID` = 'NC';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Italy' WHERE `REGION_ID` = 'IT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'CSHH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Hungary' WHERE `REGION_ID` = 'HU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Spain' WHERE `REGION_ID` = 'ES';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Israel' WHERE `REGION_ID` = 'IL';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'France' WHERE `REGION_ID` = 'FR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Namibia' WHERE `REGION_ID` = 'NA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XNA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Somalia' WHERE `REGION_ID` = 'SO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Chile' WHERE `REGION_ID` = 'CL';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Andorra' WHERE `REGION_ID` = 'AD';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'French Polynesia' WHERE `REGION_ID` = 'PF';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Nicaragua' WHERE `REGION_ID` = 'NI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Sudan' WHERE `REGION_ID` = 'SD';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Chad' WHERE `REGION_ID` = 'TD';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Barbados' WHERE `REGION_ID` = 'BB';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Portugal' WHERE `REGION_ID` = 'PT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'BUMM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Luxembourg' WHERE `REGION_ID` = 'LU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Singapore' WHERE `REGION_ID` = 'SG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Mauritius' WHERE `REGION_ID` = 'MU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Yemen' WHERE `REGION_ID` = 'YE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Dominica' WHERE `REGION_ID` = 'DM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Jersey' WHERE `REGION_ID` = 'JE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Colombia' WHERE `REGION_ID` = 'CO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Ghana' WHERE `REGION_ID` = 'GH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XYU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Sierra Leone' WHERE `REGION_ID` = 'SL';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Mexico' WHERE `REGION_ID` = 'MX';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XKO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Jamaica' WHERE `REGION_ID` = 'JM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Denmark' WHERE `REGION_ID` = 'DK';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Costa Rica' WHERE `REGION_ID` = 'CR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Czechia' WHERE `REGION_ID` = 'CZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Montenegro' WHERE `REGION_ID` = 'ME';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Azerbaijan' WHERE `REGION_ID` = 'AZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Cambodia' WHERE `REGION_ID` = 'KH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Armenia' WHERE `REGION_ID` = 'AM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Martinique' WHERE `REGION_ID` = 'MQ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Réunion' WHERE `REGION_ID` = 'RE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Norway' WHERE `REGION_ID` = 'NO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Qatar' WHERE `REGION_ID` = 'QA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Belgium' WHERE `REGION_ID` = 'BE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Angola' WHERE `REGION_ID` = 'AO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Egypt' WHERE `REGION_ID` = 'EG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Saint Kitts and Nevis' WHERE `REGION_ID` = 'KN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Nauru' WHERE `REGION_ID` = 'NR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Liberia' WHERE `REGION_ID` = 'LR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Romania' WHERE `REGION_ID` = 'RO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Saudi Arabia' WHERE `REGION_ID` = 'SA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Antarctica' WHERE `REGION_ID` = 'AQ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Afghanistan' WHERE `REGION_ID` = 'AF';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Turkey' WHERE `REGION_ID` = 'TR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Mongolia' WHERE `REGION_ID` = 'MN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Jordan' WHERE `REGION_ID` = 'JO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Saint Lucia' WHERE `REGION_ID` = 'LC';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Saint Helena' WHERE `REGION_ID` = 'SH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Georgia' WHERE `REGION_ID` = 'GE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Malaysia' WHERE `REGION_ID` = 'MY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Kazakhstan' WHERE `REGION_ID` = 'KZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Brunei Darussalam' WHERE `REGION_ID` = 'BN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Taiwan' WHERE `REGION_ID` = 'TW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Samoa' WHERE `REGION_ID` = 'WS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Belarus' WHERE `REGION_ID` = 'BY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Western Sahara' WHERE `REGION_ID` = 'EH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Burkina Faso' WHERE `REGION_ID` = 'BF';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Nigeria' WHERE `REGION_ID` = 'NG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'El Salvador' WHERE `REGION_ID` = 'SV';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Uganda' WHERE `REGION_ID` = 'UG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Burundi' WHERE `REGION_ID` = 'BI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Vatican' WHERE `REGION_ID` = 'VA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Suriname' WHERE `REGION_ID` = 'SR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Bahrain' WHERE `REGION_ID` = 'BH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Lithuania' WHERE `REGION_ID` = 'LT';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Panama' WHERE `REGION_ID` = 'PA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Laos' WHERE `REGION_ID` = 'LA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Fiji' WHERE `REGION_ID` = 'FJ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Uzbekistan' WHERE `REGION_ID` = 'UZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Serbia' WHERE `REGION_ID` = 'RS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'DDDE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Tunisia' WHERE `REGION_ID` = 'TN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Lebanon' WHERE `REGION_ID` = 'LB';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Guyana' WHERE `REGION_ID` = 'GY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Philippines' WHERE `REGION_ID` = 'PH';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Kenya' WHERE `REGION_ID` = 'KE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Guadeloupe' WHERE `REGION_ID` = 'GP';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Congo Democratic Republic' WHERE `REGION_ID` = 'CD';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Antigua and Barbuda' WHERE `REGION_ID` = 'AG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Malawi' WHERE `REGION_ID` = 'MW';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'French Guiana' WHERE `REGION_ID` = 'GF';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Puerto Rico' WHERE `REGION_ID` = 'PR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Greece' WHERE `REGION_ID` = 'GR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Brazil' WHERE `REGION_ID` = 'BR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'New Zealand' WHERE `REGION_ID` = 'NZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Cameroon' WHERE `REGION_ID` = 'CM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Togo' WHERE `REGION_ID` = 'TG';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Central African Republic' WHERE `REGION_ID` = 'CF';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Anguilla' WHERE `REGION_ID` = 'AI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'San Marino' WHERE `REGION_ID` = 'SM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'YUCS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'CSXX';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Turkmenistan' WHERE `REGION_ID` = 'TM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'India' WHERE `REGION_ID` = 'IN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Paraguay' WHERE `REGION_ID` = 'PY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Tanzania' WHERE `REGION_ID` = 'TZ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Libya' WHERE `REGION_ID` = 'LY';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Dominican Republic' WHERE `REGION_ID` = 'DO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Poland' WHERE `REGION_ID` = 'PL';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Faroe Islands' WHERE `REGION_ID` = 'FO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Albania' WHERE `REGION_ID` = 'AL';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Iraq' WHERE `REGION_ID` = 'IQ';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XEU';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Slovakia' WHERE `REGION_ID` = 'SK';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Latvia' WHERE `REGION_ID` = 'LV';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Virgin Islands (U.S.)' WHERE `REGION_ID` = 'VI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'XPI';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Sweden' WHERE `REGION_ID` = 'SE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Tonga' WHERE `REGION_ID` = 'TO';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Ukraine' WHERE `REGION_ID` = 'UA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Bangladesh' WHERE `REGION_ID` = 'BD';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'unknown' WHERE `REGION_ID` = 'AN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Netherlands' WHERE `REGION_ID` = 'NL';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Viet Nam' WHERE `REGION_ID` = 'VN';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Mauritania' WHERE `REGION_ID` = 'MR';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'South Africa' WHERE `REGION_ID` = 'ZA';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Lesotho' WHERE `REGION_ID` = 'LS';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Isle of Man' WHERE `REGION_ID` = 'IM';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Ireland' WHERE `REGION_ID` = 'IE';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Maldives' WHERE `REGION_ID` = 'MV';
UPDATE `imdb`.`region` SET `REGION_NAME` = 'Estonia' WHERE `REGION_ID` = 'EE';

-- --------------------------------------------------------------------

DROP TABLE IF EXISTS `title_principal_raw`;

-- --------------------------------------------------------------------

USE `imdb`;

SELECT 'title_aka_title_type' AS `tbl`, COUNT(*) FROM `title_aka_title_type`
UNION
SELECT 'title_principal' AS `tbl`, COUNT(*) FROM `title_principal`
UNION
SELECT 'principal_role' AS `tbl`, COUNT(*) FROM `principal_role`
UNION
SELECT 'title_genre' AS `tbl`, COUNT(*) FROM `title_genre`
UNION
SELECT 'title_aka' AS `tbl`, COUNT(*) FROM `title_aka`
UNION
SELECT 'talent_title' AS `tbl`, COUNT(*) FROM `talent_title`
UNION
SELECT 'talent_role' AS `tbl`, COUNT(*) FROM `talent_role`
UNION
SELECT 'talent' AS `tbl`, COUNT(*) FROM `talent`
UNION
SELECT 'title' AS `tbl`, COUNT(*) FROM `title`
UNION
SELECT 'title_type' AS `tbl`, COUNT(*) FROM `title_type`
UNION
SELECT 'role' AS `tbl`, COUNT(*) FROM `role`
UNION
SELECT 'region' AS `tbl`, COUNT(*) FROM `region`
UNION
SELECT 'language' AS `tbl`, COUNT(*) FROM `language`
UNION
SELECT 'genre' AS `tbl`, COUNT(*) FROM `genre`
UNION
SELECT 'content_type' AS `tbl`, COUNT(*) FROM `content_type`
UNION
SELECT 'category' AS `tbl`, COUNT(*) FROM `category`
UNION
SELECT 'title_episode' AS `tbl`, COUNT(*) FROM `title_episode`
ORDER BY 1;