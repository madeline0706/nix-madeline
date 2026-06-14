#!/bin/sh

R2_ENV="$HOME/.config/grimshot/env"
if [ -f "$R2_ENV" ]; then
  . "$R2_ENV"
else
  echo "Warning: R2 config not found at $R2_ENV — upload will be skipped" >&2
fi

when() {
  condition=$1
  action=$2
  if eval "$condition"; then
    eval "$action"
  fi
}

whenOtherwise() {
  condition=$1
  true_action=$2
  false_action=$3
  if eval "$condition"; then
    eval "$true_action"
  else
    eval "$false_action"
  fi
}

any() {
  for tuple in "$@"; do
    condition=$(echo "$tuple" | cut -d: -f1)
    action=$(echo "$tuple" | cut -d: -f2-)
    if eval "$condition"; then
      eval "$action"
      return 0
    fi
  done
  return 1
}

NOTIFY=no
CURSOR=
WAIT=no

getTargetDirectory() {
  test -f "${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs" &&
    . "${XDG_CONFIG_HOME:-$HOME/.config}/user-dirs.dirs"
  DIR="${XDG_SCREENSHOTS_DIR:-$HOME/Screenshots}"
  mkdir -p "$DIR"
  echo "$DIR"
}

parseArgs() {
  POSITIONAL_ARGS=""
  while [ $# -gt 0 ]; do
    case "$1" in
    -n | --notify)
      NOTIFY=yes
      shift
      ;;
    -c | --cursor)
      CURSOR=yes
      shift
      ;;
    -w | --wait)
      shift
      WAIT="$1"
      if echo "$WAIT" | grep "[^0-9]" -q; then
        echo "invalid value for wait '$WAIT'" >&2
        exit 3
      fi
      shift
      ;;
    *)
      POSITIONAL_ARGS="$POSITIONAL_ARGS $1"
      shift
      ;;
    esac
  done
  set -- $POSITIONAL_ARGS
  ACTION=${1:-usage}
  SUBJECT=${2:-screen}
  if [ -n "$GRIMSHOT_FILENAME_FORMAT" ]; then
    FILENAME=$GRIMSHOT_FILENAME_FORMAT
  else
    FILENAME=$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n' | sed 's/\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)/\1\2-\3\4-\5\6/')
  fi
  FILE=${3:-$(getTargetDirectory)/$FILENAME.png}
}

printUsageMsg() {
  echo "Usage:"
  echo "  grimshot [--notify] [--cursor] [--wait N] (copy|save|savecopy) [active|screen|output|area|window|anything] [FILE|-]"
  echo "  grimshot check"
  echo "  grimshot usage"
  echo ""
  echo "Commands:"
  echo "  copy:     Copy the screenshot data into the clipboard."
  echo "  save:     Save the screenshot to a regular file or '-' to pipe to STDOUT."
  echo "  savecopy: Save the screenshot to a regular file and upload to R2; URL is copied to clipboard."
  echo "  check:    Verify if required tools are installed and exit."
  echo "  usage:    Show this message and exit."
  echo ""
  echo "Targets:"
  echo "  active:   Currently active window."
  echo "  screen:   All visible outputs."
  echo "  output:   Currently active output."
  echo "  area:     Manually select a region."
  echo "  window:   Manually select a window."
  echo "  anything: Manually select an area, window, or output."
  exit
}

notify() {
  notify-send -t 3000 -a grimshot "$@"
}

notifyOk() {
  notify_disabled='[ "$NOTIFY" = "no" ]'
  action_involves_saving='[ "$ACTION" = "save" ] || [ "$ACTION" = "savecopy" ]'
  if eval $notify_disabled; then
    paplay "$SOUND" &
    return
  fi
  TITLE=${2:-"Screenshot"}
  MESSAGE=${1:-"OK"}
  paplay "$SOUND" &
  whenOtherwise "$action_involves_saving" \
    'notify "$TITLE" "$MESSAGE" -i "$FILE"' \
    'notify "$TITLE" "$MESSAGE"'
}

notifyError() {
  notify_enabled='[ "$NOTIFY" = "yes" ]'
  TITLE=${2:-"Screenshot"}
  errorMssg=$1
  MESSAGE=${errorMssg:-"Error taking screenshot with grim"}
  whenOtherwise "$notify_enabled" \
    'notify "$TITLE" "$MESSAGE" -u critical' \
    'echo "$errorMssg"'
}

die() {
  MSG=${1:-Bye}
  notifyError "Error: $MSG"
  exit 2
}

check() {
  COMMAND=$1
  command_exists='command -v "$COMMAND" > /dev/null 2>&1'
  whenOtherwise "$command_exists" \
    'RESULT="OK"' \
    'RESULT="NOT FOUND"'
  echo "   $COMMAND: $RESULT"
}

takeScreenshot() {
  FILE=$1
  GEOM=$2
  OUTPUT=$3
  output_provided='[ -n "$OUTPUT" ]'
  geom_not_provided='[ -z "$GEOM" ]'
  output_action='grim ${CURSOR:+-c} -o "$OUTPUT" "$FILE" || die "Unable to invoke grim"'
  full_screenshot_action='grim ${CURSOR:+-c} "$FILE" || die "Unable to invoke grim"'
  geometry_screenshot_action='grim ${CURSOR:+-c} -g "$GEOM" "$FILE" || die "Unable to invoke grim"'
  any \
    "$output_provided:$output_action" \
    "$geom_not_provided:$full_screenshot_action" \
    "true:$geometry_screenshot_action"
}

