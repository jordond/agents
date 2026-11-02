---
name: ideate
description: Turn a rough idea or a backlog TODO into a researched, build-ready plan and GitHub issue(s). Use when the user wants to plan, flesh out, spec, scope, design, or "ideate" a feature or task before writing code. Asks targeted clarifying questions with recommendations, researches with concrete evidence (never guesses), writes the plan(s) via subagents, creates the issue(s), updates the Status board, and hands off to /workon. Use this — not /workon — whenever there is no written plan or issue yet, even if the user says "build" or "implement": planning and research come first. Once a plan/issue exists, /workon executes it.
argument-hint: "[a TODO, issue, or new idea — or blank to pick from the board]"
---

Take something fuzzy and turn it into a plan precise enough that `/workon` can execute it with subagents and no further discovery. Quality of the plan comes from **evidence**, not assumption.

## Output discipline

You'll do a lot of research, but the user only sees: the clarifying questions, the continuation prompt, and the final handoff. Don't narrate research as you go. Keep questions tight. Tokens spent reading the codebase are worth it; tokens spent describing your reading are not.

## Agent routing

Research subagents go through the `/spawn` routing table: `scout` for locating (where is X, what calls Y, does the repo already do Z), `analyst` for judgment (how a subsystem hangs together, verifying an external API against the pinned version). Brief each with spawn's template for that agent, including its budget line. The agent files own model and effort; don't pass `model:`. The one exception is plan writing (Step 6).

Cheaper than any agent: **not spawning**. One file read, one grep, one `gh` command: do it inline.

**Keep returns small.** A subagent's own tokens stay out of your context; its *return value* does not. Tell each one exactly what to return and how short — a `file:line` table, a decision list, pass/fail plus the failing output — never a narrated walkthrough or pasted file contents.

## Context budget

Target: keep this orchestrating context under ~150k tokens. You can't measure it directly, so act on the first proxy that trips:

- The harness warns that auto-compact is near → **checkpoint now**. A deliberate handoff beats a lossy auto-summary.
- You're about to pull in a blob — a full issue body, a raw source file, the output of a wide grep → that's the leak. Route it through a subagent instead.

**Hold pointers, not payloads.** File paths, issue numbers, resolved decisions, the one-line finding — not the file contents that produced it. A subagent reads the code; you keep its conclusion.

**Trim output at the source:**
- `gh issue list --json number,title,labels` to enumerate; `gh issue view <n>` for the one issue you're actually reading.
- Don't cat whole files to skim them — `grep -n` for the symbol, or send a subagent.

## Status issue contract

The board contract (lookup command, row format, missing-board handling, `planned` marker, write rules) lives in the `where-are-we` skill's Status issue contract; follow it. Find the board with:

```bash
gh issue list --search "Status in:title" --state open --json number,title --jq '.[] | select(.title=="Status") | .number'
```

If it doesn't exist, create it as `where-are-we` does. `/ideate` adds or promotes a row to **Up Next** carrying the plan issue's `#`.

## Procedure

### 1. Choose the target
- `$ARGUMENTS` starts with `continue:` → a pasted checkpoint from Step 4. Load its decisions and evidence and jump to Step 5. Don't re-research.
- `$ARGUMENTS` names an existing issue (`#N`) → `gh issue view <n> --json title,body` once. Its body is input: carry its requirements and acceptance criteria forward as decisions, and keep the original text for the plan's `## Original request` section. Step 7 updates that issue instead of creating a new one.
- `$ARGUMENTS` names a TODO or a new idea → use it.
- Blank → find the Status issue (see Status issue contract) and offer the open TODOs (plus "something new"). Let the user pick. If there is no Status issue, ask for the idea directly; Step 7 creates the board.

### 2. Research with evidence — do not guess
This is the core of a good plan. Before asking anything, build a concrete picture:
- Find the real files, patterns, and constraints involved. Fan out with parallel `scout`s for breadth and an `analyst` when the answer needs judgment (see Agent routing). Read code yourself only where a wrong assumption would break the plan: a handful of files, not a survey.
- Confirm how similar things are already done in this repo so the plan matches existing conventions.
- For external libraries/APIs, verify current behavior (context7 docs / web) rather than recalling it. An `analyst` checks the API surface against the pinned version.

If you cannot find evidence for something the plan depends on, that's a question for the user — not a guess to paper over.

### 3. Interview to shared understanding — one question at a time
Don't settle for the top-level forks. Walk the whole decision tree: ask the highest-leverage open question first, and once it's answered, walk *down that branch* — each choice opens sub-decisions (schema shape, edge cases, failure modes, scope cuts); resolve those before moving to the next sibling. Continue until no remaining unknown would change the plan or leave the implementer guessing. If you stop before the architectural forks are resolved, the plan is too thin. Past ~6 questions, list the remaining low-leverage unknowns under the plan's Open Questions instead of asking them.

