# Architecture: a supervised multi-agent backlog for Claude Code

This document specifies the system so that an agent can build it in another repository. It is
modeled on OpenRB-338 (`AGENTS.md`, `.claude/agents/`, `backlog/`). The parts marked
**[addition]** are not in OpenRB-338. They close gaps found in the study (see `README.md` §5).

## 1. Goals and non-goals

Goals:
- A human sets direction and makes decisions; agents do all other work.
- Every unit of work is traceable from task to evidence to commit.
- Knowledge survives sessions, context compaction and agent turnover, because it lives in git.
- Parallel agents never corrupt each other's work or shared resources.
- Reverse-engineering claims are checked against the binary and, where possible, against an
  oracle that runs the original.

Non-goals:
- A GUI or an external tracker. Everything is markdown in git.
- Agents talking to the human directly. They escalate through `Decide:` tasks.

## 2. Components

```
repo/
├── AGENTS.md (or CLAUDE.md)     # Rules; auto-loaded into every session and sub-agent
├── .claude/
│   ├── agents/                  # Sub-agent types (model, effort, tools, prompt)
│   │   ├── agent-complex.md     # opus: RE, numerics, judgment
│   │   ├── agent-worker.md      # sonnet: bounded work with a spec
│   │   ├── agent-chore.md       # haiku: mechanical, text or script given
│   │   └── agent-reviewer.md    # read-only verdict
│   ├── skills/                  # [addition] versioned methods
│   │   ├── reverse-engineer/SKILL.md
│   │   └── supervise/SKILL.md
│   └── settings.json            # [addition] hooks that enforce the rules
├── backlog/                     # Backlog.md data (CLI: `backlog`; MCP server: `backlog`)
│   ├── config.yml
│   ├── tasks/task-NNN - Title.md
│   ├── drafts/                  # ideas, not scheduled
│   ├── milestones/m-N - m-N-title.md
│   └── docs/doc-001 - agent-brief.md
├── docs/                        # Knowledge documents, edited like source
│   ├── <survey>.md              # The first investigation, [C]/[G] marked
│   ├── <topic>.md               # One per subsystem, created by tasks
│   └── original_bugs.md         # Registry of the target's defects
└── tools/                       # Oracles: harness, runner, comparator
```

### 2.1 Roles

| Role | Runs as | Model | Can | Cannot |
|---|---|---|---|---|
| Human (`@owner`) | Person | n/a | Decide, assign, reprioritize | n/a |
| Supervisor | The main Claude Code session | opus | Read the queue, spawn agents, run tests, merge, push, write merge comments | Self-review; change tasks assigned to the human; work on a task an agent owns |
| `agent-complex` | Sub-agent, background, worktree | opus, effort medium | RE, engine numerics, experiments | Spawn agents, ask the user, merge, push |
| `agent-worker` | Sub-agent, background, worktree | sonnet, effort medium | Tools, CLI, file formats, tests, docs | Same; avoids engine DSP and files follow-ups for complex |
| `agent-chore` | Sub-agent, background, worktree | haiku, effort high | Apply given text or scripts | Read disassembly, write engine code, judge results |
| `agent-reviewer` | Sub-agent | haiku in the original (use sonnet or opus for RE) | Read, grep, read-only git, backlog reads | Change anything |

Tool restrictions are set in each agent's front matter:
- Workers use `disallowedTools: Agent, AskUserQuestion, Artifact, ...`. No sub-agent can spawn
  agents or block on the human.
- The reviewer uses an allowlist: `tools: Read, Grep, Glob, Bash, mcp__backlog__task_view, ...`.

### 2.2 Front matter fields used

```yaml
name: agent-complex
description: <one line the supervisor reads to route; name the work it is and is not for>
model: opus | sonnet | haiku
effort: low | medium | high
autoCompactWindow: 700000
disallowedTools: <comma list>   # workers
tools: <comma list>             # reviewer (allowlist)
```

## 3. Data model (Backlog.md)

`backlog/config.yml` (key settings):

```yaml
default_status: "To Do"
statuses: ["To Do", "In Progress", "Done"]   # In Progress exists but is never committed
zero_padded_ids: 3
task_prefix: "task"
auto_commit: false        # the agent's single commit carries backlog changes
check_active_branches: true
```

