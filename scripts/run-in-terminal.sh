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

# Log helper
LOGFILE="${XDG_RUNTIME_DIR:-/tmp}/celona-upd.log"
log() { printf '%s\n' "$*" >>"$LOGFILE" 2>/dev/null || true; }

# Command to run inside terminal
if [ "$#" -eq 0 ]; then
  echo "Usage: $0 <command...>" >&2
  exit 2
fi

# Build command string to run inside the terminal
# Note: "$*" is acceptable here since our usage is a single command string.
CMD="$*; echo; echo '[Finished] Press Enter to close...'; read _"
log "run-in-terminal: invoked with CMD='$*'"
log "run-in-terminal: PATH=$PATH"
command -v ghostty >/dev/null 2>&1 && log "run-in-terminal: ghostty=$(command -v ghostty)" || log "run-in-terminal: ghostty not found"

# 1) Hyprland spawning if available AND active (more reliable from layer-shell)
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  log "run-in-terminal: using hyprctl dispatch"
  if command -v kitty >/dev/null 2>&1; then
    log "run-in-terminal: hyprctl -> kitty"
    exec hyprctl dispatch exec -- kitty sh -lc "$CMD"
  elif command -v ghostty >/dev/null 2>&1; then
    log "run-in-terminal: hyprctl -> ghostty"
    exec hyprctl dispatch exec -- ghostty -e sh -lc "$CMD"
  elif command -v alacritty >/dev/null 2>&1; then
    log "run-in-terminal: hyprctl -> alacritty"
    exec hyprctl dispatch exec -- alacritty -e sh -lc "$CMD"
  elif command -v wezterm >/dev/null 2>&1; then
    log "run-in-terminal: hyprctl -> wezterm"
    exec hyprctl dispatch exec -- wezterm start -- sh -lc "$CMD"
  elif command -v foot >/dev/null 2>&1; then
    log "run-in-terminal: hyprctl -> foot"
    exec hyprctl dispatch exec -- foot sh -lc "$CMD"
  elif command -v gnome-terminal >/dev/null 2>&1; then
    log "run-in-terminal: hyprctl -> gnome-terminal"
    exec hyprctl dispatch exec -- gnome-terminal -- sh -lc "$CMD"
  elif command -v konsole >/dev/null 2>&1; then
    log "run-in-terminal: hyprctl -> konsole"
    exec hyprctl dispatch exec -- konsole -e sh -lc "$CMD"
  elif command -v xfce4-terminal >/dev/null 2>&1; then
    log "run-in-terminal: hyprctl -> xfce4-terminal"
    exec hyprctl dispatch exec -- xfce4-terminal -e "sh -lc '$CMD'"
  fi
fi

# 2) xdg-terminal-exec if present
if command -v xdg-terminal-exec >/dev/null 2>&1; then
  log "run-in-terminal: using xdg-terminal-exec"
  # xdg-terminal-exec expects a command directly
  exec xdg-terminal-exec sh -lc "$CMD"
fi

# 3) Environment preferred TERMINAL
if [ -n "${TERMINAL:-}" ] && command -v "$TERMINAL" >/dev/null 2>&1; then
  log "run-in-terminal: using TERMINAL='$TERMINAL'"
  case "$TERMINAL" in
    kitty)         log "run-in-terminal: TERMINAL -> kitty"; exec kitty sh -lc "$CMD" ;;
    ghostty)       log "run-in-terminal: TERMINAL -> ghostty"; exec ghostty -e sh -lc "$CMD" ;;
    alacritty)     log "run-in-terminal: TERMINAL -> alacritty"; exec alacritty -e sh -lc "$CMD" ;;
    wezterm)       log "run-in-terminal: TERMINAL -> wezterm"; exec wezterm start -- sh -lc "$CMD" ;;
    foot)          log "run-in-terminal: TERMINAL -> foot"; exec foot sh -lc "$CMD" ;;
    gnome-terminal)log "run-in-terminal: TERMINAL -> gnome-terminal"; exec gnome-terminal -- sh -lc "$CMD" ;;
    konsole)       log "run-in-terminal: TERMINAL -> konsole"; exec konsole -e sh -lc "$CMD" ;;
    xfce4-terminal)log "run-in-terminal: TERMINAL -> xfce4-terminal"; exec xfce4-terminal -e "sh -lc '$CMD'" ;;
    xterm)         log "run-in-terminal: TERMINAL -> xterm"; exec xterm -e sh -lc "$CMD" ;;
  esac
fi

# 4) Probe common terminals in order
if command -v kitty >/dev/null 2>&1; then
  log "run-in-terminal: probe -> kitty"; exec kitty sh -lc "$CMD"
elif command -v ghostty >/dev/null 2>&1; then
  log "run-in-terminal: probe -> ghostty"; exec ghostty -e sh -lc "$CMD"
elif command -v alacritty >/dev/null 2>&1; then
  log "run-in-terminal: probe -> alacritty"; exec alacritty -e sh -lc "$CMD"
elif command -v wezterm >/dev/null 2>&1; then
  log "run-in-terminal: probe -> wezterm"; exec wezterm start -- sh -lc "$CMD"
elif command -v foot >/dev/null 2>&1; then
  log "run-in-terminal: probe -> foot"; exec foot sh -lc "$CMD"
elif command -v gnome-terminal >/dev/null 2>&1; then
  log "run-in-terminal: probe -> gnome-terminal"; exec gnome-terminal -- sh -lc "$CMD"
elif command -v konsole >/dev/null 2>&1; then
  log "run-in-terminal: probe -> konsole"; exec konsole -e sh -lc "$CMD"
elif command -v xfce4-terminal >/dev/null 2>&1; then
  log "run-in-terminal: probe -> xfce4-terminal"; exec xfce4-terminal -e "sh -lc '$CMD'"
elif command -v xterm >/dev/null 2>&1; then
  log "run-in-terminal: probe -> xterm"; exec xterm -e sh -lc "$CMD"
fi

notify "Konnte kein Terminal finden. Bitte installiere z. B. kitty, alacritty, wezterm, foot, gnome-terminal, konsole, xfce4-terminal oder xterm."
log "run-in-terminal: no terminal found"
echo "Error: No terminal emulator found in PATH" >&2
exit 1
