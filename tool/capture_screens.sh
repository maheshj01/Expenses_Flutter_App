#!/usr/bin/env bash
# Runs the onboarding + add-event integration test and saves a screenshot of each screen.
#
# The test drives the flow with `flutter test` (reliable over wireless) and
# prints a `__EPOCH_SHOT__ <name>` marker to stdout when it wants a screenshot
# of the current screen, then holds that screen for ~3s. This script runs the
# test, watches its stdout for the markers, and grabs the real device
# framebuffer with `adb screencap` (Android) or `xcrun simctl io screenshot`
# (an iOS simulator, given by UDID) — no convertFlutterSurfaceToImage(), so
# animated screens (like the splash) keep running and never freeze.
#
# Output layout, under <out-dir> (default "screenshots"):
#   <out-dir>/raw/<device-name>/          raw framebuffer shots, no device frame
#   <out-dir>/raw/<device-name>/meta/     per-shot <name>.json context for MCPs
#   <out-dir>/framed/<device-name>/       the same shots wrapped in a device frame
#
# Both folders are per device, so a run on one device never erases another's.
# The test also emits a `__EPOCH_META__ <name> <base64-json>` marker per shot;
# the JSON (on-screen text, named regions in raw pixels, theme, size) is written
# to the meta/ folder beside the raw shot it describes.
#
# The device folder is named after the device (e.g. "pixel 10 pro"): the AVD
# name for an emulator, otherwise ro.product.model, lowercased. Override with
# DEVICE_NAME="my label".
#
# screencap returns the bare framebuffer (the bezel around an emulator window
# is drawn by the emulator app, never by Android), so each raw shot is also
# passed through tool/frame_screenshot.py into the per-device folder. By
# default that uses the device's real emulator skin from the SDK: for an
# emulator, the skin its AVD is configured with; for a physical device, the
# skin matching its model name (Pixel 7 -> skins/pixel_7). When no skin is
# found it falls back to a generic drawn frame. Override with SKIN=<name|path>
# or SKIN=generic; FRAME=0 skips framing entirely (raw shots only). Framing
# also skips itself, with a warning, when Pillow is missing.
#
# iOS simulators frame with the Xcode Simulator's own device bezel (SKIN=ios).
#
# Usage: [FRAME=0] [SKIN=pixel_7] [DEVICE_NAME="pixel 7"] \
#          tool/capture_screens.sh <device-serial|simulator-udid> [out-dir]
set -uo pipefail

DEVICE="${1:?usage: capture_screens.sh <device-serial> [out-dir]}"
OUT_DIR="${2:-screenshots}"
FRAME="${FRAME:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMER="$SCRIPT_DIR/frame_screenshot.py"

# An iOS simulator is addressed by its UDID (8-4-4-4-12 hex); anything else
# is an adb serial.
IOS=0
case "$DEVICE" in
  [0-9A-Fa-f]*-*-*-*-*) IOS=1 ;;
esac

