#!/usr/bin/env bash
# Records the App Store preview footage on an iOS simulator.
#
# Runs integration_test/app_preview_flow_test.dart, starts `simctl io
# recordVideo` when the test prints `__EPOCH_REC__ start`, stops it on
# `__EPOCH_REC__ stop`, and logs every `__EPOCH_SCENE__` / `__EPOCH_TAP__`
# marker with its time since the recording began. The edit step reads that
# log to place captions and tap dots on the real footage.
#
# The status bar is set to Apple's clean 9:41 look for the run.
#
# Usage: tool/record_preview.sh <simulator-udid> [out-dir]
#   -> <out-dir>/preview_raw.mp4 and <out-dir>/markers.tsv
set -uo pipefail

UDID="${1:?usage: record_preview.sh <simulator-udid> [out-dir]}"
OUT="${2:-build/preview}"
mkdir -p "$OUT"
VIDEO="$OUT/preview_raw.mp4"
MARKS="$OUT/markers.tsv"
rm -f "$VIDEO" "$MARKS"

xcrun simctl status_bar "$UDID" override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 --operatorName ''
trap 'xcrun simctl status_bar "$UDID" clear >/dev/null 2>&1; [ -n "${REC:-}" ] && kill -INT "$REC" 2>/dev/null' EXIT

now() { python3 -c 'import time; print(f"{time.time():.3f}")'; }

T0=""
REC=""
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
flutter test integration_test/app_preview_flow_test.dart -d "$UDID" 2>&1 |
while IFS= read -r line; do
  case "$line" in
    *"__EPOCH_REC__ start"*)
      xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$VIDEO" >"$OUT/recorder.log" 2>&1 &
      REC=$!
      # The recording's first frame lands when simctl says so.
      for _ in $(seq 1 100); do grep -q "Recording started" "$OUT/recorder.log" 2>/dev/null && break; sleep 0.05; done
      T0=$(now)
      echo "🎬 recording -> $VIDEO"
      ;;
    *"__EPOCH_REC__ stop"*)
      printf 'stop\t%s\n' "$(python3 -c "print(f'{$(now) - $T0:.3f}')")" >> "$MARKS"
      kill -INT "$REC" 2>/dev/null
      wait "$REC" 2>/dev/null
      REC=""
      echo "⏹  stopped"
      ;;
    *__EPOCH_SCENE__*|*__EPOCH_TAP__*)
      [ -z "$T0" ] && continue
      rest=$(printf '%s' "$line" | sed -E 's/.*__EPOCH_(SCENE|TAP)__ //')
      kind=$(printf '%s' "$line" | sed -E 's/.*__EPOCH_(SCENE|TAP)__.*/\1/' | tr '[:upper:]' '[:lower:]')
      printf '%s\t%s\t%s\n' "$kind" "$(python3 -c "print(f'{$(now) - $T0:.3f}')")" "$rest" >> "$MARKS"
      echo "  · $kind $rest"
      ;;
    *)
      case "$line" in *"[INFO]"*|*"Xcode"*|*"Running"*|*"+"*|*"Error"*|*"error"*|*"FAIL"*|*"Some tests"*|*"All tests"*) echo "$line" ;; esac
      ;;
  esac
done
status=${PIPESTATUS[0]}
echo "markers: $MARKS"
exit "$status"
