## 1. Pictures in the published description

- [x] 1.1 In `lib/site/post_html.dart`, take `img` out of `_droppedTags` and write a rebuilt `<img>` in `_write`: `src` checked by `_webAddress`, escaped `alt`, `width`/`height` only when whole numbers, `loading="lazy"`, `decoding="async"`, `referrerpolicy="no-referrer"`, nothing else. A picture without a usable address is skipped.
- [x] 1.2 Count the length cap without picture tags. Keep a separate count of non-picture characters, and have `_write` and `cleanPostHtml` check that count instead of `out.length`.
- [x] 1.3 Rewrite the file's opening note so it says pictures are kept and why.
- [x] 1.4 Make sure `_plainWords` / `plainWordsOf` give no text for a picture, so `description` stays words only.
- [x] 1.5 Tests in `test/site/post_html_test.dart`:
  - a picture between two paragraphs stays in place;
  - `onerror`, `style` and `class` are stripped;
  - `javascript:` and `data:` addresses are dropped;
  - a badge-only link is kept (topic 35651's shape);
  - forty pictures in a short post are not cut short;
  - line breaks around a picture are not collapsed;
  - a post of only pictures still gives null.
- [x] 1.6 Update any existing test that expects `<img>` to be dropped.

## 2. Gallery publishes everything and marks small pictures

- [x] 2.1 In `lib/site/gallery_filter.dart`, split the forum-furniture check out of `isBadgeOrDonationImage` into `isForumFurniture`. `isBadgeOrDonationImage` keeps calling it, so the LLM step behaves the same.
- [x] 2.2 Add `final bool? small` to `PublicImage` in `lib/site/models/public_mod_detail.dart`, written only when true. Regenerate with `dart run build_runner build --delete-conflicting-outputs`.
- [x] 2.3 In `_galleryFor` (`lib/site/public_data_builder.dart`), skip only forum furniture. Set `small: true` where `looksLikeAScreenshot` says no.
- [x] 2.4 Tests in `test/site/gallery_filter_test.dart` and `test/site/public_data_builder_test.dart`:
  - a donation button is published marked small;
  - a screenshot carries no `small` field;
  - a forum smiley is not published;
  - a picture with no size is not marked small.

## 3. The setting

- [x] 3.1 In `site/lib.js`, add `inlinePictures()` / `setInlinePictures()`. Use the `starmodderInlinePictures` key, `on` / `off`, default `on`, with every read and write wrapped so a blocked storage still gives `on`.
- [x] 3.2 In `site/index.html`, add a "Pictures in descriptions" choice group (Show / Don't show) to the "Mod pictures" section of the Settings dialog. Give each choice a one-line note in plain English.
- [x] 3.3 Wire the choice up where the other settings are wired. Tick the saved choice when the dialog opens, and save and redraw the page on change.

## 4. The mod page

- [x] 4.1 In `description()` in `site/views/mod.js`, parse `descriptionHtml` into a `<template>`, change its pictures, then move the content into the page. No picture may start loading before the setting has been applied.
- [x] 4.2 Setting on:
  - a broken picture is removed;
  - if it was its link's only content, the link's address is written in as text;
  - a picture not inside a link opens `showPicture` over the description's working pictures.
- [x] 4.3 Setting off:
  - each picture not inside a link becomes a small "picture" link that opens the viewer;
  - each picture inside a link becomes the link's address as text.
- [x] 4.4 Keep the `ResizeObserver` measuring the content inside the clip until the reader presses the button. Each time the size changes, apply or remove the cut-off and the "Show more" row.
- [x] 4.5 In `gallery()`, show non-small pictures first. Add a "Show N small pictures" / "Hide small pictures" button when there are any. Rebuild the viewer's list from what is showing. Keep the section for a mod whose pictures are all small.
- [x] 4.6 Give gallery pictures `referrerpolicy="no-referrer"` too, where `picture()` builds them.
- [x] 4.7 In `site/style.css`, use only names from the block at the top:
  - `.prose img` gets `max-width: 100%`, `height: auto`, and room around block-sized pictures;
  - add a style for the small "picture" link;
  - add a style for the gallery's small-pictures button.

## 5. Sample data, docs and checks

- [x] 5.1 Add a picture between paragraphs, a badge inside a link, and one `small` gallery entry to a mod in `site/sample-data/`. Keep `test/site/sample_data_test.dart` passing.
- [x] 5.2 Update `CLAUDE.md`:
  - the "Descriptions" bullet: pictures are kept, rebuilt and not counted toward the cap;
  - the "Galleries" bullet: everything is published, small pictures are marked and hidden behind a button, and forum furniture is never published;
  - add the new setting to the site settings notes.
- [x] 5.3 Run `dart test`.
- [x] 5.4 Open the site with `?data=sample` and with real data (`dart run bin/site_server.dart`). Check each of these:
  - pictures sit in place, and a broken one leaves its link behind;
  - the setting turns pictures off, with no picture requests in the network log;
  - "Show more" appears for a short post with large pictures;
  - the gallery's small-pictures button works;
  - the light theme and phone width still look right.
- [ ] 5.5 Hand-apply the two spec changes onto the site specs when archiving, then archive with `--skip-specs`. The site specs still live in the unarchived `starmodder-4-public-site` change, and `openspec archive` fails on MODIFIED changes.

## 6. Added while building

- [x] 6.1 Offer the same choice as "Hide pictures" / "Show pictures" beside the "About this mod" heading, only when the description has pictures, redrawing just the description in place.
