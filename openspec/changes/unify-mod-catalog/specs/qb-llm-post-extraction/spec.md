## ADDED Requirements

### Requirement: Discord threads are read by the LLM too

When LLM extraction is enabled, coverage SHALL include all threads in `discord-posts.json` and all topics in the mods index. Both SHALL use the same extractor and system prompt. Coverage SHALL NOT fetch Discord.

A Discord opening run SHALL start with the first message containing text, include consecutive messages by the same author, and stop at another author or ten messages. Convert markdown through the site's Discord HTML renderer so links retain their position. Use the thread name as the title and identify the source as a Discord announcement thread in the user prompt.

#### Scenario: Discord-only mod is read

- **WHEN** the coverage pass runs and a Discord thread has never been sent to the LLM
- **THEN** its opening run is sent to the LLM and the answer is stored under `discord:<thread id>`

#### Scenario: Author's update messages are read

- **WHEN** a Discord thread holds the author's announcement, then two update messages by the same author, then a reply by somebody else
- **THEN** the announcement and both updates are sent, and the reply and everything after it are not

### Requirement: Discord answers are stored and checked like forum answers

The extraction store SHALL cache Discord results under `discord:<thread id>` and preserve bare topic-id keys for forum results. Freshness SHALL depend on the post fingerprint, prompt version and field set.

Grounding checks for names, nicknames, URLs, copied text and description anchors SHALL use the opening run. Discord LLM downloads SHALL use the same host-resolution rules as forum downloads.

#### Scenario: Unchanged thread costs nothing

- **WHEN** a Discord thread's stored answer is fresh for its opening run and prompt version
- **THEN** it is served from the store with no live call

#### Scenario: A URL from another person's reply

- **WHEN** the LLM returns a download URL that appears only in somebody else's reply on the thread
- **THEN** that URL is dropped

### Requirement: Discord and forum prompt versions are counted apart

Discord extraction SHALL have its own prompt version. A Discord user-prompt change SHALL bump only that version, preserving forum cache freshness. A shared system-prompt or field-set change SHALL bump both versions.

#### Scenario: Discord wording fixed

- **WHEN** the Discord line in the user prompt is reworded and the Discord version is bumped
- **THEN** every Discord thread is read again and no forum topic is

### Requirement: One cap and one report for both kinds

Forum and Discord SHALL share the `llm_max_topics` live-call cap and `llm_max_concurrent_calls` concurrency limit. The report SHALL show each source's covered posts, live calls and posts still lacking results separately.

#### Scenario: Cap reached during the Discord part

- **WHEN** `llm_max_topics` is 100, 40 forum topics need a call, and 300 Discord threads need a call
- **THEN** the run makes 100 live calls in all, and the report says how many Discord threads still lack an answer
