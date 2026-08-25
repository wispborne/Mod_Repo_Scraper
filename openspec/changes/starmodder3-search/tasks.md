# Tasks

## 1. The shared search module

- [ ] 1.1 Create `site/search.js` with `searchTerms(mod)`: the thread title, the display name, the display name's slug words and their first-letter acronym, authors and `otherAuthorNames`, categories, summary, game version and mod version — all lowercased, cached per mod in a `WeakMap`. Use `modName` from `lib.js` for the display name; port Starmodder 3's slugify as written.
- [ ] 1.2 Add `matchesSearch(mod, text)` to `search.js`: split on commas, trim, lowercase; "-term" is negative; a mod is listed when any positive term appears inside one of its search terms and no negative term does; all-negative queries subtract from everything; blank input matches everything.

## 2. The browse page

- [ ] 2.1 In `site/views/browse.js`, delete `readSearch`, `searchableText` and the local `matchesSearch`; import `matchesSearch` from `search.js` instead. Check nothing else imported the deleted exports.
- [ ] 2.2 Reword the hint under the search box to say commas mean any of these and a minus leaves mods out, with the two examples from the design.

## 3. The top-bar suggestions

- [ ] 3.1 In `site/app.js`, rewrite `matchStrength` on top of `searchTerms`: name starts with the text (3), name contains it (2), any other term contains it (1).

## 4. Checking it works

- [ ] 4.1 Run `dart run bin/site_server.dart` and, on Browse with real data: "swp" finds Ship/Weapon Pack, "0.98" finds mods by game version, "faction, portrait" lists both kinds, "faction, -portrait" leaves the portrait ones out, "-portrait" alone lists everything else, and a lone "," or "-" lists everything.
- [ ] 4.2 In the top-bar box: "swp" suggests Ship/Weapon Pack, a name-start match ranks above an author match, and the People suggestions still appear.
- [ ] 4.3 Open the site with `?data=sample` to confirm the sample data still renders and searches.
- [ ] 4.4 Run `dart test` to confirm nothing on the Dart side depended on what changed.
