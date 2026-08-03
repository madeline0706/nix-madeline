#!/usr/bin/env bash
# Text-based TLP power-profile picker rendered via bemenu.
set -uo pipefail

menu() {
  bemenu -l 5 -p "$1" --fn 'Terminus 12' -c --width-factor 0.3 \
    --nb '#000000ff' --hb '#000000ff' --fb '#000000ff' --ab '#000000ff' --tb '#000000ff' --tf '#a7c080ff' --ff '#c8c4b0ff' \
    --hf '#dbbc7fff' -H 20 -B 1 --bdr '#a7c080ff'
}

notify() { notify-send -t 3000 "TLP" "$1" 2>/dev/null || true; }

# Current mode reported by the ACPI platform profile (readable without root).
current="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo '?')"
case "$current" in
  quiet|low-power|power-saver) cur="power-saver" ;;
  balanced|balanced-performance) cur="balanced" ;;
  performance) cur="performance" ;;
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
