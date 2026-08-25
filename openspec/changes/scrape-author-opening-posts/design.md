# Design

## Context

`QbTopicScraper.scrapeTopic` takes the first `.windowbg` element in `#forumposts` and builds the whole `QbModDetail` from it (`topic_scraper.dart:72`). Everything downstream — `contentHtml`, `images`, `links`, the LLM's input, download resolution, thread-only-mod grounding — sees only the first post. Threads that reserve the second post for downloads and per-mod descriptions (topic 35651 is the motivating case; topic 34161 is the existing multi-mod case) lose their downloads entirely.

Constraints:

- `forum-data-bundle.json` is TriOS's contract: existing fields must keep their meaning; new data is additive.
- The public site's description rule: a mod's description is the author's own words. A shared thread's opening post is nobody's description (from `publish-thread-only-mods`).
- Snapshots never keep post HTML — fingerprints only.
- LLM output must be grounded: it can point at things in the posts, never supply text or URLs of its own.

## Goals / Non-Goals

**Goals:**

- Capture the author's opening run of posts and feed every download/fact-hunting rule from all of them.
- Give each mod on a shared thread the author's own description when the posts contain one.
- Keep the bundle additive and the migration incremental (old details = empty `extraPosts`).

**Non-Goals:**

- Reading replies by other users, or the author's later posts in the discussion. Reply chatter contains stale links and version noise (topic 35651's page 1 has a Dropbox link to an unfinished build inside a quote).
- Changing the description of a normal single-mod thread. It stays the first post.
- Restructuring the first post's flat fields on `QbModDetail` into a posts list. The first post has a distinct role everywhere downstream, and moving it would churn every consumer and double-store its HTML for no behavioural gain.

## Decisions

### D1: Post selection — consecutive same-author posts from the top, capped

Keep post 1, then each following post while its author equals post 1's author; stop at the first other-author post; cap at 10 extra posts.

- Why not "all author posts on page 1": the author's replies to bug reports carry version noise ("did a quick fix to v1.0.1") and quoted stale links. Consecutive-from-top captures the reserved-posts convention and nothing else.
- Why not "follow the first post's self-link" (`topic=<id>.msg<N>`): precise but only catches threads that link themselves; consecutive-run subsumes the common case with no new signal required.
- Author comparison: exact string match on the scraped author name; same page, same rendering, so no normalization needed.

### D2: Storage — `extraPosts: List<QbForumPost>` beside the existing flat fields

New `QbForumPost` model: `contentHtml`, `images`, `links`, `postDate`, `lastEditDate`. First post stays in the existing flat fields.

- Alternative (full `posts` list including post 1) rejected: duplicates the first post's HTML or forces every consumer of `contentHtml`/`images`/`links`/author fields to change, with no behavioural difference.
- Absent field deserializes as `[]`, so pre-migration detail files stay readable.

### D3: Consumers take the union of posts

- **Download resolver**: caller passes `detail.links + extraPosts[*].links` to `resolveForTopic`. The resolver's cache fingerprint is over the link list, so only threads whose links changed re-resolve.
- **LLM input**: see D3a. One call per topic, all opening posts in one prompt.
- **Grounding** (`_postUrls`, `_postImages`, `_postRepoUrls`, `_checkAgainstPost`): collect from all opening posts. A URL in post 2 is grounded; a URL in a reply is not (never scraped).

### D3a: One LLM call per topic, all opening posts in one prompt

`PostReducer.reduce` runs per post, but the results go into a single user prompt: post 1 under the existing `=== POST TEXT ===` heading, then each follow-up under its own `=== FOLLOW-UP POST N BY THE SAME AUTHOR ===` heading, with the links, rule-detected downloads, and images sections merged across all posts. One call, one answer, one store entry.

Rejected alternative — one call per post, merging the answers:

