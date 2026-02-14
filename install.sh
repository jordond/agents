#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
OPENCODE_COMMANDS_DIR="$HOME/.opencode/commands"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

AUTO_YES=false
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  AUTO_YES=true
fi

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

# Opencode commands (each command is a .md file)
install_opencode_commands() {
  mkdir -p "$OPENCODE_COMMANDS_DIR"

  for cmd_file in "$SCRIPT_DIR"/opencode/*.md; do
    [ -f "$cmd_file" ] || continue
    cmd_name="$(basename "$cmd_file")"
    target="$OPENCODE_COMMANDS_DIR/$cmd_name"

    if [ -L "$target" ]; then
      rm "$target"
    elif [ -e "$target" ]; then
      if confirm_overwrite "$target"; then
        rm -rf "$target"
      else
        echo -e "  ${YELLOW}SKIP${RESET} $cmd_name"
        continue
      fi
    fi

    ln -s "$cmd_file" "$target"
    echo -e "  ${GREEN}OK${RESET}   $cmd_name ${DIM}-> $cmd_file${RESET}"
  done
}

echo -e "${BOLD}${BLUE}Claude skills${RESET} -> $CLAUDE_SKILLS_DIR"
install_claude_skills

echo ""
echo -e "${BOLD}${BLUE}OpenCode commands${RESET} -> $OPENCODE_COMMANDS_DIR"
install_opencode_commands

echo ""
echo -e "${GREEN}Done.${RESET}"
