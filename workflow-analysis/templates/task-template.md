# Task template (create with the CLI, not by hand)

```bash
backlog task create "RE: <what is traced>" \
  --type spike -l re,docs -m m-0 --priority high --ordinal 3000 \
  -a @agent-complex \
  --ref docs/<survey>.md --ref docs/<format spec> \
  --dep task-NNN \
  -d "<WHY this exists, and the context the code does not show: known addresses, the survey
section, what downstream work needs the answer.>

<WHAT to trace or build, as a bullet list of the concrete questions or deliverables.>
Verify each mapping in the disassembly, not only the decompiler." \
  --ac "docs/<topic>.md lists <X> with the builder and reader addresses" \
  --ac "Each <field> is mapped to <Y>, including <edge cases>" \
  --ac "docs/<survey>.md section N points to the new document; its [G] items resolved or marked"
```

## What the agent adds, in order (all through the CLI)

```bash
backlog task edit NNN --append-notes "Branch: <branch>"
backlog task edit NNN --plan "1. ...
2. ..."
backlog task edit NNN --append-notes "Evidence: sub_XXXX at 0x... does ...
Numbers: before ..., after ...
Failed hypothesis: ... (refuted at 0x..., because ...)
Reproduce: <command>"
backlog task edit NNN --check-ac 1 --check-ac 2
backlog task edit NNN --append-notes "Acceptance criteria evidence:
- AC1: ...
- AC2: ..."
backlog task edit NNN --final-summary "<outcome; branch and commit; numbers; tests run; follow-ups
created; notes for the supervisor>"
backlog task edit NNN -s Done
git add -A && git commit   # the ONE commit
```

## Review round (on send back, in the resumed session)

```bash
backlog task edit NNN --append-notes "Review round 1 (send back):
1. <defect> -> <fix>
2. ..."
git commit --amend
```
