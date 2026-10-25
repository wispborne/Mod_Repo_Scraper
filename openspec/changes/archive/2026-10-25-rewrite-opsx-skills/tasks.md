## 1. Rewrite the skills

- [x] 1.1 Rewrite the four frontmatter descriptions so each one names its OpenSpec action and its real trigger. Keep all four skill names unchanged, then verify the available-skills list still maps each command to the same folder.
- [x] 1.2 Rewrite `source-command-opsx-propose/SKILL.md` around change creation, CLI-reported artifact dependencies, and apply readiness. Verify the normal path, existing-name decision, and missing-context decision are all covered without a fixed response script.
- [x] 1.3 Rewrite `source-command-opsx-apply/SKILL.md` around change selection, CLI-provided context, verified task completion, and genuine blockers. Verify it cannot mark work complete before the matching change is made and checked.
- [x] 1.4 Rewrite `source-command-opsx-explore/SKILL.md` around read-only investigation and user-requested planning updates. Verify it clearly permits OpenSpec artifact edits while leaving application code unchanged.
- [x] 1.5 Rewrite `source-command-opsx-archive/SKILL.md` around readiness checks, spec synchronization, safe target selection, and the final move. Verify incomplete work and skipped spec updates require a user decision, and an existing archive target is never overwritten.

## 2. Remove migrated prompt machinery

- [x] 2.1 Remove references to `AskUserQuestion`, `TodoWrite`, Claude's `Task` and `Skill` tools, and any other unavailable tool names. Verify each decision still says what information is needed and when work may continue.
- [x] 2.2 Remove Unix-only archive commands and replace them with checked, platform-neutral file-operation instructions. Verify the archive workflow resolves the exact source and destination before moving anything.
- [x] 2.3 Remove command-template framing, canned progress blocks, canned completion blocks, decorative output rules, and repeated generic advice. Verify each skill still requires the selected change, meaningful progress state, warnings, result, and next available action where those facts matter.

## 3. Validate the result

- [x] 3.1 Run the skill creator's `quick_validate.py` against all four skill folders and fix every reported frontmatter, naming, or placeholder problem.
- [x] 3.2 Search all four rewritten files for stale migration wording, Claude-only tool names, Unix-only file commands, and copied response templates. Verify the search finds none.
- [x] 3.3 Walk one normal scenario and one decision, warning, or blocked scenario for each skill against `specs/opsx-agent-skills/spec.md`. Verify every required state has a clear next action and no scenario depends on exact prose.
- [x] 3.4 Review the final diff against the previous files and account for every removed command-specific safety rule. Verify any omitted rule is either preserved elsewhere in the new skill or already enforced by repository-level instructions.
- [x] 3.5 Run `openspec validate rewrite-opsx-skills --strict` and verify the change passes before marking the rewrite ready to apply.
