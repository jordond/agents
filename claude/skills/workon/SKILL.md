---
name: workon
description: Implement an already-planned GitHub issue end to end using subagents in an isolated git worktree. Use when the user wants to execute existing work — "work on #N", "implement issue 12", "build the plan", "start that ticket", "tackle <thing that already has a plan/issue>". Parses an issue number or plan, or offers options from the Status board; parallelizes across sub-issues when independent; updates the Status issue throughout and always at the end; then asks how to finish (PR or merge). Requires a plan or issue to exist — if the user describes something new with no plan yet, use /ideate first to research and plan it. For "what should I work on?" with no target chosen, /where-are-we suggests options.
argument-hint: "[issue number, or blank to pick from the board]"
---

Execute a plan. The plan already exists (from `/ideate`); this skill turns it into merged, verified work with minimal supervision — built so the user can drive it remotely from the Claude Code app.

## Output discipline

The user is often watching from a phone. Surface decisions and blockers, not narration. Brief progress beats on long tasks (what's done, what's next), and a tight wrap-up. Let subagents do the verbose work; you report signal.

## Status issue contract

One issue per repo, title `Status`, label `status`. `/workon` moves the item TODO/Up Next → **In Progress** (recording branch + worktree) and, on completion, → **Finished** with the PR. Update it during long work when state changes; **always** update it at the end. (Full board: see the `where-are-we` skill.)

## Procedure

### 1. Resolve the target
- `$ARGUMENTS` has an issue number → `gh issue view <n>`.
- Blank → read the Status issue and offer **Up Next** (and resumable **In Progress**) items; let the user pick. If they describe something with no plan, point them to `/ideate` first.
- Read the issue body. If it's a **master** issue with linked sub-issues, fetch those too.

### 2. Set up an isolated worktree (default)
Work in a git worktree unless the user says otherwise — it keeps their main checkout free and lets parallel sub-agents avoid collisions. If the `using-git-worktrees` skill is available, use it; otherwise:
```bash
git worktree add ../wt-<n>-<slug> -b feat/issue-<n>-<slug>
```
Do everything below inside that worktree.

### 3. Mark In Progress
```bash
gh label create in-progress --color FBCA04 2>/dev/null || true
gh issue edit <n> --add-label in-progress
```
Move the row to **In Progress** in the Status issue with the branch and worktree path.

### 4. Implement with subagents
Always use subagent-driven development — it keeps the orchestrating context lean and the work focused. If the `subagent-driven-development` and `test-driven-development` skills are available, follow them.

- **Single plan:** dispatch a subagent per coherent step/slice, sequentially where steps depend on each other.
- **Multiple sub-issues:** determine which are independent and run those **in parallel** (separate subagents, each on its slice within the worktree — or its own worktree if they'd touch the same files). Sequence only the genuinely dependent ones. State the parallelization plan in one line before launching.

Hold the quality bar: follow existing repo conventions, no AI anti-patterns (em-dash prose, dead comments, speculative abstraction). The `deslopify` and `refine` skills exist for a cleanup pass if useful.

### 5. Verify before claiming done
Run the project's tests/build/lint and confirm they pass — evidence, not assertion. If the `verification-before-completion` skill is available, follow it. Don't report success on unverified work.

### 6. Update the board
Tick the plan's checkboxes on the issue as steps land (during long runs). When work is verified complete, that's a required step — don't skip it even if finishing fast.

### 7. Finish — ask the user
Present the result (one line: what was built, tests green) and ask how to land it:
- **PR + clean up:** push the branch, `gh pr create` (body closes the issue, e.g. `Closes #<n>`), then `git worktree remove` the worktree once the PR is open. If `finishing-a-development-branch` skill is available, use it.
- **Merge to main now:** merge the branch into main, push, remove the worktree.

Either way, finalize the Status issue: move the row to **Finished** with the PR number (or note the direct merge), and remove the `in-progress` label. Confirm in one line.
