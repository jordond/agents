---
name: spawn
description: Route a task to the right custom subagent (scout, analyst, builder, reviewer, scribe) with the right model, isolation, and a compact brief. Use whenever the user wants work delegated — "spawn an agent", "launch a worker", "delegate this", "hand this off", "fire off a subagent", "run this in the background", "have an agent look at / build / review X". Picks the agent from the task shape, fills the brief template so the user never repeats onboarding, caps the return, and reports one line. Not for /workon (full issue pipeline) or /ideate (planning); those call this routing internally.
argument-hint: "[what to delegate, or blank to be asked]"
---

Delegate one task to one of the five user-wide agents in `~/.claude/agents/`. The agent file already fixes the **model** and **tools**; your job is to pick the agent, write a small brief, and relay a short return.

## Output discipline

One line on dispatch: `spawned <agent> (<model>) → <slice>`. On return, relay the agent's report as-is (it is already capped) plus at most 2 lines of your own. No narration between.

## Route by task shape

| Task shape | Agent | Model (from agent file) | Extra |
| --- | --- | --- | --- |
| Where is X / what calls Y / which files own Z; answer spans several files | `scout` | haiku | none |
| How does X work / trace a subsystem / verify a package API against the lockfile / write a research note | `analyst` | sonnet | none |
| Implement a written slice: edits with judgement, new behaviour, tests | `builder` | opus | `isolation: "worktree"` always |
| Review a diff or branch before merge | `reviewer` | sonnet | pass the base ref |
| Exact edit, ≤3 files, every value already known: board rows, doc tables, JSON/config fields, report assembly | `scribe` | sonnet | none |
| Fits none of the above | `general-purpose` | session | say so in the dispatch line |

Ambiguity rules:
- "Look at / check / find" with no fix wanted → `scout` if the answer is locations, `analyst` if it is an explanation.
- "Fix / change / add" → `scribe` if you can write the exact diff in the prompt, otherwise `builder`.
- The user names an agent explicitly → use it, even if the table says otherwise.
- The user names a model → pass `model:` as an override; otherwise **never** pass `model:`. The agent file owns it.

## Do not spawn

One grep, one file read, one `gh` call, one build or test run: do it inline. Every agent pays ~55k tokens of fixed prompt before its first action, so a spawn only wins when the transcript would be long and the return can be short. If the user insists, spawn anyway and skip the lecture.

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
Return: ≤40 lines — answer, file:line evidence, open questions. [Write research note to <path> if asked.]
```

**builder** (spawn with `isolation: "worktree"`)
```
Brief: <the slice, pasted verbatim from the issue/plan>
Owns: <2–4 files it may edit>
Do not touch: <files>
Read first: <paths / CLAUDE.md section>; existing helpers: <names, so it doesn't re-derive them>
Checks: <lint + test targets>; run budget: <n> runs, then commit and report.
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

- **Unnamed by default.** Pass `name:` only when you will message the agent again (a build owner you will hand fixes back to). A named agent costs you an extra turn per notification.
- **Parallel when independent.** Several scouts on different angles, or builders on disjoint file sets, go in one message. Builders sharing a file go in sequence or in separate worktrees.
- **Background by default** for builder and analyst; you keep working. Scout and scribe are short; wait for them.
- **Chain, don't merge.** Locate (`scout`) → implement (`builder`) → review (`reviewer`) → apply survivors (`scribe` or `builder`). Never ask one agent to do two of those.
- **Relay, don't reprocess.** The agent's return is already the user-facing report. Quote it; add a verdict or a next step only if the user needs one.
- A project-level `.claude/agents/<name>.md` with the same name overrides the user-wide one automatically; nothing to do.

## When the request is empty

Ask one line: "What should it do, and is it locate / explain / build / review / exact edit?" Then route.
