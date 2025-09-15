#!/usr/bin/env bash
set -euo pipefail

# toggle-game-mode.sh
# Tries to toggle Celona Game Mode via Quickshell IPC. Works across environments.
# Strategy:
# 1) Try common IPC client names without explicit socket.
# 2) If that fails, enumerate sockets under $XDG_RUNTIME_DIR/quickshell/*.sock and try each.
# 3) Try both `quickshell` and `qs` frontends.

try_call() {
  local bin="$1"; shift
  if command -v "$bin" >/dev/null 2>&1; then
    if "$bin" ipc call bar toggleGameMode >/dev/null 2>&1; then
      echo "Game Mode toggled via $bin"
      return 0
    fi
  fi
  return 1
}

# 1) Direct attempts (auto socket detection if supported)
try_call quickshell && exit 0 || true
try_call qs && exit 0 || true

# 2) Socket enumeration
SOCK_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/quickshell"
if [ -d "$SOCK_DIR" ]; then
  for sock in "$SOCK_DIR"/*.sock; do
    [ -e "$sock" ] || continue
    if command -v quickshell >/dev/null 2>&1; then
      if quickshell ipc --socket "$sock" call bar toggleGameMode >/dev/null 2>&1; then
        echo "Game Mode toggled via quickshell (socket: $sock)"
        exit 0
      fi
    fi
    if command -v qs >/dev/null 2>&1; then
      if qs ipc --socket "$sock" call bar toggleGameMode >/dev/null 2>&1; then
        echo "Game Mode toggled via qs (socket: $sock)"
        exit 0
      fi
    fi
  done
fi

# 3) Fallback: file-trigger toggle (handled by Celona Globals)
TOGGLE_FILE="$HOME/.config/quickshell/Celona/tmp/game_mode_toggle"
mkdir -p "$(dirname "$TOGGLE_FILE")"
printf '' > "$TOGGLE_FILE"
echo "Game Mode toggle requested via file trigger ($TOGGLE_FILE)"
exit 0
