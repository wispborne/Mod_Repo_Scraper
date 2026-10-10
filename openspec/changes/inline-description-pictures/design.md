## Context

`cleanPostHtml` in `lib/site/post_html.dart` rebuilds a forum post from a short list of safe tags. It puts `img` in `_droppedTags`, so every picture goes. Pictures reach the reader only through the Screenshots gallery (`_galleryFor` in `public_data_builder.dart`). That gallery leaves out anything `looksLikeAScreenshot` turns down: badge and donation hosts, addresses that say button, badge, avatar, icon or logo, forum furniture, and anything the post says is under 200 pixels wide.

The saved posts still hold the pictures in place, as `<img src="https://…" alt="" class="bbc_img">`. There are about 9,150 of them across all saved posts, and about 300 give a width. Forum attachments are already absolute addresses (`http://fractalsoftworks.com/forum/index.php?action=dlattach;…`). The forum's smileys are taken out earlier, in `html_processor.dart`. The gallery and the cards already load pictures straight from imgur, photobucket and the rest, so loading pictures from other hosts is nothing new for the site.

On the page, `description()` in `site/views/mod.js` puts `descriptionHtml` in with `el('div', { html })`. It starts the post cut off, measures it once with a `ResizeObserver`, then stops watching.

## Goals / Non-Goals

**Goals:**
- Pictures appear in the description where the author put them, every one of them.
- A reader can turn that off, and when it is off nothing is fetched.
- The gallery stops throwing pictures away and hides the small ones behind a button instead.
- The description stays exactly as safe as it is now: nothing that can run, nothing that can style the page.

**Non-Goals:**
- Copying pictures onto our own host. They stay where the author put them, like the gallery's.
- Changing the card picture, the Forum Data Bundle, `mods.json`, TriOS or the results viewer.
- Showing pictures in the AI paragraph or the merged Discord text. Those have none.
- Video or other embeds. Those stay dropped.

## Decisions

### A picture tag is rebuilt, never copied
`_write` writes a new `<img>` with only these: `src` (checked by the same `_webAddress` rule links use, so `http(s)` only), `alt` (escaped), `width` and `height` when they are plain whole numbers, `loading="lazy"`, `decoding="async"` and `referrerpolicy="no-referrer"`. The forum's `class`, any `style`, and any event attribute never get through. That is the same approach the file already uses for links.

`referrerpolicy="no-referrer"` matters for a second reason besides privacy. Some old image hosts refuse to serve pictures when another site asks for them, and they decide that from the referrer. The gallery should get the same attribute while this is being changed.

Considered: allowing `<img>` through a general attribute allow-list. Rejected, because a single rebuild path is easier to check than a list.

### Picture tags do not count toward the length cap
`maxDescriptionLength` is there so a reader does not get 40,000 words of changelog. It is measured against `out.length`, and a picture tag is around 150 characters. Forty pictures would use half the room, so a short post full of screenshots would be cut short. The cap therefore counts only the characters that are not picture tags. A separate counter is kept for this, and `_write` checks that counter instead of `out.length`.

### A link holding only a picture is kept
The `_emptyTag` tidy-up matches tags with nothing between them. A picture inside a link means the link is no longer empty, so this needs no new code. A test pins topic 35651's shape: a shields.io badge inside a GitHub release link. The `_tooManyBreaks` collapse only matches line breaks that follow each other directly. A picture between them breaks the run, so the author's spacing around pictures is kept. One test checks that.

`_hasWords` stays as it is. A post that is only pictures, with no words, still counts as no description and falls back. Its pictures are still in the gallery.

### The page puts the description in through a `<template>`
Setting `innerHTML` on a `div` that is not on the page yet still starts loading every `<img>` in it. With the setting off, that would fetch every picture before the page could swap them out. So `description()` parses `descriptionHtml` into a `<template>` (the browser loads nothing inside one), changes the pictures there, and then moves the content into the page.

- **Setting on**: each picture gets a load-error handler. A broken picture is removed. If it was its link's only content, the link's address is written in its place. A picture not inside a link gets a click handler that opens `showPicture` over the description's pictures.
- **Setting off**: each picture becomes a small link reading "picture" that opens the viewer. A picture inside a link becomes the link's address as text, so the download link still works.

Considered: hiding pictures with CSS when the setting is off. Rejected, because a hidden lazy picture may still be fetched depending on the browser, and the whole point of turning it off is not fetching.

### The setting sits with the other picture setting
It goes in the existing "Mod pictures" section of the Settings dialog, as a second group of choices: "Pictures in descriptions", with Show and Don't show. It is stored in `localStorage` as `starmodderInlinePictures` (`on` / `off`, anything else reads as `on`), with `inlinePictures()` and `setInlinePictures()` in `lib.js` next to `imageChoice()`. Changing it redraws the page the same way the picture choice does. Nothing needs writing onto `<html>` before the first paint, because only the mod page reads it.

The same choice is also offered beside the "About this mod" heading, as "Hide pictures" / "Show pictures", because a setting tucked away in a dialog is one most readers never find. It is only drawn when the description has pictures. It writes the same `localStorage` key and redraws only the description section, in place, so the reader is not sent back to the top of the page.

### The cut-off keeps measuring until the reader decides
The `ResizeObserver` stays connected until the reader presses "Show more" or "Show less". Each time the content changes size, it decides again. It cuts the description off and shows the button when the content overruns, and removes both when it fits. The observer watches the content inside the clip, not the clip itself, because the clip's own height is fixed while it is cut off. Pictures with a width and height keep their space while loading, so the page jumps less. The others still change the size, and the observer catches that.

### The gallery publishes everything and marks the small pictures
`looksLikeAScreenshot` keeps its meaning. `_galleryFor` no longer returns early on it. It sets `PublicImage.small = true` instead. Forum furniture is the one thing still left out, because it is the forum's, not the author's. That needs a separate check, `isForumFurniture`, split out of `isBadgeOrDonationImage`, which keeps its current behaviour for the LLM step. `small` is a nullable `bool` written only when true, the same as `isTool`, so mods without small pictures produce the same output as before.

On the page, `gallery()` draws the pictures without `small` first. If any small pictures exist, it adds a button under the grid: "Show 3 small pictures" / "Hide small pictures". The viewer's list (`working`) is rebuilt from what is showing whenever the button is pressed. A mod with only small pictures still gets the section, so the button has somewhere to be.

### The sample data shows both new things
`site/sample-data/` gets one mod whose `descriptionHtml` holds a picture between paragraphs and a badge inside a link, and whose gallery has one `small` entry. `sample_data_test.dart` already ties the sample files to the models, so `small` has to be in both.

## Risks / Trade-offs

- [A post with dozens of large pictures makes a heavy page] → `loading="lazy"` fetches only what is near the screen. The description starts cut off. The setting turns it all off.
- [Dead image hosts (photobucket and others) leave gaps or broken-picture icons] → Broken pictures are removed. The text left in a link's place keeps the link working.
- [A hotlinked host could swap a picture for something else later] → This is already true of the gallery and the cards. Nothing new is opened up, and the reader can turn pictures off.
- [Pictures change the height after the first measurement, so "Show more" could flicker] → The decision is made again only when the size really changes, and the reader's own press ends the measuring.
- [Each mod's own file grows] → Roughly 150 characters per picture. The largest mod files grow by tens of kilobytes. `mods.json` is untouched, so its 2 MB test is unaffected.
- [`descriptionHtml` used to promise no pictures] → Only the site reads it. TriOS reads the bundle, not this file.

## Open Questions

- None blocking. Whether the description's pictures should also be left out of the gallery, to avoid seeing them twice, was settled: keep them in both.
