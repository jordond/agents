# refine

Refine branch changes for code quality, reusability, type safety, and clean patterns before committing. A pre-commit quality pass that preserves behavior exactly.

BEFORE ANYTHING ELSE, verify there are changes to refine. Check `git status --porcelain` and `git log --oneline main..HEAD 2>/dev/null || git log --oneline master..HEAD 2>/dev/null`. If the working tree is clean AND there are no commits ahead of the base branch, tell me there's nothing to refine and stop.

## Procedure

1. **Identify changes to refine**

   Determine the change set:
   - **Uncommitted changes** (staged or unstaged): use those as the scope.
     ```bash
     git diff HEAD
     ```
   - **Clean tree but branch ahead of base**: use the branch diff.
     ```bash
     BASE=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)
     git diff "$BASE" HEAD
     ```

   Build a list of all changed files. These are the scope — do not touch files outside this set (except to extract into an existing shared file).

2. **Understand existing project patterns**

   Before changing anything, study the conventions:
   - Read `AGENTS.md`, `CLAUDE.md`, or similar project guidance if present.
   - Examine neighboring files in the same directories as the changed files.
   - Note patterns for: naming, file organization, component structure, error handling, imports, exports, module boundaries.
   - Identify the language(s) and frameworks in use.

   All refinements MUST follow patterns already present. Do not introduce new conventions. Exception: if the codebase contains known anti-patterns (region comments, comments that restate code, commented-out code), still remove them from the changed files — matching a bad pattern is not a reason to keep it.

3. **Simplify**

   Make a clarity pass over the changed code: collapse needless indirection, simplify control flow, remove redundancy, make names and structure clear and consistent with the project.

4. **Extract for reusability**

   Extract when something is used more than once (or clearly will be), is a self-contained unit of logic that reads better named, or is a constant/config/style that belongs in a shared location.

   Targets: reusable components, named constants/enums (kill magic strings/numbers), pure utility functions, shared types/interfaces, design tokens/theme values. Follow the project's existing locations and structure. Do NOT extract for its own sake — single-use code that's clear in context stays put.

5. **Enforce type safety**

   Apply language-appropriate best practices:

   **TypeScript/JavaScript:** no `any`/`unknown` — use proper types/interfaces/generics; no `as` assertions unless unavoidable (document why); `type` for unions/intersections, `interface` for object shapes (or follow convention); `const` assertions, template literal types, discriminated unions where they add clarity; enums or `as const` for fixed value sets.

   **Kotlin:** sealed interfaces/classes for restricted hierarchies; enums for fixed sets; data classes for value types; `when` exhaustiveness; no unresolved platform types.

   **Swift:** enums with associated values; protocols for shared behavior; structs for value types; no force unwraps (`!`) unless justified.

   **All languages:** no magic strings/numbers — name them; no stringly-typed APIs; function signatures express their contract through types.

6. **Apply clean code practices**

   - **DRY**: eliminate duplication within the changed files (don't over-abstract — three similar lines can be fine).
   - **Single responsibility**: functions and classes do one thing.
   - **Clear naming**: names describe intent, not implementation.
   - **No unnecessary comments**: remove `// region`/`// endregion`, `// TODO` placeholders, commented-out code, comments that restate the code. Doc comments (JSDoc, KDoc) are fine when they add value beyond the signature.
   - **Import hygiene**: remove unused imports, sort per convention.
   - **No dead code**: remove unused variables, functions, parameters, unreachable branches.

7. **Verify changes**

   Detect the build system and run the right checks:
   - **TypeScript/Node**: `npm run lint && npm run build` (or pnpm/yarn/bun equivalent)
   - **Kotlin/Android**: `./gradlew build` or `./gradlew compileKotlin`
   - **Swift/iOS**: `xcodebuild build` or `swift build`
   - **Rust**: `cargo clippy && cargo build`
   - **Go**: `go vet ./... && go build ./...`
   - **Python**: `ruff check . && python -m mypy .`

   If checks fail, fix and re-verify. Do not leave the code broken.

8. **Present summary**

   | Category | Changes |
   |----------|---------|
   | Simplified | _list_ |
   | Extracted | _new components, constants, utils, types_ |
   | Type safety | _types added/fixed_ |
   | Cleanup | _dead code removed, imports cleaned, etc._ |

   Note files modified and any decisions that warrant explanation.

## Principles

- **Follow the project, not your preferences.** Match existing conventions — but don't preserve anti-patterns just because they exist elsewhere.
- **Preserve behavior exactly.** This is a refine pass, not a feature change.
- **Scope is the diff.** Only touch changed files. The one exception is extracting into an existing shared file.
- **Less is more.** A small, confident refinement beats an ambitious restructuring.
