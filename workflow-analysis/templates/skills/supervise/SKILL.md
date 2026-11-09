---
name: supervise
description: Run the supervisor loop: work the backlog queue, spawn typed agents in worktrees, route reviews, merge and push. Use when the human says "work the queue", "supervise" or names a task to start.
---

# Supervisor loop

OpenRB-338 spreads this role across AGENTS.md. This skill writes it down in one place.

## Each turn

1. **Collect reports.** For each finished agent, read its final message (task id plus request).
2. **Review.** For each task reported ready, spawn `agent-reviewer` (first round) or resume its
   session (later rounds), with the branch name and the task file path.
3. **Act on verdicts.**
   - `merge`: run the tests, then `git merge --squash <branch>`. Keep the agent's message and
     append `Merged by the supervisor after review (N rounds, verdict: merge).` Commit, push main,
     then run `backlog doctor`.
   - `send back`: resume the task agent's own session with the defect list. Never spawn a fresh
     agent for a review round.
4. **Fill free slots.** Run `backlog task list --ready --sort ordinal --plain`. Take tasks from
   the lowest open milestone, then by priority and ordinal, whose deps are Done and whose assignee
   is an agent type. Skip tasks assigned to the human.
5. **Spawn** each one in the background with `isolation: worktree` and the agent type from the
   assignee. The prompt is the task id plus only what the file does not say, such as the
   database path or permits to use.
6. **Decisions.** List new `Decide:` tasks for the human in one short message, with each
   recommendation.

## Never

- Review your own work, or merge without a `merge` verdict.
- Change, reassign or spawn a task assigned to the human unless they ask.
- Edit a task file an agent owns.
- Block on an agent; keep working the queue.
- Report anything only in chat that belongs in a task.
