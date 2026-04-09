---
name: deslopify
description: Remove AI slop from code and docs - em-dashes, ChatGPT prose, useless comments, robotic language
argument-hint: "[path, description of scope, or blank for uncommitted changes]"
---

Clean AI anti-patterns ("slop") from code and documentation files.

## Determine Scope

BEFORE ANYTHING ELSE, resolve the file list from `$ARGUMENTS`:

- **No arguments**: default to uncommitted changes. Run `git diff --name-only HEAD` to get the file list. If empty, tell the user there's nothing to deslopify and stop.
- **A file or directory path**: use that directly. If it's a directory, recursively include all text files in it.
- **A description** (e.g. "the doc files in docs/", "recent changes", "everything in src/components"): resolve to a concrete file list using `git diff`, `glob`, or directory listing as appropriate.

If the resolved file list is empty, stop early. Otherwise, read every file in scope.

## What to Fix

Work through each file and fix ALL of the following anti-patterns:

### 1. Punctuation & Typographic Slop

- **Em-dashes** (`—`, `–`): replace with hyphens or rewrite the sentence
- **Curly/smart quotes** (`"` `"` `'` `'`): replace with straight quotes (`"`, `'`)
- **Ellipses as unicode** (`…`): replace with three dots (`...`) or rewrite

### 2. ChatGPT Prose (in comments, docs, READMEs, docstrings)

Remove or rewrite chatbot-sounding text. Common tells:

- "This ensures that..." / "This allows you to..." / "This enables..."
- "It's worth noting that..." / "It's important to note..."
- "In order to..." (just say "to")
- "Leverage" (say "use")
- "Utilize" (say "use")
- "Robust" / "Seamless" / "Streamline" / "Comprehensive" / "Cutting-edge"
- "Delve" / "Delve into"
- "Let's" / "Let's dive in" / "Let's take a look"
- "As mentioned earlier" / "As previously discussed"
- "Happy coding!" / "And that's it!" / "Voilà!"
- "Feel free to..." / "Don't hesitate to..."
- "Boilerplate" used outside of actual template/scaffold contexts
- Flowery or marketing-style language in technical docs
- Sentences that restate what the code already says

Don't just find-and-replace words. Rewrite the sentence to sound human - direct, natural, no filler.

### 3. Useless Comments

Remove comments that add no information:

- `// Constructor` above a constructor
- `// Initialize variables` above variable declarations
- `// Return the result` above a return statement
- `// Handle error` above a catch block
- Comments that literally restate the next line of code
- `// region` / `// endregion` / `// #region` / `// #endregion` blocks
- `// ----------` separator lines
- `// TODO: implement` with no useful context
- `// Added by [AI tool name]`

Preserve comments that explain **why** something is done, document non-obvious behavior, or contain genuinely useful context.

### 4. Structural Slop

- **Over-abstraction**: single-use wrappers that add indirection without value - note these in the summary but don't refactor (out of scope)
- **Excessive blank lines**: more than one consecutive blank line between sections
- **Trailing whitespace**: remove it
- **Overly verbose names**: e.g., `getAllUsersThatAreCurrentlyActive` - flag but use judgment; don't rename if it would break things

### 5. Markdown & Documentation Slop

In `.md`, `.mdx`, `.rst`, and similar files:

- Remove filler intro/outro paragraphs ("In this guide, we will explore...")
- Remove "Overview" sections that just restate the title
- Remove excessive bold/italic used for emphasis on every other word
- Fix headings that are questions when they should be statements ("What is X?" -> just "X" if it's a reference doc)
- Remove "Table of Contents" sections that duplicate what the sidebar already provides (use judgment)

## Procedure

1. Resolve the file list (see Determine Scope above). Stop if empty.
2. Read each file.
3. Apply all applicable fixes from the categories above.
4. Show a summary of what changed. Omit clean files.

   | File | Changes |
   |------|---------|
   | `path/to/file` | _what was cleaned_ |

## Principles

- **Sound human.** Read like a competent person wrote it - not sterile, not casual, just normal.
- **Preserve meaning.** Never change what code does. Never alter the meaning of documentation.
- **Use judgment.** Not every em-dash is wrong. Not every "ensure" is slop. The test: would a human actually write this?
- **Stay in scope.** Don't touch files outside the resolved file list.
- **Don't over-correct.** Terse and cryptic is worse than slightly verbose. Clear and human is the target.

## Current Context

Current branch:
!`git branch --show-current`

Git status:
!`git status --porcelain`

Changed files (uncommitted):
!`git diff --name-only HEAD 2>/dev/null`
