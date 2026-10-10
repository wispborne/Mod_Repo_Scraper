# Bring Starmodder 3's search over to Starmodder

## Why

Starmodder 3 (the older site, `F:\Code\Starsector\Starmodder3`) has a smarter search than this site: it matches acronyms ("swp" finds Ship/Weapon Pack), it matches game and mod versions, it checks each fact about a mod separately instead of one big string, and a comma means "any of these" rather than "all of these". This site's search misses all of that. The user asked to copy Starmodder 3's search logic into this site so both search the same way.

## What Changes

- The browse page's search matches the way Starmodder 3's does. Each mod gets a list of search terms built once: its name, the name broken into words, the first letters of those words as an acronym, everyone credited and their other names, its categories, its game version and its mod version. A typed term matches when it appears inside any one of those, not inside a run-together blob of all of them.
- **Behavior change:** comma-separated terms now mean "any of these" instead of "all of these". Typing "faction, portrait" lists faction mods and portrait mods together. A leading minus still leaves mods out, and works the same as before. The hint under the search box is reworded to say this.
- The suggestion box in the top bar uses the same term list, so typing "swp" suggests Ship/Weapon Pack there too. Name matches still rank above everything else.
- Three deliberate differences from Starmodder 3 are kept: other author names come from the published data (`otherAuthorNames`), not a hardcoded table; the mod's summary stays searchable, because it is searchable today; and the tidied `displayName` is searched as well as the thread title.

## Capabilities

### New Capabilities

- `site-search`: how the public website's search decides which mods match what a reader typed — on the browse page and in the top-bar suggestion box.

### Modified Capabilities

_None. No existing spec covers the public site's search._

## Impact

- `site/views/browse.js` — `readSearch`, `searchableText`, `matchesSearch` are replaced by the new matching; the hint text under the search box changes.
- `site/app.js` — `matchStrength` (suggestion ranking) learns the new terms.
- Likely a new shared module (for example `site/search.js`) so the browse page and the suggestion box use one implementation.
- No data files change; everything the search needs is already in `mods.json`.
- No server, pipeline or viewer code changes.
