## Why

Discord mod thread titles often embed version numbers and subtitles that the author typed in — `Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."` instead of just `Hazard Mining Incorporated`. The merger's 0.85 name-length-ratio gate then rejects the match against the Forum/Index entry because the cleaned name is much longer than the base mod name. This leaves 92+ Discord entries stranded as their own groups when they should merge with an existing Forum or Index entry. The HMI mod (groups 330, 331, 332) is the clearest example: four entries, all by King Alfonzo, all the same mod, split into three groups.

## What Changes

- A new name-cleaning function strips version noise from mod names. It removes leading bracketed tags (`[0.97a]`, `[WIP]`), trailing version numbers (with optional `v`/`V` prefix), and everything after the version (subtitles, edition labels, parenthesized notes). A final trim removes dangling separators.
- The merger compares **both readings** of a pair of names: the names as scraped, and the names with the version noise taken off. A pair matches if **either** reading passes the fuzzy comparison and the 0.85 length-ratio gate. The cleaned name is never substituted for the scraped one, so this step can only ever find more mods — it can never lose a match that works today.
- The same "either reading" rule is used by the safety check in the same-source game-version dedup, so that step keeps agreeing with the grouping step.
- The cleaned name is used **only for matching**. The original name stays on the `ScrapedMod` — nothing changes about what is scraped, stored, or written to `ModRepo.json`.
- The existing `_prepForMatching` (lowercase + strip non-alpha) still runs on both readings.

## Capabilities

### New Capabilities
- `merge-name-cleaning`: Regex-based name cleaning that strips version noise from mod names, giving the merger a second reading of every name to compare, so mods with inflated Discord thread titles can match their Forum/Index counterparts.

### Modified Capabilities
- `merge-comparison`: The merger's name-matching path now tries a second, version-stripped reading of a pair when the names as scraped do not match, so some groups gain members — and none lose any. The comparison views keep showing the original names.
- `viewer-merge-explorer`: A match reason now says which reading of the names matched, and shows the stripped names when it was the stripped reading. Merges saved before this change render without those details.

## Impact

- `lib/bot/scraper/mod_repo_utils.dart` — the new `stripVersionNoise` function lives here, alongside `compareToFindBestMatch` and `splitAuthorNames`.
- `lib/bot/scraper/mod_merger.dart` — a second map of stripped names beside `cleanedNames`; the pair check tries the second reading when the first fails; the same-source dedup safety check does the same.
- `lib/bot/scraper/debug/merge_debug_data.dart` — four new fields on `GroupMatchEntry` and one new value on `GroupMatchReason`, so the merge explorer can show what the cleaner produced. Needs the code generator re-run.
- `web/views/merge.js` — show the second reading in the match-reason line.
- `test/mod_merger_test.dart` — new cases for the cleaning function, for the pairs it newly joins, and for the real pairs that must keep matching.
- No new dependencies. No config keys. No changes to the scrape, the output shape, or anything else in the viewer.

## Measured effect

Replayed over the 1,404 pre-merge entries in the newest saved merge (`qb_data/merges/20260722T153548Z-mergeModRepo.json.gz`):

- 165 name pairs match on the stripped reading that do not match on the names as scraped, including every HMI pair, both Nexerelin entries, and "Scrapyard Armories" against "Scrapyard Armories 0.0.19 Delayed Maintenance Update". Spot-checking all 165 found no pair that is not plainly the same mod.
- 0 pairs are lost, because the names as scraped are still compared first.
- All 165 are already offered to the pair check as candidates today — 162 through trigram overlap, 3 through the shared-forum-thread bucket — so the candidate indexes do not need to change.
