## ADDED Requirements

### Requirement: The publish target is set by config keys
`config.properties` SHALL have a `publish_` group setting where a publish sends the output files and where it keeps its working clone: `publish_repo_url` (the target repo, defaulting to the SSH URL of `wispborne/StarsectorModRepo`) and `publish_clone_dir` (the folder the server keeps its clone in, kept apart from any folder the cron script wipes). These keys SHALL be manager environment — read where the publish service is built, never served to the browser — and SHALL be listed among the recognized keys and documented in `config.example.properties` with their defaults and a plain-English note. There SHALL be no token key; publishing SHALL use the host's existing git/SSH auth.

#### Scenario: Keys are read
- **WHEN** a config file sets `publish_repo_url` and `publish_clone_dir`
- **THEN** the publish service is built to push to that repo using that folder for its clone

#### Scenario: Keys are left out
- **WHEN** the `publish_` keys are absent
- **THEN** the built-in defaults apply and no warning is given

#### Scenario: Key is misspelled
- **WHEN** a config file sets `publish_repo_ur=...`
- **THEN** a startup warning names the unrecognized key and the default applies
