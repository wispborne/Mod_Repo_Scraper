## Context

Starmodder is a static site on Cloudflare Pages, built twice a day by the scraper on Zephyrus and published as commits to `wispborne/StarsectorModRepo`. It has no server, and the site's rules say every file comes from its own address. The LLM runs on Notus, reached at `llm.wispborne.com`. Notus also serves the user's own coding sessions. Its request log (`/notus/api/requests`) lists every request, and a request still running has no `finished_at`.

ADR 0003 describes the design: a separate account service, static pages, averages in the static files, review text read from the service, and reviews checked by the scraper's LLM. This document describes the implementation.

## Goals and non-goals

**Goals:**
- Players can sign in, rate, review, report, and delete their account.
- Averages are calculated in one place (the scraper) and published like every other field.
- Review text and display names never enter the public git repo.
- The site still loads and works when the account service is down. Only the account features stop.
- Checking reviews never competes with any other use of Notus.

**Non-Goals:**
- Ratings in TriOS or in `mod-catalog-extras.json`.
- Favorites saved to an account, mod lists, update alerts.
- Authors managing their own mods: self-service opt-out, replies, corrections. Opt-out is done by hand in the viewer for now.
- Votes on reviews.

## Decisions

**The account service is kept in this repo, in `account-service/`, as a Cloudflare Worker with a D1 database.** Plain JavaScript modules with no build step, the same as the site. Deployed with `wrangler`. Its address is `accounts.starmodder.wispborne.com`. Alternatives: a separate repo (the scraper and the service exchange data in agreed formats, so one repo keeps them in step); a home-server app (rejected in ADR 0003).

**The service handles sign-in, with each provider's own sign-in page.** The site sends the player to `/signin/<provider>` on the service. The service sends them back to the page they came from, with a session cookie set on the service's own address (`HttpOnly`, `Secure`, `SameSite=Lax`). The site and the service share `wispborne.com`, so the browser counts them as the same site and sends the cookie with the site's requests. The service answers only requests from the site's own address (and `localhost` while developing). Players link a second sign-in by following the same steps while already signed in. A sign-in already linked to another account is refused with a message explaining why.

**The database holds accounts, sign-ins, ratings, reviews, reports, blocks and the id map.** One table each. A rating row holds the account, the permanent id the player rated, the version, the date and the five scores. A review row belongs to one rating and holds its text, its status (`waiting`, `approved`, `textRemoved`, `rejected`, `abusive`, `hidden`) and the reason for that status. A display name has the same statuses. Deleting an account deletes its rows in one transaction.

**The scraper talks to the service through a small private API, with a token.** Three calls: get everything waiting to be checked; send verdicts; send the id map. The token is a config key on the scraper side and a Worker secret on the service side. The public API never shows a token, an email address or a provider's own account id.

**The id map is sent after every site build.** It holds the moved ids, the Collection ids, the taken-down ids and the opted-out ids. The service uses it when serving reviews: reviews for a moved id are served under the mod it moved to, and reviews for a hidden id are not served at all. So the pages and the service never disagree about which mod a review belongs to, and nothing is deleted when a mod is hidden.

**Averages are calculated in `PublicDataBuilder`, from every rating the service has.** The scraper downloads all ratings (scores, version, date and permanent id, never names or text) at the start of each site build. For each mod and criterion:
- A rating counts fully while its version is the mod's current version, or when the mod has no known releases.
- Once the mod has a newer release, the rating's weight halves every 3 months, counted from that release's date. The release dates come from the mod's release history, which the builder already has.
- N/A is not a score and does not count.
- A rating whose review was marked `abusive`, or that belongs to a blocked account, does not count.

`mods.json` gets `ratings`: for each criterion with at least one score, the weighted average to one decimal and the number of players. It is written only for mods with ratings, so most records do not grow. `mods/<id>.json` gets the same. The player count is used for the "needs 3 ratings" rule, because a weighted count would make a mod drop out of the ranking for no visible reason.

Alternative considered: the service works out the averages. Rejected because the release dates live in the scraper, and the averages would then change at a different moment from every other field on the page.

