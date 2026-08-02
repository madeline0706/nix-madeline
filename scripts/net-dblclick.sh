#!/usr/bin/env bash
# Waybar has no double-click event; emulate it. Two clicks within 400ms on the
# bandwidth module launch a speedtest in a floating terminal.
set -euo pipefail

f="/tmp/waybar_stats/net_lastclick"
mkdir -p "$(dirname "$f")"
now=$(date +%s%3N)
last=$(cat "$f" 2>/dev/null || echo 0)
[[ "$last" =~ ^[0-9]+$ ]] || last=0
echo "$now" > "$f"

if [ $(( now - last )) -lt 400 ]; then
  exec foot --app-id=floatterm -e sh -c 'speedtest-rs; echo; read -n1 -rs -p "Press any key to close…"'
fi
