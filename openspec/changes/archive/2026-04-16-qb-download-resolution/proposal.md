## Why

The QBMBAMM scraper resolves direct download URLs from links found in forum topic first posts. This enables one-click mod installation by mapping hosting-provider pages (GitHub releases, Google Drive, MediaFire, etc.) to actual downloadable file URLs. This is part 2 of 3 in the QBMBAMM port — it builds on the core scraping from `qb-forum-scraping` and feeds into the bundle assembly in `qb-bundle-publishing`.

## What Changes

- Add URL normalizer for hosting providers (Google Drive, Dropbox, OneDrive, GitHub blob→raw)
- Add archive file extension helpers
- Add download resolver with host-specific logic for: GitHub (direct assets + releases API), Google Drive (URL normalization + filename probing), Dropbox, MediaFire (CDN URL extraction from page HTML), OneDrive, Bitbucket, Patreon, and URL shorteners
- Add post-resolution deduplication (by resolved URL and by archive filename)
- Add archive filename extraction from URLs, link text, HTTP headers, and HTML metadata
- Add fingerprint-based resolution cache with disk persistence and schema versioning

## Capabilities

### New Capabilities

- `qb-download-resolution`: Resolve direct download URLs from external hosting providers, extract filenames, deduplicate candidates, cache results with fingerprint-based invalidation

### Modified Capabilities

(none)

## Impact

- **New files**: 3 Dart files under `lib/bot/scraper/qb/` (`download_resolver.dart`, `url_normalizer.dart`, `archive_helpers.dart`)
- **Dependencies**: No new pub dependencies — uses existing `http` package
- **Disk**: Creates `qb_data/assumed-downloads-cache.json`
- **Network**: HTTP requests to GitHub API, MediaFire pages, Google Drive, URL shortener redirects; mitigated by caching
- **Depends on**: `qb-forum-scraping` (uses `LinkRef` model, `ForumConstants.isForumHosted()`)
