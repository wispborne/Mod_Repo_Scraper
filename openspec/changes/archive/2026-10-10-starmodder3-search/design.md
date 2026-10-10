# Design: Bring Starmodder 3's search over

## Context

Starmodder 3 lives at `F:\Code\Starsector\Starmodder3` (one `app.js`, no modules). Its search works like this:

- `buildSearchTags(item)` builds a cached list of lowercase terms per mod: the name; the name slugified, each slug word, and the slug words' first letters as an acronym; each author and their aliases (a hardcoded table); each category; the game version; the mod version.
- `searchMods(items, query)` splits the query on commas. Each term is a substring check against each tag. Positive terms union their matches; a term with a leading "-" removes its matches from the result. Only-negative queries start from every mod.

This site searches in two places today:

- `site/views/browse.js` — `readSearch` (comma split, minus), `searchableText` (name, displayName, authors, other names, categories, summary, joined into **one string**), `matchesSearch` (**every** positive term must match).
- `site/app.js` — `matchStrength` ranks top-bar suggestions: name-starts-with (3), name-contains (2), author-contains (1).

So the site already has the comma split and the minus. What it lacks from Starmodder 3: the acronym, matching versions, per-fact matching instead of one joined string, and commas meaning "any" instead of "all".

## Goals / Non-Goals

**Goals:**

- Match the way Starmodder 3 matches: per-fact substring checks over a cached term list, acronym included, versions included, commas meaning "any of these".
- One implementation used by both the browse page and the top-bar suggestions.
- Keep what this site already does better: other author names from the published data, summary searchable, displayName searchable.

**Non-Goals:**

- No debounce on the browse search box. Starmodder 3 debounces because it rebuilds its whole page per keystroke; this site redraws only the results and is fast enough as it is.
- No port of Starmodder 3's `penalty` field on tags — nothing in its own code ever reads it.
- No hardcoded author-alias table. `otherAuthorNames` in `mods.json` already carries the same facts, kept up to date by the pipeline.
- No change to the category, version, needs or author dropdown filters, the switches, or sorting. Only the free-text search changes.
- No change to `mods.json` or any published file.

## Decisions

**A new module, `site/search.js`.** Holds the term builder and the matcher, exported for both callers. Today the search functions sit in `views/browse.js` and `app.js` imports nothing from views; a shared module keeps that separation. `readSearch`, `searchableText` and `matchesSearch` in `browse.js` are replaced by it, not kept beside it.

**Terms are built once per mod and cached.** Like Starmodder 3, but keyed on the mod object in a `WeakMap` rather than on the name in a `Map` — two mods can share a name spelling, and the mod list is loaded once and reused, so object identity is stable.

**The acronym and word terms come from the display name.** Starmodder 3 slugifies `item.name`; here `modName(mod)` (displayName, falling back to name) is the honest name — the thread title carries "[0.98a]" and dates, whose acronym would be noise. The slugify step (lowercase, non-alphanumeric runs to "-") is ported as written; each word and the joined first letters become terms. The full thread title stays a term of its own, so old spellings still match.

**Match semantics are Starmodder 3's, exactly.** Split on commas; trim; lowercase; a leading "-" (with something after it) makes a term negative. A mod is listed when it matches any positive term and no negative term. All-negative queries subtract from the full list. This changes commas from "all of these" to "any of these" — that is the point of the change, and the hint text is rewritten to say it: e.g. "Commas mean any of these: "faction, portrait" shows both kinds. A minus leaves mods out: "faction, -portrait"."

**Suggestions rank name first, then everything else.** `matchStrength` becomes: name starts with the text (3), name contains it (2), any other term contains it (1). That folds the old author rank into the general term rank and adds acronyms, versions and categories to what can suggest a mod. Suggestion behaviour otherwise unchanged (5 mods, people list, 2-character minimum).

**The suggestion box treats the typed text as one term.** No comma splitting there — it suggests as you type, and "faction, por" mid-thought would suggest nothing useful. Enter still hands the whole text to Browse, which applies the full comma rules. This matches what happens today.

## Risks / Trade-offs

- **"Any of these" surprises someone who used commas to narrow.** → The hint under the box states the new meaning with an example, and single-term searches — the overwhelmingly common case — behave exactly as before.
- **Short acronyms match by substring, so "swp" also matches anything with "swp" inside a word.** → Same behaviour as Starmodder 3; substring matching over short terms is the accepted cost of finding acronyms at all.
- **No JS test runner in this repo, so the matcher has no unit tests.** → Keep `search.js` free of DOM so it could be tested later; verify against `?data=sample` and the real data through `dart run bin/site_server.dart`.
- **Per-fact matching can drop a match someone relied on** (a phrase spanning summary into category). → Vanishingly unlikely to be deliberate; per-fact is the more honest behaviour and is what Starmodder 3 ships.

## Migration Plan

Nothing to migrate. The site is static; the change ships with the next build. Rollback is reverting the commit.

## Open Questions

None.