Task fields and their meaning:

| Field | Values | Use |
|---|---|---|
| `status` | To Do, Done (In Progress only in a worktree, never committed) | Lifecycle |
| `assignee` | `@agent-complex`, `@agent-worker`, `@agent-chore`, `@owner`, `@supervisor` | Routing |
| `labels` | Closed set, e.g. `re, engine, cli, tools, tests, testmachine, docs, ui, decision` | Filtering |
| `type` | bug, feature, enhancement, task, chore, docs, spike | `spike` for RE and decisions |
| `milestone` | `m-0` ... | Queue order level 1. A milestone title starts with its id. |
| `priority` | high, medium, low | Queue order level 2 |
| `ordinal` | integer (1000 steps) | Queue order level 3 |
| `dependencies` | task ids | Blocks readiness |
| `references` | paths | What the agent must read |

Task body sections, all written through the CLI:
`Description`, `Acceptance Criteria` (`- [ ] #1 ...`), `Implementation Plan`,
`Implementation Notes`, `Final Summary`.

### 3.1 Decision tasks

- Title `Decide: <question>`, `type: spike`, labels `decision,<area>`, assignee `@owner`.
- The description holds the context, numbered options and one recommendation.
- Dependent tasks list it in `dependencies`.
- When resolved, the final summary reads `Decided by @owner on YYYY-MM-DD: option N ...`, and the
  status becomes Done.

## 4. The task lifecycle

```
           (human or supervisor writes the task: why, ACs, refs, labels, milestone, deps)
                                        │
                                   [To Do on main]
                                        │ supervisor picks: lowest milestone → priority → ordinal,
                                        │ deps done, assignee is an agent type
                                        ▼
            supervisor spawns agent-<type> in background, isolation: worktree, prompt = task id
                                        │
   agent: append-notes "Branch: X" → research → --plan → work + append-notes (evidence, numbers,
          failed hypotheses, repro commands) → tests → rebase onto main → diff-stat check →
          --check-ac N (with evidence) → --final-summary → -s Done → ONE commit
                                        │
                                        ▼  final chat message = "task-NNN: merge" (or "decide task-MMM")
              supervisor spawns agent-reviewer (first round fresh; later rounds resume its session)
                                        │
                         ┌──────────────┴──────────────┐
                    verdict: merge               verdict: send back (defects with file:line)
                         │                              │
       supervisor runs tests, squash-merges,     supervisor RESUMES the same task-agent session
       appends "Merged by the supervisor after   with the defects; agent records "Review round N"
       review (N rounds, verdict: merge)",       in its notes and amends its one commit → re-review
       pushes, runs `backlog doctor`
```

Invariants:
1. Main never contains `In Progress`.
2. A task's branch holds exactly one commit, and that commit holds the task's `To Do → Done`.
3. Only the assigned agent edits a task file while it owns it.
4. Only the supervisor merges and pushes.
5. Every merge has a reviewer `merge` verdict first.
6. `git diff main --stat` on the branch lists only files the task changed.

Parallelism: agents run in the background, and the supervisor keeps working the queue. Shared
external resources (hardware, licensed apps) are guarded by a lease-based semaphore (§6.4).

## 5. Rules (put in AGENTS.md)

The standing rules, grouped:

- **Backlog.** Change it only through the CLI or MCP, never by hand. A worktree uses the CLI (the
  MCP writes to the main checkout). Long docs are read from the file (`doc view` truncates). A
  multi-line value uses a real newline, never `\n`.
- **Scope.** Keep to the task. A design choice it does not settle becomes a `Decide:` task. Other
  work becomes a new task with labels, milestone, dependencies and a self-sufficient description.
- **Knowledge.** A new fact goes into its `docs/` file in the same commit as the work. Facts about
  a binary carry addresses and a [C] or [G] mark. A defect of the target also goes into
  `docs/original_bugs.md`.
- **Reporting.** Nothing is reported only in chat. The final message is the task id plus what the
  supervisor must do.
- **Editing.** Source is edited with Edit/Write, not sed or python.
- **Commits.** The subject is `<area>: <what>`, at most 72 characters. The body has Change, Result
  (numbers before and after), Testing, `Task: task-NNN`, an optional `Decision: task-NNN`, then the
  attribution.
