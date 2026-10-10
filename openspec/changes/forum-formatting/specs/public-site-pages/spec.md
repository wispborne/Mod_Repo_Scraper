## ADDED Requirements

### Requirement: Spoilers fold, and their pictures wait
A spoiler in a mod's description SHALL be drawn as a fold, shut at first, labelled
with its title. Pictures inside a shut spoiler SHALL NOT be fetched until it is opened.
Opening or shutting one SHALL re-check the description's "Show more" cut-off.

#### Scenario: A post with screenshots in a spoiler
- **WHEN** a reader opens a mod whose screenshots sit in a spoiler titled "Screenshots"
- **THEN** a shut fold labelled "Screenshots" is shown, and its pictures load only once it is opened

### Requirement: Author colours stay readable in every theme
Text the author coloured SHALL be shown in that colour, adjusted to the current theme.
On a dark theme it SHALL be lightened until it reads against the background. On a light
theme it SHALL be darkened. Its hue SHALL be kept.

#### Scenario: Black text on the dark theme
- **WHEN** an author wrote a line in black and the reader is on a dark theme
- **THEN** the line is shown light enough to read, and coloured lines keep their hue

#### Scenario: Yellow text on the light theme
- **WHEN** an author wrote a line in yellow and the reader is on the Light theme
- **THEN** the line is shown dark enough to read against white

### Requirement: A YouTube video plays only when asked
A YouTube video in a description SHALL be shown as its thumbnail with a play button,
linking to the video. Clicking it SHALL play the video in its place, using the
`youtube-nocookie.com` player. Nothing SHALL be loaded from YouTube's player before that
click. With pictures in descriptions turned off, the thumbnail SHALL NOT be fetched
either, and the video SHALL be shown as a link reading "Video on YouTube".

#### Scenario: Playing a video
- **WHEN** a reader clicks a video's thumbnail in a description
- **THEN** the video starts playing where the thumbnail was, and the page does not move

#### Scenario: Pictures turned off
- **WHEN** pictures in descriptions are off and a description holds a video
- **THEN** a "Video on YouTube" link is shown, and nothing is fetched from YouTube

### Requirement: Tables and alignment survive a narrow screen
A table in a description SHALL keep its columns. Where it is wider than the screen, it
SHALL scroll sideways inside its own box rather than widening the page. Centred and
right-aligned blocks SHALL be drawn that way.

#### Scenario: A wide table on a phone
- **WHEN** a reader on a phone opens a mod whose post has a four-column table
- **THEN** the table scrolls sideways in its box, and the page itself does not scroll sideways
