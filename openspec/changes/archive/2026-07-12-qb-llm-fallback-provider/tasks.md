## 1. Config

- [x] 1.1 In `lib/bot/common.dart`, add fields to `BotConfig`: `llmFallbackBaseUrl` (String?), `llmFallbackModel` (String?), `llmFallbackApiToken` (String?), `llmFallbackDisableThinking` (bool, default false)
- [x] 1.2 Read them from `config.properties` in `readConfig`: `llm_fallback_base_url`, `llm_fallback_model`, `llm_fallback_api_token`, `llm_fallback_disable_thinking` (use `_trimOrNull` / the `?.toLowerCase() == 'true'` pattern already used for the primary keys)
- [x] 1.3 Add a `bool get llmFallbackEnabled` on `BotConfig` — true when `llmFallbackBaseUrl` and `llmFallbackModel` are both non-blank
- [x] 1.4 If `BotConfig` is a `@MappableClass`, regenerate: `dart run build_runner build --delete-conflicting-outputs`
- [x] 1.5 Add the four commented `llm_fallback_*` keys to `config.properties` with a short plain-English note that the fallback is used only when the primary server can't be reached, and that `llm_fallback_disable_thinking` must stay false for cloud endpoints

## 2. FallbackLlmClient

- [x] 2.1 Add `lib/bot/scraper/qb/llm/fallback_llm_client.dart`: `class FallbackLlmClient implements LlmClient` holding a `primary` and a `fallback` `LlmClient`, plus a `bool _primaryReachable = true` latch and a `Logger`
- [x] 2.2 In `complete`, when `_primaryReachable` is false, call `fallback.complete` directly (skip the primary)
- [x] 2.3 Otherwise call `primary.complete`; on success return it
- [x] 2.4 Catch `LlmException`: if `_isConnectionFailure(e)` (see 2.5), set `_primaryReachable = false`, log once at WARNING with the primary URL and the fallback model, then return `await fallback.complete(request)`; for any other `LlmException`, rethrow unchanged
- [x] 2.5 Add `bool _isConnectionFailure(LlmException e) => e.cause is SocketException;` — explicitly NOT `TimeoutException`, status-code errors, or parse errors (import `dart:io` for `SocketException`)
- [x] 2.6 Do not add retry logic here — `PostExtractor._callWithRetry` already sits above the client and must keep owning retries

## 3. Wiring

- [x] 3.1 In `main_repo_scraper.dart` (around line 371), build the primary `OpenAiCompatibleClient` from the existing `llm*` config as today
- [x] 3.2 When `config.llmFallbackEnabled`, build a second `OpenAiCompatibleClient` from the `llmFallback*` config (its own `ThrottledClient`, model, token, and `disableThinking`), and wrap both in a `FallbackLlmClient`; pass the wrapper to `PostExtractor` instead of the bare primary
- [x] 3.3 When the fallback is not enabled, pass the single primary client exactly as today (no behavior change)
- [x] 3.4 Extend the "LLM extraction enabled" startup log line to note the fallback model + endpoint when the fallback is enabled
- [x] 3.5 Ensure any extra `ThrottledClient` created for the fallback is closed alongside the existing `llmClient?.close()`

## 4. Tests

- [x] 4.1 Unit test `FallbackLlmClient`: primary succeeds → fallback never called
- [x] 4.2 Primary throws `LlmException(cause: SocketException)` → fallback is called and its answer returned; latch is now closed
- [x] 4.3 After a connection failure, a second `complete` goes straight to fallback without touching the primary (assert the primary's call count stays at 1)
- [x] 4.4 Primary throws `LlmException(cause: TimeoutException)` → rethrown, fallback NOT called, latch stays open
- [x] 4.5 Primary throws a status-code `LlmException` (no cause) → rethrown, fallback NOT called
- [x] 4.6 `BotConfig.llmFallbackEnabled` is false when either fallback field is blank, true when both are set

## 5. Verify

- [x] 5.1 `dart test` green
- [x] 5.2 Manual: point `llm_base_url` at a dead port with fallback set → confirm the run logs the one-time switch and finishes on the fallback; point it at a live local server → confirm the fallback is never called
- [x] 5.3 Confirm a run with the fallback fields blank behaves exactly as before this change
