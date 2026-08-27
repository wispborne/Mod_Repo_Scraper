## Purpose

Defines reliable, plain-English OpenSpec workflows that Codex can follow with the tools available in this repository.

## ADDED Requirements

### Requirement: Stable command entry points
The skill set SHALL keep the existing `source-command-opsx-propose`, `source-command-opsx-apply`, `source-command-opsx-explore`, and `source-command-opsx-archive` names and SHALL describe the matching `opsx` command clearly enough for correct selection.

#### Scenario: Existing command is invoked
- **WHEN** the user invokes one of the four existing `opsx` commands
- **THEN** the matching skill handles the request without requiring a renamed command

### Requirement: Natural instructions and responses
Each skill SHALL use direct, plain English. It SHALL define required results and checks without prescribing canned progress messages, decorative status blocks, praise, or a fixed conversational style.

#### Scenario: Agent reports progress or completion
- **WHEN** a skill asks the agent to update the user
- **THEN** the agent can describe the result naturally while still including the information needed to understand the state of the work

### Requirement: Available tools and safe file operations
The skills SHALL describe actions using capabilities available to Codex. File operations SHALL work on the current platform and SHALL preserve the repository's normal safety and approval rules.

#### Scenario: User input is required
- **WHEN** the workflow cannot safely choose a change or continue without a user decision
- **THEN** the skill tells the agent to ask the user through an available input method rather than naming a Claude-only tool

#### Scenario: A change is archived
- **WHEN** the archive workflow moves a completed change
- **THEN** it uses a checked, platform-appropriate file operation and does not depend on Unix-only command syntax

### Requirement: Proposal workflow
The proposal skill SHALL create an OpenSpec change and all artifacts required before implementation. It SHALL obtain the artifact order and content rules from the OpenSpec CLI rather than assuming a fixed schema.

#### Scenario: Proposal request has enough context
- **WHEN** the user describes a change clearly
- **THEN** the skill derives a useful change name, creates the change, follows the reported artifact dependencies, and stops only when every artifact required for apply is complete

#### Scenario: Change name already exists
- **WHEN** the proposed change name is already active
- **THEN** the skill asks whether to continue that change or use a different name before writing into it

### Requirement: Apply workflow
The apply skill SHALL select the intended change, read the CLI-provided context files, implement pending tasks, verify each task in proportion to its risk, and mark a task complete only after its work is finished.

#### Scenario: Apply can proceed
- **WHEN** the selected change is ready and contains pending tasks
- **THEN** the skill continues through the tasks until all are complete or a real blocker requires user input

#### Scenario: Apply is blocked or complete
- **WHEN** the OpenSpec CLI reports missing prerequisites or no remaining tasks
- **THEN** the skill reports that state without making unrelated changes

### Requirement: Exploration workflow
The explore skill SHALL support read-only investigation and discussion. It SHALL not edit application code, but it may create or update OpenSpec planning artifacts when the user asks.

#### Scenario: User explores a problem
- **WHEN** the user asks to understand an idea, bug, design, or existing change
- **THEN** the skill inspects relevant evidence, discusses useful options, and leaves implementation files unchanged

### Requirement: Archive workflow
The archive skill SHALL check artifact completion, task completion, delta-spec sync needs, and target-path availability before moving a change. It SHALL require confirmation before archiving known incomplete work or skipping needed spec updates.

#### Scenario: Completed change is ready to archive
- **WHEN** all artifacts and tasks are complete, required specs are synchronized, and the target path is free
- **THEN** the skill moves the full change directory into the dated archive location and reports where it went

#### Scenario: Archive has warnings
- **WHEN** artifacts or tasks are incomplete, spec changes would be skipped, or the target path already exists
- **THEN** the skill explains the exact issue and either obtains the required decision or stops without overwriting data
