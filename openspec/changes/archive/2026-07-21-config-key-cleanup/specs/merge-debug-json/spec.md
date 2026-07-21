# merge-debug-json — delta

## MODIFIED Requirements

### Requirement: Config key renamed with backward-compatible alias
The config key controlling merge debug output SHALL be `modrepo_merge_debug`. The old keys `generate_merge_debug` and `generate_debug_html` SHALL NOT be read; like any unrecognized key, they SHALL be reported by the startup unknown-key warning.

#### Scenario: New config key works
- **WHEN** a config file sets `modrepo_merge_debug=true`
- **THEN** the scraper writes `merge-debug.json`

#### Scenario: Old config keys no longer work
- **WHEN** a config file sets only `generate_merge_debug=true` or `generate_debug_html=true`
- **THEN** no merge debug file is written and the stale key is named in a startup warning
