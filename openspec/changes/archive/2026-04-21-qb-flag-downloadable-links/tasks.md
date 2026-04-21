## 1. Shared heuristic helper (sync + async)

- [x] 1.1 Create `lib/bot/scraper/download_link_detector.dart` exposing:
  - `bool isLikelyModDownloadUrl(String url)` — synchronous, substring/host check, union of the current `DiscordReader._isDefiniteDownloadLink` rules (`.zip`, `.rar`, `.7z`, `drive.google.com`, `mega.nz`, `mediafire`).
  - `Future<bool> isDownloadableUrl(String url, {Duration timeout = const Duration(seconds: 10), http.Client? client})` — runs the sync check first; if `true`, returns `true` immediately without I/O. Otherwise issues a HEAD (falling back to GET and aborting after headers) and returns `true` iff `Content-Disposition` starts with `attachment` or `Content-Type` is in `{application/octet-stream, application/zip}` — same semantics as today's `Common.isDownloadable`. On any error or timeout, returns the sync heuristic's answer (i.e. `false` here).
- [x] 1.2 Unit-test `isLikelyModDownloadUrl`:
  - each extension case (`.zip`, `.rar`, `.7z`) → `true`
  - each known host (`drive.google.com`, `mega.nz`, `mediafire.com`) → `true`
  - non-download URLs (`imgur.com`, `youtube.com`, forum topic URL, nexus mod URL) → `false`
  - empty / malformed URL → `false`
- [x] 1.3 Unit-test `isDownloadableUrl` using a mock `http.Client`:
  - obvious `.zip` URL short-circuits and MUST NOT touch the client.
  - ambiguous URL with `Content-Disposition: attachment` → `true`.
  - ambiguous URL with `Content-Type: application/octet-stream` → `true`.
  - ambiguous URL with `Content-Type: text/html` → `false`.
  - timeout → `false`.
  - network error → `false`.
- [x] 1.4 Replace `DiscordReader._isDefiniteDownloadLink` body with a call to `isLikelyModDownloadUrl`; replace calls to `Common.isDownloadable` with `isDownloadableUrl`. Keep `Common.isDownloadable` as a thin deprecated shim that forwards to the new helper, or delete it and update imports — whichever keeps the diff smaller.
- [x] 1.5 Run the legacy scraper test suite to confirm no regression in Discord classification.

## 2. Extend `LinkRef`

- [x] 2.1 Add `final bool isDownloadable;` to `LinkRef` in [lib/bot/scraper/qb/models/mod_detail.dart](lib/bot/scraper/qb/models/mod_detail.dart) as the LAST field; give the constructor parameter a default of `false` and place it last in the parameter list. This keeps the `dart_mappable`-generated `toString` additive: the new field appears at the end after `url`, `text`, `isExternal`.
- [x] 2.2 Regenerate `lib/bot/scraper/qb/models/mod_detail.mapper.dart` via `dart run build_runner build --delete-conflicting-outputs`. Commit the regenerated file.
- [x] 2.3 Add a unit test that serializes a `LinkRef` with `isDownloadable = true` and deserializes it, asserting round-trip equality; and a second test that deserializes a JSON object missing the `isDownloadable` key and asserts it defaults to `false`.
- [x] 2.4 Add a unit test that `LinkRef(url: 'u', text: 't', isExternal: true, isDownloadable: true).toString()` contains `'url'`, `'text'`, `'isExternal'` in that order followed by `'isDownloadable'`, to lock the additive-field-order contract.
- [x] 2.5 Grep the codebase for any caller that pattern-matches or parses `LinkRef.toString()` output (none expected — it's debug format). Confirm none break. (Verified: no callers parse `LinkRef.toString()`; it's only used for logging/debug via `stringifyValue`.)

## 3. Populate the flag during QB scraping

- [x] 3.1 Leave [lib/bot/scraper/qb/topic_scraper.dart](lib/bot/scraper/qb/topic_scraper.dart) `_extractLinks` as-is (it stays sync; the constructed `LinkRef`s get `isDownloadable = false` by default).
- [x] 3.2 Add an async post-pass in `TopicScraper` (called by the same per-topic scrape future, after `_extractLinks` returns) that does:
  ```dart
  final results = await Future.wait(
    links.map((l) => isDownloadableUrl(l.url, client: _externalClient)),
  );
  return [
    for (var i = 0; i < links.length; i++)
      links[i].copyWith(isDownloadable: results[i]),
  ];
  ```
  Use an *unthrottled* external HTTP client (reuse whatever `QbDownloadResolver` uses so we share connection pooling / user-configured limits).
- [x] 3.3 Per-link probe timeout: 10s (configurable). On error or timeout, `isDownloadable` falls back to the sync heuristic's answer (per the helper's contract).
- [x] 3.4 Integration test: feed sample topic HTML with a mix of (a) archive-URL links, (b) file-hosting links, (c) ambiguous links where a mocked server responds with `Content-Disposition: attachment`, (d) ambiguous links with `Content-Type: text/html`, and (e) a link whose mock server hangs past the timeout. Assert `isDownloadable` is `true` for a/b/c and `false` for d/e.
- [x] 3.5 Confirm via the pipelined scraper's existing cache behavior that re-running against an already-populated bundle does NOT re-issue probes — the persisted `isDownloadable` values should be reused (no change to cache keys needed; the post-pass only runs when the topic is being freshly scraped). (Verified: `_classifyDownloadableLinks` is called inside `QbTopicScraper.scrapeTopic`, which the engine only invokes for topics that survive `_applyIncrementalFilter` at [scraper_engine.dart:498](lib/bot/scraper/qb/scraper_engine.dart:498). Unchanged topics keep their cached `QbModDetail` — including persisted `isDownloadable` — without any new probe.)

## 4. Verify the flag is visible in string form

- [x] 4.1 Unit test: `LinkRef(url: 'https://example.com/mod.zip', isDownloadable: true).toString()` contains `'isDownloadable: true'` (or the equivalent token `dart_mappable` emits). (Covered by `test/link_ref_test.dart`.)
- [x] 4.2 Unit test: the pre-existing fields `url`, `text`, `isExternal` still appear in the `toString()` output ahead of `isDownloadable`, with the same labels as before. (Covered by `test/link_ref_test.dart`.)

## 5. Verification

- [x] 5.1 Run the full Dart test suite: `dart test`. All tests pass. (135/135 passing.)
- [ ] 5.2 Manually run the QB scraper against at least one real forum topic known to contain both archive-file links and supporting non-download links (including at least one link that only the async probe can classify — e.g. a direct CDN URL without a familiar extension). Inspect the resulting bundle JSON and confirm `isDownloadable` values are correct on each `LinkRef`, and that wall-clock time for the scrape did not regress by more than ~(avg external-link count) × (probe latency) per topic.
- [ ] 5.3 Load a pre-existing cached bundle (from before this change) and confirm it deserializes with every `LinkRef.isDownloadable == false`, and that re-saving upgrades the file to include the new key.
- [x] 5.4 Update [openspec/specs/qb-download-resolution/spec.md](openspec/specs/qb-download-resolution/spec.md) only via `openspec archive` when the change is accepted — do not hand-edit during implementation. (Not touched during this session.)
