#!/usr/bin/env bash
# Flash a procedurally-generated manga "impact frame" (radial speed lines +
# "LOW BATTERY") fullscreen for a beat. Invoked by the battery watcher defined
# in parts/home/impact-frame.nix when the battery is low and discharging.
set -euo pipefail

# Match the focused Sway output so the radial lines reach the screen corners;
# fall back to 1080p if Sway can't be queried.
DIMS=$(swaymsg -t get_outputs 2>/dev/null \
  | jq -r 'first(.[] | select(.active)) | "\(.current_mode.width) \(.current_mode.height)"' 2>/dev/null || true)
SW=${DIMS% *}; SH=${DIMS#* }
[[ "$SW" =~ ^[0-9]+$ ]] || SW=1920
[[ "$SH" =~ ^[0-9]+$ ]] || SH=1080

OUT=$(mktemp --suffix=.png)
trap 'rm -f "$OUT"' EXIT

# Random-width black stripes along the angular axis of a strip; wrapping that
# strip through a Polar distortion turns each stripe into a radial speed line
# converging on the center. D is the diagonal so the lines fill the corners.
D=$(awk -v w="$SW" -v h="$SH" 'BEGIN{printf "%d", int(sqrt(w*w+h*h))+1}')
A=2400            # angular resolution
R=$((D / 2))      # radial resolution
draw="fill black"
n=$(( RANDOM % 60 + 140 ))   # 140..199 lines, so every flash looks different
for ((i = 0; i < n; i++)); do
  x=$(( RANDOM % A )); w=$(( RANDOM % 7 + 2 ))
  draw="$draw rectangle ${x},0 $((x + w)),${R}"
done

BOLD=$(magick -list font | awk -F': ' '/Font: .*Bold/{print $2; exit}')
magick -size "${A}x${R}" xc:white -draw "$draw" \
  -virtual-pixel white -distort Polar "${R} 0" \
  -gravity center -background white -extent "${D}x${D}" \
  -gravity center -crop "${SW}x${SH}+0+0" +repage \
  -gravity center -fill white -draw "ellipse $((SW / 2)),$((SH / 2)) $((SW / 4)),$((SH / 8)) 0,360" \
  ${BOLD:+-font "$BOLD"} -fill black -pointsize "$((SH / 9))" -annotate 0 "LOW\nBATTERY" \
  "$OUT"

# Flash it fullscreen (a Sway rule on app_id "imv" forces fullscreen/floating),
# then clear it after ~1.2s.
imv -f "$OUT" &
imv_pid=$!
sleep 1.2
kill "$imv_pid" 2>/dev/null || true
wait "$imv_pid" 2>/dev/null || true
