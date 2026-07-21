## Why

LLM extraction only ever runs on topics the scraper happens to fetch in the current run, because `PostExtractor.extractForTopic` is invoked solely from the QB engine's `onTopicSaved` callback. With the normal `qb_scope=new_data`, that is a handful of changed topics per run, so the bundle is permanently incomplete: today it carries LLM output for 79 of 1030 mods, and a topic that was already scraped before the LLM was turned on will never be picked up, because from the scraper's point of view it is not "unchanged and skipped" — it is simply never visited.

Turning `llm_enabled` on should mean the bundle's LLM data is complete, not that it slowly fills in over months of incidental re-scrapes.

## What Changes

- When `llm_enabled` is true, the QB pipeline runs LLM extraction over **every topic in the mods index**, not only the topics scraped this run. Topics scraped this run are already fresh in the store, so re-visiting them costs nothing.
- Coverage is decided by the extraction store's existing freshness check, not by whether a topic happened to be scraped. The store is already content-addressed (a fingerprint of the reduced post text, the prompt version, and the field set), so a topic is processed exactly when it is new, its post changed, or the prompt changed — and is a free store hit otherwise.
- `llm_max_topics` becomes the meaningful per-run cap: it already limits how many live calls a run may make, so anyone who wants to work through a large backlog in bounded chunks can, and each run resumes where the last stopped.
- `llm_reprocess_only` becomes a scrape-skipping variant of the normal path rather than the only way to get complete coverage. It keeps its existing meaning (do the LLM pass, skip the scrape) and stays useful for reprocessing after a prompt change without touching the network.
- The run logs how many stored topics were covered and how many needed a live call, so an incomplete bundle is visible rather than silent.

**Not breaking**: no config keys are added, removed, or renamed, and no output shape changes. A run with `llm_enabled=false` is unaffected. The first run after this change with `llm_enabled=true` will be long, because it pays the extraction cost that was previously never paid; `llm_max_topics` bounds it for anyone who wants to spread it out.

## Capabilities

### New Capabilities

None. This changes the coverage rule of an existing capability.

### Modified Capabilities

- `qb-llm-post-extraction`: the coverage requirement changes from "each **scraped** topic is read once by the LLM" to "every topic **in the store** has fresh LLM output, or gets it this run". Adds the per-run cap and the coverage-reporting behavior as requirements.

## Impact

- `lib/bot/scraper/main_repo_scraper.dart` — the QB block: the `onTopicSaved` LLM call becomes a post-scrape pass over the whole index; `_runLlmOverStoredPosts` is reused (or generalized) so the normal path and `llm_reprocess_only` share one implementation.
- `lib/bot/scraper/qb/llm/post_extractor.dart` — no behavior change expected; its freshness check and `llm_max_topics` slot reservation already do the right thing when called for every topic.
- Download resolution: the pass needs each topic's resolved download candidates as LLM input. Scraped topics have them from `resolveForTopic`; backfilled topics read them from the resolver's cache, as `_runLlmOverStoredPosts` already does.
- `config.properties` / `README.md` / `CLAUDE.md` — documentation of what `llm_enabled`, `llm_max_topics`, and `llm_reprocess_only` now mean.
- Run time: the first `llm_enabled=true` run after this change processes the ~950 stored topics that have never been sent to the LLM. Cost is bounded by `llm_max_topics` if set.
