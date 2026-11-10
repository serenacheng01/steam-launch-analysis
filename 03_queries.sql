-- =====================================================================
-- Steam launch analysis | 03_queries.sql
-- Question: what price, positioning and launch month give a small
-- studio's story-led game the best chance of being noticed on Steam?
--
-- Two measures are used throughout:
--   Liked    = average share of positive reviews (positive_pct)
--   Noticed  = share of games passing 1,000 reviews
-- Average review counts were also checked, but a few huge hits distort
-- them, so "noticed" counts each game once instead.
--
-- Queries 1 to 4 and 6 use the games table (30,624 games with 50+
-- reviews). Query 5 uses games_raw, so it counts every launch.
-- =====================================================================

USE steam_launch;

-- ---------------------------------------------------------------------
-- Query 1: does price relate to how well games are liked and noticed?
-- ---------------------------------------------------------------------
-- Finding: $5 to $9.99 (81.5%) and $10 to $19.99 (80.8%) are best liked;
-- Free and $30+ are lowest (76.2%). The share passing 1,000 reviews rises
-- with price: 19.2% under $5, 31.2% at $10 to $19.99, 47.1% at $20 to
-- $29.99. Under $5 is the largest band (16,155 games) and weakest on both.
SELECT price_band,
       COUNT(*)                                   AS games,
       ROUND(AVG(positive_pct), 1)                AS avg_positive_pct,
       ROUND(AVG(total_reviews))                  AS avg_reviews,
       ROUND(100 * AVG(total_reviews >= 1000), 1) AS pct_with_1000_reviews
FROM games
GROUP BY price_band
ORDER BY price_band;

-- ---------------------------------------------------------------------
-- Query 2: does the release month matter?
-- ---------------------------------------------------------------------
-- Finding: liking barely changes by month (77.5% to 79.2%). For games
-- released 2018 to 2024, September has the highest share passing 1,000
-- reviews (27.4%); December (19.2%), February (19.4%) and July (20.0%)
-- are lowest. August's high average (8,448 reviews) came from a few hits:
-- on the fairer measure it is mid-table.
SELECT release_month,
       COUNT(*)                                       AS games_all_years,
       ROUND(AVG(positive_pct), 1)                    AS avg_positive_pct,
       ROUND(AVG(total_reviews))                      AS avg_reviews,
       ROUND(100 * AVG(total_reviews >= 1000), 1)     AS pct_1000_all_years,
       SUM(release_year BETWEEN 2018 AND 2024)        AS games_2018_2024,
       ROUND(100 * AVG(CASE WHEN release_year BETWEEN 2018 AND 2024
                            THEN total_reviews >= 1000 END), 1) AS pct_1000_2018_2024
FROM games
GROUP BY release_month
ORDER BY release_month;

-- ---------------------------------------------------------------------
-- Query 3: which genres are noticed, and which are liked? (join)
-- ---------------------------------------------------------------------
-- Finding: attention and liking pull in opposite directions. Massively
-- Multiplayer is noticed most (38.4%) but liked least (67.4%); Casual is
-- liked most (79.6%) but noticed least (16.5%). Adventure is well liked
-- (79.1%) but below the middle on attention (23.7%, 8th of 12), and
-- crowded (13,191 games). Utilities is software, so it is excluded.
SELECT gg.genre,
       COUNT(*)                                     AS games,
       ROUND(AVG(g.positive_pct), 1)                AS avg_positive_pct,
       ROUND(AVG(g.total_reviews))                  AS avg_reviews,
       ROUND(100 * AVG(g.total_reviews >= 1000), 1) AS pct_with_1000_reviews
FROM game_genres gg
JOIN games g ON g.app_id = gg.app_id
WHERE gg.genre <> 'Utilities'
GROUP BY gg.genre
HAVING COUNT(*) >= 200
ORDER BY pct_with_1000_reviews DESC;

