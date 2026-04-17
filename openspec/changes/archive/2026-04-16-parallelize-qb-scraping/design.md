## Context

The QB scraper fetches topic details from the Starsector forum and resolves download links from external hosts (GitHub, Google Drive, MediaFire, etc.). Currently, everything flows through a single `ThrottledClient` with a 1500ms inter-request delay. This means requests to GitHub API, Google Drive, and MediaFire each wait 1500ms — even though the throttle exists solely to protect the forum. A topic with 5 external links adds 7.5 seconds of unnecessary waiting. Over 500 topics this compounds to significant wasted time.

The topic loop is also strictly sequential: fetch → parse → save → resolve downloads → next topic. Parsing, saving, and download resolution could overlap with the throttle delay for the next forum fetch.

## Goals / Non-Goals

**Goals:**
- Eliminate unnecessary throttle delays on non-forum HTTP requests
- Pipeline the topic loop so non-forum work overlaps with the forum throttle wait
- Resolve download links for a single topic concurrently
- Maintain the same forum request rate (one request per ~1500ms)
- Preserve existing error handling semantics (a failed topic doesn't block the run)

**Non-Goals:**
- Increasing the forum request rate or adding multiple concurrent forum requests
- Changing the board scraping phase (already fast enough, few pages)
- Adding retry logic or circuit breakers
- Changing data models or output format

## Decisions

### Decision 1: Separate throttled and unthrottled HTTP clients

**Choice**: Create a second, unthrottled `http.Client` (with a reasonable timeout) for non-forum requests. The existing `ThrottledClient` continues to serve forum requests exclusively.

**Alternative considered**: Add host-based throttle exceptions to `ThrottledClient`. Rejected because it mixes concerns — the throttled client's job is forum rate-limiting, not host routing.

**Implementation**: `QbDownloadResolver` accepts an `http.Client` (unthrottled) instead of `ThrottledClient`. The `ThrottledClient` class is unchanged. The engine wires the two clients at construction.

### Decision 2: Concurrent link resolution within a topic

**Choice**: Use `Future.wait()` to resolve all external links for a topic concurrently, with an optional concurrency cap via a semaphore if needed.

**Alternative considered**: Stream-based processing with `StreamController`. Rejected as over-engineered for 5-15 links per topic.

**Implementation**: In `resolveForTopic()`, replace the sequential `for` loop with `Future.wait(externalLinks.map(_resolveLink))`.

### Decision 3: Pipelined topic loop

**Choice**: After fetching a topic from the forum, kick off parsing + saving + download resolution as a fire-and-forget `Future`, then immediately start the throttle wait for the next forum request. Use a small bounded queue (size 2-3) to avoid unbounded memory growth.

**Alternative considered**: Full producer-consumer with `StreamController`. Rejected — the throttle delay is the natural backpressure mechanism, so a simple futures-based approach suffices.

**Implementation**: The topic loop becomes:
1. `await topicScraper.scrapeTopic(id)` — forum fetch (throttled)
2. Start `_processAndResolve(detail)` as a `Future` (not awaited immediately)
3. Track pending futures in a bounded list; if full, `await` the oldest one before fetching the next topic
4. After the loop, `await Future.wait(pendingFutures)` to drain remaining work

This ensures at most N topics are being processed concurrently while forum requests remain sequential.

### Decision 4: Index bookkeeping stays synchronous

**Choice**: The `indexMap` updates and meaningful-change tracking happen after each topic's processing future completes, not during. The bounded queue ensures ordering is mostly preserved, but final index save happens after all futures complete.

**Alternative considered**: Lock-free concurrent map. Rejected — unnecessary complexity for a small bounded queue.

## Risks / Trade-offs

- **[Shared state in download resolver cache]** → The `_cache` map in `QbDownloadResolver` is written to from concurrent futures. Mitigation: Dart is single-threaded (event loop), so map writes are atomic within a single isolate. No actual race condition exists.

- **[Error reporting ordering]** → With pipelining, error logs may appear out of order relative to the topic being fetched. Mitigation: Each log message includes the topic ID, so ordering is traceable. Acceptable trade-off.

- **[External host rate limits]** → Concurrent link resolution could hit GitHub API rate limits faster. Mitigation: GitHub allows 60 requests/hour unauthenticated. A typical scrape has <60 GitHub releases pages. If needed, add a GitHub-specific semaphore later.

- **[Memory usage]** → Bounded queue of 2-3 in-flight topic details. Each detail is ~10-50KB. Total additional memory: <150KB. Negligible.
