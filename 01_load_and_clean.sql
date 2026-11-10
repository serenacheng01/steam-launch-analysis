-- =====================================================================
-- Steam launch analysis | 01_load_and_clean.sql
-- Load the Steam Games Dataset (Fronkon Games) into MySQL and build a
-- clean table of games with at least 50 reviews.
-- Tools: MySQL 8, DBeaver. Run each section with Option+X (whole script).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Before loading: fix the file's header (done in Terminal, not SQL)
-- ---------------------------------------------------------------------
-- The original games.csv header joins "Discount" and "DLC count" into one
-- name, so every label after Price sits one column to the left of its
-- values. The header was replaced on a copy of the file (games_fixed.csv).
-- See README.md, "How to reproduce", for the three Terminal commands.

-- ---------------------------------------------------------------------
-- 1. Create the database
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS steam_launch CHARACTER SET utf8mb4;
USE steam_launch;

-- ---------------------------------------------------------------------
-- 2. Allow loading a local file (once)
-- ---------------------------------------------------------------------
-- Also needed in DBeaver: Edit Connection > Driver properties >
-- allowLoadLocalInfile = true, then reconnect. Without both, MySQL
-- returns error 3948 ("Loading local data is disabled").
SET GLOBAL local_infile = 1;
SHOW VARIABLES LIKE 'local_infile';   -- should be ON

-- ---------------------------------------------------------------------
-- 3. Raw table: 18 columns, all stored as text for now
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS games_raw;

CREATE TABLE games_raw (
  app_id VARCHAR(20), name VARCHAR(255), release_date VARCHAR(30),
  estimated_owners VARCHAR(40), peak_ccu VARCHAR(20), price VARCHAR(20),
  metacritic_score VARCHAR(10), user_score VARCHAR(10),
  positive VARCHAR(20), negative VARCHAR(20), recommendations VARCHAR(20),
  average_playtime_forever VARCHAR(20), median_playtime_forever VARCHAR(20),
  developers VARCHAR(500), publishers VARCHAR(500),
  categories TEXT, genres TEXT, tags TEXT
) CHARACTER SET utf8mb4;

-- ---------------------------------------------------------------------
-- 4. Load the header-fixed file
-- ---------------------------------------------------------------------
-- DBeaver's CSV import wizard failed on quoted text containing commas,
-- quotes and line breaks, so the file is loaded by MySQL directly.
-- Lines end with a plain line feed: '\n' is correct ('\r\n' loads 1 row).
-- The file has 40 columns; each @d discards one the project does not use.
-- Change the path to where games_fixed.csv is saved on your computer.
TRUNCATE TABLE games_raw;

LOAD DATA LOCAL INFILE 'path/to/games_fixed.csv'
INTO TABLE games_raw
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(app_id, name, release_date, estimated_owners, peak_ccu, @d, price,
 @d, @d, @d, @d, @d, @d, @d, @d, @d, @d, @d, @d, @d,
 metacritic_score, @d, user_score, positive, negative, @d, @d,
 recommendations, @d, average_playtime_forever, @d, median_playtime_forever, @d,
 developers, publishers, categories, genres, tags, @d, @d);

SELECT COUNT(*) FROM games_raw;   -- 125,855

-- ---------------------------------------------------------------------
-- 5. Inspect the data before cleaning
-- ---------------------------------------------------------------------
-- Duplicate games? Result: none, so app_id is safe to use as the key.
SELECT app_id, COUNT(*)
FROM games_raw
GROUP BY app_id
HAVING COUNT(*) > 1;

-- How are release dates written? Result: like "Oct 23, 2025".
SELECT release_date, COUNT(*)
FROM games_raw
GROUP BY release_date
ORDER BY COUNT(*) DESC
LIMIT 30;

-- Games with no reviews. Result: 42,899 (34%), including unreleased listings.
SELECT COUNT(*)
FROM games_raw
WHERE CAST(positive AS UNSIGNED) + CAST(negative AS UNSIGNED) = 0;

-- Free games. Result: 26,661 (21%).
SELECT COUNT(*)
FROM games_raw
WHERE CAST(price AS DECIMAL(8,2)) = 0;

-- Owner ranges. Result: about 80% under 20,000 owners; 1,354 above 1 million.
SELECT estimated_owners, COUNT(*)
FROM games_raw
GROUP BY estimated_owners
ORDER BY COUNT(*) DESC;

-- Any release dates that do not match "Mon DD, YYYY"? Result: none.
SELECT release_date, COUNT(*)
FROM games_raw
WHERE release_date NOT REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$'
GROUP BY release_date
ORDER BY COUNT(*) DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- 6. Clean table: typed columns, games with 50+ reviews only
-- ---------------------------------------------------------------------
-- A 100% score from three reviews means little, so only games with at
-- least 50 reviews are kept. The date guard converts only well-formed
-- dates, since one bad date can stop the whole statement in strict mode.
DROP TABLE IF EXISTS games_clean;

CREATE TABLE games_clean AS
SELECT
  CAST(app_id AS UNSIGNED) AS app_id,
  name,
  CASE WHEN release_date REGEXP '^[A-Za-z]{3} [0-9]{1,2}, [0-9]{4}$'
       THEN STR_TO_DATE(release_date, '%b %d, %Y') END AS release_date,
  CAST(price AS DECIMAL(8,2)) AS price_usd,
  CAST(SUBSTRING_INDEX(estimated_owners, ' - ', 1) AS UNSIGNED) AS owners_low,
  CAST(positive AS UNSIGNED) AS positive,
  CAST(negative AS UNSIGNED) AS negative,
  CAST(positive AS UNSIGNED) + CAST(negative AS UNSIGNED) AS total_reviews,
  ROUND(100 * CAST(positive AS UNSIGNED) /
        NULLIF(CAST(positive AS UNSIGNED) + CAST(negative AS UNSIGNED), 0), 1) AS positive_pct,
  CAST(average_playtime_forever AS UNSIGNED) AS avg_playtime_mins,
  genres, tags, categories, developers, publishers
FROM games_raw
WHERE CAST(positive AS UNSIGNED) + CAST(negative AS UNSIGNED) >= 50;

SELECT COUNT(*) FROM games_clean;                             -- 30,624 (24% of all listings)
SELECT COUNT(*) FROM games_clean WHERE release_date IS NULL;  -- 0
