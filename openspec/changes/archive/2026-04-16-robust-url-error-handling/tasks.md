## 1. QB Download Resolver — Safe URL Decode

- [x] 1.1 Add `_tryDecodeFull(String encoded)` helper to `QbDownloadResolver` in `download_resolver.dart` that wraps `Uri.decodeFull` in try-catch, returns `null` on error, logs warning
- [x] 1.2 Replace `Uri.decodeFull` at line ~701 in `_extractFilenameFromUrl` with `_tryDecodeFull`
- [x] 1.3 Replace `Uri.decodeFull` at line ~551 in `_resolveDropbox` with `_tryDecodeFull`
- [x] 1.4 Replace `Uri.decodeFull` at line ~506 in `_extractContentDispositionFilename` with `_tryDecodeFull`

## 2. QB Download Resolver — Per-URL Isolation

- [x] 2.1 In `resolveForTopic` (~line 200), wrap each `_resolveLink` call inside `Future.wait` with try-catch so one URL failure doesn't crash all URL resolution for the topic

## 3. QB Scraper Engine — Per-Topic Isolation

- [x] 3.1 Wrap `_processTopicDetail` future creation (~line 249-260) in try-catch so one topic error doesn't break the pipelined loop
- [x] 3.2 Replace `Future.wait(pending)` (~line 268) with error-tolerant draining (e.g., catch per-future or use `Future.wait` with `eagerError: false` + individual error handling)

## 4. QB Mod Index Scraper — Per-Post Isolation

- [x] 4.1 In the category extraction loop (~line 54-79), wrap `_extractTopicCategoriesFromPost` call in try-catch, log warning with post index, and continue to next post

## 5. Testing

- [x] 5.1 Add test for `_resolveBitbucket` with malformed URL (`%252.2.7`) — should return candidate with `archiveFilename == null`, not throw
- [x] 5.2 Add test for `_resolveBitbucket` with valid percent-encoded URL — should still extract filename correctly
