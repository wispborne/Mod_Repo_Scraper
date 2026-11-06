## Context

The new viewer has been served beside the old one since `viewer-v2-shell`: the old viewer at `/` and the new one at `/v2/`, or the other way round with `--ui v2`. Every page is now built. The new viewer no longer depends on the old one.

## Decisions

**Rename `web2/` to `web/` instead of keeping `web2/`.** The server, the release and the update script already know `web/`, and a folder named after a version that no longer exists would only confuse. Browser storage keys starting with `viewer2` keep their names to preserve the saved choices.

**Redirect `/v1/` and `/v2/` instead of returning 404.** Bookmarks and open tabs from the past weeks point there. A redirect to the same path without the prefix keeps the `#/...` part, because browsers keep the fragment through a redirect. A name that only starts with the prefix (`/v2x/`) is not redirected.

**Map the old viewer's page addresses in the browser** (`movedAddress` in `routes.js`). The server never sees the `#/...` part, so the browser must map these addresses. The router replaces the address before drawing, so Back does not return to the old address. Only the search text is carried over to lists, because the old filter names differ from the new ones. An old Mod Catalog id was a position in `ModRepo.json`, not a permanent id, so `#/modrepo/<n>` opens the Mods list.

**Ship an empty `web2/` for one transition.** The update script stops with "The release is missing web2. Nothing was changed." when a folder it lists is missing. The copy on the host is not updated by a release and may list `web2`. The folder keeps updates working with either copy of the script on the host. Remove it once the host's script no longer lists `web2`.

**Remove the old page specs instead of rewriting them.** `runs-page`, `topic-actions`, `viewer-llm-inspection`, `viewer-merge-explorer` and `viewer-output-browsing` describe pages that no longer exist. The `viewer-v2-*` specs describe the pages that replaced them, and the server behaviour those specs relied on is in `viewer-server`, `bundle-comparison`, `merge-comparison`, `topic-history` and the run history specs, which stay.
