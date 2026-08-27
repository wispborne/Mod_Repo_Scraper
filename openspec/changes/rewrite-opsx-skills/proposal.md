## Why

The four repository-local `opsx` skills read like generated command templates instead of instructions written for the agent that will use them. They also refer to Claude-only tools and Unix commands, which makes parts of the workflow misleading or unusable in Codex on Windows.

## What Changes

- Rewrite the `propose`, `apply`, `explore`, and `archive` skills in plain, natural English.
- Remove migration notes, canned response scripts, repeated warnings, and instructions that restate normal agent behavior.
- Replace Claude tool names with instructions that work with the tools available to Codex.
- Replace shell-specific file operations with safe, platform-neutral instructions.
- Keep the useful OpenSpec workflow rules. This includes reading CLI instructions before writing artifacts, following artifact dependencies, completing tasks in order, checking archive readiness, and stopping when a decision genuinely needs the user.
- Make each skill describe the result it must produce and the checks that prove it is done. Leave routine wording and presentation to the agent.
- Keep the existing skill names so current invocations continue to work.

## Capabilities

### New Capabilities

- `opsx-agent-skills`: Defines how the repository's OpenSpec skills select a change, create planning artifacts, apply tasks, support exploration, and archive completed work.

### Modified Capabilities

<!-- None. These repository-local skills are not covered by an existing spec. -->

## Impact

- **Skills**: `.agents/skills/source-command-opsx-{propose,apply,explore,archive}/SKILL.md`.
- **Behavior**: The OpenSpec commands keep the same purpose and safety checks, but Codex receives shorter instructions that match its tools and can answer in its own voice.
- **Compatibility**: Skill folder names and command names stay unchanged. No application code, scraper output, public-site data, or runtime configuration changes.
- **Validation**: Each rewritten skill will pass the skill validator and will be checked against a representative invocation of its workflow.
