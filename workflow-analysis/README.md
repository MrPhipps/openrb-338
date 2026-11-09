# How OpenRB-338 runs Claude, and what to copy

This folder studies how the owner of OpenRB-338 runs Claude Code on a large reverse-engineering
project. It was written on 2026-11-09 from the repository's state at commit `cbca449`.

| File | For |
|---|---|
| `README.md` (this file) | You: the findings and what to change in your own workflow. |
| `ARCHITECTURE.md` | An agent that builds the same system in another repository. |
| `templates/` | Files that agent copies and fills in. |

## 1. The short version

The owner does not chat with Claude to get work done. They run a **supervisor session** that
works a **file-based backlog** and spawns **typed sub-agents** in **git worktrees**. Each agent
does one task, records everything in that task's file, and produces **one commit**. A **read-only
reviewer** must approve before the supervisor merges. The human is involved only through
**`Decide:` tasks**, which agents write with options and a recommendation.

The numbers show it works: 173 tasks, 164 done, 14 decisions, 50 commits on main in about two weeks
(2026-10-26 to 2026-11-09). Agents did 148 of those tasks: `@agent-worker` 96, `@agent-complex` 48,
`@agent-chore` 4.

## 2. What is in the repository

| Piece | Path | Role |
|---|---|---|
| Project rules | `AGENTS.md` | Claude Code loads it into every session. It holds the backlog rules, the commit format, the build commands and the standing rules. |
| Agent brief | `backlog/docs/doc-001 - agent-brief.md` | Shared operating manual: worktree, IDA, test machine, permits, testing, rebase. |
| Agent types | `.claude/agents/agent-{complex,worker,chore,reviewer}.md` | Four sub-agents tiered by model, effort and tools. |
| Backlog | `backlog/` (Backlog.md) | Tasks, milestones, drafts, docs. Markdown files with YAML front matter. |
| Knowledge | `docs/*.md` | Facts about the original program with addresses and [C]/[G] confidence marks. |
| Oracles | `tools/rbhost/`, `tools/rb_export.py`, `tools/rbcmp.py`, `tests/refs/` | Ways to check a claim against the real program: an offline DLL host, the original's export on a Windows machine, and a comparator. |

There is **no** `.claude/settings.json`, no hooks, no slash commands and no skills in the repo.
The whole system is prose rules plus agent definitions plus Backlog.md.

## 3. How the backlog works

