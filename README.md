# agents

Shared commands for Claude Code that run a GitHub issue-driven development workflow, coordinated through a single pinned **Status** issue that every agent reads and updates.

## Workflow

A `Status` issue (one per repo) is the source of truth: a board with four tables — **TODO → Up Next → In Progress → Finished**. Capture ideas, plan them into issues, build them in worktrees, and the board stays in sync.

```text
/add-todo -> /ideate -> /workon
        \-> /where-are-we (orient / reconcile anytime)
```

## Commands

| Command          | Description                                                                                          | Arguments                  |
| ---------------- | ---------------------------------------------------------------------------------------------------- | -------------------------- |
| `/where-are-we`  | Read the Status issue, reconcile it against git history, summarize, and suggest next steps           | `[focus area]`             |
| `/add-todo`      | Condense an idea into a one-line task and append it to the Status board's TODO table                 | `[the thing to remember]`  |
| `/ideate`        | Research a TODO/idea with evidence, ask steering questions, write the plan(s) via subagents, create issue(s), update the board | `[a TODO, issue, or idea]` |
| `/workon`        | Implement a planned issue with subagents in an isolated worktree, update the board, finish via PR or merge | `[issue number]`           |
| `/refine`        | Refine branch changes for code quality, reusability, type safety, and clean patterns before committing |                            |

Goals: autonomous work drivable from the Claude Code app, minimal token waste (terse output), and quality work free of AI anti-patterns.

## Examples

```bash
/add-todo cache the forecast API responses, they're slow
/ideate add user authentication with OAuth
/workon 12
/where-are-we
```

## Install

```bash
./install.sh           # install (--yes/-y skips overwrite prompts)
./install.sh --rm      # uninstall (--remove also works)
```

Symlinks Claude skills into `~/.claude/skills/` and Codex skills into `~/.agents/skills/` (both follow symlinked skill folders). Re-running is safe; existing symlinks are replaced. A non-symlink target prompts before overwrite (`--yes`/`-y` skips prompts). `--rm`/`--remove` deletes only the symlinks that point back into this repo. The installer also cleans up leftover installs from older versions of this script (`~/.codex/skills/` symlinks and `~/.codex/prompts/` files; see below).

## Codex

The same six commands ship as [Codex CLI](https://github.com/openai/codex) skills — single-agent rewrites of the Claude skills (no subagents/worktrees) as `SKILL.md` folders, surfaced via `/skills` and invoked as `$where-are-we`, `$add-todo`, `$ideate`, `$workon`, `$refine`, `$deslopify` in Codex. They drive the identical `Status`-issue workflow over `gh` + `git`.

> These shipped as `~/.codex/prompts/` files until Codex removed the custom-prompts feature in v0.118.0. Skills (`~/.agents/skills/<name>/SKILL.md`) are the supported replacement; Codex follows symlinked skill folders under User scope, so the same symlink install works.

## Structure

```
claude/skills/       # Claude Code skills (SKILL.md per directory)
codex/skills/        # Codex CLI skills (SKILL.md per directory)
install.sh           # Symlink installer / uninstaller
```
