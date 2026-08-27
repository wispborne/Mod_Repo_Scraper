## 1. Publish the mods the merge never saw

- [x] 1.1 In `_threadOnlyMods` (`lib/site/public_data_builder.dart`), keep building `publishedByTopic`, but walk the bundle's threads instead of that map, treating a thread nothing points at as having an empty published list.
- [x] 1.2 Apply the `mainMods.length < 2` early return only when a published mod points at the thread. Where none does, a single `main` mod is published.
- [x] 1.3 Leave the grounding checks, the sibling-name check and `_standInFor` exactly as they are — both kinds of thread go through the same code.
- [x] 1.4 Change the log line for a published thread mod to say whether the thread had a merged mod behind it, so a run's log tells the two apart.

## 2. Publish when the thread was last posted on

- [x] 2.1 Add the field to `PublicMod` and `PublicModDetail` in `lib/site/models/`, read from the thread's `lastPostDate` through `parseForumDate`, absent when there is no readable date and when the mod has no thread.
- [x] 2.2 Regenerate the mappers with `dart run build_runner build --delete-conflicting-outputs`.
- [x] 2.3 Add the field to `site/sample-data/` and to whatever `test/site/sample_data_test.dart` pins, which is where a model change has to be made twice.

## 3. Say which same-name mod is which

- [x] 3.1 Add an optional `id` to `PublicOlderVersion` so an entry can point at a page on the site instead of only out to the forum, and regenerate the mappers.
- [x] 3.2 Fill `PublicModDetail.olderVersions` in the builder from the same-name grouping — every other published mod whose name matches on the `modNamesMatch` comparison — with each one's authors, both versions, its thread's last post date and its id.
- [x] 3.3 In `site/views/mod.js`, rework the `olderVersions` panel: draw the authors and the thread's last post date alongside the versions, link to the mod's page on the site where the entry has an id and out to the forum where it does not, and change the heading from "Older versions" to wording that also fits a fork and two unrelated mods of one name.
- [x] 3.4 Move the panel high enough on the page that a reader arriving from outside meets it without scrolling past the downloads.
- [x] 3.5 Add whatever `site/style.css` needs, using only the names in the block at the top of the file.

## 4. Tests

- [x] 4.1 A thread no published mod points at, holding one `main` mod with a grounded name and a download: it is published, with a permanent id and `partOfThreadTitle` set to the thread's title.
- [x] 4.2 The same thread holding three `main` mods: all three are published.
- [x] 4.3 A thread no published mod points at that produces nothing — no `main` mod, or a name the post never writes, or a mod with no download: nothing is published.
- [x] 4.4 A thread no published mod points at whose only entries are `addon` or `variant`: nothing is published as a mod of its own.
- [x] 4.5 A thread mod whose cleaned name matches a merged mod published from a different thread: both are published, the merged mod keeps the plain id, the thread mod takes the numbered one, and each one's `olderVersions` names the other.
- [x] 4.6 A mod whose name nothing else shares publishes an empty `olderVersions`.
- [x] 4.7 The thread's last post date is published where the thread has a readable one, and absent for a relative date like "Today at 03:12:22 PM" and for a mod with no thread.
- [x] 4.8 The existing shared-thread cases still pass unchanged, in particular the single-`main`-mod thread where the merged mod's name looks nothing like the entry's ("Red" / "Red - the Oculian Armada").
- [x] 4.9 `dart test test/site/` is green, and `dart analyze` (or `mcp__idea__get_file_problems` if the CLI analyzer crashes) is clean on the changed files.

## 5. Check it against the real data

- [x] 5.1 Run the site build against the local `qb_data` and `outputs`, and count the mods added to `mods.json`. Expect about 173 against the 2026-08-26 data; a count far above that means a rule is not doing what it is written to do.
- [x] 5.2 Confirm topic 35651 publishes seven mods, that Kwin's Sector Industry Compilation, Farsight Drive and FSF Military Corporation take plain ids, and that Junk Pirates, Valkyrians, Blackrock Drive Yards and Stellar Networks take numbered ones while the originals keep their addresses.
- [x] 5.3 Confirm ExtendedControls, Custom Start, Ship Editor, Cult Of The Circle, ThirstSector and Nijigen Extend are published — the single-mod threads that motivated most of this.
  - All but Cult Of The Circle (topic 34120). Its post never writes its own
    name — only the thread title does — so the name-grounding rule leaves it
    out, which is the rule working as written.
- [x] 5.4 Confirm no help thread is published: check the run log for anything from topics 34015, 34066, 35353, 35415 or 35906.
- [x] 5.5 Confirm there are 35 same-name groups covering about 71 mods, and open a few of them — Scy, Diable Avionics, Junk Pirates, Kadur Remnant — to check each page names the others and the dates make the choice obvious.
  - 38 groups covering 77 mods against the data on disk on 2026-08-26, which
    holds 908 merged mods rather than the 926 this change was measured against.
- [x] 5.6 Confirm `mods.json` is still under 2 MB and note the new size in the change, since the margin is now the thing to watch.
  - 1,378 KB for 1,089 mods.
- [x] 5.7 Look at Browse's default view and note how many of the new mods land in it. About a hundred are expected, because they carry no game version and `browse.js` reads that as current. This is a number to record, not a thing to fix here.
  - 99 of the 181 mods read off a thread carry no game version.

## 6. Spec bookkeeping

- [ ] 6.1 The `public-site-data` and `public-site-pages` capabilities are not in `openspec/specs/` yet — they are defined by the in-flight `starmodder-4-public-site` and `publish-thread-only-mods` changes. Archive those two first, in that order.
- [ ] 6.2 Hand-apply this change's MODIFIED deltas into `openspec/specs/`, then archive with `--skip-specs`. `openspec archive` fails on MODIFIED deltas.
  - Blocked: `starmodder-4-public-site` still has nine unfinished tasks, so it
    cannot be archived yet, and this change's deltas cannot be applied until it
    and `publish-thread-only-mods` have been.
- [x] 6.3 Update the "A thread can be several mods" section of `CLAUDE.md`: the rule that only threads a published mod points at are read is no longer true, and the reason it was written — unvetted threads getting permanent addresses — is now carried by the grounding rules instead. Say why `isMod` is not the gate, so nobody reaches for it again, and write down that two mods of one name are both published with each page naming the other.
