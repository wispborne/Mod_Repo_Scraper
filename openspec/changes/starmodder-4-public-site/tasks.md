Stage 1 must be finished first. Stages 2, 3, 4 and 5 can then be worked on at the same
time, in any order — they share no files. Stage 6 needs 2, 3 and 4 done. Stage 7 is the
final check.

## 1. Shapes and sample files (do this first, nothing else can start without it)

- [x] 1.1 Add `lib/site/models/public_mod.dart` — the record that goes in `mods.json`: permanent id, name, authors, categories, game version, mod version, one image, one-line summary, save compatible, has direct download, source is public, is work in progress, last release date
- [x] 1.2 Add `lib/site/models/public_mod_detail.dart` — the record that goes in `mods/<id>.json`: everything from the list record plus description, image gallery, downloads with kind and file name, changelog by version, license, source code link, support links, forum/Discord/Nexus links, release history, older versions
- [x] 1.3 Add `lib/site/models/mod_release.dart` — one entry in `updates.json`: mod id, mod name, day seen, old version, new version, game version, changelog notes
- [x] 1.4 Mark LLM-written text on both mod records, so the site can tell copied words from generated ones
- [x] 1.5 Run `dart run build_runner build --delete-conflicting-outputs` and commit the generated `.mapper.dart` files
- [x] 1.6 Write `site/sample-data/mods.json`, `site/sample-data/updates.json` and three `site/sample-data/mods/<id>.json` by hand, covering a full mod, a Discord-only mod and a mod with add-ons
- [x] 1.7 Add a test that every sample file parses back into its model without loss

## 2. Building the data files

- [x] 2.1 Add `lib/site/mod_id_store.dart` — reads and writes `qb_data/mod-ids.json`, hands out an id for a mod name it has not seen, never changes an id it has already given out
- [x] 2.2 Make the id worked out from a mod's name with the bracketed game version, the mod version and any trailing date stripped off
- [x] 2.3 Add a number on the end when a new mod's id is already taken, leaving the first mod's id alone
- [x] 2.4 Fail the run with a plain message when the id file exists but cannot be read, and publish nothing
- [x] 2.5 Add `lib/site/public_data_builder.dart` — joins merged mods to bundle threads on the forum topic id
- [x] 2.6 Fill the list record for every merged mod, taking the mod version, save compatibility and the rest from the bundle where there is a thread
- [x] 2.7 Fill the detail record for every merged mod, including the image gallery, downloads and changelog
- [x] 2.8 Handle mods with no forum thread — leave the bundle-only fields out rather than guessing
- [x] 2.9 On a multi-mod thread, use the main mod for the page and list the add-ons on it
- [x] 2.10 Strip everything internal: no config values, no tokens, no local paths, no run ids, no confidence scores
- [x] 2.11 Write `mods.json` and one `mods/<id>.json` per mod into `outputs/site/`
- [x] 2.12 Add a test that `mods.json` stays under 2 MB for the current mod set
- [x] 2.13 Add a test that no published field carries a local path or a config value
- [x] 2.14 Call the builder at the end of a run, after the bundle is published

## 3. Working out which mods released

- [x] 3.1 Add `lib/site/version_text.dart` — cleans a version string, and returns nothing for one that does not start with a number or holds more than one version
- [x] 3.2 Add version comparison that reads parts as numbers, counts a trailing letter as newer, and counts `rc`, `alpha`, `beta`, `pre` and `dev` as older
- [x] 3.3 Add tests for the comparison covering 3.5.2 against 3.5.2g, 1.0-rc1 against 1.0, and "0.99a BETA" against "0.99a"
- [x] 3.4 Add a check that throws out a version matching the thread's game version or the bracketed version at the front of the title
- [x] 3.5 Add a reader that pulls a version out of a thread title, ignoring the bracketed game version at the front
- [x] 3.6 Add `lib/site/release_state_store.dart` — holds each mod's believed version and how many scrapes in a row the current reading has held
- [x] 3.7 Add `lib/site/release_detector.dart` — advances the state by one bundle and returns any releases found
- [x] 3.8 Only believe a reading once it has held for two scrapes running
- [x] 3.9 Ignore a reading older than the believed version, and leave the believed version alone
- [x] 3.10 Drop a new version that disagrees with a version in the thread title; ignore the title when it has none
- [x] 3.11 Record no release the first time a mod's version is believed
- [x] 3.12 Write `updates.json`, newest first, with the changelog notes for that version where the post gave them
- [x] 3.13 Add tests for each rule, using small hand-made bundle pairs
- [x] 3.14 Add a test that a mod settling 1.3.3, then 1.3.2, then 1.3.3 again produces exactly one release
- [x] 3.15 Add `bin/backfill_releases.dart` — walks every saved bundle once to seed the state and fill the feed's history
- [x] 3.16 Run the backfill over the real saved bundles and check the result by hand against the mods' own threads
- [x] 3.17 Call the detector at the end of a run, after the bundle snapshot is saved

## 4. The site shell and the browse page

