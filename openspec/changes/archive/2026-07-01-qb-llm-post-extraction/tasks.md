## 1. Config + provider seam

- [x] 1.1 Add `enable_llm`, `openrouter_api_token`, `llm_model`, `llm_base_url`, `llm_max_consecutive_failures` (default 10), and `llm_max_topics` (optional, blank = off) to `config.properties` (commented, off by default) and to `BotConfig` in `common.dart`, parsed like the existing tokens/flags
- [x] 1.2 Define an `LlmClient` interface in `lib/bot/scraper/qb/llm/llm_client.dart` (input → structured answer)
- [x] 1.3 Implement `OpenRouterClient` in `lib/bot/scraper/qb/llm/openrouter_client.dart` — POST to `<llm_base_url>` with `Authorization: Bearer`, body `{ model, messages, temperature: 0, response_format: json_object, max_tokens, stream: false }`; read `choices[0].message.content` and `usage`
- [x] 1.4 Keep the literal prompt text and exact numeric settings as versioned constants in code (tie the prompt to `promptVersion`)
- [x] 1.5 Add throttling (reuse the existing `ThrottledClient` gate so several in-flight topics still space out provider calls) and a per-call timeout; retry a bad/unusable response (error, non-2xx, unparseable, or wrong shape) exactly once, then fall back
- [x] 1.6 Log every failure through Timber with the topicId and reason (HTTP error, timeout, parse/shape failure, dropped item, retry, fallback); log token usage on success
- [x] 1.7 Track consecutive failures (counted in call-completion order, updated under a lock) and bail out (stop LLM calls for the rest of the run, log it) once they reach a configurable threshold (default ~10). Reset the count to zero on any success. A late-by-one bail under overlap is acceptable
- [x] 1.8 Add an optional total-volume cap (max posts the LLM may process per run), disabled by default; it is a soft ceiling — may overshoot by up to (concurrency − 1) with calls in flight, which is acceptable
- [x] 1.9 Add test-mode config: `llm_test_mode` (off), `llm_test_limit` (default 5), `llm_test_topic_ids` (blank), wired into `BotConfig`

## 2. Extraction model + prompt

- [x] 2.1 Add `models/post_extraction.dart` (`@MappableClass(ignoreNull: true)`) with: downloads (list), changelog (link + text), version, supportLinks (list), license
- [x] 2.2 Write the extraction prompt asking for all fields at once, instructing the model to copy text (never summarize) and to only use links/text present in the post; include the rule resolver's found links (as their **original** post URLs — confirm/extend/drop, with a one-line reason on a drop or override), the known game version (do not repeat as the mod's version), and which links were already flagged downloadable
- [x] 2.3 Build the reduced post input: use `HtmlProcessor` for cleanup only (note: it does not return text+links), then keep the text and every `<a href>` with anchor text, and **keep** spoiler-box contents (opposite of `_extractLinks`). Skip topics where `isPlaceholderDetail` is true — no LLM call
- [x] 2.4 Parse the model's answer robustly (reuse `jsanity.dart`) and shape-check it; treat `finish_reason: length` as truncation and drop the long field (e.g. changelog). A bad answer triggers the single retry (task 1.5), then falls back to no LLM extras for that topic

## 3. Grounding (safety)

- [x] 3.1 Collect the set of URLs actually present in the post
- [x] 3.2 Drop any returned download/support/changelog URL not in that set
- [x] 3.3 Verify version, license, and changelog text appear in the **same reduced post text we sent the model** (check like against like); otherwise treat as not stated (blank)

## 4. Merge downloads (reconciled in the one call)

- [x] 4.1 After the rule resolver runs for a topic, gather its download candidates and the LLM's grounded, reconciled downloads (the LLM already saw the rule links per task 2.2)
- [x] 4.2 Match and de-duplicate on the **normalized original/source URL** (`UrlNormalizer` over `sourceUrl`), never the resolved URL — otherwise clean downloads look like disagreements and duplicate. Keep the de-duplicated union
- [x] 4.3 Tag each download entry with an optional `source` (`rules` | `llm` | `rules+llm`) and an optional one-line `llmReason` when the LLM dropped or overrode a rule link. Mark LLM-only (unresolved) entries `confidence: low` + `requiresManualStep: true`

