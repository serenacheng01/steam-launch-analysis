-- =====================================================================
-- Steam launch analysis | 02_build_tables.sql
-- Split the clean data into three related tables:
--   games        one row per game (primary key app_id)
--   game_genres  one row per game and genre (links to games)
--   game_tags    one row per game and tag (links to games)
-- Genres and tags arrive as comma-separated text in one cell, which
-- cannot be counted or compared until they are split into rows.
-- Requires MySQL 8 or later (JSON_TABLE).
-- =====================================================================

USE steam_launch;

SELECT VERSION();   -- must be 8.0 or later

-- ---------------------------------------------------------------------
-- 1. games: one row per game, with release year, month and price band
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS game_tags;
DROP TABLE IF EXISTS game_genres;
DROP TABLE IF EXISTS games;

CREATE TABLE games (
  app_id INT UNSIGNED PRIMARY KEY,
  name VARCHAR(255),
  release_date DATE,
  release_year SMALLINT,
  release_month TINYINT,
  price_usd DECIMAL(8,2),
  price_band VARCHAR(20),
  owners_low INT UNSIGNED,
  positive INT UNSIGNED,
  negative INT UNSIGNED,
  total_reviews INT UNSIGNED,
  positive_pct DECIMAL(4,1),
  avg_playtime_mins INT UNSIGNED
);

INSERT INTO games
SELECT app_id, name, release_date, YEAR(release_date), MONTH(release_date),
  price_usd,
  CASE WHEN price_usd = 0  THEN '1 Free'
       WHEN price_usd < 5  THEN '2 Under $5'
       WHEN price_usd < 10 THEN '3 $5 to $9.99'
       WHEN price_usd < 20 THEN '4 $10 to $19.99'
       WHEN price_usd < 30 THEN '5 $20 to $29.99'
       ELSE '6 $30 and over' END,
  owners_low, positive, negative, total_reviews, positive_pct, avg_playtime_mins
FROM games_clean
WHERE release_date IS NOT NULL;

SELECT COUNT(*) FROM games;   -- 30,624

-- ---------------------------------------------------------------------
-- 2. game_genres: split the genres text into one row per genre
-- ---------------------------------------------------------------------
CREATE TABLE game_genres (
  app_id INT UNSIGNED,
  genre VARCHAR(60),
  PRIMARY KEY (app_id, genre),
  FOREIGN KEY (app_id) REFERENCES games(app_id)
);

INSERT INTO game_genres
SELECT DISTINCT c.app_id, TRIM(j.genre)
FROM games_clean c
JOIN games g ON g.app_id = c.app_id,
JSON_TABLE(CONCAT('["', REPLACE(c.genres, ',', '","'), '"]'),
           '$[*]' COLUMNS (genre VARCHAR(60) PATH '$')) j
WHERE c.genres IS NOT NULL AND c.genres <> '';

-- ---------------------------------------------------------------------
-- 3. game_tags: the same split for tags (wider column for long names)
-- ---------------------------------------------------------------------
CREATE TABLE game_tags (
  app_id INT UNSIGNED,
  tag VARCHAR(100),
  PRIMARY KEY (app_id, tag),
  FOREIGN KEY (app_id) REFERENCES games(app_id)
);

INSERT INTO game_tags
SELECT DISTINCT c.app_id, TRIM(j.tag)
FROM games_clean c
JOIN games g ON g.app_id = c.app_id,
JSON_TABLE(CONCAT('["', REPLACE(c.tags, ',', '","'), '"]'),
           '$[*]' COLUMNS (tag VARCHAR(100) PATH '$')) j
WHERE c.tags IS NOT NULL AND c.tags <> '';

-- ---------------------------------------------------------------------
-- 4. Check the split worked
-- ---------------------------------------------------------------------
-- Expect familiar names (Action, Indie, Adventure / Singleplayer, Indie...).
SELECT genre, COUNT(*) AS games
FROM game_genres
GROUP BY genre
ORDER BY games DESC;

SELECT tag, COUNT(*) AS games
FROM game_tags
GROUP BY tag
ORDER BY games DESC
LIMIT 60;

SELECT COUNT(*) FROM game_genres;
SELECT COUNT(*) FROM game_tags;

-- The ER diagram (diagram.png in this repository) shows the three tables
-- and the links on app_id. Made in DBeaver: Files panel > Diagrams >
-- Create > New ER Diagram, with games, game_genres and game_tags ticked.
