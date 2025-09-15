#!/usr/bin/env bash
# Browse cliphist entries via fuzzel and copy selection to clipboard with notification
set -euo pipefail

APP_NAME="fuzzel-cliphist"
PROMPT_ICON="󰆍 "
LINES=${LINES:-15}
WIDTH=${WIDTH:-60}

# Check dependencies (soft checks; we continue but adjust behavior)
have() { command -v "$1" >/dev/null 2>&1; }

if ! have cliphist; then
  echo "Error: cliphist not found in PATH" >&2
  exit 1
fi

# Build menu and get selection
selection=$(cliphist list | fuzzel --dmenu --prompt="$PROMPT_ICON" --width="$WIDTH" --lines="$LINES")
[[ -z "${selection:-}" ]] && exit 0

# Decode to get the original clipboard content
content=$(printf '%s' "$selection" | cliphist decode)

# Copy to clipboard (wl-copy preferred)
if have wl-copy; then
  printf '%s' "$content" | wl-copy --trim-newline
elif have xclip; then
  printf '%s' "$content" | xclip -selection clipboard
else
  echo "Warning: neither wl-copy nor xclip found; cannot copy to clipboard" >&2
  exit 1
fi

# Generate a short preview for notification (single-line, truncated)
preview=$(printf '%s' "$content" | tr '\n' ' ' | sed 's/\s\+/ /g' | cut -c1-120)
[ -z "$preview" ] && preview="(binary or empty content)"

# Notify user
if have notify-send; then
  notify-send --app-name="$APP_NAME" --icon=edit-paste "Clipboard" "Entry copied to clipboard: $preview"
fi

exit 0
