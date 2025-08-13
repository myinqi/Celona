#!/usr/bin/env sh
# Print pending updates as lines. Uses aurHelper from theme.json when possible.
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/scripts}"
THEME_JSON="$ROOT_DIR/theme.json"

read_aur_helper() {
  if [ -f "$THEME_JSON" ]; then
    if command -v jq >/dev/null 2>&1; then
      val=$(jq -r '."aurHelper" // empty' "$THEME_JSON" 2>/dev/null || true)
      [ "${val:-}" != "null" ] && [ -n "${val:-}" ] && { printf '%s\n' "$val"; return 0; }
    fi
    val=$(sed -n 's/.*"aurHelper"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$THEME_JSON" | head -n1)
    [ -n "${val:-}" ] && { printf '%s\n' "$val"; return 0; }
  fi
  return 1
}

HELPER=""
if HELPER=$(read_aur_helper); then :; else HELPER=""; fi

strip_ansi() { sed -r 's/\x1B\[[0-9;]*[mK]//g'; }

print_pacman() {
  # Prefer checkupdates if available (repo updates), else fall back to pacman -Qu
  if command -v checkupdates >/dev/null 2>&1; then
    checkupdates 2>/dev/null | strip_ansi || true
  else
    pacman -Qu 2>/dev/null | strip_ansi || true
  fi
}

case "$HELPER" in
  yay)
    # yay may colorize; disable color and combine AUR + repo
    if command -v yay >/dev/null 2>&1; then
      { yay -Qua --color=never 2>/dev/null; print_pacman; } | awk '!(seen[$0]++)'
    else
      print_pacman
    fi
    ;;
  paru)
    # paru separates AUR (-Qua) and repo (-Qu); combine both
    if command -v paru >/dev/null 2>&1; then
      { paru -Qua --color=never 2>/dev/null | strip_ansi; print_pacman; } | awk '!(seen[$0]++)'
    else
      print_pacman
    fi
    ;;
  "")
    # No helper configured; show repo updates at least
    print_pacman
    ;;
  *)
    # Unknown helper: try it with -Qu, then fall back to pacman
    if command -v "$HELPER" >/dev/null 2>&1; then
      "$HELPER" -Qu 2>/dev/null | strip_ansi || true
    else
      print_pacman
    fi
    ;;
 esac
