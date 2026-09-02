## Context

See `proposal.md` for the motivation. The public site is a static application on a plain host. Its mod route was `#/mods/<id>`, while the data build already wrote `mods/<id>/index.html` carrying that mod's Open Graph metadata and a script redirecting a human reader to the hash route — so the browser always finished on the generic, non-previewable address.

The site must stay portable to an arbitrary deployment folder on a plain static server: no rewrites, no Workers, no Pages Functions, no redirect rules.

## Goals / Non-Goals

**Goals:**

- Make the ordinary browser address of a displayed mod its existing `mods/<id>/` preview address.
- Keep one record of the current route, so the address bar and the drawn page can never disagree.
- Keep styles, scripts and data requests resolving against the deployment directory.
- Keep reload, redraw, Back and Forward working, and never reload the site to move between pages.

**Non-Goals:**

- Replacing every site route with a path. Only mod pages are shared to link-preview clients, and only mod pages have a file behind them; hash routes are cheaper and need nothing generated.
- Adding server rewrites, redirects, Workers, Pages Functions, or runtime configuration.
- Adding a copy/share control. The complaint is about the address bar, which a button does not answer.

## Decisions

### The address is the route; nothing is kept beside it

`site/address.js` derives the route from the browser address alone: a path of `mods/<id>/` below the deployment directory is that mod, and anything else reads the hash on the front document. There is no route in `history.state`.

An earlier attempt kept the hash route in `history.state` while showing the mod's path, and it produced three defects in one week, all instances of the same mismatch between what the address said and what was loaded: a dead Back button, a full site reload on every link followed from a mod, and a silently dropped `?data=sample`. Two records of one fact need arbitration, and every mechanism keyed on the address — which history event fires, how a link resolves, what a reload fetches — sided with the address.

### A mod's page is the site's own document, not a redirect

`buildModPageHtml` takes the text of `site/index.html` and replaces one marked head region — between `<!--page-head-->` and `<!--/page-head-->` — with that mod's `<base>`, title, description and preview tags. So `mods/<id>/` is a real, working page: a shared link lands on it directly, and a reload settles on the same address with no bounce.

Duplicating the chrome in Dart was rejected: two copies of the header, settings dialog and footer would drift. Reading the one file the publisher already copies keeps a single source, and a test pins that the marks are still present and still above the first relative address on the page.

The cost is size: about 6.5 MB across 1,089 mods, against 1.3 MB for the redirecting stubs, on a published output already around 21 MB. The files are near-identical, so the published repo's growth per commit is far smaller than the working-tree figure. A trimmed shell would roughly halve it at the price of moving the settings dialog's markup into JavaScript — a separate change, not worth bundling here.

A site folder that cannot be read, or one that has lost its marks, falls back to the old small redirecting page and logs it. Mod links point at these paths, so a page must always exist; degrading to a working-but-hash-addressed page is the safe failure.

### Clicks on our own links become history entries

Because a mod's address and a hash address have different paths, an ordinary click between them is a whole new document load. One delegated click handler resolves each link, and pushes a history entry for any address the site draws; everything else — other origins, `mods/<id>.json`, the release feed, new tabs, downloads, modified clicks — is left to the browser.

"Ours" means the front document or a `mods/<id>/` **folder**. Requiring the folder is load-bearing: `mods/<id>.json` sits right beside `mods/<id>/` and matches any looser rule, and treating a data file as a page swallows the click.

### Both history events are listened for

An ordinary hash link fires `hashchange`, and in some browsers `popstate` as well. A jump between a mod's path and a hash address changes more than the fragment, so it fires **only** `popstate`. Listening for one of those alone is exactly what left the Back button dead. The address last drawn is remembered so a hash link that fires both events is still drawn once.

### The document base is pinned absolute at startup

Both documents carry a base saying where the site's files are — `./` on the front document, `../../` on a mod's page — and the address module pins it to an absolute address as the site starts. The address bar moves without a document being loaded, so a base still written relatively would follow it and every style, script and data request would be looked for inside the mod's folder.

The reader's `?data=…` is pinned onto the base too, which is what keeps `?data=sample` alive across every link on the site, including a middle-click.

## Risks / Trade-offs

- **[Two address shapes make history traversal fire different events]** → Listen for both `popstate` and `hashchange`, remember the address last drawn, and cover Back and Forward in the tests over a fake browser with a real history stack.
- **[A moving address breaks relative references]** → Pin the base absolute at startup; test a nested deployment and a data request made from a mod address.
- **[Mod pages grow the published output]** → Measured: +6.5 MB on ~21 MB, near-identical files that compress and delta well.
- **[A missing site folder would leave mod links pointing at nothing]** → Fall back to the redirecting page and log it; a test pins that path.
- **[Discord may retain an older preview for a stable URL]** → Cache refresh remains outside this change; the permanent address is the correct fetch target.

## Migration Plan

Publish the updated static assets normally. Existing `#/mods/<id>` links keep working and draw the mod. Existing `mods/<id>/` links keep serving the same metadata and now land on a working page. No data migration, configuration or hosting change is required. Rollback restores the prior assets.
