## 0. Before starting

- [x] 0.1 Archive the finished `starmodder3-search` change, so `openspec/specs/site-search/spec.md` exists for this change's spec to apply to. If `openspec archive` fails on its spec, apply the spec by hand and archive with `--skip-specs`.

## 1. Make the search loadable without a browser

- [x] 1.1 Create `site/mod_names.js` holding `modName`, `otherNamesOf` and `everyOtherName`, moved out of `site/lib.js` with their comments. This file must not use any browser code.
- [x] 1.2 In `site/lib.js`, import the three from `mod_names.js` and export them again, so every other file keeps importing them from `lib.js` unchanged.
- [x] 1.3 Point `site/search.js` at `mod_names.js` instead of `lib.js`, and create an empty `site/nicknames.js` so the test file can load.
- [x] 1.4 Add `test/site/search_test.dart`, which runs `node --test test/site/search_test.mjs` the same way `address_test.dart` runs its test.
- [x] 1.5 Run it and confirm the test file loads and fails on the missing exports. Nothing should break before the search itself is reached.

## 2. The clean-up and the edit distance

- [x] 2.1 Add `normalize(text)` to `site/search.js` with the six steps in the design, in that order. Apostrophes come out before Unicode decomposition. A dot is kept only between two digits.
- [x] 2.2 Add `editDistance(a, b, limit)`, counting a swap of two letters next to each other as one mistake. It stops early once the answer is over `limit`.
- [x] 2.3 Run the `normalize` and `editDistance` groups of `search_test.mjs` until they pass.

## 3. Reading what was typed

- [x] 3.1 Rewrite `readSearch(text)`:
  - split on commas outside quotes
  - split each group on spaces and plus signs outside quotes
  - read each piece as a minus word, a quoted phrase (an unclosed quote runs to the end of the group), a known field term, or a plain word
  - clean up each piece, splitting a plain word into several where clean-up does
  - drop pieces that clean to nothing
- [x] 3.2 A field term reads its key ignoring capitals, and takes a quoted value. An unknown key, or a known key with an empty value, falls through to plain words.

## 4. Terms and scoring

- [x] 4.1 Build each mod's terms already cleaned up, and add the name with its spaces taken out and each person's name with its spaces taken out. Raise the summary's cost to 40. Keep the `WeakMap` cache.
- [x] 4.2 Score a plain word against a term: exact, starts with, a word inside starts with, holds. Score a quoted phrase the same way as one word. Score a field term at 100 when the cleaned value is inside any cleaned field value.
- [x] 4.3 Add close spellings, under the rules in the design: five letters or more, no digits, the first letter right, only when the word misses the name and people terms, compared with whole name and person words and with the start of each longer word. Score 38 for one mistake and 34 for two.
- [x] 4.4 Add shorthand:
  - split names at capitals inside a word, as a second set of name words
  - add word starts run together, with the two limits in the design (three letters or more; all single letters, or every piece but the last two letters or more), scoring 45
  - give an exact match on a mod's initials a +40 bonus
- [x] 4.5 Create `site/nicknames.js` with `ssp` for `starsector`, `brdy` for `blackrock-drive-yards` and `blackrock-drive-yards-2`, and `armaa` for `arma-armatura`. Add each nickname from the table, and each one in the mod's own `nicknames` field, as a term with the name's cost.
- [x] 4.6 Add the group bonus: +60 when the group is exactly the shown name or title (with or without spaces), +40 when the name or title starts with it, +30 when it appears in order anywhere else inside.
- [x] 4.7 Add `compileSearch(text, mods)` returning `{ isEmpty, score(mod) }`. Minus words narrow their own group, and groups made only of minus words remove mods from the whole result. With only minus groups, start from every mod.
- [x] 4.8 Add `searchMods(mods, text)`: best first, ties broken by name and then id. With nothing to look for, return the mods in the order given. Never change the list passed in.
- [x] 4.9 Remove `scoreOfTerm`, `scoreOfSearch` and `matchesSearch`. Check nothing else in `site/` still imports them.
- [x] 4.10 Run the whole of `search_test.mjs`. When a test fails, decide whether the expectation or the code is wrong. If the expectation is wrong, fix it and add a one-line comment saying why. Never loosen a test just to make it pass.

## 5. The two search boxes

- [x] 5.1 Add `suggestMods(mods, text, count)`. It gives nothing when no plain word was typed, or when what was typed cleans to fewer than two characters. Otherwise it gives the first `count` of `searchMods`.
- [x] 5.2 Move the people list into `search.js` as `peopleMatching(mods, text, count)`. It looks only at credited authors, matches the cleaned name or the name with spaces taken out against every plain word, keeps one entry per cleaned name, and sorts by name.
- [x] 5.3 In `site/app.js`, replace `matchStrength`, the hand-written filter and sort, and the old `peopleMatching` with `suggestMods` and `peopleMatching` from `search.js`.
- [x] 5.4 In `site/views/browse.js`, compile the search once per redraw and use that one compiled search for the filter, the result count, the "older releases" count and the Best match sort. Do not read the text again for every mod.
- [x] 5.5 Reword the hint under Browse's search box: every word must match in any order, commas list either, and a minus leaves mods out.
- [x] 5.6 Update `WAYS_TO_SEARCH` in `site/lib.js`. It needs lines for words in any order, exact phrases in quotes, commas, the minus, acronyms, versions, close spellings and field search. Drop the plus line.

## 6. Check it for real

- [x] 6.1 Run `dart run bin/site_server.dart` and try, in both the top bar and Browse:
  - `seeker unidentified contact`
  - `amazighs`
  - `espanol`
  - `battlestar portrait`
  - `nexerlin`
  - `"unknown contact"`
  - `seeker -author:tartiflette`
  - `faction, -portrait`
  - `author:dark.revenant`
  - `indevo`, `kol`, `uaf`, `gl` and `ssp`
  - a lone `-`, `+` and `"`
- [x] 6.2 Time a three-word search and a close-spelling search against the full real list in the browser. The aim is well under 16 ms each. If not, cache each mod's name words for the close-spelling check.
- [x] 6.3 Open the site with `?data=sample` and confirm the sample data still renders and searches.
- [x] 6.4 Run `dart test` to confirm the new Node test runs from it and nothing else broke.

## 7. Write it down

- [x] 7.1 Add a short entry on the search to the public website section of `CLAUDE.md`. It should cover:
  - the shared clean-up
  - words in any order
  - quotes
  - minus words versus minus groups
  - the narrow close-spelling rule and why it stays narrow
  - the shorthand rules, and that the nickname table is only for names the rules cannot find
  - the one module both boxes use
  - where the tests and their real-record fixture live
- [x] 7.2 Check the About page and any other page that describes the search, and bring their wording in line.
