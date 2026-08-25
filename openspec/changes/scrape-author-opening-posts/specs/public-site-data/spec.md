## ADDED Requirements

### Requirement: The opening posts stand in wherever a rule reads "the post"
Wherever a site-building rule reads or grounds against "the thread's post" — the name check for thread-only mods, the grounding of what a mod needs, and the gallery — "the post" SHALL mean the author's opening run: the first post plus every `extraPosts` entry. The gallery SHALL run the extra posts' images through the same not-a-screenshot rules as the first post's. The thread's own description is the exception and SHALL remain the first post alone.

#### Scenario: A mod named only in the Downloads post
- **WHEN** the LLM names a `main` mod whose name appears in the author's second post but not the first
- **THEN** the name check passes and the mod is eligible for publishing as a thread-only mod

#### Scenario: Screenshots in a follow-up post
- **WHEN** an author's second post holds the thread's screenshots
- **THEN** they appear in the gallery, filtered by the same rules as first-post images

#### Scenario: The thread description is unchanged
- **WHEN** a single-mod thread has extra opening posts
- **THEN** its published description is still built from the first post alone

## MODIFIED Requirements

### Requirement: The description is the author's own post, kept formatted
Where a mod has a forum thread of its own — one holding no other `main` mod — its
description SHALL be taken from that thread's first post and published as
`descriptionHtml`: a rebuilt piece of HTML holding only paragraphs, line breaks, lists,
headings, quotes, code, emphasis and links. Anything that can run, anything that can
style the page and anything that loads from another host SHALL be left out. Links SHALL
carry `rel="nofollow noopener"`. Bare web addresses SHALL be turned into links. Where
the mod has no forum post, the merged description SHALL be used, and failing that the AI
paragraph, labelled as AI. `description` SHALL keep holding the same words as plain
text.

Where the thread holds more than one `main` mod, the shared post SHALL NOT be any of
those mods' whole description. Instead, a mod whose LLM entry carries grounded
`descriptionAnchors` SHALL take as its description the HTML sliced verbatim from the
opening post between those anchors, passed through the same rebuild rules, and SHALL
NOT be labelled as AI-generated — the words are the author's, located but not written
by the model. A mod without grounded anchors SHALL fall back as if it had no post: its
own merged description first, failing that its own LLM entry's paragraph, labelled as
AI; a mod with neither SHALL be published with no description.

#### Scenario: A mod on both the forum and Discord
- **WHEN** a mod has a forum post and a Discord announcement
- **THEN** the description is the forum post, not the Discord announcement

#### Scenario: A post carries a script
- **WHEN** the post holds a `<script>`, a `<style>` or an `<img>`
- **THEN** none of them appear in `descriptionHtml`

#### Scenario: A very long post
- **WHEN** a post runs to tens of thousands of characters
- **THEN** the published description is cut off at a whole block and marked as cut short

#### Scenario: A shared thread whose Downloads post describes each mod
- **WHEN** a thread holds several `main` mods and the author's second post carries a paragraph per mod, with grounded anchors for one of them
- **THEN** that mod's description is the author's paragraph sliced from the post, not labelled as AI, and its `descriptionHtml` passes the same sanitising rebuild as any description

#### Scenario: Anchors failed to ground
- **WHEN** a mod on a shared thread has no grounded `descriptionAnchors`
- **THEN** its description falls back to its own merged description, then its LLM paragraph labelled as AI, then nothing — exactly as before this change
