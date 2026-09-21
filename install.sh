#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global (user-wide) targets.
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_AGENTS_DIR="$HOME/.claude/agents"
# Non-deprecated Codex user skills location (loader.rs registers $HOME/.agents/skills).
CODEX_SKILLS_DIR="$HOME/.agents/skills"
# Legacy targets cleaned up by older versions of this script:
#   - $CODEX_HOME/skills: deprecated user skills dir (we briefly installed here)
#   - $CODEX_HOME/prompts: dead custom-prompts feature (removed in Codex v0.118.0)
CODEX_LEGACY_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
CODEX_PROMPTS_DIR="${CODEX_HOME:-$HOME/.codex}/prompts"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

usage() {
  cat <<EOF
Usage: ./install.sh [--yes|-y] [--rm|--remove]
       ./install.sh --repo [path] [--yes|-y] [--rm|--remove]

  (no --repo)   Install user-wide: claude/agents -> ~/.claude/agents,
                claude/skills -> ~/.claude/skills, codex/skills -> ~/.agents/skills.
  --repo [path] Install the GitHub Status-issue workflow (claude/repo-skills,
                codex/repo-skills) into one repo: <repo>/.claude/skills and
                <repo>/.agents/skills. Defaults to the current directory.
  --rm          Remove instead of install (same scope rules).
  --yes         Skip overwrite prompts.
EOF
}

