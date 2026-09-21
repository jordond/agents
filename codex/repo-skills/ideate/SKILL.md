---
name: ideate
description: 'Turn a rough idea or a backlog TODO into a researched, build-ready plan and GitHub issue(s). Use when the user wants to plan, flesh out, spec, scope, design, or "ideate" a feature or task before writing code. Asks targeted clarifying questions one at a time with recommendations, researches with concrete evidence (never guesses), writes the plan, creates the issue(s), updates the Status board, and hands off to $workon. Use this — not $workon — whenever there is no written plan or issue yet, even if the user says "build" or "implement": planning and research come first.'
---

# Ideate

Turn something fuzzy into a plan precise enough that `$workon` can execute it with no further discovery. Plan quality comes from **evidence**, not assumption. Use this — not `$workon` — whenever there is no written plan or issue yet, even if the user says "build" or "implement": planning and research come first.

Argument (`$ARGUMENTS`): a TODO, issue, or new idea. Blank → pick from the board.

## Output discipline

You'll do a lot of research, but the user only sees: the clarifying questions, the continuation prompt, and the final handoff. Don't narrate research as you go. Keep questions tight. Tokens spent reading the codebase are worth it; tokens spent describing your reading are not.

## Status issue contract

One issue per repo, title `Status`, label `status`. `$ideate` promotes an item from **TODO** to **Up Next** and records the new issue number. (Full board: TODO → Up Next → In Progress → Finished — see `$where-are-we`.)

## Procedure

### 1. Choose the target
- `$ARGUMENTS` names a TODO/issue/idea → use it.
- Otherwise read the Status issue and offer the open TODOs (plus "something new"). Let the user pick.

### 2. Research with evidence — do not guess
The core of a good plan. Before asking anything, build a concrete picture:
- Find the real files, patterns, and constraints involved. Search the repo for breadth; read the actual code for the parts that matter.
- Confirm how similar things are already done in this repo so the plan matches existing conventions.
- For external libraries/APIs, verify current behavior (official docs / web search) rather than recalling it.

If you cannot find evidence for something the plan depends on, that's a question for the user — not a guess to paper over.

### 3. Interview to shared understanding — one question at a time
Don't settle for the top-level forks. Walk the whole decision tree: ask the highest-leverage open question first, and once answered, walk *down that branch* — each choice opens sub-decisions (schema shape, edge cases, failure modes, scope cuts); resolve those before moving to the next sibling. Continue until no remaining unknown would change the plan or leave the implementer guessing. Stop short of architectural forks and the plan is too thin.

- **One question at a time.** Each answer reshapes what to ask next; batching forecloses that. Ask, then wait for the answer (cluster only when questions are genuinely independent).
- **Recommend an answer to every question** — your best pick plus a one-line why — so the user confirms or redirects instead of composing prose.
- **Explore, don't ask, when the codebase can answer.** Anything research can settle (existing conventions, current lib behavior, what's already wired up) you resolve yourself first. Questions are only for genuine forks and unknowns evidence can't reach.
- **Resolve dependencies in order.** Decide the fork that gates the most downstream work first; let dependent decisions follow from its answer.

### 4. Checkpoint — hand off a clean-context continuation
Once intent is clear, **stop and let the user clear context** (planning research bloats the window; writing the plan fresh is cleaner and cheaper). Give a paste-ready continuation prompt that carries everything forward, e.g.:

```
$ideate continue: <target>. Decisions: <bulleted resolved answers>. Evidence: <key files/paths, conventions, constraints found>. Write the plan now.
```

When the user pastes it back, resume at step 5 without re-researching.

### 5. Decide size — split if big
Judge whether this is one plan or several. Split when parts are independently buildable and large enough that one plan would be unwieldy (distinct subsystems, separable migrations, frontend vs backend that can proceed in parallel). When in doubt, one plan is fine — don't over-fragment.

### 6. Write the plan(s)
Write each plan to `./scratchpad/plan-<slug>.md` using the template below. The plan must be specific: real file paths, the approach, ordered steps, and a Workon Prompt. Carry forward the evidence and decisions so the plan stands on its own.

### 7. Create the issue(s) and update the board
- **Single plan:** `gh issue create --title "<title>" --body-file ./scratchpad/plan-<slug>.md --label feature`. Then move the item from TODO → **Up Next** in the Status issue with the new `#`.
- **Split:** create one **master** issue summarizing the effort, then a sub-issue per plan linked to it (reference the master `#` in each sub-issue body and list the sub-issues in the master). Add the master (and optionally subs) to **Up Next**.
- Verify creation (`gh issue view <n>`), then delete the scratchpad files.

### 8. Hand off
Stop. Tell the user — one line — to clear context and run `$workon <issue#>` (the master issue, if split). Don't start implementing.

## Plan template

```markdown
## Summary
<1-3 sentence problem statement>

## Requirements
- [ ] …

## Approach
<implementation strategy, grounded in the evidence found>

## Steps
- [ ] Step 1 — <description, with the real files it touches>
- [ ] Step 2 — …

## Open Questions
- <anything still unresolved>

---
## Workon Prompt
> **Start here:** <specific first action>
> **Key files:** `path/a`, `path/b`
> **Context:** <what an implementer needs that isn't obvious from the repo>
> **Parallelizable with:** <sibling sub-issue #s, or "n/a">
```
