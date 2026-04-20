---
name: review-plan
description: Run an exhaustive review of a plan document, verdict PASS/FAIL with REVISE or REJECT, loop revisions until clean
argument-hint: [path-to-plan]
disable-model-invocation: true
---

BEFORE ANYTHING ELSE, CHECK IF THE USER PROVIDED A PATH AS AN ARGUMENT (`$ARGUMENTS`). IF THEY DID, USE THAT. IF NOT, ASK FOR THE PATH TO THE PLAN DOCUMENT. DO NOT PROCEED WITHOUT A PATH.

Take a path to a plan document, study it deeply, review it against the project's actual state and conventions, and return a concise verdict. Loop revisions with the user until the plan passes or the user stops.

## Arguments

- `$ARGUMENTS` - Absolute or repo-relative path to the plan file (markdown)

## Procedure

1. **Verify the file exists**

   ```bash
   test -f "$PLAN_PATH" || echo "missing"
   ```

   If missing, report and stop.

2. **Read the plan in full**

   Read the entire plan document. Do not skim. Note:
   - Scope and explicit out-of-scope callouts
   - Architecture decisions / ADRs
   - Phases, steps, checkboxes, acceptance criteria
   - Every file path, table name, symbol, or API the plan references
   - Any embedded code / SQL / schemas

3. **Gather project context**

   Find and read every guidance file that could govern the plan:
   - `CLAUDE.md` at the repo root
   - Any `CLAUDE.md` in ancestor directories of the plan file
   - Any `CLAUDE.md` nested inside directories the plan touches (feature packages, sub-projects)
   - `AGENTS.md`, `.cursorrules`, `CONTRIBUTING.md`, `ARCHITECTURE.md` if present
   - READMEs in directories the plan modifies

   Then spot-check the actual codebase for every concrete claim the plan makes:
   - File paths it cites → do they exist and contain what the plan says?
   - Symbols / functions / types it extends → do they have the shape the plan assumes?
   - Migrations / schemas / APIs it builds on → confirm the current state
   - Existing patterns the plan says to follow → read one real example to see if the plan's template matches reality

   This step is non-negotiable. A plan that reads beautifully but contradicts the codebase is a FAIL.

4. **Decide review mode**

   - **Inline**: plan is under ~300 lines, single-domain, or scope is small. Review yourself.
   - **Parallel subagents**: plan is large (>300 lines, multi-domain, crosses client/server/DB, or spans many phases). Dispatch subagents in parallel — each covers one lens. Recommended lenses:
     - Architecture & design conformance (vs. CLAUDE.md + existing code)
     - Correctness of codebase claims (paths, symbols, schemas cited)
     - Completeness (missing tests, migrations, error handling, observability, rollback)
     - Code style / naming / module boundaries
     - Security, authn/authz, trust boundaries (when the plan touches auth, user data, or external inputs)
     - Scope & sequencing (phase ordering, dependencies, scope creep, contradictions)

     Give each subagent the plan path, the relevant CLAUDE.md files, and a narrow lens. Have them report issues with file:line citations. Aggregate in the main thread.

5. **Evaluate against the full checklist**

   Work through these dimensions. For each, note concrete issues with citations (plan section + codebase file:line where relevant):

   **Accuracy**
   - Every cited file/path/symbol exists and matches the plan's description
   - Embedded code / SQL / types compile or parse against current schema
   - No stale references to renamed or deleted code
   - Line counts, enum sizes, table columns match reality

   **Architecture & design**
   - Follows the module / package boundaries declared in CLAUDE.md
   - Uses the existing dependency-injection, navigation, state-management patterns rather than inventing new ones
   - Respects layering (domain / data / UI, or equivalent)
   - No new frameworks, libraries, or paradigms without justification
   - ADRs are explicit where a choice is non-obvious

   **Completeness**
   - Tests: unit, integration, end-to-end — specified where needed
   - Migrations / schema changes have an up-path AND a rollback/forward-only strategy
   - Error handling, empty states, loading states called out
   - Observability: logging, metrics, traces where they'd matter
   - Edge cases: offline, concurrent writes, partial failures, empty inputs, large inputs
   - Accessibility / i18n when UI is involved
   - Security: authn, authz, input validation, rate limits, secret handling when relevant

   **Code style & conventions**
   - Naming matches project conventions (case, prefixes, suffixes)
   - File locations match the project's feature layout
   - Proposed signatures match the shape of neighboring code
   - No introduction of anti-patterns flagged in CLAUDE.md

   **Scope & sequencing**
   - Out-of-scope items are explicit and consistent
   - Phases are independently shippable or explicitly sequenced with reasons
   - No hidden dependencies between phases
   - No scope creep vs. the stated goal
   - No contradictions between sections (e.g. ADR says X, task list assumes not-X)

   **Clarity & executability**
   - Every task is specific enough to act on (not "improve performance")
   - "Workon Prompt" / kickoff instruction is present if the plan convention requires it
   - Open questions are listed honestly rather than glossed over
   - Acceptance criteria / Definition of Done exist per phase

