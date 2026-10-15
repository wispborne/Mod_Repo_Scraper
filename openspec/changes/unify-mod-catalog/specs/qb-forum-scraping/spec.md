## MODIFIED Requirements

### Requirement: Mod index category scraper

The system SHALL scrape topic 177 and store its mod index lines on each topic's `QbModSummary`. Each line SHALL retain link-text name, author, game version and category. Preserve index order, deduplicate lines with the same name and category for a topic, and use the first line's category as the topic category. The merge SHALL be able to read these lines without a network call.

The scraper SHALL handle current categories in the first post and archived categories in later posts. Apply the legacy category map and track unknown archived categories.

Category parsing SHALL:

- Find the topic list even when elements such as `<br>` separate it from the heading.
- Accept only `<strong>` headings directly inside the category cell.
- Strip all trailing colons from labels.
- Preserve current category casing while comparing names case-insensitively.
- Log categories and sample topic mappings for parity checks.

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
