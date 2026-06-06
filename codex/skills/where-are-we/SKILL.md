---
name: where-are-we
description: Read the GitHub "Status" issue, reconcile it against git history, and report where the project stands with concrete next steps. Use when the user asks "where are we", "what's the status", "what should I work on next", "catch me up", "what's left", or wants orientation at the start of a session. Creates the Status issue if it doesn't exist. Orients and suggests only — it does not plan (use $ideate) or implement (use $workon).
---

# Where are we

Orient the user: read the canonical **Status** GitHub issue, make it match reality (git history), then give a tight summary plus what to do next.

This is the project's read/reconcile entry point. `$add-todo`, `$ideate`, and `$workon` all write to the same Status issue; this one keeps it honest. It only orients and suggests — it does not plan (use `$ideate`) or implement (use `$workon`).

Argument (`$ARGUMENTS`, optional): a focus area to bias next steps toward.

## Output discipline

Tokens are the budget. Report only what the user needs to act: a short status line, the few items that matter, and 1-3 concrete next steps. No preamble, no "I will now…", no restating the issue verbatim. If nothing changed during reconciliation, say so in one line.

## Status issue contract

One issue per repo, title exactly `Status`, label `status`. Single source of truth all agents read and edit. Body is four markdown tables in this fixed order:

```markdown
# Status

_Single source of truth. Agents read + update this issue. Last reconciled: <YYYY-MM-DD> @ <short-sha>_

## TODO
| Task | Notes |
|------|-------|
| <one-line summary> | <optional> |

## Up Next
| Issue | Task | Notes |
|-------|------|-------|
| #12 | <one-line summary> | plan ready |

## In Progress
| Issue | Task | Branch | Notes |
|-------|------|--------|-------|
| #12 | <task> | feat/issue-12-slug | <optional> |

## Finished
| Issue | Task | PR |
|-------|------|----|
| #12 | <task> | #34 |
```

Lifecycle: a raw idea lands in **TODO** → `$ideate` researches it, creates an issue, moves it to **Up Next** → `$workon` moves it to **In Progress** (branch) → on merge it moves to **Finished**. Rows carry the issue `#` so everything links.

## Procedure

1. **Locate the Status issue.**
   ```bash
   gh issue list --search "Status in:title" --state open --json number,title --jq '.[] | select(.title=="Status") | .number'
   ```
   - Found: `gh issue view <n> --json number,body`.
   - Not found: create it. `gh label create status --color 5319E7 --description "Coordination board" 2>/dev/null || true`, then `gh issue create --title Status --label status --body-file <empty-template>`. Pin if possible (`gh issue pin <n>` may fail — ignore). Seed any obviously-open work from open issues, then tell the user it was created.

2. **Gather reality.** Run these and read the output:
   ```bash
   git log --oneline -20
   git branch -a --format='%(refname:short)'
   git worktree list
   gh pr list --state merged --limit 15 --json number,title,headRefName,mergedAt
   gh pr list --state open --limit 15 --json number,title,headRefName
   gh issue list --state open --limit 30 --json number,title,labels
   ```

3. **Reconcile** the Status body against reality. Apply only changes you have evidence for:
   - In Progress row whose branch was merged (matching merged PR `headRefName`) → move to **Finished** with the PR `#`.
   - In Progress row whose branch is gone with no merge → it stalled; keep it but flag in the summary.
   - Open issue with a plan label not on the board → add to **Up Next**.
   - Closed/merged issue still in TODO/Up Next/In Progress → move to **Finished**.
   - Stamp the `Last reconciled:` line with today's date and `git rev-parse --short HEAD`.
   If nothing needs changing, skip the write.

4. **Write back** only if changed: `gh issue edit <n> --body-file <updated>`. Edit the whole body; preserve rows you have no evidence to touch.

5. **Summarize.** Format:
   ```
   <repo> @ <short-sha> · reconciled <N changes / no changes>
   In progress: <n> · Up next: <n> · TODO: <n>
   ▸ <most important in-progress or blocking item>
   Next: 1) … 2) … 3) …
   ```
   Pick next steps from Up Next first (plans ready), then unblocking stalled work, then promising TODOs worth `$ideate`. If a focus area was passed as an argument, bias toward it.

Don't guess at state you can't verify — if git and the board disagree and you can't tell why, surface the conflict instead of silently picking one.
