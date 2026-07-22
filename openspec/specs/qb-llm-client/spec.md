# qb-llm-client

## Purpose

Talk to any OpenAI-style language model in a safe, bounded way — off unless switched on, capped in how much it spends, and able to carry on when the model is unreachable or answers badly.
## Requirements
### Requirement: LLM feature is off by default and configured via config.properties
The system SHALL read LLM settings from `config.properties` into `BotConfig`, and SHALL perform no LLM calls unless `llm_enabled` is true.

#### Scenario: Feature disabled
- **WHEN** `llm_enabled` is absent or false
- **THEN** the QB pipeline behaves exactly as before, makes no LLM calls, and writes no LLM extras to the bundle

#### Scenario: Feature enabled with no API token (local endpoint)
- **WHEN** `llm_enabled` is true AND `llm_api_token` is blank
- **THEN** the system still runs LLM extraction and sends requests without an `Authorization` header (so a keyless local endpoint like Ollama works), logging a note that no token is set

#### Scenario: Settings loaded
- **WHEN** `llm_enabled`, `llm_api_token`, `llm_model`, and `llm_base_url` are set
- **THEN** they load into `BotConfig` and drive the LLM client, mirroring how `modrepo_discord_auth_token` / `modrepo_nexus_api_token` load today (the legacy key `openrouter_api_token` is not read; it is reported by the startup unknown-key warning)

### Requirement: LLM access is behind a provider-agnostic interface
The system SHALL call the LLM through an `LlmClient` interface, implemented against any OpenAI-compatible chat-completions endpoint (OpenRouter, OpenAI, DeepSeek, or a local server such as Ollama / LM Studio / llama.cpp), so a different provider (including a local model) can be substituted by config alone without changing the extraction logic.

#### Scenario: OpenAI-compatible implementation
- **WHEN** the feature is enabled
- **THEN** an `OpenAiCompatibleClient` implementing `LlmClient` issues HTTP requests to `llm_base_url` using `llm_model`, and includes a Bearer `Authorization` header only when `llm_api_token` is set

### Requirement: LLM results are stored on disk as cache, source of truth, and resume point
The system SHALL keep one on-disk store keyed by topicId with a fingerprint over the exact input sent to the model (reduced post content + rule-link hints + requested field set + prompt version) and a schema version, reusing the resolver's cache pattern. Each entry SHALL hold the finished per-topic result (merged downloads and extras), so the bundle publisher reads from this store. A store hit with a matching fingerprint SHALL skip the network call. The store SHALL be written as the run progresses (not only at the end), through a single serialized writer, so that an interrupted run resumes and only unfinished topics call the LLM on restart.

#### Scenario: Repeat run uses the store
- **WHEN** a topic's post content and the prompt version are unchanged since the last run
- **THEN** the stored result is used and no LLM network call is made for that topic

#### Scenario: Interrupted run resumes
- **WHEN** a run is interrupted after some topics finished but before all did, and is started again
- **THEN** the finished topics are served from the store and only the unfinished topics make LLM calls

#### Scenario: Changed post invalidates cache
- **WHEN** a topic's post content changes (its fingerprint differs)
- **THEN** the LLM is called again for that topic and the cache entry is replaced

#### Scenario: Prompt or schema version bump re-runs
- **WHEN** the prompt version or schema version is increased
- **THEN** all affected cache entries are treated as stale and re-run on the next live run

### Requirement: LLM requests use deterministic JSON settings
The system SHALL send requests as an OpenAI-style chat completion using the project's HTTP client, with `temperature` set to 0, a JSON response format requested, and streaming disabled, so answers are faithful and stable enough for the content-fingerprint cache.

#### Scenario: Deterministic extraction request
- **WHEN** the client sends a post to the LLM
- **THEN** the request sets `temperature: 0`, asks for a JSON response, and does not stream

#### Scenario: Truncated answer is not half-saved
- **WHEN** the model's answer is cut off at the token limit
- **THEN** the affected field (e.g. a long changelog) is treated as not captured rather than saved partially

### Requirement: A wrong response is retried, then falls back
When a call errors, returns a non-success status, or returns a body that cannot be parsed or does not match the expected shape, the system SHALL retry the call up to two more times (three attempts in total). If every attempt fails, the topic SHALL fall back to the rule-based downloads only, with no LLM extras written for it. A timeout is the exception: it SHALL NOT be retried, because the retry would run under the same limit and almost always time out again — the topic falls straight back to the rule-based downloads.

#### Scenario: First attempt is unusable, a retry succeeds
- **WHEN** the first response is malformed or errors AND a following retry returns a valid, parseable answer
- **THEN** the retry's answer is used for that topic

#### Scenario: All attempts fail
- **WHEN** the first attempt and both of its retries fail
- **THEN** the topic falls back to rule-based downloads only, no LLM extras are written, and the run continues with the next topic

#### Scenario: A timeout is not retried
- **WHEN** a call times out
- **THEN** the system does not retry it and the topic falls back to rule-based downloads only

### Requirement: Every LLM error is logged
The system SHALL log every LLM failure through the existing logger, including the topicId and the reason — HTTP errors, timeouts, non-success statuses, parse failures, shape-check failures, each dropped (grounded-out) URL or fact, retries, and fallbacks. Nothing SHALL fail silently. Successful calls SHALL log their token usage.

#### Scenario: Failure is recorded
- **WHEN** any LLM call fails or any returned item is dropped by grounding
- **THEN** a log entry is written with the topicId and the specific reason

