## Why

The Investigate section of the new viewer still has placeholder pages. `docs/viewer-redesign-requirements.md` (**Investigate**) organizes it by mod, with a page for each source post and one list of all source posts. Today the old viewer has a Topics list for forum topics only, a thread page, and a separate Discord thread page, and none of them says what became of a post: how many mods it gave, whether it was left out, or whether it was taken down.

## What Changes

- **Source posts list** (`#/posts`): forum topics and Discord threads in one list, with search, filters, sorting and paging kept in the address. The data quality numbers (no download found, no LLM answer, placeholder posts) sit at the top and each opens the list with its filter. Posts can be ticked across pages, and the per-post jobs act on the ticked posts: Re-scrape, Re-run LLM, Recheck downloads and Scan images for forum topics, Re-run LLM for Discord threads.
- **Source post page** (`#/posts/topic/<id>` and `#/posts/discord/<id>`), one page for both kinds, replacing the old thread page and Discord thread page. It keeps what they show: the LLM's mods with their downloads and extras, the rules' downloads, the pictures grouped by post with their AI descriptions, the posts in sandboxed frames, the warning when the published bundle is behind (with its Rebuild button), the per-post job buttons, the topic history, and raw JSON. It also says in one line what happened to the post, for example "Became 4 mods: …", "Left out: the LLM says it is not a mod and nothing can be downloaded.", "Points to topic 18011." or "Taken down.", and has a Take down button that adds a pending change.
- **Two read-only server routes:** `GET /api/posts` (the combined list) and `GET /api/posts/outcome` (what happened to one post, with the one line ready to show).
- Searching for a topic id, forum address or Discord address now opens the new source post page instead of the old viewer.

## Capabilities

### New Capabilities
- `viewer-v2-source-posts`: the Source posts list and the source post page.

### Modified Capabilities
- `viewer-server`: the two read-only routes.

## Impact

- `lib/viewer/api.dart`, a new `lib/viewer/post_views.dart` (list rows and outcomes), `lib/viewer/data_access.dart`.
- New `web2/views/posts.js`, `web2/views/post.js`, `web2/views/post_history.js` and their styles; `web2/app.js`, `web2/routes.js` (search goes to the new pages).
- Tests: Dart tests for both routes; Node tests for any new pure helpers.