checkRequiredTools() {
  echo "Checking if required tools are installed..."
  check grim
  check slurp
  check swaymsg
  check wl-copy
  check jq
  check paplay
  check aws
  exit
}

uploadToR2() {
  FILE=$1
  if [ -z "$R2_ACCOUNT_ID" ] || [ -z "$R2_BUCKET" ]; then
    echo "R2 not configured, skipping upload" >&2
    return 1
  fi
  FILENAME=$(basename "$FILE")
  PROFILE="${AWS_PROFILE:-r2}"
  ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
  S3_KEY="screenshots/${FILENAME}"
  PUBLIC_URL="${R2_PUBLIC_BASE_URL%/}/${S3_KEY}"
  aws s3 cp "$FILE" "s3://${R2_BUCKET}/${S3_KEY}" \
    --endpoint-url "$ENDPOINT" \
    --profile "$PROFILE" \
    --content-type "image/png" \
    --no-progress > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "$PUBLIC_URL"
    return 0
  else
    echo "R2 upload failed" >&2
    return 1
  fi
}

selectArea() {
  GEOM=$(slurp -d)
  geomIsEmpty='[ -z "$GEOM" ]'
  when "$geomIsEmpty" "exit 1"
  WHAT="Area"
}

selectActiveWindow() {
  FOCUSED=$(swaymsg -t get_tree | jq -r 'recurse(.nodes[]?, .floating_nodes[]?) | select(.focused)')
  GEOM=$(echo "$FOCUSED" | jq -r '.rect | "\(.x),\(.y) \(.width)x\(.height)"')
  APP_ID=$(echo "$FOCUSED" | jq -r '.app_id')
  WHAT="$APP_ID window"
}

selectScreen() {
  GEOM=""
  WHAT="Screen"
}

selectOutput() {
  GEOM=""
  OUTPUT=$(swaymsg -t get_outputs | jq -r '.[] | select(.focused)' | jq -r '.name')
  WHAT="$OUTPUT"
}

selectWindow() {
  GEOM=$(swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' | slurp -r)
  geomIsEmpty='[ -z "$GEOM" ]'
  when "$geomIsEmpty" "exit 1"
  WHAT="Window"
}

selectAnything() {
  GEOM=$(swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"' | slurp -o)
  geomIsEmpty='[ -z "$GEOM" ]'
  when "$geomIsEmpty" "exit 1"
  WHAT="Selection"
}

handleSaveCopy() {
  PUBLIC_URL=$(uploadToR2 "$FILE")
  if [ $? -eq 0 ] && [ -n "$PUBLIC_URL" ]; then
    printf '%s' "$PUBLIC_URL" | wl-copy
    MESSAGE="$MESSAGE — URL copied to clipboard"
  else
    wl-copy --type image/png <"$FILE" || die "Clipboard error"
    MESSAGE="$MESSAGE and clipboard (upload failed)"
  fi
}

handleScreenshotSuccess() {
  TITLE="Screenshot of $SUBJECT"
  MESSAGE=$(basename "$FILE")
  isSaveCopy='[ "$ACTION" = "savecopy" ]'
  when "$isSaveCopy" "handleSaveCopy"
  notifyOk "$MESSAGE" "$TITLE"
  echo "$FILE"
}

handleScreenshotFailure() {
  notifyError "Error taking screenshot with grim"
}

handleCopy() {
  takeScreenshot - "$GEOM" "$OUTPUT" | wl-copy --type image/png || die "Clipboard error"
  notifyOk "$WHAT copied to clipboard"
}

handleSave() {
  screenshotTaken="takeScreenshot \"$FILE\" \"$GEOM\" \"$OUTPUT\""
  whenOtherwise "$screenshotTaken" \
    "handleScreenshotSuccess" \
    "handleScreenshotFailure"
}

handleUnknownSubject() {
  die "Unknown subject to take a screenshot from: $SUBJECT"
}

handleScreenshot() {
  actionIsInvalid='[ "$ACTION" != "save" ] && [ "$ACTION" != "copy" ] && [ "$ACTION" != "savecopy" ] && [ "$ACTION" != "check" ]'
  actionIsCheck='[ "$ACTION" = "check" ]'
  subjectIsArea='[ "$SUBJECT" = "area" ]'
  subjectIsActiveWindow='[ "$SUBJECT" = "active" ]'
  subjectIsScreen='[ "$SUBJECT" = "screen" ]'
  subjectIsOutput='[ "$SUBJECT" = "output" ]'
  subjectIsWindow='[ "$SUBJECT" = "window" ]'
  subjectIsAnything='[ "$SUBJECT" = "anything" ]'
  subjectIsUnknown=true
  any \
    "$actionIsInvalid:printUsageMsg" \
    "$actionIsCheck:checkRequiredTools" \
    "$subjectIsArea:selectArea" \
    "$subjectIsActiveWindow:selectActiveWindow" \
    "$subjectIsScreen:selectScreen" \
    "$subjectIsOutput:selectOutput" \
    "$subjectIsWindow:selectWindow" \
    "$subjectIsAnything:selectAnything" \
    "$subjectIsUnknown:handleUnknownSubject"
  wait='[ "$WAIT" != "no" ]'
  when "$wait" "sleep $WAIT"
  actionIsCopy='[ "$ACTION" = "copy" ]'
  whenOtherwise "$actionIsCopy" \
    "handleCopy" \
    "handleSave"
}

parseArgs "$@"
handleScreenshot
