#!/usr/bin/env bash
# Installs the Aspen Agent Kit as a skill for agents that support the
# agentskills.io format. Run from a clone of the repo:
#
#   ./install.sh                 # interactive: offers every detected agent
#   ./install.sh --all           # install for every detected agent, no prompt
#   ./install.sh --dir <path>    # install into a custom skills directory
#   ./install.sh --link          # symlink instead of copy (updates with git pull)
set -euo pipefail

KIT_NAME="aspen-agent-kit"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$SRC/SKILL.md" ]]; then
  echo "error: run install.sh from a clone of the aspen-agent-kit repo" >&2
  exit 1
fi

MODE="copy"
ALL=false
CUSTOM_DIRS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ALL=true; shift ;;
    --link) MODE="link"; shift ;;
    --dir) CUSTOM_DIRS+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

# agent name -> skills directory (the parent dir signals the agent is present)
AGENTS=(
  "Claude Code|$HOME/.claude|$HOME/.claude/skills"
  "Cursor|$HOME/.cursor|$HOME/.cursor/skills"
  "Codex|$HOME/.codex|$HOME/.codex/skills"
)

install_into() {
  local dest_root="$1"
  local dest="$dest_root/$KIT_NAME"
  mkdir -p "$dest_root"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" ]]; then
      rm -f "$dest"
    else
      # Refuse to blow away a directory we did not create without consent.
      if [[ ! -f "$dest/SKILL.md" ]] || ! grep -q '^name: aspen-agent-kit' "$dest/SKILL.md" 2>/dev/null; then
        echo "refusing to overwrite $dest — it is not an aspen-agent-kit install" >&2
        echo "remove it yourself, or pass --dir <path> to install elsewhere" >&2
        return 1
      fi
      if [[ "$ALL" != true ]]; then
        read -r -p "Replace existing install at $dest? [y/N] " ans
        [[ "$ans" =~ ^[Yy] ]] || { echo "skipped $dest"; return 0; }
      fi
      rm -rf "$dest"
    fi
  fi
  if [[ "$MODE" == "link" ]]; then
    ln -s "$SRC" "$dest"
    echo "linked  $dest -> $SRC"
  else
    mkdir -p "$dest"
    cp -R "$SRC/SKILL.md" "$SRC/README.md" "$SRC/DISCLAIMER.md" "$SRC/LICENSE" \
          "$SRC/references" "$SRC/scripts" "$dest/"
    echo "installed $dest"
  fi
}

if [[ ${#CUSTOM_DIRS[@]} -gt 0 ]]; then
  for d in "${CUSTOM_DIRS[@]}"; do install_into "$d"; done
  exit 0
fi

FOUND=false
for entry in "${AGENTS[@]}"; do
  IFS='|' read -r name marker skills_dir <<<"$entry"
  [[ -d "$marker" ]] || continue
  FOUND=true
  if [[ "$ALL" == true ]]; then
    install_into "$skills_dir"
  else
    read -r -p "Install for $name ($skills_dir)? [y/N] " ans
    [[ "$ans" =~ ^[Yy] ]] && install_into "$skills_dir"
  fi
done

if [[ "$FOUND" == false ]]; then
  echo "No supported agent detected (Claude Code, Cursor, Codex)."
  echo "Use --dir <path> to install into a custom skills directory."
  exit 1
fi

echo "Done. Restart your agent (or start a new session) to pick up the skill."
