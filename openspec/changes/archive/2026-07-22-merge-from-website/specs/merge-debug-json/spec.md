## MODIFIED Requirements

### Requirement: Merge debug data is written as JSON
When merge debug output is enabled, the scraper SHALL serialize the collected `MergeDebugData` (summary, phase timings, pre-dedup removals, match groups with match reasons, same-source dedup entries, merge decisions, validation removals, and final output list) to `merge-debug.json`, and SHALL also save the same data as that run's snapshot under `<qb_data_path>/merges/`. The HTML generator (`merge_debug_html_generator.dart`) and the `MergeDebug.html` output SHALL be removed.

#### Scenario: Debug-enabled run writes JSON
- **WHEN** the scraper runs with merge debug output enabled
- **THEN** `merge-debug.json` is written containing all collected merge debug sections, that run's snapshot is saved as well, and no `MergeDebug.html` is produced

#### Scenario: Debug disabled
- **WHEN** the scraper runs with merge debug output disabled
- **THEN** no merge debug file and no snapshot are written, and merging behaves as before

### Requirement: Config key renamed with backward-compatible alias
The config key controlling merge debug output for CLI runs SHALL be `modrepo_merge_debug`. Merges started from the website SHALL always collect debug data regardless of that key. The old keys `generate_merge_debug` and `generate_debug_html` SHALL NOT be read; like any unrecognized key, they SHALL be reported by the startup unknown-key warning.

#### Scenario: New config key works
- **WHEN** a config file sets `modrepo_merge_debug=true`
- **THEN** the scraper writes `merge-debug.json`

#### Scenario: Old config keys no longer work
- **WHEN** a config file sets only `generate_merge_debug=true` or `generate_debug_html=true`
- **THEN** no merge debug file is written and the stale key is named in a startup warning
