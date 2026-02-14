---
name: plan-task
description: Create a plan for a feature or task, producing a GitHub issue as source of truth
argument-hint: [description]
disable-model-invocation: true
---

BEFORE ANYTHING ELSE, CHECK IF THE USER PROVIDED A DESCRIPTION AS AN ARGUMENT (`$ARGUMENTS`). IF THEY DID, USE THAT. IF NOT, ASK THE USER FOR A DETAILED DESCRIPTION OF WHAT THEY WANT. DO NOT PROCEED UNLESS YOU HAVE THE DESCRIPTION!

Create a plan for a feature or task. Produces a GitHub issue as the source of truth.

## Procedure

1. **Research** - Explore codebase to understand scope and constraints
2. **Draft** - Create `./scratchpad/plan-<slug>.md` with the template below (create the `scratchpad` directory if it doesn't exist: `mkdir -p ./scratchpad`)
3. **Review** - Present draft to user for feedback
4. **Finalize** - Once approved, create GitHub issue:
   ```bash
   # Ensure label exists
   gh label create "feature" --description "Feature request" --color "0E8A16" 2>/dev/null || true
   gh issue create --title "<title>" --body-file ./scratchpad/plan-<slug>.md --label "feature"
   ```
5. **Cleanup** - Verify the issue was created successfully (`gh issue view <number>`), then delete the scratchpad file

## Issue Template

The scratchpad file MUST follow this format to work with `/workon`:

```markdown
## Summary

<1-3 sentence problem statement>

## Requirements

- [ ] Requirement 1
- [ ] Requirement 2
- [ ] Requirement 3

## Proposed Approach

<Brief description of the implementation strategy>

## Implementation Steps

- [ ] Step 1 - <description>
- [ ] Step 2 - <description>
- [ ] Step 3 - <description>

## Open Questions

- <Any unresolved decisions or unknowns>

---

## Workon Prompt

> **Start here:** <specific first action to take>
>
> **Key files:** `path/to/file1.rs`, `path/to/file2.rs`
>
> **Context:** <any important background needed to begin>
```

## Notes

- The "Workon Prompt" section is essential - it tells `/workon` how to begin

## Current Context

Open issues:
!`gh issue list --state open --limit 10 --json number,title --jq '.[] | "- #\(.number) \(.title)"' 2>/dev/null || echo "no issues"`

Existing scratchpad plans:
!`ls -1 ./scratchpad/plan-*.md 2>/dev/null || echo "no drafts"`

Project structure:
!`ls -1 -d */ 2>/dev/null | head -15 || echo "empty directory"`