## 5. On-disk store: cache + source of truth + resume

- [x] 5.1 Add an `llm-extraction-cache.json` under `<qb_data_path>`, keyed by topicId with a fingerprint over (reduced input + rule-link hints + field set + prompt version) and a schema version. Each entry holds the finished result: merged downloads (with `source`/`llmReason`) and the extras
- [x] 5.2 On a cache hit with matching fingerprint, skip the LLM call (this also drives resume — an interrupted run skips already-finished topics)
- [x] 5.3 Write **as the run progresses**, not only at the end: after each topic finishes, update the in-memory store and flush to disk on a throttled cadence (every few seconds / every N topics) plus one guaranteed final flush. A single serialized writer owns the flush so concurrent topics never write the file at once
- [x] 5.4 `bundle_publisher` reads merged downloads and extras from this store (this is where the reconciled result lives between the per-topic callback and publish). Bumping prompt/schema version invalidates cleanly

## 6. Wire into the pipeline + bundle

- [x] 6.1 Construct the LLM client + extractor in `main_repo_scraper.dart` (only when `enable_llm` is true) and call it from the `onTopicSaved` seam that already has the full `QbModDetail`. It runs under the engine's existing bounded overlap (`maxPending`); keep LLM concurrency low and configurable (default matches `maxPending`)
- [x] 6.2 Add optional `source` and `llmReason` fields to `AssumedDownloadCandidate` (`models/assumed_download.dart`), kept null when off
- [x] 6.3 Add an optional per-topic extras map to `ForumDataBundle` (`models/forum_data_bundle.dart`) for changelog/version/support/license
- [x] 6.4 Populate both in `bundle_publisher.dart`; omit when absent
- [x] 6.5 Run code generation for the new/changed mapper classes (`dart_mappable`)

## 7. Test mode (validation + tuning)

- [x] 7.1 When `llm_test_mode` is on, select posts: use `llm_test_topic_ids` if given, else sample the hard posts (rules found no download or only low-confidence); process at most `llm_test_limit`
- [x] 7.2 In test mode, call the LLM live (bypass the answer cache) and do not write to the real bundle or the answer cache
- [x] 7.3 Write a verbose report to `<qb_data_path>/llm-test-output.json`: per topic — input sent (post + hints), raw answer, parsed+grounded result, dropped items, rules-vs-LLM comparison + any drop/override reason, token usage
- [x] 7.4 Reuse the same client/grounding/comparison code as a real run so test output matches real behavior

## 8. Verify

- [x] 8.1 With `enable_llm=false`, confirm the bundle is byte-compatible in shape with today (no `source`, no extras) and no LLM calls are made
- [x] 8.2 With `enable_llm=true`, confirm a spoiler-hidden and an unknown-host download are now captured on sample topics that previously had none
- [x] 8.3 Confirm an invented URL (forced in a test) is dropped by grounding
- [x] 8.4 Confirm a second run is served entirely from the LLM store (zero LLM calls), and that a run interrupted partway resumes — only the unfinished topics call the LLM on restart
- [x] 8.4b Confirm a clean download the rules resolved and the LLM named appears **once** in the list (de-duplicated on the normalized original URL, not two entries), with no drop/override reason
- [x] 8.5 Confirm an old reader can still parse the new bundle (added fields are optional/ignored)
- [x] 8.6 Confirm a forced LLM failure on one topic falls back to rules and does not stop the run
- [x] 8.7 Confirm a first bad response is retried exactly once, and a good retry is used
- [x] 8.8 Confirm every failure path (HTTP error, timeout, parse/shape failure, dropped item, fallback) writes a log line with the topicId, and success logs token usage
- [x] 8.9 Confirm ~10 failures in a row bails out (rest of run uses rules, logged), and that a success in between resets the count so scattered failures don't bail
- [x] 8.10 Confirm test mode makes at most `llm_test_limit` calls, writes the report, and leaves the real bundle and answer cache untouched
