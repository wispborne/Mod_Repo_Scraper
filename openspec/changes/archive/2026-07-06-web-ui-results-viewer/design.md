# Design: Web UI Results Viewer

## Context

The scraper is a run-and-exit CLI. Its results live in files on disk:

| File | Size (typical) | Contents |
|------|------|----------|
| `outputs/ModRepo.json` | 1.3 MB | Merged mod list (forum + Discord + Nexus) |
| `outputs/forum-data-bundle.json` | 13 MB | QB bundle: index + details + assumed downloads |
| `new_data/mods-index.json` | ~1 MB | QB topic index (~900 topics), a JSON array |
| `new_data/mods/<id>/detail.json` | ×~900 | Per-topic post HTML, images, links, author info |
| `new_data/llm-extraction-cache.json` | 1 MB | LLM extraction per topic, map keyed by topic id |
| `new_data/llm-test-output.json` | small | LLM test-mode inspection report |
| `new_data/assumed-downloads-cache.json` | 0.5 MB | Rule-based download guesses, map keyed by topic id |
| `merge-debug.json` (new, repo root) | ~2 MB | Merge debug data (replaces `MergeDebug.html`) |
| `ModRepo.log` (repo root) | ~1 MB | Run log |

Today the only inspection tools are raw JSON files and a generated static
`MergeDebug.html` (2.5 MB). The immediate pain is verifying LLM post
extraction against the original forum posts. TriOS is the downstream consumer
of the published outputs.

## Goals / Non-Goals

**Goals:**
- One local web page where every result file can be browsed and searched.
- Fast verification loops: filter to suspicious topics, open one, compare the
  rendered forum post against what the rules and the LLM extracted.
- Replace `MergeDebug.html` with a searchable equivalent, without losing any
  of the collected merge data.
- Zero frontend toolchain: open-in-editor HTML/JS/CSS files served as-is.
- Detailed enough that implementation requires no further design decisions.

**Non-Goals:**
- Starting or stopping scraper runs from the UI.
- Editing `config.properties` or any scraper data from the UI.
- Serving anyone but the local user (no auth, binds to `127.0.0.1`).
- Real-time updates while a scrape is running (refresh the page instead).

## Decisions

### D1: Small Dart `shelf` server, scraper stays a separate process

A browser page cannot read local files, and the data is too big to ship
whole, so a server is required. Dart is chosen because the server can reuse
the existing `dart_mappable` models to parse the scraper's own files — no
second schema definition. The server is a new entry point
(`bin/viewer_server.dart`) and never imports scraper *run* logic; it only
reads output files. Alternatives considered: a static file server plus
client-side search (rejected: browser would need the 13 MB bundle and ~900
detail files), a Node/Vite app (rejected: second toolchain, duplicate
schemas).

### D2: Paths and port come from command-line flags, never from config

The server does not read `config.properties` (see D7), so it cannot learn
`qb_data_path` from there. Instead it takes flags with defaults that match
the current setup:

```
dart run bin/viewer_server.dart
  --port 8085            # default 8085
  --data-dir new_data    # QB data dir: mods-index.json, mods/, the caches
  --outputs-dir outputs  # ModRepo.json, forum-data-bundle.json
  --root-dir .           # merge-debug.json, ModRepo.log
```

Use `package:args`. If a directory or file is missing, endpoints answer with
the "not on disk" envelope (see API contract) rather than crashing.

### D3: Plain HTML/JS frontend, server-side search

Frontend is hand-written HTML/CSS/JS in `web/`, served by `shelf_static`. No
framework, no bundler, no npm. One `index.html` shell with a nav bar; each
view is a JS module that renders into the main area, switched by URL hash
(`#/topics`, `#/topics/10046`, `#/llm-test`, `#/merge`, `#/modrepo`,
`#/bundle`, `#/files`, `#/log`). All list endpoints support query parameters
for text search, filters, sorting, and pagination, and return only the page
of rows the UI shows. The browser holds at most one topic's full detail at a
time.

