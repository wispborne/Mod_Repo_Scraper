# merge-debug-json

## Requirements

### Requirement: Merge debug data is written as JSON
When merge debug output is enabled, the scraper SHALL serialize the collected `MergeDebugData` (summary, phase timings, pre-dedup removals, match groups with match reasons, same-source dedup entries, merge decisions, validation removals, and final output list) to `merge-debug.json`. The HTML generator (`merge_debug_html_generator.dart`) and the `MergeDebug.html` output SHALL be removed.

#### Scenario: Debug-enabled run writes JSON
- **WHEN** the scraper runs with merge debug output enabled
- **THEN** `merge-debug.json` is written containing all collected merge debug sections, and no `MergeDebug.html` is produced

#### Scenario: Debug disabled
- **WHEN** the scraper runs with merge debug output disabled
- **THEN** no merge debug file is written and merging behaves as before

### Requirement: Config key renamed with backward-compatible alias
The config key controlling merge debug output SHALL be `generate_merge_debug`. The old key `generate_debug_html` SHALL continue to work as an alias so existing config files keep producing debug output.

#### Scenario: Old config key still works
- **WHEN** a config file sets only `generate_debug_html=true`
- **THEN** the scraper writes `merge-debug.json`
