## ADDED Requirements

### Requirement: How many bundle snapshots to keep is a config key
`config.properties` SHALL have a `qb_bundles_to_keep` key setting how many bundle snapshots the system keeps, defaulting to 20, where 0 keeps everything. It SHALL be listed among the recognized keys and documented in `config.example.properties` with its default and a plain-English note saying roughly how much disk each snapshot costs.

#### Scenario: Key is read
- **WHEN** a config file sets `qb_bundles_to_keep=5`
- **THEN** the snapshot store keeps the newest five bundles

#### Scenario: Key is left out
- **WHEN** the key is absent
- **THEN** twenty snapshots are kept and no warning is given

#### Scenario: Key is misspelled
- **WHEN** a config file sets `qb_bundle_to_keep=5`
- **THEN** a startup warning names the unrecognized key and the default of twenty applies
