#!/bin/sh
PATH="/run/current-system/sw/bin:/run/wrappers/bin:$PATH"
R2_ENV="$HOME/.config/grimshot/env"
if [ -f "$R2_ENV" ]; then
  . "$R2_ENV"
else
  echo "Warning: R2 config not found at $R2_ENV — upload will be skipped" >&2
fi
RECORDINGS_DIR="$HOME/Recordings"
mkdir -p "$RECORDINGS_DIR"
play_sound() {
  [ -n "$SOUND" ] && [ -f "$SOUND" ] && paplay "$SOUND" &
}
uploadToR2() {
  FILE="$1"
  if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$R2_BUCKET" ]; then
    echo "R2 not configured, skipping upload" >&2
    return 1
  fi
  FILENAME=$(basename "$FILE")
  PROFILE="${AWS_PROFILE:-r2}"
  ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
  S3_KEY="recordings/${FILENAME}"
  PUBLIC_URL="${R2_PUBLIC_BASE_URL%/}/${S3_KEY}"
  if aws s3 cp "$FILE" "s3://${R2_BUCKET}/${S3_KEY}" \
    --endpoint-url "$ENDPOINT" \
    --profile "$PROFILE" \
    --content-type "video/mp4" \
    --no-progress > /dev/null 2>&1; then
    echo "$PUBLIC_URL"
    return 0
  else
    echo "R2 upload failed" >&2
    return 1
  fi
}
if pgrep -f wf-recorder > /dev/null; then
  PID=$(pgrep -f wf-recorder | head -1)
  kill -SIGINT "$PID"
  while kill -0 "$PID" 2>/dev/null; do
    sleep 0.2
  done
  play_sound
  FILE=$(find "$RECORDINGS_DIR" -maxdepth 1 -name '*.mp4' -printf '%T@ %p\n' \
    | sort -rn | head -1 | cut -d' ' -f2-)
  if [ -n "$FILE" ]; then
    PUBLIC_URL=$(uploadToR2 "$FILE")
    if [ -n "$PUBLIC_URL" ]; then
      printf '%s' "$PUBLIC_URL" | wl-copy
      notify-send -t 4000 -a recorder "Recording saved" "URL copied to clipboard"
    else
      notify-send -t 4000 -a recorder "Recording saved" "Upload failed — file kept locally"
    fi
  fi
else
  FILENAME=$(cat /proc/sys/kernel/random/uuid)
  FILE="$RECORDINGS_DIR/${FILENAME}.mp4"
  SINK="$(pactl get-default-sink).monitor"
  play_sound
  sleep 0.5
  wf-recorder \
    --audio="$SINK" \
    --framerate=120 \
    --codec=libx264 \
    --file="$FILE" \
    --geometry="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" \
    -p preset=fast \
    -p crf=18 &
  notify-send -t 3000 -a recorder "Recording started" "$(date +%H:%M:%S)"
fi
