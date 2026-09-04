## Why

The LLM fallback switches on two failures only — the primary can't be reached, or
it timed out. Anything else (a bad HTTP status, an unreadable answer envelope)
is rethrown and the post ends up with rules-only downloads, even when a working
second endpoint is sitting right there. The reason it was written that way was
cost: the switch latches for the whole run, so one 500 from a free local server
would send every remaining topic to a paid cloud endpoint.

That reasoning only holds when the fallback costs more than the primary. Where
both endpoints are paid, or both free, switching on a bad reply costs nothing
new. So the rule should be about money, not about which kind of failure happened.

## What Changes

- Work out whether each endpoint charges per token, from its address and model
  name: a loopback or private-network host is free, an OpenRouter model name
  ending in `:free` is free, anything else is paid.
- **Any** primary failure now latches the switch to the fallback for the rest of
  the run — a bad status and an unreadable answer join the existing connection
  failure and timeout — as long as switching does not turn a free run into a
  paid one.
- **BREAKING**: a free primary no longer falls back to a paid endpoint by
  default. New key `llm_fallback_free_to_paid` (default `false`) turns that back
  on; with it `true`, a free primary falls over to a paid fallback on any
  failure, as it does today. Anyone running a local primary with a cloud
  fallback must set this to `true` to keep the behaviour they have.
- When a fallback is configured but the cost gate forbids ever using it, say so
  once in the log, naming the key to turn on. Today a fallback that never fires
  is silent.

## Capabilities

### New Capabilities
- `qb-llm-endpoint-cost`: deciding whether an LLM endpoint charges per token,
  from its base URL and model name, with no network call and no new config.

### Modified Capabilities
- `qb-llm-client`: the fallback rule changes. "Only connection failures fall
  back" becomes "any failure falls back, unless it would turn a free primary
  into a paid one". The timeout requirement is also corrected — it has said
  timeouts do not fall back since July 2026, when the code started falling back
  on them.

## Impact

- `lib/bot/scraper/qb/llm/fallback_llm_client.dart` — the switch rule.
- `lib/bot/scraper/qb/llm/endpoint_cost.dart` — new, the free/paid decision.
- `lib/bot/common.dart` — the new key on `BotConfig` and in `_recognizedKeys`.
- `lib/manager/scraper_settings.dart` — the new field on `LlmSettings`.
- `lib/manager/scraper_service.dart` — works out the gate and passes it in.
- `config.example.properties` — the new key with its note.
- `test/qb_fallback_llm_client_test.dart`, plus tests for the cost decision.
- Nothing on the wire, in the bundle, in `ModRepo.json` or on the website
  changes. No model is added or removed.
