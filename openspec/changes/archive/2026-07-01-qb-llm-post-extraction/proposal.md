## Why

The QB scraper finds downloads with hand-written, host-by-host rules (`download_resolver.dart`). Those rules only ever see a link's URL and its anchor text, so they miss anything the rules don't already know about. Looking at the real bundle (`outputs/forum-data-bundle.json`, 878 posts):

- **255 posts (about 1 in 3) end with no download link at all.** Many of those hide the download inside a `[spoiler]` box, which `_extractLinks` deliberately skips (`topic_scraper.dart:277`), or on a file host the rules don't recognize (`download_resolver.dart:399` returns nothing for unknown hosts).
- **130 candidates are low-confidence or need a manual step; 154 have no file name.**
- Other useful facts are sitting in the post text but never captured: **487 posts mention a changelog** (367 of them inside a spoiler box, only 108 as a link), most posts state a **version**, 116 have a **support link** (Patreon/Ko-fi), 95 state a **license**.

The full post HTML is already kept end to end (`QbModDetail.contentHtml`), so the data an LLM would need is already in hand. This change reads each post once with a cloud LLM (OpenRouter, DeepSeek to start) and pulls out structured facts the rules can't — starting with downloads, then version, support links, and license.

## What Changes

- **Read every post once with an LLM.** After a topic is scraped, send its post HTML to the LLM and get back a structured answer. The existing rule-based resolver still runs.
- **Downloads (first field).** The rules' found links are handed to the LLM inside the *same* read, so it confirms them, adds ones the rules missed, and drops non-downloads in one pass — no separate tie-break call. The merged list is de-duplicated on the original post URL (the rules keep a *resolved* URL while the LLM keeps the *original* one, so the same file must be matched by its original URL or it would look like a disagreement and double up). When the LLM drops or overrides a rule link, its short reason is saved. Downloads stay a **list** per topic (a mod may have more than one link, e.g. a mirror).
- **Changelog, version, support links, license (next fields).** The same single read returns these too. The changelog is often text inside a spoiler box (367 posts) and sometimes a link (108); it is copied word-for-word or kept as its link, never summarized. Each field is optional and only filled when the post actually states it.
- **Grounding (hard safety rule).** The LLM may only return links that appear in the post, and it copies text word-for-word — it never invents a URL or summarizes. Anything it returns that is not in the post is dropped.
- **On-disk store (cache + resume).** Each finished result is written to disk by a fingerprint of the post content as the run goes, mirroring the resolver's existing `assumed-downloads-cache.json`. Repeat runs cost nothing; only new or changed posts pay. Because it is written as it goes, an interrupted run resumes where it left off instead of starting over. The bundle publisher reads the merged downloads and extras from this store.
- **Config + provider seam.** New `config.properties` keys (`enable_llm`, `openrouter_api_token`, `llm_model`, `llm_base_url`) load into `BotConfig`. The provider sits behind a thin `LlmClient` interface so a local model can slot in later.
- **Test mode.** A `llm_test_mode` switch runs the feature over a small, targeted set of posts (default 5), calls the LLM live, writes a verbose inspection report instead of touching the real bundle or cache, and lets you point at specific topics — so the prompt can be validated and fine-tuned cheaply.
- **Backwards-compatible JSON.** Every existing field and shape in `forum-data-bundle.json` is preserved. New data is additive and optional: an optional `source` tag on download entries, and a new optional per-topic extras section for version/support/license. Old readers ignore what they don't know.

## Capabilities

### New Capabilities
- `qb-llm-client`: A cached, throttled, provider-agnostic client for calling a cloud LLM (OpenRouter/DeepSeek to start), configured via `config.properties`, with per-topic error isolation.
- `qb-llm-post-extraction`: Read each scraped post once and return structured, grounded facts — downloads (a list, reconciled with the rules in the same call and de-duplicated on the original URL), changelog, version, support links, and license — written into the bundle in a backwards-compatible way.

### Modified Capabilities

(none — no existing spec-level requirement changes; the rule-based resolver keeps working as-is)

## Impact

- **Code (new):** `lib/bot/scraper/qb/llm/` — `llm_client.dart` (interface), `openrouter_client.dart` (implementation), `post_extractor.dart` (prompt + parse + grounding + reconcile/merge), `models/post_extraction.dart` (downloads, changelog, version, support links, license), and the on-disk result store (cache + resume).
- **Code (edited):** `common.dart` (new config fields), `main_repo_scraper.dart` (wire the extractor into the `onTopicSaved` seam), `bundle_publisher.dart` (read merged downloads + extras from the store), `models/assumed_download.dart` (optional `source` + `llmReason` fields), `models/forum_data_bundle.dart` (optional extras map).
- **Config:** New keys in `config.properties`: `enable_llm`, `openrouter_api_token`, `llm_model`, `llm_base_url`, `llm_max_consecutive_failures` (default 10), `llm_max_topics` (optional, off by default), `llm_test_mode` (off), `llm_test_limit` (default 5), `llm_test_topic_ids` (optional).
- **Files:** New cache artifact (e.g. `<qb_data_path>/llm-extraction-cache.json`) and a test-mode report (`<qb_data_path>/llm-test-output.json`), both already covered by `.gitignore`'s `qb_data/`.
- **Behavior:** With `enable_llm=false` (default) nothing changes. With it on, the scraper reads each post once (cached after), finds more downloads, and adds version/support/license to the bundle.
- **Cost:** One cheap LLM call per post on a first run (no separate tie-break call), then free from the store until posts change. Confirm the real number from a few test-mode runs before a full pass; expected to be small on a cheap model like DeepSeek.
- **Out of scope (follow-up):** Merging the new fields into the final `ModRepo.json`; extracting dependencies (dropped for now over false-positive risk); a local (non-cloud) model.
