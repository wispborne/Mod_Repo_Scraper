## Context

The ModRepo merger groups mods from three sources (Forum Index, Discord, Nexus) into one entry per mod. Grouping compares cleaned names (`_prepForMatching`: lowercase, strip non-alpha) and checks a 0.85 length-ratio gate before accepting a fuzzy match. Discord thread titles often embed version numbers and subtitles — `Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."` — that inflate the cleaned name and block the ratio gate. 92+ Discord entries sit alone as a result.

`mod_repo_utils.dart` already holds `_prepForMatching`, `compareToFindBestMatch`, and `splitAuthorNames`. The new function belongs there.

## Goals / Non-Goals

**Goals:**
- Give the merger a second reading of every name, with the version noise taken off, so the fuzzy comparison and the length-ratio gate can see the base name instead of the version-decorated Discord thread title.
- **Never lose a match that works today.** Cleaning names is a guess; the names as scraped are not. The scraped names must stay the first thing compared.
- Change nothing about what is scraped, stored, or written to `ModRepo.json`.
- Keep the regex simple enough to reason about and test against real data.

**Non-Goals:**
- Handling true renames (e.g. "Combat Analytics" → "Detailed Combat Results") — those need a different approach (overrides file or LLM), tracked separately in the known-hard-cases memory.
- Cleaning names at scrape time or changing the `ScrapedMod` model.
- Adding config keys or LLM calls.
- Making the cleaner perfect. Under the design below an imperfect clean costs a missed opportunity, never a broken merge, so it does not have to be.

## Decisions

### 1. Compare both readings — do not replace the name

The merger keeps `cleanedNames[i] = _prepForMatching(mod.name)` exactly as it is, and gains a second map alongside it:

```dart
strippedNames[i] = _prepForMatching(stripVersionNoise(mod.name));
```

In the pair check, the names as scraped are compared first. Only when they fail, and only when the cleaner actually changed one of the two names, is the stripped reading compared. A pair matches on name if **either** reading passes both the fuzzy comparison and the 0.85 length-ratio gate.

**This is the whole point of the design.** An earlier draft replaced `cleanedNames` with the stripped names — one line, and it looked equivalent. It is not. Replaying that draft over the 1,404 pre-merge entries of the newest saved merge broke 8 merges that work today:

- The regex cuts at the **first** `digits.digits` in a name and `.*` eats the rest, so a version in the middle of a title destroys the real name that follows. `Substance.Abuse 1.1.c - Consumable Alcohol` becomes `Substance.Abuse`, which no longer matches `Substance.Abuse - Consumable Alcohol` (the ratio drops from 0.97 to 0.45). The same breaks `SSMSControllerEx - Controller Support`, `Orky Sector (Formally Looted Sector)`, `Carter's Freetraders (CFT) v3.2.3`, `Tri-Tac Special Circumstances (TTSC) v1.3.1` and `CJY's Toy Box`.
- `cleanedNames` is not only read by the fuzzy comparison. It also builds `nameBuckets` and `trigramIndex`, and it is handed to `_namesLookRelated`, the guard on the shared-forum-thread path. Shortening a name makes that guard *harder* to pass: on forum topic 25040, `Kon's Multi-Pack v.6.0.6 - 13th Battlegroup Player Faction` and `Kon's Player Faction Bundles` merge today and stop merging, because the shortened name shares only 2 of its 11 three-letter pieces with the other one.

Comparing both readings removes both problems at the root, and it removes them for every future case too — not just the eight found by replaying one data set. Because the scraped names are still compared first and on their own terms, no change to the cleaner can ever take a merge away.

**Cost:** a second `compareToFindBestMatch` call for candidate pairs that fail on their scraped names and whose names the cleaner changed. Guarding on "did the cleaner change anything" keeps this off the great majority of pairs, since most names carry no version noise at all.

**Alternative considered:** cleaning inside `_prepForMatching`. Rejected because `_prepForMatching` is also used for author names and is a pure character-level transform; mixing in structural regex logic would muddy it, and it would replace rather than add a reading.

### 2. The regex

```
^(?:\[[^\]]*\]\s*)?(.*?)(?:\s*[(\[]?[vV]?\.?\d+\.\d+.*)?$
```

Three parts:
1. `(?:\[[^\]]*\]\s*)?` — an optional leading bracketed tag.
2. `(.*?)` — the mod name, captured lazily.
3. `(?:\s*[(\[]?[vV]?\.?\d+\.\d+.*)?$` — optional version tail: an optional opening bracket or paren, optional `v`/`V`, optional dot, then `digits.digits` and everything after.

After the regex, trim trailing separators (`-`, `–`, `|`, `:`, `,`, whitespace) from the captured group.

If the regex doesn't match or the capture is empty, return the original name unchanged.

Two things this regex is known **not** to do well. Neither costs a merge under decision 1, so neither blocks the change:

- **It cuts at the first `digits.digits`, not the last**, so a version in the middle of a title takes the rest of the title with it (`Substance.Abuse 1.1.c - Consumable Alcohol` → `Substance.Abuse`). Under decision 1 that pair still matches on its scraped names.
- **It only recognises a version marker glued to the digits**, so markers written as a separate word survive: `Agrean Breakers, ver 3.0` → `Agrean Breakers, ver`, `Enhanced Sprites v. 0.08 + Hull Livery` → `Enhanced Sprites v.`, `Carter's Freetraders - V 3.2.4` → `Carter's Freetraders - V`. Five pairs in the pre-merge data would match if the marker were trimmed too and do not. Worth a follow-up (allow `\s*` before the digits, accept `ver`/`ver.`, and trim a dangling marker word), but it costs opportunities, not correctness.

Note also that the trailing-separator trim does **not** affect matching: `_prepForMatching` deletes every non-letter straight afterwards. It exists so the stripped name reads properly in the merge explorer.

### 3. Applied to all sources, not just Discord

The function runs on every mod name, not only Discord entries. The regex is a no-op on names with no version pattern (the lazy capture eats the whole string), so applying it uniformly avoids source-specific branching. Measured: 189 of the 887 names in the current `ModRepo.json` are changed by the cleaner, and none of the 165 newly-matching pairs it produces across the pre-merge data is a pair of different mods.

### 4. The candidate indexes stay on the names as scraped

`nameBuckets` and `trigramIndex` are built from `cleanedNames` and are left alone. This was checked rather than assumed: of the 165 pairs that newly match on the stripped reading, **all 165** are already offered to the pair check as candidates — 162 through trigram overlap on their scraped names, and the remaining 3 (Nexerelin, Caymon's Ship Pack, Custom LPCs) through the shared-forum-thread bucket.

This holds for a reason, not by luck: the stripped name's letters are a subset of the scraped name's letters, in order, so the plainer of two names always has nearly all of its three-letter pieces inside the noisier one — which is what the 40% trigram gate asks for.

Adding the stripped names to the indexes as extra keys would be safe (it only ever widens the candidate set), but on this data it buys nothing and costs 8.5% more candidate pairs to check. If a future case turns up that shares no forum thread and no trigram overlap, that is the change to make.

### 5. Stripped names in the debug output

The `MergeDebugCollector` records the original `ScrapedMod` objects, so those keep their raw names. `GroupMatchEntry` gains four fields:

- `outerStrippedName`, `innerStrippedName` — whatever `stripVersionNoise` returned for the two mods, always filled in. When the regex was a no-op the stripped name equals the original, which is the honest answer and needs no special-casing.
- `strippedNameScore`, `strippedNameLengthRatio` — the second comparison's score and ratio, or null when it wasn't run (the names as scraped already matched, or the cleaner changed nothing).

`nameScore` and `nameLengthRatio` keep their present meaning: the names as scraped. Old merge snapshots stay readable, and the two readings never get confused for each other.

`GroupMatchReason` gains `strippedNameAndAuthor` beside `nameAndAuthor`, so the merge explorer's match-reason line can say which reading did the work.

`GroupMatchEntry` and `GroupMatchReason` are `dart_mappable` types, so `merge_debug_data.mapper.dart` must be regenerated — this is a task, not an afterthought, because a missed regeneration drops the new fields silently with no compile error.

### 6. The same-source dedup safety check uses the same rule

`_deduplicateSameSourceByGameVersion` keeps only the newest game version per source within a group, guarded by a safety check that refuses to discard when the two names' cleaned lengths differ by more than 30%. That check reads the scraped names.

This change deliberately pulls version-decorated entries into groups with plainly-named ones, which is exactly when scraped names differ most. `Domain Historical Society-0.97 Achi edition (original edition attached below)` and `Domain Historical Society-0.98` are both Discord entries that will now share a group; their scraped cleaned names are 62 and 23 letters, a ratio of 0.37, so the safety check would block the dedup, log a warning, and file a "safety blocked" line in the merge explorer for what is plainly one mod.

So the safety check gets the same either-reading treatment: it passes when **either** the scraped names or the stripped names are within the 0.70 ratio. The two steps then agree about which names count as similar, which is the property that was quietly broken.

## Risks / Trade-offs

**[Risk: a wrong merge from over-stripping]** Two different mods could strip to the same base name and merge. → Checked on the pre-merge data: of the 165 newly-matching name pairs, none is a pair of different mods. The 0.85 ratio gate, the fuzzy comparison and the separate author check all still apply to the stripped reading — the change adds a second reading, it does not relax any test. The riskiest shape is a name that strips very short (`UNSF v1.0.0 - FULL RELEASE` → `UNSF`), where a short name against another short name passes the ratio gate easily; the author check is what stands behind it, as it already does for short names today.

**[Risk: the second comparison slows the merge]** → It only runs for candidate pairs that failed on their scraped names *and* whose names the cleaner changed. Most names carry no version noise, so the guard skips most pairs. Worth confirming against the "Total time to merge" line in the log before and after.

**[Risk: the leading-tag rule strips more than game versions]** `\[[^\]]*\]` removes any bracketed prefix, so 16 real names lose a `[WIP]`, `[Showcase/WIP]` or `[heavily WIP]` tag as well as the game-version tags it was written for. This is wanted — it lets `[WIP] Faces in the Void v0.5` match a released `Faces in the Void` — but it is wider than the name suggests, so the spec says so plainly and a test pins it.
