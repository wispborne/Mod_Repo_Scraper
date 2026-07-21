## Context

`PostExtractor.extractForTopic` is called from exactly one place on the normal path: the `onTopicSaved` callback passed to `QbScraperEngine.run` in `main_repo_scraper.dart`. That callback fires only for topics the engine actually fetched. Under the production scope (`qb_scope=new_data`) the engine skips every topic whose forum last-post time is unchanged, so a topic that was scraped before the LLM was enabled is never revisited and never extracted. The result is a bundle with LLM output for 79 of 1030 mods that will not converge on its own.

Two facts make the fix cheap:

- `PostExtractor` already decides for itself whether a call is needed. It builds a fingerprint from the reduced post text, the prompt version, and the effective field set, and returns early on `_store.isFresh(...)` (`post_extractor.dart:199-210`). Calling it for an already-extracted topic costs a fingerprint computation and nothing else.
- The freshness check runs **before** `_reserveSlot()`, so store hits do not consume `llm_max_topics` budget. A capped run therefore spends its budget only on topics that actually need work, and naturally makes progress across runs instead of re-chewing the same prefix of the index.

There is already a function that does the whole-store walk — `_runLlmOverStoredPosts` — but it is reachable only through the `llm_reprocess_only` branch, which skips the scrape entirely.

## Goals / Non-Goals

**Goals:**

- When `llm_enabled` is true, a normal run leaves every stored topic with fresh LLM output, or with output that was deliberately deferred by the per-run cap.
- One implementation of the coverage walk, shared by the normal path and `llm_reprocess_only`.
- Make incomplete coverage visible in the log instead of silent.
- No new config keys; no change to the bundle's shape.

**Non-Goals:**

- Changing what the LLM extracts, the prompt, or the grounding rules.
- Changing download resolution, or how `assumedDownloads` is produced.
- Making LLM extraction concurrent. The extractor is driven one topic at a time today; keeping that avoids hammering a local single-GPU server.
- Automatically re-extracting on prompt edits beyond what the existing fingerprint already handles (it already does).

## Decisions

### Keep the per-topic call in `onTopicSaved`, and add a coverage pass after the scrape

The obvious move is to rip the LLM call out of `onTopicSaved` and do everything in one post-scrape pass. I am not doing that.

`onTopicSaved` runs inside the pipelined scrape loop, whose whole point (per the `qb-pipelined-scraping` spec) is that per-topic work overlaps the throttle wait before the next forum fetch. An LLM call for a freshly-scraped topic is exactly the kind of work that should ride along in that gap rather than being serialized after the scrape. Moving it out would make a typical incremental run slower for no benefit.

So: `onTopicSaved` keeps doing download resolution and LLM extraction for the topics it scrapes. After the scrape (and after the existing outdated-download redo), a coverage pass walks the whole index and calls `extractForTopic` on every stored topic. Topics handled during the scrape are store hits in the pass, so they are not paid for twice — this is the "not paid for twice" scenario in the spec, and it holds because of the freshness check, not because of any bookkeeping we add.

*Alternative considered:* a single post-scrape pass and nothing in `onTopicSaved`. Simpler control flow, one call site — but it gives up the pipelining and makes the common case (a few changed topics) slower. Rejected.

*Alternative considered:* gate the coverage pass behind a new `llm_backfill_missing` config key, defaulted off. Rejected: it reproduces the current bug as the default. If the LLM is on, the data should be complete; the cap (`llm_max_topics`) is the knob for people who want to pace the cost, and it already exists.

### `_runLlmOverStoredPosts` becomes the one coverage pass, used by both paths

The `llm_reprocess_only` branch and the normal path now call the same function. `llm_reprocess_only` keeps its current meaning — do the coverage pass, skip the scrape — which is exactly "the normal path minus the scrape". This kills the current situation where full coverage is only reachable through a special mode.

The function needs a small generalization: it currently logs as if it were the whole run ("processing all stored posts (no scrape)"). It should report coverage neutrally so it reads correctly from both callers.

### Report coverage from counts the extractor already keeps

`PostExtractor` already tracks `_processed` (slots reserved, i.e. live calls attempted) and `_bailed`. Neither is exposed. Add a getter for the live-call count, and have the coverage pass report: topics in the index, topics already fresh, live calls made, and topics still without output. The last number is the one that matters — it is what has been silently zero-information until now.

### Cap semantics stay as they are

`llm_max_topics` caps live calls per run, not topics visited. That is already what `_reserveSlot` implements, and it is the right meaning now that we visit every topic every run: visiting is free, calling is not. A capped run finishes normally, writes the store and the bundle, and the next run continues — because the fresh topics from last run are store hits that consume no budget.

## Risks / Trade-offs

- **The first enabled run after this change is long.** ~950 stored topics have never been extracted, at roughly 5-20s each against the local model. → This is the cost of the data the user asked for by enabling the feature, and it is paid once. `llm_max_topics` bounds it for anyone who wants to spread it across runs. The log now states how many remain, so progress is visible.

- **Cost via the OpenRouter fallback.** If the local endpoint is unreachable, the fallback provider is used, and a backfill of ~950 topics is a meaningfully larger bill than the current ~9 topics/run. → The fallback is only used when the primary is unreachable, and `llm_max_topics` bounds any single run. Worth calling out in the config comments so nobody discovers it by invoice.

- **Backfilled topics may have no cached download candidates.** The coverage pass feeds the LLM the resolver's cached candidates via `getCachedCandidates`, which returns an empty list for a topic the resolver never processed. The LLM then sees no rule hints for that topic. → Not a correctness problem: the prompt already asks the model to find downloads in the post itself, and rule hints are an aid, not an input it depends on. The resolver's own cache (876 entries) covers most of the store already, and the outdated-entry redo keeps filling it.

- **Coverage now depends on the mods index being accurate.** A topic missing from `mods-index.json` is invisible to the pass. → Same assumption the bundle publisher already makes; no new exposure.

## Migration Plan

No data migration. The extraction store's format is unchanged and existing entries stay valid (they are keyed by content fingerprint, not by run).

Rollout is just: run it. To pace the first run, set `llm_max_topics` to a batch size and run repeatedly until the log reports zero topics remaining.

Rollback is `llm_enabled=false`, or reverting the commit; neither invalidates the store.
