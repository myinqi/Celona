#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# Resolve repository root (one level up from this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_JSON="${REPO_DIR}/config.json"
COLORS_CSS="${REPO_DIR}/colors.css"
MODE_FILE="${REPO_DIR}/colors.mode"

# State file to remember last mode
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/Celona"
STATE_FILE="${STATE_DIR}/matugen_mode"
mkdir -p "${STATE_DIR}"

usage() {
  echo -e "Usage: $(basename "$0") [--force light|dark]" >&2
}

# Dependencies
need() {
  command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}Missing dependency:${RESET} $1" >&2; exit 1; }
}

need matugen
need jq
# ffmpeg is optional unless we only have an animated wallpaper

# Parse args
FORCE_MODE=""
if [[ "${1:-}" == "--force" && -n "${2:-}" ]]; then
  case "$2" in
    light|dark) FORCE_MODE="$2" ; shift 2 ;;
    *) usage; exit 2 ;;
  esac
elif [[ "${1:-}" == "--help" ]]; then
  usage; exit 0
fi

# Read paths from config.json
if [[ ! -f "${CONFIG_JSON}" ]]; then
  echo -e "${RED}config.json not found at${RESET} ${CONFIG_JSON}" >&2
  exit 1
fi

static_path=$(jq -r '.wallpaperStaticPath // ""' "${CONFIG_JSON}")
animated_path=$(jq -r '.wallpaperAnimatedPath // ""' "${CONFIG_JSON}")

# Expand leading ~ for user paths
expand_home() {
  local p="$1"
  if [[ "$p" == ~* ]]; then
    echo "${p/#~/$HOME}"
  else
    echo "$p"
  fi
}

static_path=$(expand_home "$static_path")
animated_path=$(expand_home "$animated_path")

# Determine source image for Matugen
SRC_IMAGE=""
TEMP_IMAGE=""
cleanup() { [[ -n "$TEMP_IMAGE" && -f "$TEMP_IMAGE" ]] && rm -f "$TEMP_IMAGE"; }
trap cleanup EXIT

if [[ -n "$static_path" && -f "$static_path" ]]; then
  SRC_IMAGE="$static_path"
  echo -e "${CYAN}Using static wallpaper:${RESET} $SRC_IMAGE"
else
  if [[ -n "$animated_path" && -f "$animated_path" ]]; then
    if command -v ffmpeg >/dev/null 2>&1; then
      TEMP_IMAGE="$(mktemp /tmp/celona_matugen_XXXXXX.png)"
      echo -e "${CYAN}No static wallpaper set. Extracting first frame from animated wallpaper:${RESET} $animated_path"
      # Extract the first frame (n=0) as PNG
      ffmpeg -y -loglevel error -i "$animated_path" -frames:v 1 "$TEMP_IMAGE"
      if [[ ! -s "$TEMP_IMAGE" ]]; then
        echo -e "${RED}Failed to extract frame from video with ffmpeg.${RESET}" >&2
        exit 1
      fi
      SRC_IMAGE="$TEMP_IMAGE"
      echo -e "${CYAN}Extracted frame:${RESET} $SRC_IMAGE"
    else
      echo -e "${RED}ffmpeg is required to extract a frame from animated wallpaper but is not installed.${RESET}" >&2
      exit 1
    fi
  else
    echo -e "${RED}No usable wallpaper found.${RESET} Set 'wallpaperStaticPath' in ${CONFIG_JSON} or provide a valid animated wallpaper." >&2
    exit 1
  fi
fi

# Decide mode: toggle or forced
MODE=""
if [[ -n "$FORCE_MODE" ]]; then
  MODE="$FORCE_MODE"
else
  if [[ -f "$STATE_FILE" ]]; then
    last=$(<"$STATE_FILE")
    case "$last" in
      light) MODE="dark" ;;
      dark)  MODE="light" ;;
      *)     MODE="dark" ;;
    esac
  else
    # Default first run
    MODE="dark"
  fi
fi

echo -e "${GREEN}Generating Matugen theme in mode:${RESET} ${MODE}"

# Run matugen in repo root so colors.css lands there
pushd "$REPO_DIR" >/dev/null
matugen -v image "$SRC_IMAGE" -m "$MODE"
popd >/dev/null

if [[ -f "$COLORS_CSS" ]]; then
  echo -e "${GREEN}colors.css generated at:${RESET} $COLORS_CSS"
else
  echo -e "${YELLOW}Warning:${RESET} colors.css not found at repo root after running matugen.\n" \
          "Ensure your matugen version writes colors.css to the current directory." >&2
fi

# Toggle GTK theme to match
echo -e "${CYAN}Syncing GTK color scheme...${RESET}"
if [[ "$MODE" == "dark" ]]; then
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  echo -e "${GREEN}GTK theme set to:${RESET} prefer-dark"
else
  gsettings set org.gnome.desktop.interface color-scheme 'default'
  echo -e "${GREEN}GTK theme set to:${RESET} default (light)"
fi

# Persist new mode for next toggle
echo "$MODE" > "$STATE_FILE"
echo "$MODE" > "$MODE_FILE"
echo -e "${CYAN}Next toggle will switch to:${RESET} $( [[ "$MODE" == "dark" ]] && echo light || echo dark )"
