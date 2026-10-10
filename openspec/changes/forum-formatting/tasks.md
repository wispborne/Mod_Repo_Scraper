## 1. The builder writes the forum's formatting as our own

- [x] 1.1 In `lib/site/post_html.dart`, recognise spoilers (`div.sp-wrap` / `sp-head` / `sp-body` / `sp-foot`). Write `<details class="spoiler"><summary>…</summary>…</details>`, with "Spoiler" for an empty title and no "[close]".
- [x] 1.2 Quotes and code: drop `quoteheader`, `quotefooter` and `codeheader`. Turn a quote header naming someone into `<cite>` inside the next `<blockquote>`. Turn `tt` into `<code>`.
- [x] 1.3 Tables: keep `table` / `tbody` / `thead` / `tr` / `td` / `th` with no attributes, inside `<div class="table-scroll">`. Keep `td` and `th` out of the empty-tag tidy-up.
- [x] 1.4 Alignment: `align="center"` and `text-align: center|right` become `div.align-center` / `div.align-right`. Teach the empty-tag tidy-up `div` and `span`.
- [x] 1.5 Sizes: read `font-size` (pt, em, px, `small`), convert to points, and write `span.size-*` by the steps in the spec. Drop sizes that can't be read.
- [x] 1.6 Colours: add a named-colour table and a reader for `#rgb`, `#rrggbb` and `rgb()`. Write `span.author-colour style="--c:#rrggbb"`. Drop anything else.
- [x] 1.7 Underline `span.bbc_u` becomes `<u>`. A `ul` with `list-style-type: decimal` becomes `<ol>`.
- [x] 1.8 Videos: a YouTube iframe with a valid 11-character id becomes `a.video-link` holding the `i.ytimg.com` thumbnail as a rebuilt picture. A Vimeo iframe becomes a "Video on Vimeo" link. Anything else is dropped.
- [x] 1.9 Tests in `test/site/post_html_test.dart`:
  - one test for each scenario in the `public-site-data` spec, using real forum markup;
  - a test that the only classes in the output come from the fixed list, and that `style` only ever holds `--c:#rrggbb`;
  - a test that a hostile colour, an invalid video id and an iframe from another host all write nothing.

## 2. The mod page

- [x] 2.1 In `postBody` (`site/views/mod.js`), handle `a.video-link`:
  - with pictures on, a plain click swaps in a `youtube-nocookie.com` player of the same size;
  - with pictures off, it reads "Video on YouTube" and no thumbnail is fetched;
  - a thumbnail that fails to load leaves the same words.
- [x] 2.2 Keep video thumbnails out of the screenshot viewer's list, and out of the "picture inside a link" handling.
- [x] 2.3 Check that pictures inside a shut spoiler are not fetched until it opens, and that opening one re-checks the cut-off.

## 3. Styles

- [x] 3.1 Add `--author-l-min` and `--author-l-max` to every colour block at the top of `style.css`: the dark default, the light media query, the shared `[data-theme]` block and `[data-theme="light"]`.
- [x] 3.2 Add the `.prose` rules:
  - spoiler folds;
  - `table-scroll` and table cells;
  - `align-center` / `align-right`;
  - the four `size-*` steps on the `--type-*` names;
  - `author-colour` (the `color-mix` fallback, then `oklch(from …)`);
  - `cite` in quotes;
  - the video preview, a 16:9 box with a play mark, and the player that replaces it.

## 4. Sample data, docs and checks

- [x] 4.1 Add a spoiler, a named quote, a table, centred text, a size, a colour and a video to the Nexerelin sample. Keep `sample_data_test.dart` passing.
- [x] 4.2 Update the "Descriptions" bullet in `CLAUDE.md`.
- [x] 4.3 Run `dart test`.
- [x] 4.4 Rebuild `outputs/site` from real data (using copies of the id and release files), then check in the browser:
  - spoilers start shut and their pictures wait;
  - a video plays on click;
  - black and yellow author colours are readable on the dark and Light themes;
  - a button table scrolls on a phone;
  - sizes look like headings, not banners.
- [ ] 4.5 At archive time, widen the tag list in "The description is the author's own post, kept formatted" by hand, then archive with `--skip-specs`.
