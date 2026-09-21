---
name: gh-workflow
description: Enable, disable, or check the GitHub Status-issue workflow (/where-are-we, /add-todo, /ideate, /workon) for the current repo. These skills are opt-in per repo because they create and edit GitHub issues; this skill symlinks them into the repo's .claude/skills and .agents/skills.
argument-hint: "[enable | disable | status]  (default: enable)"
disable-model-invocation: true
---

Turn the GitHub Status-issue workflow on or off for **this repo only**. Nothing here is global.

## Resolve paths

The agents repo is wherever this skill's symlink points:

```bash
AGENTS_REPO="$(cd "$(dirname "$(readlink -f ~/.claude/skills/gh-workflow)")/../.." && pwd)"
REPO="$(git rev-parse --show-toplevel)"
```

If `git rev-parse` fails, say "not in a git repo" and stop. If `$AGENTS_REPO/install.sh` is missing, print the resolved path and stop.

## Actions (`$ARGUMENTS`, default `enable`)

**enable**
```bash
"$AGENTS_REPO/install.sh" --repo "$REPO" -y
```
Then tell the user in one line: enabled, and that the new skills load on the next session start (or `/reload`-equivalent if the CLI offers one). Warn in one more line if `gh auth status` fails or the repo has no GitHub remote, since every workflow skill needs both.

**disable**
```bash
"$AGENTS_REPO/install.sh" --repo "$REPO" --rm
```
One line back.

**status**
```bash
ls -l "$REPO/.claude/skills" "$REPO/.agents/skills" 2>/dev/null
```
Report `enabled` if all four (`where-are-we`, `add-todo`, `ideate`, `workon`) are symlinks into `$AGENTS_REPO`, `partial` if some, else `disabled`. One line.

## Output discipline

One or two lines total. No explanation of what the workflow is unless asked; `$AGENTS_REPO/README.md` has it.
