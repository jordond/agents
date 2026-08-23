---
name: workon
description: Implement an already-planned GitHub issue end to end using subagents in an isolated git worktree. Use when the user wants to execute existing work — "work on #N", "implement issue 12", "build the plan", "start that ticket", "tackle <thing that already has a plan/issue>". Parses an issue number or plan, or offers options from the Status board; parallelizes across sub-issues when independent; updates the Status issue throughout and always at the end; then asks how to finish (PR or merge). Requires a plan or issue to exist — if the user describes something new with no plan yet, use /ideate first to research and plan it. For "what should I work on?" with no target chosen, /where-are-we suggests options.
argument-hint: "[issue number, or blank to pick from the board]"
---

Execute a plan. The plan already exists (from `/ideate`); this skill turns it into merged, verified work with minimal supervision — built so the user can drive it remotely from the Claude Code app.

## Output discipline

The user is often watching from a phone. Surface decisions and blockers, not narration. Brief progress beats on long tasks (what's done, what's next), and a tight wrap-up. Let subagents do the verbose work; you report signal.

## Model routing

Subagents keep your context lean, but each one still burns tokens. Pass `model:` on every `Agent` call so the cost matches the work:

| Work | Model |
| --- | --- |
| Locating files, listing call sites, grepping for a convention, running tests and reporting pass/fail | `haiku` |
| Tracing dataflow, summarizing a subsystem, mechanical implementation slices (boilerplate, renames, test scaffolding, docs, config) | `sonnet` |
| Core logic, the plan's real design decisions, anything where a wrong judgment costs a rewrite | omit `model:` — inherits the session model |

Cheaper than any model: **not spawning**. One file read, one grep, one `gh` command — do it inline.

**Keep returns small.** A subagent's own tokens stay out of your context; its *return value* does not. Tell each one exactly what to return and how short — a `file:line` table, a decision list, pass/fail plus the failing output — never a narrated walkthrough or pasted file contents.

## Context budget

Target: keep this orchestrating context under ~150k tokens. You can't measure it directly, so act on the first proxy that trips:

- The harness warns that auto-compact is near → **checkpoint now**. A deliberate handoff beats a lossy auto-summary.
- You're about to pull in a blob — a full issue body, a raw test log, a wide `git diff`, a source file over a few hundred lines → that's the leak. Route it through a subagent instead.

**Hold pointers, not payloads.** Issue numbers, file paths, step status, resolved decisions. Bodies, diffs, and logs live on GitHub and on disk; a subagent fetches what it needs when it needs it and returns a summary.

**Trim output at the source:**
- `gh issue list --json number,title,labels` to enumerate; `gh issue view <n>` only for the issue you're acting on right now.
- `git diff --stat` first; full `git diff` only for a specific file you must judge yourself.
- Never pipe a raw build/test log into context — a subagent runs it and returns pass/fail plus the failing lines.

## Status issue contract

One issue per repo, title `Status`, label `status`. `/workon` moves the item TODO/Up Next → **In Progress** (recording branch + worktree) and, on completion, → **Finished** with the PR. Update it during long work when state changes; **always** update it at the end. (Full board: see the `where-are-we` skill.)

## Procedure

### 1. Resolve the target
- `$ARGUMENTS` has an issue number → `gh issue view <n>`.
- Blank → read the Status issue and offer **Up Next** (and resumable **In Progress**) items; let the user pick. If they describe something with no plan, point them to `/ideate` first.
- Read the issue body. If it's a **master** issue with linked sub-issues, read the master only — list the subs with `gh issue list --json number,title` and take the dependency order from the master's body. **Don't pull sub-issue bodies into your context**; each implementing subagent runs `gh issue view <sub#>` for its own slice.

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

**You don't read source.** If you're reaching for a file to understand it, that's a subagent's job — dispatch one and take its summary. Your job is dispatch, sequencing, and the board.

- **Single plan:** dispatch a subagent per coherent step/slice, sequentially where steps depend on each other. Route by slice, not by habit: mechanical slices (boilerplate, renames, test scaffolding, docs, config, wiring an already-designed interface) go to `sonnet`; slices carrying the plan's real design decisions inherit the session model.
- **Multiple sub-issues:** determine which are independent and run those **in parallel** (separate subagents, each on its slice within the worktree — or its own worktree if they'd touch the same files). Sequence only the genuinely dependent ones. State the parallelization plan in one line before launching.

Hold the quality bar: follow existing repo conventions, no AI anti-patterns (em-dash prose, dead comments, speculative abstraction). The `deslopify` and `refine` skills exist for a cleanup pass if useful.

### 5. Verify before claiming done
Run the project's tests/build/lint and confirm they pass — evidence, not assertion. If the `verification-before-completion` skill is available, follow it. Don't report success on unverified work.

Running the suite is a `haiku` job: have it return the commands run, pass/fail per command, and the failing output only — no green log dumps. Diagnosing a failure is not — bring that back to the session model or a `sonnet` subagent with the failure text.

### 6. Update the board — it's your memory
Tick the plan's checkboxes on the issue as steps land (during long runs) and keep the Status row current with branch, worktree, and next step. When work is verified complete, that's a required step — don't skip it even if finishing fast.

Because the board is durable, a long run doesn't need one continuous context. **To checkpoint:** tick what landed, update the Status row, then tell the user in one line to clear context and re-run `/workon <n>`. A resumed run reads the board, sees the ticked boxes, and starts at the first unticked step — no re-discovery, no re-reading finished work.

### 7. Finish — ask the user
Present the result (one line: what was built, tests green) and ask how to land it:
- **PR + clean up:** push the branch, `gh pr create` (body closes the issue, e.g. `Closes #<n>`), then `git worktree remove` the worktree once the PR is open. If `finishing-a-development-branch` skill is available, use it.
- **Merge to main now:** merge the branch into main, push, remove the worktree.

Either way, finalize the Status issue: move the row to **Finished** with the PR number (or note the direct merge), and remove the `in-progress` label. Confirm in one line.
