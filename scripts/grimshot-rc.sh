#!/usr/bin/env bash

export PATH="/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin:$PATH"

R2_ENV="$HOME/.config/grimshot/env"
[ -f "$R2_ENV" ] && . "$R2_ENV"

RECORDINGS_DIR="$HOME/Recordings"
mkdir -p "$RECORDINGS_DIR"

play_sound() {
  [ -n "$SOUND" ] && [ -f "$SOUND" ] && paplay "$SOUND" &
}

upload_to_r2() {
  local file="$1"
  local filename endpoint s3_key public_url

  [ -z "$R2_ACCOUNT_ID" ] || [ -z "$R2_BUCKET" ] || [ -z "$R2_PUBLIC_BASE_URL" ] && return 1

  filename=$(basename "$file")
  endpoint="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
  s3_key="recordings/${filename}"
  public_url="${R2_PUBLIC_BASE_URL%/}/${s3_key}"

  aws s3 cp "$file" "s3://${R2_BUCKET}/${s3_key}" \
    --endpoint-url "$endpoint" \
    --profile "${AWS_PROFILE:-r2}" \
    --content-type "video/mp4" \
    --no-progress > /dev/null 2>&1 || return 1

  echo "$public_url"
}

stop_recording() {
  local pid
  pid=$(grep -rl wf-recorder /proc/*/cmdline 2>/dev/null | grep -v '/proc/self\|/proc/thread-self' | head -1 | cut -d/ -f3)

  [ -z "$pid" ] && { notify-send -t 3000 -a recorder "Recorder" "No recording found"; exit 1; }

  kill -INT "$pid"
  while [ -d "/proc/$pid" ]; do sleep 0.1; done
  sleep 1

  play_sound

  local file
  file=$(find "$RECORDINGS_DIR" -maxdepth 1 -name '*.mp4' -printf '%T@ %p\n' \
    | sort -rn | head -1 | cut -d' ' -f2-)

  [ -z "$file" ] && { notify-send -t 3000 -a recorder "Recorder" "No file found"; exit 1; }

  local url
  url=$(upload_to_r2 "$file")

  if [ -n "$url" ]; then
    printf '%s' "$url" | wl-copy
    notify-send -t 4000 -a recorder "Recording saved" "URL copied to clipboard"
  else
    notify-send -t 4000 -a recorder "Recording saved" "Upload failed — kept locally"
  fi
}

start_recording() {
  local file sink geometry

  file="$RECORDINGS_DIR/$(cat /proc/sys/kernel/random/uuid).mp4"
  sink="$(pactl get-default-sink).monitor"
  geometry=$(swaymsg -t get_outputs \
    | jq -r '.[] | select(.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')

  play_sound
  sleep 0.5

  setsid wf-recorder \
    --audio="$sink" \
    --framerate=120 \
    --codec=libx264 \
    --file="$file" \
    --geometry="$geometry" \
    -p preset=fast \
    -p crf=18 &

  notify-send -t 3000 -a recorder "Recording started" "$(date +%H:%M:%S)"
}

# Main
if grep -rl wf-recorder /proc/*/cmdline 2>/dev/null | grep -qv '/proc/self\|/proc/thread-self'; then
  stop_recording
else
  start_recording
fi
