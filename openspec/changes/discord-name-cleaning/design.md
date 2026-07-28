## Context

The ModRepo merger groups mods from three sources (Forum Index, Discord, Nexus) into one entry per mod. Grouping compares cleaned names (`_prepForMatching`: lowercase, strip non-alpha) and checks a 0.85 length-ratio gate before accepting a fuzzy match. Discord thread titles often embed version numbers and subtitles — `Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."` — that inflate the cleaned name and block the ratio gate. 92+ Discord entries sit alone as a result.

The cleaning function in `mod_repo_utils.dart` already holds `_prepForMatching`, `compareToFindBestMatch`, and `splitAuthorNames`. The new function belongs there.

## Goals / Non-Goals

**Goals:**
- Strip version noise from mod names so the merger's fuzzy comparison and length-ratio gate see the base name, not the version-decorated Discord thread title.
- Change nothing about what is scraped, stored, or written to `ModRepo.json`. The cleaned name is used only inside the merger's comparison loop.
- Keep the regex simple enough to reason about and test against real data (470 current Discord names, plus the Forum/Index/Nexus names that don't carry version noise).

**Non-Goals:**
- Handling true renames (e.g. "Combat Analytics" → "Detailed Combat Results") — those need a different approach (overrides file or LLM), tracked separately in the known-hard-cases memory.
- Cleaning names at scrape time or changing the `ScrapedMod` model.
- Adding config keys or LLM calls.

## Decisions

### 1. Clean before `_prepForMatching`, not instead of it

The new function (`stripVersionNoise`) runs first and returns a string that `_prepForMatching` then lowercases and strips non-alpha. This keeps the two concerns separate: `stripVersionNoise` is about structure (removing version tails), `_prepForMatching` is about normalising characters.

The cleaned name replaces the raw `mod.name` in the `cleanedNames` map at line 60 of `mod_merger.dart`. The change is one line: `_prepForMatching(stripVersionNoise(mod.name))` instead of `_prepForMatching(mod.name)`.

**Alternative considered:** cleaning inside `_prepForMatching`. Rejected because `_prepForMatching` is also used for author names and is a pure character-level transform; mixing in structural regex logic would muddy it.

### 2. The regex

```
^(?:\[[^\]]*\]\s*)?(.*?)(?:\s*[(\[]?[vV]?\.?\d+\.\d+.*)?$
```

Three parts:
1. `(?:\[[^\]]*\]\s*)?` — optional leading game-version tag like `[0.97a]` or `[0.98a]`.
2. `(.*?)` — the mod name, captured lazily.
3. `(?:\s*[(\[]?[vV]?\.?\d+\.\d+.*)?$` — optional version tail: an optional opening bracket or paren, optional `v`/`V`, optional dot, then `digits.digits` and everything after.

After the regex, trim trailing separators (`-`, `–`, `|`, `:`, `,`, whitespace) from the captured group.

If the regex doesn't match or the capture is empty, return the original name unchanged — the function never makes a name worse.

### 3. Applied to all sources, not just Discord

The function runs on every mod name in the comparison loop, not only Discord entries. Reason: the regex is a no-op on names that don't contain version patterns (the lazy capture eats the whole string when there's no version tail), and applying it uniformly avoids source-specific branching. A Forum entry whose name happens to contain a version string (unlikely but possible) benefits too.

### 4. Stripped names in the debug output

The `MergeDebugCollector` records the original `ScrapedMod` objects, so those keep their raw names. Each `GroupMatchEntry` already carries `nameLengthRatio` and scores; it gains two new fields — `outerStrippedName` and `innerStrippedName` — holding whatever `stripVersionNoise` returned for the two mods being compared. When the regex was a no-op, the stripped name equals the original, so no special-casing is needed. The merge explorer on the website shows these alongside the existing match details.

## Risks / Trade-offs

**[Risk: over-stripping]** A mod name that legitimately contains `digits.digits` could lose its tail. Example: `Star Wars 2020 v1.0.4` → `Star Wars` (correct), but a hypothetical `Mod 1.5` could strip to `Mod`. → Mitigation: the regex requires `\d+\.\d+` (digits-dot-digits), so a bare number like `2020` or `21` doesn't trigger it. The smallest trigger is something like `1.0`, which is almost always a version string. We tested against all 470 current Discord names with no false strips.

**[Risk: under-stripping]** Some names put the version in an unusual format (e.g. `0.3.8f` with a trailing letter, or `rc11_t2`). The regex catches these because it requires only `\d+\.\d+` and then `.*` eats the rest. But a name using only a single-segment version (`v3`) would not be stripped. → Accepted: single-segment versions are rare and the name-length difference is small.

**[Risk: the regex runs on Forum/Index names that never needed it]** → No-op in practice. Tested: zero Forum/Index names in the current dataset are changed by the regex. If one were, it would still be a correct strip (versions don't belong in comparison names).
