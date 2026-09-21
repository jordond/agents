---
name: workon
description: Implement an already-planned GitHub issue end to end using subagents in an isolated git worktree. Use when the user wants to execute existing work — "work on #N", "implement issue 12", "build the plan", "start that ticket", "tackle <thing that already has a plan/issue>". Parses an issue number or plan, or offers options from the Status board; parallelizes across sub-issues when independent; updates the Status issue throughout and always at the end; then asks how to finish (PR or merge). Requires a plan or issue to exist — if the user describes something new with no plan yet, use /ideate first to research and plan it. For "what should I work on?" with no target chosen, /where-are-we suggests options.
argument-hint: "[issue number, or blank to pick from the board]"
---

Execute a plan. The plan already exists (from `/ideate`); this skill turns it into merged, verified work with minimal supervision — built so the user can drive it remotely from the Claude Code app.

## Output discipline

The user is often watching from a phone. Surface decisions and blockers, not narration. Brief progress beats on long tasks (what's done, what's next), and a tight wrap-up. Let subagents do the verbose work; you report signal.

## What a run costs

Measured on a 12-step client feature (2026-09-04): 17 agents, 1,292 turns, 187M tokens, and the bill was **turns × context**, not model rate. Every agent starts at ~55k tokens of fixed prompt (tool lists, skills, CLAUDE.md, memory) before it does anything, so that overhead alone was 38% of the run. A sonnet agent on a two-model Kotlin slice took 137 turns and cost 4× a comparable session-model agent that took 63. The orchestrator's own 183 turns, a third of them replies to agent notifications, were the single largest line. A device-driving agent burned 14% and delivered nothing.

So optimise turns and context, in this order:

1. **Fewer agents.** One agent per coherent slice, never per file. A slice under ~3 files with a fully written spec is an inline edit or a tiny agent; don't spawn for one grep, one `gh` call, one build.
2. **Unnamed agents by default.** A named teammate delivers its result *and* an idle notification, and each costs you a full turn at your current context. Name an agent only when you expect to message it again (the build owner of a wave, a reviewer whose fixes you will hand back).
3. **Small onboarding.** Paste the agent's step bullet from the issue into its prompt (a few hundred tokens) instead of telling it to `gh issue view <n>` (thousands, retained every turn). Name the 2–4 files it owns, the helpers that already exist so it doesn't re-derive them, and the files it must not touch. Point at the CLAUDE.md *section* it needs, not the whole file.
4. **Short returns.** Tell each agent exactly what to return and how many lines. Its transcript stays out of your context; its return does not.
5. **Pre-flight the fixed prompt.** Before a long run, tell the user in one line how many MCP servers and plugins are loaded and that disabling the ones this repo doesn't use (mail, calendar, design tools, desktop control) cuts every turn of every agent. Then move on.

## Model routing

| Work | Model |
| --- | --- |
| Anything that edits a model, screen, use case, repo, or test with judgment in it | omit `model:` — session model |
| ≤3-file mechanical slices with the exact edit in the prompt: strings/resources, a glossary entry, a preview fix, a rename with the list of call sites | `sonnet` |
| Pure lookup returning a `file:line` table | `haiku`, and only if you can't do it with one grep yourself |

Running a test suite or build is **not** an agent job: run it inline, redirect to a file, grep for `^e: |FAILED|BUILD`, and read only that. An agent that exists to run one command still pays the 55k start.

## Context budget

Target ≤120k for this orchestrating context; the last run hit 209k by the finish. Proxies that mean **checkpoint now** (tick the board, update the Status row, tell the user to `/clear` and re-run `/workon <n>`):

- The harness warns that auto-compact is near.
- The main code waves have landed and what's left is review, device work, or landing the PR — that's the natural seam.
- You're about to pull in a blob: a full issue body you've already read once, a raw log, a wide diff, a file over a few hundred lines.

**Hold pointers, not payloads.** Issue numbers, file paths, step status, decisions. `git diff --stat` first; `gh issue view` once, then work from the board's checkboxes.

## Status issue contract

One issue per repo, title `Status`, label `status`. `/workon` moves the item TODO/Up Next → **In Progress** (recording branch + worktree) and, on completion, → **Finished** with the PR. Update it during long work when state changes; **always** update it at the end. (Full board: see the `where-are-we` skill.)

## Procedure