[Backlog.md](https://github.com/MrLesk/Backlog.md) stores each task as
`backlog/tasks/task-NNN - Title.md`. Each file has front matter (status, assignee, labels,
milestone, dependencies, references, priority, type, ordinal) and fixed sections: Description,
Acceptance Criteria, Implementation Plan, Implementation Notes and Final Summary.

The owner's conventions on top of the tool:

1. **Three statuses, and "In Progress" is never committed.** A task moves from `To Do` to `Done`
   inside the single commit that does the work. Main never shows a half-done task, so the backlog
   on main always tells the truth.
2. **One task, one commit.** Review fixes amend that commit. The supervisor squash-merges it and
   adds a line such as `Merged by the supervisor after review (2 rounds, verdict: merge).`
3. **The assignee is the routing key.** `@agent-complex`, `@agent-worker` and `@agent-chore` are
   agent types. `@pingw33n` (the human) owns every `Decide:` task. The supervisor only spawns
   agents on tasks assigned to an agent type.
4. **Queue order** is milestone first (`m-0` before `m-1`), then priority, then `ordinal`.
   Tasks outside a milestone are tracking or ideas. Drafts hold ideas not yet scheduled.
5. **The task file is the whole brief.** An agent must be able to do it without the chat that
   created it. It needs a why, testable acceptance criteria, refs, labels, type, priority,
   milestone and dependencies.
6. **The notes are a lab notebook.** The agent writes, in order: branch name, plan (before any
   code), evidence as it goes (addresses, numbers, failed hypotheses, commands that reproduce),
   each AC checked with evidence, final summary, then `Done`. See `task-003` for a full example.
7. **Decisions are escalated, not made.** An agent that hits an unsettled design choice creates a
   `Decide: <title>` task (`--type spike -l decision,<area> -a @pingw33n`) with context, options
   and a recommendation. It adds a dependency on it and stops. When the human decides, the final
   summary records the outcome and the date (`task-006`).
8. **Nothing lives only in chat.** An agent's final message is just the task id and what the
   supervisor must do. Follow-up work becomes new tasks.
9. **The CLI in worktrees, the MCP at the root.** The Backlog MCP tools write to the main checkout.
   So an agent in a worktree uses the `backlog` CLI, and reads long docs from the file because
   `doc view` truncates them. This is the most important practical trap the owner documented.

## 4. How reverse engineering is done

**Your "reverse engineer anything" skill is not in this repository.** No `SKILL.md`, no
`.claude/skills/` and no mention of it. The owner encodes the RE method in three other places:
the `agent-complex` definition, the IDA section of the agent brief, and the standing rules in
`AGENTS.md`. Everything below comes from those files. Compare it with what your skill does.

The RE method:

- **The tool.** IDA through the **idalib MCP tools**, headless, on a **copy** of the database in
  the agent's scratchpad. The agent opens it with `idb_open(..., mode="force_headless")` and closes
  it with `idb_close(save=false)`. The agent never renames, comments or patches anything. The
  human's `.i64` files stay outside git. The supervisor gives their path in each prompt, and agents
  may not search the disk for them.
- **The ground truth.** The disassembly is the reference and Hex-Rays is "a second opinion". The
  agent checks x87 operand order, every `fstp dword` (an f32 rounding point) and every integer
  conversion. It decodes constants from the bytes, not from IDA's float display. It knows which
  `.data` ranges are zero on disk and filled at run time.
- **Address discipline.** Every fact carries an address (`0x10xxxxxx` for the DLL, `0x4xxxxx` for
  the exe). Facts go into `docs/` in the same commit as the work, never into the database.
- **Confidence marks.** `[C]` means confirmed in the disassembly and `[G]` means guessed. Later
  tasks must confirm or refute `[G]` items and update the survey document.
- **Failed hypotheses are recorded.** `task-003` lists five, such as "x8 track scaling" and "msg 33
  at load". This stops the next agent from trying them again.
- **A registry of the original's bugs.** Every defect of the original goes into
  `docs/original_bugs.md` with What, Where, Trigger, Effect, Corpus, orb's model and [C]/[G].
  The rewrite copies the bugs on purpose.
- **Oracles that can prove a claim.** Static reading alone is not enough. The owner built:
  - a Windows test machine running the real program, driven by `rcs_client.py`
    (exec, input, screenshot, get and put);
  - `locky`, a semaphore with leases so parallel agents never share the machine's desktop;
  - `rbhost`, an offline host that loads the original DLL headless and renders;
  - a reference corpus of renders and a comparator that prints the first differing sample;
  - a golden test that runs in `cargo test`.
- **Numeric rules for a bit-exact port.** Compute in f64, round to f32 exactly where the original
  stores, use no FMA, and keep the original's operand order.
- **Legal hygiene.** The copyrighted binaries were purged from git history (`task-066`). Tests take
  the files from a CD image (`ORB_CD_ISO`) and skip with a message when it is not set.

## 5. What to change in your workflow

Listed by value. Each item names the file in `templates/` that implements it.

1. **Move from chat to a backlog with a supervisor.** Keep one long-running session as the
   supervisor and let it spawn background agents per task. Put the queue rules in `AGENTS.md` /
   `CLAUDE.md`. (`templates/AGENTS.md`)
2. **Tier the agents by model and give each a narrow scope.** Opus for RE and hard numerics,
   Sonnet for bounded tasks with a spec, Haiku for scripted chores, and a read-only reviewer with
   an explicit tool allowlist. Agents get `disallowedTools: Agent, AskUserQuestion, ...` so they
   cannot spawn more agents or block on the human. (`templates/agents/`)
3. **Make the task file the only brief.** Require acceptance criteria and a plan before code. Make
   the notes hold evidence, numbers and failed hypotheses. Your past research then survives context
   compaction and session loss. (`templates/task-template.md`)
4. **Add `Decide:` tasks.** Agents stop guessing on design choices and you answer in batches:
   `backlog task list -l decision -a @you --plain`. (`templates/decide-template.md`)
5. **Require a reviewer pass before every merge**, and resume the same agent session for fixes
   instead of starting a fresh one. The fixer then keeps its context.
6. **Put your RE skill in the repository** as `.claude/skills/reverse-engineer/SKILL.md` so every
   agent and every machine gets the same version. Add the owner's rules to it: work on copies,
   save=false, disassembly over decompiler, decode constants from bytes, addresses on every fact,
   [C]/[G] marks, failed hypotheses, a bug registry. (`templates/skills/reverse-engineer/SKILL.md`)
7. **Build an oracle early.** For any RE target, first make a way to run the original and compare
   outputs: a harness, a golden corpus and a diff tool that prints the first difference. Every
   later claim gets checked against it. Guard shared hardware with a lease-based lock.
8. **Write for context economy.** The owner's agent files say "AGENTS.md is already in your
   context: do not read it again", "grep for the heading, then Read with offset and limit", "batch
   commands into scripts" and "do not re-read the brief". They set `autoCompactWindow: 700000`.
   This cuts token cost on long RE sessions.

### Gaps in the owner's setup that you can avoid

- **The rules are prose and nothing enforces them.** Add hooks: block `Edit`/`Write` under
  `backlog/`, check the one-commit-per-branch rule before a merge, and keep binaries such as
  `*.i64`, `*.exe` and `*.dll` out of commits. (`templates/settings.json`)
- **The supervisor has no definition file.** Its behavior is spread across `AGENTS.md`. Write it
  down as a skill or a command so a fresh session can take over the role.
  (`templates/skills/supervise/SKILL.md`)
- **The reviewer runs on Haiku** and must judge engine numerics and disassembly claims. For RE
  branches, consider Sonnet or Opus for the reviewer.
- **The RE method is spread over three files.** A single skill is easier to version and reuse.
- **Machine-specific assumptions** (the fish shell, `/usr/bin/python3`, `~/dev/dcre/...`) are
  hard-coded. Put them in one environment section so another machine can override them.