- [x] 4.1 Create `site/` with `index.html`, `app.js`, `lib.js` and `style.css`, plain ES modules and no build step
- [x] 4.2 Add routing so every page has its own address, and reading data comes only from fetching published files
- [x] 4.3 Point the site at `site/sample-data/` while the real files do not exist yet
- [x] 4.4 Build the browse page: grid of cards and a row list, the reader's choice, kept between visits
- [x] 4.5 Add search over name, authors and their other known names, categories and description
- [x] 4.6 Support several search terms separated by commas, and a leading minus to leave matches out
- [x] 4.7 Add filters for game version, category and author
- [x] 4.8 Add switches for save compatible, has a direct download, source is public, and hide works in progress
- [x] 4.9 Add sorting by name, by newest, and by most recently updated
- [x] 4.10 Keep the search text, filters, sort and page number in the address, and read them back on load
- [x] 4.11 Show a plain message and a way to clear the filters when nothing matches
- [x] 4.12 Show when the data was last collected, on every page
- [x] 4.13 Make every page work on a phone with no sideways scrolling of the page itself
- [x] 4.14 Check no page offers any way to start a job or change anything
- [x] 4.15 Add the AI summaries checkbox, on by default, kept in a cookie, applying to cards, mod pages and author pages
- [x] 4.16 Leave a mod's description out entirely when summaries are off and the only description was AI-written
- [x] 4.17 Fetch every data file from the site's own origin, never from GitHub or any other host
- [x] 4.18 Check nothing uses Cloudflare Workers, Pages Functions or Cloudflare redirect rules

## 5. Publishing and hosting

- [x] 5.1 Copy `mods.json`, `updates.json` and every `mods/<id>.json` into the published repo clone during a publish job
- [x] 5.2 Remove any `mods/<id>.json` in the clone that this run did not produce
- [x] 5.3 Copy the contents of `site/` into the clone, so the pushed repo can be served as the website with no further step
- [x] 5.4 Keep publishing `ModRepo.json` and `forum-data-bundle.json` exactly as before, in the same commit
- [x] 5.5 Publish the existing outputs as normal, with a line in the log, when the website files are not there
- [x] 5.6 Add a test that a publish with no website files still publishes the existing outputs
- [x] 5.7 Add a test that a mod dropped since the last publish has its file removed
- [x] 5.8 Add a test that the pushed layout puts each data file where the site asks for it
- [ ] 5.9 Point Cloudflare Pages at the published repo, serving the root as the site
- [ ] 5.10 Check a push updates the live site, and that the site fetches its data from its own origin
- [x] 5.11 Note in the README how to serve the same repo from an ordinary web server instead

## 6. The remaining pages (needs stages 2, 3 and 4)

- [x] 6.1 Point the site at the real published files instead of the samples
- [x] 6.2 Build the home page: releases newest first, grouped by day, each showing mod name and new version
- [x] 6.3 Let a release row open to show that version's changelog notes, where there are any
- [x] 6.4 Add the search box and a strip of recently added mods to the home page
- [x] 6.5 Say so plainly when there are no releases yet, and still show search and recently added mods
- [x] 6.6 Build the mod page at its permanent address: name, authors, version, game version, save compatibility
- [x] 6.7 Add download buttons, screenshots and description to the mod page
- [x] 6.8 Add the changelog by version to the mod page
- [x] 6.9 Add links out to the forum thread, Discord, Nexus and source code, plus the license and any support links
- [x] 6.10 Leave a section out entirely when the mod has nothing for it, rather than showing it empty
- [x] 6.11 Mark any summary the LLM wrote rather than copied, and hide it when the AI summaries checkbox is off
- [x] 6.12 Add the older versions list to the mod page, empty until old-thread matching exists
- [x] 6.13 Build the author page: every mod credited to one person, with their other known names folded in
- [x] 6.14 Link the author name on a mod page to that author's page

## 6b. What the pages show, and getting around (from the revamp read on 19 August 2026)

Opening the site against the real 906-mod data showed the layout holding up and the
content letting it down: names full of thread-title noise, Discord announcements
standing in for forum posts, donation buttons listed as screenshots.

- [x] 6b.1 Publish a tidied `displayName`, keep the raw title, and sort the list by the tidied name
- [x] 6b.2 Take the description from the forum post, published as a safe subset of its HTML
- [x] 6b.3 Turn bare addresses into links, and let long ones break on a phone
- [x] 6b.4 Drop a summary that is only a link, only emphasis marks, or only a list of requirements
- [x] 6b.5 Keep buttons, badges, avatars, icons and tiny pictures out of the gallery
- [x] 6b.6 Start every page at its top, except coming back to the same Browse list
- [x] 6b.7 Give release rows a chevron and "Read the notes", and drop the "no notes" label
- [x] 6b.8 Clamp a card's summary to three lines so a grid row cannot be stretched by one mod
- [x] 6b.9 Put one search box in the bar at the top, with suggestions and the "/" key
- [x] 6b.10 Default Browse to current game version first, with older ones behind a switch
- [x] 6b.11 Fold game versions that differ only in spelling into one filter choice
- [x] 6b.12 Drop the author dropdown and add a people index at `#/authors`
- [x] 6b.13 Add an About page and a "something wrong?" link at the foot of every mod page
- [x] 6b.14 Show "Updated N days ago" on cards, and colour the game version badge by how current it is
- [x] 6b.15 Show the mod's picture beside its release on Home, and the first letter where there is no picture
- [x] 6b.16 Show "Last checked" next to the download on a mod page
- [x] 6b.17 Add a skip link and a visible focus ring, and `aria-pressed` on the filter switches

## 7. Finishing up

- [x] 7.1 Check by hand that `ModRepo.json` and `forum-data-bundle.json` are unchanged by all of this
- [ ] 7.2 Run a full scrape and publish end to end, and open the site against the real files
- [ ] 7.3 Read the first week of the release feed against the mods' own threads and note anything wrong
- [x] 7.4 Update `CLAUDE.md` with the new files, the site folder and the release rules
- [x] 7.5 Add the new config keys, if any, to `config.example.properties` and `Common._recognizedKeys`
