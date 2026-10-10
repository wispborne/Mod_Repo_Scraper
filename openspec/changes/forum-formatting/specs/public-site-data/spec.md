## ADDED Requirements

### Requirement: The description keeps the forum's formatting
`descriptionHtml` SHALL keep the formatting the forum gave a post, written with the
site's own tags and classes and never with the forum's. Every class and attribute in it
SHALL come from a fixed list the builder writes. Nothing SHALL be copied across from
the post's HTML. In particular:

- A spoiler SHALL become `<details class="spoiler">` with the spoiler's title as its
  `<summary>`, starting shut. A spoiler with no title SHALL be labelled "Spoiler". The
  forum's "[close]" line SHALL be dropped.
- A quote's "Quote" header line SHALL be dropped. A header that names who is quoted SHALL
  be kept as `<cite>` at the top of the `<blockquote>`, as plain text.
- A code block's "Code" header line SHALL be dropped, and the block kept as
  `<pre><code>`. Inline `tt` text SHALL become `<code>`.
- A table SHALL keep its rows and cells (`table`, `tbody`, `tr`, `td`, `th`, with no
  attributes), inside `<div class="table-scroll">`. A cell SHALL be kept even when it
  is empty, so columns stay lined up.
- A block centred or right-aligned by the post, through `align` or `text-align`, SHALL
  become `<div class="align-center">` or `<div class="align-right">`. Left alignment
  SHALL be dropped.
- A text size SHALL become one of `size-small`, `size-big`, `size-bigger` or
  `size-biggest` on a `<span>`. Point sizes map as follows: under 10pt is `size-small`,
  10 to 13pt has no class, 14 to 17pt is `size-big`, 18 to 23pt is `size-bigger`, and
  24pt or more is `size-biggest`. `em`, `px` and named sizes SHALL be converted to
  points first. A size that cannot be read SHALL be dropped.
- An underline SHALL become `<u>`.
- A list the post numbers SHALL be `<ol>`.
- An author's text colour SHALL become `<span class="author-colour"
  style="--c:#rrggbb">`, with the colour written as six hex digits. Named colours, short
  hex and `rgb()` SHALL be converted. A colour that cannot be read, or `transparent`,
  SHALL be dropped. That custom property SHALL be the only `style` the description ever
  carries.
- A YouTube embed SHALL become `<a class="video-link" href="https://www.youtube.com/watch?v=ID">`
  holding the video's thumbnail from `i.ytimg.com`, with the same picture attributes as
  any other picture. The video id SHALL be exactly 11 letters, digits, `-` or `_`, or
  the embed SHALL be dropped. A Vimeo embed SHALL become a plain link to the video,
  reading "Video on Vimeo". Any other embed SHALL be dropped.
- Fonts, text shadows and marquees SHALL be dropped, keeping the words inside them.

#### Scenario: A spoiler
- **WHEN** a post holds a spoiler titled "Changelog"
- **THEN** `descriptionHtml` holds `<details class="spoiler"><summary>Changelog</summary>` with the spoiler's contents, and no "[close]"

#### Scenario: A plain quote and a named quote
- **WHEN** one quote's header is "Quote" and another's is "Quote from: Vayra on September 1"
- **THEN** the first has no header and the second starts with `<cite>Quote from: Vayra on September 1</cite>`

#### Scenario: A table of download buttons
- **WHEN** a post has a two-cell table, each cell holding a centred picture link
- **THEN** both cells are kept in one row, inside a `table-scroll` box

#### Scenario: Sizes
- **WHEN** a post has text at 8pt, 12pt, 14pt, 18pt and 36pt
- **THEN** they get `size-small`, no class, `size-big`, `size-bigger` and `size-biggest`

#### Scenario: Colours
- **WHEN** a post has text coloured `red`, `#bbb`, `rgb(255, 255, 255)` and `transparent`
- **THEN** the first three become `--c:#ff0000`, `--c:#bbbbbb` and `--c:#ffffff`, and the last keeps its words with no colour

#### Scenario: A colour cannot break out
- **WHEN** a post's colour is `red url(x)` or `expression(alert(1))`
- **THEN** no colour is written for it

#### Scenario: Other declarations beside a colour
- **WHEN** a post's style is `color: red; background: url(x)`
- **THEN** only `--c:#ff0000` is written, and nothing of the background

#### Scenario: A YouTube video
- **WHEN** a post embeds `//www.youtube.com/embed/9fRQzyMvl7k?rel=0`
- **THEN** `descriptionHtml` holds a `video-link` to `https://www.youtube.com/watch?v=9fRQzyMvl7k` with the thumbnail `https://i.ytimg.com/vi/9fRQzyMvl7k/hqdefault.jpg`, and no iframe

#### Scenario: An embed from anywhere else
- **WHEN** a post embeds an iframe from a host that is neither YouTube nor Vimeo
- **THEN** nothing is written for it

#### Scenario: Nothing else comes across
- **WHEN** a post's tags carry `class`, `style`, `id` or event attributes of their own
- **THEN** none of them appear in `descriptionHtml`, and the only classes there are the ones listed above
