#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CODEX_PROMPTS_DIR="$HOME/.codex/prompts"

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

# Claude skills (each skill is a directory with SKILL.md)
install_claude_skills() {
  mkdir -p "$CLAUDE_SKILLS_DIR"

  for skill_dir in "$SCRIPT_DIR"/claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    target="$CLAUDE_SKILLS_DIR/$skill_name"

    if [ -L "$target" ]; then
      rm "$target"
    elif [ -e "$target" ]; then
      if confirm_overwrite "$target"; then
        rm -rf "$target"
      else
        echo -e "  ${YELLOW}SKIP${RESET} $skill_name"
        continue
      fi
    fi

    ln -s "$skill_dir" "$target"
    echo -e "  ${GREEN}OK${RESET}   $skill_name ${DIM}-> $skill_dir${RESET}"
  done
}

# Codex prompts (each prompt is a single .md file -> /name slash command)
install_codex_prompts() {
  mkdir -p "$CODEX_PROMPTS_DIR"

  for prompt_file in "$SCRIPT_DIR"/codex/prompts/*.md; do
    [ -f "$prompt_file" ] || continue
    prompt_name="$(basename "$prompt_file")"
    target="$CODEX_PROMPTS_DIR/$prompt_name"

    if [ -L "$target" ]; then
      rm "$target"
    elif [ -e "$target" ]; then
      if confirm_overwrite "$target"; then
        rm -rf "$target"
      else
        echo -e "  ${YELLOW}SKIP${RESET} $prompt_name"
        continue
      fi
    fi

    ln -s "$prompt_file" "$target"
    echo -e "  ${GREEN}OK${RESET}   $prompt_name ${DIM}-> $prompt_file${RESET}"
  done
}

# Remove skills this repo installed (symlinks pointing back into SCRIPT_DIR)
uninstall_claude_skills() {
  for skill_dir in "$SCRIPT_DIR"/claude/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    target="$CLAUDE_SKILLS_DIR/$skill_name"

    if [ -L "$target" ]; then
      link_dest="$(readlink "$target")"
      case "$link_dest" in
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
  done
}

# Remove codex prompts this repo installed (symlinks pointing back into SCRIPT_DIR)
uninstall_codex_prompts() {
  for prompt_file in "$SCRIPT_DIR"/codex/prompts/*.md; do
    [ -f "$prompt_file" ] || continue
    prompt_name="$(basename "$prompt_file")"
    target="$CODEX_PROMPTS_DIR/$prompt_name"

    if [ -L "$target" ]; then
      link_dest="$(readlink "$target")"
      case "$link_dest" in
        "$SCRIPT_DIR"/*)
          rm "$target"
          echo -e "  ${GREEN}RM${RESET}   $prompt_name"
          ;;
        *)
          echo -e "  ${YELLOW}SKIP${RESET} $prompt_name ${DIM}(symlink points elsewhere)${RESET}"
          ;;
      esac
    else
      echo -e "  ${DIM}MISS $prompt_name (not installed)${RESET}"
    fi
  done
}

if $REMOVE; then
  echo -e "${BOLD}${BLUE}Removing Claude skills${RESET} from $CLAUDE_SKILLS_DIR"
  uninstall_claude_skills
  echo ""
  echo -e "${BOLD}${BLUE}Removing Codex prompts${RESET} from $CODEX_PROMPTS_DIR"
  uninstall_codex_prompts
  echo ""
  echo -e "${GREEN}Done.${RESET}"
  exit 0
fi

echo -e "${BOLD}${BLUE}Claude skills${RESET} -> $CLAUDE_SKILLS_DIR"
install_claude_skills

echo ""
echo -e "${BOLD}${BLUE}Codex prompts${RESET} -> $CODEX_PROMPTS_DIR"
install_codex_prompts

echo ""
echo -e "${GREEN}Done.${RESET}"
