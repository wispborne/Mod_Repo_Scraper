# viewer-llm-inspection

## ADDED Requirements

### Requirement: Filterable topic index
The viewer SHALL show a searchable, sortable table of all topics from `mods-index.json`, joined by topic id with `llm-extraction-cache.json` and `assumed-downloads-cache.json`. It SHALL offer at least these quality filters, computed server-side: no download found, only low-confidence downloads, has LLM-only downloads, placeholder detail, missing game version, and WIP.

#### Scenario: Filter to topics with no download
- **WHEN** the user applies the "no download found" filter
- **THEN** the table shows only topics where neither the rules nor the LLM produced any download

#### Scenario: Filter to LLM-only downloads
- **WHEN** the user applies the "has LLM-only downloads" filter
- **THEN** the table shows only topics with at least one download whose `source` is `llm`

#### Scenario: Text search
- **WHEN** the user types a search term
- **THEN** the table shows only topics whose title or author matches it

### Requirement: Topic inspector with extraction provenance
The viewer SHALL provide a per-topic inspector that shows, together on one page: the rendered post `contentHtml` (in a sandboxed frame, scripts disabled), the index row fields, and the extraction results — every download with its `source` (`rules`, `llm`, or `rules+llm`), confidence, host, file name, and manual-step flag, plus the LLM extras (changelog, mod version, support links, license). Downloads found only by the LLM SHALL be visually distinguished from those found by the rules.

#### Scenario: Inspect a topic
- **WHEN** the user opens a topic from the index table
- **THEN** the inspector shows the rendered post beside the extraction results for that topic

#### Scenario: LLM-only download is highlighted
- **WHEN** a topic has a download with `source` = `llm`
- **THEN** the inspector marks that download as found only by the LLM

#### Scenario: Topic with no LLM extraction
- **WHEN** the user inspects a topic that has no entry in the LLM extraction cache
- **THEN** the inspector still shows the post and the rule-based results, and states that no LLM extraction exists

### Requirement: LLM test report viewer
The viewer SHALL render `llm-test-output.json` as a readable report, showing each tested topic with its extraction result, and SHALL state when the file does not exist.

#### Scenario: View the test report
- **WHEN** the user opens the LLM test report page after a test-mode run
- **THEN** each tested topic's extraction output is shown

#### Scenario: No test report on disk
- **WHEN** `llm-test-output.json` does not exist
- **THEN** the page says no test report has been generated instead of erroring
