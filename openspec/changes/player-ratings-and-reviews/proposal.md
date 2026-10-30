## Why

Players have asked for a way to rate mods and write short reviews on Starmodder. Today the site only shows what authors post. There is no way to learn from other players whether a mod is stable, balanced or fun. The design was settled in a grilling session and is recorded in `CONTEXT.md` (Account, Rating, Review, Balance, Vanilla Friendliness) and `docs/adr/0003-ratings-through-a-separate-account-service.md`.

## What Changes

- Players can sign in with Discord, GitHub or Google. One account can have several sign-ins linked to it, and each sign-in belongs to one account only. The player picks a display name, which the LLM checks before it is shown. A player can delete their account and all its data.
- A rating scores one mod, for the mod version the player used, on five criteria: Stability, Balance, Vanilla Friendliness, Fun and Polish. Each is 1 to 5 or N/A. There is no overall score. The current version is selected by default, and the player can pick an earlier release. One account has one rating per mod per version.
- A review is optional text sent with a rating: up to 1,000 characters, plain text, no links. It is shown only after it passes a check.
- A separate account service (a Cloudflare Worker with its own database, at its own address) handles signing in, sending ratings and reviews, and reading review text and display names. Mod pages fetch review text from it. Everything else on the site stays static. **BREAKING** for the site rule that every file comes from the site's own address: signing in, sending, and reading review text are the one exception (ADR 0003).
- The scraper works out each mod's average per criterion and writes it into `mods.json` and `mods/<id>.json`. A rating counts fully while its version is current. After the mod moves past that version, its weight halves every 3 months. A mod needs at least 3 ratings on a criterion to be ranked by it.
- Browse can sort by any one criterion and filter by "at least N" on any criterion. Filters keep mods with no ratings unless the reader turns on "Hide mods with no ratings". Cards show a criterion's average and count only while Browse is sorted or filtered by it. The mod page always shows all five, plus the reviews.
- A new job checks reviews and display names with the LLM every hour. It runs only when the LLM server has no other request running, and it checks again before each review. Insults, slurs, spam and reviews about another mod are rejected. Bug reports and reviews with no meaningful content keep the rating and drop the text. A rejected review's scores still count, unless the scores are part of the abuse.
- Any signed-in player can report a review. Reports never hide anything on their own. The results viewer gets a Reviews page under Corrections: waiting, rejected and reported reviews, how long the oldest one has waited, and ways to approve or hide a review, block an account, and mark an account as a mod's author.
- A mod's author can be verified through Discord (they posted the mod's Discord thread), GitHub (they own the mod's source code repository) or manually in the viewer.
- Authors can opt their mods out of ratings. The opt-out list is kept like the takedown list. Ratings on an opted-out mod are hidden, not deleted.
- Ratings follow a moved id to the mod it was joined into. Collection pages and taken-down mods show no ratings; their ratings are kept.
- Starmodder gets a privacy page, which Discord and Google require before they allow sign-in.
- Not part of this change: ratings in TriOS, favorites saved to an account, mod lists, authors managing their own mods, replies from authors, update alerts.

## Capabilities

### New Capabilities
- `player-accounts`: signing in, linked sign-ins, display names, deleting an account, the privacy page, and who can make requests to the account service.
- `mod-ratings`: what a rating contains, which version it is for, how averages and weights are calculated, what the site shows, sorting and filtering, and what happens when ids move, mods become Collections, are taken down or opted out.
- `mod-reviews`: review text, how it is shown on a mod page, and reporting.
- `review-checks`: the hourly check job, the LLM server idle rule, the verdicts, and the viewer's Reviews page.

### Modified Capabilities
- `scraper-configuration`: a new `ratings_` group of config keys for the account service.
- `saved-filters`: a saved filter also holds the rating filters.

## Impact

- New: `account-service/` (the Cloudflare Worker, its database schema and its deploy settings).
- Scraper: a client for the account service, the rating averages and weights in `lib/site/public_data_builder.dart`, a new `checkReviews` job kind in `lib/manager/job.dart` (regenerate `job.mapper.dart`), a timer in the viewer server that starts it, and a step after each site build to send moved, hidden and Collection ids to the service.
- Discord scrape: `discord-posts.json` saves the Discord user id of each thread's author, so Discord sign-ins can be matched to authors.
- Site: `mods.json` and `mods/<id>.json` gain rating averages; new sign-in, account and rating panels; Browse sorting, filters and cards; `site/filter_set.js` gains rating keys; a privacy page.
- Viewer: a Reviews page under Corrections and the routes behind it.
- Config: new `ratings_` keys in `config.example.properties` and `Common._recognizedKeys`.
- Docs: `CLAUDE.md` (the site no longer fetches only from its own address), the About page, `CONTEXT.md` (already updated).
- Outside the code: a Cloudflare Worker and database, a DNS name for it, and Discord, GitHub and Google sign-in apps. Their secrets live in Cloudflare, never in the repo.
