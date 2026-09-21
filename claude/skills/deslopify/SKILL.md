---
name: deslopify
description: Remove AI slop from code and docs - em-dashes, AI prose, mannered prose, useless comments, robotic language
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

Work through each file and fix ALL of the following anti-patterns. They are ordered from mechanical (safe to fix on sight) to rhetorical (needs a rewrite with judgment).

### 1. Punctuation, Typographic & Markup Slop

Fix on sight. No judgment needed.

- **Em-dashes** (`—`, `–`): replace with hyphens or rewrite the sentence
- **Curly/smart quotes** (`"` `"` `'` `'`): replace with straight quotes (`"`, `'`)
- **Ellipses as unicode** (`…`): replace with three dots (`...`) or rewrite
- **AI-tool citation artifacts**: `oaicite`, `contentReference`, `turn0search0`, `[cite: 1]`, `ppl-ai-file-upload`, stray `†` markers. Leftovers from pasting model output. Always strip.
- **Decorative markup**: `---` horizontal rules used as section decoration, Title Case Headings In Body Docs, skipped heading levels

### 2. AI Prose (in comments, docs, READMEs, docstrings)

Every model produces this, not just one vendor, and the vocabulary drifts between model generations. So match the **patterns** below, not only the example words. For each hit, ask: is this word doing plain technical work, or is it filler? Then rewrite the sentence around the plain version. Never bare find-and-replace.

**Filler and hedge phrases**

- "This ensures that..." / "This allows you to..." / "This enables..."
- "It's worth noting that..." / "It's important to note..."
- "In order to..." (just say "to")
- "As mentioned earlier" / "As previously discussed"
- "Feel free to..." / "Don't hesitate to..."
- "Let's" / "Let's dive in" / "Let's take a look"
- Sentences that restate what the code already says

**AI vocabulary** (swap for the plain word, or cut)

- Leverage, utilize -> use
- Delve, delve into -> look at, cover, or just cut
- Robust, seamless, streamline, comprehensive, cutting-edge, intricate, pivotal, crucial, vibrant, meticulous
- Tapestry, testament, landscape, realm, synergy, journey
- Underscore, showcase, foster, garner, enhance, elevate, empower, align with
- "Boilerplate" used outside of actual template/scaffold contexts

**Copula avoidance**: "serves as", "stands as", "represents a", "functions as", "boasts a", "offers a" where "is" or "has" would do. Use "is".

**Significance inflation**: "is a testament to", "underscores the importance of", "plays a crucial role in", "marks a turning point", "reflects a broader trend". Manufactured importance for a mundane fact. State the fact.

**Negative parallelism**: "It's not just X, it's Y", "not only X but also Y", "This isn't about X. It's about Y." Say Y.

**Rule of three**: three adjectives, three examples, or three clauses imposed for rhythm when the content has one or two real items, or four. Keep the real items. A genuine list of three is fine.

**Participial tack-ons**: a sentence that ends with "..., enabling X, supporting Y, and fostering Z" to sound analytical without adding information. Cut the tail or make it its own claim.

**Sycophantic openers and formulaic closers**: "Great question!", "In this guide, we will explore...", "In conclusion...", "Despite these challenges, X continues to...", "Happy coding!", "And that's it!", "Voilà!". Cut them.

**Marketing register**: flowery or promotional language in technical docs. Describe what it does.

### 3. Mannered Prose

Mannered prose substitutes metaphor and flourish for direct statement. Instead of "a parameter worth varying," the mannered writer produces "a dial worth turning." Instead of "this point still matters," they write "this point earns its keep." The phrases exist to display the writer, not to convey the idea, and readers can tell. That is why mannered prose irritates: it makes the reader work harder so the writer can perform. It is also imprecise. Metaphors drag in connotations the writer did not choose and cannot control. The fix is to say what you mean. When a literal phrase is available, use it.

Related tells:

- Stock flourish phrases: "earns its keep", "carries the argument", "does the heavy lifting", "load-bearing" outside actual engineering, "the quiet part", "a north star"
- Inanimate subjects staged for a reveal: "The real story here is...", "What this really reveals is..."
- Performative hedges: "honestly", "frankly", "to be clear", "if I'm being honest"
- Rhetorical questions used as headers or transitions: "So what does this mean?" -> state what it means

Leave dead metaphors and real domain terms alone: "bottleneck", "race condition", "boilerplate" for actual scaffolding, "hot path". The target is live, writer-displaying flourish, not established vocabulary.

### 4. Useless Comments

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

### 5. Structural Slop

- **Over-abstraction**: single-use wrappers that add indirection without value - note these in the summary but don't refactor (out of scope)
- **Excessive blank lines**: more than one consecutive blank line between sections
- **Trailing whitespace**: remove it
- **Overly verbose names**: e.g., `getAllUsersThatAreCurrentlyActive` - flag but use judgment; don't rename if it would break things

### 6. Markdown & Documentation Slop

In `.md`, `.mdx`, `.rst`, and similar files:

- Remove filler intro/outro paragraphs ("In this guide, we will explore...")
- Remove "Overview" sections that just restate the title
- Remove bold/italic used for emphasis on every other word, and bolded lead-ins on every bullet
- Remove emoji used as structure (bullet markers, header prefixes)
- Fix headings that are questions when they should be statements ("What is X?" -> just "X" if it's a reference doc)
- Remove "Table of Contents" sections that duplicate what the sidebar already provides (use judgment)
- Collapse bullet lists and header stacks that fragment what should be a paragraph. Keep lists where the content is genuinely list-shaped (steps, options, parallel items). Do not flatten structure that aids clarity.

## Procedure

1. Resolve the file list (see Determine Scope above). Stop if empty.
2. Read each file.
3. Apply all applicable fixes from the categories above. For categories 2 and 3, read the surrounding paragraph before rewriting; the tells are pattern-level, not line-level.
4. Show a summary of what changed. Omit clean files.

   | File | Changes |
   |------|---------|
   | `path/to/file` | _what was cleaned_ |

## Principles

- **Sound human.** Read like a competent person wrote it - not sterile, not casual, just normal.
- **Say what you mean.** When a literal phrase exists, use it. Plain beats clever.
- **Preserve meaning.** Never change what code does. Never alter the meaning of documentation.
- **Tells are evidence, not verdicts.** "Ensure thread safety" and "robust error handling" are real technical claims. Not every em-dash is wrong. The test: would a competent human write this here?
- **Stay in scope.** Don't touch files outside the resolved file list.
- **Don't over-correct.** Terse and cryptic is worse than slightly verbose. Stripping useful structure is worse than leaving a bullet list. Clear and human is the target.

## Current Context

Current branch:
!`git branch --show-current`

Git status:
!`git status --porcelain`

Changed files (uncommitted):
!`git diff --name-only HEAD 2>/dev/null`
