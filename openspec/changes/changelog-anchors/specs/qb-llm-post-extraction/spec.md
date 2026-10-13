## MODIFIED Requirements

### Requirement: The LLM may only return facts grounded in the post
The system SHALL discard any LLM output not supported by the post: any returned URL that does not appear in the post SHALL be dropped, and any copied text (license, changelog text) that is not found in the post SHALL be treated as not stated. A changelog entry SHALL be kept only when its text was cut out of the post by the system, or, for a short entry the model copied whole, when that copied text is found in the post.

#### Scenario: Invented URL is dropped
- **WHEN** the LLM returns a download or support URL that does not appear anywhere in the post
- **THEN** that URL is removed from the result and not written to the bundle

#### Scenario: Unstated fact is left blank
- **WHEN** the LLM returns a version, license, or changelog text that cannot be found in the post
- **THEN** that field is treated as not stated and left blank rather than saved

#### Scenario: A changelog entry the model reworded is dropped
- **WHEN** the LLM copies a short changelog entry whole and the copied words cannot be found in the post
- **THEN** that entry is dropped and the drop is logged with the topic id and the version

### Requirement: The LLM extracts changelog, version, support links, and license
When the feature is enabled, the system SHALL extract, when present and grounded in the post: a changelog (a link, the author's notes for each version, or both), the mod's own current version (kept separate from the game version), support links (e.g. Patreon, Ko-fi, donate), and the license as stated. When the post offers both a changelog link and changelog text, both SHALL be kept.

The model SHALL NOT be asked to copy a long changelog entry. For each version it SHALL give the version and the first few and last few words of that version's notes, and the system SHALL cut the notes out of the post between those words. Only an entry shorter than its two sets of words SHALL be copied whole by the model. The stored changelog SHALL keep its shape — a map from version to that version's notes — so nothing that reads it has to change.

#### Scenario: Changelog in a spoiler box
- **WHEN** the post has changelog text inside a spoiler box and no changelog link
- **THEN** each version's notes are stored as the author's own words, cut out of the post (not summarized, not reworded)

#### Scenario: Changelog as a link
- **WHEN** the post links to a changelog and shows no changelog text
- **THEN** the changelog link is stored and no entries are stored

#### Scenario: Changelog link and text together
- **WHEN** the post both links to a changelog and shows changelog text
- **THEN** both the link and the entries are stored

#### Scenario: A long entry is cut from the post
- **WHEN** the model gives a version with the first and last words of its notes, and the post holds that version followed by those words in that order
- **THEN** the stored notes for that version are the post's text from the first words through the end of the line holding the last words, with the line breaks kept and without the version heading itself

#### Scenario: The cut is tied to the version
- **WHEN** the same first words appear under more than one version, for example a line like "- Fixed a crash" repeated in several releases
- **THEN** the cut for each version starts at the first words that follow that version's own heading, not at the first place the words appear in the post

#### Scenario: A version that is the start of another version
- **WHEN** the post has notes for both "1.2.1a" and "1.2.1"
- **THEN** the search for "1.2.1" does not match the text "1.2.1a", and each version's notes come from under its own heading

#### Scenario: Pointers that cannot be found
- **WHEN** the version, the first words, or the last words cannot be found in one of the author's posts in that order
- **THEN** that entry is dropped, the drop is logged with the topic id and the version, and the other entries are kept

#### Scenario: Our own link notes are taken out
- **WHEN** the cut text holds a `[link: <url>]` note the system added to the post for the model
- **THEN** that note does not appear in the stored notes

#### Scenario: Version separated from game version
- **WHEN** the post states both the mod's version and the game version it targets
- **THEN** the mod's own version is captured as the version field, not the game version

#### Scenario: License only when stated
- **WHEN** the post does not state a license
- **THEN** the license field is left blank (never guessed)
