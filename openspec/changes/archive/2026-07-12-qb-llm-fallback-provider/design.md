# Design — optional fallback LLM provider

## Goal

Use the RTX 4090's local model when it is awake; quietly fall to OpenRouter when
it is not. Each provider runs its own model. No wake step, no cloud fallback for
anything except "the local server isn't there."

## Where it plugs in

```
        PostExtractor                     (unchanged — only sees LlmClient)
             │
             ▼
   ┌──────────────────────┐
   │  FallbackLlmClient    │  implements LlmClient
   └──────────────────────┘
        │              │
   try primary     on connection
   (4090 local)    failure only
        ▼              ▼
  OpenAiCompatible   OpenAiCompatible
   (local quant)      (OpenRouter, full precision)
```

The wrapper is only built when the fallback config fields are set. Otherwise
`main_repo_scraper.dart` builds the single `OpenAiCompatibleClient` exactly as
today, so the default path is unchanged.

## The fallback rule

Per post:

```
 local marked unreachable this run?
    ├─ yes ─────────────────────────────► call fallback (OpenRouter)
    └─ no
         └─ try primary (4090)
              ├─ success ─────────────────► return
              ├─ CONNECTION failure ──────► mark local unreachable (log once)
              │                             → call fallback for this post and
              │                               every post after it this run
              └─ any other error ─────────► rethrow (PostExtractor's existing
                                            retry-once → rule-based path)
```

### What counts as a "connection failure"

`OpenAiCompatibleClient` wraps network errors as `LlmException('Request failed',
cause)`, keeping the underlying error as `cause`:

| Situation | `cause` | Connection failure? |
|---|---|---|
| PC off / llama.cpp not started | `SocketException` (refused / unreachable) | **yes** → fall back |
| Bad host / DNS | `SocketException` | **yes** → fall back |
| Server there but slow | `TimeoutException` | no → rethrow |
| HTTP 4xx/5xx from a live server | none (status-code `LlmException`) | no → rethrow |
| Unparseable / wrong-shape JSON | none / parse error | no → rethrow |

So the crisp test is: **`e is LlmException && e.cause is SocketException`**.
A `TimeoutException` is explicitly *not* a connection failure — a slow local post
uses the existing rule-based fallback, not the cloud. (Easy to widen later if we
decide a mid-run sleep, which can surface as a timeout, should also flip to cloud.)

### Why latch for the whole run

If the primary is off, we do not want all ~555 backfill posts each to eat a
connection attempt (plus `PostExtractor`'s retry) before giving up. The first
failed post sets a `bool _primaryReachable = false` on the wrapper; every later
`complete()` sees it and goes straight to the fallback. Logged once, at the moment
it flips, with the primary URL and the fallback model, so `ModRepo.log` shows
which provider actually ran the batch.

The latch is one-way and per-run (the wrapper is rebuilt each run), so a PC that
wakes up between the 11am and 11pm runs is picked up again on the next run.

## Interaction with existing behavior

- **Retry-once + rule-based (existing).** `PostExtractor._callWithRetry` sits
  *above* the client. When the wrapper rethrows a non-connection error, that path
  runs unchanged. When the wrapper *handles* a connection failure by calling the
  fallback, the wrapper returns a normal `LlmResponse`, so `PostExtractor` sees a
  success and never retries.
- **Consecutive-failure bail (existing).** Still counts extractor-level failures
  (both the call *and* its retry failed). Because a connection failure is now
  absorbed by the fallback, it no longer contributes to the bail as long as the
  fallback answers. If the fallback *also* fails, that is a real failure and the
  bail counts it, exactly as today.
- **Throttling.** Build a `ThrottledClient` per provider so the cloud endpoint
  keeps its request spacing. For now both reuse the existing `llm_timeout_seconds`
  and delay; per-provider tuning is out of scope.

## Config

Reuse the primary keys; add a parallel fallback set. Fallback is enabled when
`llm_fallback_base_url` **and** `llm_fallback_model` are both non-blank.

```properties
# Primary — the 4090 (opportunistic; usually asleep)
llm_base_url          = http://<4090-ip>:8080/v1/chat/completions
llm_model             = Qwen3.6-35B-A3B-GGUF-UD-IQ4_XS
llm_disable_thinking  = true
# llm_api_token is usually blank for a local server

# Fallback — OpenRouter (full-precision model, its own key)
llm_fallback_base_url         = https://openrouter.ai/api/v1/chat/completions
llm_fallback_model            = deepseek/deepseek-chat
llm_fallback_api_token        = sk-or-...
llm_fallback_disable_thinking = false
```

`llm_fallback_disable_thinking` defaults to **false** — cloud endpoints reject the
unknown `think` / `chat_template_kwargs` body fields, so it must stay off for
OpenRouter. It exists only in case both providers are ever local servers.

## Alternatives considered

- **Startup health probe to pick the provider once.** Rejected as redundant: the
  first post's connection failure is itself the probe, and the run-long latch
  gives the same "don't knock on a dead server repeatedly" benefit with less code.
- **Wake-on-LAN from the scraper.** Out of scope by decision — the 4090 is used
  opportunistically, not woken.
- **Falling back on any failure + a circuit breaker.** Rejected by decision — only
  connection failures fall back; content failures keep today's rule-based path.
