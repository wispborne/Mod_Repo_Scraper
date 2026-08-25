# Scrape the author's opening run of posts

## Why

The topic scraper keeps only the first post of a thread. Some authors put the substance in follow-up posts: topic 35651 ("Computica's Faction Forks") lists a dozen mods in post 1 but holds every description and all seven GitHub download links in post 2 (same author, titled "Downloads"). Result today: the detail has zero downloads, the LLM extracts one mod with an empty download list, and the thread-only-mod path drops all seven forks at its "no download tied to it" check. The reserved-second-post pattern is a common SMF convention, so this is not a one-thread problem.

## What Changes

- The topic scraper keeps the **opening run**: the first post plus each consecutive post by the same author, stopping at the first reply by anyone else (capped at 10). Follow-up posts are stored on `QbModDetail` as a new `extraPosts` list (own HTML, images, links, post date, last-edit date). First-post fields are unchanged.
- Download resolution runs over the union of first-post and extra-post links.
- LLM extraction input includes the extra posts (reduced the same way, labelled as follow-up posts by the same author); URL/image/text grounding checks against all opening posts. `promptVersion` bumps, so the store re-extracts.
- New per-mod extraction field: **description anchors** — the exact opening and closing words of the post section describing that mod. The site builder slices the author's real HTML between the anchors and publishes it as that mod's description (author's words, not AI-labelled). Anchors that can't be located in the posts are dropped; the mod falls back to the AI paragraph as today. Only used on shared threads; single-mod threads keep the first post as description.
- Bundle: details gain `extraPosts` additively (session ids stripped, `localPath` stripped, same as `contentHtml`). TriOS's existing reads are untouched.
- Snapshots/working bundle: each extra post's HTML is replaced by a fingerprint, like `contentHtml`. Diff pages report "the author's Nth post changed" via a describe field.
- Site builder: thread-only name grounding (`_postNames`), `needs` grounding, and the gallery read all opening posts. The thread's description stays the first post.
- Viewer thread page renders extra posts in their own sandboxed frames below the first.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `qb-forum-scraping`: `QbModDetail` gains `extraPosts` (new `QbForumPost` model); the topic scraper collects the author's opening run, not just the first post.
- `qb-llm-post-extraction`: input covers all opening posts; grounding is against all opening posts; new per-mod description-anchor field with verbatim-slice grounding.
- `qb-bundle-publishing`: bundle details carry `extraPosts` additively with the same cleaning as `contentHtml`.
- `bundle-run-history`: snapshots replace each extra post's HTML with a fingerprint, not just the first post's.
- `bundle-comparison`: extra posts are a compared field, reported by describe ("post text changed"), never by dumping HTML.
- `public-site-data` (delta on top of the in-flight `publish-thread-only-mods` change): per-mod descriptions sliced verbatim from the opening posts on shared threads; name/needs grounding and the gallery read all opening posts.

## Impact

- **Scraper**: `topic_scraper.dart`, `models/mod_detail.dart` (+ regenerated mapper), `scraper_engine.dart` (HTML processing + resolver wiring).
- **LLM**: `llm/prompt.dart` (promptVersion bump), `llm/post_reducer.dart`, `llm/post_extractor.dart` (input + grounding), extraction models (+ mapper).
- **Bundle**: `bundle_publisher.dart`, `bundle_snapshot_store.dart`, `viewer/working_bundle.dart`, `viewer/bundle_views.dart`.
- **Site**: `site/public_data_builder.dart`, `site/post_html.dart`, `site/gallery_filter.dart` callers; sample data in `site/sample-data/` (pinned by `test/site/sample_data_test.dart`).
- **Viewer**: `web/views/bundle.js` / `extraction_views.js` (extra-post frames), diff pages pick up the new field via `bundle_views.dart`.
- **Migration**: `dart run build_runner build`; one full re-scrape (`qb_scope=all`) to fill `extraPosts`; LLM store re-extracts under the new prompt version (bounded per run by `llm_max_topics`). Old detail files without the field read as an empty list — nothing breaks mid-migration.
- **Depends on**: the `publish-thread-only-mods` change (shared-thread stand-ins) being in place; the description-anchor publishing amends its rules.