### 1. Resolve the target
- `$ARGUMENTS` has an issue number → `gh issue view <n>` once; it is the only time the body enters your context.
- Blank → read the Status issue and offer **Up Next** (and resumable **In Progress**) items; let the user pick. If they describe something with no plan, point them to `/ideate` first.
- A **master** issue with sub-issues: read the master only, list the subs with `gh issue list --json number,title`, take the dependency order from the master's body. Each implementing agent gets its own sub-issue's text pasted, not a `gh` command.

### 2. Set up an isolated worktree (default)
Work in a git worktree unless the user says otherwise — it keeps their main checkout free and lets parallel agents avoid collisions. If the `using-git-worktrees` skill is available, use it; otherwise:
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
Subagent-driven, but wave-shaped. If the `subagent-driven-development` and `test-driven-development` skills are available, follow them.

**You don't read source.** If you're reaching for a file to understand it, that's an agent's job. Your job is dispatch, sequencing, and the board.

- **Wave A lands the shared surface first**: the domain types, the test fakes, routes, and every string/resource the later steps will need, in one small wave. Then parallel slices never edit the same file and never wait on each other.
- **Wave B runs the independent slices in parallel**, each owning disjoint files (list them in every prompt). **One build owner per wave**: exactly one agent may run Gradle/xcodebuild/tsc; the rest write and run the linter on their files only. Concurrent builds in one worktree corrupt each other's outputs and cost each agent a compile per turn.
- **After each wave you run one verification inline** (compile + tests + `check --fix`), commit, tick the boxes. Hand a failure back to the agent that owns the file only if it's still cheap; a one-line fix is yours to make.
- **Sub-issues that touch the same files** get their own worktree, merged after.
- State the wave plan in one line before launching.

Agents never commit, stash, or checkout. You commit at the wave boundary.

Hold the quality bar: follow existing repo conventions, no AI anti-patterns (em-dash prose, dead comments, speculative abstraction). The `deslopify` and `refine` skills exist for a cleanup pass if useful.

### 5. Verify before claiming done
Run the project's tests/build/lint inline and confirm they pass — evidence, not assertion. If the `verification-before-completion` skill is available, follow it. Don't report success on unverified work.

Then one **read-only review agent** on `git diff main...HEAD` with the lenses that matter for this change (the last run's reviewer cost 7M and found two majors nobody else had). Cap its return at ~15 `path:line: severity: problem. fix.` lines. One fixer agent applies what survives.

**Generated artifacts stamped against sources** (baseline profiles, snapshots, codegen outputs) regenerate once, *after* merging `main` into the branch, immediately before the final push. Regenerating earlier means doing it twice.

**Device work is not an agent job.** A simulator/emulator pass (fixtures, Maestro flows, pixel baselines) runs in this session, one bounded slice at a time, with a hard stop rule: two failed inspects or taps on the same screen → stop and report. If the goal is to land the PR, default to shipping with the unit/compile evidence and capturing the device pass as a TODO row; ask the user before starting one.

### 6. Update the board — it's your memory
Tick the plan's checkboxes on the issue as steps land and keep the Status row current with branch, worktree, and next step. When work is verified complete, that's a required step — don't skip it even if finishing fast.

Because the board is durable, a long run doesn't need one continuous context. A resumed `/workon <n>` reads the board, sees the ticked boxes, and starts at the first unticked step — no re-discovery, no re-reading finished work.

### 7. Finish — ask the user
Present the result (one line: what was built, tests green) and ask how to land it, unless the user already said:
- **PR + clean up:** merge `origin/main` into the branch first (a CONFLICTING PR runs no checks), push, `gh pr create` (body closes the issue, e.g. `Closes #<n>`), wait for CI with a background poll, then `gh pr merge --squash --delete-branch` if asked to merge. Remove the worktree. If `finishing-a-development-branch` skill is available, use it.
- **Merge to main now:** merge the branch into main, push, remove the worktree.

Either way, finalize the Status issue: move the row to **Finished** with the PR number (or note the direct merge), add a TODO row for anything owed, and remove the `in-progress` label. Confirm in one line.

## Measuring a run
Per-agent tokens live in the transcripts. Sum `message.usage` over assistant turns in `~/.claude/projects/<project>/<session>/subagents/*.jsonl` (and the session's own `.jsonl`): fresh input = `input_tokens + cache_creation_input_tokens`, plus `cache_read_input_tokens` and `output_tokens`. Turn count and context at the last turn tell you which agent to redesign.
