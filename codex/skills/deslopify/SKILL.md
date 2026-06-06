---
name: deslopify
description: Remove AI slop from code and docs — em-dashes, smart quotes, ChatGPT prose, useless comments, structural and markdown slop. Use when the user wants to deslopify, clean AI anti-patterns, strip robotic language, or de-AI changed files. Argument is a path, a scope description, or blank for uncommitted changes.
---

# Deslopify

Clean AI anti-patterns ("slop") from code and documentation files.

Argument (`$ARGUMENTS`): a path, a description of scope, or blank for uncommitted changes.

## Determine Scope

BEFORE ANYTHING ELSE, resolve the file list from `$ARGUMENTS`:

- **No arguments**: default to uncommitted changes. Run `git diff --name-only HEAD`. If empty, tell the user there's nothing to deslopify and stop.
- **A file or directory path**: use it directly. If a directory, recursively include all text files in it.
- **A description** (e.g. "the doc files in docs/", "recent changes", "everything in src/components"): resolve to a concrete file list using `git diff`, glob, or directory listing.

If the resolved file list is empty, stop early. Otherwise, read every file in scope.

## What to Fix

Work through each file and fix ALL of the following.

### 1. Punctuation & Typographic Slop
- **Em-dashes** (`—`, `–`): replace with hyphens or rewrite the sentence.
- **Curly/smart quotes**: replace with straight quotes (`"`, `'`).
- **Unicode ellipses** (`…`): replace with `...` or rewrite.

### 2. ChatGPT Prose (comments, docs, READMEs, docstrings)
Remove or rewrite chatbot-sounding text. Tells:
- "This ensures that..." / "This allows you to..." / "This enables..."
- "It's worth noting that..." / "It's important to note..."
- "In order to..." (just "to"), "Leverage"/"Utilize" (just "use")
- "Robust" / "Seamless" / "Streamline" / "Comprehensive" / "Cutting-edge"
- "Delve" / "Delve into"
- "Let's" / "Let's dive in" / "Let's take a look"
- "As mentioned earlier" / "As previously discussed"
- "Happy coding!" / "And that's it!" / "Voilà!"
- "Feel free to..." / "Don't hesitate to..."
- "Boilerplate" outside actual template/scaffold contexts
- Flowery or marketing-style language in technical docs
- Sentences that restate what the code already says

Don't just find-and-replace words. Rewrite the sentence to sound human — direct, natural, no filler.

### 3. Useless Comments
Remove comments that add no information:
- `// Constructor` above a constructor, `// Initialize variables`, `// Return the result`, `// Handle error` above a catch
- Comments that restate the next line
- `// region` / `// endregion` / `// #region` / `// #endregion`
- `// ----------` separator lines
- `// TODO: implement` with no useful context
- `// Added by [AI tool name]`

Preserve comments that explain **why**, document non-obvious behavior, or carry genuinely useful context.

### 4. Structural Slop
- **Over-abstraction**: single-use wrappers adding indirection without value — note in the summary, don't refactor (out of scope).
- **Excessive blank lines**: more than one consecutive blank line between sections.
- **Trailing whitespace**: remove it.
- **Overly verbose names**: flag, but use judgment; don't rename if it would break things.

### 5. Markdown & Documentation Slop
In `.md`, `.mdx`, `.rst`, and similar:
- Remove filler intro/outro paragraphs ("In this guide, we will explore...").
- Remove "Overview" sections that just restate the title.
- Remove excessive bold/italic on every other word.
- Fix question-headings that should be statements ("What is X?" → "X" in a reference doc).
- Remove "Table of Contents" sections that duplicate the sidebar (use judgment).

## Procedure

1. Resolve the file list (see Determine Scope). Stop if empty.
2. Read each file.
3. Apply all applicable fixes.
4. Show a summary; omit clean files.

   | File | Changes |
   |------|---------|
   | `path/to/file` | _what was cleaned_ |

## Principles

- **Sound human.** Read like a competent person wrote it — not sterile, not casual.
- **Preserve meaning.** Never change what code does. Never alter the meaning of docs.
- **Use judgment.** Not every em-dash is wrong. The test: would a human actually write this?
- **Stay in scope.** Don't touch files outside the resolved list.
- **Don't over-correct.** Terse and cryptic is worse than slightly verbose. Clear and human is the target.
