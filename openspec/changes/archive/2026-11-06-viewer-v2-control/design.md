## Context

The frame from `viewer-v2-shell` gives every page a toolbar with an actions area, a central panel and folding side panels. The old viewer spreads the Control page's work over Home (quick jobs, last run, health numbers), Runs (start a job, queue, history) and the run page (record, live log, Stop, Run again). The requirements combine the shared features on one page.

"Run LLM: All" has no server support. The LLM catch-up pass (`ScraperService._llmCoveragePass` and `_discordCoverage`) asks `PostExtractor.extractFor` about each post, and the extractor skips any post whose saved answer has the same fingerprint and prompt version. The per-run call limit (`llm_max_topics`) caps how many calls a run makes. Saved answers (`LlmStoreEntry`) record no time.

## Goals / Non-Goals

**Goals:**
- The Control page as the requirements describe it, minus Pending changes.
- "Run LLM: All" that works with the call limit: a capped run must not re-read the same posts every time.
- One read-only route for the Needs attention counts.

**Non-Goals:**
- The Pending changes panel (comes with the corrections pages).
- The Run history page and the run page (next change). Links to a run go to `#/runs/<id>`, which is still a placeholder linking to the old run page.
- The What changed page. The "What it changed" tab links to the old viewer's Details diff until that page is built.
- Browser notifications when a run ends.

## Decisions

### "All" re-reads by age, oldest first
`JobRequest.llmRereadAll` (bool, default false) applies to `llmCoveragePass`. When set, the job takes its start time as a cut-off. The extractor treats a saved answer made before the cut-off (or with no time) as out of date, the same as a changed post. The pass processes forum topics and Discord threads as one list, ordered by answer time, with posts that have no time first. Walking forum topics first would not work: once every topic had been read, each new "All" run would start on the forum topics again, since they are all older than its start, and Discord threads would only get the calls left over.

So when the call limit stops a run, the posts it read now have the newest answers. The next "All" run starts with the posts it did not reach. Repeated runs cycle through every post without any saved state about where the last run stopped.

Alternatives: dropping every saved answer first (a capped run would leave most posts with no answer at all, and the site would lose their facts until they are read again); a "re-read before" date chosen in the browser (more to explain, and the age order gives the same result).

The fingerprint-move step (moving a saved answer to a new fingerprint without a call) is skipped for answers older than the cut-off, or "All" would not re-read them.

### Answer time
`LlmStoreEntry.answeredAt` (DateTime, UTC, written as ISO 8601) is set on every new answer. Entries saved before have none and read as null. A moved fingerprint keeps the answer's time. Nothing published reads it.

### Attention counts come from one route
`GET /api/attention` (`lib/viewer/attention.dart`) returns:
- `unmatchedDependencyNames`: spellings in `requirement-names-report.json` that matched no mod.
- `authorPairsToDecide`: suggested pairs from the same report the Author aliases page uses, minus pairs marked "different people".
- `takedownsExcludedNothing` and `takedownsReturned`: from `takedown-matches.json`.
- `postsWithoutLlmAnswer`: saved forum topics (not placeholders) plus saved Discord threads with no answer in `llm-extraction-cache.json`.
- `modsWithoutDownload`: mods in `outputs/site/mods.json` with no `bestDownload`.

A count whose file is missing is left out, so the page shows nothing for it. The route only reads. The last run's errors come from the run record the page already has.

Alternative: the browser requests data from each page's route and counts it. That sends five large responses to the browser for five numbers. The topics count also needs a paged query per filter.

### Job requests and sentences in one module
`web2/jobs.js` builds every request the page sends and the sentence each confirm dialog shows. It has no DOM, so Node tests it. The sentences start from the old viewer's `describeJob`, reworded where the new choices need it. The old module is not imported; `web/` is deleted later.

### Drop-downs are panels under the toolbar
A job button with options is a split button: the main part starts the job with the options shown, the arrow opens a panel under the toolbar with the options. The choices last for the visit and are not saved. "Fetch and update" keeps today's defaults: new and changed topics, all three boards, Discord on, Nexus off, LLM on. "Run LLM" defaults to "Only changed". The button reads "Run LLM · All" while "All" is picked, so the choice is never hidden.

### The run panel keeps its log
The live log follows the old run page's rules: it is built once, only the lines that fell off the top are removed and new ones appended, and the reader's distance from the bottom is kept. The panel polls the run's record and log tail with each status update while a run is live. Polling stops when the user leaves the page.

## Risks / Trade-offs

- [An "All" run with a high call limit can cost money] → The confirm dialog says how many posts it may read and that LLM calls may cost money. The call limit still applies.
- [Answers saved before `answeredAt` existed all count as oldest] → They are re-read first, in index order, which is what "All" is for.
- [`/api/attention` reads several files on each ask] → The page asks once on load and again when a run ends, not on a timer.

## Migration Plan

`answeredAt` is optional, so old cache files read as before. The new request field defaults to false, so saved run records and the CLI behave as today.
