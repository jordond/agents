# agents

Shared commands for Claude Code and OpenCode that manage a GitHub issue-driven development workflow.

## Workflow

Plan a feature as a GitHub issue, work on it, track progress, submit a PR, and address review feedback.

```text
/plan -> /workon -> /update-plan -> /work-done -> /pr-feedback
```

## Commands

| Command        | Description                                                                      | Arguments                        |
| -------------- | -------------------------------------------------------------------------------- | -------------------------------- |
| `/plan-task`   | Research and create a GitHub issue with a structured plan                        | `[description]`                  |
| `/workon`      | Start working on an issue: set up branch, mark in-progress, begin implementation | `[issue-number or search-query]` |
| `/update-plan` | Post a progress update comment on the issue and update checkboxes                | `[issue-number]`                 |
| `/work-done`   | Create a PR that auto-closes the issue when merged                               | `[issue-number]`                 |
| `/pr-feedback` | Walk through PR review comments one by one with confirmation                     | `[pr-number]`                    |

## Examples

```bash
# Plan a new feature
/plan-task add user authentication with OAuth

# Start working on issue #12
/workon 12

# Update progress on current issue
/update-plan

# Create a PR when finished
/work-done

# Address review feedback on PR #15
/pr-feedback 15
```

## Install

```bash
./install.sh # --yes
```

This symlinks everything into the right places:

- Claude skills to `~/.claude/skills/`
- OpenCode commands to `~/.opencode/commands/`

Re-running is safe. Existing symlinks are replaced. If a non-symlink file exists at the target, the script prompts before overwriting. Use `--yes` or `-y` to skip prompts.

## Structure

```
claude/skills/       # Claude Code skills (SKILL.md per directory)
opencode/            # OpenCode commands (.md files)
install.sh           # Symlink installer
```
