#!/usr/bin/env bash
# Text-based Tailscale "systray" menu rendered via bemenu.
set -uo pipefail

menu() {
  bemenu -l 15 -p "$1" --fn 'Terminus 12' -c --width-factor 0.3 \
    --nb '#000000ff' --hb '#000000ff' --fb '#000000ff' --ab '#000000ff' \
    --hf '#dbbc7fff' -H 24 -B 1 --bdr '#a7c080ff'
}

notify() { notify-send -t 3000 "Tailscale" "$1" 2>/dev/null || true; }

status_json="$(tailscale status --json 2>/dev/null)" || {
  notify "tailscale status failed"; exit 1
}

state="$(jq -r '.BackendState' <<<"$status_json")"
self_ip="$(jq -r '.Self.TailscaleIPs[0] // "—"' <<<"$status_json")"
self_name="$(jq -r '.Self.HostName' <<<"$status_json")"
exit_node="$(jq -r '[.Peer[]? | select(.ExitNode==true) | .HostName] | first // "none"' <<<"$status_json")"

exit_menu() {
  local sel ip
  sel="$( { echo "None (disable)"; \
    jq -r '.Peer[]? | select(.ExitNodeOption==true) | .HostName' <<<"$status_json" | sort; \
  } | menu "Exit node" )" || return 0
  [ -z "$sel" ] && return 0
  if [ "$sel" = "None (disable)" ]; then
    tailscale set --exit-node= && notify "Exit node disabled"
    return 0
  fi
  ip="$(jq -r --arg h "$sel" '.Peer[]? | select(.HostName==$h) | .TailscaleIPs[0]' <<<"$status_json" | head -1)"
  [ -n "$ip" ] && tailscale set --exit-node="$ip" && notify "Exit node: $sel"
}

devices_menu() {
  local sel ip
  sel="$(jq -r '[.Peer[]? | select((.TailscaleIPs|length)>0)
      | select(((.DNSName // "") | test("mullvad")) or ((.HostName // "") | test("(^|[-.])wg[-0-9]")) | not)]
    | sort_by([(if .Online then 0 else 1 end), (.HostName | ascii_downcase)])
    | .[] | "\(if .Online then "●" else "○" end) \(.HostName) — \(.TailscaleIPs[0])"' \
    <<<"$status_json" | menu "Devices (copy IP)")" || return 0
  [ -z "$sel" ] && return 0
  ip="$(grep -oE '100\.[0-9]+\.[0-9]+\.[0-9]+|fd7a:[0-9a-f:]+' <<<"$sel" | head -1 || true)"
  [ -n "$ip" ] && printf '%s' "$ip" | wl-copy && notify "Copied $ip"
}

if [ "$state" = "Running" ]; then
  conn_label="● Connected ($self_ip)"
  toggle="Disconnect"
else
  conn_label="○ $state"
  toggle="Connect"
fi

choice="$(printf '%s\n' \
  "$conn_label" \
  "$toggle" \
  "Exit node: $exit_node" \
  "Devices…" \
  "Copy my IP" \
  "Admin console" | menu "$self_name")" || exit 0

case "$choice" in
  "Connect")       tailscale up && notify "Connected" ;;
  "Disconnect")    tailscale down && notify "Disconnected" ;;
  "Exit node:"*)   exit_menu ;;
  "Devices…")      devices_menu ;;
  "Copy my IP")    printf '%s' "$self_ip" | wl-copy && notify "Copied $self_ip" ;;
  "Admin console") xdg-open "https://login.tailscale.com/admin/machines" ;;
esac
