## 1. Manual setup

- [ ] 1.1 Create the Cloudflare Worker and its D1 database, and point `accounts.starmodder.wispborne.com` at the Worker
- [ ] 1.2 Check that the home network's Pi-hole sends `accounts.starmodder.wispborne.com` to Cloudflare, not to Zephyrus (the existing `starmodder.wispborne.com` line may already cover it)
- [ ] 1.3 Create the Discord, GitHub and Google sign-in apps, with the service's return addresses and the `privacy/` page's address, and store their secrets as Worker secrets
- [ ] 1.4 Create the scraper's token, store it as a Worker secret, and put it in production's `config.properties` as `ratings_service_token`
- [ ] 1.5 Create the player code secret and store it as a Worker secret only

## 2. The account service (`account-service/`)

- [ ] 2.1 `package.json` with `wrangler` and Cloudflare's test runner for Workers, kept inside `account-service/`
- [ ] 2.2 Database schema: accounts, sign-ins, ratings, reviews, display names, reports, blocks, authors and the id map, with a migration file
- [ ] 2.3 Sign-in with Discord (`identify`), GitHub (no extra permission) and Google (`openid`); no email address asked for or stored; 90-day session cookie; sign-out; return to the page the player started from
- [ ] 2.4 Let signed-in players link another sign-in. Refuse sign-ins that belong to another account
- [ ] 2.5 Display names: 3 to 32 characters of letters, digits, spaces and `. _ -`; unique ignoring capitals; refuse a credited author's name unless the account is a verified author of that author's mods; set, waiting, approved, rejected; "Unnamed player" for everyone else while waiting
- [ ] 2.6 Save a rating (five criteria, 1–5 or N/A, at least one score, version or none), replacing any existing rating for that version
- [ ] 2.7 Accept reviews: 1,000 characters at most, plain text, no links. An edited review shows its approved text until the changes are approved. Changing only the scores needs no check
- [ ] 2.8 Serve a mod's approved reviews under its current id, with the author mark. Refuse requests for hidden ids. Let players see their own reviews in every state
- [ ] 2.9 Let players report a review once per account
- [ ] 2.10 Delete an account and all its data in one transaction
- [ ] 2.11 Only Starmodder's own address (and `localhost`) may call it from a browser. Limits per account: 30 ratings or reviews an hour, 10 reports an hour, 3 display name changes a day. Refuse requests over these limits and tell the player when to try again
- [ ] 2.12 Delete rejected review text 30 days after rejection, and reports once their review is dealt with or deleted. Keep no IP addresses or request logs
- [ ] 2.13 Player codes: a hash of the account id with the player code secret, `p-` plus six hex characters. Lengthen the codes if two accounts get the same one
- [ ] 2.14 Require the scraper's token for its calls: list waiting reviews and names, send verdicts, send the id map (with credited author names), export every rating by player code, and make a full copy
- [ ] 2.15 Require the same token for the viewer's calls: approve or hide a review, approve or reject a name, block or unblock, mark an author
- [ ] 2.16 Tests for every rule above, run against a local database

## 3. Scraper side

- [ ] 3.1 Add `ratings_service_url`, `ratings_service_token`, `ratings_check_minutes` and `ratings_llm_activity_url` to `BotConfig`, `Common._recognizedKeys` and `config.example.properties`; check no route serves them
- [ ] 3.2 Add an account service client in Dart for the site build, the check job and the viewer
- [ ] 3.3 Save each Discord thread author's user id in `discord-posts.json`
- [ ] 3.4 Verify each mod's authors (Discord thread author, GitHub source code owner, authors marked in the viewer) after each site build
- [ ] 3.5 Keep an opt-out list in `qb_data`, read and published like the takedown list
- [ ] 3.6 Download the rating export at the start of a site build and calculate the weighted averages and player counts in `PublicDataBuilder`; exclude ratings from blocked accounts, ratings marked abusive and ratings by a verified author of the mod
- [ ] 3.7 Write `ratings.json` and each rated mod's averages into `mods/<id>.json`, and the count of approved reviews into `mods/<id>.json`; nothing for Collections, taken-down or opted-out mods; nothing added to `mods.json`
- [ ] 3.8 Write `ratings-export.json`: every rating that is not blocked or abusive, by player code, with the author mark and approved review text
- [ ] 3.9 Publish `ratings.json` and `ratings-export.json` with the other data files
- [ ] 3.10 The first site build each day saves a full copy to `qb_data/ratings-backup/<date>.json.gz` and keeps the newest 14; a failed copy is logged and does not fail the build
- [ ] 3.11 Send the id map, with credited author names, after each site build; log a failure without failing the build
- [ ] 3.12 Tests: weights (current, a week after a release, two years after), unknown versions, moved ids, hidden ids, author ratings left out, player counts, nothing personal in the export

