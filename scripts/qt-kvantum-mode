#!/usr/bin/env bash
# qt-kvantum-mode: switches between Dark/Light
# usage: qt-kvantum-mode dark | light
set -euo pipefail

KVCONF="${XDG_CONFIG_HOME:-$HOME/.config}/Kvantum/kvantum.kvconfig"

# set the two kvantum theme files here
LIGHT_THEME="${LIGHT_THEME:-KvGlassWhite}"
DARK_THEME="${DARK_THEME:-KvGlass}"

case "${1:-}" in
  dark)  THEME="$DARK_THEME" ;;
  light) THEME="$LIGHT_THEME" ;;
  *) echo "Usage: $(basename "$0") {dark|light}"; exit 2 ;;
esac

mkdir -p "$(dirname "$KVCONF")"

if grep -q '^theme=' "$KVCONF" 2>/dev/null; then
  sed -i "s/^theme=.*/theme=$THEME/" "$KVCONF"
else
  printf 'theme=%s\n' "$THEME" > "$KVCONF"
fi

echo "Kvantum → $THEME set. Restart your Qt-Apps to see the effect."
