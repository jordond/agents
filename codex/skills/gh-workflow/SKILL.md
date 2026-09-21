---
name: gh-workflow
description: Enable, disable, or check the GitHub Status-issue workflow ($where-are-we, $add-todo, $ideate, $workon) for the current repo. Opt-in per repo because these skills create and edit GitHub issues.
---

Turn the GitHub Status-issue workflow on or off for **this repo only**. Nothing here is global.

## Resolve paths

```bash
AGENTS_REPO="$(cd "$(dirname "$(readlink -f ~/.agents/skills/gh-workflow)")/../.." && pwd)"
REPO="$(git rev-parse --show-toplevel)"
```

If `git rev-parse` fails, say "not in a git repo" and stop. If `$AGENTS_REPO/install.sh` is missing, print the resolved path and stop.

## Actions (argument, default `enable`)

- **enable**: `"$AGENTS_REPO/install.sh" --repo "$REPO" -y`. One line back; note the skills load next session. Warn in one line if `gh auth status` fails or there is no GitHub remote.
- **disable**: `"$AGENTS_REPO/install.sh" --repo "$REPO" --rm`. One line back.
- **status**: `ls -l "$REPO/.agents/skills"`; report `enabled` / `partial` / `disabled` depending on how many of the four are symlinks into `$AGENTS_REPO`.

## Output discipline

One or two lines total.
