## Context

The QB pipeline scrapes a forum topic into a `QbModDetail` that keeps the full first-post HTML (`contentHtml`) plus the links the regex extractor found (`List<LinkRef>`). Right after a topic is saved, `main_repo_scraper.dart:264` calls `qbResolver.resolveForTopic(detail.topicId, detail.links)` — the hand-written, host-by-host download resolver. That resolver only sees the links list, not the surrounding prose, and returns nothing for unknown hosts or spoiler-hidden links.

The full HTML is retained all the way into the bundle (`bundle_publisher.dart:66`), so an LLM has real material to read at exactly the point the resolver runs. The resolver already keeps a fingerprint-keyed cache (`assumed-downloads-cache.json`, `schemaVersion = 2`) — the same caching shape we reuse for LLM answers.

## Goals / Non-Goals

**Goals:**
- Read every scraped post once with a cloud LLM and return structured facts: downloads (a list), changelog, version, support links, license.
- Improve downloads by finding what the rules miss (spoilers, unknown hosts) while keeping the rules for the clean cases.
- Never let the LLM invent a URL or reword copied text (grounding).
- Cache every LLM answer by post content so repeat runs are free.
- Keep `forum-data-bundle.json` fully backwards-compatible.
- Put the provider behind an interface so a local model can replace OpenRouter later.

**Non-Goals:**
- Merging the new fields into `ModRepo.json` (follow-up).
- Extracting dependencies / required mods (dropped for now — false-positive risk).
- A local/offline model (interface is ready for it; not built here).
- Replacing the rule-based resolver (it stays; the LLM augments and, on disagreement, is tie-broken against it).

## Decisions

### 1. Read every post once, not just the hard ones
**Choice:** Call the LLM for every scraped topic. **Why:** the extra fields (changelog-style facts, version, support, license) live in roughly half of all posts, not only the ones where downloads were hard, so a "only when the rules struggled" gate would miss most of them. One cheap call per post, cached forever after, is the simplest model. Reading every post also means the LLM sees the easy-download posts, so a confidently-wrong rule result can be caught in the same call.
**Alternative:** Only escalate to the LLM when the rules produced nothing or low confidence (~385 posts). Rejected: misses version/support/license on the ~470 clean-download posts.

### 2. Rules stay; the LLM reconciles both in one call
**Choice:** Run the rule resolver as today, then give its found links to the LLM inside the **same** extraction call. The prompt says, in effect: "here are the links the scraper already auto-detected — confirm which are the mod's downloads, add any it missed, and drop any that aren't downloads; give a one-line reason when you drop or override one." The LLM's answer is the reconciled download list. No separate second call.

**Comparing the two sides — the important detail.** The rules do **not** keep the link that sits in the post; they keep a *resolved* link (a GitHub releases page becomes a direct asset URL, a `bit.ly` link is followed to its target, Google Drive is rewritten). The LLM, by the grounding rule, can only ever return a link that literally appears in the post — i.e. the *original*, unresolved URL. So the two sides will hold different strings for the very same file. Therefore:
- **Match and de-duplicate on the normalized *original* URL** (`DownloadCandidate.sourceUrl` via `UrlNormalizer`), never on the resolved URL. Without this, every clean download reads as a "disagreement" and the merged list shows the same file twice.
- To let the LLM line up against the rules, the rule links handed to the model are their **original** post URLs (what the reader actually sees), not the resolved ones.

**Merge outcome.** The final per-topic download list is the de-duplicated union, each entry tagged with a `source`: `rules` (rules found it, LLM did not object), `llm` (only the LLM found it — e.g. inside a spoiler or on an unknown host), or `rules+llm` (both). When the LLM drops or overrides a rule link, its one-line reason is saved on that entry so the decision is auditable.

**Why:** folding the rules into the one call fixes the resolved-vs-original mismatch, keeps the reliable rule output, covers the open-world cases the rules miss, and keeps a human-readable reason — all without a second paid call per hard post.
**Alternative A:** a separate second "tie-break" call on disagreement. Rejected: with resolved-vs-original strings nearly every post looks like a disagreement, so this would fire almost always — extra cost for no gain. **Alternative B:** LLM overrides rules whenever present. Rejected: throws away reliable rule output and has no audit trail.

### 3. Grounding is mandatory and enforced in code, not just the prompt
**Choice:** After every LLM answer, validate it against the very same reduced post we sent the model — check like against like, so nothing gets wrongly dropped:
- Every returned URL must appear in that post text; drop any that don't.
- Version and license strings must appear in that post text; if not found, treat as not stated (leave blank) rather than trusting the model.
- Changelog: a changelog link must appear in the post; changelog text must be found in the post word-for-word (the model is told to copy, never summarize). Because we check the model's copy against the exact text we sent it — the same form on both sides — a real changelog isn't dropped over stray whitespace or an HTML tag. If neither a link nor a matching copied block is found, leave blank.
**Why:** LLMs make up plausible URLs and facts; the prompt alone is not enough. This is the single biggest correctness risk.

