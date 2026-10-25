# ai-use-on-site Specification

## Purpose
TBD - created by archiving change extract-ai-use-statements. Update Purpose after archive.
## Requirements
### Requirement: The site publishes each mod's AI use in four states
The site SHALL publish, for each mod, one of four states:
- AI use stated;
- explicit no-AI statement;
- read, and nothing stated;
- not read for AI use yet.

The list record in `mods.json` SHALL include `usesAi`, `true` or `false`, and SHALL leave it out when it is `null`. It SHALL include `aiUses` only when `usesAi` is `true`. Each entry SHALL contain `area`, plus `how` and `optional` if stated by the author. Entries SHALL be sorted by area, with duplicates removed and `extent` omitted. A mod with no AI-use statement SHALL carry neither field. The mod's own file SHALL carry the whole `aiUse`, including the quote and the tools. A mod read with nothing stated SHALL carry an empty `aiUse` in its own file. A mod not read yet SHALL carry no `aiUse`.

#### Scenario: A mod that used AI
- **WHEN** a mod's `aiUse.usesAi` is `true` and its uses are portraits and code
- **THEN** its list record SHALL carry `usesAi: true` and `aiUses` listing code before portraits

#### Scenario: Explicit no-AI statement
- **WHEN** a mod's `aiUse.usesAi` is `false`
- **THEN** its list record SHALL carry `usesAi: false` and no `aiUses`

#### Scenario: Nothing stated, or not read yet
- **WHEN** a mod has no `aiUse`, or an `aiUse` with no `usesAi`
- **THEN** its list record SHALL carry neither `usesAi` nor `aiUses`

### Requirement: Keep unknown AI use distinct from no AI use
The site SHALL NOT show, filter or search a mod with no AI-use statement as if it had no AI. It SHALL show a mod read with nothing stated as "Unknown", and a mod not read yet as "Not checked yet".

#### Scenario: The posts say nothing
- **WHEN** a reader opens the page of a mod whose `aiUse` has no `usesAi`
- **THEN** the AI use row SHALL read "Unknown"

#### Scenario: Not read yet
- **WHEN** a reader opens the page of a mod with no `aiUse`
- **THEN** the AI use row SHALL read "Not checked yet"

### Requirement: The mod page shows an AI use row
The mod page SHALL show one "AI use" row in the Details card. When AI was used, it SHALL list each area with its `how` and whether it is optional. For example: "Portraits (edited, optional) · Code (assisted)". When the author says no AI was used, it SHALL read "None". The author's quote SHALL show on hover. The row SHALL describe AI use without warning colours, warning icons or commentary.

#### Scenario: Hovering the row
- **WHEN** a reader points at the AI use row of a mod with a quote
- **THEN** the author's quote SHALL be shown

### Requirement: Browse can filter mods by what their authors say about AI use
Browse SHALL offer an "AI use" filter. Its two modes SHALL be labelled "Don't show AI-gen…" and "Only show AI-gen…". The mode buttons SHALL be stacked. "Don't show AI-gen…" SHALL hide mods with stated AI use in a checked part. "Only show AI-gen…" SHALL show only those mods. The filter SHALL start on "Don't show AI-gen…" with nothing checked. This SHALL hide nothing. There SHALL be no off button. The filter SHALL offer:
- parts grouped as Art, Sound, Text, Code and Other, with no "Parts" heading. A group's checkbox SHALL select or clear the whole group;
- under the heading "If AI did…", a choice of how much AI work counts: "all of the work", "some, but edited by a human" or "anything at all". Stated AI use with no `how` SHALL count at every level;
- a checkbox to ignore optional parts;

The All and None links SHALL sit in the side panel's heading. In the top layout's box, they SHALL sit in a small "AI use" heading row. Pressing them SHALL NOT fold the panel.

Each part SHALL show its match count among mods shown by the other filters. "Don't show AI-gen…" SHALL NOT hide a mod whose author says nothing about AI. A mod with an explicit no-AI statement SHALL never be hidden with "Don't show AI-gen…". The address SHALL store the filter as `ai`, `aiparts`, `ailevel`, and `aioptional`. It SHALL store nothing for the starting filter. An old `hideai=<area>,<area>` address SHALL open with "Don't show AI-gen…" with those parts checked. The line above the results SHALL say how many mods the filter hides and SHALL offer a "Clear AI filter" link.

#### Scenario: Hiding AI art
- **WHEN** a reader selects "Don't show AI-gen…" and checks only the Art group
- **THEN** every mod whose author says AI was used for portraits, illustrations, sprites or icons SHALL be hidden. Mods with no statement SHALL stay visible

#### Scenario: Allowing AI help
- **WHEN** a reader selects "Don't show AI-gen…", checks every part and picks "some, but edited by a human"
- **THEN** a mod whose only use is code written with AI help SHALL stay visible

#### Scenario: A shared link
- **WHEN** a reader opens an address with `aiparts=music,voice`
- **THEN** Browse SHALL open with "Don't show AI-gen…" with Music and Voice checked

#### Scenario: An old link
- **WHEN** a reader opens an address with `hideai=music,voice`
- **THEN** Browse SHALL open with "Don't show AI-gen…" with Music and Voice checked

### Requirement: Search supports AI-use filters
The search box SHALL accept `has:ai`, which keeps mods whose `usesAi` is `true`, and `is:noai`, which keeps mods whose `usesAi` is `false`. A minus in front of either SHALL leave those mods out. Both search terms SHALL have a score of zero. They SHALL filter results without changing their order.

#### Scenario: Leaving out mods that used AI
- **WHEN** a reader searches `faction -has:ai`
- **THEN** the results SHALL match "faction" and SHALL leave out every mod whose `usesAi` is `true`, keeping mods marked "Unknown" or "Not checked yet"

#### Scenario: Finding mods with explicit no-AI statements
- **WHEN** a reader searches `is:noai`
- **THEN** the results SHALL be exactly the mods whose `usesAi` is `false`

### Requirement: The results viewer shows the AI-use answer
The results viewer's thread page SHALL show each mod's `aiUse` beside its other LLM extras: the quote, the sorted uses, the tools, and `usesAi`.

#### Scenario: A thread with an AI-use answer
- **WHEN** a developer opens the viewer's page for a thread whose mod has an `aiUse`
- **THEN** the page SHALL show the quote and each sorted use

