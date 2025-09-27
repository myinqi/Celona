#!/usr/bin/env bash
#ddcutil getvcp 10
set -euo pipefail

LOCK_FILE="/tmp/monitor-brightness.lock"
STATE_FILE="/tmp/monitor-brightness.last"
RATE_LIMIT_NS=500000000  # 0.5 Sekunden in Nanosekunden

if [[ $# -ne 1 ]]; then
    echo "Usage: monitor-brightness [+/-STEP|VALUE]" >&2
    exit 1
fi

arg="$1"

read_current() {
    ddcutil getvcp 10 | sed -nE 's/.*current value = *([0-9]+).*/\1/p'
}

normalize_target() {
    local value="$1"
    (( value < 0 )) && value=0
    (( value > 100 )) && value=100
    printf '%d' "$value"
}

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

if [[ "$arg" =~ ^[+-]?[0-9]+$ ]]; then
    if [[ "$arg" == +* || "$arg" == -* ]]; then
        current="$(read_current)"
        if [[ -z "$current" ]]; then
            echo "Could not read current brightness" >&2
            exit 1
        fi
        target=$(( current + arg ))
    else
        target="$arg"
    fi
else
    echo "Invalid value: $arg" >&2
    exit 1
fi

target="$(normalize_target "$target")"
ddcutil setvcp 10 "$target"

date +%s%N >"$STATE_FILE"

