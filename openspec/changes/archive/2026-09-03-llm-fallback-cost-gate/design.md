## Context

`FallbackLlmClient` wraps two `LlmClient`s. Today it switches to the second one
on exactly two failures — `LlmException.cause is SocketException` and
`... is TimeoutException` — and latches that switch for the life of the wrapper,
which is one run. Everything else is rethrown, and `PostExtractor._callWithRetry`
retries once and then gives the topic rules-only downloads.

Two facts about the current code shape the design:

- **The wrapper only ever sees the client's own failures.** `OpenAiCompatibleClient`
  throws `LlmException` for a bad base URL, a network error or timeout (with a
  `cause`), a non-success status, and an answer envelope it cannot read (no
  `choices`, no message content, cut off at the token limit). The extraction JSON
  is parsed in `PostExtractor`, *above* the client, so a model that answers with
  junk never reaches the wrapper at all. Widening the wrapper's rule therefore
  buys bad statuses and unreadable envelopes, and nothing else.
- **The latch is what made cost the deciding factor.** One failure moves the
  whole rest of the run. That is the right behaviour for a sleeping PC and the
  wrong one for a single 500 — but only when the fallback costs more.

## Goals / Non-Goals

**Goals:**

- Decide the switch on money, not on which failure happened.
- Let a paid-to-paid or free-to-free pairing use the fallback on any failure.
- Never turn a free run into a paid one without being told to, in writing.
- Say something in the log when a configured fallback can never fire.

**Non-Goals:**

- Making the extractor's JSON parse failure able to reach the fallback. It sits
  above the client and moving it is a larger change with its own risks.
- Per-provider timeouts, delays or token limits. Still shared.
- Reading prices from anywhere. No network call, no price table, no API probe.
- Any change to what is published — bundle, `ModRepo.json`, website.

## Decisions

### The free/paid decision is a pure function in its own file

`lib/bot/scraper/qb/llm/endpoint_cost.dart` holds an `EndpointCost` enum
(`free`, `paid`) and one function over `(baseUrl, model)`. No config, no network,
no clock. `FallbackLlmClient` does not call it — the cost comparison happens in
`ScraperService._buildExtractor`, where both endpoints' settings are already in
hand, and the wrapper is handed the answer as one boolean.

*Why not put it in the wrapper?* The wrapper would then need four strings and a
config flag to work out something it can be told. Keeping it out means the
wrapper's rule is testable with a boolean and the cost rule is testable with two
strings.

*Alternative rejected — explicit `llm_paid` / `llm_fallback_paid` keys.* Two more
keys to keep right, and getting one wrong silently changes what gets spent. The
addresses already say enough.

### Private and `.local` addresses count as free, not just loopback

A home LLM box is often another machine on the network — `192.168.1.40`, or
`workshop.local` — not `127.0.0.1`. Reading those as paid would gate the switch
for the exact setup the fallback was built for. So loopback, the three private
IPv4 ranges and `.local` host names are all free.

*Trade-off:* a paid proxy sitting on localhost or on the LAN would be read as
free, and the gate would then block a switch that costs nothing. The failure
direction is safe — it under-spends, and `llm_fallback_free_to_paid` reopens it.

### `:free` on the model name counts as free

OpenRouter's own convention for a model it does not charge for. It means a free
OpenRouter primary with a paid OpenRouter fallback is read correctly, which is
the pairing the address alone cannot tell apart.

### The wrapper takes one boolean, and logs at construction when it is false

`FallbackLlmClient({..., bool switchAllowed = true})`. When false, `complete()`
always rethrows and the fallback is never called — the same behaviour as no
fallback at all. The one log line goes out when the wrapper is built, not on the
first failure, so it appears even on a run where the primary never fails; a
fallback that can never fire is worth knowing about before it matters.

*Alternative rejected — skip building the wrapper when the switch is forbidden.*
Simpler, but then nothing holds the explanation, and a user who configured a
fallback would see no sign of why it never fired.

### Any failure latches, once switching is allowed

`_shouldSwitchToFallback` goes away: every `LlmException` from the primary
switches. That includes `Invalid llm_base_url` — a config typo — which will now
be absorbed by the fallback rather than surfacing as failed calls. The one log
line names the primary endpoint and quotes the error, so the typo is still
visible; and `PostExtractor`'s consecutive-failure bail no longer has to be the
thing that catches it.

## Risks / Trade-offs

- **[The default silently turns off an existing production fallback]** → A local
  primary with a cloud fallback stops falling over the moment this ships, and the
  only sign is the new log line. Mitigation: the log line at construction names
  the key to set, `config.example.properties` says it plainly, and the migration
  note in the spec delta spells it out. This is a deliberate choice, not an
  accident of the design.
- **[One transient 500 moves a whole paid run to the fallback]** → Accepted, and
  chosen over per-post switching: the latch is what stops a broken primary being
  knocked on for every topic, and a paid-to-paid switch costs no more than staying
  put. A fallback running a worse model for a whole run is the real cost here.
- **[A paid endpoint on a private address is read as free]** → Under-spends
  rather than over-spends, and `llm_fallback_free_to_paid = true` reopens it.
- **[Bad extraction JSON still cannot reach the fallback]** → Unchanged from
  today, and the largest remaining gap: `llm_structured_output = true` on the
  primary is what actually prevents it. Called out in the spec so it is a known
  limit rather than a surprise.
