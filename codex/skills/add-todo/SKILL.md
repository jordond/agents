---
name: add-todo
description: Append a backlog item to the GitHub "Status" issue's TODO table. Use when the user wants to capture or jot a task or idea for later — "add a todo", "remind me to", "put X on the backlog", "we should eventually", "note that we need to". Capture only; it condenses the description into a one-line summary and does not research or plan. Use $ideate to flesh an idea into a plan, $workon to build it.
---

# Add todo

Append a backlog item to the **Status** GitHub issue's TODO table. Fast, low-ceremony — capture only, not planning (`$ideate` plans, `$workon` builds).

Argument (`$ARGUMENTS`): the thing to remember. Blank → ask once.

## Output discipline

Minimal. One line back: what was added. No confirmation theater.

## Status issue contract

One issue per repo, title exactly `Status`, label `status`, single source of truth. The relevant table:

```markdown
## TODO
| Task | Notes |
|------|-------|
| <one-line summary> | <optional> |
```

(Full board structure lives in the `$where-are-we` skill: TODO → Up Next → In Progress → Finished.)

## Procedure

1. **Get the content.** If `$ARGUMENTS` is non-empty, use it. Otherwise ask once: "What do you want to capture?" — then stop and wait.

2. **Condense.** Distill into a single clear task line (imperative, ≤ ~12 words). Keep concrete specifics (file, constraint, deadline) in the Notes cell rather than padding the task line. Don't invent scope the user didn't state.

3. **Find the Status issue.**
   ```bash
   gh issue list --search "Status in:title" --state open --json number,title --jq '.[] | select(.title=="Status") | .number'
   ```
   If it doesn't exist, create it the same way `$where-are-we` does (label `status`, the four-table body) with this TODO as the first row.

4. **Append the row.** Read the body (`gh issue view <n> --json body`), insert the new row at the end of the TODO table, write back: `gh issue edit <n> --body-file <updated>`. Don't disturb other tables or rows.

5. **Confirm** in one line, e.g. `Added to TODO: "Cache forecast API responses" (#Status)`.
