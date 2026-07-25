## 1. Job kind and config

- [x] 1.1 Add `publishOutputs` to `JobKind` in `lib/manager/job.dart`, with a doc line, and a `JobRequest.publishOutputs()` factory. Regenerate `job.mapper.dart` with build_runner.
- [x] 1.2 Add a plain-English label for `publishOutputs` in `jobKindLabel` (`lib/manager/modrepo_service.dart`).
- [x] 1.3 Add `publishRepoUrl` and `publishCloneDir` fields to `BotConfig` (`lib/bot/common.dart`), read them in `readConfig`, and add `publish_repo_url` / `publish_clone_dir` to `Common._recognizedKeys` with sensible defaults (target SSH URL; a clone folder apart from the cron script's `./StarsectorModRepo`).
- [x] 1.4 Document the two `publish_*` keys in `config.example.properties` with defaults and a plain-English note (no token; needs a git/SSH-capable service user).

## 2. Publish service

- [x] 2.1 Add `PublishEnvironment` to `lib/manager/scraper_settings.dart` (repo URL + clone dir) with a `fromConfig` factory. Environment only; no token.
- [x] 2.2 Create `lib/manager/publish_service.dart` with `PublishService implements JobRunner`, handling only `JobKind.publishOutputs` and throwing for any other kind.
- [x] 2.3 Implement the prepare-clone step: clone into the clone dir if absent; otherwise fetch and hard-reset to the remote default branch (read from `origin/HEAD`, not hardcoded). Report the phase and log each git step.
- [x] 2.4 Implement copy + stage + change check: copy `ModRepo.json` and `forum-data-bundle.json` from the outputs folder into the clone, `git add`, and `git diff --cached --quiet`. On no change, finish completed with a "nothing to publish" log line and push nothing.
- [x] 2.5 Implement commit + push on change, with a fixed commit message and a plain commit (no force). Check the cancel token before commit and before push; a publish cancelled before the push returns cancelled and logs that the target repo was left as it was.
- [x] 2.6 On any non-zero git exit, end the run failed with the git stderr in the log; never return success without having pushed the changed files.

## 3. Wiring

- [x] 3.1 Add a `publish` field to `JobRouter` (`lib/manager/modrepo_service.dart`) and route `publishOutputs` to it.
- [x] 3.2 Build `PublishService` and pass it to `JobRouter` in `bin/viewer_server.dart`, using `PublishEnvironment.fromConfig` and the viewer's outputs folder.

## 4. Frontend

- [x] 4.1 Teach `describeJob` in `web/manager.js` about `publishOutputs` (one plain sentence for the confirm dialog).
- [x] 4.2 Add a "Publish to GitHub" card to the start-a-job area in `web/views/runs.js`, drawn only when the manager is on, submitting `publishOutputs` via `confirmAndSubmit`.

## 5. Tests

- [x] 5.1 Publish service test: with a throwaway local bare repo as the remote, a changed output produces exactly one commit and a push; assert the pushed files match.
- [x] 5.2 "Nothing changed" test: a second publish with identical outputs makes no commit and returns completed.
- [x] 5.3 Failure test: an unreachable/​unwritable remote ends the run failed with the git error captured, and nothing claims success.
- [x] 5.4 Cancellation test: a cancel before the push pushes nothing and returns cancelled.
- [x] 5.5 Router test: `publishOutputs` reaches the publish runner and not the QB or ModRepo one.
- [x] 5.6 Config test: `publish_*` keys load into `BotConfig`; a misspelled key warns; absent keys use defaults.

## 6. Verify

- [x] 6.1 `dart test` passes; check the changed files with the IDE problems tool (the CLI analyzer crashes on shutdown).
- [ ] 6.2 Manual smoke: start the server, click "Publish to GitHub" against a scratch clone dir, confirm the commit lands and a re-click reports "nothing to publish".
