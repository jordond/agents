---
name: refine
description: Refine branch changes for code quality, reusability, type safety, and clean patterns before committing
argument-hint:
disable-model-invocation: true
---

BEFORE ANYTHING ELSE, verify there are changes to refine. Check `git status --porcelain` and `git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD 2>/dev/null`. If the working tree is clean AND there are no commits ahead of the base branch, inform the user there is nothing to refine and stop.

Refine all uncommitted changes on the current branch for code quality, reusability, type safety, and adherence to existing project patterns. This is a pre-commit quality pass.

## Procedure

1. **Identify changes to refine**

   Determine the change set. Use **one** of the following depending on the state of the working tree:

   - **If there are uncommitted changes** (staged or unstaged): use those as the scope.
     ```bash
     git diff HEAD
     ```
   - **If the working tree is clean but the branch has commits ahead of the base**: use the branch diff as the scope.
     ```bash
     BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)
     git diff "$BASE" HEAD
     ```

   Build a list of all changed files. These are the scope of the refinement — do not touch files outside this set.

2. **Understand existing project patterns**

   Before making any changes, study the codebase to understand established conventions:

   - Read `CLAUDE.md`, `AGENTS.md`, or similar project guidance files if they exist
   - Examine neighboring files in the same directories as the changed files
   - Note the project's existing patterns for: naming, file organization, component structure, error handling, imports, exports, and module boundaries
   - Identify the language(s) and frameworks in use

   All refinements MUST follow the patterns already present in the project. Do not introduce new conventions. However, if the codebase contains known anti-patterns (region comments, useless comments that restate code, commented-out code, etc.), still remove them from the changed files — matching a bad pattern is not a reason to keep it.

3. **Run `/simplify`**

   Invoke the `/simplify` skill on the changed code. This handles the initial pass for clarity, consistency, and maintainability.

4. **Extract for reusability**

   Review the changes for extraction opportunities. Extract when something is:
   - Used more than once (or clearly will be)
   - A self-contained unit of logic that improves readability when named
   - A constant, configuration value, or style that belongs in a shared location

   Extraction targets:
   - **Components**: Reusable UI components (follow the project's existing component patterns for location and structure)
   - **Constants/Enums**: Magic strings and numbers become named constants or enums in the appropriate shared location
   - **Utility functions**: Pure helper logic moves to the project's existing utils/helpers location
   - **Types/Interfaces**: Shared type definitions move to the project's existing types location
   - **Styles**: Repeated style values become design tokens, theme values, or shared style definitions per project convention

   Do NOT extract for the sake of it. Single-use code that is clear in context stays where it is.

5. **Enforce type safety**

   Apply language-appropriate type system best practices:

   **TypeScript/JavaScript:**
   - No `any` or `unknown` — use proper types, interfaces, or generics
   - No type assertions (`as`) unless truly unavoidable (document why)
   - Prefer `type` for unions/intersections, `interface` for object shapes (or follow project convention)
   - Use `const` assertions, template literal types, and discriminated unions where they add clarity
   - Enums or `as const` objects for fixed sets of values

   **Kotlin:**
   - Use sealed interfaces/classes for restricted hierarchies
   - Use enums for fixed value sets
   - Use data classes for value types
   - Leverage `when` exhaustiveness
   - No platform types left unresolved

   **Swift:**
   - Use enums with associated values
   - Use protocols for shared behavior
   - Use structs for value types
   - No force unwraps (`!`) unless justified

   **General (all languages):**
   - No magic strings or magic numbers — use named constants
   - No stringly-typed APIs — use the language's type system
   - Function signatures should express their contract through types

6. **Apply clean code practices**

   - **DRY**: Eliminate duplication found within the changed files (but do not over-abstract — three similar lines can be fine)
   - **Single responsibility**: Functions and classes should do one thing
   - **Clear naming**: Names should describe intent, not implementation
   - **No unnecessary comments**: Remove `// region`, `// end region`, `// TODO` placeholders, commented-out code, and comments that restate the code. Function/class/property doc comments (JSDoc, KDoc, etc.) are acceptable when they add value beyond what the signature conveys
   - **Import hygiene**: Remove unused imports, sort per project convention
   - **No dead code**: Remove unused variables, functions, parameters, and unreachable branches

7. **Verify changes**

   Detect the project's build system and run appropriate checks:

   - **TypeScript/Node**: `npm run lint && npm run build` (or pnpm/yarn/bun equivalent)
   - **Kotlin/Android**: `./gradlew build` or `./gradlew compileKotlin`
   - **Swift/iOS**: `xcodebuild build` or `swift build`
   - **Rust**: `cargo clippy && cargo build`
   - **Go**: `go vet ./... && go build ./...`
   - **Python**: `ruff check . && python -m mypy .`

   If checks fail, fix the issues and re-verify. Do not leave the code in a broken state.

8. **Present summary**

   Show a concise summary of what was refined:

   | Category | Changes |
   |----------|---------|
   | Simplified | _list of simplifications_ |
   | Extracted | _new components, constants, utils, types_ |
   | Type safety | _types added/fixed_ |
   | Cleanup | _dead code removed, imports cleaned, etc._ |

   Note any files modified and any decisions that warrant explanation.

## Principles

- **Follow the project, not your preferences.** Match existing conventions for naming, structure, and style. But don't preserve anti-patterns just because they exist elsewhere — remove region comments, dead code, and useless comments even if the rest of the codebase has them.
- **Preserve behavior exactly.** This is a refine pass, not a feature change.
- **Scope is the diff.** Only touch files that are part of the current changes. The one exception is extracting something to an existing shared file.
- **Less is more.** A small, confident refinement is better than an ambitious restructuring.

## Current Context

Current branch:
!`git branch --show-current`

Base branch:
!`git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null || echo "N/A"`

Changed files (uncommitted):
!`git diff --name-only HEAD 2>/dev/null`

Changed files (branch commits):
!`BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null) && [ -n "$BASE" ] && git diff --name-only "$BASE" HEAD 2>/dev/null || echo "N/A"`

Git status:
!`git status --porcelain`
