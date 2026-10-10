## Why

The public site's search can't find "Seeker - Unidentified Contact" when somebody types `seeker unidentified contact`. Everything typed is treated as one piece of text, and that text must appear exactly, letter for letter, inside one fact about a mod. So the " - " in the name is enough to hide it. 274 of the 1,089 published names contain punctuation (dashes, slashes, apostrophes, dots, long dashes, accents), so the same miss happens all over the site. On top of that, words must be typed in the order the name uses them, a single spelling mistake finds nothing, and the box in the top bar handles commas, plus signs and minus signs differently from Browse.

## What Changes

- What the reader types and every fact about a mod are cleaned up the same way before they are compared. Capitals, accents, apostrophes and punctuation stop mattering: `amazighs` finds "Amazigh's Ship Foundry", `espanol` finds "Starsector en Español", and `seeker unidentified contact` finds the Seeker mod.
- Spaces separate words, and every word must match, in any order. `battlestar portrait` finds "Battlestar Galactica - Portrait Pack". Each word must still sit inside one fact, so the end of one field never runs into the start of the next.
- Double quotes keep a phrase together: `"unknown contact"` must appear exactly as written, after the clean-up.
- A minus in front of any word leaves out mods that match it, as TriOS's newer search does: `seeker -author:tartiflette`. A comma group made only of minus words still takes mods out of the whole list, so `faction, -portrait` keeps working.
- A plus now means the same as a space. Old links that use it keep working, but the help panel no longer offers it.
- A close spelling is found when a word does not match a mod's name or people exactly: `nexerlin`, `tahaln` and `tartiflete` all find their mod. This only applies to words of five letters or more, only against the words of mod names and people's names, and never to numbers.
- Common shorthand finds the mod:
  - initials: `kol`, `uaf`, `sotf`
  - the start of each word run together: `indevo` for Industrial.Evolution
  - capitals inside a name: `gl` for GraphicsLib
  - the other names the author's own post uses for the mod, which the LLM now reads off the post and the site publishes as `nicknames` (done already, outside this change): "Formerly known as the Pirate Collection" makes `pirate collection` find Yunru's Pirates and Pathers
  - a small hand-kept nickname table for the few that none of those gives away: `ssp` for Starsector+, `brdy` for Blackrock Drive Yards
- Ranking improves:
  - A mod whose name is exactly what was typed comes first.
  - A name holding the whole search in order comes next.
  - A match at the start of a word beats one in the middle of a word.
  - A close spelling of a name beats a word buried in a summary.
- A mod's name and each person's name can also be matched with the spaces taken out, so `shipweapon` finds "Ship/Weapon Pack" and `darkrevenant` finds Dark.Revenant's mods.
- The box in the top bar uses exactly the same search as Browse, including commas, minus signs and quotes. Its list of matching people uses the same clean-up.
- Field searches (`author:`, `version:` and the rest) use the same clean-up, so `author:dark revenant` and `author:Dark.Revenant` give the same answer.
- **BREAKING** (small): a field term's value now ends at the next space unless it is quoted. `author:dark revenant` used to mean one author name. Now it means "credited to someone with *dark* in their name, and *revenant* somewhere". On the real data that gives the same mods.
- **BREAKING** (small): a minus at the start of a comma group with several words now leaves out only the word it sits on, not the whole group.
- The help panel describes the new rules.
- A large test file pins all of this down, using real mod records and searches people actually type.

TriOS is not changed by this. Its catalog search has the same bug, and fixing it is a separate change.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `site-search`: how a typed search is read and matched. This covers clean-up, word-by-word matching, quotes, minus words, close spellings, ranking, the top-bar box, people suggestions and the help panel. The capability was set up by the `starmodder3-search` change, which is finished but not archived yet. Archive that one first so `openspec/specs/site-search/spec.md` exists for this delta to apply to.

## Impact

- `site/search.js`: mostly rewritten. It gains `normalize`, `editDistance`, `compileSearch`, `searchMods`, `suggestMods` and `peopleMatching`. `scoreOfTerm`, `scoreOfSearch` and `matchesSearch` are replaced.
- `site/nicknames.js` (new): the nickname table, keyed by permanent mod id.
- `site/mod_names.js` (new): `modName`, `otherNamesOf` and `everyOtherName` move here from `lib.js`, so the search can be loaded without a browser. `lib.js` still exports all three, so nothing else changes.
- `site/app.js`: the top-bar box and its people list use the shared search.
- `site/views/browse.js`: filtering and Best match use the compiled search, and the hint under the box is reworded.
- `site/lib.js`: the help panel's lines.
- `test/site/search_test.mjs` (new), `test/site/search_fixture.json` (new, 128 real mod records from the published list), and `test/site/search_test.dart` (new, runs the Node test from `dart test`, like `address_test.dart`).
- `CLAUDE.md`: a short note on the search under the public website section.
- No data files, pipeline code or viewer code change.
