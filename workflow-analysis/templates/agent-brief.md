The shared brief for agents on <PROJECT>. Read in order: the root AGENTS.md (already in your
context), this brief, the task (`backlog task view task-N --plain`), the documents it points to.
Of the large survey `docs/<survey>.md`, read only your sections: grep the heading, then read
that line range.

## Your worktree

- You work in your own git worktree on your own branch. Do not touch the human's checkout.
- One commit holds the whole task. Squash your work commits into it before you report, and
  amend it for review fixes. The task goes from `To Do` to `Done` in it.
- Do not merge or push. Rebase onto nothing but main.
- Change the task with the `backlog` CLI in your worktree.
- Temporary files go in a scratchpad subdirectory named after your branch. Never run a script
  you did not write there.
- Shell: <bash/fish>. Put multi-step sequences in a script file. Python: <path>.

## Analysis databases

See the `reverse-engineer` skill. In short: copy, open headless, read only, close without
saving; every fact gets an address (`<DLL range>` DLL, `<EXE range>` exe).

## Shared hardware

<Host, how to reach it (exec, get, put, input, screenshot), where the target is installed,
the working folder, how to start and stop the target, known modal dialogs.>

Permits: semaphore `<name>` with leases. Read the count from `<lock> list`; never assume it.
- Acquire: `<lock> acquire <name> N --owner BRANCH --acquire-timeout 3600 --lease-timeout 1800`
- Refresh: `<lock> refresh <name> --owner BRANCH --lease-timeout 1800`
- Release: `<lock> release <name> all --owner BRANCH`
- Never release-all. Never stop a process you did not start.

## Testing

- Code: `<test cmd>`, all pass.
- Tools: `<tool test cmd>`, plus one real run recorded in the notes.
- Behavior change: the corpus comparison; the commit message states exact, within tolerance,
  or the first differing sample.
- Docs only: nothing.

## Rebase and the final check

Rebase once onto main after your tests pass and before the final commit.
- A file you did not change takes main's version.
- A file you changed is merged hunk by hunk, keeping both sides.
- A backlog file is never resolved by hand: take main's, then redo your change with the CLI.

Mandatory: `git diff main --stat` lists only files your task changed. Reset anything else
(`git checkout main -- <path>`) and amend. Say in your report that you ran this check.
