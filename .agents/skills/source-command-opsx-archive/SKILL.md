---
name: source-command-opsx-archive
description: Check and archive an OpenSpec change, including its spec updates. Use for `/opsx:archive` or a request to archive completed OpenSpec work.
---

# Archive an OpenSpec change

Archive one selected change without hiding incomplete work, skipping spec updates silently, or overwriting an existing archive.

## Select and check the change

Use the name supplied by the user. If none is supplied, run `openspec list --json`, show the active changes, and ask which one to archive.

Run `openspec status --change "<name>" --json`. Record the schema and list any artifacts that are not done. Locate the task artifact from the reported workflow data and count its checked and unchecked tasks when it exists.

If artifacts or tasks are incomplete, explain exactly what remains and get confirmation before continuing.

## Decide how to handle specs

If the change has delta specs, compare them with the matching main specs and summarize the additions, changes, removals, and renames.

- When updates remain, ask whether to apply them during archive or archive with `--skip-specs`.
- When the main specs already contain the deltas, offer to archive normally, archive with `--skip-specs`, or cancel.
- When there are no delta specs, continue without a spec decision.

## Archive safely

Resolve the source change directory and the dated target under `openspec/changes/archive/`. Confirm the source is the selected active change and the target does not exist. Stop without moving anything when the target already exists.

Use the OpenSpec CLI to perform the archive so validation, spec updates, and the directory move remain one operation:

```bash
openspec archive "<name>"
```

Add `--skip-specs` only when the user chose to skip spec updates. Do not bypass validation unless the user explicitly authorizes that separate risk.

After the command succeeds, confirm the active change is gone and the dated archive exists. Report the archive path, schema, spec-update result, and any incomplete work the user chose to archive.
