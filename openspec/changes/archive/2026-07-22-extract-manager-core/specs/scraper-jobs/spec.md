# scraper-jobs

## ADDED Requirements

### Requirement: A job is an explicit request
The manager core SHALL accept work only as a job request that fully describes what to do: the kind, and (per kind) topic ids, scope, boards, page limits, whether to run LLM extraction, and whether replaying cached HTML is allowed. The service SHALL read environment (tokens, keys, endpoints, data path) and guardrails (spend caps, throttle delays, page caps) from the config file at construction, and SHALL NOT read job-shape config keys (`qb_scope`, `qb_boards`, `qb_use_cached`, `llm_enabled`, page limits) at any point.

#### Scenario: Job shape comes only from the request
- **WHEN** a job request with scope `topics` is handed to the service while `config.properties` says `qb_scope=all`
- **THEN** the run covers only the requested topics, and the config file's scope value has no effect

#### Scenario: Environment cannot be overridden by a request
- **WHEN** a job request is built
- **THEN** it has no fields for tokens, API keys, endpoints, or the data path — those come only from the service's construction

### Requirement: Job kinds match the cache layers
The core SHALL support these job kinds: `fullRun`, `rescrapeTopics`, `resolveDownloads`, `extractLlm`, `llmCoveragePass`, `llmTest`, and `rebuildBundle`. Each per-topic kind SHALL drop only its own layer's cached entries for the chosen topics before re-running that stage: `resolveDownloads` drops download-candidate and probe entries; `extractLlm` drops LLM extraction entries; `rescrapeTopics` re-fetches the pages and re-runs the full per-topic chain (parse, resolve, extract). No kind SHALL touch cache entries for topics it was not asked about.

#### Scenario: Re-resolving downloads leaves LLM results alone
- **WHEN** a `resolveDownloads` job runs for topic 123
- **THEN** topic 123's download-candidate and probe cache entries are dropped and rebuilt, and its LLM extraction cache entry is unchanged

#### Scenario: Other topics are untouched
- **WHEN** an `extractLlm` job runs for topic 123
- **THEN** the LLM extraction cache entry for topic 456 is byte-identical before and after

#### Scenario: Re-scraping runs the whole per-topic chain
- **WHEN** a `rescrapeTopics` job runs for topic 123
- **THEN** the topic's page is fetched fresh, parsed, its downloads re-resolved, LLM extraction re-run (when requested and configured), the stored detail updated, and the bundle rebuilt

### Requirement: Per-topic jobs always fetch live
`rescrapeTopics` SHALL fetch pages from the network — throttled and recorded to the raw cache — even when `qb_use_cached=true`. Only `fullRun` SHALL honor a replay-allowed setting, taken from its request.

#### Scenario: Reprocess ignores replay mode
- **WHEN** `qb_use_cached=true` and a `rescrapeTopics` job runs
- **THEN** the topic pages are fetched from the network, not replayed from the raw cache

### Requirement: Jobs run one at a time
The job manager SHALL run at most one job at a time. Requests made while a job is running SHALL wait in a queue in arrival order.

#### Scenario: Second job waits
- **WHEN** a `fullRun` job is running and an `extractLlm` job is requested
- **THEN** the `extractLlm` job runs only after the `fullRun` job ends

### Requirement: Jobs can be cancelled
The job manager SHALL support cancelling the running job. Cancel SHALL take effect between topics (and between LLM calls), SHALL keep all work already saved, and SHALL record the run as cancelled.

#### Scenario: Cancel keeps finished work
- **WHEN** a job that has processed 40 of 100 topics is cancelled
- **THEN** the job stops before the next topic, the 40 topics' saved results remain on disk, and the run record says cancelled with 40 done

### Requirement: Guardrails bind every job
Guardrail settings (`llm_max_topics`, throttle delay, the lesser-board page cap) SHALL apply to every job regardless of how it was requested. A job stopped short by a guardrail SHALL finish as completed, with the guardrail stop recorded on its run.

#### Scenario: LLM cap applies to requested jobs
- **WHEN** `llm_max_topics=50` and an `extractLlm` job requests 80 topics
- **THEN** live LLM calls stop at 50, the run completes, and its record says the cap was hit with 30 topics left

### Requirement: The CLI keeps working like today
`bin/scraper_main.dart` SHALL build its job request from the existing config keys and run it through the manager core: `qb_scope`/`qb_boards`/page limits/`qb_use_cached`/`llm_enabled` shape a `fullRun`; `llm_reprocess_only=true` requests `llmCoveragePass`; `llm_test_mode=true` requests `llmTest`. Config key names, run order, console output style, and output files SHALL be unchanged from before this change.

#### Scenario: Existing workflow is unchanged
- **WHEN** a user edits `config.properties` and runs the CLI exactly as before this change
- **THEN** the same scrape happens and the same output files are produced as before

#### Scenario: Reprocess-only mode maps to a job kind
- **WHEN** the CLI runs with `llm_reprocess_only=true`
- **THEN** the manager core runs an `llmCoveragePass` job (coverage pass over the store, then bundle rebuild), same as the old special branch

### Requirement: Progress is reported through one interface
The service SHALL report progress (items done, total, current item, phase) and log lines through a reporter interface, not directly to the console. The CLI SHALL plug the console progress bar into that interface.

#### Scenario: The core has no console wiring
- **WHEN** the service runs a job with a test reporter attached
- **THEN** the test reporter receives progress updates and the service writes nothing directly to the console progress bar
