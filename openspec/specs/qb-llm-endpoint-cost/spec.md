# qb-llm-endpoint-cost

## Purpose

Decide whether an LLM endpoint charges per token, from its address and model name alone, so the fallback can refuse to turn a free run into a paid one without being told to.

## Requirements

### Requirement: Whether an LLM endpoint charges per token is worked out from its address and model

The system SHALL decide whether an LLM endpoint costs money from its base URL
and its model name alone. The decision SHALL make no network call, read no
config key of its own, and reach no service — it is a pure function of two
strings, so it can be tested and cannot fail at run time.

An endpoint SHALL be treated as **free** when either:

- its host is a machine you own — a loopback address (`localhost`, `127.0.0.1`,
  `::1`, `0.0.0.0`), a private IPv4 address (`10.x.x.x`, `192.168.x.x`,
  `172.16.x.x` through `172.31.x.x`), or a host name ending in `.local`; or
- its model name ends in `:free`, which is how OpenRouter marks a model it does
  not charge for.

Every other endpoint SHALL be treated as **paid**. An address that cannot be
parsed SHALL be treated as paid, because guessing "free" would be the answer
that spends money.

#### Scenario: A local server is free
- **WHEN** the base URL is `http://127.0.0.1:8080/v1/chat/completions`
- **THEN** the endpoint is free

#### Scenario: A server on the home network is free
- **WHEN** the base URL is `http://192.168.1.40:8080/v1/chat/completions`
- **THEN** the endpoint is free

#### Scenario: A host name ending in .local is free
- **WHEN** the base URL is `http://workshop.local:8080/v1/chat/completions`
- **THEN** the endpoint is free

#### Scenario: An OpenRouter free model is free
- **WHEN** the base URL is `https://openrouter.ai/api/v1/chat/completions` AND the model is `qwen/qwen3-235b-a22b:free`
- **THEN** the endpoint is free

#### Scenario: A cloud endpoint with a paid model is paid
- **WHEN** the base URL is `https://openrouter.ai/api/v1/chat/completions` AND the model is `deepseek/deepseek-chat`
- **THEN** the endpoint is paid

#### Scenario: A public address is paid even for a model named like a local one
- **WHEN** the base URL is `https://llm.example.com/v1/chat/completions` AND the model is `qwen3-32b`
- **THEN** the endpoint is paid

#### Scenario: An unreadable address is treated as paid
- **WHEN** the base URL cannot be parsed as a URL
- **THEN** the endpoint is paid
