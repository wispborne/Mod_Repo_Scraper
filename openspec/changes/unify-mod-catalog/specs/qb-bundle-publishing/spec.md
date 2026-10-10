## MODIFIED Requirements

### Requirement: Git publishing
The system SHALL optionally publish the bundle to a local git repo clone, as `forum-data-bundle-v2.json`. It SHALL NOT write `forum-data-bundle.json`, which is frozen at its last published contents.

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
