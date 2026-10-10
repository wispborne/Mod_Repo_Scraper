## MODIFIED Requirements

### Requirement: Mod index category scraper
The system SHALL scrape topic 177 to build, for each topic id, the list of mod index lines that link to it. Each line SHALL keep the mod's name as the link text gives it, the author, the game version, and the category it sits under. The topic's category SHALL still be the category of its first line. Lines SHALL be kept in the order the index lists them, and two lines with the same name and category for one topic SHALL be kept once. The scraper SHALL handle main (first post) and archived (subsequent posts) categories, apply a legacy category name map, and track unknown legacy categories. Category-header extraction SHALL be robust to intermediate elements (for example `<br>`) between the label and its topic list, SHALL reject nested `<strong>` elements that are not direct children of the category cell, SHALL strip any number of trailing `:` from labels, SHALL preserve the canonical casing of main-post category names while comparing case-insensitively, and SHALL emit parity diagnostic logs. The lines SHALL be stored on the topic's `QbModSummary` so the merge can read them without a network call.

#### Scenario: Parse mod index
- **WHEN** topic 177 is fetched
- **THEN** the system SHALL match category headers with a direct-child chain `table.bbc_table > tbody > tr > td > strong`, and for each header SHALL locate the topic list by walking all following element siblings and picking the first `ul.bbc_list`

#### Scenario: Index lines are kept
- **WHEN** the index lists "Better Combat" by its author under "Utility Mods" for topic 29877
- **THEN** topic 29877's summary holds a line with that name, author, game version and category

#### Scenario: Several names for one topic
- **WHEN** the index links topic 21968 from lines named "Midline Expansion", "Pirate Collection" and "Yunru Mods"
- **THEN** all three lines are kept on that topic, in index order

#### Scenario: Low link count retry
- **WHEN** fewer than 20 topic links are found
- **THEN** the system SHALL retry with `;all` suffix

#### Scenario: Intermediate element between header and list
- **WHEN** a `<strong>` category header is followed by a `<br>` (or any non-`<ul>` element) before the `<ul class="bbc_list">`
- **THEN** the scraper SHALL still find that `<ul>` and map its topics to the header's category

#### Scenario: Legacy category mapping
- **WHEN** an archived category is not in the main categories set
- **THEN** it SHALL be mapped via the legacy map (e.g., "Factions" → "Faction Mods"); unmapped categories become "uncategorized" and are tracked as unknowns

#### Scenario: Nested strong ignored
- **WHEN** a `<strong>` element appears nested inside a descendant of `<td>` (for example inside a `<p>` in a description) rather than as a direct child of `<td>`
- **THEN** it SHALL NOT be treated as a category header

#### Scenario: Trailing colons stripped
- **WHEN** a category label ends with one or more `:` characters (for example "Factions:::")
- **THEN** all trailing `:` SHALL be removed before normalization

#### Scenario: Main-category casing preserved
- **WHEN** the result object exposes the set of main-post categories
- **THEN** values SHALL retain their original casing (for example "Faction Mods"), and membership checks against either casing SHALL succeed

#### Scenario: Diagnostic logging
- **WHEN** a mod-index scrape completes
- **THEN** the scraper SHALL log the distinct main-post categories and up to the first 10 topic-to-category sample mappings at INFO level

#### Scenario: Unknown-legacy warning includes map source
- **WHEN** one or more archived categories cannot be resolved via the legacy map
- **THEN** the WARNING log SHALL include a pointer to `lib/bot/scraper/qb/legacy_category_map.dart` so operators know which source file to edit

#### Scenario: Case-insensitive unknown-legacy dedupe
- **WHEN** `unknownLegacyCategories` contains entries that differ only by casing
- **THEN** the logged set SHALL be deduplicated case-insensitively