#### Scenario: Cost is visible
- **WHEN** an LLM call succeeds
- **THEN** its token usage (from the response) is logged

### Requirement: LLM calls are throttled, run with small overlap, and bail on consecutive failures
The system SHALL rate-limit LLM calls (spacing provider requests even when a few topics are in flight at once), apply a timeout, and count failures that occur in a row. The LLM step MAY run under the pipeline's existing bounded overlap (a small, configurable number of calls in flight); shared counters SHALL be updated under a lock. Once the number of consecutive failures — counted in call-completion order — reaches a configurable threshold (default around 10), the system SHALL stop making LLM calls for the remainder of the run and proceed on the rules alone. Any successful call SHALL reset the consecutive-failure count to zero. Scattered failures that do not occur back-to-back SHALL NOT trip the bail. Under overlap the bail MAY fire a call or two later than the exact threshold, which is acceptable.

#### Scenario: Provider is down
- **WHEN** LLM calls fail one after another and reach the consecutive-failure threshold
- **THEN** no further LLM calls are made for the remainder of the run, this is logged, and remaining topics use rule-based downloads only

#### Scenario: Occasional scattered failures do not bail
- **WHEN** individual calls fail here and there but successes occur in between
- **THEN** the consecutive-failure count resets on each success and the run keeps using the LLM

### Requirement: An optional total-volume cap is off by default
The system SHALL support a configurable cap on how many posts the LLM may process per run, and it SHALL be disabled by default. When unset, no total-volume limit applies (the consecutive-failure bail is the only automatic stop).

#### Scenario: Cap unset
- **WHEN** no total-volume cap is configured
- **THEN** the LLM may process every post (subject to caching and the consecutive-failure bail)

#### Scenario: Cap set and reached
- **WHEN** a total-volume cap is configured AND the number of posts processed by the LLM reaches it
- **THEN** no further LLM calls are started for the remainder of the run, this is logged, and remaining topics use rule-based downloads only

#### Scenario: Cap is a soft ceiling under overlap
- **WHEN** a cap is configured AND a few calls are in flight when it is reached
- **THEN** the already-started calls may finish, so the cap may be exceeded by up to (concurrency − 1) — an accepted small overshoot

### Requirement: An optional fallback LLM provider covers an unreachable primary

The system SHALL support a second, optional LLM provider, configured through
`llm_fallback_base_url`, `llm_fallback_model`, `llm_fallback_api_token`, and
`llm_fallback_disable_thinking` in `config.properties`, loaded into `BotConfig`
alongside the primary `llm_*` settings. The fallback SHALL be considered enabled
only when both `llm_fallback_base_url` and `llm_fallback_model` are non-blank.
When it is not enabled, the pipeline SHALL use the single primary provider and
behave exactly as it did before this capability existed.

When the fallback is enabled, the system SHALL send each post to the primary
provider first and SHALL use the fallback provider for that post **only** when the
primary call fails with a connection-level error — the "the server isn't there"
signals such as connection refused, host unreachable, or DNS failure. Each
provider MAY run its own model; the primary and fallback answers SHALL share the
one content-fingerprinted cache and SHALL NOT be re-run against each other.

#### Scenario: Fallback not configured
- **WHEN** `llm_enabled` is true AND the fallback fields are blank
- **THEN** only the primary provider is used and the pipeline behaves exactly as before this capability

#### Scenario: Primary reachable
- **WHEN** the fallback is enabled AND a post's primary call succeeds
- **THEN** the primary's answer is used and the fallback provider is not called for that post

#### Scenario: Primary unreachable
- **WHEN** the fallback is enabled AND a post's primary call fails with a connection-level error (e.g. the local server is off or not listening)
- **THEN** that post is sent to the fallback provider and the fallback's answer is used

### Requirement: Only connection failures fall back; other failures keep the rule-based path

When the primary provider is reachable but a call times out, returns a
non-success status, or returns a body that cannot be parsed or does not match the
expected shape, the system SHALL NOT send that post to the fallback provider.
Such a post SHALL instead follow the existing retry-once-then-rule-based path. A
timeout SHALL be treated as "reachable but slow," not as a connection failure.

#### Scenario: Primary times out
- **WHEN** the fallback is enabled AND a primary call times out
- **THEN** the post does not go to the fallback provider and follows the existing retry-then-rule-based behavior

#### Scenario: Primary returns a bad status or unparseable answer
- **WHEN** the fallback is enabled AND a primary call returns a non-success status or an answer that cannot be parsed
- **THEN** the post does not go to the fallback provider and follows the existing retry-then-rule-based behavior

### Requirement: An unreachable primary is detected once and skipped for the rest of the run

Once the primary provider is found unreachable during a run, the system SHALL
stop calling the primary for the remainder of that run and SHALL send every
following post directly to the fallback provider, logging the switch exactly once
with the primary endpoint and the fallback model. This latch SHALL be per-run, so
a later run re-attempts the primary.

#### Scenario: Later posts skip a known-dead primary
- **WHEN** the primary has already failed with a connection-level error earlier in the run
- **THEN** each remaining post is sent straight to the fallback provider without calling the primary again

#### Scenario: Switch is logged once
- **WHEN** the primary is first found unreachable in a run
- **THEN** a single log entry records the switch, naming the primary endpoint and the fallback model

#### Scenario: A new run re-attempts the primary
- **WHEN** a fresh run starts after an earlier run switched to the fallback
- **THEN** the primary is tried again on that run's first post
