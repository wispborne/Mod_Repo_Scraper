## Why

Starmodder already publishes mod-specific Open Graph pages, but the page a reader actually visits uses a `#/mods/<id>` address. Discord never sends the fragment to the server, so copying the page address—the ordinary way people share a page—still produces the generic Starmodder preview.

## What Changes

- Show the existing `mods/<id>/` address in the browser while a mod page is open, so ordinary address-bar copying produces a mod-specific preview.
- Keep the hash route in browser history as the application's private route, so redraws and Back/Forward continue to find the displayed mod after its hash is hidden.
- Fix the application's base at its deployment directory so hash links and relative data fetches keep working from the deeper visible mod path, including when Starmodder is hosted below a path.
- Keep the existing generated preview pages and static-host-only architecture unchanged.

## Capabilities

### New Capabilities

- `mod-page-sharing`: Every displayed mod page has a stable, mod-specific browser address whose Discord preview carries that mod's published identity and content.

### Modified Capabilities

None.

## Impact

- Public-site address and history handling, router integration, and mod-page rendering in `site/`.
- Browser-side tests for root and nested deployments, route persistence, and navigation history.
- Existing generated pages under `outputs/site/mods/<id>/` and their Open Graph metadata remain the destination and require no hosting feature, API, or dependency.
