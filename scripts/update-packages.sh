#!/usr/bin/env sh
# Portable updater: runs paru -Syu or yay -Syu depending on theme.json (aurHelper)
# Works under sh/bash/zsh/fish (invoked via sh)
set -eu

# Resolve project root (../ from this script directory)
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="${SCRIPT_DIR%/scripts}"
THEME_JSON="$ROOT_DIR/theme.json"

# Read aurHelper from theme.json without external deps (jq optional)
read_aur_helper() {
  if [ -f "$THEME_JSON" ]; then
    # Try jq if present for robust parsing
    if command -v jq >/dev/null 2>&1; then
      val=$(jq -r '."aurHelper" // empty' "$THEME_JSON" 2>/dev/null || true)
      [ "${val:-}" != "null" ] && [ -n "${val:-}" ] && {
        printf '%s\n' "$val"
        return 0
      }
    fi
    # Fallback: naive sed extraction of "aurHelper": "VALUE"
    val=$(sed -n 's/.*"aurHelper"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$THEME_JSON" | head -n1)
    if [ -n "${val:-}" ]; then
      printf '%s\n' "$val"
      return 0
    fi
  fi
  return 1
}

HELPER=""
if HELPER=$(read_aur_helper); then
  :
else
  # Auto-detect if not specified
  if command -v paru >/dev/null 2>&1; then
    HELPER=paru
  elif command -v yay >/dev/null 2>&1; then
    HELPER=yay
  else
    printf 'Error: No AUR helper specified in theme.json (aurHelper) and neither paru nor yay found in PATH.\n' >&2
    exit 1
  fi
fi

case "$HELPER" in
  paru|yay) : ;;
  *) printf 'Error: Unsupported aurHelper "%s". Supported: paru, yay.\n' "$HELPER" >&2; exit 1 ;;
 esac

# Run system upgrade
exec "$HELPER" -Syu
