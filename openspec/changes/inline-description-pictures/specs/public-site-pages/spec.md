## ADDED Requirements

### Requirement: A mod's description shows the author's pictures where they put them
A mod's page SHALL show the pictures in its description in the places the post put
them, no wider than the description's column, keeping their shape. A picture that
fails to load SHALL be taken out of the page. Where that picture was a link's only
content, the link SHALL be left with its address as text, so the link still works. A
picture that is not inside a link SHALL open over the page when clicked, in the same
viewer the screenshots use. A picture inside a link SHALL follow the link.

#### Scenario: Reading a post with screenshots
- **WHEN** a reader opens a mod whose post has a screenshot under each paragraph
- **THEN** each screenshot is shown under its own paragraph

#### Scenario: A badge download link whose picture is gone
- **WHEN** a download link's only content is a badge picture and that picture fails to load
- **THEN** the link is still on the page, showing its address

#### Scenario: Clicking a screenshot in the description
- **WHEN** a reader clicks a picture in the description that is not a link
- **THEN** it opens over the page, and Escape puts them back where they were

### Requirement: The reader can turn pictures in descriptions off
The Settings dialog SHALL offer "Pictures in descriptions": shown (the default) or not
shown. The choice SHALL be kept in the reader's own browser and SHALL NOT be sent
anywhere. Changing it SHALL redraw the page. When it is off, no picture in a
description SHALL be loaded. Each SHALL be shown as a small "picture" link instead,
which opens the picture over the page. A picture inside a link SHALL be shown as that
link's address, so the link still works. Where a description has pictures, the same
choice SHALL also be offered beside the "About this mod" heading, as "Hide pictures" or
"Show pictures", so a reader finds it where the pictures are. Pressing it SHALL change
the setting for every mod and redraw the description in place, leaving the reader
where they were on the page.

#### Scenario: Turning pictures off from the description
- **WHEN** a reader presses "Hide pictures" beside the "About this mod" heading
- **THEN** the description's pictures become "picture" links, the button reads "Show pictures", and Settings shows the choice as off

#### Scenario: A description with no pictures
- **WHEN** a mod's description has no pictures
- **THEN** no "Hide pictures" button is drawn beside its heading

#### Scenario: A reader on a slow connection
- **WHEN** a reader turns pictures in descriptions off and opens a mod with twenty pictures in its post
- **THEN** none of the twenty is fetched, and each is shown as a "picture" link

#### Scenario: The default
- **WHEN** a reader who has never opened Settings opens a mod page
- **THEN** the pictures in its description are shown

### Requirement: The description's cut-off follows its pictures
Where a description starts cut off with a "Show more" button, whether the button is
needed SHALL be checked again as the description's pictures load, until the reader
presses it. A description that fitted before its pictures arrived and overruns
afterwards SHALL become cut off with the button showing.

#### Scenario: A short post with large pictures
- **WHEN** a post's words fit, but its three screenshots push it past the cut-off once they load
- **THEN** the description is cut off and "Show more" appears

### Requirement: Small pictures in the gallery are behind a button
The Screenshots section SHALL show only the pictures not marked as small. Where the
mod has small pictures, a button under the gallery SHALL say how many there are and
show them when pressed. Pressing it again SHALL hide them. A mod with only small
pictures SHALL still show the Screenshots section, with the button and no pictures
showing. The picture viewer SHALL move only between the pictures currently showing.

#### Scenario: A post with screenshots and badges
- **WHEN** a mod has four screenshots and three badges
- **THEN** the section shows the four screenshots and a button offering three small pictures

#### Scenario: Showing the small pictures
- **WHEN** the reader presses that button
- **THEN** the three badges are shown in the gallery, and the button offers to hide them

## MODIFIED Requirements

### Requirement: Screenshots open over the page
A screenshot, or a picture in a mod's description that is not inside a link, SHALL open
over the page rather than as a raw image in a new tab. The reader SHALL be able to move
between pictures and close the viewer with the keyboard, and closing it SHALL leave them
where they were. A picture from the description SHALL move between the description's
pictures. A screenshot SHALL move between the screenshots showing.

#### Scenario: Looking through the screenshots
- **WHEN** a reader opens one screenshot and presses the right arrow
- **THEN** the next one is shown, and Escape puts them back on the page they were reading

#### Scenario: Looking through the description's pictures
- **WHEN** a reader clicks the second picture in a description and presses the right arrow
- **THEN** the third picture in the description is shown
