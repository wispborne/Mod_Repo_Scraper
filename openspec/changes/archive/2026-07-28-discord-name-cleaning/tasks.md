## 1. The stripping function

- [x] 1.1 Add `stripVersionNoise(String name)` to `lib/bot/scraper/mod_repo_utils.dart`. Regex: `^(?:\[[^\]]*\]\s*)?(.*?)(?:\s*[(\[]?[vV]?\.?\d+\.\d+.*)?$`. After capture, trim trailing `-`, `–`, `|`, `:`, `,`, and whitespace. Return the original name when the regex doesn't match or the capture is empty. Build the `RegExp` once at the top of the file, not per call — it runs twice per mod.

## 2. Wire it into the merger as a second reading

- [x] 2.1 In `lib/bot/scraper/mod_merger.dart`, keep `cleanedNames[i] = _prepForMatching(mod.name)` **unchanged**, and fill a second map beside it in the same loop: `strippedNames[i] = _prepForMatching(stripVersionNoise(mod.name))`. Leave `nameBuckets`, `trigramIndex` and everything handed to `_namesLookRelated` on the scraped names — see design decisions 1 and 4.
- [x] 2.2 Pull the length-ratio test out into a small helper (it is written out four times once the second reading exists).
- [x] 2.3 In the pair loop, compare the scraped names first, exactly as now. Only when that fails, and only when `outerStripped != outer || innerStripped != inner`, run the second `compareToFindBestMatch` on the stripped names and apply the same 0.85 ratio gate to them. The name test passes if either reading passed. Feed whichever reading matched into `doNameAndAuthorMatch`; the author check is unchanged and still applies.
- [x] 2.4 In `_deduplicateSameSourceByGameVersion`, apply the same either-reading rule to the 0.70 safety check, so it stops blocking dedups for the entries this change newly groups (design decision 6).

## 3. Debug output

- [x] 3.1 Add `outerStrippedName`, `innerStrippedName` (always filled), `strippedNameScore` and `strippedNameLengthRatio` (null when the second comparison didn't run) to `GroupMatchEntry` in `lib/bot/scraper/debug/merge_debug_data.dart`. Leave `nameScore` and `nameLengthRatio` meaning the names as scraped.
- [x] 3.2 Add `strippedNameAndAuthor` to the `GroupMatchReason` enum, and set it instead of `nameAndAuthor` when the stripped reading is what matched.
- [x] 3.3 Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `merge_debug_data.mapper.dart`. Without this the new fields are silently missing from `merge-debug.json` and every merge snapshot, with no compile error to point at it.
- [x] 3.4 In `web/views/merge.js`, handle the new reason in `matchReason()`: a "Name+Author (version stripped)" badge showing the stripped name of each side plus its score and ratio. Old snapshots have neither the reason nor the fields, so read them defensively — the existing `!= null` style is right.

## 4. Tests

- [x] 4.1 Unit test `stripVersionNoise`: version + subtitle (`Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."` → `Hazard Mining Incorporated`), leading game-version tag (`[0.97a] Combat Docking Module v0.0.6` → `Combat Docking Module`), leading non-version tag (`[WIP] Arcahv Empire` → `Arcahv Empire`), `v.` prefix (`Caymon's Ship pack v.1.2.4-...` → `Caymon's Ship pack`), no version (`Chatter Expansion Project` → unchanged), number-not-version (`Warhammer 40000: Banished Imperium 1.0` → `Warhammer 40000: Banished Imperium`), empty result falls back (`v1.0.0` → `v1.0.0`).
- [x] 4.2 Unit test the two known weaknesses, so they are recorded as decisions rather than surprises: a version mid-title takes the tail with it (`Substance.Abuse 1.1.c - Consumable Alcohol` → `Substance.Abuse`), and a spaced marker survives (`Agrean Breakers, ver 3.0` → `Agrean Breakers, ver`).
- [x] 4.3 Merge test: the four HMI entries (the Forum/Index pair and the Discord pair from groups 330–332) become one group.
- [x] 4.4 **Regression tests — these are the point of the design.** Each of these merges today and must still merge: `Substance.Abuse - Consumable Alcohol` with `Substance.Abuse 1.1.c - Consumable Alcohol`; `SSMSControllerEx - Controller Support` with `[0.98a]SSMSControllerEx v1.1 - Controller support`; and, sharing forum topic 25040, `Kon's Multi-Pack v.6.0.6 - 13th Battlegroup Player Faction` with `Kon's Player Faction Bundles`. The last one goes through the shared-forum-thread path, so it pins that `_namesLookRelated` still sees the scraped names.
- [x] 4.5 Merge test: two Discord entries of one mod whose scraped names differ wildly in length (the Domain Historical Society pair) end up in one group **and** the same-source dedup keeps only the newer game version, rather than being blocked by the safety check.
- [x] 4.6 Run `dart test` — all existing tests still pass. `test/mod_merger_test.dart` already covers "Known Skies" vs "Unknown Skies" and "ApproLight" vs "ApproLight Plus" staying separate; those are the guard against the second reading being too loose.

## 5. Check it against real data

- [x] 5.1 Run a merge with `modrepo_merge_debug=true` over the current caches and compare the group count and `ModRepo.json` against the previous run in the Bundle diff / ModRepo diff views. Expect groups to fall by roughly the number of newly-joined pairs and nothing to split apart.
- [x] 5.2 Compare the "Total time to merge" line before and after, to confirm the second comparison hasn't slowed the merge noticeably (design risk 2).
