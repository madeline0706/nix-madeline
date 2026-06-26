#!/usr/bin/env bash

export PATH="/run/current-system/sw/bin:/run/wrappers/bin:/usr/bin:/bin:$PATH"

R2_ENV="$HOME/.config/grimshot/env"
if [ -f "$R2_ENV" ]; then
  . "$R2_ENV"
else
  echo "Warning: R2 config not found at $R2_ENV — upload will be skipped" >&2
fi

RECORDINGS_DIR="$HOME/Recordings"
RC_LOCKFILE="/tmp/.nixshot-recorder.lock"
mkdir -p "$RECORDINGS_DIR"

# --- Shared utilities ---

die() {
  echo "Error: ${1:-fatal error}" >&2
  exit 2
}

notify_send() {
  local app="$1" title="$2" msg="$3"
  local urgency="${4:-normal}" timeout="${5:-3000}" icon="${6:-}"
  local args=(-t "$timeout" -a "$app" -u "$urgency")
  [ -n "$icon" ] && args+=(-i "$icon")
  notify-send "${args[@]}" "$title" "$msg"
}

play_sound() {
  [ -n "$SOUND" ] && [ -f "$SOUND" ] && paplay "$SOUND" &
}

make_filename() {
  local ext="$1"
  local uuid
  uuid=$(tr -d '-' < /proc/sys/kernel/random/uuid)
  echo "$(date +%m-%d-%y)-${uuid:0:4}-${uuid:4:4}${ext}"
}

upload_to_r2() {
  local file="$1" prefix="$2" content_type="$3"
  local filename s3_key public_url

  if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$R2_BUCKET" ] || [ -z "$R2_PUBLIC_BASE_URL" ]; then
    return 1
  fi

  filename=$(basename "$file")
  s3_key="${prefix}/${filename}"
  public_url="${R2_PUBLIC_BASE_URL%/}/${s3_key}"

  aws s3 cp "$file" "s3://${R2_BUCKET}/${s3_key}" \
    --endpoint-url "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
    --profile "${AWS_PROFILE:-r2}" \
    --content-type "$content_type" \
    --no-progress > /dev/null 2>&1 || return 1

  echo "$public_url"
}

# --- Screenshot mode (ss) ---

ss_get_target_dir() {
  local config="${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
  [ -f "$config" ] && . "$config"
  local dir="${XDG_SCREENSHOTS_DIR:-$HOME/Screenshots}"
  mkdir -p "$dir"
  echo "$dir"
}

ss_select_subject() {
  case "$1" in
    area)
      SS_GEOM=$(slurp -d) || exit 1
      SS_WHAT="Area"
      ;;
    active)
      local focused
      focused=$(swaymsg -t get_tree | jq -r 'recurse(.nodes[]?, .floating_nodes[]?) | select(.focused)')
      SS_GEOM=$(echo "$focused" | jq -r '.rect | "\(.x),\(.y) \(.width)x\(.height)"')
      SS_WHAT="$(echo "$focused" | jq -r '.app_id') window"
      ;;
    screen)
      SS_GEOM=""
      SS_WHAT="Screen"
      ;;
    output)
      SS_GEOM=""
      SS_OUTPUT=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name')
      SS_WHAT="$SS_OUTPUT"
      ;;
    window)
      SS_GEOM=$(swaymsg -t get_tree \
        | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' \
        | slurp -r) || exit 1
      SS_WHAT="Window"
      ;;
    anything)
      SS_GEOM=$(swaymsg -t get_tree \
        | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' \
        | slurp -o) || exit 1
      SS_WHAT="Selection"
      ;;
    *)
      die "Unknown subject: $1"
      ;;
  esac
}

ss_take() {
  local file="$1"
  local grim_args=()
  [ -n "$SS_CURSOR" ]                      && grim_args+=(-c)
  [ -n "$SS_OUTPUT" ]                      && grim_args+=(-o "$SS_OUTPUT")
  [[ -z "$SS_OUTPUT" && -n "$SS_GEOM" ]]   && grim_args+=(-g "$SS_GEOM")
  grim "${grim_args[@]}" "$file"
}

ss_check() {
  echo "Checking required tools..."
  local tools=(grim slurp swaymsg wl-copy jq paplay aws)
  for t in "${tools[@]}"; do
    command -v "$t" > /dev/null 2>&1 && echo "  $t: OK" || echo "  $t: NOT FOUND"
  done
  exit 0
}

