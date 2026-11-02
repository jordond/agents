---
name: workon
description: Implement an already-planned GitHub issue end to end using subagents in an isolated git worktree. Use when the user wants to execute existing work — "work on #N", "implement issue 12", "build the plan", "start that ticket", "tackle <thing that already has a plan/issue>". Parses an issue number, or offers options from the Status board; parallelizes across sub-issues when independent; updates the Status issue throughout and always at the end; then asks how to finish (PR or merge). Requires a plan or issue to exist — if the user describes something new with no plan yet, use /ideate first to research and plan it. For "what should I work on?" with no target chosen, /where-are-we suggests options.
argument-hint: "[issue number, or blank to pick from the board]"
---

Execute a plan. The plan already exists (from `/ideate`); this skill turns it into merged, verified work with minimal supervision — built so the user can drive it remotely from the Claude Code app.

## Output discipline

The user is often watching from a phone. Surface decisions and blockers, not narration. Brief progress beats on long tasks (what's done, what's next), and a tight wrap-up. Let subagents do the verbose work; you report signal.

## What a run costs

Measured on a 12-step client feature (2026-09-04): 17 agents, 1,292 turns, 187M tokens, and the bill was **turns × context**, not model rate. Every agent starts at ~55k tokens of fixed prompt (tool lists, skills, CLAUDE.md, memory) before it does anything, so that overhead alone was 38% of the run. A sonnet agent on a two-model Kotlin slice took 137 turns and cost 4× a comparable session-model agent that took 63. The orchestrator's own 183 turns, a third of them replies to agent notifications, were the single largest line. A device-driving agent burned 14% and delivered nothing.

So optimise turns and context, in this order:

1. **Fewer agents.** One agent per coherent slice, never per file. A slice under ~3 files with a fully written spec is an inline edit or a tiny agent; don't spawn for one grep, one `gh` call, one build.
2. **Unnamed agents, cheapest owner for follow-ups.** Name an agent only for a mid-flight correction; each named agent costs an extra turn per notification. Follow-up work (a review finding, a retry) goes to the owner `/spawn` picks under "One agent, one task, then stop": a warm builder via `SendMessage`, inline if small, else a fresh spawn. Slice sizing and ceilings: `/spawn` § Context budget.
3. **Small onboarding.** Paste the agent's step bullet from the issue into its prompt (a few hundred tokens) instead of telling it to `gh issue view <n>` (thousands, retained every turn). Name the 2–4 files it owns, the helpers that already exist so it doesn't re-derive them, and the files it must not touch. Point at the CLAUDE.md *section* it needs, not the whole file.
4. **Short returns.** Tell each agent exactly what to return and how many lines. Its transcript stays out of your context; its return does not.
5. **Pre-flight the fixed prompt.** Before a long run, tell the user in one line how many MCP servers and plugins are loaded and that disabling the ones this repo doesn't use (mail, calendar, design tools, desktop control) cuts every turn of every agent. Then move on.

## Agent routing

Every agent goes through the `/spawn` routing table and its brief templates; never pass `model:` (the agent files own model and effort):

| Work | Agent |
| --- | --- |
| A slice with judgment: model, screen, use case, repo, test | `builder`, `isolation: "worktree"` |
| ≤3-file exact edit, every value in the prompt: strings/resources, a glossary entry, a rename with its call-site list | `scribe` |
| Lookup returning a `file:line` table, only if one grep won't do | `scout` |
| Review of the branch | `reviewer` |

While builders are out, keep `/spawn`'s watchdog running.

Running a test suite or build is **not** an agent job: run it inline, redirect to a file, and grep for the toolchain's error marker (Gradle/Kotlin `^e: |FAILED|BUILD`, tsc `error TS`, xcodebuild `error:`, pytest `FAILED|ERROR`). Trust the exit code over the grep: non-zero with no match means read the tail. An agent that exists to run one command still pays the 55k start.

## Context budget

Target ≤120k for this orchestrating context; the last run hit 209k by the finish. Proxies that mean **checkpoint now** (tick the board, update the Status row, tell the user to `/clear` and re-run `/workon <n>`):

- The harness warns that auto-compact is near.
- The main code waves have landed and what's left is review, device work, or landing the PR — that's the natural seam.
- You're about to pull in a blob: a full issue body you've already read once, a raw log, a wide diff, a file over a few hundred lines.

**Hold pointers, not payloads.** Issue numbers, file paths, step status, decisions. `git diff --stat` first; `gh issue view` once, then work from the board's checkboxes.

## Status issue contract

The board contract (row format, `planned` marker, fetch-before-write) lives in `where-are-we`'s "Shared rules"; follow it on every write. Find the board with:

```bash
gh issue list --search "Status in:title" --state open --json number,title --jq '.[] | select(.title=="Status") | .number'
```

`/workon` moves the item TODO/Up Next → **In Progress** (recording branch + worktree), and → **Finished** only once the work is merged. Update it during long work when state changes; **always** update it at the end.

## Procedure

