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
| `/pr-feedback`   | Walk through PR review comments one by one with confirmation                                         | `[pr-number]`              |

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
./install.sh # --yes
```

Symlinks Claude skills into `~/.claude/skills/` and OpenCode commands into `~/.opencode/commands/`. Re-running is safe; existing symlinks are replaced. A non-symlink target prompts before overwrite (`--yes`/`-y` skips prompts).

## Structure

```
claude/skills/       # Claude Code skills (SKILL.md per directory)
opencode/            # OpenCode commands (.md files)
install.sh           # Symlink installer
```
