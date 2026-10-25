## Context

The four skills were migrated from command prompts written for Claude. Their instructions mix OpenSpec rules with tool names, scripted status messages, duplicated warnings, and broad advice about how the agent should think. The result is long, repetitive, and partly wrong for the current Codex environment.

The OpenSpec CLI remains the source of truth for schemas, artifact dependencies, context files, and completion state. The repository also has general rules for safe edits, user questions, plans, and progress updates. The skills only need to add the parts that are specific to each OpenSpec action.

## Goals / Non-Goals

**Goals:**

- Make each file short enough that its command-specific workflow is easy to find.
- Preserve the checks that prevent incomplete proposals, false task completion, accidental archive overwrites, and unwanted code edits during exploration.
- Let Codex choose natural wording for progress, questions, and final reports.
- Make the instructions usable on Windows and in other supported shells.

**Non-Goals:**

- Rename the skill folders or command entry points.
- Change the OpenSpec schema or CLI.
- Combine the four actions into one router skill.
- Add scripts or dependencies for work the OpenSpec CLI and Codex tools already handle.

## Decisions

### Rewrite around outcomes instead of editing sentences in place

Each skill will be rebuilt from three parts: when it applies, the command-specific work, and the conditions that mean the work is complete or must stop. This avoids carrying the old prompt's structure and tone into shorter wording.

Trimming the existing files line by line was rejected. Their repetition is structural. Keeping the old headings and output samples would keep the agent focused on reproducing a script.

### Keep each action as its own discoverable skill

The four existing skills remain separate and keep descriptions that support both explicit command use and natural-language requests. Each action has a different permission boundary. Exploration is read-only by default, apply edits the project, and archive moves files. Keeping them separate makes those boundaries clear.

A single router skill was rejected because it would add another instruction layer without removing any command the user already knows.

### Treat the CLI response as live workflow data

The skills will tell Codex to read `openspec status` and `openspec instructions` at the point where each result is needed. They will not copy assumed artifact names, schemas, or context-file lists into the workflow except as examples where that adds real clarity.

This keeps the skills working if the repository changes schema. It also removes duplicated explanations of fields that the CLI already returns.

### State required report content without supplying response templates

The skills will name facts the user needs, such as the selected change, completed task count, archive path, warnings, and next available action. They will not prescribe headings, checkmark symbols, congratulations, or exact sentences.

Examples remain only where they explain input syntax or an unsafe edge case. Large sample responses are removed.

### Refer to capabilities, not product-specific tool names

When a decision is required, the skill will say what must be asked and why. It will not name `AskUserQuestion`, `TodoWrite`, `Task`, or `Skill`. Codex can then use the interaction, planning, delegation, or skill tools that are actually available in its current mode.

Archive file operations will be described by their checks and result. The agent will choose the correct platform-native operation under the repository's safety rules.

### Validate structure and behavior separately

The skill validator will check frontmatter, names, and unfinished placeholders. A manual scenario pass will then check one normal path and one decision or warning path for each command. The review will focus on whether an agent can reach the correct result from the rewritten instructions, not whether it repeats expected wording.

## Risks / Trade-offs

- **Shorter instructions could drop a rare safety check.** → Build a checklist from the existing four files before rewriting, then account for every command-specific rule in the new files or record why it is redundant.
- **Natural response wording is less snapshot-testable.** → Validate required facts and state changes instead of exact prose.
- **Removing named tools could make an action less concrete.** → Name the required decision and completion condition precisely. Repository-level tool rules decide how to carry it out.
- **Automatic skill selection may remain broader than explicit command use.** → Keep descriptions short and name the exact OpenSpec action each skill handles.

## Migration Plan

1. Record the required behavior and safety checks from each current skill.
2. Rewrite all four files while keeping their names and invocation descriptions.
3. Validate all four skill folders.
4. Run representative read-only checks of proposal, apply, explore, and archive behavior. Use temporary or existing fixture changes where a mutation would otherwise be needed.
5. Review the diff for lost requirements, stale Claude references, Unix-only commands, canned output, and repeated generic advice.

The change is limited to instruction files. Rolling back means restoring the four previous `SKILL.md` files.
