## 1. URL Normalizer and Archive Helpers

- [x] 1.1 Create `lib/bot/scraper/qb/url_normalizer.dart` — normalizeDownloadUrl() for Google Drive (/file/d/{id} → uc?export=download), Dropbox (dl=0→dl=1), OneDrive (download=1), GitHub blob→raw; isUnsupportedAutoDownloadHost() for mega.nz
- [x] 1.2 Create `lib/bot/scraper/qb/archive_helpers.dart` — hasSupportedArchiveExtension() (.zip/.rar/.7z/.tar.gz/.tar/.bz2/.gz/.xz), getArchiveBaseName()

## 2. Download Resolver Core

- [x] 2.1 Create `lib/bot/scraper/qb/download_resolver.dart` — `QbDownloadResolver` class with public API: resolveForTopic(), getCachedCandidates(), hasCachedCandidates(), getAllCandidates(), importCandidates()
- [x] 2.2 Implement URL shortener following — manual redirect via 3xx Location header for tinyurl, bit.ly, t.co, goo.gl, ow.ly, is.gd, buff.ly, rebrand.ly
- [x] 2.3 Implement GitHub resolution — direct asset regex (high confidence) + releases API call to find archive asset + fallback low confidence

## 3. Provider-Specific Resolvers

- [x] 3.1 Implement Google Drive resolution — normalize URL, probe filename from Content-Disposition header, HTML title/og:title, JSON title extraction
- [x] 3.2 Implement Dropbox (normalize dl, extract filename), OneDrive (normalize download param), Bitbucket (/downloads/ path, high confidence)
- [x] 3.3 Implement MediaFire — fetch page HTML, extract CDN URL via 3 regex patterns (plain, JSON-escaped, href attribute)
- [x] 3.4 Implement Patreon — low confidence, requiresManualStep=true

## 4. Post-Processing

- [x] 4.1 Implement archive filename extraction from URL path and link text (link text priority)
- [x] 4.2 Implement alternate download filename inference and Google Drive sibling filename inference
- [x] 4.3 Implement dedup by resolved URL (normalized, path-only, case-insensitive) then by archive filename
- [x] 4.4 Implement non-archive file filtering (.ogg, .mp3, .png, .jpg, .pdf, .txt, .jar, .exe, etc.)

## 5. Caching

- [x] 5.1 Implement fingerprint computation — sorted normalized link URLs joined by separator
- [x] 5.2 Implement in-memory cache with fingerprint-based invalidation and schema versioning
- [x] 5.3 Implement disk persistence to {dataPath}/assumed-downloads-cache.json
- [x] 5.4 Implement bundle import with sentinel fingerprint "bundle"

## 6. Verify

- [x] 6.1 Run `dart analyze` to verify no errors
- [x] 6.2 Smoke test: resolve downloads for a topic with known GitHub releases link, verify candidates are produced
