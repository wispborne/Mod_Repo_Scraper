## Why

Discord mod thread titles often embed version numbers and subtitles that the author typed in — `Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."` instead of just `Hazard Mining Incorporated`. The merger's 0.85 name-length-ratio gate then rejects the match against the Forum/Index entry because the cleaned name is much longer than the base mod name. This leaves 92+ Discord entries stranded as their own groups when they should merge with an existing Forum or Index entry. The HMI mod (groups 330, 331, 332) is the clearest example: four entries, all by King Alfonzo, all the same mod, split into three groups.

## What Changes

- A new name-cleaning function strips version noise from mod names before the merger compares them. It removes leading game-version tags (`[0.97a]`), trailing version numbers (with optional `v`/`V` prefix), and everything after the version (subtitles, edition labels, parenthesized notes). A final trim removes dangling separators.
- The cleaned name is used **only for matching** inside the merger. The original name stays on the `ScrapedMod` — nothing changes about what is scraped, stored, or written to `ModRepo.json`.
- The existing `_prepForMatching` (lowercase + strip non-alpha) still runs after this new step.

## Capabilities

### New Capabilities
- `merge-name-cleaning`: Regex-based name cleaning that strips version noise from mod names before comparison, so mods with inflated Discord thread titles can match their Forum/Index counterparts.

### Modified Capabilities
- `merge-comparison`: The merger's name-matching path now applies the version-stripping step before the fuzzy comparison and the length-ratio check. No new config keys, no changes to the merge debug output shape — groups just form better.

## Impact

- `lib/bot/scraper/mod_merger.dart` — the comparison logic calls the new cleaning function before `_prepForMatching`.
- `lib/bot/scraper/mod_repo_utils.dart` — where the new function likely lives (alongside `compareToFindBestMatch` and `_prepForMatching`).
- `test/mod_merger_test.dart` — new test cases for the cleaning function and for the HMI merge scenario.
- No new dependencies. No config keys. No changes to the scrape, the output shape, or the viewer.
