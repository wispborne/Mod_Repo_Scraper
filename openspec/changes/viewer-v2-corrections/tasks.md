## 1. The job (server)

- [x] 1.1 `Correction` model and `JobRequest.corrections`, new `JobKind.saveCorrections`; regenerate mappers
- [x] 1.2 `lib/manager/corrections_service.dart`: apply in memory, check with the existing rules, write only changed files, all or nothing
- [x] 1.3 `JobRouter`: run it with one merge, one rebuild and an optional publish
- [x] 1.4 Tests: each kind, several kinds at once, no writes if any correction is refused, one rebuild, publish only when asked

## 2. Pending changes (web2)

- [x] 2.1 `web2/pending.js` (no DOM): the list in `sessionStorage`, add, remove, clear, change events; Node tests
- [x] 2.2 The toolbar count opens the list; remove, Publish afterwards, Save all, Discard all
- [x] 2.3 Save all: the confirmation dialog, one `saveCorrections` job, the server's message on refusal
- [x] 2.4 A Pending changes side panel for any page; shown on Control while not empty; `beforeunload` while not empty

## 3. Takedowns page (web2)

- [x] 3.1 `web2/views/takedowns.js`: entries, what each left out, warnings, Restore
- [x] 3.2 The take-down forms for a mod and a person, with the preview, adding pending changes
- [x] 3.3 Pending changes side panel on the page; phone width

## 4. Checks and docs

- [x] 4.1 Check in the browser: add from the Takedowns page, the toolbar list, remove, reload, save (refused and accepted, on a copy of the data), Control's panel
- [x] 4.2 Update `CLAUDE.md`
- [x] 4.3 Run `dart test`
