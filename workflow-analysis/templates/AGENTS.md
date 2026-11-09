# AGENTS.md: <PROJECT>

<One paragraph: what the project is, the target being reimplemented or reverse engineered, and the
pass criterion (e.g. "output matches the original sample for sample within a tolerance set by a
`Decide:` task").>

The original binaries are not in git. Tests read them from `<PROJ>_ORIGINAL` and skip with a
message when it is not set. The human's analysis databases live outside the repository; the
supervisor gives their path in each agent's prompt.

Planning, progress and decisions live in `backlog/` (Backlog.md). The shared agent brief is the
backlog doc `agent-brief` (`backlog/docs/doc-001 - agent-brief.md`).

## Where things are

| Command | Shows |
|---|---|
| `backlog task list --ready --sort ordinal --plain` | The queue |
| `backlog task list -l decision -a @<owner> --plain` | Pending decisions |
| `backlog milestone list --plain` | The plan |

- A decision is a task labeled `decision`, titled `Decide: <title>`, assigned to `@<owner>`.
- `In Progress` is never committed: a task goes from `To Do` to `Done` in its one commit.
- A milestone's title starts with its id (`m-1: ...`).
- Milestones: `m-0` oracles and survey; `m-1` ...; `m-2` ...
- Knowledge documents are `docs/*.md`. `docs/<survey>.md` marks items [C] confirmed or [G]
  guessed. `docs/original_bugs.md` lists the target's defects.

**Assignees.** `@<owner>` is the human and owns every decision. `@supervisor` is the orchestrator.
The agent types in `.claude/agents/` are `@agent-complex` (opus), `@agent-worker` (sonnet) and
`@agent-chore` (haiku). `agent-reviewer` reviews branches and is never an assignee.

## Backlog rules

- **Changes.** Only through Backlog.md's MCP tools or CLI. Never edit `backlog/` by hand. In a
  worktree, use the CLI (the MCP writes to the main checkout). Multi-line text uses real newlines.
- **Routing.** The supervisor spawns an agent only for a task assigned to an agent type:
  - complex: reverse engineering, numerics, experiments that need judgment;
  - worker: bounded work with a spec (tools, CLI, formats, tests, docs);
  - chore: mechanical work whose text or script is already written.
  A task assigned to `@<owner>` is never changed or spawned unless the human asks.
- **Order.** The lowest open milestone first, then priority, then ordinal. A task outside a
  milestone is tracking or an idea.
- **Starting.** The agent is spawned in the background on the task as it is (`To Do`). It writes
  its branch with `--append-notes` and records `--plan` before changing code.
- **Working.** `--append-notes` holds the evidence (addresses, functions, scripts run), the numbers
  before and after, the failed hypotheses and the commands that reproduce a result.
- **Finishing.** Check each AC with evidence (`--check-ac`), write `--final-summary`, set
  `-s Done`, all in the one commit. Review fixes amend it. It lands by squash merge with the
  supervisor's merge line.
- **Review.** The reviewer returns merge or send back, with defects at file:line. Send back:
  the supervisor resumes the same task-agent session. Re-review resumes the same reviewer session.
  No merge without a merge verdict, and the supervisor never self-reviews.
- **What you learn.** Facts about the target go into `docs/` with addresses. Follow-up work
  becomes a new task with labels, milestone, deps and a self-contained description. An unsettled
  design choice becomes a `Decide:` task with options and a recommendation; your task depends on
  it, and you stop.
- **Reporting.** Your final chat message is the task id plus what the supervisor must do.
- **A task** is doable without this conversation. It has a why, testable ACs, `--ref`, labels
  (`re`, `engine`, `cli`, `tools`, `tests`, `docs`, `decision`), a type, a priority, a milestone
  and deps.
- **Ownership.** While an agent owns a task, only it edits the task file. Only the supervisor
  merges and pushes.

## Standing rules

- Never save or modify the human's analysis databases; never commit them or their working files.
- Never edit a committed reference output by hand.
- Facts about the target carry addresses and are checked against the disassembly, not only the
  decompiler.
- <Numeric rules, e.g. "compute in f64, round to f32 where the original stores, no FMA, keep
  operand order".>
- A behavior change is checked against the reference corpus.
- Edit source with Edit/Write, not sed or python.

## Commit messages

Subject: `<area>: <what>`, at most 72 characters. Areas: <list>.

Body: **Change** (what and where), **Result** (numbers before and after, the corpus result),
**Testing** (`<test cmd> N pass`, the corpus comparison, or none), `Task: task-NNN`, optionally
`Decision: task-NNN`, then the attribution line.

## Build and test

- Build: `<cmd>`
- Test: `<cmd>`
- Lint and format: `<cmd>`
- Golden: `<cmd>` (needs `<PROJ>_ORIGINAL`; skips without it)