**A rating's version is the version text the player picked.** The picker lists the mod's current version and its earlier releases, from `mods/<id>.json`. A mod with no known version has nothing to pick, and the rating is stored with no version. When calculating weights, a version that is not in the mod's release history counts as current, because there is no record that this version was replaced.

**The check job is a manager job, `checkReviews`, started by a timer in the viewer server.** The interval is a config key, 60 minutes by default. The job manager puts it in the same queue as other jobs. This avoids the data lock problems of running a second process. A run that found nothing to check is not saved to the run history, so empty hourly runs do not displace other runs from the 100 kept.

**The idle rule reads Notus's request log.** Before the job starts, and again before each review, it asks the request log for recent requests. Any request with no `finished_at` that started less than `llm_timeout_seconds` ago means Notus is busy. The job then stops for this hour, leaving the rest waiting. The request log's address is a config key; when it is empty the job does not run at all, so a missing setting can never make it compete with other work. The job's own LLM calls go through the same client and limits as post reading, and count against `llm_max_topics`.

**One LLM call per review, with a fixed response format.** The model answers `approve`, `keepRatingOnly` (a bug report or a review with no meaningful content), `reject` (insults, slurs, spam, links, or about another mod) or `abusive` (the scores are part of the abuse), plus one short reason. Display names use the same call with their own short prompt. An answer the code cannot read leaves the review waiting, so an invalid answer cannot approve anything.

**The page reads review text from the service only when the mod has reviews.** `mods/<id>.json` says how many approved reviews the mod had at the last build. When a reader is not signed in, a mod page with no approved reviews makes no request to the account service, so most page views make no extra request. The player's own waiting review comes from the service too, which only shows it to its author.

**The scraper verifies authors and sends them with the id map.** The Discord scrape saves each thread author's Discord user id in `discord-posts.json`. A mod's GitHub owner comes from its source code link. The viewer can manually mark an account as a mod's author. The service marks a review as the author's own when the account is one of the mod's verified authors. Whether an author's own rating counts toward the average is left open below.

**The rating filters are part of a filter set.** `site/filter_set.js` gains `rate=<criterion>:<n>` (repeatable) and `rated=1` for "Hide mods with no ratings". So saved filters, Home's filters and Browse's remembered filters include them automatically. Sorting by a criterion is a sort, not a filter, so it stays out of saved filters like every other sort.

## Risks and trade-offs

- [Notus is busy all day] → Reviews wait. The viewer shows how long the oldest one has waited.
- [Someone signs in three times with three providers] → They can rate three times. There is no overall score or ranking to win, and a blocked account loses all its ratings.
- [The account service is down] → Mod pages still show averages. The review list says it could not be loaded, and the sign-in button says the service is not answering.
- [A missing or expired provider secret] → Sign-in fails for that provider only. The service logs which one.
- [`mods.json` passes its 2 MB limit] → Ratings are written only for rated mods, as numbers with one decimal. The size test covers the worst case of every mod rated on every criterion.
- [Cloudflare's free limits] → Starsector's audience is far below them. The service has a per-account limit on how often it accepts ratings, which also slows down abuse.
- [The release detector confirms a new version only after two runs] → A rating given in the first 12 to 24 hours after a release is filed under the old version. Accepted.

## Migration Plan

1. Create the Cloudflare Worker, the D1 database, the DNS name and the three providers' sign-in apps. These are manual steps; `tasks.md` lists them.
2. Deploy the service. Turn on sign-in with no site change, and test it by hand.
3. Ship the scraper side with the check job's request log address left empty, so nothing runs. Check that a site build with no ratings writes no `ratings` fields.
4. Ship the site. Set the request log address, and the check job starts.

Rolling back: the site works without the service. Removing the sign-in button and the review list from the site puts it back to how it was. The database keeps everything.

## Open Questions

- Does an author's own rating of their mod count toward its average, or only show with an "Author" mark?
- Should the privacy page be its own folder page (like the install guide), or a section of About?
