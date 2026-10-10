## Why

A mod's description is rebuilt from the author's forum post, but most of the forum's own formatting is thrown away, and some of it leaves junk behind:

- **Spoilers** are the worst case: 3,601 of them in 724 posts. Each loses its fold, so everything inside is shown open, with the spoiler's title stuck on the line above and a stray "[close]" on the line below.
- **Quotes and code blocks** leak the words "Quote" and "Code" into the text.
- **Tables** (72 posts, mostly rows of download buttons) run their cells together into one line.
- **Centred text** (4,745 blocks) is pushed to the left.
- **Text sizes** (about 5,200) are flattened, so an author's headings read like body text.
- **Underlines and colours** are lost (292 and 343 posts).
- **Videos** (117 YouTube and 9 Vimeo) vanish without a trace.

The site now shows the post's pictures in place, so the post should look like the author laid it out as well.

## What Changes

- **Spoilers** become folds that start shut, with the author's title as the label. The "[close]" line goes.
- **Quotes** lose the "Quote" header line. A header that names someone ("Quote from: Vayra on …") is kept as a small line at the top of the quote.
- **Code blocks** lose the "Code" header line. Inline `tt` text becomes `code`.
- **Tables** keep their rows and cells, inside a box that scrolls sideways on a narrow screen.
- **Centred and right-aligned blocks** keep their alignment.
- **Text sizes** are kept as one of four steps (smaller, bigger, much bigger, biggest) mapped onto the site's own text sizes. The author's exact point size is not kept.
- **Underlined text** stays underlined. Numbered lists stay numbered.
- **Author colours** are kept, but the page adjusts each one to the current theme so it stays readable. Black text on the dark theme, for example, is lightened.
- **YouTube videos** become a preview: the video's thumbnail with a play button, linking to the video. Clicking it plays the video in place. Nothing is loaded from YouTube's player until then. The thumbnail is a picture like any other, so the pictures setting covers it. **Vimeo videos** become a plain link.
- Fonts, text shadows and scrolling marquees are still dropped.
- Every class and every attribute in `descriptionHtml` is still written by the builder from a fixed list. Nothing is copied from the forum's HTML.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `public-site-data`: the description keeps more of the forum's formatting (new requirements beside "The description is the author's own post, kept formatted").
- `public-site-pages`: how spoilers, videos, colours and tables look and behave on a mod's page.

Both requirements files still live in the unarchived `starmodder-4-public-site` change. These are written as ADDED requirements. "The description is the author's own post, kept formatted" lists the tags that survive, so its list has to be widened by hand when this is archived.

## Impact

- `lib/site/post_html.dart`: most of the work. It reads the forum's classes and styles and writes our own fixed classes in their place. It also turns spoilers into folds, iframes into video previews, and drops header lines.
- `site/views/mod.js` (`postBody`): turns a video preview into a player on click, follows the pictures setting for video thumbnails, and leaves pictures in shut spoilers alone.
- `site/style.css`: styles for folds, alignment, the four size steps, author colours (new names in the block at the top, in every theme), tables, quote lines and video previews.
- `site/sample-data/`: one description showing each kind of formatting.
- `test/site/post_html_test.dart`: a test for each kind of formatting, and one for each thing that must still be dropped.
- `CLAUDE.md`: the "Descriptions" bullet.
- `mods.json`, the Forum Data Bundle, `ModRepo.json`, TriOS and the results viewer are unchanged. Each mod's own file grows slightly.
