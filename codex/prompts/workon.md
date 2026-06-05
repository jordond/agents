# workon

Execute an already-planned GitHub issue end to end. The plan already exists (from `/ideate`); this turns it into merged, verified work. Requires a plan or issue — if I describe something new with no plan yet, use `/ideate` first. For "what should I work on?" with no target chosen, `/where-are-we` suggests options.

Argument (`$ARGUMENTS`): an issue number. Blank → offer options from the board.

## Output discipline

I'm often watching from a phone. Surface decisions and blockers, not narration. Brief progress beats on long tasks (what's done, what's next), and a tight wrap-up. Report signal, not noise.

## Status issue contract

One issue per repo, title `Status`, label `status`. `/workon` moves the item TODO/Up Next → **In Progress** (recording the branch) and, on completion, → **Finished** with the PR. Update it during long work when state changes; **always** update it at the end. (Full board: see `/where-are-we`.)

## Procedure

### 1. Resolve the target
- `$ARGUMENTS` has an issue number → `gh issue view <n>`.
- Blank → read the Status issue and offer **Up Next** (and resumable **In Progress**) items; let me pick. If I describe something with no plan, point me to `/ideate` first.
- Read the issue body. If it's a **master** issue with linked sub-issues, fetch those too.

### 2. Create a feature branch
Work on a dedicated branch, not the base branch:
```bash
git switch -c feat/issue-<n>-<slug>
```
(If parallel slices would touch the same files, a separate `git worktree add` per slice avoids collisions — optional.)

### 3. Mark In Progress
```bash
gh label create in-progress --color FBCA04 2>/dev/null || true
gh issue edit <n> --add-label in-progress
```
Move the row to **In Progress** in the Status issue with the branch name.

### 4. Implement
Work the plan in coherent, ordered steps. Follow the plan's steps; for a master issue, complete each sub-issue's slice in dependency order.

Hold the quality bar: follow existing repo conventions, no AI anti-patterns (em-dash prose, dead comments, speculative abstraction). Run `/deslopify` and `/refine` for a cleanup pass when useful.

### 5. Verify before claiming done
Run the project's tests/build/lint and confirm they pass — evidence, not assertion. Don't report success on unverified work.

### 6. Update the board
Tick the plan's checkboxes on the issue as steps land (during long runs).

### 7. Finish — ask me
Present the result (one line: what was built, tests green) and ask how to land it:
- **PR:** push the branch, `gh pr create` (body closes the issue, e.g. `Closes #<n>`).
- **Merge to main now:** merge the branch into the base, push.
- If you used a worktree, `git worktree remove` it once landed.

Either way, finalize the Status issue: move the row to **Finished** with the PR number (or note the direct merge), and remove the `in-progress` label. Confirm in one line.