### D4: Read files fresh, with an mtime-based cache

Handlers read from disk per request but keep a parsed copy in memory keyed by
the file's last-modified time: on each request, `stat` the file; if mtime is
unchanged, use the cached parse, otherwise re-read. This makes repeated
searches cheap while a new scraper run shows up on the next request without
restarting the server. Applies to: `mods-index.json`, both caches,
`ModRepo.json`, `forum-data-bundle.json`, `merge-debug.json`. Per-topic
`detail.json` files are read on demand, uncached — except the
placeholder-detail scan below.

**Placeholder-detail scan:** the `isPlaceholderDetail` flag lives inside each
`detail.json`, not in the index. To power the list filter without opening 900
files per request, the server builds a `Set<int>` of placeholder topic ids by
reading every `mods/<id>/detail.json` once, cached and invalidated when the
`mods/` directory's own mtime changes (directory mtime changes when entries
are added/removed; a full rescan is also triggered if `mods-index.json`
mtime changes, which every scraper run rewrites).

### D5: Merge debug becomes JSON written by the scraper

`MergeDebugCollector` already gathers everything the HTML page shows. The
classes in `merge_debug_data.dart` are plain Dart with no serialization, so
they get `@MappableClass()` annotations (the project's existing convention)
and generated mappers via `dart run build_runner build`. The scraper then
writes `MergeDebugData` as `merge-debug.json` in the repo root (same place
`MergeDebug.html` went); `merge_debug_html_generator.dart` is deleted and its
call site in `main_repo_scraper.dart` switches to the JSON write. The config
key is renamed `generate_merge_debug`; the old `generate_debug_html` key
keeps working as an alias so existing config files don't silently lose the
feature. Rationale: the collector is the valuable part; rendering belongs in
the viewer where it can be searched. Alternative considered: viewer
re-derives merge decisions from inputs (rejected: duplicates merger logic and
can drift from what actually ran).

### D6: Quality filters computed server-side from joined sources

The topic list is built by joining, per topic: the index row
(`mods-index.json`), the LLM cache entry, the assumed-downloads entry, and
the placeholder set from D4. **Join-key gotcha:** the index stores `topicId`
as an int; both cache files are maps keyed by the topic id as a *string*
(`"7958"`). Convert explicitly.

Exact filter definitions (field names as they exist on disk today):

| Filter | True when |
|--------|-----------|
| `noDownload` | The topic's assumed-downloads entry is absent or has empty `candidates`, AND its LLM cache entry is absent or has empty `downloads`. |
| `lowConfidenceOnly` | The union of assumed-download `candidates[].confidence` and LLM `downloads[].confidence` is non-empty and every value is `"low"`. |
| `llmOnlyDownloads` | The LLM entry has at least one `downloads[]` item whose `source` is exactly `"llm"`. |
| `placeholderDetail` | Topic id is in the placeholder set (`detail.json` has `isPlaceholderDetail: true`). |
| `missingGameVersion` | Index row `gameVersion` is null or empty/whitespace. |
| `wip` | Index row `isWip` is `true`. |
| `noLlmExtraction` | No entry for the topic in `llm-extraction-cache.json`. |

Text search matches case-insensitive substrings of index `title` and
`author`. Sortable columns: `title`, `author`, `lastPostDate`, `views`,
`replies`, `gameVersion`, `topicId` (default: `lastPostDate` descending).

### D7: Secrets never touch the server

The server never opens `config.properties`. The raw-file endpoints serve only
files from a fixed allowlist built from the D2 directories:
`mods-index.json`, `llm-extraction-cache.json`, `llm-test-output.json`,
`assumed-downloads-cache.json`, `ModRepo.json`, `forum-data-bundle.json`,
`merge-debug.json`, `ModRepo.log`. Requests name a file by its allowlist id,
never by path, so path traversal is impossible by construction. Per-topic
detail files are served only through `/api/topics/<id>`, where `<id>` must
parse as an int.

### D8: Post HTML rendered inside a sandboxed iframe

`contentHtml` is scraped, third-party HTML. The inspector renders it via
`<iframe sandbox srcdoc="...">` (the bare `sandbox` attribute: no scripts, no
same-origin) with a small stylesheet approximating forum styling (dark
background, styled `bbc_*` classes for links/tables/spoilers). This keeps the
viewer immune to odd or hostile markup while showing the post the way a human
would read it. Images load from their original remote URLs; broken images are
acceptable.

### D9: TriOS card preview is a fixed, labeled approximation

The card renders, from bundle data: thumbnail (`thumbnailPath`, stripping the
`ext:` prefix when present), `title`, `author`, `gameVersion` chip, `views` /
`replies`, first ~200 chars of the post's plain text, and one download button
per high/medium-confidence download. A visible "approximation — TriOS is the
source of truth" label is always shown. No attempt to copy TriOS pixel
styling; matching *which fields are shown* is the point.

## API contract

All endpoints return JSON. List endpoints share this envelope:

```json
{ "items": [...], "total": 123, "page": 0, "pageSize": 50 }
```

Missing-file responses use HTTP 200 with
`{ "missing": true, "file": "<allowlist id>", "hint": "<what run produces it>" }`
so the UI can show a friendly message (HTTP 404 is reserved for unknown
routes/ids). Common list params: `q` (search text), `sort`, `dir` (`asc` |
`desc`), `page` (0-based), `pageSize` (default 50, max 500).

| Endpoint | Params beyond common | Returns |
|----------|----------------------|---------|
| `GET /api/topics` | `filters` = comma-separated D6 filter names (ANDed) | Rows: index fields + computed booleans for every D6 filter + download counts (rules, llm-only) |
| `GET /api/topics/<id>` | — | `{ index, detail, assumedDownloads, llm }` — the full detail.json (incl. `contentHtml`, `images`, `links`), the assumed-downloads entry, the LLM cache entry; each null when absent |
| `GET /api/llm-test` | — | `llm-test-output.json` verbatim (`generatedAt`, `promptVersion`, `callCount`, `topics`) |
| `GET /api/merge/summary` | — | Summary + phase timings from `merge-debug.json` |
| `GET /api/merge/groups` | `q` matches any member mod name/author; `multiOnly` bool | Paged groups with members and match reasons |
| `GET /api/merge/groups/<id>` | — | One group with its merge decisions (field, winner, sources) |
| `GET /api/merge/removals` | `kind` = `preDedup` \| `sameSource` \| `validation` | Paged removal entries of that kind |
| `GET /api/modrepo` | — | Paged merged mods: name, authors, game version, urls, `sources` |
| `GET /api/modrepo/<index>` | — | One merged mod in full, incl. `sources` list |
| `GET /api/bundle/meta` | — | Bundle `updatedAt` + `meta` |
| `GET /api/bundle/mods` | — | Paged entries joined from bundle `index` (array) + `details` (map by id) + `assumedDownloads` (map by id) |
| `GET /api/files` | — | Allowlist: id, path, size bytes, mtime, exists |
| `GET /api/files/<id>` | `offset`, `length` (bytes, default 0 / 256 KiB) | `{ content, offset, length, totalSize, eof }` — raw text slice |
| `GET /api/log` | `q` filter, `tail` = last N lines (default 500) | Matching/tail lines of `ModRepo.log` |

The raw-file viewer pretty-prints client-side only when the whole file was
fetched and is under 5 MB; otherwise it shows plain text slices with
prev/next paging by `offset`. No server-side pretty-printing.

## Data shapes reference (as on disk today)

For the implementer — verified against real files:

- **`mods-index.json`**: array of index rows: `topicId` (int), `title`,
  `category`, `inModIndex`, `isArchivedModIndex`, `gameVersion`, `author`,
  `replies`, `views`, `createdDate`, `lastPostDate`, `lastPostBy`,
  `topicUrl`, `thumbnailPath` (may carry `ext:` prefix), `scrapedAt`,
  `isWip`, `sourceBoard`. Dart model already exists (dart_mappable).
- **`mods/<id>/detail.json`**: `topicId`, `title`, `gameVersion`, `author`,
  `authorTitle`, `authorPostCount`, `authorAvatarPath`, `postDate`,
  `lastEditDate`, `contentHtml`, `images[]` (`originalUrl`, `localPath`,
  `alt`), `links[]` (`url`, `text`, `isExternal`, `isDownloadable`),
  `scrapedAt`, `isPlaceholderDetail`.
- **`llm-extraction-cache.json`**: map, **string** topic id →
  `{ fingerprint, schemaVersion, promptVersion, downloads[], extras }`;
  `downloads[]`: `originalUrl`, `resolvedDirectUrl?`, `sourceHost`,
  `fileName?`, `confidence` (`high`/`medium`/`low`), `requiresManualStep`,
  `linkText`, `source` (`rules` / `llm` / `rules+llm`); `extras`:
  `changelog?` (`entries`: version → text map), `modVersion?`,
  `supportLinks?[]` (each `{ url, type }`, where `type` is worked out from the
  URL host: `patreon`, `kofi`, `paypal`, ... or `other`), `license?`.
- **`assumed-downloads-cache.json`**: map, **string** topic id →
  `{ fingerprint, schemaVersion, candidates[] }`; `candidates[]`:
  `sourceUrl`, `resolvedUrl`, `archiveFilename`, `confidence`,
  `requiresManualStep`, `linkText`.
- **`llm-test-output.json`**: `{ generatedAt, promptVersion, callCount,
  topics }`.
- **`forum-data-bundle.json`**: `{ updatedAt, meta, index (array),
  details (map by string id), assumedDownloads (map by string id) }`;
  `meta` has `generatedAt`, `totalMods`, `totalDetails`,
  `totalAssumedDownloadEntries`, `placeholderDetailCount`, plus run stats.
- **`ModRepo.json`**: `ScrapedMods` — `items[]` of `ScrapedMod`; each has
  `name`, `authorsList`, `urls`, `sources` (list of `ModSource` enum values:
  which scrapers contributed). **Note:** the merged entry does *not* retain
  per-source field values; only `merge-debug.json` has those.
- **`merge-debug.json`** (new): serialized `MergeDebugData` — see
  `merge_debug_data.dart`: `preDedupEntries`, `groups`
  (`DebugModGroup`: members + `GroupMatchEntry` match reasons),
  `sameSourceDedupEntries`, merge decisions (`MergeStepEntry` /
  `MergeDecision`), `validationRemovalEntries`, `finalOutput`, timings.
  Field names follow whatever dart_mappable generates from the existing
  class fields — do not rename fields while annotating.

## Risks / Trade-offs

- [13 MB bundle parse is slow on first request] → mtime cache (D4) makes it
  a one-time cost per scraper run; acceptable for a local tool.
- [Placeholder scan opens ~900 files] → once per data change, cached (D4);
  ~900 small local files parse in well under a second.
- [Sandboxed iframe styling won't match the forum exactly] → good enough for
  verification; readability, not pixel fidelity, is the goal.
- [TriOS card preview may drift from real TriOS rendering] → permanently
  labeled as an approximation (D9); TriOS is the source of truth.
- [Renaming `generate_debug_html` could silently disable debug output for an
  old config] → old key accepted as alias (D5).
- [Allowlist raw-file viewer means newly added output files need a one-line
  registration] → acceptable; the price of never serving arbitrary paths.
- [Annotating merge debug classes triggers build_runner codegen] → the
  project already depends on build_runner/dart_mappable; run it as part of
  the task.

## Open Questions

- None. Port, paths, filters, endpoints, and shapes are fixed above; any
  remaining choices (CSS colors, exact copy) are cosmetic.
