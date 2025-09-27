#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

# Runtime dir (bevorzugt XDG_RUNTIME_DIR)
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/celona-brightness"
mkdir -p "$RUNTIME_DIR"

LOCK_FILE="$RUNTIME_DIR/monitor-brightness.lock"
STATE_FILE="$RUNTIME_DIR/monitor-brightness.last_ns"
LASTVAL_FILE="$RUNTIME_DIR/monitor-brightness.last_val"

# 0.5 Sekunden in Nanosekunden (konfigurierbar via ENV)
RATE_LIMIT_NS="${RATE_LIMIT_NS:-500000000}"

usage() {
  echo "Usage: $0 [+STEP|-STEP|VALUE] [all|--all] [--bus N]" >&2
  exit 1
}

arg="${1:-}"; shift || true
[[ -z "$arg" ]] && usage

ALL=0
BUS_OPT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    all|--all)
      ALL=1; shift ;;
    --bus)
      [[ $# -ge 2 ]] || usage
      BUS_OPT="--bus $2"; shift 2 ;;
    *) usage ;;
  esac
done

have_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! have_cmd ddcutil; then
  echo "Error: ddcutil not found. Install ddcutil and ensure i2c permissions." >&2
  exit 2
fi

# Optional: autodetect primary bus if not provided
detect_primary_bus() {
  # Liefert z. B. "--bus 5" oder leere Zeichenkette, wenn nicht ermittelbar
  local bus
  bus="$(ddcutil detect 2>/dev/null | awk '
    BEGIN{b=""}
    /Display [0-9]+:/ {cur=""}
    /I2C bus: bus/ { if ($0 ~ /I2C bus: bus/) { gsub(/.*bus ([0-9]+).*/, "\\1"); cur=$0 } }
    /Primary: Yes/ { if (cur ~ /^[0-9]+$/) { print cur; exit } }
  ')"
  if [[ "$bus" =~ ^[0-9]+$ ]]; then
    echo "--bus $bus"
  else
    echo ""
  fi
}

if [[ -z "$BUS_OPT" ]]; then
  BUS_OPT="$(detect_primary_bus)" || true
fi

read_current() {
  # Falls wir einen zuletzt gesetzten Wert haben, nutze ihn als Hint
  if [[ -f "$LASTVAL_FILE" ]]; then
    local lv
    lv="$(<"$LASTVAL_FILE")"
    if [[ "$lv" =~ ^[0-9]+$ ]] && (( lv >= 0 && lv <= 100 )); then
      echo "$lv"
      return 0
    fi
  fi
  # Direkter Read via ddcutil
  ddcutil getvcp 0x10 $BUS_OPT 2>/dev/null | sed -nE 's/.*current value = *([0-9]+).*/\1/p'
}

normalize_target() {
  local value="$1"
  (( value < 0 )) && value=0
  (( value > 100 )) && value=100
  printf '%d\n' "$value"
}

read_current_bus() {
  local busnum="$1"
  ddcutil getvcp 0x10 --bus "$busnum" 2>/dev/null | sed -nE 's/.*current value = *([0-9]+).*/\1/p'
}

set_brightness() {
  local val="$1"
  # Erster Versuch schnell und ohne verify
  if ddcutil setvcp 0x10 "$val" --noverify $BUS_OPT 2>/dev/null; then
    return 0
  fi
  # Zweiter Versuch mit kleinem Delay
  ddcutil setvcp 0x10 "$val" --noverify --sleep-multiplier=2 $BUS_OPT 2>/dev/null
}

set_brightness_bus() {
  local val="$1"; local busnum="$2"
  if ddcutil setvcp 0x10 "$val" --noverify --bus "$busnum" 2>/dev/null; then
    return 0
  fi
  ddcutil setvcp 0x10 "$val" --noverify --sleep-multiplier=2 --bus "$busnum" 2>/dev/null
}

list_buses() {
  ddcutil detect 2>/dev/null | sed -nE 's/.*i2c-([0-9]+).*/\1/p'
}

# Lock + Rate Limit
exec 200>"$LOCK_FILE"
flock 200

now_ns="$(date +%s%N)"
if [[ -f "$STATE_FILE" ]]; then
  last_ns="$(<"$STATE_FILE")"
  if [[ "$last_ns" =~ ^[0-9]+$ ]]; then
    delta_ns=$(( now_ns - last_ns ))
    if (( delta_ns < RATE_LIMIT_NS )); then
      remaining_ns=$(( RATE_LIMIT_NS - delta_ns ))
      sleep "$(awk -v ns="$remaining_ns" 'BEGIN { printf "%.3f", ns/1000000000 }')"
    fi
  fi
fi

# Zielwert/Modus berechnen
DELTA_MODE=0
DELTA=0
ABS_VAL=0
if [[ "$arg" =~ ^[+-]?[0-9]+$ ]]; then
  if [[ "$arg" == +* || "$arg" == -* ]]; then
    DELTA_MODE=1
    DELTA="$arg"
  else
    ABS_VAL="$(normalize_target "$arg")"
  fi
else
  echo "Error: invalid argument '$arg' (use +N, -N, or absolute 0-100)" >&2
  exit 4
fi

if [[ "$ALL" -eq 1 ]]; then
  # Auf alle erkannten Displays anwenden
  mapfile -t buses < <(list_buses)
  if [[ ${#buses[@]} -eq 0 ]]; then
    echo "Error: no DDC-capable displays detected" >&2
    exit 6
  fi
  for b in "${buses[@]}"; do
    if [[ "$DELTA_MODE" -eq 1 ]]; then
      curb="$(read_current_bus "$b")"
      if ! [[ "$curb" =~ ^[0-9]+$ ]]; then
        echo "Warn: skip bus $b (cannot read current)" >&2
        continue
      fi
      tgt="$(normalize_target "$(( curb + DELTA ))")"
    else
      tgt="$ABS_VAL"
    fi
    set_brightness_bus "$tgt" "$b" || echo "Warn: failed to set bus $b to $tgt" >&2
  done
  printf '%s' "$now_ns" > "$STATE_FILE"
  # kein globaler LASTVAL_FILE update im ALL-Modus
else
  # Einzel-Display (Primary oder --bus)
  if [[ "$DELTA_MODE" -eq 1 ]]; then
    cur="$(read_current)"
    if ! [[ "$cur" =~ ^[0-9]+$ ]]; then
      echo "Error: failed to read current brightness (ddcutil/getvcp 0x10)" >&2
      exit 3
    fi
    target="$(normalize_target "$(( cur + DELTA ))")"
  else
    target="$ABS_VAL"
  fi

  if ! set_brightness "$target"; then
    echo "Error: failed to set brightness to $target. Check i2c group and ddcutil access." >&2
    exit 5
  fi
  printf '%s' "$now_ns" > "$STATE_FILE"
  printf '%s\n' "$target" > "$LASTVAL_FILE"
fi