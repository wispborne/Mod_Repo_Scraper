## Why

The QB scraper processes topics strictly sequentially: fetch topic HTML, parse it, write to disk, resolve download links, then move to the next topic. The 1500ms inter-request throttle to the forum is necessary and must stay, but significant wall-clock time is wasted waiting on non-forum work (download link resolution, disk I/O, HTML parsing) that could overlap with the forum throttle delay. For a typical scrape of ~500 topics, download resolution alone adds minutes of sequential waiting on external hosts (GitHub API, Google Drive, MediaFire) that are completely independent of forum load.

## What Changes

- **Pipeline the topic loop**: After fetching a topic from the forum, hand off parsing, disk writes, and download resolution to run concurrently while the throttle delay counts down for the next forum request. The forum request rate stays identical (one request per 1500ms), but non-forum work hides behind the wait.
- **Parallelize download resolution within a topic**: Resolve all external links for a single topic concurrently instead of sequentially. These hit different external hosts (GitHub, Google Drive, MediaFire, etc.) and do not touch the forum.
- **Batch disk writes**: Collect detail results in memory and flush to disk in batches, reducing per-topic I/O overhead.

## Capabilities

### New Capabilities
- `qb-pipelined-scraping`: Orchestration of the topic scrape loop as a pipeline where forum fetches, parsing, download resolution, and persistence run as overlapping stages, maintaining the existing forum request rate.

### Modified Capabilities
- `qb-download-resolution`: Download links within a single topic are resolved concurrently instead of sequentially. No change to resolution logic, only to execution model.

## Impact

- **Code**: `scraper_engine.dart` (topic loop restructured), `download_resolver.dart` (concurrent link resolution), `throttled_client.dart` (unchanged — still enforces per-request delay)
- **Dependencies**: No new packages. Uses Dart's built-in `Future.wait` and `Completer`/`Stream` APIs.
- **Risk**: Low. Forum request rate is unchanged. External host concurrency is bounded per-topic (typically 5-15 links). Failure handling per-topic remains the same — a failed download resolution doesn't block the next forum fetch.
- **Expected speedup**: 2-4x wall-clock reduction depending on topic count and link density, with zero increase in forum request rate.
