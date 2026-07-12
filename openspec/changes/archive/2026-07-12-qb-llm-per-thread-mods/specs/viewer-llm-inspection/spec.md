## MODIFIED Requirements

### Requirement: Filterable topic index
The viewer SHALL show a searchable, sortable table of all topics from `mods-index.json`, joined by topic id with `llm-extraction-cache.json` and `assumed-downloads-cache.json`. It SHALL offer at least these quality filters, computed server-side: no download found, only low-confidence downloads, has LLM downloads the rules missed, has more than one mod, placeholder detail, missing game version, and WIP.

#### Scenario: Filter to topics with no download
- **WHEN** the user applies the "no download found" filter
- **THEN** the table shows only topics where neither the rules nor the LLM produced any download

#### Scenario: Filter to LLM downloads the rules missed
- **WHEN** the user applies the "has LLM downloads the rules missed" filter
- **THEN** the table shows only topics where the LLM's mods list holds a download whose post URL is not in that topic's rule-based `assumedDownloads`

#### Scenario: Filter to multi-mod threads
- **WHEN** the user applies the "has more than one mod" filter
- **THEN** the table shows only topics whose LLM output has two or more mods in its list

#### Scenario: Text search
- **WHEN** the user types a search term
- **THEN** the table shows only topics whose title or author matches it

### Requirement: Topic inspector with extraction details
The viewer SHALL provide a per-topic inspector that shows, together on one page: the rendered post `contentHtml` (in a safe frame with scripts off), the index row fields, the rule-based `assumedDownloads`, and the LLM output for the topic. The LLM output SHALL be shown as its list of mods; for each mod the inspector SHALL show the mod name, role, and any `requires`, the mod's `image` when present, its downloads (each with kind, resolved host, file name, and manual-step flag), and the mod's extras (changelog, version, support links, license, save compatibility, and summary when present). Downloads the LLM found that are not in the rule-based `assumedDownloads` SHALL be visually set apart.

#### Scenario: Inspect a topic
- **WHEN** the user opens a topic from the index table
- **THEN** the inspector shows the rendered post beside the rule-based downloads and the LLM mods list for that topic

#### Scenario: Multi-mod thread is grouped by mod
- **WHEN** a topic's LLM output has more than one mod
- **THEN** the inspector shows each mod separately, with that mod's own downloads and extras under it

#### Scenario: A mod with its own image
- **WHEN** a mod in the LLM output carries an `image`
- **THEN** the inspector shows that picture under the mod, loaded from the `ext:<url>` value with the `ext:` marker stripped

#### Scenario: LLM-found download is highlighted
- **WHEN** the LLM lists a download whose post URL is not in that topic's `assumedDownloads`
- **THEN** the inspector marks that download as found by the LLM and not the rules

#### Scenario: Topic with no LLM extraction
- **WHEN** the user inspects a topic that has no LLM output
- **THEN** the inspector still shows the post and the rule-based results, and states that no LLM extraction exists