- The answer is about the **thread**, not a post. The output is one `mods` list; on a reserved-downloads thread the names and prose sit in one post and the download links in another. Split the input and neither call can answer correctly: one returns mods with no downloads (today's bug, relocated), the other returns downloads with nothing to attach them to.
- Merging two `mods` lists means reconciling the model's own output by name — the same fuzzy-matching problem `mod_name_match.dart` exists for, now with the model on both sides. A disagreement between calls ("Junk Pirates" vs "Junk Pirates/ASP/PACK") mints a duplicate mod with a permanent id.
- Grounding is already thread-wide. One call over a union URL set grounds a post-1 claim backed by a post-2 link. Per-post calls would either reject that valid claim or ground against the union anyway, in which case the split bought nothing.
- Cost is higher split, not lower: the system prompt (rules, schema, summary guidance) is large and would be paid once per post rather than once per thread.
- The cache key is computed over the built user prompt, so one prompt gives one per-topic fingerprint, and a change to any opening post re-extracts the topic — the spec'd behaviour. Per-post calls would need per-post entries plus a freshness rule that ANDs them.

Size is not the constraint. Measured on topic 35651: post 1 is 6,028 chars → 4,234 prompt tokens (from the store's own stats); post 2 adds 2,196 chars and 7 links → roughly 700 more. That is ~4,900 against a corpus average of 4,730 and an existing maximum of 33,195 across 974 extracted topics. Most threads have no follow-up posts at all, so the average barely moves.

**Input budget**: `maxInputChars` (`llm_max_input_chars`) currently trims `reduced.text` for the single post. With several posts it SHALL apply to the combined body, and the follow-up posts SHALL be given their text in full first, with the first post's body trimmed to whatever budget remains. Follow-up posts are short and download-dense; the first post is the long prose. Trimming in scrape order would let a 30,000-character first post crowd out the Downloads post entirely, which is the exact failure this change exists to fix. A trim is logged, naming which post was cut.

Prompt text changes bump `promptVersion` (a cache-key component), forcing store-wide re-extraction — accepted cost, bounded per run by `llm_max_topics`.
- **Site builder**: `_postNames` and `_groundNeeds` ground against the concatenated plain words of all opening posts; the gallery runs `gallery_filter` over the extra posts' images too. The thread description (`cleanPostHtml(detail.contentHtml)`) is unchanged.

### D4: Per-mod descriptions — anchor slice, not model text

New per-mod extraction field `descriptionAnchors`: the exact first ~8 words and last ~8 words of the contiguous post section describing that mod. The builder locates the anchors in the cleaned post HTML (letters-and-digits comparison, so entities/whitespace don't break matching), slices the HTML between them, and runs the slice through `cleanPostHtml`. Published as the mod's `descriptionHtml`/`description` with `descriptionIsGenerated: false` — the words are verifiably the author's; the model only said where they start and end.

- Grounding: anchors not found, found out of order, or spanning more than one post → slice discarded, fall back to the existing chain (merged description → AI paragraph labelled AI).
- Alternative (model returns the description text, verified by substring match) rejected: verifying long text verbatim is fragile across HTML entities and encourages silent paraphrase; anchors keep the model's output small and checkable.
- Scattered descriptions (non-contiguous fragments) are out of scope by design: stitching is where "the author's words" stops being true.
- Applies to any mod resolved from a shared thread's LLM entry — thread-only stand-ins and merged mods that currently fall back. Single-main threads never enter this path.

### D5: Bundle, snapshots, diffs — additive field, fingerprinted like `contentHtml`

- `bundle_publisher` emits `extraPosts` on each detail with `stripSessionIds` applied and `localPath` blanked, mirroring `contentHtml`/`images` handling.
- `bundle_snapshot_store` and `working_bundle` replace each extra post's `contentHtml` with a `contentFingerprint`, so snapshots stay small and the seam between old (no-field) and new snapshots produces "field added", not a false "post changed".
- `bundle_views.dart` adds the field to `bundleFields` with a `describe` ("the author's post N changed") — same pattern as the existing post-text field. Diff pages and topic history pick it up for free.

### D6: Viewer — extra posts as posts

The thread page renders each extra post in its own sandboxed frame under the first, with its post/last-edit dates. Links and downloads need no per-post UI: the resolver cache and link tables already operate at topic level and now include the extra posts' links.

## Risks / Trade-offs

- [LLM re-extraction cost: promptVersion bump re-runs ~1000 topics] → Accepted by the user; `llm_max_topics` chunks it across scheduled runs; unchanged topics still cost one call each but only once.
- [A thread where the author's second post is a "reserved" placeholder] → Harmless: no links, no names, adds a few tokens to the LLM input.
- [A same-author second post that is discussion, not content] → It grounds only what it contains; the LLM is instructed to list only mods downloadable from the thread, and download grounding still requires real links.
- [Anchor slice captures too much (model picks generous anchors)] → Slice is bounded to one post and passes through `cleanPostHtml`'s existing length cutoff; worst case a mod's description includes a neighbouring sentence, still the author's words.
- [Bundle size growth] → Extra posts exist on a small minority of threads; the bundle already carries full first posts. Snapshots carry fingerprints only.
- [Detail files re-scraped with `qb_scope=all` while site publishes mid-migration] → Absent field reads as empty list; behaviour degrades to today's, never breaks.

## Migration Plan

1. Land model + mapper changes (`build_runner`), scraper, consumers, publisher, viewer, site, tests.
2. Run a full re-scrape (`qb_scope=all`) to populate `extraPosts`.
3. Let scheduled LLM coverage passes re-extract under the new prompt version.
4. No rollback machinery needed: the field is additive everywhere; reverting the code leaves inert extra data in detail files.

## Open Questions

None.
