## Context

The site's search lives in `site/search.js`. It came over from Starmodder 3 in the `starmodder3-search` change. Each mod gets a list of terms (name, name words, acronym, people, categories, summary, versions), each with a cost. A typed comma group is split on `+`, and each piece must appear, as typed, inside one term. Only lowercasing is done to either side.

That one rule causes most of the misses. The text `seeker unidentified contact` is not inside `seeker - unidentified contact`. 274 of the 1,089 published names have punctuation in them. The top-bar box also calls `scoreOfTerm` on the whole text instead of `scoreOfSearch`, so commas and minus signs mean nothing there. Its people list uses a third rule, a plain `includes`.

TriOS was checked for ideas. Its newer search (mods grid, viewers) splits on spaces, treats every word as required, keeps quoted text together and allows a minus on any word. It does no clean-up of punctuation. Its catalog search has the same bug as this site. Neither does anything about spelling mistakes.

The site has no build step and no server. Every file is fetched from its own origin, so a search library would have to be copied into the repo. The whole mod list (about 1,100 mods) is in memory, and the search runs on every key press.

## Goals / Non-Goals

**Goals:**

- Punctuation, accents, apostrophes and capitals never stop a match.
- Words can be typed in any order.
- Simple spelling mistakes in mod names and people's names are forgiven, without letting junk into ordinary searches.
- The best answer is listed first, and exact names win.
- Browse and the top-bar box give the same answers in the same order.
- The search can be tested in Node, with a large set of realistic searches against real mod records.

**Non-Goals:**

- Changing TriOS. Its catalog search has the same bug, and fixing it is a separate change.
- Searching text the list file does not carry, such as full descriptions or changelogs.
- Guessing at meaning: synonyms, "2nd" for "second", acronyms with the little words taken off the front, and so on.
- A search index built at publish time. The list is small enough to search directly in the browser.

## Decisions

### One clean-up function, used on both sides

`normalize(text)` runs on every term as it is built, and on every typed word. Its steps, in order:

