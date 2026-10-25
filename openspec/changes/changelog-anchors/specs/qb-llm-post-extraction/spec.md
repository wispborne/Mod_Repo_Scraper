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

#### Scenario: Notes written before their version
- **WHEN** the post gives a version's notes first and names the version after them, or in another of the author's posts
- **THEN** the notes are still cut from the post, as long as the version appears in one of the posts or in the thread's title

#### Scenario: Our own link notes are taken out
- **WHEN** the cut text holds a `[link: <url>]` note the system added to the post for the model
- **THEN** that note does not appear in the stored notes, and neither does the forum's spoiler end mark `[close]`

#### Scenario: Version separated from game version
- **WHEN** the post states both the mod's version and the game version it targets
- **THEN** the mod's own version is captured as the version field, not the game version

#### Scenario: License only when stated
- **WHEN** the post does not state a license
- **THEN** the license field is left blank (never guessed)

### Requirement: Downloads are a list, combined with the rules in one call
The system SHALL, in the single extraction call, ask the LLM to produce the thread's downloads grouped under the mod each belongs to. It SHALL give the links found by the rule-based resolver (as their original post URLs) to the LLM inside that call, so the LLM can confirm them, add ones the rules missed (including links inside spoiler boxes or on unknown hosts), and drop any that are not the mod's download — in one pass, with no separate follow-up call. Each post link in the prompt's list SHALL carry a number, and the LLM SHALL name a download by that number rather than copying its URL and link text. Only a download whose URL is not in that list (such as an address written out in the post text) SHALL be given as a copied URL. Each download the system keeps SHALL carry the raw post URL, the link's text as the post wrote it (taken from the list, or empty when the link had none), and a `kind` of `direct`, `mirror`, or `trios`. The system SHALL then run each kept link through the existing download resolver, so every stored download also carries the resolved direct URL, filename, and requires-manual-step flag. The LLM SHALL NOT make up or resolve a URL. This grouped result SHALL be written into the thread's `llm` output and SHALL NOT overwrite the rule-based `assumedDownloads` list.

#### Scenario: Link the rules missed
- **WHEN** the rules find no download but the LLM finds a grounded one (e.g. inside a spoiler or on an unknown host)
- **THEN** the LLM's download is added under its mod in the `llm` output, and is run through the resolver for its resolved URL and filename

#### Scenario: A mod offers a mirror
- **WHEN** a post offers the same file on two hosts
- **THEN** both links appear under that mod, one with `kind` `direct` and the mirror with `kind` `mirror`

#### Scenario: Install-with-TriOS link
- **WHEN** a post offers an "Install with TriOS" link alongside a plain download for the same mod
- **THEN** both appear under that mod, the TriOS link with `kind` `trios` and the plain download with `kind` `direct`

#### Scenario: A link that is not a download is dropped
- **WHEN** the rules flagged a link as a download but the LLM, seeing the whole post, judges it is not the mod's download
- **THEN** that link SHALL NOT appear in the `llm` output — decided in the single call, with no extra request

#### Scenario: Rule-based list stays unchanged
- **WHEN** the LLM produces its grouped download result for a thread
- **THEN** the thread's `assumedDownloads` entry SHALL still contain the rule-based candidates, unchanged

#### Scenario: A download named by its number
- **WHEN** the LLM names a download by the number of a link in the prompt's list
- **THEN** the stored download carries that link's URL and that link's text from the post

#### Scenario: A number that is not in the list
- **WHEN** the LLM names a download by a number the list does not have
- **THEN** that download is dropped and the drop is logged with the topic id and the number

#### Scenario: An address written out in the post
- **WHEN** a download's address appears in the post text but not in the list of links, and the LLM copies the address
- **THEN** the download is kept with that address and an empty link text, after the usual check that the address is in the post
