#!/usr/bin/env bash
# List sway keybindings from the generated config in a bemenu popup.
set -uo pipefail

cfg="$HOME/.config/sway/config"

grep -E '^[[:space:]]*bindsym' "$cfg" \
  | sed -E 's/^[[:space:]]*bindsym[[:space:]]+(--[^ ]+[[:space:]]+)*//' \
  | sed -E 's/\bMod4\b/Super/g; s/\bMod1\b/Alt/g' \
  | awk '{ key=$1; $1=""; sub(/^ /,""); printf "%-24s %s\n", key, $0 }' \
  | sort \
  | bemenu -l 25 -p "keybinds" --fn 'Terminus 12' -c --width-factor 0.6 \
      --nb '#000000ff' --hb '#000000ff' --fb '#000000ff' --ab '#000000ff' \
      --hf '#ffea00ff' -B 1 --bdr '#00e600ff' >/dev/null