### 4. One on-disk store that is cache, source of truth, and resume point
**Choice:** Keep a single `llm-extraction-cache.json` under `<qb_data_path>`, keyed by topicId. Each entry holds a `fingerprint` over the exact input sent to the model (the reduced post text + the rule links given as hints + the field set + a `promptVersion`), a `schemaVersion`, and the finished result for that topic — the merged download list (with `source` tags and any reasons) plus the extras (version/changelog/support/license). This one file plays three roles:
- **Cache:** on a run, a topic whose fingerprint still matches is served from the file and makes no network call.
- **Source of truth for the bundle:** `bundle_publisher` reads the merged downloads and extras straight from this store — this is the answer to "where does the reconciled result live between the per-topic callback and the publisher." The callback does not throw its result away (as the rule resolver's return value is thrown away today, `main_repo_scraper.dart:264`); it writes it here.
- **Resume point:** because it is written *as the run progresses* (see below), a run that is interrupted — crash, network death, Ctrl-C — restarts from where it left off. Topics already finished are skipped on the fingerprint match; only the unfinished ones pay.

**Written as it goes, not only at the end.** The rule resolver saves its cache once, at the end of the run (`saveCache()`). That is fine for a cheap local step but would throw away a whole partial LLM run on a crash. Instead, after each topic's result is ready it is put into the in-memory store and the store is flushed to disk on a throttled cadence — at most once every few seconds (and every N finished topics), plus one guaranteed final flush. A crash loses at most the last few seconds of work, which simply re-runs next time (idempotent and cheap). A single writer owns the flush so concurrent topics don't corrupt the file (see Decision 12).

**Why:** matches the existing `assumed-downloads-cache.json` shape (`download_resolver.dart:855`), so invalidation is automatic when the post or the prompt changes and bumping `promptVersion`/`schemaVersion` re-runs everything cleanly — while also giving free resume on a long, paid, network-bound run where finishing all 878 posts in one uninterrupted go is not guaranteed.

### 5. Reduce the HTML before sending, and feed the model what we already know
**Choice:** Send a reduced form of `contentHtml` — keep the text and every `<a href>` with its anchor text and its spoiler context, and keep spoiler contents (unlike `_extractLinks`, which drops them). Note: `HtmlProcessor` only cleans HTML (strips smileys/edit-marks, decodes entities); it does **not** hand back "text plus links," so this reduction is new code, not a call into it — it reuses `HtmlProcessor` for the cleanup only.

Alongside the reduced post, hand the model three things the scraper already knows, as hints (this is where the cheap wins live):
- **The rule resolver's found links** (their original post URLs) so the model can confirm/extend them in one pass (Decision 2).
- **The game version already scraped** (`QbModDetail.gameVersion`): "the game version is X — do not report that as the mod's own version," which is exactly the mod-version-vs-game-version confusion we want to avoid.
- **Which links the scraper already flagged downloadable** (`LinkRef.isDownloadable`, added recently) as a soft hint toward the real download.

**Skip placeholder posts.** `QbModDetail.isPlaceholderDetail` marks a stub with no real content; never spend an LLM call on one.

**Why:** posts vary wildly in size, so reduction lowers cost and improves signal; keeping spoilers is the whole point (that's where downloads and changelogs hide); and the three hints cost nothing extra yet directly sharpen the two hardest fields (finding the real download, and separating the mod version from the game version). The hints are folded into the fingerprint (Decision 4), so changing them re-runs cleanly.

### 6. Backwards-compatible output: additive and optional only
**Choice:**
- `assumedDownloads` keeps its exact shape and fields. LLM-found downloads are added as additional entries in the same per-topic list, each with an **optional** `source` tag (`"rules" | "llm" | "rules+llm"`) and an **optional** one-line `llmReason` when the LLM dropped or overrode a rule link (Decision 2). Old readers ignore the unknown fields.
- An LLM-only download (found in the post but never resolved by the rules — unknown host, spoiler) is unverified: it gets `confidence: "low"` and `requiresManualStep: true`, matching how the rules already tag links they can't resolve. It is a raw post URL, honestly marked, not a resolved direct link.
- Changelog, version, support links, and license go in a **new optional** per-topic extras section on the bundle (e.g. `llmExtraction: { topicId: { version?, changelog?: { link?, text? }, supportLinks?: [...], license? } }`). Absent when the LLM is off or found nothing.
- Models use `@MappableClass(ignoreNull: true)` (as the existing ones do), so null/absent fields are omitted.
**Why:** the user's hard constraint — every existing field and shape in the bundle must keep working.

### 7. Provider behind a thin `LlmClient` interface
**Choice:** `LlmClient` exposes a single "given this input, return this structured answer" call. `OpenRouterClient` implements it over HTTP (OpenRouter, DeepSeek model by default), reading `openrouter_api_token`, `llm_model`, `llm_base_url` from config. The extractor depends only on the interface.
**Why:** "cloud for now" implies a local model later; the seam makes that a drop-in.

### 8. Wire it in the orchestrator, keep the engine agnostic
**Choice:** Construct the LLM client + extractor in `main_repo_scraper.dart` and call it from the QB pipeline (the `onTopicSaved` seam that already has the full `QbModDetail`), mirroring how caching and the resolver are wired at the orchestrator level. `QbScraperEngine` stays unaware of the LLM.
**Why:** matches the existing separation (`qb-use-cached` design decision 4) — the engine uses whatever it's given.

### 9. LLM wire protocol and request settings

**Choice:** Talk to the provider with a plain HTTPS POST using the project's existing `http` package — OpenRouter uses the same "chat completions" shape as OpenAI, so no extra SDK is needed. The `LlmClient` interface hides the call; `OpenRouterClient` sends:

```
POST <llm_base_url>            e.g. https://openrouter.ai/api/v1/chat/completions
Headers: Authorization: Bearer <openrouter_api_token>, Content-Type: application/json
         (plus optional X-Title / HTTP-Referer attribution headers)
Body:   { "model": <llm_model>,
          "messages": [ {system: the rules}, {user: the reduced post} ],
          "temperature": 0,
          "response_format": { "type": "json_object" },
          "max_tokens": <generous cap>,
          "stream": false }
```

The answer is read from `choices[0].message.content` (a JSON string we parse) and `usage` (token counts) is logged for cost visibility.

**Settings and why:**
- **`temperature: 0`** — faithful extraction, not creativity; also keeps answers stable, which the content-fingerprint cache relies on.
- **`response_format: json_object`** — ask for JSON, not prose. A strict JSON schema is used where the provider supports it, but it is treated as a bonus, not a substitute for defensive parsing.
- **`max_tokens`** — generous, because copied changelog text can be long. Truncation is detected from the response's `finish_reason` being `length` (not guessed from output size); when it happens, that topic's changelog is treated as not captured rather than saved half-formed.
- **`stream: false`** — the whole answer at once.

**Prompt:** a system message with the rules (return only JSON in the given shape; copy text exactly, never summarize; only use links/text present in the post; leave a field blank if unstated) and a user message with the reduced post **plus the hints from Decision 5** — the rule resolver's found links (confirm/extend/drop with a reason), the known game version (don't repeat it as the mod version), and which links were already flagged downloadable. The **literal prompt text and the exact numeric settings live as versioned constants in code**, not in this spec — the wording will iterate, and `promptVersion` (already folded into the cache key) makes a change re-run cleanly. The spec captures the contract and the values' rationale; code is the single source of truth for the exact strings.

### 10. Retry once, log every error, and cap spend per run

**Choice:**
- **Retry once on a bad response.** If a call errors, times out, or returns something we cannot use (non-2xx, unparseable JSON, or JSON that fails the shape check), retry exactly one time. If the retry also fails, fall back to the rule-based downloads for that topic and write no LLM extras for it.
- **Log every error.** Every failure — HTTP error, timeout, parse failure, shape-check failure, a grounded-out (dropped) URL or fact, and each fallback — is logged through the existing Timber logger with the topicId, so nothing fails silently. Successful calls log their token usage.
- **Bail on consecutive failures (default guard).** Track how many calls fail *in a row*. Once that hits a threshold (default ~10 in a row), stop making LLM calls for the rest of the run and finish on the rules alone. Any success resets the counter to zero. This catches the "provider is down / bad key / wrong model" case — where failures pile up back-to-back — without tripping on a mostly-healthy run that has a few scattered failures. With a few calls in flight at once (Decision 12), "in a row" is counted in the order calls *finish*; the shared counter is updated under a lock. A small overlap can let the bail fire a call or two late — that's fine, the point is to stop a clearly-broken provider, not to be exact to the single call.
- **Optional total-volume cap (off by default).** A configurable limit on how many posts the LLM may touch per run (or a rough token/spend budget) for anyone who wants a hard ceiling. Left unset by default, because caching already keeps repeat-run cost near zero, so the broken-provider case (covered by the consecutive-failure bail) is the real risk. With calls in flight at once, the cap may be **overshot by up to (concurrency − 1)** calls — a handful at most, and by explicit choice acceptable — so the cap is a soft ceiling, not a hard gate.

**Why:** the LLM is the one part that reaches an external paid service, so it needs the strongest failure handling: one retry catches transient blips, full logging makes problems visible, and a *consecutive*-failure bail (not a scattered total) is the sharp signal that something is genuinely broken. A bad LLM day degrades to today's rule-only behavior, never a broken or runaway run.

### 11. Test mode for validation and tuning

**Choice:** Add a `llm_test_mode` switch that turns the feature into a small, repeatable tuning harness:
- Caps the run to a small number of LLM calls (`llm_test_limit`, default 5).
- Targets specific posts by ID (`llm_test_topic_ids`) when given; otherwise samples the *hard* posts (topics where the rules found no download or only low-confidence ones), since those are the interesting cases to validate.
- Writes a verbose inspection report to its own file (e.g. `<qb_data_path>/llm-test-output.json`): for each topic, the exact input sent to the model (post + hints), the raw answer, the parsed-and-grounded result, what grounding dropped, the rules-vs-LLM comparison and any drop/override reason, and token usage.
- Does **not** modify the real bundle or the answer cache, and calls the LLM **live** (ignores the cache), so trials can be repeated freely while tuning the prompt without polluting real output or re-running all 878 posts.

**Why:** a "read every post" feature is expensive and slow to tune if each trial is a full run. Test mode makes the loop cheap, targeted, and fully inspectable, which is exactly what prompt fine-tuning needs. It reuses the same client, grounding, and comparison code — only the selection, the "don't persist," and the extra report differ — so what you validate in test mode is what runs for real.

**Alternative considered:** reuse the optional `llm_max_topics` cap alone. Rejected: a bare cap still writes to the real bundle/cache, serves cached answers, picks arbitrary posts, and produces no inspection detail — none of which supports tuning.

### 12. Run under the pipeline's existing bounded concurrency, with safe shared state

**Choice:** The QB engine already processes topics with a small amount of overlap — up to `maxPending` (3 today) topics in flight, and `onTopicSaved` is awaited *inside* that bounded loop (`scraper_engine.dart`). So the LLM step is **not** serial; a few calls run at once. We keep it that way — the overlap hides network latency, which is the dominant cost of a "read every post" run — and make the shared state safe for it:
- **Provider rate limit still applies.** Reuse the existing `ThrottledClient` gate (the same future-chaining delay the scraper uses), so even with several topics in flight the calls to the provider are spaced out and we don't hammer the API.
- **The failure counter and volume cap are updated under a lock** and are allowed to be slightly loose (Decision 10): the bail may fire a call or two late, the cap may overshoot by up to (concurrency − 1). Both are acceptable by explicit choice — going a little over is fine.
- **One writer owns the on-disk store.** Concurrent topics hand their finished result to a single serialized writer that updates the in-memory map and flushes the file (Decision 4), so the JSON is never written by two topics at once.
- **Concurrency is a small, configurable number** (default matches the engine's `maxPending`), kept low on purpose: this is a paid external call, not free CPU work, and a big fan-out would blow the rate limit and the spend for little gain.

**Why:** a fully serial LLM pass over ~878 posts would be needlessly slow when the work is almost all waiting on the network; a little overlap is a real speed-up. The cost is a handful of edge cases around the counter, cap, and file write — all handled by a lock and an accepted small looseness, which the user has signed off on.

## Risks / Trade-offs

- **Hallucinated URLs/facts** → mitigated by mandatory in-code grounding (Decision 3); anything not in the post is dropped.
- **Grounding is not a safety check.** Grounding only guarantees a returned link actually appears in the post. It does **not** vouch that the link is safe — a post author can put a bad link in their own post and both the rules and the LLM will faithfully surface it. That is the same trust boundary the rule resolver already lives with; the LLM does not widen it. Not solved here, just named.
- **Cost on first run** → one call per post (~878), now with **no** separate tie-break call (Decision 2), cached after. Put a real number in before shipping: estimate tokens per post from a handful of test-mode runs and multiply out — on a cheap model like DeepSeek this is expected to be a few cents to low dollars for the whole first pass, but confirm it, don't assert it. The on/off switch defaults off, so nobody pays by accident.
- **Latency** → LLM calls are network-bound; a small amount of overlap (Decision 12, default ~3 in flight) hides most of the wait, and per-topic error isolation means one slow/failed call falls back to the rules for that topic while the run continues. A crash mid-run resumes from the on-disk store (Decision 4), so a long first pass never has to start over.
- **Prompt drift** → `promptVersion` in the fingerprint means changing the prompt cleanly re-runs affected posts instead of serving stale answers.
- **Model/provider outage** → per-topic failures are isolated; the rules still produce their normal output, so a bad LLM day degrades to today's behavior, not a broken run.
- **Bundle growth** → most extras are small and optional. Verbatim changelog text can be large (some changelogs are long). Keep it whole and verbatim for honesty, but store a changelog **link** in preference when the post offers one, and only the copied text otherwise. If size becomes a problem, a later change can cap or externalize it.
