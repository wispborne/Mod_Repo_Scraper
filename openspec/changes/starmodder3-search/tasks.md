# Tasks

## 1. The shared search module

- [x] 1.1 Create `site/search.js` with `searchTerms(mod)`: the thread title, the display name, the display name's slug words and their first-letter acronym, authors and `otherAuthorNames`, categories, summary, game version and mod version — all lowercased, cached per mod in a `WeakMap`. Use `modName` from `lib.js` for the display name; port Starmodder 3's slugify as written.
- [x] 1.2 Add `matchesSearch(mod, text)` to `search.js`: split on commas, trim, lowercase; "-term" is negative; a mod is listed when any positive term appears inside one of its search terms and no negative term does; all-negative queries subtract from everything; blank input matches everything.

## 2. The browse page

- [x] 2.1 In `site/views/browse.js`, delete `readSearch`, `searchableText` and the local `matchesSearch`; import `matchesSearch` from `search.js` instead. Check nothing else imported the deleted exports.
- [x] 2.2 Reword the hint under the search box to say commas mean any of these and a minus leaves mods out, with the two examples from the design.

## 3. The top-bar suggestions

- [x] 3.1 In `site/app.js`, rewrite `matchStrength` on top of `searchTerms`: name starts with the text (3), name contains it (2), any other term contains it (1).

## 5. The panel saying what the search understands

- [x] 5.1 Add `searchHelpField` to `site/lib.js`: one shared search box, `?` button and panel, used by every search box on the site. Word it to Starmodder's own template — an opening line saying what is searched, then a bold name, how it works, and the letters to type.
- [x] 5.2 Show the panel under the pointer (`:hover` on the whole box, as Starmodder does) and while the box is in use (`:focus-within`), and hide it when the pointer leaves and focus goes. Bridge the gap under the box so moving the pointer into the panel does not flick it away. Pressing the `?` puts the keyboard in it, since a press does not focus a button in every browser.
- [x] 5.3 Use it on all three boxes: Browse, Home, and the bar at the top. The one at the top passes `hideWhileTyping`, so the suggested mods get that room once there is something to suggest.
- [x] 5.4 Style `.search-field`, `.search-help-btn` and `.search-help` in `site/style.css` using only the existing colour, size and spacing names, matching how `.suggestions` is built. Anchor the top bar's panel to its right edge.
- [x] 5.5 Check it in the browser: on all three boxes it shows on focus, stays while typing, and goes on blur; the top one gives way to suggestions and comes back; it reads correctly in the light version and does not run off the side of a phone screen.

## 6. The plus and field search, as the original Starmodder has them

- [x] 6.1 In `site/search.js`, split each comma group on "+" into terms that must all match, keeping the minus working on the whole group.
- [x] 6.2 Add `matchesTerm`, which reads `key:value` and matches that field alone. Map only the fields the published list file carries; an unknown key falls through to an ordinary search.
- [x] 6.3 Point the top bar's suggestion ranking at `matchesTerm`, so a field search suggests mods there too.
- [x] 6.4 Put the AND and Field search lines back in the panel, worded as the original words them.
- [x] 6.5 Check against the real data: `hartley + abuse` finds the one mod, every field key returns a sensible count, an unknown key with a colon still finds the mod, and a lone "-" or "+" still lists everything.

## 7. Scoring and Best match, as the original Starmodder has them

- [x] 7.1 Give every term in `searchTerms` a cost, so a match on a category or the summary ranks below one on the name or a person.
- [x] 7.2 Add the initials taken again with the little words dropped, so "Ashes of The Domain" answers to both "aotd" and "ad".
- [x] 7.3 Score a term exact/starts-with/holds at 100/75/50 less its cost; a field asked about by name scores 100. Add the scores of terms joined by a plus; take the best of the comma groups.
- [x] 7.4 Add a "Best match" sort to Browse that is only offered while something is typed, is chosen automatically when a search begins, gives way to a sort the reader picks by hand, and steps aside when the box is emptied.
- [x] 7.5 Point the top bar's suggestions at the same score, so the two never disagree about which mod answers best.
- [x] 7.6 Check against the real data: the ranking is sensible, the sort appears and disappears with the search text, and a hand-picked sort survives further typing.

## 4. Checking it works

- [x] 4.1 Run `dart run bin/site_server.dart` and, on Browse with real data: "swp" finds Ship/Weapon Pack, "0.98" finds mods by game version, "faction, portrait" lists both kinds, "faction, -portrait" leaves the portrait ones out, "-portrait" alone lists everything else, and a lone "," or "-" lists everything.
- [x] 4.2 In the top-bar box: "swp" suggests Ship/Weapon Pack, a name-start match ranks above an author match, and the People suggestions still appear.
- [x] 4.3 Open the site with `?data=sample` to confirm the sample data still renders and searches.
- [x] 4.4 Run `dart test` to confirm nothing on the Dart side depended on what changed.
