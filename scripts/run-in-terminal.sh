#!/usr/bin/env sh
# Run a given command in an available terminal emulator.
# Prefers Hyprland exec, then xdg-terminal-exec, then common terminals.
# Usage: run-in-terminal.sh <command...>
set -eu

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Celona Updates" "$1" || true
  fi
}

# Command to run inside terminal
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <command...>" >&2
  exit 2
fi

# Build command string to run inside the terminal
# Note: "$*" is acceptable here since our usage is a single command string.
CMD="$*; echo; echo '[Finished] Press Enter to close...'; read _"

# 1) Hyprland spawning if available (more reliable from layer-shell)
if command -v hyprctl >/dev/null 2>&1; then
  if command -v kitty >/dev/null 2>&1; then
    exec hyprctl dispatch exec -- kitty sh -lc "$CMD"
  elif command -v alacritty >/dev/null 2>&1; then
    exec hyprctl dispatch exec -- alacritty -e sh -lc "$CMD"
  elif command -v wezterm >/dev/null 2>&1; then
    exec hyprctl dispatch exec -- wezterm start -- sh -lc "$CMD"
  elif command -v foot >/dev/null 2>&1; then
    exec hyprctl dispatch exec -- foot sh -lc "$CMD"
  elif command -v gnome-terminal >/dev/null 2>&1; then
    exec hyprctl dispatch exec -- gnome-terminal -- sh -lc "$CMD"
  elif command -v konsole >/dev/null 2>&1; then
    exec hyprctl dispatch exec -- konsole -e sh -lc "$CMD"
  elif command -v xfce4-terminal >/dev/null 2>&1; then
    exec hyprctl dispatch exec -- xfce4-terminal -e "sh -lc '$CMD'"
  fi
fi

# 2) xdg-terminal-exec if present
if command -v xdg-terminal-exec >/dev/null 2>&1; then
  # xdg-terminal-exec expects a command directly
  exec xdg-terminal-exec sh -lc "$CMD"
fi

# 3) Environment preferred TERMINAL
if [ -n "${TERMINAL:-}" ] && command -v "$TERMINAL" >/dev/null 2>&1; then
  case "$TERMINAL" in
    kitty)       exec kitty sh -lc "$CMD" ;;
    alacritty)   exec alacritty -e sh -lc "$CMD" ;;
    wezterm)     exec wezterm start -- sh -lc "$CMD" ;;
    foot)        exec foot sh -lc "$CMD" ;;
    gnome-terminal) exec gnome-terminal -- sh -lc "$CMD" ;;
    konsole)     exec konsole -e sh -lc "$CMD" ;;
    xfce4-terminal) exec xfce4-terminal -e "sh -lc '$CMD'" ;;
    xterm)       exec xterm -e sh -lc "$CMD" ;;
  esac
fi

# 4) Probe common terminals in order
if command -v kitty >/dev/null 2>&1; then
  exec kitty sh -lc "$CMD"
elif command -v alacritty >/dev/null 2>&1; then
  exec alacritty -e sh -lc "$CMD"
elif command -v wezterm >/dev/null 2>&1; then
  exec wezterm start -- sh -lc "$CMD"
elif command -v foot >/dev/null 2>&1; then
  exec foot sh -lc "$CMD"
elif command -v gnome-terminal >/dev/null 2>&1; then
  exec gnome-terminal -- sh -lc "$CMD"
elif command -v konsole >/dev/null 2>&1; then
  exec konsole -e sh -lc "$CMD"
elif command -v xfce4-terminal >/dev/null 2>&1; then
  exec xfce4-terminal -e "sh -lc '$CMD'"
elif command -v xterm >/dev/null 2>&1; then
  exec xterm -e sh -lc "$CMD"
fi

notify "Konnte kein Terminal finden. Bitte installiere z. B. kitty, alacritty, wezterm, foot, gnome-terminal, konsole, xfce4-terminal oder xterm."
echo "Error: No terminal emulator found in PATH" >&2
exit 1