## 4. The check job

- [ ] 4.1 Add the `checkReviews` job kind (regenerate `job.mapper.dart`) and route it
- [ ] 4.2 The idle rule: read the request log before starting and before each item; unfinished requests started less than `llm_timeout_seconds` ago mean the server is busy; no address means the job does not run
- [ ] 4.3 The review prompt and the display name prompt, with the four verdicts and a short reason; an unreadable answer leaves the item waiting
- [ ] 4.4 Calls go through the post-reading client and count against `llm_max_topics`
- [ ] 4.5 A timer in the viewer server that submits the job every `ratings_check_minutes`; runs with nothing to check are not saved to the history
- [ ] 4.6 Tests: busy, idle, stale unfinished request, busy partway through, unreadable answer, each verdict
- [ ] 4.7 Live-model tests in `test/llm_live/` for a fair review, an insult, a bug report, a review about another mod and an unacceptable display name

## 5. The site

- [ ] 5.1 Sign-in button and account menu in the top bar: sign in, link another sign-in, display name, sign out, delete account
- [ ] 5.2 The privacy page at `privacy/`, built from `site/index.html` like the install guide, included in `PAGE_FOLDERS`, the sitemap and the published files; linked from the sign-in choices, the review box and About
- [ ] 5.3 Mod page: the five averages with player counts, the "Rate this mod" panel with the version picker, and the opt-out notice
- [ ] 5.4 Mod page: reviews from the service, current version first, earlier versions collapsed, the "Author" label, report, the player's own waiting or rejected review with the reason; no request for an unrated mod when signed out; a clear message when the service does not answer
- [ ] 5.5 The review box says approved reviews are published under a player code and that old copies stay in the public history
- [ ] 5.6 `site/filter_set.js`: `rate=<criterion>:<n>` and `rated=1`, with tests in `test/site/filter_set_test.mjs`
- [ ] 5.7 Browse: loads `ratings.json` only when sorting or filtering by a criterion; a sort per criterion with the 3-player rule, the "at least N" filters, "Hide mods with no ratings", in both layouts
- [ ] 5.8 Cards and rows show the criterion being sorted or filtered by
- [ ] 5.9 Home's filter bar gains the rating filters through `filterControls`
- [ ] 5.10 Add ratings to `site/sample-data/` and keep `test/site/sample_data_test.dart` passing
- [ ] 5.11 Check every new icon's alignment in the browser, following the icon rule in `CLAUDE.md`

## 6. The viewer

- [ ] 6.1 A Reviews page under Corrections: waiting, rejected and reported reviews and names, and how long the oldest has waited
- [ ] 6.2 Add actions: approve or hide a review, approve or reject a name, block or unblock an account, mark an author, add or remove an opt-out
- [ ] 6.3 Add routes for the Reviews page. Do not expose config values

## 7. Docs and roll-out

- [ ] 7.1 `CLAUDE.md`: the account service, the check job, the new keys, `ratings.json` and `ratings-export.json`, and the changed rule that the site fetches only from its own address
- [ ] 7.2 The About page: how ratings work, how reviews are checked, how to opt a mod out
- [ ] 7.3 `account-service/README.md`: how to run its tests, apply a schema change and deploy by hand with `wrangler deploy`
- [ ] 7.4 Roll out in the order in `design.md`: service first, then the scraper with no request log address, then the site, then turn the check job on
