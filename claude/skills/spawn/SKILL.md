---
name: spawn
description: Route a task to the right custom subagent (scout, analyst, builder, reviewer, scribe) with the right model, isolation, and a compact brief. Use whenever the user wants work delegated — "spawn an agent", "launch a worker", "delegate this", "hand this off", "fire off a subagent", "run this in the background", "have an agent look at / build / review X". Picks the agent from the task shape, fills the brief template so the user never repeats onboarding, caps the return, and reports one line. Not for /workon (full issue pipeline) or /ideate (planning); those call this routing internally.
argument-hint: "[what to delegate, or blank to be asked]"
---

Delegate one task to one of the five user-wide agents in `~/.claude/agents/`. The agent file already fixes the **model** and **tools**; your job is to pick the agent, write a small brief, and relay a short return.

## Output discipline

One line on dispatch: `spawned <agent> (<model>) → <slice>`. On return, relay the agent's report as-is (it is already capped) plus at most 2 lines of your own. No narration between.

## Route by task shape

| Task shape | Agent | Model (from agent file) | Effort (from agent file) | Extra |
| --- | --- | --- | --- | --- |
| Where is X / what calls Y / which files own Z; answer spans several files | `scout` | haiku | n/a (Haiku has no effort) | none |
| How does X work / trace a subsystem / verify a package API against the lockfile / write a research note | `analyst` | sonnet | high | none |
| Implement a written slice: edits with judgement, new behaviour, tests | `builder` | opus | high | `isolation: "worktree"` always |
| Review a diff or branch before merge | `reviewer` | sonnet | xhigh | pass the base ref |
| Exact edit, ≤3 files, every value already known: board rows, doc tables, JSON/config fields, report assembly | `scribe` | sonnet | medium | none |
| Fits none of the above | `general-purpose` | session | session | say so in the dispatch line |

Ambiguity rules:
- "Look at / check / find" with no fix wanted → `scout` if the answer is locations, `analyst` if it is an explanation.
- "Fix / change / add" → `scribe` if you can write the exact diff in the prompt, otherwise `builder`.
- The user names an agent explicitly → use it, even if the table says otherwise.
- The user names a model → pass `model:` as an override; otherwise **never** pass `model:`, reviewers included. The agent file owns model and effort, and a `model:` on the call beats the file.

## Do not spawn

One grep, one file read, one `gh` call, one build or test run: do it inline. Every agent pays ~55k tokens of fixed prompt before its first action, so a spawn only wins when the transcript would be long and the return can be short. If the user insists, spawn anyway and skip the lecture.

## Context budget

Cost is **turns × context**, but wall time is **turns × latency**, and every new agent pays its way in again: ~55k of fixed prompt, then a median 38 tool calls and 5 minutes of reading before its first edit (MaterialKolor builder v2, 208 builder runs). Tiny slices multiply that toll. Size the slice by file ownership and feature, so the agent finishes under **250k tokens** of context; **400k is the ceiling** and means the slice was cut wrong.

- Prefer one slice that owns a whole feature over three that each own a file of it. Split only when two parts can run in parallel on disjoint files, or when one part alone would pass the ceiling.
- Tell the agent its budget in the brief (`Budget: finish under 250k context`), so it reads the named files and stops exploring instead of reading the tree.
- Never paste a whole issue, plan, or file dump into a brief when a section will do. Every retained token is paid on every turn.
- If an agent reports it is near its ceiling or its return is unfinished, do not extend it. Take what it produced, write a brief for the remainder, and spawn fresh.

## One agent, one task, then stop

**Pick the cheapest owner for follow-up work.** A finished agent still holds its whole transcript, so a message to it costs the old context plus the new work, but it skips the re-reading a fresh agent pays for.

- A small fix to a slice that just landed (a clipped row, a missed case, a review finding in the files it owned) goes back to the **same builder** with `SendMessage` while it is warm: it reported within the last hour and is under ~250k. On the builder v2 audit that took 10 minutes, against about 20 for a fresh builder.
- A fix of about 40 lines in one module with an obvious cause you make **inline**, with that module's tests.
- Everything else (a new slice, a builder near its ceiling, a second angle on a question) is a **new spawn** with the prior result pasted in as `Context:`, trimmed to what the new task needs.
- When an agent is done for good, stop it (`TaskStop`) if it is still resident, and carry forward only its report.