6. **Assign verdict**

   - **PASS** — Plan is accurate, complete, aligned with conventions, and executable as-is. Minor nits are fine; list them but don't block.
   - **FAIL / REVISE** — Plan has fixable issues. Most failures land here. Use when the structure is sound but specific corrections are needed (wrong paths, missing tests, style mismatch, ambiguous steps, missed edge cases, architectural drift).
   - **FAIL / REJECT** — Plan is fundamentally broken or wrong-headed. Use only when the plan contradicts the codebase at its core, solves the wrong problem, violates a hard CLAUDE.md rule that can't be patched, or proposes a design that can't be salvaged by edits. Rare.

7. **Report to the user (CONCISE)**

   Use this exact template. Keep it tight — the summary is for a human skimming:

   ```markdown
   ## Plan Review: <plan filename>

   **Verdict: PASS** | **Verdict: FAIL — REVISE** | **Verdict: FAIL — REJECT**

   ### Summary
   <2-4 sentences: what the plan does, overall quality, headline issue if any>

   ### Critical Issues
   - <Issue with citation, e.g. "§4.1 references `volumes` table as new, but migration `0001_schema.sql:42` already has it">
   - <...>

   ### Recommended Revisions
   - <Concrete fix, e.g. "Update §2 A-7 to cite actual CLAUDE.md rule about feature packages">
   - <...>

   ### Minor Nits
   - <Low-priority polish items>

   ### Next Step
   Reply `revise` to apply the recommended revisions, or `stop` to end the review.
   ```

   If the verdict is PASS, skip "Critical Issues" and "Recommended Revisions" — just say what's good and note any nits.

   If the verdict is REJECT, skip "Recommended Revisions" and explain why revision wouldn't salvage it. Offer to help draft a replacement plan instead.

8. **Handle the user's reply**

   - **"revise"** alone (or any synonym: "fix", "update", "apply", "yes", "do it", "go"):
     Apply every item in "Recommended Revisions" to the plan file.
   - **"revise" with selection** — the user may narrow or steer the revisions. Examples:
     - "revise but skip the security stuff" → apply all except security-related items
     - "revise 1, 3, 5" or "fix the first two" → apply only the numbered items (count down the "Recommended Revisions" list in the order shown)
     - "revise, but ignore the migration change — we'll handle that separately" → exclude that item
     - "revise and also tighten §4.2" → apply the list plus the extra ask
     - "just fix the critical issues" → apply items from "Critical Issues" only
     When the selection is ambiguous (e.g. "fix the arch stuff" but multiple items could qualify), echo back which items you plan to apply before editing. Do not silently guess.
   - **"stop"** (or any synonym: "cancel", "exit", "done", "quit", "nope"):
     End the review. Do not modify the plan further.
   - **Anything else**: treat as a question or clarification. Answer it, then re-prompt for `revise` or `stop`.

   When applying revisions:
   1. Edit the plan file directly (Edit/Write). Preserve structure, voice, formatting — no gratuitous rewrites.
   2. When a revision requires information you don't have, ask the user before guessing.
   3. After edits, re-run this entire procedure from step 2 against the revised file.
   4. Loop until verdict is PASS or the user says stop.

## Principles

- **Ground every claim in the codebase.** A review that says "looks good" without checking the actual files is worthless. Read real code before approving.
- **Cite, don't assert.** Every issue should point at a plan section and/or a file:line. The user should be able to verify each finding in seconds.
- **Be ruthless but not petty.** REVISE for things that will cause real problems during implementation. Don't gate on cosmetic preferences dressed up as rules.
- **Prefer REVISE over REJECT.** Almost every plan can be saved by edits. Reserve REJECT for genuinely broken direction.
- **Keep the summary small.** The value of this skill is a fast, scannable verdict with the load-bearing issues pulled out. If the summary is longer than the plan, something has gone wrong.
- **Loop until clean.** The whole point of the revise/re-review loop is that a plan should leave the review cycle genuinely ready to build, not "close enough".

## Notes

- Pairs with `/plan-task` (creates plans) and `/workon` (executes them). This skill sits between: review the plan before it becomes an issue or before work begins.
- If the plan lives in GitHub rather than on disk, fetch it first: `gh issue view <n> --json body --jq '.body' > /tmp/plan.md` and review that path.
- For large plans, parallel subagents save real time. Don't skip the dispatch just because it feels heavier — a six-lens parallel review is faster AND better than a single serial pass.

## Current Context

Git repo root:
!`git rev-parse --show-toplevel 2>/dev/null || echo "not a git repo"`

CLAUDE.md files in repo:
!`find . -name "CLAUDE.md" -not -path "./node_modules/*" -not -path "./.git/*" 2>/dev/null | head -20`

AGENTS.md files in repo:
!`find . -name "AGENTS.md" -not -path "./node_modules/*" -not -path "./.git/*" 2>/dev/null | head -20`

Current branch:
!`git branch --show-current 2>/dev/null`
