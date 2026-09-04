## 1. The free/paid decision

- [x] 1.1 Add `lib/bot/scraper/qb/llm/endpoint_cost.dart` with an `EndpointCost` enum (`free`, `paid`) and `endpointCost({required String baseUrl, required String model})`
- [x] 1.2 Treat as free: loopback hosts (`localhost`, `127.0.0.1`, `::1`, `0.0.0.0`), private IPv4 ranges (`10.*`, `192.168.*`, `172.16.*`–`172.31.*`), host names ending `.local`, and any model name ending `:free`
- [x] 1.3 Treat everything else as paid, including a base URL that will not parse
- [x] 1.4 Add `test/qb_endpoint_cost_test.dart` covering every scenario in `specs/qb-llm-endpoint-cost/spec.md`, plus the `172.15`/`172.32` edges either side of the private range

## 2. The config key

- [x] 2.1 Add `llmFallbackFreeToPaid` to `BotConfig` in `lib/bot/common.dart`, read from `llm_fallback_free_to_paid`, default false
- [x] 2.2 Add `llm_fallback_free_to_paid` to `Common._recognizedKeys`
- [x] 2.3 Add the key to `config.example.properties` in the fallback block, with a plain-English note saying what it does and that a local-primary-plus-cloud-fallback setup needs it set to `true`
- [x] 2.4 Rewrite the fallback block's existing comment — it says the fallback is used "only when the primary can't be reached at all", which stops being true

## 3. The wrapper

- [x] 3.1 Add `bool switchAllowed = true` to `FallbackLlmClient`'s constructor
- [x] 3.2 When `switchAllowed` is false, log once at construction naming both endpoints and `llm_fallback_free_to_paid`, and make `complete()` always delegate to the primary and rethrow its failures
- [x] 3.3 Delete `_shouldSwitchToFallback`; any `LlmException` from the primary now closes the latch and goes to the fallback
- [x] 3.4 Keep the log-once-on-the-flip behaviour and its no-`await`-between-read-and-set comment — several calls are in flight at once
- [x] 3.5 Rewrite the class doc comment: the rule is now about cost, not about which failure happened, and note that extraction JSON is parsed above the client so it never arrives here

## 4. Wiring

- [x] 4.1 Add `fallbackFreeToPaid` to `LlmSettings` in `lib/manager/scraper_settings.dart` and to `LlmSettings.fromConfig`
- [x] 4.2 In `ScraperService._buildExtractor`, work out both endpoints' cost and pass `switchAllowed:` to `FallbackLlmClient` — false only when the primary is free, the fallback is paid, and `fallbackFreeToPaid` is false

## 5. Tests

- [x] 5.1 Rewrite the `status-code error (no cause): rethrows, no fallback (4.5)` test — a bad status now falls back when switching is allowed
- [x] 5.2 Add: a bad status latches the switch for the rest of the run
- [x] 5.3 Add: with `switchAllowed: false`, a connection failure rethrows and the fallback is never called
- [x] 5.4 Add: with `switchAllowed: false`, the fallback is never called across several failures (the latch cannot open by accident)
- [x] 5.5 Add a `BotConfig` test for `llm_fallback_free_to_paid` defaulting to false and reading `true`
- [x] 5.6 Add an `LlmSettings.fromConfig` test carrying the flag through
- [x] 5.7 Run `dart test` and confirm the whole suite passes

## 6. Documentation

- [x] 6.1 Update the QB LLM section of `CLAUDE.md` to describe the cost gate, the widened latch, and the new key
- [x] 6.2 Note in the change folder that archiving needs the spec delta hand-applied with `--skip-specs`, because it carries MODIFIED requirements

## Archiving note

`specs/qb-llm-client/spec.md` carries MODIFIED requirements, which
`openspec archive` cannot apply. Hand-apply the delta to
`openspec/specs/qb-llm-client/spec.md`, then archive with `--skip-specs`.
