---
name: source-command-opsx-apply
description: Implement the pending tasks in an OpenSpec change. Use for `/opsx:apply` or a request to carry out an existing OpenSpec plan.
---

# Apply an OpenSpec change

Implement the selected change until its tasks are complete or a real blocker requires the user.

## Select and inspect the change

Use a change named by the user. Otherwise, use a change clearly identified by the conversation or the only active change. If the choice is still ambiguous, run `openspec list --json` and ask the user which active change to apply.

Tell the user which change you selected. Then run:

```bash
openspec status --change "<name>" --json
openspec instructions apply --change "<name>" --json
```

Use the returned schema, state, progress, tasks, and `contextFiles`. Read every listed context file before editing anything.

If the state is `blocked`, report the missing prerequisites and stop. If it is `all_done`, report that there is nothing left to implement and offer the archive action.

## Complete the tasks

For each pending task, in order:

1. Make the changes required by the planning artifacts.
2. Verify the result in proportion to its risk.
3. Mark the task complete in the task file only after the change and its check both succeed.
4. Continue to the next pending task.

Keep going until all tasks are complete. Stop when a task needs a user decision, the implementation contradicts the planning artifacts, verification fails without a safe in-scope fix, or the user interrupts. Explain the exact blocker and leave unfinished tasks unchecked.

On completion or pause, report what changed, the current completed and total task counts, any checks run, and the next available action.