### 1. Resolve the target
- **Resume first.** If the Status row for the target is already **In Progress** with a worktree, this is a resumed run: `cd` into that worktree, read the issue's checkboxes (`gh issue view <n> --json body --jq .body | grep -n '\- \['`), skip Steps 2–3, and start Step 4 at the first unticked step. Don't re-read the full body.
- `$ARGUMENTS` has an issue number → `gh issue view <n>` once; it is the only time the body enters your context.
- Blank → read the Status issue and offer **Up Next** (and resumable **In Progress**) items; let the user pick. If they describe something with no plan, point them to `/ideate` first.
- A **master** issue with sub-issues: read the master only, list the subs with `gh issue list --search '"Part of #<master>" in:body' --state open --json number,title`, take the dependency order from the master's checklist. Each implementing agent gets its own sub-issue's text pasted, not a `gh` command.

### 2. Set up an isolated worktree (default)
Work in a git worktree unless the user says otherwise; it keeps their main checkout free. This is the **feature worktree**; builders get their own worktrees and merge into it.
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

### 4. Implement in waves
Subagent-driven, but wave-shaped. These rules win over any general subagent or TDD skill that would add per-task agents or reviews.

**You don't read source.** If you're reaching for a file to understand it, that's an agent's job. Your job is dispatch, sequencing, and the board.

- **Wave A lands the shared surface first**: the domain types, the test fakes, routes, and every string/resource the later steps will need, in one small wave. Then parallel slices never edit the same file and never wait on each other.
- **Wave B runs the independent slices in parallel**: one `builder` per slice (up to four at a time), each owning disjoint files listed in its brief. Put the feature branch's tip SHA in the brief's `Verified at:` and `Base:` lines so the builder branches from it. Builders run lint and tests for their touched modules only; the full build is your gate.
- **Merge each green builder branch into the feature branch as it lands.** After each wave, run one gate inline in the feature worktree (compile + tests + `check --fix`), commit, tick the boxes. A red gate: bisect over the wave's merges. Route the fix per `/spawn` (warm builder, inline if ~40 lines or less, else fresh).
- **Sub-issues that touch the same files run in sequence**, the second starting after the first has merged. Disjoint sub-issues can run in parallel.
- State the wave plan in one line before launching.

Builders commit in their own worktrees; only you commit or merge on the feature branch. Scouts, scribes and reviewers never commit, stash or checkout.

Hold the quality bar: follow existing repo conventions, no AI anti-patterns (em-dash prose, dead comments, speculative abstraction). `deslopify` and `refine` are there for a cleanup pass if useful.

### 5. Verify before claiming done
Run the project's tests/build/lint inline and confirm they pass — evidence, not assertion. Don't report success on unverified work.

Then one **read-only review agent** on `git diff main...HEAD` with the lenses that matter for this change (the last run's reviewer cost 7M and found two majors nobody else had). Cap its return at ~15 `path:line: severity: problem. fix.` lines. Route what survives per `/spawn` (one builder for the batch, or inline if small), then **re-run the inline verification and commit**. The fixes are unverified until then.

**Generated artifacts stamped against sources** (baseline profiles, snapshots, codegen outputs) regenerate once, *after* merging `main` into the branch, immediately before the final push. Regenerating earlier means doing it twice.

**Device work is not an agent job.** A simulator/emulator pass (fixtures, Maestro flows, pixel baselines) runs in this session, one bounded slice at a time, with a hard stop rule: two failed inspects or taps on the same screen → stop and report. If the goal is to land the PR, default to shipping with the unit/compile evidence and listing the owed device pass in the PR body and your final reply; ask the user before starting one.

### 6. Update the board — it's your memory
Tick the plan's checkboxes on the issue as steps land and keep the Status row current with branch, worktree, and next step. When work is verified complete, that's a required step — don't skip it even if finishing fast.

Because the board is durable, a long run doesn't need one continuous context. A resumed `/workon <n>` reads the board, sees the ticked boxes, and starts at the first unticked step — no re-discovery, no re-reading finished work.

### 7. Finish — ask the user
Present the result (one line: what was built, tests green) and ask how to land it, unless the user already said:
- **PR + clean up:** merge `origin/main` into the branch first (a CONFLICTING PR runs no checks), push, `gh pr create` (body closes the issue, e.g. `Closes #<n>`), wait for CI with a background poll, then `gh pr merge --squash --delete-branch` if asked to merge. Remove the worktree only after the merge, or leave it if the PR stays open.
- **Merge to main now:** the main checkout must be clean (`git -C <main checkout> status --porcelain` empty; otherwise stop and ask). Then in the main checkout: `git pull --ff-only`, merge the branch, re-run the inline verification, push, remove the worktree.

Then finalize the Status issue:
- **Merged** (PR merged or direct merge) → move the row to **Finished** with the PR number (or note the direct merge) and remove the `in-progress` label.
- **PR open, not merged** → keep the row in **In Progress** with `PR #<m> open` in Notes, and keep the label. `where-are-we` moves it to Finished on merge.
- Either way, add a TODO row only for a follow-up feature or a bug found. Owed verification, device passes, sign-offs and ops steps go in the PR body and your reply, never the board.

Confirm in one line.

## Measuring a run
Per-agent tokens live in the transcripts. Sum `message.usage` over assistant turns in `~/.claude/projects/<project>/<session>/subagents/*.jsonl` (and the session's own `.jsonl`): fresh input = `input_tokens + cache_creation_input_tokens`, plus `cache_read_input_tokens` and `output_tokens`. Turn count and context at the last turn tell you which agent to redesign.