# Work out a human-friendly folder name for this device's framed shots.
if [ -z "${DEVICE_NAME:-}" ]; then
  DEVICE_NAME=""
  case "$DEVICE" in
    emulator-*)
      DEVICE_NAME=$(adb -s "$DEVICE" emu avd name 2>/dev/null | head -1 | tr -d '\r')
      ;;
  esac
  if [ "$IOS" = 1 ]; then
    # "    iPhone 17 Pro (15D1B369-...) (Booted)" -> "iPhone 17 Pro"
    DEVICE_NAME=$(xcrun simctl list devices 2>/dev/null | grep -F "($DEVICE)" | sed -E 's/^ *(.*) \([0-9A-Fa-f-]+\).*/\1/' | head -1)
  fi
  [ -z "$DEVICE_NAME" ] && [ "$IOS" = 0 ] && DEVICE_NAME=$(adb -s "$DEVICE" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
  [ -z "$DEVICE_NAME" ] && DEVICE_NAME="$DEVICE"
  # "Pixel 10 Pro" / "Pixel_9_Pro" -> lowercased, so folders are predictable.
  DEVICE_NAME=$(printf '%s' "$DEVICE_NAME" | tr '[:upper:]' '[:lower:]')
fi
FRAMED_DIR="$OUT_DIR/framed/$DEVICE_NAME"
RAW_DIR="$OUT_DIR/raw/$DEVICE_NAME"
# Context sidecars for MCP servers live beside the raw shots (their regions are
# in raw-screenshot pixels), under a meta/ subfolder of the raw device folder.
META_DIR="$RAW_DIR/meta"

mkdir -p "$RAW_DIR" "$META_DIR"
rm -f "$RAW_DIR"/*.png "$META_DIR"/*.json 2>/dev/null || true

if [ "$FRAME" = 1 ] && ! python3 -c 'import PIL' >/dev/null 2>&1; then
  echo "⚠️  Pillow not installed; saving raw screenshots only (python3 -m pip install pillow)"
  FRAME=0
fi

if [ "$FRAME" = 1 ]; then
  mkdir -p "$FRAMED_DIR"
  rm -f "$FRAMED_DIR"/*.png 2>/dev/null || true
fi

# Work out which emulator skin to frame with. FRAMER_ARGS stays empty for the
# generic frame.
FRAMER_ARGS=()
if [ "$FRAME" = 1 ]; then
  SKIN="${SKIN:-auto}"
  if [ "$SKIN" = auto ] && [ "$IOS" = 1 ]; then
    # The Xcode Simulator's own bezel for this device (see frame_screenshot.py).
    SKIN=ios
  elif [ "$SKIN" = auto ]; then
    SKIN=""
    case "$DEVICE" in
      emulator-*)
        # The AVD's config.ini names the skin the emulator window draws.
        avd_dir=$(adb -s "$DEVICE" emu avd path 2>/dev/null | head -1 | tr -d '\r')
        if [ -f "$avd_dir/config.ini" ]; then
          SKIN=$(sed -nE 's/^skin\.path=(.*)$/\1/p' "$avd_dir/config.ini" | tr -d '\r')
          [ -d "$SKIN" ] || SKIN=$(sed -nE 's/^skin\.name=(.*)$/\1/p' "$avd_dir/config.ini" | tr -d '\r')
        fi
        ;;
      *)
        # "Pixel 7" -> "pixel_7", which is how the SDK names its skins.
        model=$(adb -s "$DEVICE" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        SKIN=$(printf '%s' "$model" | tr '[:upper:] ' '[:lower:]_')
        ;;
    esac
    # Only keep it if the framer can actually find that skin.
    if [ -z "$SKIN" ] || ! PYTHONPATH="$SCRIPT_DIR" python3 -c 'import sys, frame_screenshot as f; f.resolve_skin(sys.argv[1], (0, 0))' "$SKIN" >/dev/null 2>&1; then
      echo "No emulator skin for this device${SKIN:+ ($SKIN)}; framing with the generic frame"
      SKIN=generic
    fi
  fi
  if [ "$SKIN" != generic ]; then
    FRAMER_ARGS=(--skin "$SKIN")
    echo "Framing with emulator skin: $SKIN"
  fi
fi

echo "Running onboarding flow on $DEVICE"
echo "  raw    -> $RAW_DIR/"
[ "$FRAME" = 1 ] && echo "  framed -> $FRAMED_DIR/"

# Foldables expose several displays. Without `-d`, screencap prints a
# "multiple displays" warning into the PNG stream (corrupting it) and grabs
# the first display, which is black while the device is folded. Pick the
# display that the system currently reports as active.
SCREENCAP_DISPLAY=""
display_count=0
[ "$IOS" = 0 ] && display_count=$(adb -s "$DEVICE" shell dumpsys SurfaceFlinger --display-id 2>/dev/null | grep -c '^Display ')
if [ "${display_count:-0}" -gt 1 ]; then
  active_id=$(adb -s "$DEVICE" shell dumpsys display 2>/dev/null |
    grep -o "isActive=true, displayId=[0-9]*, uniqueId='local:[0-9]*'" | head -1 |
    sed -E "s/.*local:([0-9]+)'/\1/")
  if [ -n "$active_id" ]; then
    SCREENCAP_DISPLAY="$active_id"
    echo "Device has $display_count displays; capturing active display $active_id"
  fi
fi

# Keep the device awake for the duration so the wireless debug bridge holds.
WAKER=""
if [ "$IOS" = 0 ]; then
  ( for _ in $(seq 1 60); do adb -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP >/dev/null 2>&1; sleep 5; done ) &
  WAKER=$!
fi
trap '[ -n "$WAKER" ] && kill "$WAKER" 2>/dev/null || true' EXIT

echo "Building and installing the app on $DEVICE — the first build can take a few"
echo "minutes and prints little. Progress appears below; capture starts at 📸."

# Pipe flutter's output through a filter that drops the device-log firehose
# (logcat W/I/D/V lines, Play-services spam, Java stack frames) but keeps build,
# install and test-progress lines, so a long silent build no longer looks stuck.
# E/ lines are kept so real errors still surface.
flutter test integration_test/onboarding_flow_test.dart \
  -d "$DEVICE" \
  --dart-define=CAPTURE_SHOTS=true 2>&1 |
grep --line-buffered -vE '^[WIDV]/|^[[:space:]]+at |FlagStore|GoogleApiManager|PlayCore|ProfileInstaller|libbinder|Background concurrent|Surface |com\.google\.|gms@' |
while IFS= read -r line; do
  case "$line" in
    *__EPOCH_META__*)
      # "__EPOCH_META__ <name> <base64-json>" -> screenshots/raw/<device>/meta/<name>.json
      rest="${line##*__EPOCH_META__ }"
      mname="${rest%% *}"                  # first token: the screenshot name
      payload="${rest#* }"                 # the rest: base64 (no spaces)
      [ -z "$mname" ] && continue
      if printf '%s' "$payload" | base64 --decode > "$META_DIR/$mname.json" 2>/dev/null \
         && [ -s "$META_DIR/$mname.json" ]; then
        echo "  📝 $META_DIR/$mname.json"
      else
        rm -f "$META_DIR/$mname.json" 2>/dev/null
        echo "  ⚠️  failed to write metadata for $mname"
      fi
      ;;
    *__EPOCH_SHOT__*)
      name="${line##*__EPOCH_SHOT__ }"   # text after the marker
      name="${name%%[[:space:]]*}"        # first whitespace-delimited token
      [ -z "$name" ] && continue
      # Small settle so the held frame is fully painted before we grab it.
      # Kept short so a transient screen (the splash auto-navigates after ~3s)
      # is still on screen when we grab it.
      sleep 0.5
      # shellcheck disable=SC2086  # intentionally empty when single-display
      if [ "$IOS" = 1 ]; then
        xcrun simctl io "$DEVICE" screenshot "$RAW_DIR/$name.png" >/dev/null 2>&1
      else
        adb -s "$DEVICE" exec-out screencap ${SCREENCAP_DISPLAY:+-d "$SCREENCAP_DISPLAY"} -p > "$RAW_DIR/$name.png" 2>/dev/null
      fi
      if [ -s "$RAW_DIR/$name.png" ]; then
        echo "  📸 $RAW_DIR/$name.png"
        # Framing runs in the background so the ~2s of image work doesn't
        # delay the next capture; the script waits for all of them at the end.
        if [ "$FRAME" = 1 ]; then
          # ${arr[@]+...} keeps an empty array from tripping `set -u` on bash 3.2.
          ( python3 "$FRAMER" ${FRAMER_ARGS[@]+"${FRAMER_ARGS[@]}"} "$RAW_DIR/$name.png" "$FRAMED_DIR/$name.png" >/dev/null 2>&1 \
              && echo "  🖼  $FRAMED_DIR/$name.png" \
              || echo "  ⚠️  failed to frame $name" ) &
        fi
      else
        echo "  ⚠️  failed to capture $name"
      fi
      ;;
    *)
      # Everything else — build, install and test-progress lines — is shown so a
      # long, otherwise-silent build doesn't look stuck. (Device-log noise was
      # already filtered out of the stream above.)
      [ -n "$line" ] && echo "$line"
      ;;
  esac
done
# Propagate the test's exit status (not the while-loop's), so a failing flow
# fails this script — required for it to be a valid CI gate.
status=${PIPESTATUS[0]}
# Wait for any framing jobs still running (the waker is killed by the trap).
wait 2>/dev/null

echo "Done."
echo "Raw screenshots:"
ls -1 "$RAW_DIR"/*.png 2>/dev/null || echo "(no screenshots captured)"
if [ "$FRAME" = 1 ]; then
  echo "Framed screenshots ($DEVICE_NAME):"
  ls -1 "$FRAMED_DIR"/*.png 2>/dev/null || echo "(no framed screenshots)"
fi
exit "$status"
