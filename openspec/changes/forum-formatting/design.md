## Context

`cleanPostHtml` in `lib/site/post_html.dart` walks a post's HTML and writes a new copy from a short list of tags. A tag it does not know is unwrapped, keeping its words. That rule is what loses the forum's formatting. The forum (Simple Machines Forum) writes almost all of it as `div` and `span` with a class or a `style`:

| Formatting | What the forum writes | Uses (posts) |
|---|---|---|
| Spoiler | `div.sp-wrap` > `div.sp-head` (title), `div.sp-body` (contents), `div.sp-foot` ("[close]") | 3,601 (724) |
| Centre / right | `div align="center"`, `div style="text-align: right"` | 4,745 + 29 |
| Size | `span.bbc_size style="font-size: 14pt"`; also `em`, `px`, `small` | 5,219 (762) |
| Colour | `span.bbc_color style="color: red"`; named, hex, a few `rgb()` | 1,824 (343) |
| Underline | `span.bbc_u` | 1,452 (292) |
| Quote | `div.quoteheader` > `div.topslice_quote` ("Quote" or "Quote from: …"), `blockquote`, `div.quotefooter` | 147 (78) |
| Code | `div.codeheader` ("Code"), `div.block_code` > `pre` > `code` | 106 (69) |
| Table | `table.bbc_table` > `tbody` > `tr` > `td` | 72 posts |
| Video | `iframe src="//www.youtube.com/embed/ID…"`; 9 from `player.vimeo.com` | 126 (74) |
| Numbered list | `ul style="list-style-type: decimal"` | 61 |
| Monospace | `tt.bbc_tt` | 153 |
| Dropped on purpose | `span.bbc_font`, `text-shadow`, `marquee` | |

These numbers come from the saved posts in `qb_data/mods/*/detail.json`, first posts and the author's later posts together.

## Goals / Non-Goals

**Goals:**
- A post on the site looks the way its author laid it out: folds, headings, centring, colour, tables, videos.
- `descriptionHtml` stays exactly as safe as it is now. The builder writes every class and attribute from a fixed list, and nothing is copied across.
- Nothing new loads from another host until the reader asks for it, apart from pictures, which the pictures setting already covers.

**Non-Goals:**
- Exact font sizes or fonts. Sizes are mapped onto the site's own scale, and fonts are dropped.
- Other BBCode the saved posts do not use, or use too rarely to matter.
- The results viewer, which shows the raw post in a sandboxed frame.

## Decisions

### Read the forum's markup, write our own
Each forum construct is recognised by its class or style in `_write`, and written as one of our own tags or classes. This is the same approach already used for links and pictures. The fixed list of classes the builder can write is: `spoiler`, `table-scroll`, `align-center`, `align-right`, `size-small`, `size-big`, `size-bigger`, `size-biggest`, `author-colour` and `video-link`. A test pins that no other class can appear.

Considered: allowing `class` and `style` through a filter. Rejected, because the forum's class names would then become part of the site's stylesheet, and a filter on `style` is easy to get wrong.

### Spoilers are `<details>`
A native fold needs no script, opens from the keyboard, and the browser does not load lazy pictures inside a shut one, because they are never drawn. The spoiler's title becomes the `<summary>` as plain text, and an empty title reads "Spoiler". The `sp-foot` "[close]" line is dropped. A spoiler inside a spoiler (13 are titled "Super Spoiler") nests naturally.

### Sizes are four steps on the site's own scale
Size is mapped to points first: `em` × 12, `px` × 0.75, and `small` = 9pt. Then: under 10pt is `size-small` (`--type-small`), 10 to 13pt has no class, 14 to 17pt is `size-big` (`--type-big`), 18 to 23pt is `size-bigger` (`--type-heading`), and 24pt or more is `size-biggest` (`--type-title`). The forum's body text is about 12pt, so the most common size (12pt, 1,079 uses) changes nothing. An author's 36pt banner text comes out at the site's title size rather than three times bigger. The size rule in `style.css` keeps "no text size written out longhand".

