# Press Start: what helps a story-led game get noticed on Steam?

A SQL case study using public data on 125,855 Steam store listings, written as a launch recommendation for Fernhill Games, a fictional indie studio. The studio is made up; the data is real and public.

## The answer first

For a small studio launching a story-led game, I would recommend:

1. **Position it as Story Rich** (and Atmospheric, if it fits) rather than relying on the broad Adventure or Indie labels.
2. **Price it between $10 and $19.99**, and avoid going under $5.
3. **Aim for a September launch**, and avoid July.

The full recommendation is in [`business_proposal.pdf`](business_proposal.pdf).

## Why I did this

What draws me to games is how storytelling, user experience, visuals and psychology work together to hold a player's attention, which is much the same craft as marketing. So I wanted to look at the other half of the problem: once a good story game exists, what helps people find it?

## The problem: more games, the same amount of attention

![Steam launches against the share of games reaching 50 reviews, 2013 to 2024](images/market_growth.png)

Steam launches grew from 468 in 2013 to 20,033 in 2024, about 43 times more. But the number of games reaching 50 reviews stayed at roughly 2,400 to 3,200 a year from 2016 onwards. In 2024 only 16% of launches, about one in six, reached 50 reviews. For a new game, being noticed is the main risk, so every question below is about discoverability.

## Data and approach

- **Data:** [Steam Games Dataset](https://huggingface.co/datasets/FronkonGames/steam-games-dataset) by Fronkon Games (MIT licence), downloaded from Kaggle as `games.csv`.
- **Tools:** MySQL 8 and DBeaver for loading, cleaning, modelling and analysis. Terminal for one file fix. Charts produced with Python (matplotlib), with AI assistance.
- **Scope:** comparisons of liking and attention use the 30,624 games with at least 50 reviews, because a score from a handful of reviews means little. The market analysis uses every launch.
- **Two measures:**
  - *Liked*: the average share of positive reviews.
  - *Noticed*: the share of games passing 1,000 reviews. I started with average review counts, but a few huge hits distorted them, so I switched to a measure that counts each game once.

**Data model.** Genres and tags arrive as comma-separated text in a single cell, which cannot be counted or compared. I split them into their own tables, linked to the games table on `app_id`:

![Entity relationship diagram of games, game_genres and game_tags](images/diagram.png)

## What I found

**Positioning matters more than genre.** Story Rich games beat the all-games average on both measures: 83.0% liked and 32.6% noticed, against 78.5% and 23.5%. Games in the Adventure genre, by contrast, are noticed no more often than average (23.7%), and the genre is crowded with 13,191 games. Visual Novel is the best liked of the tags I compared (85.3%) but the least noticed (20.1%).

![Story-led tags against all games on liking and attention](images/positioning.png)

**Price: the middle balances liking and attention.** Among Story Rich games, $10 to $19.99 is among the best liked (85.1%) and noticed more often than cheaper games (37.4%, against 28.6% under $5). Under $5 is the most crowded band and the weakest on attention. The $20+ bands are noticed more, but they are small groups (192 and 74 games) that are likely dominated by bigger productions.

![Story Rich games by price band](images/price.png)

**Timing is a smaller lever.** September had the highest share of games passing 1,000 reviews, both across all games released 2018 to 2024 (27.4%) and among Story Rich games (38.8%). July was among the weakest in both. How much players like a game barely changes by month, so timing affects visibility, not reception.

**Being loved is not enough.** The best-liked games in each genre (99%+ positive) are mostly small: 12 of the top 15 have under 2,500 reviews. The most-reviewed well-liked games are either big-budget releases or indie hits with a decade of sales behind them, neither of which is a fair benchmark for a new studio.

## What changed my mind along the way

- My first genre query sorted by average reviews and made Adventure look like a sweet spot. Sorting by the share passing 1,000 reviews moved it to 8th of 12.
- August looked like the best launch month on average reviews (8,448). On the fairer measure it was mid-table, because a few big August releases were lifting the average.
- My first market-growth query only counted games with 50+ reviews, which showed growth in noticed games rather than the market. Rebuilding it on every launch gave the most important finding in the project.

## Limits

- The comparisons of liking and attention cover games with at least 50 reviews, so they describe games that were already noticed.
- Prices are today's prices, not launch prices. Some well-known games appear at discounted prices (The Witcher 3 at $3.99).
- Steam tags are partly applied by players, and higher-priced games are often bigger productions, so these are links, not proof of cause.
- Monthly differences are a few points on groups of about 500 games, so September is a pattern to test, not a guarantee.

## What I would test next with a studio's own data

- Wishlist-to-purchase conversion at $14.99 against $19.99.
- An A/B test of store page tags and copy that lead with the story.
- Wishlist growth in the months before a September launch.

## Data problems found and fixed

| Problem | Fix |
|---|---|
| The file's header joined "Discount" and "DLC count" into one name, so every label after Price sat one column to the left of its values | Replaced the header on a copy of the file before loading |
| DBeaver's CSV import wizard failed on quoted text containing commas, quotes and line breaks | Loaded the file with MySQL `LOAD DATA LOCAL INFILE` instead |
| The first load brought in 1 row because of the wrong line ending | Used `'\n'` instead of `'\r\n'`; all 125,855 rows loaded |
| A third of listings (42,899) had no reviews, which would distort averages | Kept games with 50+ reviews for the comparisons |
| Average review counts were pulled up by a few huge hits | Added the share passing 1,000 reviews, which counts each game once |
| 3,316 listings are dated 2026, which are unreleased games | Quoted 2024 as the latest full year |

## Repository contents

| File | What it holds |
|---|---|
| `01_load_and_clean.sql` | Database setup, loading the CSV, data inspection and the clean table |
| `02_build_tables.sql` | The `games`, `game_genres` and `game_tags` tables |
| `03_queries.sql` | The analysis queries, each with its finding as a comment |
| `business_proposal.pdf` | The one-page launch recommendation |
| `images/` | The ER diagram and charts |

**SQL used:** joins, aggregation with `GROUP BY` and `HAVING`, `CASE`, CTEs, window functions (`RANK`, running totals with `SUM() OVER`), `UNION ALL`, and `JSON_TABLE` to split text lists into rows.

## How to reproduce

1. Download `games.csv` from the Steam Games Dataset by Fronkon Games on Kaggle.
2. Fix the header in Terminal, from the folder holding the file:

   ```bash
   tail -n +2 games.csv > games_body.csv
   printf '%s\r\n' 'app_id,name,release_date,estimated_owners,peak_ccu,required_age,price,discount,dlc_count,about_the_game,supported_languages,full_audio_languages,reviews,header_image,website,support_url,support_email,windows,mac,linux,metacritic_score,metacritic_url,user_score,positive,negative,score_rank,achievements,recommendations,notes,average_playtime_forever,average_playtime_two_weeks,median_playtime_forever,median_playtime_two_weeks,developers,publishers,categories,genres,tags,screenshots,movies' > games_fixed.csv
   cat games_body.csv >> games_fixed.csv
   ```

3. In MySQL 8, run `01_load_and_clean.sql` (change the file path in `LOAD DATA`), then `02_build_tables.sql`, then `03_queries.sql`.

Results depend on the dataset version. This analysis used the version downloaded in November 2026.
