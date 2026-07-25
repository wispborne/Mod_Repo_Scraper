## Context

The two output files live only in the local `outputs/` folder (both gitignored).
TriOS reads them from the public `wispborne/StarsectorModRepo` repo. Today the
only thing that pushes there is a twice-a-day cron script (`update-mod-repo.sh`)
running as user `david`, whose SSH key is allowed to push. It clones the target
repo shallow into `./StarsectorModRepo`, copies `outputs/*` in, commits if
anything changed, and pushes.

The manager core already runs work as jobs on one queue, behind one lock, with a
run history, a per-run log and a status chip — and two `JobRunner`s (`ScraperService`,
`ModRepoService`) sit behind a `JobRouter` that picks one by job kind. A publish
button fits this shape: a third runner for a new `publishOutputs` kind.

The publish job automates the tail of the cron script, on demand, from inside the
running server.

## Goals / Non-Goals

**Goals:**
- Publish the current `outputs/` files to the target repo from a browser button.
- Reuse the host's existing git/SSH auth — no new secret to store.
- Ride the existing queue, lock, history, log and chip like every other job.
- Report a git failure plainly in the run log; never claim success without pushing.

**Non-Goals:**
- No auto-publish after a scrape or merge (manual button only, for now).
- No change to the cron script; it keeps working as its own path to the same repo.
- No token-based GitHub API path; no force-push or history rewriting.
- No new push credentials or per-request repo/branch selection.

## Decisions

### A third `JobRunner`, routed by kind
Add `PublishService implements JobRunner` in `lib/manager/publish_service.dart`,
owning only `JobKind.publishOutputs`. Extend `JobRouter` with a third field
(`publish`) and route `publishOutputs` to it; merge kinds still go to `modRepo`,
everything else to `qb`. Add `publishOutputs` to `JobKind` and a plain label in
`jobKindLabel`.

*Why not fold it into `ModRepoService`?* The existing pattern keeps each pipeline
sharing "no code, no files and no secrets." Publishing touches a git clone, not
the merge's caches or outputs-writing, so a separate runner keeps that clean and
keeps the router readable.

### Shell out to `git`, reuse host SSH — not the GitHub API
The publish runs `git` as a subprocess against a local clone, exactly as the cron
script does. Auth is the host user's SSH key.

*Why over the GitHub REST API?* The API path would need a token stored somewhere
(a new secret to manage), and the 15.5 MB bundle is awkward for the simpler
Contents API. Shelling out to `git` reuses the auth the cron already relies on,
handles the large file without special cases, and keeps the code close to the
script the user already trusts. Trade-off: `git` must be installed and the service
user must have push access — true where cron runs.

### A persistent clone in its own folder
The clone lives at `publish_clone_dir` (config), **kept apart** from the cron
script's `./StarsectorModRepo`, which cron `rm -rf`s at the start of every run —
sharing that folder would let a cron run wipe the clone mid-publish. Prepare step:
if the folder has no clone, `git clone` it (shallow is fine); otherwise `git fetch`
and hard-reset to the remote's default branch, so a divergent or dirty local copy
never blocks a publish. The remote's default branch is read from `origin/HEAD`
rather than assumed to be `main` or `master`.

*Why persistent over clone-fresh-each-time (as cron does)?* The server publishes
far more often than twice a day and re-cloning a growing repo each time is wasteful;
fetch-and-reset is cheap and just as safe.

### "Nothing changed" is a clean, quiet success
After copying the two files and `git add`, run `git diff --cached --quiet`. If it
reports no change, finish the run as completed with a log line ("nothing to
publish") and push nothing — matching the cron script. Otherwise commit with a
fixed message and push.

### Environment-only config, no token
Two keys, both manager environment (read where the service is built, never served
to the browser): `publish_repo_url` (default the SSH URL of the target repo) and
`publish_clone_dir`. Held in a `PublishEnvironment` in `scraper_settings.dart`,
built at the server's `JobRouter` wiring. Added to `Common._recognizedKeys` and
documented in `config.example.properties`. No token key — auth is the host's git.

### Failure and cancellation
Every `git` step checks the subprocess exit code; a non-zero exit ends the run as
failed with the git stderr in the log (the server's `LogRunReporter` already
bridges log lines into the run's file). The service checks the cancel token before
commit and before push; a publish cancelled before the push pushes nothing and
says the target repo was left as it was. The prepared clone is always safe to
leave for the next publish.

### Frontend
A third card in `web/views/runs.js`'s start-a-job area ("Publish to GitHub"),
drawn only when the manager is on, using the existing `confirmAndSubmit` /
`describeJob` path so the confirm dialog reads in one plain sentence. `describeJob`
in `web/manager.js` learns the `publishOutputs` kind. No new endpoint — it posts to
`POST /api/manager/jobs` like every other job.

## Risks / Trade-offs

- **Service user lacks SSH push access** → the push fails; mitigation: the run is
  recorded as failed with the git error in its log (never a silent success), and
  `config.example.properties` notes the service must run as a user whose git can
  push (the cron user does).
- **Target repo history grows ~15 MB per publish** → accepted: it matches today's
  cron behavior, and the user expressed no preference. A future change could switch
  to a single rolling commit if size ever matters.
- **Cron restarts the service mid-publish** → the cron script `systemctl stop`s the
  service; a browser publish in flight would be killed and recorded as interrupted
  at next start. Rare and self-healing; not worth guarding beyond the lock.
- **`git` not installed** → the first `git` call fails with a clear error in the
  log, same path as any other git failure.

## Migration Plan

1. Add the `publish_*` keys (with defaults) to `config.properties` on the host and
   to `config.example.properties`.
2. Ensure the `starsector-scraper` service runs as a user whose git can push
   (`david`, matching cron).
3. Deploy; the card appears on the Runs view when the manager is on.

Rollback: remove the card and the keys; the cron script and every other job are
untouched.

## Open Questions

- None blocking. The default branch is detected from `origin/HEAD` rather than
  hardcoded, so `main` vs `master` needs no decision here.
