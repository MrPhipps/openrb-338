#!/usr/bin/env bash
# Enforces rules that OpenRB-338 states only in prose.
# Install as .claude/hooks/guard.sh (chmod +x). Exit code 2 blocks the tool call and shows
# the message on stderr to the agent.
set -euo pipefail
mode="$1"
input="$(cat)"

if [ "$mode" = "edit" ]; then
  path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""')"
  case "$path" in
    */backlog/*)
      echo "Blocked: change backlog/ only through the backlog CLI or MCP, never by hand." >&2
      exit 2 ;;
    *.i64|*.idb|*.id0|*.id1|*.nam|*.til)
      echo "Blocked: never write an analysis database." >&2
      exit 2 ;;
  esac
fi

if [ "$mode" = "bash" ]; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // ""')"
  # Only the supervisor pushes; sub-agents run in worktrees (path contains /worktrees/ or
  # .claude/worktrees). Adjust the test to how your worktrees are named.
  if printf '%s' "$cmd" | grep -Eq '(^|[;&| ])git push' && pwd | grep -q 'worktree'; then
    echo "Blocked: agents never push; the supervisor merges and pushes." >&2
    exit 2
  fi
  if printf '%s' "$cmd" | grep -Eq 'git add .*\.(i64|idb|exe|dll)(\s|$)'; then
    echo "Blocked: binaries and analysis databases are never committed." >&2
    exit 2
  fi
  if printf '%s' "$cmd" | grep -Eq 'locky release-all'; then
    echo "Blocked: never release-all; release only your own permits." >&2
    exit 2
  fi
fi
exit 0