-- ---------------------------------------------------------------------
-- Query 4: the most-reviewed well-liked games per genre (CTE + RANK)
-- ---------------------------------------------------------------------
-- Finding: among games with 90%+ positive reviews, the most-reviewed are
-- big-budget releases (Black Myth: Wukong, Baldur's Gate 3, Elden Ring)
-- or indie hits with years of sales (Terraria, 2011; Stardew Valley,
-- 2016). Not useful benchmarks for a new small studio. The price column
-- also shows the current-price limit: The Witcher 3 appears at $3.99.
-- (A first version ranked by positive % instead: the top 15 scored 99%+
-- but 12 of them had under 2,500 reviews.)
WITH ranked AS (
  SELECT gg.genre, g.name, g.price_usd, g.release_year,
         g.positive_pct, g.total_reviews,
         RANK() OVER (PARTITION BY gg.genre
                      ORDER BY g.total_reviews DESC) AS rnk
  FROM games g
  JOIN game_genres gg ON gg.app_id = g.app_id
  WHERE g.positive_pct >= 90
    AND gg.genre IN ('Adventure', 'RPG', 'Indie')
)
SELECT *
FROM ranked
WHERE rnk <= 5
ORDER BY genre, rnk;

-- ---------------------------------------------------------------------
-- Query 5: how has the market grown? (all launches, CTE + running total)
-- ---------------------------------------------------------------------
-- Finding: launches grew from 468 (2013) to 20,033 (2024), about 43x,
-- while the number reaching 50 reviews stayed at roughly 2,400 to 3,200
-- a year since 2016. The share of launches noticed fell from 92.5% (2013)
-- to 16.0% (2024): about one in six. 2025 is partial (too recent to have
-- reviews) and the 3,316 games dated 2026 are unreleased listings, so
-- 2024 is the latest year quoted.
WITH yearly AS (
  SELECT YEAR(STR_TO_DATE(release_date, '%b %d, %Y')) AS release_year,
         COUNT(*) AS games_launched,
         SUM(CAST(positive AS UNSIGNED) + CAST(negative AS UNSIGNED) >= 50) AS reached_50
  FROM games_raw
  GROUP BY release_year
)
SELECT release_year,
       games_launched,
       reached_50,
       ROUND(100 * reached_50 / games_launched, 1) AS pct_reached_50,
       SUM(games_launched) OVER (ORDER BY release_year) AS running_total
FROM yearly
ORDER BY release_year;

-- ---------------------------------------------------------------------
-- Query 6a: which story-led tag fits best? (join + UNION ALL benchmark)
-- ---------------------------------------------------------------------
-- Finding: Story Rich beats the all-games benchmark on both measures:
-- 83.0% liked and 32.6% noticed, against 78.5% and 23.5% (6,928 games).
-- Atmospheric is similar (80.8%, 33.4%). Visual Novel is best liked
-- (85.3%) but least noticed (20.1%).
SELECT gt.tag,
       COUNT(*)                                     AS games,
       ROUND(AVG(g.positive_pct), 1)                AS avg_positive_pct,
       ROUND(100 * AVG(g.total_reviews >= 1000), 1) AS pct_with_1000_reviews
FROM game_tags gt
JOIN games g ON g.app_id = gt.app_id
WHERE gt.tag IN ('Story Rich', 'Choices Matter', 'Multiple Endings', 'Visual Novel',
                 'Mystery', 'Psychological', 'Atmospheric', 'Exploration')
GROUP BY gt.tag

UNION ALL

SELECT 'All games',
       COUNT(*),
       ROUND(AVG(positive_pct), 1),
       ROUND(100 * AVG(total_reviews >= 1000), 1)
FROM games

ORDER BY pct_with_1000_reviews DESC;

-- ---------------------------------------------------------------------
-- Query 6b: Story Rich games only, by price band
-- ---------------------------------------------------------------------
-- Finding: liked peaks at $5 to $9.99 (85.2%) and $10 to $19.99 (85.1%).
-- Noticed rises from 28.6% under $5 to 37.4% at $10 to $19.99. The $20+
-- bands are higher still (50.5%, 68.9%) but small (192 and 74 games) and
-- likely dominated by bigger productions.
SELECT g.price_band,
       COUNT(*)                                     AS games,
       ROUND(AVG(g.positive_pct), 1)                AS avg_positive_pct,
       ROUND(100 * AVG(g.total_reviews >= 1000), 1) AS pct_with_1000_reviews
FROM games g
JOIN game_tags gt ON gt.app_id = g.app_id
WHERE gt.tag = 'Story Rich'
GROUP BY g.price_band
ORDER BY g.price_band;

-- ---------------------------------------------------------------------
-- Query 6c: Story Rich games only, by release month
-- ---------------------------------------------------------------------
-- Finding: September is best again (38.8% pass 1,000 reviews), then
-- November (37.1%) and June (35.8%); July (27.8%) and April (28.4%) are
-- weakest. Groups are about 425 to 725 games, so small gaps may be noise.
SELECT g.release_month,
       COUNT(*)                                     AS games,
       ROUND(AVG(g.positive_pct), 1)                AS avg_positive_pct,
       ROUND(100 * AVG(g.total_reviews >= 1000), 1) AS pct_with_1000_reviews
FROM games g
JOIN game_tags gt ON gt.app_id = g.app_id
WHERE gt.tag = 'Story Rich'
GROUP BY g.release_month
ORDER BY g.release_month;
