---
name: source-command-opsx-propose
description: Create an OpenSpec change and every planning artifact required before implementation. Use for `/opsx:propose` or a request to propose a change through OpenSpec.
---

# Propose an OpenSpec change

Turn the user's request into an apply-ready OpenSpec change.

## Choose the change

The user may give a kebab-case change name or describe what they want. Derive a short kebab-case name from a description. Ask what they want to change only when the request does not contain enough information to proceed.

Run `openspec list --json` before creating anything. If the name already exists, ask whether to continue that change or use a different name.

Create a new change with:

```bash
openspec new change "<name>"
```

## Build the planning artifacts

Run `openspec status --change "<name>" --json`. Treat its artifact graph and `applyRequires` list as the source of truth.

For each ready artifact:

1. Run `openspec instructions <artifact-id> --change "<name>" --json`.
2. Read every completed dependency named in the response.
3. Write the artifact at `outputPath` using the returned template and instructions.
4. Apply `context` and `rules` as constraints. Keep those instruction blocks out of the artifact itself.
5. Confirm the output file exists, then run status again.

Continue in dependency order until every artifact in `applyRequires` is done. Ask the user only when an artifact needs a material decision that cannot be recovered from the request or repository.

Finish by running the plain status command. Tell the user the change name and location, what was created, whether it is ready to apply, and the next available command.
