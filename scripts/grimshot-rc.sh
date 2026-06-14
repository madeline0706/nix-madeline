#!/bin/sh

R2_ENV="$HOME/.config/grimshot/env"
if [ -f "$R2_ENV" ]; then
  . "$R2_ENV"
else
  echo "Warning: R2 config not found at $R2_ENV — upload will be skipped" >&2
fi

PIDFILE="/tmp/wf-recorder.pid"
RECORDINGS_DIR="$HOME/Recordings"
mkdir -p "$RECORDINGS_DIR"

uploadToR2() {
  FILE=$1
  if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$R2_BUCKET" ]; then
    echo "R2 not configured, skipping upload" >&2
    return 1
  fi
  FILENAME=$(basename "$FILE")
  PROFILE="${AWS_PROFILE:-r2}"
  ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
  S3_KEY="recordings/${FILENAME}"
  PUBLIC_URL="${R2_PUBLIC_BASE_URL%/}/${S3_KEY}"
  aws s3 cp "$FILE" "s3://${R2_BUCKET}/${S3_KEY}" \
    --endpoint-url "$ENDPOINT" \
    --profile "$PROFILE" \
    --content-type "video/mp4" \
    --no-progress > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "$PUBLIC_URL"
    return 0
  else
    echo "R2 upload failed" >&2
    return 1
  fi
}

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill -SIGINT "$PID"
    rm -f "$PIDFILE"
    wait "$PID" 2>/dev/null
    paplay "$SOUND" &
    FILE=$(ls -t "$RECORDINGS_DIR"/*.mp4 2>/dev/null | head -1)
    if [ -n "$FILE" ]; then
      PUBLIC_URL=$(uploadToR2 "$FILE")
      if [ $? -eq 0 ] && [ -n "$PUBLIC_URL" ]; then
        printf '%s' "$PUBLIC_URL" | wl-copy
        notify-send -t 4000 -a recorder "Recording saved" "URL copied to clipboard"
      else
        notify-send -t 4000 -a recorder "Recording saved" "Upload failed — file kept locally"
      fi
    fi
  else
    rm -f "$PIDFILE"
  fi
else
  FILENAME=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n' | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2-\3\4-\5\6/')
  FILE="$RECORDINGS_DIR/${FILENAME}.mp4"
  SINK="$(pactl get-default-sink).monitor"
  paplay "$SOUND"
  sleep 0.5
  wf-recorder \
    --audio="$SINK" \
    --framerate=120 \
    --codec=libx264 \
    --file="$FILE" \
    --geometry="$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" \
    -p preset=fast \
    -p crf=18 \
    &
  echo $! > "$PIDFILE"
  notify-send -t 3000 -a recorder "Recording started" "$(date +%H:%M:%S)"
fi