### Colours are checked, normalised, and adjusted in the browser
The builder converts each colour to `#rrggbb`. It uses a table of CSS named colours, accepts `#rgb` and `#rrggbb`, and reads `rgb(r, g, b)` with whole numbers 0–255. Anything else is dropped, `transparent` included, so a value can never carry a second declaration. It writes `style="--c:#rrggbb"` and nothing more.

The page can't know the reader's theme in advance, so the adjusting happens in CSS. The style rule is `color: oklch(from var(--c) clamp(var(--author-l-min), l, var(--author-l-max)) min(c, 0.25) h)`. It keeps the hue, holds the chroma back from garish, and clamps the lightness into a band that reads on the current background. `--author-l-min` and `--author-l-max` are new names in the block at the top of `style.css`: about 0.72–0.95 for the dark default and every dark theme, and about 0.30–0.55 in both light blocks (the media query and `[data-theme="light"]`, kept in step as they already are). Browsers without relative colour syntax get a first line, `color: color-mix(in srgb, var(--c) 60%, var(--text))`, which pulls every colour toward the readable text colour.

Considered: adjusting colours in the builder. Rejected, because it would have to pick one theme.

### Videos are a link that becomes a player
For a YouTube embed, the builder writes a plain link to the video holding its thumbnail (`https://i.ytimg.com/vi/ID/hqdefault.jpg`). This works without any script and stays a link in the feed and in plain text. On the page, `postBody` treats a `video-link` as its own case. With pictures on, a click (without modifier keys) stops the link and puts a `youtube-nocookie.com/embed/ID?autoplay=1` iframe in the same 16:9 box, so the page does not move. With pictures off, the thumbnail is never fetched, and the link shows "Video on YouTube" instead. A thumbnail that fails to load leaves the same words. Vimeo has no thumbnail address that can be built without asking Vimeo, so the builder writes a plain "Video on Vimeo" link.

Considered: embedding the player outright. Rejected, because every page view would load YouTube's player and its tracking for videos most readers never play.

### Quotes and code drop their header lines
The `quoteheader` / `quotefooter` / `codeheader` wrappers are dropped. A quote header whose words are more than "Quote" (about 20 of 147) becomes `<cite>` at the top of the following `<blockquote>`, as text. The header's link back to the quoted post is left out, because it points into the forum's own pages.

### Tables keep their cells, and empty cells too
`table`, `tbody`, `thead`, `tr`, `td` and `th` are kept with no attributes, inside `<div class="table-scroll">`, which scrolls sideways. `td` and `th` are left out of the `_emptyTag` tidy-up, or an empty cell would shift a whole column. On a phone, the table scrolls in its box and the page does not.

### Alignment is a block class
`div align="center"` and `text-align: center|right` become `<div class="align-center">` or `<div class="align-right">`. Other `div`s are still unwrapped. The div is not kept for left alignment, which is the default. The `_emptyTag` tidy-up learns `div` and `span`, so an emptied centre block disappears.

### The rest
- `span.bbc_u` becomes `<u>`, which is already kept.
- `tt` becomes `<code>`.
- A `ul` with `list-style-type: decimal` becomes `<ol>`.
- `font-family`, `text-shadow` and `marquee` are unwrapped, as now.

### The cut-off and the viewer
Opening a spoiler changes the post's size. The `ResizeObserver` added for pictures already re-measures until the reader presses "Show more", so nothing new is needed there. Inline pictures inside a spoiler join the viewer's list in post order, as now.

## Risks / Trade-offs

- [Relative colour syntax is new (2023–24 browsers)] → The `color-mix` line before it is the fallback, and it is always readable. The worst case is a duller colour.
- [Exact sizes are lost] → That is deliberate. The steps keep an author's headings looking like headings without letting a 40pt banner flood the page.
- [Very wide layout tables (button grids) look different on a phone] → They scroll in their box. That is better than the cells running into one line, which is what happens now.
- [A video thumbnail is fetched from `i.ytimg.com`] → It is a picture under the pictures setting, the same as any picture the author posted. The player itself is never loaded uninvited.
- [Each mod's own file grows] → Mostly class names and `<details>` tags, a few hundred bytes per post. `mods.json` is untouched.

## Open Questions

- None blocking.