1. Remove apostrophe-like characters (`'`, `’`, `‘`, `´`, `` ` ``). This has to happen before step 2, because Unicode decomposition turns `´` into a space plus a combining mark. That would leave "mepgear s" instead of "mepgears".
2. Decompose with `NFKD` and drop combining marks (`\p{M}`). This takes accents off and turns full-width letters into ordinary ones.
3. Lowercase.
4. Turn every run of characters that are not letters, digits or dots (`[^\p{L}\p{N}.]`) into a space.
5. Keep a dot only when there is a digit on each side of it. Every other dot becomes a space.
6. Squeeze repeated spaces into one, and trim the ends.

*Alternatives:*
- Keep only `a-z0-9`. Rejected, because a name in another script would vanish entirely.
- Turn every dot into a space. Rejected, because `0.98` would become two words and match "0 98" anywhere.

### Read the typed text once, then score each mod against it

`compileSearch(text, mods)` reads the typed text once and returns `{ isEmpty, score(mod) }`. A score below zero means "leave this mod out". The reading steps:

1. Split on commas that are not inside double quotes.
2. Inside each group, split on spaces and plus signs that are not inside quotes.
3. Read each piece as one of:
   - a minus word (a leading `-`)
   - a quoted phrase
   - a field term (`key:value`, where the key is known and the value is non-empty)
   - a plain word
4. Clean up plain words. A plain word that clean-up splits into several words becomes several plain words. A quoted phrase is cleaned up but stays as one phrase.

Browse and the top-bar box each compile once per redraw or key press, then call `score` once per mod. The old code read the text again for every mod.

Exports:
- `normalize`, `editDistance` and `readSearch`, which are useful in tests.
- `compileSearch`.
- `searchMods(mods, text)`: every mod with a score of zero or more, best first, ties broken by name and then id. When there is nothing to look for, it returns the mods in the order given, because Browse puts them in its own order.
- `suggestMods(mods, text, count)`.
- `peopleMatching(mods, text, count)`.

`scoreOfTerm`, `scoreOfSearch` and `matchesSearch` go.

*Alternative:* keep `scoreOfSearch(mod, text)` and read the text again each time. Rejected because it repeats work for every mod. Holding a compiled search also makes the top-bar box and Browse share the exact same code path.

### Scoring

Each mod's terms are built once, cleaned up, and cached in the existing `WeakMap`. The term list gains two things: the shown name with its spaces taken out, and each person's name with its spaces taken out. Costs stay as they are except the summary's, which goes from 30 to 40: name 0, name pieces 10, initials 0, person 0, category 20, version 20, summary 40. A word buried in a paragraph means least, and the higher cost leaves room below the name scores for close spellings (see below).

How one plain word scores against one term:

| How it matches | Score |
|---|---|
| The term is exactly the word | 100 − cost |
| The term starts with the word | 80 − cost |
| A word inside the term starts with the word | 70 − cost |
| The term holds the word somewhere | 50 − cost |

A word's score is its best score across all terms. A quoted phrase is scored the same way, with the whole phrase as the word. A field term scores 100 when it matches. A group's score is the sum of its words' scores, plus a bonus:

- +60 when the cleaned group (its plain words joined with spaces) equals the cleaned shown name or title. This is also checked with the spaces taken out of both sides.
- +40 when the shown name or title starts with the group.
- +30 when the group appears in order anywhere else inside the shown name or title.

The middle tier matters. Without it, "QoL Pack" and "Dark QOL" tie for `qol`, because both hold "qol" as a whole name word.

The best group wins. Minus words only rule mods out; they never add to a score.

### Shorthand

Measured against the real list of 1,089 mods, most community shorthand is already in the name, in one of four shapes:
- the start of the name (`nex`)
- initials (`kol`, `uaf`, `sotf`, `dme`, `thi`, `vic`, `tsc`)
- word starts run together (`indevo`, `grandcol`, `armaa`)
- capitals inside one word (`gl` for GraphicsLib)

Of 40 nicknames tried, 35 were found by the first three shapes. The five that were not are `ssp`, `brdy`, `uw`, `sws` and `gl`. The capitals rule fixes `gl`.

**Word starts run together** are checked by a small search over the cleaned name words. Try each word as a starting point. Take a non-empty start of that word, then a start of the next word, and so on, skipping stop words when needed, until the typed word is used up. Two limits keep it clean. Both were measured on the real list:

- The typed word must be three letters or more.
- Either every piece is one letter, or every piece but the last is two letters or more.

Without the second limit, `faction` found Fleet Action History ("f" + "action"), `nex` found Nijigen Extend, and `star` found Station Refitting. With it, the ordinary words tried (`pirate`, `portrait`, `faction`, `station`, `colony`, `weapon`, `fleet`, `pack`, `remnant` and others) found nothing new, apart from one stray each for `ships`, `mod` and `star`. Those score at the bottom.

A run of word starts scores 45. That is below every match on the name's own words (at least 50 for a full name term), so a mod whose name really holds the letters always comes first. A typed word that is exactly a mod's initials earns a +40 bonus, the same as a name starting with the search. That is what puts Tiandong Heavy Industries above Random Assortment of Things for `thi`, and still leaves the mod called "RAT" above Random Assortment of Things for `rat`.

**Capitals inside a word**: before lowercasing, a name is also split where a lowercase letter is followed by a capital ("GraphicsLib" becomes "Graphics Lib"). That gives a second set of name words and initials. The original words stay too, so nothing that matched before stops matching.

**Nicknames from the post** arrive on each mod's record as `nicknames`. The LLM reads them off the author's own post, and the extractor keeps one only when it stands as a whole word in the author's words, never only in a link address. That part is already built, outside this change, and it reaches the data as each topic is read again (`promptVersion` 21). The search adds each one as a term with the name's cost, so it scores and earns the exact-name bonus as the name does. Until the re-read has run, most records carry none, which is why the table below still matters.

**The nickname table** is `site/nicknames.js`: a plain object mapping a permanent mod id to a short list of nicknames. Each nickname is a term with the name's cost, so it scores and earns the bonus exactly as the name does. It is keyed by id, because ids never change. It is kept small on purpose: a nickname only goes in when the rules above cannot find the mod. It starts with:
- `ssp` for Starsector+
- `brdy` for both Blackrock Drive Yards mods
- `armaa` for Arma Armatura. The rules do find it, but Project MISTRAL's own name holds the word "ArmaA" and would outrank it.

The table lives in the site, not in `mods.json`, so it costs that file nothing. It needs no Dart change, and a test can load it.

*Alternatives:*
- **The mod's own game id** from `mod_info.json`. It is often the shorthand ("IndEvo", "brdy"), but the scraper never downloads mods, so the site doesn't have it.
- **Only the nicknames the LLM reads off the post**, with no table. That covers every mod whose post writes its own shorthand, but many don't. Starsector+'s post never calls itself "SSP", for example, so the table covers what no post writes.

### Close spellings, kept narrow

`editDistance(a, b)` counts single-letter insertions, deletions, substitutions, and swaps of two letters next to each other (optimal string alignment). It stops early once the answer goes over the limit.

A plain word is checked for close spellings only when all of these hold:

- it is five letters or longer
- it has no digits
- its first letter matches the first letter of the word it is compared with. Almost every typo keeps the first letter. Without this, `faction` is one letter from "action" and finds Fleet Action History.
- its best exact score against the mod's name terms and person terms is below zero

It is then compared with every word of the shown name, the title, and each person's names. It is compared with each whole word, and with the start of each longer word cut to the typed word's length. The limit is one mistake for five to seven letters and two for eight or more.

A close match scores 38 for one mistake and 34 for two. That is below every exact match on a name or person, which is at least 40 (a name piece held mid-word: 50 − 10). It is above a word found at the start of a word in the summary (70 − 40 = 30) and a word held mid-word in it (50 − 40 = 10). Only a summary that begins with the word (80 − 40 = 40) or is exactly the word (60) beats it, and real summaries almost never do.

*Alternatives considered:*

- **The "letters in order" fuzzy match** that `fuzzy/fuzzy.dart` uses. Measured on the real list, `tahlan` matched 11 names and 521 summaries. It also does nothing for word order.
- **Fuse.js.** It needs threshold tuning and works poorly on long text, and it would have to be copied into the repo.
- **Allowing close spellings only when no mod in the whole list matches the word exactly.** This would keep results cleaner, but it breaks a real case. One summary spells "Nexerellin", so typing that misspelling would never find Nexerelin. The gate is per mod and covers the name and people only. That gets the same cleanliness for common words, because those match names exactly anyway.

### Minus words, and groups made only of them

Within a group, minus words narrow that group. A group with no plain words is collected separately, and any mod it matches is removed from the final result. This keeps `faction, -portrait` working exactly as it does today. If no group has plain words, the search starts from every mod.

### Field values end at a space unless quoted

This copies TriOS. The alternative was letting a field value run to the next comma, as it does today. Then `author:wisp ships` would look for an author named "wisp ships". Since every field value is matched by "appears inside", `author:dark revenant` still finds Dark.Revenant's mods: "dark" matches the author, and "revenant" matches the author term too.

### The mod-name helpers move to a module with no browser code

`lib.js` reads `location` as soon as it loads, so `search.js` cannot be imported in Node while it imports `lib.js`. So `modName`, `otherNamesOf` and `everyOtherName` move to `site/mod_names.js`, which needs no browser. `lib.js` imports them from there and exports them again, so no other file changes. `search.js` imports only from `mod_names.js`.

### Tests run in Node from `dart test`

`test/site/search_test.mjs` uses `node:test`, like `address_test.mjs`. Node will not import a bare `.js` file from a folder with no `package.json` in every version, so the test loads the modules through `data:` addresses:

1. Read `mod_names.js` and turn it into a `data:` address.
2. Read `search.js` and replace its `./mod_names.js` import with that address.
3. Import the result.

`test/site/search_test.dart` runs it from `dart test`, the same way `address_test.dart` runs its test.

The test data, `test/site/search_fixture.json`, is 128 real records copied from the published `mods.json`, keeping only the fields the search reads. It includes:
- the cases from this change: the Seeker mods, apostrophes, accents, a long dash, dotted names, "Starsector+"
- several mods that share a name
- several mods by the same people

The tests use real records rather than made-up ones, because the bugs came from real names.

## Risks / Trade-offs

- **Matching each word on its own makes some searches wider.** A three-word search that used to need the exact phrase now matches any mod holding the three words separately. → The phrase bonus puts the mods holding the exact phrase first. Quotes are there for anyone who wants only the phrase.
- **Close spellings can let in a near-miss name.** → Only for words of five letters or more, only against name and person words, never for words with digits, never for minus words. They are always scored below an exact name match. The test file asserts that common words (`portrait`, `pirate`, `faction`, `ships`) bring in nothing that does not really hold the word.
- **The scoring numbers are hand-picked.** → The tests check orderings ("A above B"), not exact numbers, so the numbers can be tuned without rewriting tests.
- **Some expected results in the test file may turn out wrong** once the code runs, because they were written before the code. → When a test fails, first check whether the expectation or the code is wrong. If the expectation is wrong, change it and add a one-line comment saying why. Never loosen a test just to make it pass.
- **Speed.** About 1,100 mods × about 20 terms × a few words, on every key press. Close-spelling checks run only for words that missed the name, and they stop early. → Measure with the real list during implementation. The goal is well under 16 ms for a three-word search.
- **The `site-search` spec is not archived yet.** → Archive `starmodder3-search` before archiving this change. The memory note on this repo says `openspec archive` fails on MODIFIED deltas, so the spec changes may need applying by hand, then archiving with `--skip-specs`.

## Open Questions

- Should close spellings also be tried against category names? (`portriat` → Portraits and flags.) The plan is no: categories have their own chips. Revisit if readers ask for it.
