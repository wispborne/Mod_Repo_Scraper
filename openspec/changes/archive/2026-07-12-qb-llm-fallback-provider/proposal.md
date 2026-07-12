## Why

LLM extraction runs on a schedule (11am / 11pm) on a laptop server. The best
local model lives on a separate PC with an RTX 4090, but that PC is usually off.
Today the pipeline points at exactly one endpoint, so if we point it at the 4090
it fails every time the PC is asleep, and if we point it at the cloud we never
use the fast free hardware when it *is* on.

We want the 4090 used when it happens to be awake, and a paid cloud endpoint
(OpenRouter) to quietly take over when it is not — with each provider running
its own model (the 4090 a quantized GGUF, OpenRouter a full-precision model).

The existing design already makes this cheap: everything downstream talks only to
the `LlmClient` interface, and the on-disk cache is keyed by post content + prompt
version + field set — **not** by which model answered. So answers from the local
model and the cloud model share one cache and are never redone by the other.

## What Changes

- **A second, optional LLM endpoint.** New `llm_fallback_*` settings describe a
  fallback provider (base URL, model, API token, disable-thinking). The fallback
  is **on only when its fields are filled**; when they are blank the pipeline
  behaves exactly as today (single provider).
- **A `FallbackLlmClient` that wraps two `LlmClient`s.** It tries the primary
  (the 4090) first and falls to the fallback (OpenRouter) on a **connection
  failure only** — the "the server isn't there" signals: connection refused,
  host unreachable, DNS failure.
- **Connection failures latch for the run.** The first time the primary is found
  unreachable, the client logs it once and sends every remaining post straight to
  the fallback for the rest of the run — no repeated knocking on a sleeping PC.
- **Nothing else falls back.** If the primary *is* reachable but a specific post
  times out, returns a bad status, or returns unparseable JSON, that is handled
  by the existing retry-once-then-rule-based path. It does **not** go to the
  cloud. A timeout is treated as "reachable but slow," not a connection failure.
- **`PostExtractor`, the cache, grounding, and the bundle are untouched** — they
  only ever see an `LlmClient`.

## Impact

- Affected spec: `qb-llm-client` (adds the optional-fallback-provider capability).
- Affected code:
  - `lib/bot/common.dart` — new `llmFallback*` fields on `BotConfig`, read from
    `config.properties`.
  - `lib/bot/scraper/qb/llm/fallback_llm_client.dart` — **new** `FallbackLlmClient`.
  - `lib/bot/scraper/main_repo_scraper.dart` — build the primary client, and wrap
    it in a `FallbackLlmClient` when the fallback fields are set.
  - `config.properties` — new commented `llm_fallback_*` keys.
- No change to the bundle shape, the LLM store schema, the prompt, or the viewer.
- Not covered here (kept deliberately out of scope): waking the 4090
  (Wake-on-LAN), any circuit breaker on *content* failures, and per-provider
  throttle/timeout tuning.
