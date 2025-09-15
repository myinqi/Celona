#!/usr/bin/env bash
# Create .desktop entries for fuzzel-emoji and fuzzel-hyprpicker if missing
set -euo pipefail

APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fuzzel"
EMOJI_SCRIPT="$CFG_DIR/fuzzel-emoji.sh"
HYPRPICKER_SCRIPT="$CFG_DIR/fuzzel-hyprpicker.sh"
CLIPHIST_SCRIPT="$CFG_DIR/fuzzel-cliphist.sh"
POWER_SCRIPT="$CFG_DIR/fuzzel-power.sh"
EMOJI_DESKTOP="$APP_DIR/fuzzel-emoji.desktop"
HYPRPICKER_DESKTOP="$APP_DIR/fuzzel-hyprpicker.desktop"
CLIPHIST_DESKTOP="$APP_DIR/fuzzel-cliphist.desktop"
POWER_DESKTOP="$APP_DIR/fuzzel-power.desktop"
ICON_DIR="$CFG_DIR/icons"
EMOJI_ICON="$ICON_DIR/emoji.svg"
COLOR_ICON="$ICON_DIR/color.svg"
CLIPBOARD_ICON="$ICON_DIR/clipboard.svg"
POWER_ICON="$ICON_DIR/power.svg"

mkdir -p "$APP_DIR" "$ICON_DIR"

# --- Icon creators (idempotent) ---
create_emoji_icon() {
  [[ -f "$EMOJI_ICON" ]] && return 0
  cat > "$EMOJI_ICON" <<'EOF'
<svg width="128" height="128" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FFD76A"/>
      <stop offset="100%" stop-color="#FFC036"/>
    </linearGradient>
  </defs>
  <circle cx="64" cy="64" r="60" fill="url(#g)" stroke="#E0A21A" stroke-width="4"/>
  <circle cx="46" cy="52" r="7" fill="#3B3B3B"/>
  <circle cx="82" cy="52" r="7" fill="#3B3B3B"/>
  <path d="M36 78c8 10 22 16 28 16s20-6 28-16" fill="none" stroke="#3B3B3B" stroke-width="6" stroke-linecap="round"/>
</svg>
EOF
}

create_color_icon() {
  [[ -f "$COLOR_ICON" ]] && return 0
  cat > "$COLOR_ICON" <<'EOF'
<svg width="128" height="128" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <rect width="128" height="128" rx="20" ry="20" fill="#222"/>
  <circle cx="40" cy="44" r="16" fill="#E74C3C"/>
  <circle cx="88" cy="44" r="16" fill="#F1C40F"/>
  <circle cx="40" cy="92" r="16" fill="#2ECC71"/>
  <circle cx="88" cy="92" r="16" fill="#3498DB"/>
  <path d="M20 20 L108 108" stroke="#aaa" stroke-width="4" stroke-linecap="round" opacity="0.25"/>
</svg>
EOF
}

create_clipboard_icon() {
  [[ -f "$CLIPBOARD_ICON" ]] && return 0
  cat > "$CLIPBOARD_ICON" <<'EOF'
<svg width="128" height="128" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <rect x="28" y="20" width="72" height="96" rx="10" ry="10" fill="#ECEFF4" stroke="#4C566A" stroke-width="4"/>
  <rect x="46" y="12" width="36" height="20" rx="6" ry="6" fill="#81A1C1" stroke="#4C566A" stroke-width="4"/>
  <rect x="40" y="40" width="48" height="8" fill="#4C566A" opacity="0.6"/>
  <rect x="40" y="56" width="48" height="8" fill="#4C566A" opacity="0.6"/>
  <rect x="40" y="72" width="36" height="8" fill="#4C566A" opacity="0.6"/>
</svg>
EOF
}

create_power_icon() {
  [[ -f "$POWER_ICON" ]] && return 0
  cat > "$POWER_ICON" <<'EOF'
<svg width="128" height="128" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="pg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#FF5A5F"/>
      <stop offset="100%" stop-color="#C81E3A"/>
    </linearGradient>
  </defs>
  <circle cx="64" cy="64" r="58" fill="url(#pg)" stroke="#7A0F1F" stroke-width="4"/>
  <rect x="58" y="18" width="12" height="42" rx="6" fill="#fff"/>
  <path d="M40 48 a32 32 0 1 0 48 0" fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round"/>
</svg>
EOF
}

create_emoji_desktop() {
  cat > "$EMOJI_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Picker: Emoji
Comment=Pick and type/copy emojis via fuzzel
Exec=$EMOJI_SCRIPT
Icon=$EMOJI_ICON
Terminal=false
Categories=Utility;
Keywords=picker;emoji;fuzzel;emoticon;
StartupNotify=false
NoDisplay=false
EOF
}

create_hyprpicker_desktop() {
  cat > "$HYPRPICKER_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Picker: Color
Comment=Pick colors and manage history
Exec=$HYPRPICKER_SCRIPT
Icon=$COLOR_ICON
Terminal=false
Categories=Utility;Graphics;
Keywords=picker;color;hyprpicker;fuzzel;palette;
StartupNotify=false
NoDisplay=false
EOF
}

create_cliphist_desktop() {
  cat > "$CLIPHIST_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Picker: Clipboard
Comment=Browse and copy clipboard history via cliphist and fuzzel
Exec=$CLIPHIST_SCRIPT
Icon=$CLIPBOARD_ICON
Terminal=false
Categories=Utility;
Keywords=picker;clipboard;history;cliphist;fuzzel;paste;
StartupNotify=false
NoDisplay=false
EOF
}

create_power_desktop() {
  cat > "$POWER_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Picker: Power
Comment=Power menu (Lock, Suspend, Reboot, Poweroff, Logout) for Hyprland and Niri
Exec=$POWER_SCRIPT
Icon=$POWER_ICON
Terminal=false
Categories=System;Utility;
Keywords=picker;power;shutdown;reboot;suspend;logout;lock;hyprland;niri;
StartupNotify=false
NoDisplay=false
EOF
}

# Create if missing
# Ensure icons exist first
create_emoji_icon
create_color_icon
create_clipboard_icon
create_power_icon

if [[ ! -f "$EMOJI_DESKTOP" ]]; then
  echo "Creating $EMOJI_DESKTOP"
  create_emoji_desktop
fi

if [[ ! -f "$HYPRPICKER_DESKTOP" ]]; then
  echo "Creating $HYPRPICKER_DESKTOP"
  create_hyprpicker_desktop
fi

if [[ ! -f "$CLIPHIST_DESKTOP" ]]; then
  echo "Creating $CLIPHIST_DESKTOP"
  create_cliphist_desktop
fi

if [[ ! -f "$POWER_DESKTOP" ]]; then
  echo "Creating $POWER_DESKTOP"
  create_power_desktop
fi

# Ensure scripts are executable (best-effort)
chmod +x "$EMOJI_SCRIPT" 2>/dev/null || true
chmod +x "$HYPRPICKER_SCRIPT" 2>/dev/null || true
chmod +x "$CLIPHIST_SCRIPT" 2>/dev/null || true
chmod +x "$POWER_SCRIPT" 2>/dev/null || true

# Refresh desktop database if available
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APP_DIR" || true
fi

# Optional notify
if command -v notify-send >/dev/null 2>&1; then
  notify-send --app-name="fuzzel-setup" --icon=applications-system "Fuzzel Setup" "Desktop entries ensured in $APP_DIR"
fi

echo "Done. If you don't see the entries immediately, try reopening your launcher."
