## Why

Some forum threads hold several mods at once. "Hartley's Miscellaneous Mods" (topic 34161) is four: Useful.Tithes, Big Pilum Energy, Lost.Sector and Disco.Balls. The site publishes one mod per merged ModRepo entry, and ModRepo learns about mods from the forum board listings (one row per thread) or from Discord — so the only ones that reach the site are the three the author happened to also post on Discord. Lost.Sector is on the site nowhere at all, even though the LLM already read it off that thread, with its own download, and it is sitting in `forum-data-bundle.json` today.

TriOS already solves this. Its catalog builds extra entries from a thread's LLM mod list (`withSynthesizedAddonEntries` in `lib/catalog/catalog_links.dart`), which is why Lost.Sector has a card in TriOS and no page on the site. The two should agree about which mods exist, and TriOS's code is the model to follow here — where this change deviates from it, the deviation is named in the design and has a reason.

## What Changes

- The site's data builder makes an extra published mod for every `main` mod the LLM named on a published mod's thread that no mod already being published accounts for. It takes its name, downloads, image and facts from the LLM's reading of that thread, and its authors and forum URL from the thread. Its game version is the thread's, falling back to the sibling merged mod's — the same fallback TriOS uses, so the new mod is not hidden by Browse's game-version filter on the very page meant to surface it.
- Threads are reached only through the mods already being published, the same way TriOS only reaches a thread through a real catalog entry. A thread no published mod points at contributes nothing.
- A thread-only mod gets a permanent id from `ModIdStore` like any other, so its page address never moves. Its `mark` is the topic id, which is what keeps SirHartley's `Lost.Sector` and Kissa_Mies's `LOST_SECTOR` — the same cleaned name, two different mods — on two ids rather than fighting over one.
- A thread-only mod says which thread it came from (`partOfThreadTitle`), so its page and its card can say "part of Hartley's Miscellaneous Mods" rather than looking like a thread of its own. As in TriOS, only the made-up entries carry the field; a merged mod never does.
- Matching an LLM mod against the mods already being published works the way TriOS's `modNamesMatch` works: cleaned names first (`ModIdStore.cleanName`, so `Useful.Tithes` matches the merged `Useful.Tithes 1.0.a`), then letters and numbers only, so a punctuation difference in how the LLM spelled a name cannot mint a duplicate page with a permanent id.
- On a shared thread, no mod's facts are guessed. A mod takes the LLM entry whose name matches its own; a thread with a single `main` entry gives it to the merged mod whatever either is called. Those are the two rules of TriOS's `_isTheCatalogEntry`. A merged mod on a multi-mod thread that matches no entry takes no LLM facts at all — today it silently takes the first entry's, which would put one mod's downloads and changelog on another mod's page.
- A shared thread's post stops being any of its mods' description, and a shared thread's releases stop being credited to whichever of its mods happened to come last in the builder's list.
- `sources` on a thread-only mod is `["forum"]`, and a merged mod whose thread was scraped gets `forum` added to its sources. The "Discord only" badge itself is already fixed in `site/lib.js` — `isDiscordOnly` stands down for any mod with a forum link — so this is about the published data saying the same thing the badge logic already knows, and about the "found on" list on a mod's own page.
- Not changed: `mods.json` stays under its size limit, nothing internal reaches the published files, and the add-on list on a mod's page keeps working as it does — a mod the LLM marked `addon` or `variant` is still an add-on, not a mod of its own. TriOS synthesizes cards for those too; the site deliberately does not.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `public-site-data`: adds requirements that a thread's other mods are published as mods in their own right, with permanent ids and a note of which thread they came from; that a mod found on a scraped thread has the forum as a source; and that a shared thread's facts and releases are never guessed. Modifies the description requirement, because a shared thread's post must not be any one mod's description. This capability is defined by the in-flight `starmodder-4-public-site` change and is not yet in `openspec/specs/` — that change has to be archived first, and the modified requirement hand-applied (see the archive note in tasks).

## Impact

- `lib/site/public_data_builder.dart` — where the extra mods are built. `_mainLlmMod`, `_addonsFor` and `_releasesByMod` all change how they treat a shared thread; `_JoinedMod` learns whether a mod is merged or a stand-in; `_sourcesFor` learns about the thread.
- `lib/site/mod_id_store.dart` — ids for mods that have no merged `ScrapedMod` behind them.
- `lib/site/models/public_mod.dart` and `public_mod_detail.dart` (plus their generated mappers) — a field saying which thread a mod is part of.
- `site/views/browse.js`, `site/views/mod.js`, `site/lib.js` — showing that field.
- `site/sample-data/` and `test/site/sample_data_test.dart` — the examples are pinned to the models, so a new field has to be added in both.
- `outputs/site/mods.json` grows by however many thread-only mods there are; the under-2-MB test stands.
- Not touched: `ModRepo.json` and `forum-data-bundle.json` keep their current shape, and TriOS keeps reading both exactly as it does now.
