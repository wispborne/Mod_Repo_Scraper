# For the TriOS repo: duplicate catalog cards on a thread holding several mods

Not filed — this is the text to post as an issue on TriOS when you want to.
Written while building the same feature on Starmodder's side, from reading
`lib/catalog/catalog_links.dart`.

---

## What happens

`withSynthesizedAddonEntries` can draw a second card for a mod the catalog
already lists, on any thread that holds more than one mod. Whether it does
depends on the order `realMods` happens to be in, so it will look intermittent.

Topic 34161, "Hartley's Miscellaneous Mods", is the example. The thread holds
four mods, all read as `main`. Three are real catalog entries, under the names
the mod index gives them:

| catalog entry | LLM entry on the thread |
| --- | --- |
| `Useful.Tithes 1.0.a` | `Useful.Tithes` |
| `Big Pilum Energy 1.0.d` | `Big Pilum Energy` |
| `Disco.Balls 1.1.c - More Lamp Colour Options` | `Disco.Balls` |
| — | `Lost.Sector` (rightly synthesized) |

## Why

Two checks stand between an LLM entry and a made-up card, and on this thread
both can miss the same mod.

1. **`existingNames` is keyed on raw lowercased names.** It is built as
   `mod.name.toLowerCase().trim()`, so it holds `useful.tithes 1.0.a` and the
   candidate key is `useful.tithes`. No match, though they are one mod.

2. **`_isTheCatalogEntry` only sees the entry the thread was reached through.**
   The loop is `for (final mod in realMods)`, and the thread is looked up from
   that mod. Three entries point at topic 34161, so the thread is processed
   three times, and each time every LLM entry is compared against only *that*
   entry. When the loop arrives via `Useful.Tithes 1.0.a`, the candidate
   `Big Pilum Energy` is compared against Useful.Tithes, misses, and — having
   already missed check 1 — gets a card.

`modNamesMatch` itself is fine: `cleanModDisplayName` takes `1.0.a` off the end
and the two names do agree. It just never gets asked about the right pair.

`synthesizedNames` then stops the *same* name being synthesized twice across the
three passes, which is why the result is one extra card per affected mod rather
than three, and why it depends on which entry the loop reaches first.

## Suggested fix

Either would do; the second is closer to the real intent.

- Key `existingNames` on `cleanModDisplayName(mod.name).toLowerCase()` rather
  than the raw name, and compare candidates the same way.
- Group the real entries by topic id first, and have `_isTheCatalogEntry`
  compare a candidate against **every** real entry on that thread rather than
  the one the loop arrived by. This also means each thread is walked once
  instead of once per entry pointing at it.

## Two smaller things, while you are in here

- **A version in the middle of a name gets past `cleanModDisplayName`.**
  `_nameDecoration`'s version pattern is anchored to the end
  (`\s+v?\.?\s*\d[\w.\-]*$`), so `Disco.Balls 1.1.c - More Lamp Colour Options`
  cleans to itself and never matches `Disco.Balls`. The forum writes titles this
  way fairly often — name, version, then a subtitle. Starmodder cuts the name at
  the first version wherever it sits instead of trimming one off the end, which
  handles both shapes; see `matchableName` in `lib/site/mod_name_match.dart`
  over there if it is useful.
- **Starmodder will show two mods where TriOS shows one.** Both SirHartley's
  `Lost.Sector` (topic 34161) and Kissa_Mies's `LOST_SECTOR` (topic 27556)
  exist and are different mods. TriOS's `synthesizedNames` dedups made-up names
  across all threads, first thread wins, so only one card is ever drawn.
  Starmodder scopes the check to one thread and publishes both, because it hands
  out permanent web addresses and two real mods need two of them. Worth knowing
  the two catalogs will disagree here on purpose; if TriOS wants to match, the
  dedup would need to key on the topic as well as the name.
