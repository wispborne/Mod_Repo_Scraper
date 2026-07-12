## ADDED Requirements

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
- **WHEN** `enable_llm` is true AND the fallback fields are blank
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
