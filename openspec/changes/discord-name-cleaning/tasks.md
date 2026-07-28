## 1. The stripping function

- [ ] 1.1 Add `stripVersionNoise(String name)` to `lib/bot/scraper/mod_repo_utils.dart`. Regex: `^(?:\[[^\]]*\]\s*)?(.*?)(?:\s*[(\[]?[vV]?\.?\d+\.\d+.*)?$`. After capture, trim trailing `-`, `–`, `|`, `:`, `,`, and whitespace. Return the original name when the capture is empty.

## 2. Wire it into the merger

- [ ] 2.1 In `lib/bot/scraper/mod_merger.dart` line 59, change `_prepForMatching(mod.name)` to `_prepForMatching(stripVersionNoise(mod.name))`.
- [ ] 2.2 Add `outerStrippedName` and `innerStrippedName` fields to `GroupMatchEntry`. Populate them from the version-stripped names when building the debug pair entry. Show them in the merge explorer on the website.

## 3. Tests

- [ ] 3.1 Unit test `stripVersionNoise` with cases from the spec: version + subtitle (`Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."` → `Hazard Mining Incorporated`), leading tag (`[0.97a] Combat Docking Module v0.0.6` → `Combat Docking Module`), `v.` prefix (`Caymon's Ship pack v.1.2.4-...` → `Caymon's Ship pack`), no version (`Chatter Expansion Project` → unchanged), number-not-version (`Warhammer 40000: Banished Imperium 1.0` → `Warhammer 40000: Banished Imperium`), empty result fallback (`v1.0.0` → `v1.0.0`).
- [ ] 3.2 Add a merge integration test: four HMI entries (the two Forum/Index ones and the two Discord ones from groups 330–332) merge into one group.
- [ ] 3.3 Run `dart test` — all existing tests still pass.
