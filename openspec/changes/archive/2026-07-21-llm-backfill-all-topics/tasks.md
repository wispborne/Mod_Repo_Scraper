## 1. Expose coverage counts from the extractor

- [x] 1.1 Add a public getter to `PostExtractor` for the number of live calls made this run (the existing `_processed` counter), alongside the existing `hasBailed`.
- [x] 1.2 Confirm the freshness check in `extractForTopic` runs before `_reserveSlot()`, so store hits do not consume `llm_max_topics` budget (this is what lets a capped run make progress across runs rather than re-chewing the same prefix). Add a comment saying so, since it is load-bearing.

## 2. Turn the stored-posts walk into the shared coverage pass

- [x] 2.1 Rename `_runLlmOverStoredPosts` in `main_repo_scraper.dart` to a name that reads correctly from both callers (e.g. `_runLlmCoveragePass`), and change its logging to be neutral about whether a scrape happened.
- [x] 2.2 Have the pass count and report: topics in the index, topics already fresh (store hits), live calls made, and topics still without output at the end. Log the remaining count explicitly, including when it is zero.
- [x] 2.3 Log a clear line when the pass stops early because `llm_max_topics` was reached or the extractor bailed on consecutive failures, stating how many topics remain.

## 3. Run the coverage pass on the normal path

- [x] 3.1 In the normal (scrape) branch, after the scrape and the existing outdated-download redo, call the coverage pass over the full mods index when `extractor != null`.
- [x] 3.2 Leave the LLM call in `onTopicSaved` in place, so freshly-scraped topics are still extracted inside the pipelined loop; verify they come back as store hits in the coverage pass rather than triggering a second live call.
- [x] 3.3 Ensure ordering is: scrape → outdated-download redo → coverage pass → `llmStore.flush()` → resolver/probe cache saves → bundle publish, so the bundle sees the pass's output.
- [x] 3.4 Point the `llm_reprocess_only` branch at the same coverage pass, so the two paths share one implementation and differ only in whether the scrape ran.

## 4. Verify

- [x] 4.1 Run with `llm_enabled=true` and `llm_max_topics=3` on the existing store; confirm exactly 3 live calls are made, results are saved, and the log reports the remaining count. (3 calls: topics 27284 (failed, bad JSON from the model), 7327, 5066. Store 429 → 431. Log: "498 topic(s) still have no LLM results".)
- [x] 4.2 Run again with the same cap; confirm the 3 topics from the previous run are store hits (no live call) and 3 *different* topics get processed — i.e. the backlog advances. (7327/5066 not called again; "already had results" 429 → 431; new calls on 10458, 8020 (+ a retry of the failing 27284). Remaining 498 → 496.)
- [x] 4.3 Confirm a topic scraped this run is extracted once, not twice (one live call, then a store hit in the coverage pass). (One-page live scrape with `llm_max_topics=25`: 13 calls during the scrape, then the pass made 12 more *with budget still spare* while walking all 1030 topics. No topic appears twice in the call log — the 13 scraped topics were store hits in the pass.)
- [x] 4.4 Confirm `llm_enabled=false` is unaffected: no LLM calls, no coverage pass, bundle written as before. (Zero LLM log lines; bundle written; `llm-extraction-cache.json` byte-identical afterwards.)
- [x] 4.5 Confirm `llm_test_mode=true` still short-circuits to the test path and does not run the coverage pass or touch the real store/bundle. (Test path ran (3 calls), wrote `llm-test-output.json`; real store and bundle both byte-identical afterwards.)
- [x] 4.6 Check the bundle's LLM thread count rises by the number of live calls made, and `dart test` passes. (Cap-20 run: 20 calls → 10 brand-new topics covered (10 were re-extractions, see note below); store 444 → 454 and bundle LLM threads 417 → 427, i.e. +10 for +10. `dart test`: 251/251 pass.)

**Found during verification (pre-existing, not caused by this change):** the forum injects a `PHPSESSID=` session token into a link in the post HTML, and the scraper saves it in `detail.json`. It differs on every fetch, so re-scraping an *unchanged* topic changes the LLM prompt, changes the fingerprint, and forces a re-extraction. It also ships session tokens to TriOS: 359 saved posts and 1,191 URLs in `forum-data-bundle.json` contain one. Under `qb_scope=new_data` the damage is limited (only genuinely-changed topics are re-scraped), but under `pages`/`all` every re-scraped topic is paid for again. Worth its own change.

## 5. Documentation

- [x] 5.1 Update the `llm_enabled`, `llm_max_topics`, and `llm_reprocess_only` comments in `config.properties` to state the new coverage rule: enabling the LLM means every stored topic gets output, and `llm_max_topics` is how you pace it.
- [x] 5.2 Note in the config comments that a large backfill will use the OpenRouter fallback if the local endpoint is unreachable, so the cost is visible before someone discovers it on a bill.
- [x] 5.3 Update the QB LLM section of `CLAUDE.md` (and `README.md` if it describes the modes) to describe the coverage pass and to stop presenting `llm_reprocess_only` as the only route to complete coverage. (README only describes the bundle format, not the run modes, so it needed no change.)
