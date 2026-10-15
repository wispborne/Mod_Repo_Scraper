## MODIFIED Requirements

### Requirement: Git publishing

When configured, the system SHALL publish `forum-data-bundle-v2.json` to a local git clone. It SHALL NOT write the frozen `forum-data-bundle.json`.

#### Scenario: Write and push

- **WHEN** `qbRepoPath` is configured
- **THEN** the system SHALL write `forum-data-bundle-v2.json`, run `git add`, `git commit -m "scrape update: {updatedAt}"`, and `git push`

#### Scenario: Old bundle untouched

- **WHEN** a bundle is published
- **THEN** `forum-data-bundle.json` in the clone is not written, staged or deleted

#### Scenario: Skip push when unchanged

- **WHEN** git commit reports nothing to commit
- **THEN** push SHALL be skipped with an info log

#### Scenario: Skip when not configured

- **WHEN** `qbRepoPath` is null or empty
- **THEN** publishing SHALL be silently skipped

#### Scenario: Local bundle copy

- **WHEN** a scrape completes
- **THEN** the bundle SHALL be written to `{qbDataPath}/forum-data-bundle-v2.json` regardless of repo config

## ADDED Requirements

### Requirement: The bundle carries the Discord answers

The bundle SHALL include `discordThreads`, with one entry per thread with an LLM result. Each entry SHALL contain the thread id, link, name and extracted mods with downloads and extras, using the forum LLM mod shape. Entries SHALL contain no Discord message text, confidence scores or local paths.

#### Scenario: Discord-only mod's facts

- **WHEN** a Discord thread's LLM answer names one main mod with a download and a requirement
- **THEN** the bundle's `discordThreads` entry for that thread holds that mod with its download and requirement

#### Scenario: No message text

- **WHEN** the bundle is written
- **THEN** no `discordThreads` entry holds the text of any Discord message
