# qb-llm-client — delta

## MODIFIED Requirements

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
