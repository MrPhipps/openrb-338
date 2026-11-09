# Decide-task template

```bash
backlog task create "Decide: <the question>" \
  --type spike -l decision,<area> -a @<owner> -m <milestone> --priority medium \
  -d "<Context: what forces the choice now, with numbers (sizes, costs, risks).>

Options:
1. <option> - <consequence>
2. <option> - <consequence>
3. <option> - <consequence>

Recommendation: option N, because <reason>. <Any sub-question the owner should also answer.>"

# The blocked task depends on it:
backlog task edit <blocked> --dep task-<decide id>
```

When the owner answers:

```bash
backlog task edit <decide id> --final-summary "Decided by @<owner> on YYYY-MM-DD: option N, \
<restated outcome with any modifications>." -s Done
```

A commit that applies the decision adds `Decision: task-<decide id>` to its message.