- **One question at a time.** Each answer reshapes what to ask next; batching forecloses that. Use `AskUserQuestion` per question (cluster only when the questions are genuinely independent).
- **Recommend an answer to every question** — your best pick plus a one-line why — so the user confirms or redirects instead of composing prose.
- **Explore, don't ask, when the codebase can answer.** Anything research can settle (existing conventions, current lib behavior, what's already wired up) you resolve yourself first. Questions are only for genuine forks and unknowns evidence can't reach.
- **Resolve dependencies in order.** Decide the fork that gates the most downstream work first; let dependent decisions follow from its answer.

### 4. Checkpoint — hand off a clean-context continuation
Checkpoint when research was heavy: the harness warned that auto-compact is near, or you pulled in large blobs (see Context budget). Then, once intent is clear, or sooner if context is already loaded, **stop and let the user clear context** (writing the plan fresh is cleaner and cheaper). If research stayed light, skip this step, say so in one line, and go to Step 5. When checkpointing, give a paste-ready continuation prompt that carries everything forward, e.g.:

```
/ideate continue: <target, with #N if it is an existing issue>. Decisions: <bulleted resolved answers>. Evidence: <key files/paths, conventions, constraints found>. Write the plan now.
```

When they paste it back, resume at step 5 without re-researching.

### 5. Decide size — split if big
Judge whether this is one plan or several. Split when parts are independently buildable and large enough that one plan would be unwieldy or un-parallelizable (e.g. distinct subsystems, separable migrations, frontend vs backend that can proceed in parallel). When in doubt, one plan is fine — don't over-fragment.

### 6. Write the plan(s) — in subagents, parallel when split
Dispatch a subagent per plan (in parallel if independent) to write each plan to `<scratch>/plan-<slug>.md` using the template below. `<scratch>` is the session scratchpad directory the harness provides (else `mktemp -d`), passed to the subagent as an absolute path. Never write plans into the repo working tree. Give each subagent the evidence and decisions so it doesn't re-discover. The plan must be specific: real file paths, the approach, ordered steps, how to verify it, and a Workon Prompt.

Use a `general-purpose` agent with **no `model:` override**: it inherits the session model. The plan is the deliverable, and a weak one costs a rewrite downstream. Have each subagent return just the file path and a two-line summary; read the file yourself if you need the detail.

### 7. Create the issue(s) and update the board
**Labels.** Every plan issue (the master, when split) gets `planned`, the board's plan marker; create it idempotently per the contract. Add a type label (`feature`, `bug`, `chore`, …) only if it exists: `gh label list --limit 200 --json name --jq '.[].name'`. Don't create type labels unasked. Sub-issues get the type label only, never `planned`.

**Single plan:**
- Target was an existing issue → `gh issue edit <n> --body-file <scratch>/plan-<slug>.md --add-label planned`. The plan includes the original text under `## Original request`. Keep the title unless the plan changed the scope.
- Otherwise → `gh issue create --title "<title>" --body-file <scratch>/plan-<slug>.md --label planned [--label <type>]`.

**Split**, in this order (each sub-issue needs the master `#`, and the master needs the sub-issue `#`s):
1. Create the master with a short summary body and `--label planned`, or reuse the target issue: its summary body keeps the original text under `## Original request`.
2. Create each sub-issue with `Part of #<master>` as the first line of its plan body.
3. Rewrite the master body as summary + a checklist of the sub-issue `#`s in dependency order: `gh issue edit <master> --body-file …`. `--body-file` replaces the whole body, so the file must contain both.

If a create fails partway, stop and report which issues exist. Don't retry blindly; ask whether to finish the rest or close the partial set.

**Board.** Fetch the body immediately before editing (`gh issue view <status#> --json body --jq .body`), edit it, and write it back whole in the same step (`gh issue edit <status#> --body-file <file>`):
- The target was a TODO row → remove it and add `| #<n> | <one-line summary> | plan ready |` to **Up Next**.
- New idea or existing issue not on the board → add the Up Next row directly.
- Split → one Up Next row for the master. Sub-issues are tracked in the master's checklist.
- No Status issue → create it per the contract with this row in Up Next.

Verify with `gh issue view <n>`, then delete the scratch plan files.

### 8. Hand off
Stop. Tell the user — one line — to clear context and run `/workon <issue#>` (the master issue, if split). Don't start implementing.

## Plan template

```markdown
## Summary
<1-3 sentence problem statement>

## Original request
<existing issue's original body, verbatim; omit this section for new ideas>

## Requirements
- [ ] …

## Approach
<implementation strategy, grounded in the evidence found>

## Steps
- [ ] Step 1 — <description, with the real files it touches>
- [ ] Step 2 — …

## Verification
- <commands to run, tests to add or update, acceptance checks that prove it works>

## Open Questions
- <anything still unresolved>

---
## Workon Prompt
> **Start here:** <specific first action>
> **Key files:** `path/a`, `path/b`
> **Context:** <what an implementer needs that isn't obvious from the repo>
> **Parallelizable with:** <sibling sub-issue #s, or "n/a">
```