## Brief templates

Paste the task text into the prompt; never tell the agent to go fetch it (`gh issue view`, "read the plan") — that costs thousands of retained tokens per turn. Point at the CLAUDE.md *section* it needs, not the whole file. Fill only the lines that apply; drop the rest.

**scout**
```
Question: <one line>
Scope: <dir or package, or "repo">
Return: one-line answer + file:line table, ≤30 rows.
```

**analyst**
```
Question: <one line>
Read first: <2–4 paths or CLAUDE.md section>
Constraints: <invariants, locked decisions, pinned versions if relevant>
Budget: finish under 150k context; read the named paths, do not survey the tree.
Return: ≤40 lines — answer, file:line evidence, open questions. [Write research note to <path> if asked.]
```

**builder** (spawn with `isolation: "worktree"`)
```
Brief: <the slice, pasted verbatim from the issue/plan>
Owns: <2–4 files it may edit>
Do not touch: <files>
Read first: <paths / CLAUDE.md section>; existing helpers: <names, so it doesn't re-derive them>
Verified at: <sha>. Every path, type and signature named above was checked against it, so do not re-survey.
Checks: <lint + tests of the touched modules only; the orchestrator gates the batch>; run budget: <n> runs, then commit and report.
Budget: finish under 250k context; if you cannot, commit what is done and report what is left.
Return: the 40-line report from your agent definition.
```

**reviewer**
```
Diff: git diff <base>...<branch>   [or: staged / working tree]
Brief / ownership list: <paste if one exists>
Lenses that matter here: <e.g. correctness, layer boundaries, companion edits>
Return: ≤15 lines `path:line: severity: problem. fix.` + verdict.
```

**scribe**
```
Files: <≤3 paths>
Edit: <exact text / rows / fields to write, verbatim>
Check: <validator or "none">
Return: ≤8 lines.
```

## Dispatch rules

- **Unnamed by default.** Pass `name:` only when you expect to send a mid-flight correction before the agent reports. A named agent costs you an extra turn per notification. Naming is not a licence to reuse it after it reports (see above).
- **Parallel by default.** Several scouts on different angles, or builders on disjoint file sets (up to four at a time), go in one message. Only builders sharing a file go in sequence.
- **Background by default** for builder and analyst; you keep working. Scout and scribe are short; wait for them.
- **Verify the brief, not the builder.** Before dispatch, check the brief's paths, types and signatures against the tip yourself and write the SHA into it. No analyst pre-draft: an extra hop per slice costs more than the grep it saves.
- **Review per batch, not per slice.** Merge each green slice as it lands. After every three or four merges run one gate (build, tests, lint, e2e where the project has them) and one `reviewer` on the whole range. A red gate is bisected over the first-parent merges. Fix slices are only for real bugs, each with a failing test first; nits go on one polish list, done in a single slice at the milestone end. On builder v2, per-slice review and fix hops turned 117 merges into 51 follow-up slices and about 60 fix slices.
- **Relay, don't reprocess.** The agent's return is already the user-facing report. Quote it; add a verdict or a next step only if the user needs one.
- A project-level `.claude/agents/<name>.md` with the same name overrides the user-wide one automatically; nothing to do.

## Watch running builders

Nothing tells you when a background agent is stuck: a hung test or a dead agent just goes quiet. Whenever builders are out, keep the watchdog running with `run_in_background: true`:

```
python3 ~/.claude/skills/spawn/watchdog.py --repo <repo root> --session <your session id>
```

Your session id is the directory name in your scratchpad path. The watchdog exits, and its notification wakes you, the moment an agent is **HUNG** (a test JVM in its worktree past 6 minutes, with the stuck frame), **STALLED** (no transcript change for 15 minutes) or **OVERTIME** (past 60 minutes). Act on each flag: send the builder the stuck frame, stop it and merge what it committed, or resume it if it died on an API error. Then restart the watchdog with `--ack <agent-id>:<KIND>` for each flag you chose to leave running. When the user asks whether something is still going, check the worktree and its processes before answering, and never promise a time you have not measured.

## When the request is empty

Ask one line: "What should it do, and is it locate / explain / build / review / exact edit?" Then route.
