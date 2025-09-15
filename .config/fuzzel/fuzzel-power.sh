#!/usr/bin/env bash
# Power menu for fuzzel that works on Hyprland and Niri (and generally on systemd systems)
set -euo pipefail

APP_NAME="fuzzel-power"
PROMPT_ICON="  "
WIDTH=${WIDTH:-34}
LINES=${LINES:-6}

have() { command -v "$1" >/dev/null 2>&1; }
notify() { if have notify-send; then notify-send --app-name="$APP_NAME" --icon=system-shutdown "$1" "${2:-}"; fi }

# Detect compositor/env
is_hyprland() { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && have hyprctl; }
is_niri() { have niri; }

# Build menu
build_menu() {
  cat <<'EOF'
Lock
Suspend
Reboot
Poweroff
Logout
EOF
}

selection=$(build_menu | fuzzel --dmenu --prompt="$PROMPT_ICON" --width="$WIDTH" --lines="$LINES")
[[ -z "${selection:-}" ]] && exit 0

case "$selection" in
  "Lock")
    if have hyprlock; then
      hyprlock &
      notify "Lock" "Lock screen activated."
    elif have swaylock; then
      swaylock &
      notify "Lock" "Lock screen (swaylock) activated."
    else
      notify "Lock" "No lock utility found (tried hyprlock, swaylock)." || true
      exit 1
    fi
    ;;
  "Suspend")
    # Try loginctl first, fallback to systemctl
    (have loginctl && loginctl suspend) || systemctl suspend
    ;;
  "Reboot")
    # Optional confirmation
    confirm=$(printf '%s\n%s\n' "Yes" "No" | fuzzel --dmenu --prompt="Reboot?  " --width=20 --lines=2)
    [[ "$confirm" == "Yes" ]] || exit 0
    (have loginctl && loginctl reboot) || systemctl reboot
    ;;
  "Poweroff")
    confirm=$(printf '%s\n%s\n' "Yes" "No" | fuzzel --dmenu --prompt="Poweroff?  " --width=20 --lines=2)
    [[ "$confirm" == "Yes" ]] || exit 0
    (have loginctl && loginctl poweroff) || systemctl poweroff
    ;;
  "Logout")
    if is_hyprland; then
      hyprctl dispatch exit
    elif is_niri; then
      niri msg action quit --skip-confirmation
    else
      notify "Logout" "No supported compositor logout found."
      exit 1
    fi
    ;;
  *)
    exit 0
    ;;
 esac

exit 0
