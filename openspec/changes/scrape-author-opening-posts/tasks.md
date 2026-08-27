# Tasks

## 1. Model and scraper

- [x] 1.1 Add `QbForumPost` to `lib/bot/scraper/qb/models/mod_detail.dart` (contentHtml, images, links, postDate, lastEditDate) and `extraPosts` (default `[]`) to `QbModDetail`; run `dart run build_runner build --delete-conflicting-outputs`
- [x] 1.2 `topic_scraper.dart`: collect all `#forumposts .windowbg/.windowbg2` posts in order; keep consecutive same-author follow-ups (cap 10) as `extraPosts`, reusing the first-post extraction helpers per post; first-post handling unchanged
- [x] 1.3 `scraper_engine.dart`: run `HtmlProcessor.processHtml` over each extra post's HTML; pass the union of first-post and extra-post links to download resolution; extend the board-3 file-hosting gate to consider extra-post links
- [x] 1.4 Tests: opening-run selection (reserved second post kept, other-author stops the run, cap), old detail JSON without the field reads as empty list

## 2. LLM extraction

- [x] 2.1 `post_reducer.dart` / `post_extractor.dart` / `prompt.dart`: reduce each opening post; build ONE user prompt per topic — first post, then each follow-up under its own heading, with links/rule-links/images merged across posts; fingerprint covers the whole input (falls out of the prompt-based fingerprint)
- [x] 2.1a Apply `maxInputChars` to the combined body: follow-up posts keep their text in full, the first post's body is trimmed to the remaining budget, and the trim is logged naming the post that was cut
- [x] 2.2 Extend grounding collectors (`_postUrls`, `_postImages`, `_postRepoUrls`, `_checkAgainstPost`) over all opening posts
- [x] 2.3 `prompt.dart`: describe follow-up posts; add `descriptionAnchors` (opening/closing words, one contiguous section, one post) to the schema and field set; bump `promptVersion`
- [x] 2.4 Parse and ground anchors in the extractor (letters-and-digits match, same post, in order); store on the LLM mod model (+ mapper regen)
- [x] 2.5 Tests: one call per topic regardless of post count, URL in second post grounds, URL in nobody's post drops, anchors ground/drop/span-posts cases, changed second post re-extracts, over-budget first post is trimmed while follow-ups survive intact

## 3. Bundle, snapshots, diffs

- [x] 3.1 `bundle_publisher.dart`: emit `extraPosts` per detail with `stripSessionIds` and blank `localPath`; `contentHtml` untouched
- [x] 3.2 `bundle_snapshot_store.dart` and `viewer/working_bundle.dart`: replace each extra post's HTML with a fingerprint, same function as the first post's
- [x] 3.3 `viewer/bundle_views.dart`: add extra posts to `bundleFields` with a describe ("follow-up post N changed"); added/removed post reported as such, no false first-post change against old snapshots
- [x] 3.4 Tests: snapshot holds no extra-post HTML, changed-second-post diff, old-snapshot seam

## 4. Public site

- [x] 4.1 `public_data_builder.dart`: `_postNames` and `_groundNeeds` ground against all opening posts' plain words; gallery runs over extra posts' images through `gallery_filter`
- [x] 4.2 Anchor slice: locate grounded anchors in the cleaned post HTML, slice, pass through `cleanPostHtml`; use as description for shared-thread mods (`descriptionIsGenerated: false`); fallback chain unchanged when anchors absent
- [x] 4.3 Tests: topic-35651-shaped fixture — seven thread-only mods published with downloads and author descriptions; single-mod thread description unchanged; anchor-failure fallback
- [x] 4.4 Update `site/sample-data/` for any published-shape additions and keep `test/site/sample_data_test.dart` green

## 5. Viewer frontend

- [x] 5.1 Thread page (`web/views/bundle.js` / `extraction_views.js`): render each extra post in its own sandboxed frame below the first, with its dates
- [x] 5.2 Diff pages and topic history show the new field via the shared `diff_table.js` path (verify, no per-page code expected)

## 6. Migration

- [x] 6.1 `dart analyze` (via IDE inspection) and full `dart test`
- [ ] 6.2 Run a full re-scrape (`qb_scope=all`) to populate `extraPosts`; confirm topic 35651's detail carries the Downloads post and its seven links
- [ ] 6.3 Confirm LLM re-extraction picks up under the new prompt version (coverage pass, `llm_max_topics`-bounded) and topic 35651 yields the seven forks with downloads and anchors