cmd_ss() {
  local notify=no wait=no action subject file url
  local -a pos=()
  SS_CURSOR="" SS_GEOM="" SS_OUTPUT="" SS_WHAT=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -n|--notify) notify=yes; shift ;;
      -c|--cursor) SS_CURSOR=yes; shift ;;
      -w|--wait)
        shift
        [[ "$1" =~ ^[0-9]+$ ]] || die "invalid value for --wait: '$1'"
        wait="$1"; shift ;;
      *) pos+=("$1"); shift ;;
    esac
  done

  action="${pos[0]:-usage}"
  subject="${pos[1]:-screen}"

  case "$action" in
    check) ss_check ;;
    copy|save|savecopy) ;;
    *)
      echo "Usage: nixshot ss [--notify] [--cursor] [--wait N] (copy|save|savecopy) [active|screen|output|area|window|anything] [FILE|-]"
      echo "       nixshot ss check"
      exit 0
      ;;
  esac

  ss_select_subject "$subject"
  [ "$wait" != no ] && sleep "$wait"

  file="${pos[2]:-$(ss_get_target_dir)/$(make_filename .png)}"

  if [ "$action" = copy ]; then
    ss_take - | wl-copy --type image/png || die "Clipboard error"
    [ "$notify" = yes ] && notify_send grimshot "Screenshot" "$SS_WHAT copied to clipboard"
    return
  fi

  if ss_take "$file"; then
    local title="Screenshot of $subject"
    local message
    message=$(basename "$file")

    if [ "$action" = savecopy ]; then
      url=$(upload_to_r2 "$file" "screenshots" "image/png")
      if [ -n "$url" ]; then
        printf '%s' "$url" | wl-copy
        message="$message — URL copied"
      else
        wl-copy --type image/png < "$file" || die "Clipboard error"
        message="$message (upload failed, image copied)"
      fi
    fi

    [ "$notify" = yes ] && notify_send grimshot "$title" "$message" normal 3000 "$file"
    echo "$file"
  else
    local err="Error taking screenshot with grim"
    if [ "$notify" = yes ]; then
      notify_send grimshot "Screenshot" "$err" critical
    else
      echo "$err" >&2
    fi
  fi
}

# --- Recording mode (rc) ---

rc_start() {
  local file sink geometry
  file="$RECORDINGS_DIR/$(make_filename .mp4)"
  sink="$(pactl get-default-sink).monitor"
  geometry=$(swaymsg -t get_outputs \
    | jq -r '.[] | select(.focused) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')

  play_sound
  sleep 0.5

  wf-recorder \
    --audio="$sink" \
    --framerate=120 \
    --codec=libx264 \
    --file="$file" \
    --geometry="$geometry" \
    -p preset=fast \
    -p crf=18 &

  printf '%s:%s\n' "$!" "$file" > "$RC_LOCKFILE"
  notify_send recorder "Recording started" "$(date +%H:%M:%S)"
}

rc_stop() {
  local entry pid file url

  entry=$(cat "$RC_LOCKFILE" 2>/dev/null) || { notify_send recorder "Recorder" "No recording found"; exit 1; }
  pid="${entry%%:*}"
  file="${entry#*:}"

  if [ ! -d "/proc/$pid" ]; then
    rm -f "$RC_LOCKFILE"
    notify_send recorder "Recorder" "No recording found"
    exit 1
  fi

  kill -INT "$pid"
  while [ -d "/proc/$pid" ]; do sleep 0.1; done
  rm -f "$RC_LOCKFILE"

  play_sound

  url=$(upload_to_r2 "$file" "recordings" "video/mp4")
  if [ -n "$url" ]; then
    printf '%s' "$url" | wl-copy
    notify_send recorder "Recording saved" "URL copied to clipboard" normal 4000
  else
    notify_send recorder "Recording saved" "Upload failed — kept locally" normal 4000
  fi
}

cmd_rc() {
  if [ -f "$RC_LOCKFILE" ]; then
    rc_stop
  else
    rc_start
  fi
}

# --- Main ---

case "${1:-}" in
  ss) shift; cmd_ss "$@" ;;
  rc) cmd_rc ;;
  *)
    echo "Usage: nixshot <ss|rc> [args...]"
    exit 1
    ;;
esac
