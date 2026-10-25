# gallery-ai-captions Specification

## Purpose
TBD - created by archiving change gallery-ai-captions. Update Purpose after archive.
## Requirements
### Requirement: Publish captions separately
Gallery images SHALL preserve author captions and publish saved current-version generated captions separately, without new LLM calls.

#### Scenario: Both captions exist
- **WHEN** an image has an author caption and a saved generated caption
- **THEN** both are published in separate fields

### Requirement: Respect reader preferences
Gallery tooltips, alt text and enlarged captions SHALL use the existing AI summary mode and mod-page AI visibility. Never or hide excludes AI text; always prefers generated captions; whenMissing prefers author captions. Generated captions SHALL be identified as AI descriptions.

#### Scenario: AI disabled
- **WHEN** either setting disables AI text
- **THEN** only the author caption is displayed, or no caption if absent

#### Scenario: AI allowed
- **WHEN** AI is allowed
- **THEN** the chosen caption follows always or whenMissing and falls back when the preferred caption is absent

