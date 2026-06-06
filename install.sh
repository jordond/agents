#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
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

AUTO_YES=false
REMOVE=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
    --rm|--remove) REMOVE=true ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
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

# Symlink a skill directory (containing SKILL.md) into a destination skills dir.
# Codex (User scope) and Claude both follow symlinked skill folders.
link_skill() {
  local skill_dir="${1%/}"
  local dest_dir="$2"
  local skill_name target
  skill_name="$(basename "$skill_dir")"
  target="$dest_dir/$skill_name"

  if [ -L "$target" ]; then
    rm "$target"
  elif [ -e "$target" ]; then
    if confirm_overwrite "$target"; then
      rm -rf "$target"
    else
      echo -e "  ${YELLOW}SKIP${RESET} $skill_name"
      return 0
    fi
  fi

  ln -s "$skill_dir" "$target"
  echo -e "  ${GREEN}OK${RESET}   $skill_name ${DIM}-> $skill_dir${RESET}"
}

# Claude skills (each skill is a directory with SKILL.md)
install_claude_skills() {
  mkdir -p "$CLAUDE_SKILLS_DIR"
  for skill_dir in "$SCRIPT_DIR"/claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    link_skill "$skill_dir" "$CLAUDE_SKILLS_DIR"
  done
}

# Codex skills (each skill is a directory with SKILL.md). Codex 0.137.0 follows
# symlinked skill folders under $CODEX_HOME/skills (User scope), so symlink them.
install_codex_skills() {
  mkdir -p "$CODEX_SKILLS_DIR"
  for skill_dir in "$SCRIPT_DIR"/codex/skills/*/; do
    [ -d "$skill_dir" ] || continue
    link_skill "$skill_dir" "$CODEX_SKILLS_DIR"
  done
}

# Remove a skill we installed: a symlink under dest_dir pointing back into SCRIPT_DIR.
unlink_skill() {
  local skill_name="$1"
  local dest_dir="$2"
  local target="$dest_dir/$skill_name"

  if [ -L "$target" ]; then
    case "$(readlink "$target")" in
      "$SCRIPT_DIR"/*)
        rm "$target"
        echo -e "  ${GREEN}RM${RESET}   $skill_name"
        ;;
      *)
        echo -e "  ${YELLOW}SKIP${RESET} $skill_name ${DIM}(symlink points elsewhere)${RESET}"
        ;;
    esac
  else
    echo -e "  ${DIM}MISS $skill_name (not installed)${RESET}"
  fi
}

uninstall_claude_skills() {
  for skill_dir in "$SCRIPT_DIR"/claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    unlink_skill "$(basename "$skill_dir")" "$CLAUDE_SKILLS_DIR"
  done
}

uninstall_codex_skills() {
  for skill_dir in "$SCRIPT_DIR"/codex/skills/*/; do
    [ -d "$skill_dir" ] || continue
    unlink_skill "$(basename "$skill_dir")" "$CODEX_SKILLS_DIR"
  done
}

# Clean up installs from older versions of this script: ~/.codex/skills symlinks
# (deprecated dir) and ~/.codex/prompts copies (dead feature, removed in v0.118.0).
uninstall_legacy_codex() {
  for skill_dir in "$SCRIPT_DIR"/codex/skills/*/; do
    [ -d "$skill_dir" ] || continue
    name="$(basename "${skill_dir%/}")"

    # Deprecated ~/.codex/skills/<name> symlink pointing back into this repo.
    local skill_target="$CODEX_LEGACY_SKILLS_DIR/$name"
    if [ -L "$skill_target" ]; then
      case "$(readlink "$skill_target")" in
        "$SCRIPT_DIR"/*) rm "$skill_target"; echo -e "  ${GREEN}RM${RESET}   $name ${DIM}(legacy ~/.codex/skills)${RESET}" ;;
      esac
    fi

    # Dead ~/.codex/prompts/<name>.md (symlink into repo, or stale copy).
    local prompt_target="$CODEX_PROMPTS_DIR/$name.md"
    if [ -L "$prompt_target" ]; then
      case "$(readlink "$prompt_target")" in
        "$SCRIPT_DIR"/*) rm "$prompt_target"; echo -e "  ${GREEN}RM${RESET}   $name.md ${DIM}(legacy prompt)${RESET}" ;;
      esac
    elif [ -f "$prompt_target" ]; then
      rm "$prompt_target"; echo -e "  ${GREEN}RM${RESET}   $name.md ${DIM}(legacy prompt)${RESET}"
    fi
  done
}

if $REMOVE; then
  echo -e "${BOLD}${BLUE}Removing Claude skills${RESET} from $CLAUDE_SKILLS_DIR"
  uninstall_claude_skills
  echo ""
  echo -e "${BOLD}${BLUE}Removing Codex skills${RESET} from $CODEX_SKILLS_DIR"
  uninstall_codex_skills
  uninstall_legacy_codex
  echo ""
  echo -e "${GREEN}Done.${RESET}"
  exit 0
fi

echo -e "${BOLD}${BLUE}Claude skills${RESET} -> $CLAUDE_SKILLS_DIR"
install_claude_skills

echo ""
echo -e "${BOLD}${BLUE}Codex skills${RESET} -> $CODEX_SKILLS_DIR"
install_codex_skills
uninstall_legacy_codex  # remove old ~/.codex/skills + ~/.codex/prompts installs

echo ""
echo -e "${GREEN}Done.${RESET}"
