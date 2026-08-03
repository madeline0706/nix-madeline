#!/bin/bash
# Waybar sysinfo. Prints one metric chosen by $1: cpu | ram | disk | net
set -euo pipefail

STATE_DIR="/tmp/waybar_stats"
mkdir -p "$STATE_DIR"

metric="${1:-cpu}"

color() {
    local pct=$1
    if   [ "$pct" -lt 60 ]; then echo "#c8c4b0"
    elif [ "$pct" -lt 80 ]; then echo "#dbbc7f"
    else                          echo "#e67e80"
    fi
}

kb_to_human() {
    local kb=$1
    if [ "$kb" -ge $(( 1024 * 1024 * 1024 )) ]; then
        printf "%d.%dTB" $(( kb / 1024 / 1024 / 1024 )) $(( (kb / 1024 / 1024 % 1024) * 10 / 1024 ))
    elif [ "$kb" -ge $(( 1024 * 1024 )) ]; then
        printf "%d.%dGB" $(( kb / 1024 / 1024 )) $(( (kb % (1024 * 1024)) * 10 / 1024 / 1024 ))
    else
        printf "%dMB" $(( kb / 1024 ))
    fi
}

case "$metric" in
  cpu)
    read -r _ cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ < <(grep '^cpu ' /proc/stat)
    cpu_total=$(( cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal ))
    cpu_idle_prev=$(cat "$STATE_DIR/cpu_idle" 2>/dev/null || echo 0)
    cpu_total_prev=$(cat "$STATE_DIR/cpu_total" 2>/dev/null || echo 0)
    echo "$cpu_idle"  > "$STATE_DIR/cpu_idle"
    echo "$cpu_total" > "$STATE_DIR/cpu_total"
    [[ "$cpu_idle_prev"  =~ ^[0-9]+$ ]] || cpu_idle_prev=0
    [[ "$cpu_total_prev" =~ ^[0-9]+$ ]] || cpu_total_prev=0
    cpu_delta=$(( cpu_total - cpu_total_prev ))
    cpu_idle_delta=$(( cpu_idle - cpu_idle_prev ))
    if [ "$cpu_delta" -gt 0 ] && [ "$cpu_idle_delta" -ge 0 ] && [ "$cpu_idle_delta" -le "$cpu_delta" ]; then
        cpu_pct=$(( (cpu_delta - cpu_idle_delta) * 100 / cpu_delta ))
    else
        cpu_pct=0
    fi
    printf "<span color='%s'>%s</span>\n" "$(color "$cpu_pct")" "${cpu_pct}%"
    ;;

  temp)
    tdir=""
    for h in /sys/class/hwmon/hwmon*; do
        [ "$(cat "$h/name" 2>/dev/null)" = "k10temp" ] && { tdir="$h"; break; }
    done
    tc=$(( $(cat "$tdir/temp1_input" 2>/dev/null || echo 0) / 1000 ))
    printf "<span color='%s'>%s</span>\n" "$(color "$tc")" "${tc}°C"
    ;;

  ram)
    read -r ram_total_kb ram_avail_kb < <(awk '/^MemTotal/{t=$2} /^MemAvailable/{a=$2} END{print t, a}' /proc/meminfo)
    ram_used_kb=$(( ram_total_kb - ram_avail_kb ))
    ram_pct=$(( ram_used_kb * 100 / ram_total_kb ))
    printf "<span color='%s'>%s</span>\n" "$(color "$ram_pct")" "$(kb_to_human "$ram_used_kb")"
    ;;

  disk)
    read -r disk_total_kb disk_used_kb disk_pct < <(df -k / | awk 'NR==2 {gsub("%","",$5); print $2, $3, $5}')
    printf "<span color='%s'>%s</span>\n" "$(color "$disk_pct")" "$(kb_to_human "$disk_used_kb")"
    ;;

  net)
    iface=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/ {for(i=1;i<=NF;i++) if($i=="dev") print $(i+1); exit}')
    rx_now=$(cat "/sys/class/net/${iface}/statistics/rx_bytes" 2>/dev/null || echo 0)
    tx_now=$(cat "/sys/class/net/${iface}/statistics/tx_bytes" 2>/dev/null || echo 0)
    ts_now=$(date +%s%3N)
    rx_prev=$(cat "$STATE_DIR/rx" 2>/dev/null || echo "$rx_now")
    tx_prev=$(cat "$STATE_DIR/tx" 2>/dev/null || echo "$tx_now")
    ts_prev=$(cat "$STATE_DIR/ts" 2>/dev/null || echo "$ts_now")
    [[ "$rx_prev" =~ ^[0-9]+$ ]] || rx_prev=$rx_now
    [[ "$tx_prev" =~ ^[0-9]+$ ]] || tx_prev=$tx_now
    [[ "$ts_prev" =~ ^[0-9]+$ ]] || ts_prev=$ts_now
    echo "$rx_now" > "$STATE_DIR/rx"
    echo "$tx_now" > "$STATE_DIR/tx"
    echo "$ts_now" > "$STATE_DIR/ts"
    elapsed_ms=$(( ts_now - ts_prev ))
    rx_diff=$(( rx_now - rx_prev ))
    tx_diff=$(( tx_now - tx_prev ))
    if [ "$elapsed_ms" -gt 100 ] && [ "$rx_diff" -ge 0 ] && [ "$tx_diff" -ge 0 ]; then
        rx_mbps="$(( rx_diff * 8 / 1000000 * 1000 / elapsed_ms )).0"
        tx_mbps="$(( tx_diff * 8 / 1000000 * 1000 / elapsed_ms )).0"
        total_mbps=$(( (rx_diff + tx_diff) * 8 / 1000000 * 1000 / elapsed_ms ))
    else
        rx_mbps="0.0"; tx_mbps="0.0"; total_mbps=0
    fi
    if   [ "$total_mbps" -lt 50  ]; then net_color="#c8c4b0"
    elif [ "$total_mbps" -lt 200 ]; then net_color="#dbbc7f"
    else                                  net_color="#e67e80"
    fi
    printf "<span color='%s'>↑ %-7s ↓ %-7s</span>\n" "$net_color" "$tx_mbps" "$rx_mbps"
    ;;
esac
