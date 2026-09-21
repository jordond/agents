# agents

Shared subagents and skills for Claude Code and Codex CLI. Two tiers:

- **Global** (installed user-wide): five generic subagents plus `/spawn`, `/refine`, `/deslopify`, `/gh-workflow`. Nothing here touches GitHub.
- **Per-repo, opt-in**: the GitHub issue-driven workflow (`/where-are-we`, `/add-todo`, `/ideate`, `/workon`). It creates and edits issues, so it is only enabled in repos you turn it on in.

## Install

```bash
./install.sh           # global: agents + generic skills (--yes/-y skips overwrite prompts)
./install.sh --rm      # uninstall global (--remove also works)
```

Symlinks `claude/agents/*.md` into `~/.claude/agents/`, `claude/skills/*` into `~/.claude/skills/`, and `codex/skills/*` into `~/.agents/skills/`. Re-running is safe; existing symlinks are replaced. A non-symlink target prompts before overwrite. `--rm` deletes only symlinks that point back into this repo. The installer also removes leftovers from older layouts (the workflow skills when they were still global, `~/.codex/skills/` symlinks, `~/.codex/prompts/` files).

## Agents (global)

Five generic Claude Code subagents in `~/.claude/agents/`. They read `CLAUDE.md` / `AGENTS.md` for a repo's conventions rather than hard-coding any stack. A project-level `.claude/agents/<name>.md` with the same name overrides these.

| Agent      | Model   | Role                                                                                       |
| ---------- | ------- | ------------------------------------------------------------------------------------------ |
| `scout`    | haiku   | Read-only locator: `file:line` table for where-is / what-calls / who-owns questions        |
| `analyst`  | sonnet  | Read-only investigator: traces subsystems, verifies package APIs, writes research notes    |
| `builder`  | opus    | Implements one written brief in its own worktree; lint + targeted tests; ≤40-line report   |
| `reviewer` | sonnet  | Read-only diff review: ≤15 severity-tagged lines + `merge \| fix-first \| discuss` verdict |
| `scribe`   | sonnet  | Exact edits to ≤3 files (status rows, report assembly, JSON fields); no design judgement   |

## Skills (global)

| Command        | Description                                                                                                                                   | Arguments                       |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| `/spawn`       | Route a task to the right subagent with a compact brief; auto-triggers on "spawn an agent", "delegate this". Sizes slices to finish under 150k context (250k ceiling) and never reuses a finished agent: stop it, spawn fresh. | `[what to delegate]`            |
| `/refine`      | Refine branch changes for code quality, reusability, type safety, and clean patterns before committing                                        |                                 |
| `/deslopify`   | Remove AI slop from code and docs                                                                                                              | `[path or scope]`               |
| `/gh-workflow` | Enable, disable, or check the GitHub workflow below for the current repo                                                                      | `[enable \| disable \| status]` |

## GitHub workflow (per repo, opt-in)

A `Status` issue (one per repo) is the source of truth: a board with four tables, **TODO → Up Next → In Progress → Finished**. Capture ideas, plan them into issues, build them in worktrees, and the board stays in sync.

```text
/add-todo -> /ideate -> /workon
        \-> /where-are-we (orient / reconcile anytime)
```

Enable it from inside a repo:

```bash
/gh-workflow                       # in a Claude Code session, or:
./install.sh --repo [path]         # from this repo; path defaults to cwd
./install.sh --repo [path] --rm    # disable
```

This symlinks `claude/repo-skills/*` into `<repo>/.claude/skills/` and `codex/repo-skills/*` into `<repo>/.agents/skills/`, and lists those paths in `<repo>/.git/info/exclude` so the machine-local symlinks never get committed. Repos without these symlinks cannot trigger the workflow at all. `/where-are-we` additionally requires an explicit slash invocation (it creates the Status issue if missing).

| Command         | Description                                                                                                                   | Arguments                  |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| `/where-are-we` | Read the Status issue, reconcile it against git history, summarize, and suggest next steps                                    | `[focus area]`             |
| `/add-todo`     | Condense an idea into a one-line task and append it to the Status board's TODO table                                          | `[the thing to remember]`  |
| `/ideate`       | Research a TODO/idea with evidence, ask steering questions, write the plan(s) via subagents, create issue(s), update the board | `[a TODO, issue, or idea]` |
| `/workon`       | Implement a planned issue with subagents in an isolated worktree, update the board, finish via PR or merge                    | `[issue number]`           |

Goals: autonomous work drivable from the Claude Code app, minimal token waste (terse output), and quality work free of AI anti-patterns.

```bash
/add-todo cache the forecast API responses, they're slow
/ideate add user authentication with OAuth
/workon 12
/where-are-we
```

## Codex

The same skills ship for [Codex CLI](https://github.com/openai/codex) as single-agent rewrites (no subagents/worktrees) in `SKILL.md` folders, surfaced via `/skills` and invoked as `$refine`, `$deslopify`, `$gh-workflow` (global) and `$where-are-we`, `$add-todo`, `$ideate`, `$workon` (per repo). They drive the identical `Status`-issue workflow over `gh` + `git`.

> These shipped as `~/.codex/prompts/` files until Codex removed the custom-prompts feature in v0.118.0. Skills are the supported replacement; Codex follows symlinked skill folders at both User (`~/.agents/skills/`) and Repo (`<repo>/.agents/skills/`) scope, so the same symlink install works.

## Structure

```text
claude/agents/        # Claude Code subagents, global (<name>.md per agent)
claude/skills/        # Claude Code skills, global (SKILL.md per directory)
claude/repo-skills/   # Claude Code skills, per-repo opt-in (GitHub workflow)
codex/skills/         # Codex CLI skills, global
codex/repo-skills/    # Codex CLI skills, per-repo opt-in
install.sh            # Symlink installer / uninstaller (global and --repo)
```
