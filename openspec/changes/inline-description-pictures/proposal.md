## Why

A mod's description is the author's forum post with every picture taken out. Authors place their pictures with care: a banner at the top, a screenshot under the paragraph about each ship, a badge as the download link. With the pictures gone, the page reads like a different post, and some links vanish completely. In topic 35651, every download link is a picture of a badge. The link holds nothing else, so it is removed as empty and the description shows no downloads at all.

The Screenshots section has the opposite problem. Everything the screenshot rules turn down is gone for good. A reader who wants to see the author's small pictures has no way to.

## What Changes

- The description keeps every picture from the post, in the place the author put it. That includes badges, donation buttons and small icons. Only the address and the alt text are kept, plus the width and height the author gave. Nothing else on the tag survives.
- A link whose only content is a picture is kept, so badge-style download links come back.
- A new setting, "Pictures in descriptions", has two choices: show them or don't. It is on by default and kept in the reader's browser like the other settings. When it is off, the pictures are not loaded at all. Each one becomes a small "picture" link that opens it over the page.
- The Screenshots section now publishes every picture, not just the ones that pass the screenshot rules. A picture the rules turn down is marked as a small picture and hidden at first, and a button under the gallery shows them. The forum's own furniture (smileys, theme graphics, avatars) is still never published.
- Inline pictures that fail to load are taken out, the way the gallery already does it. A picture that was a link's only content leaves the link's address behind as text, so the link still works.
- Clicking an inline picture that is not inside a link opens the same picture viewer the Screenshots section uses.
- The description's "Show more" cut-off is measured again as pictures load. A short post can turn long once its pictures arrive.
- **BREAKING (for the published data only)**: `descriptionHtml` can now hold `<img>` tags, and gallery entries can carry `small: true`. TriOS does not read either of these. `mods.json` does not change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `public-site-data`: "The description is the author's own post, kept formatted" now keeps pictures. "The gallery holds screenshots, not badges" becomes a gallery that publishes everything and marks the small pictures. Both requirements come from the unarchived `starmodder-4-public-site` change, which is where the site's specs currently live.
- `public-site-pages`: new requirements for showing pictures in the description, the setting that turns them off, and the button that shows the gallery's small pictures. "Screenshots open over the page" is extended to cover pictures in the description.

## Impact

- `lib/site/post_html.dart`: stop dropping `img`, write a cleaned picture tag, and keep picture tags from counting toward the length cap.
- `lib/site/gallery_filter.dart` and `_galleryFor` in `lib/site/public_data_builder.dart`: publish every picture and mark the small ones, instead of leaving them out.
- `lib/site/models/public_mod_detail.dart` (`PublicImage.small`) and its generated mapper.
- `site/views/mod.js`: put the description in without loading pictures early, handle the setting, broken pictures and clicks, keep measuring the cut-off, and add the "show small pictures" button.
- `site/lib.js`, `site/index.html` and `site/style.css`: the new setting and how inline pictures look.
- `site/sample-data/` and `test/site/sample_data_test.dart`.
- Tests: `test/site/post_html_test.dart`, `test/site/gallery_filter_test.dart` and `test/site/public_data_builder_test.dart`.
- `CLAUDE.md`: the "Descriptions" and "Galleries" bullets, and the site settings notes.
- Each mod's own `mods/<id>.json` gets a little bigger. `mods.json`, the Forum Data Bundle, `ModRepo.json` and the results viewer are unchanged.