AUTO_YES=false
REMOVE=false
REPO_MODE=false
REPO_PATH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) AUTO_YES=true ;;
    --rm|--remove) REMOVE=true ;;
    --repo)
      REPO_MODE=true
      if [ $# -gt 1 ] && [[ "$2" != --* ]] && [[ "$2" != -y ]]; then
        REPO_PATH="$2"; shift
      fi
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

confirm_overwrite() {
  local target="$1"
  if $AUTO_YES; then
    return 0
  fi
  echo -en "  ${YELLOW}$target already exists. Delete and replace? [y/N]${RESET} "
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# Symlink a path (skill dir or agent file) into dest_dir under its basename.
# Claude and Codex both follow symlinked skill folders / agent files.
link_into() {
  local src="${1%/}"
  local dest_dir="$2"
  local name target
  name="$(basename "$src")"
  target="$dest_dir/$name"

  if [ -L "$target" ]; then
    rm "$target"
  elif [ -e "$target" ]; then
    if confirm_overwrite "$target"; then
      rm -rf "$target"
    else
      echo -e "  ${YELLOW}SKIP${RESET} ${name%.md}"
      return 0
    fi
  fi

  mkdir -p "$dest_dir"
  ln -s "$src" "$target"
  echo -e "  ${GREEN}OK${RESET}   ${name%.md} ${DIM}-> $src${RESET}"
}

# Remove something we installed: a symlink under dest_dir pointing back into SCRIPT_DIR.
# quiet=1 suppresses the "not installed" line (used for cleanup of old layouts).
unlink_from() {
  local name="$1"
  local dest_dir="$2"
  local quiet="${3:-0}"
  local target="$dest_dir/$name"

  if [ -L "$target" ]; then
    case "$(readlink "$target")" in
      "$SCRIPT_DIR"/*)
        rm "$target"
        echo -e "  ${GREEN}RM${RESET}   ${name%.md}"
        ;;
      *)
        [ "$quiet" = 1 ] || echo -e "  ${YELLOW}SKIP${RESET} ${name%.md} ${DIM}(symlink points elsewhere)${RESET}"
        ;;
    esac
  else
    [ "$quiet" = 1 ] || echo -e "  ${DIM}MISS ${name%.md} (not installed)${RESET}"
  fi
}

# Iterate skill dirs under $SCRIPT_DIR/<group> (e.g. claude/skills), calling $fn with each.
each_skill() {
  local group="$1" fn="$2"; shift 2
  for skill_dir in "$SCRIPT_DIR/$group"/*/; do
    [ -d "$skill_dir" ] || continue
    "$fn" "${skill_dir%/}" "$@"
  done
}

each_agent() {
  local fn="$1"; shift
  for agent_file in "$SCRIPT_DIR"/claude/agents/*.md; do
    [ -f "$agent_file" ] || continue
    "$fn" "$agent_file" "$@"
  done
}

_unlink_by_path() { unlink_from "$(basename "$1")" "$2" "${3:-0}"; }

# Clean up installs from older versions of this script: ~/.codex/skills symlinks
# (deprecated dir) and ~/.codex/prompts copies (dead feature, removed in v0.118.0).
uninstall_legacy_codex() {
  local skill_dir name skill_target prompt_target
  for skill_dir in "$SCRIPT_DIR"/codex/skills/*/ "$SCRIPT_DIR"/codex/repo-skills/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "${skill_dir%/}")"

    skill_target="$CODEX_LEGACY_SKILLS_DIR/$name"
    if [ -L "$skill_target" ]; then
      case "$(readlink "$skill_target")" in
        "$SCRIPT_DIR"/*) rm "$skill_target"; echo -e "  ${GREEN}RM${RESET}   $name ${DIM}(legacy ~/.codex/skills)${RESET}" ;;
      esac
    fi

    prompt_target="$CODEX_PROMPTS_DIR/$name.md"
    if [ -L "$prompt_target" ]; then
      case "$(readlink "$prompt_target")" in
        "$SCRIPT_DIR"/*) rm "$prompt_target"; echo -e "  ${GREEN}RM${RESET}   $name.md ${DIM}(legacy prompt)${RESET}" ;;
      esac
    elif [ -f "$prompt_target" ]; then
      rm "$prompt_target"; echo -e "  ${GREEN}RM${RESET}   $name.md ${DIM}(legacy prompt)${RESET}"
    fi
  done
}

# The repo-skills used to be installed user-wide. Remove any such symlinks so the
# Status-issue workflow only runs in repos that opted in via --repo.
uninstall_legacy_global_repo_skills() {
  each_skill claude/repo-skills _unlink_by_path "$CLAUDE_SKILLS_DIR" 1
  each_skill codex/repo-skills _unlink_by_path "$CODEX_SKILLS_DIR" 1
}

# Add a path to <repo>/.git/info/exclude (idempotent) so machine-local symlinks
# never get committed.
git_exclude_add() {
  local repo="$1" pattern="$2"
  local exclude
  exclude="$(git -C "$repo" rev-parse --git-path info/exclude 2>/dev/null)" || return 0
  [[ "$exclude" = /* ]] || exclude="$repo/$exclude"
  mkdir -p "$(dirname "$exclude")"
  touch "$exclude"
  grep -qxF "$pattern" "$exclude" || echo "$pattern" >> "$exclude"
}

git_exclude_remove() {
  local repo="$1" pattern="$2"
  local exclude
  exclude="$(git -C "$repo" rev-parse --git-path info/exclude 2>/dev/null)" || return 0
  [[ "$exclude" = /* ]] || exclude="$repo/$exclude"
  [ -f "$exclude" ] || return 0
  grep -vxF "$pattern" "$exclude" > "$exclude.tmp" || true
  mv "$exclude.tmp" "$exclude"
}

_link_repo_skill() {
  local src="$1" repo="$2" sub="$3"
  link_into "$src" "$repo/$sub"
  git_exclude_add "$repo" "$sub/$(basename "$src")"
}

_unlink_repo_skill() {
  local src="$1" repo="$2" sub="$3"
  unlink_from "$(basename "$src")" "$repo/$sub"
  git_exclude_remove "$repo" "$sub/$(basename "$src")"
}

install_repo() {
  local repo="$1"
  echo -e "${BOLD}${BLUE}Claude repo skills${RESET} -> $repo/.claude/skills"
  each_skill claude/repo-skills _link_repo_skill "$repo" ".claude/skills"
  echo ""
  echo -e "${BOLD}${BLUE}Codex repo skills${RESET} -> $repo/.agents/skills"
  each_skill codex/repo-skills _link_repo_skill "$repo" ".agents/skills"
  echo ""
  echo -e "${DIM}Symlinks are machine-local and listed in .git/info/exclude.${RESET}"
}

uninstall_repo() {
  local repo="$1"
  echo -e "${BOLD}${BLUE}Removing Claude repo skills${RESET} from $repo/.claude/skills"
  each_skill claude/repo-skills _unlink_repo_skill "$repo" ".claude/skills"
  echo ""
  echo -e "${BOLD}${BLUE}Removing Codex repo skills${RESET} from $repo/.agents/skills"
  each_skill codex/repo-skills _unlink_repo_skill "$repo" ".agents/skills"
  rmdir "$repo/.claude/skills" "$repo/.claude" "$repo/.agents/skills" "$repo/.agents" 2>/dev/null || true
}

install_global() {
  echo -e "${BOLD}${BLUE}Claude skills${RESET} -> $CLAUDE_SKILLS_DIR"
  each_skill claude/skills link_into "$CLAUDE_SKILLS_DIR"
  echo ""
  echo -e "${BOLD}${BLUE}Claude agents${RESET} -> $CLAUDE_AGENTS_DIR"
  each_agent link_into "$CLAUDE_AGENTS_DIR"
  echo ""
  echo -e "${BOLD}${BLUE}Codex skills${RESET} -> $CODEX_SKILLS_DIR"
  each_skill codex/skills link_into "$CODEX_SKILLS_DIR"
  uninstall_legacy_codex
  uninstall_legacy_global_repo_skills
}

uninstall_global() {
  echo -e "${BOLD}${BLUE}Removing Claude skills${RESET} from $CLAUDE_SKILLS_DIR"
  each_skill claude/skills _unlink_by_path "$CLAUDE_SKILLS_DIR"
  echo ""
  echo -e "${BOLD}${BLUE}Removing Claude agents${RESET} from $CLAUDE_AGENTS_DIR"
  each_agent _unlink_by_path "$CLAUDE_AGENTS_DIR"
  echo ""
  echo -e "${BOLD}${BLUE}Removing Codex skills${RESET} from $CODEX_SKILLS_DIR"
  each_skill codex/skills _unlink_by_path "$CODEX_SKILLS_DIR"
  uninstall_legacy_codex
  uninstall_legacy_global_repo_skills
}

if $REPO_MODE; then
  REPO_PATH="$(cd "${REPO_PATH:-.}" && pwd)"
  if ! git -C "$REPO_PATH" rev-parse --show-toplevel >/dev/null 2>&1; then
    echo "Not a git repository: $REPO_PATH" >&2; exit 1
  fi
  REPO_PATH="$(git -C "$REPO_PATH" rev-parse --show-toplevel)"
  if $REMOVE; then uninstall_repo "$REPO_PATH"; else install_repo "$REPO_PATH"; fi
else
  if $REMOVE; then uninstall_global; else install_global; fi
fi

echo ""
echo -e "${GREEN}Done.${RESET}"