- **Protected assets.** The human's analysis databases are never saved or modified, and never
  committed. Reference outputs are never edited by hand. No test needs the copyrighted binary in
  the repo: tests read it from an env var and skip with a message when it is not set.

## 6. The reverse-engineering subsystem

### 6.1 Static analysis

- An MCP server for the disassembler (OpenRB-338 uses idalib through the IDA MCP tools: `idb_open`
  and `idb_close`). Ghidra or Binary Ninja MCP servers fit the same slot.
- Protocol: copy the database into the scratchpad, open it headless, read only, close with
  `save=false`. The supervisor passes the database path in the prompt, and the agent never
  searches the disk for it.
- Trust order: raw disassembly, then bytes, then the decompiler. Check operand order, store
  widths (rounding points) and integer conversions. Decode constants from the bytes.

### 6.2 The knowledge base

- **The survey document.** It is written first. Every claim carries an address and [C] or [G].
  Later tasks resolve [G] items in place and link the topic document.
- **Topic documents.** One per subsystem (load path, export state, file format). Each records
  the message and struct layouts, the address of every builder and reader, and the errata of the
  official specs.
- **`original_bugs.md`.** Entries OB-n with What, Where, Trigger, Effect, Corpus, Model in the
  rewrite and [C]/[G].
- **Task notes** hold the evidence trail and the failed hypotheses. The docs hold the conclusions.

### 6.3 Dynamic oracles (build these early)

| Oracle | OpenRB-338's version | Generic shape |
|---|---|---|
| Run the original end to end | `tools/rb_export.py` drives the real app on a Windows box | A runner script around remote exec, input and screenshots |
| Run the original's core headless | `tools/rbhost/rbhost.c` loads the DLL and renders | A minimal host that loads the library and calls its entry points |
| A reference corpus | `tests/refs/manifest.json`, FLAC renders plus hashes | Inputs plus the original's outputs plus provenance (protocol, tool version, hashes) |
| A comparator | `tools/rbcmp.py`, `orb compare` | Prints the first difference: position, context, both values |
| A golden test | `cargo test --test corpus_golden` | Runs the corpus in CI-style tests |

### 6.4 Shared hardware

- A semaphore with leases (`locky`): `acquire NAME N --owner BRANCH --lease-timeout 1800`, then
  `refresh`, then `release ... all --owner BRANCH`. Never use `release-all`.
- A desktop session takes all the permits. Runner tools acquire and release permits themselves.
- Never stop a process you did not start.

## 7. Context economy (put in every agent prompt)

- "AGENTS.md is already in your context: do not read it again."
- "The task file is your full brief; the supervisor's prompt adds only what it does not say."
- "Of the large survey, read only your sections: grep the heading, then Read with offset and
  limit."
- "Batch commands into a script; read what you need once; do not re-read the brief."
- `autoCompactWindow: 700000` for long sessions.

## 8. Enforcement [addition]

OpenRB-338 relies on prose. Add hooks in `.claude/settings.json` (see `templates/settings.json`):

| Hook | Matcher | Blocks |
|---|---|---|
| PreToolUse | `Edit\|Write` | Any path under `backlog/` (forces CLI use) |
| PreToolUse | `Bash` | `git push` from a sub-agent; `git add` of `*.i64`, `*.idb`, `*.exe`, `*.dll` |
| Stop (sub-agent) | n/a | Ending while the branch has more than one commit ahead of main, or the task is not Done |

## 9. Build order for an implementing agent

1. Install Backlog.md (`npm i -g backlog.md`), run `backlog init`, and set `config.yml` as in §3.
   Register its MCP server.
2. Write `AGENTS.md` from `templates/AGENTS.md`: project facts, backlog rules, commit format,
   build and test commands, standing rules.
3. Write the agent brief as `backlog doc create` from `templates/agent-brief.md`.
4. Add `.claude/agents/*.md` from `templates/agents/`.
5. Add `.claude/skills/reverse-engineer/SKILL.md` and `.claude/skills/supervise/SKILL.md`.
6. Add `.claude/settings.json` hooks and test each one by trying the blocked action.
7. Create milestone `m-0` for the oracles (harness, corpus, comparator) and the first survey.
   Create its tasks with acceptance criteria.
8. Dry-run one `agent-chore` task through the full lifecycle, including a send-back round.
