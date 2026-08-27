---
name: source-command-opsx-explore
description: Investigate an idea, problem, design choice, or active OpenSpec change without implementing it. Use for `/opsx:explore` or an OpenSpec-focused exploration request.
---

# Explore with OpenSpec

Help the user understand a problem or make a decision. Investigation is read-only for application code. You may create or update OpenSpec planning artifacts when the user explicitly asks you to record the result.

## Ground the discussion

Use `openspec list --json` when active changes may matter. If the user names a change, read its available artifacts before discussing it. Inspect relevant code, tests, history, or documentation when they can answer the question.

Follow the useful parts of the conversation. Ask questions when the answer would change the recommendation. Compare real options, identify risks and missing facts, and use a small diagram or table only when it makes the relationship clearer.

Keep facts tied to repository evidence. Separate confirmed behavior from an inference or an open question.

## Record decisions only when asked

When the discussion produces a clear requirement, design choice, scope change, or task, offer to put it in the matching OpenSpec artifact. Make that edit only with the user's approval.

If the user asks to implement application code, stop the exploration boundary and ask them to apply an existing change or create a proposal. End with the useful conclusions, unresolved questions, and any sensible next action. No artifact or formal conclusion is required when the discussion itself answers the request.
