#!/usr/bin/env bash
# Text-based TLP power-profile picker rendered via bemenu.
set -uo pipefail

menu() {
  bemenu -l 5 -p "$1" --fn 'Terminus 12' -c --width-factor 0.3 \
    --nb '#000000ff' --hb '#000000ff' --fb '#000000ff' --ab '#000000ff' --tb '#000000ff' --tf '#a7c080ff' --ff '#c8c4b0ff' \
    --hf '#dbbc7fff' -H 20 -B 1 --bdr '#a7c080ff'
}

notify() { notify-send -t 3000 "TLP" "$1" 2>/dev/null || true; }

# Active mode from TLP's state file (field 1: 0=perf, 1=balanced, 2=power-saver).
# More reliable than /sys/.../platform_profile, whose power-saver mapping
# (low-power) is unsupported on some hardware and silently no-ops.
case "$(awk '{print $1}' /run/tlp/last_pwr 2>/dev/null)" in
  0) cur="performance" ;;
  1) cur="balanced" ;;
  2) cur="power-saver" ;;
  *) cur="" ;;
esac

mark() { [ "$1" = "$cur" ] && printf '●' || printf '○'; }

choice="$(printf '%s\n' \
  "$(mark performance) Performance" \
  "$(mark balanced) Balanced" \
  "$(mark power-saver) Power-saver" | menu "power profile")" || exit 0
[ -z "$choice" ] && exit 0

profile="$(awk '{print tolower($2)}' <<<"$choice")"
[ -z "$profile" ] && exit 0

if sudo tlp "$profile" >/dev/null 2>&1; then
  notify "Profile: $profile"
else
  notify "Failed to set $profile"
fi
