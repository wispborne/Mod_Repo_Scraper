## Why

The two output files (`ModRepo.json`, `forum-data-bundle.json`) are only useful to
TriOS once they land in the public `wispborne/StarsectorModRepo` repo. Today that
push only happens from a twice-a-day cron script on the host. There is no way to
publish on demand — after a scrape or merge started from the browser, the fresh
output just sits in `outputs/` until the next cron run. A publish button on the
web page closes that gap.

## What Changes

- A new **`publishOutputs` job kind**: copies `outputs/ModRepo.json` and
  `outputs/forum-data-bundle.json` into a local clone of the target repo, commits
  only if something changed, and pushes over the host's existing git SSH auth.
- The publish job rides the **same queue, lock, run history, per-run log and
  status chip** as every other job — a third `JobRunner` beside the QB and
  ModRepo services, wired through the same `JobRouter`.
- A **`publish_*` config group** (environment only): the target repo URL and the
  folder to keep the clone in. No token — auth stays with the host's git/SSH,
  exactly as the cron script relies on. None of these values are ever served to
  the browser.
- The **Runs view gains a third card** ("Publish to GitHub") beside the scrape and
  merge cards, with the usual in-page confirm dialog, hidden when the manager is
  off.
- Normal git history is kept (plain commit + push, no force). A publish with
  nothing changed finishes cleanly as "nothing to publish" and pushes nothing.
- Manual button only for now — no auto-publish after a run.

## Capabilities

### New Capabilities
- `output-publishing`: publishing the current `outputs/` files to the target
  GitHub repo as a manager job — the job kind, its clone/copy/commit/push steps,
  the "nothing changed" case, cancellation, and how failures are reported.

### Modified Capabilities
- `scraper-configuration`: adds the `publish_*` config keys (repo URL, clone
  folder) as manager environment, recognised at startup like the other keys.
- `runs-page`: adds the "Publish to GitHub" card to the start-a-job area, subject
  to the same manager-on/off rules as the existing cards.

## Impact

- **New code**: a publish service (`lib/manager/publish_service.dart`), a
  `publishOutputs` entry in `JobKind`, `JobRouter` wiring, `PublishEnvironment`
  in `scraper_settings.dart`, and a Runs-view card in `web/views/runs.js`.
- **Config**: `config.properties` / `config.example.properties` gain the
  `publish_*` keys; `Common._recognizedKeys` learns them.
- **External dependency**: the host must have `git` and an SSH key allowed to push
  to the target repo (already true where cron runs). The service must run as a
  user with that access; a push failure is surfaced as a plain error in the run's
  log, never a silent no-op.
- **No breaking changes**: existing job kinds, outputs and the cron script are
  untouched; the button is an additional path to the same result.
