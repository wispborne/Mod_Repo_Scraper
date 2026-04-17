## Context

The QBMBAMM C# app includes `AssumedDownloadService.cs` (~880 lines) that resolves direct download URLs from hosting provider pages. This is the heaviest single file in the port. It depends on `UrlNormalizer.cs` and `ArchiveFileHelper.cs` from the server project.

**C# source files being ported:**
- `QBModsBrowser.Server/Services/AssumedDownloadService.cs` — main resolver
- `QBModsBrowser.Server/Services/UrlNormalizer.cs` — Google Drive, Dropbox, OneDrive, GitHub blob normalization
- `QBModsBrowser.Server/Services/ArchiveFileHelper.cs` — archive extension checks

This change depends on `qb-forum-scraping` for the `LinkRef` model and `ForumConstants`.

## Goals / Non-Goals

**Goals:**
- Resolve direct download URLs for GitHub, Google Drive, Dropbox, MediaFire, OneDrive, Bitbucket, Patreon
- Follow URL shortener redirects
- Extract archive filenames from URLs, link text, headers, and HTML metadata
- Deduplicate candidates by resolved URL and by filename
- Cache results with fingerprint-based invalidation and disk persistence

**Non-Goals:**
- Actually downloading mod archives
- Bundle assembly (that's `qb-bundle-publishing`)

## Decisions

### Port caching as-is
The C# fingerprint-based cache avoids redundant HTTP calls on incremental runs. The fingerprint (sorted normalized URLs of a topic's links) invalidates when link content changes. Schema versioning allows cache-busting when resolver logic changes. Worth porting for correctness and efficiency.

### Serial resolution instead of semaphore
The C# version uses `SemaphoreSlim(3)` for concurrency. In Dart, we'll resolve serially within a topic's link set — simpler and sufficient since the bottleneck is the throttled HTTP client, not CPU. Cross-topic resolution is already serialized by the engine's topic loop.

### Separate files for URL normalizer and archive helpers
These are small, reusable utilities that the bundle publisher may also reference. Keeping them in their own files follows the C# structure and avoids a 600+ line resolver file.

### File layout

```
lib/bot/scraper/qb/
  url_normalizer.dart       ← ~80 lines, Google Drive/Dropbox/OneDrive/GitHub normalization
  archive_helpers.dart      ← ~30 lines, extension checks + base name extraction
  download_resolver.dart    ← ~500 lines, main resolver + caching
```

## Risks / Trade-offs

**[Risk] GitHub API rate limiting** → 60 req/hr unauthenticated. Mitigated by caching; a full scrape hits ~400 topics but most don't have GitHub releases links.

**[Risk] MediaFire CDN URL patterns change** → The three regex patterns for extracting MediaFire CDN URLs are fragile. Same risk as C# version.

**[Trade-off] ~600 lines of new code** → The resolver is complex but maps 1:1 from well-tested C# code.
