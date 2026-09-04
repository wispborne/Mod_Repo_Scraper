## MODIFIED Requirements

### Requirement: An optional fallback LLM provider covers an unreachable primary

The system SHALL support a second, optional LLM provider, configured through
`llm_fallback_base_url`, `llm_fallback_model`, `llm_fallback_api_token`, and
`llm_fallback_disable_thinking` in `config.properties`, loaded into `BotConfig`
alongside the primary `llm_*` settings. The fallback SHALL be considered enabled
only when both `llm_fallback_base_url` and `llm_fallback_model` are non-blank.
When it is not enabled, the pipeline SHALL use the single primary provider and
behave exactly as it did before this capability existed.

When the fallback is enabled, the system SHALL send each post to the primary
provider first and SHALL use the fallback provider when the primary call fails
and the cost rule below permits the switch. Each provider MAY run its own model;
the primary and fallback answers SHALL share the one content-fingerprinted cache
and SHALL NOT be re-run against each other.

#### Scenario: Fallback not configured
- **WHEN** `llm_enabled` is true AND the fallback fields are blank
- **THEN** only the primary provider is used and the pipeline behaves exactly as before this capability

#### Scenario: Primary reachable
- **WHEN** the fallback is enabled AND a post's primary call succeeds
- **THEN** the primary's answer is used and the fallback provider is not called for that post

#### Scenario: Primary unreachable
- **WHEN** the fallback is enabled AND the cost rule permits the switch AND a post's primary call fails with a connection-level error (e.g. the local server is off or not listening)
- **THEN** that post is sent to the fallback provider and the fallback's answer is used

### Requirement: An unreachable primary is detected once and skipped for the rest of the run

Once the primary provider has failed during a run in a way the cost rule permits
switching for, the system SHALL stop calling the primary for the remainder of
that run and SHALL send every following post directly to the fallback provider,
logging the switch exactly once with the primary endpoint and the fallback model.
This latch SHALL be per-run, so a later run re-attempts the primary. The latch
SHALL close on any such failure, including a non-success status and an unreadable
answer, not only on an unreachable server.

#### Scenario: Later posts skip a known-dead primary
- **WHEN** the primary has already failed with a connection-level error earlier in the run
- **THEN** each remaining post is sent straight to the fallback provider without calling the primary again

#### Scenario: Switch is logged once
- **WHEN** the primary is first found unreachable in a run
- **THEN** a single log entry records the switch, naming the primary endpoint and the fallback model

#### Scenario: A new run re-attempts the primary
- **WHEN** a fresh run starts after an earlier run switched to the fallback
- **THEN** the primary is tried again on that run's first post

#### Scenario: A bad status latches the switch too
- **WHEN** the fallback is enabled AND the cost rule permits the switch AND the primary returns a non-success status
- **THEN** that post goes to the fallback and every following post goes straight to the fallback for the rest of the run

## ADDED Requirements

### Requirement: Switching to the fallback is allowed only when it does not turn a free run into a paid one

The system SHALL decide, once per run, whether the primary may fall over to the
fallback at all, by comparing what the two endpoints cost (see the
`qb-llm-endpoint-cost` capability).

- Where the fallback does **not** cost money the primary was already costing —
  both paid, both free, or a paid primary with a free fallback — the switch SHALL
  be permitted.
- Where the primary is **free** and the fallback is **paid**, the switch SHALL be
  permitted only when `llm_fallback_free_to_paid` is `true`. That key SHALL
  default to `false`.

When the switch is permitted, **any** primary failure SHALL send that post to the
fallback and latch the switch for the rest of the run — a connection-level error,
a timeout, a non-success status, and an answer envelope that cannot be read.

When the switch is forbidden, the system SHALL never call the fallback: every
primary failure SHALL be rethrown so the existing retry-once-then-rule-based path
runs, exactly as it does with no fallback configured. The system SHALL log this
once per run, naming both endpoints and `llm_fallback_free_to_paid`, so a
configured fallback that can never fire is not silent.

The extraction answer's own JSON is parsed above the client, so a model that
returns unusable extraction JSON SHALL continue to follow the retry-at-a-higher-
temperature path and SHALL NOT reach the fallback rule.

#### Scenario: Both endpoints are paid
- **WHEN** the primary and the fallback are both paid AND the primary returns a non-success status
- **THEN** the post goes to the fallback, whatever `llm_fallback_free_to_paid` is set to

#### Scenario: A free primary with a free fallback
- **WHEN** both endpoints are free AND the primary fails for any reason
- **THEN** the post goes to the fallback, whatever `llm_fallback_free_to_paid` is set to

#### Scenario: A paid primary with a free fallback
- **WHEN** the primary is paid AND the fallback is free AND the primary fails for any reason
- **THEN** the post goes to the fallback

#### Scenario: A free primary and a paid fallback, switch off
- **WHEN** the primary is free AND the fallback is paid AND `llm_fallback_free_to_paid` is false AND the primary cannot be reached
- **THEN** the fallback is not called, the failure is rethrown, and the post follows the retry-then-rule-based path

#### Scenario: A free primary and a paid fallback, switch on
- **WHEN** the primary is free AND the fallback is paid AND `llm_fallback_free_to_paid` is true AND the primary fails for any reason
- **THEN** the post goes to the fallback and the switch latches for the rest of the run

#### Scenario: A fallback that can never fire says so
- **WHEN** a fallback is configured AND the cost rule forbids the switch
- **THEN** one log entry names both endpoints and `llm_fallback_free_to_paid`

#### Scenario: Unusable extraction JSON does not reach the fallback
- **WHEN** the primary answers successfully but the extraction JSON in that answer cannot be parsed
- **THEN** the fallback is not called and the existing retry-at-a-higher-temperature path runs

## REMOVED Requirements

### Requirement: Only connection failures fall back; other failures keep the rule-based path

**Reason**: The rule it states is no longer the rule, and half of it had already
stopped being true — it said a timeout must not fall back, while the code has
latched the switch on a timeout since commit 0a4516b (12 July 2026). What decides
the switch now is whether it costs money, not which failure happened.

**Migration**: Replaced by "Switching to the fallback is allowed only when it does
not turn a free run into a paid one". Anyone relying on the old behaviour of a
free local primary falling over to a paid cloud fallback must set
`llm_fallback_free_to_paid = true` in `config.properties`; without it a free
primary now keeps the rule-based path on every failure.
