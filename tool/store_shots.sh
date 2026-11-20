#!/usr/bin/env bash
# Captures store screenshots straight into a storeshots project.
#
#   tool/store_shots.sh ios      [project-dir]   # iPhone 17 Pro Max (1320x2868)
#   tool/store_shots.sh android  [project-dir]   # a Pixel emulator
#
# Picks (and if needed creates, boots or launches) the right simulator or
# emulator, then runs tool/capture_screens.sh with STORESHOTS=<project-dir>.
# Shots land in <project-dir>/captures/$LOCALE/ (LOCALE defaults to "en").
#
# Overrides: IOS_DEVICE_TYPE="iPhone 17 Pro Max", DEVICE=<udid|adb-serial>,
# AVD=<emulator name>, LOCALE=<code>.
set -euo pipefail

PLATFORM="${1:?usage: store_shots.sh <ios|android> [project-dir]}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ios_udid() {
  local type="${IOS_DEVICE_TYPE:-iPhone 17 Pro Max}"
  local udid
  udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devices = [d for rt, ds in json.load(sys.stdin)["devices"].items() if "iOS" in rt for d in ds]
devices = [d for d in devices if d["name"] == name]
devices.sort(key=lambda d: d["state"] != "Booted")
print(devices[0]["udid"] if devices else "")
' "$type")
  if [ -z "$udid" ]; then
    # No simulator of this type yet: make one on the newest iOS runtime.
    local type_id runtime
    type_id=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
print(next((t["identifier"] for t in json.load(sys.stdin)["devicetypes"] if t["name"] == sys.argv[1]), ""))
' "$type")
    # The newest iOS runtime that supports this device type.
    runtime=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rts = [
    r for r in json.load(sys.stdin)["runtimes"]
    if r["platform"] == "iOS" and r["isAvailable"]
    and any(t["identifier"] == sys.argv[1] for t in r.get("supportedDeviceTypes", []))
]
rts.sort(key=lambda r: [int(p) for p in r["version"].split(".")])
print(rts[-1]["identifier"] if rts else "")
' "$type_id")
    if [ -z "$type_id" ] || [ -z "$runtime" ]; then
      echo "No iOS runtime installed that supports \"$type\" (Xcode > Settings > Components)." >&2
      exit 1
    fi
    if ! udid=$(xcrun simctl create "$type" "$type_id" "$runtime"); then
      echo "Couldn't create a \"$type\" simulator on $runtime." >&2
      exit 1
    fi
    echo "Created simulator \"$type\" ($udid, ${runtime##*.})" >&2
  fi
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  echo "$udid"
}

android_serial() {
  local serial
  serial=$(adb devices | awk '/^emulator-[0-9]+\tdevice$/ {print $1; exit}')
  if [ -n "$serial" ]; then
    echo "$serial"
    return
  fi
  local emulator="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}/emulator/emulator"
  command -v emulator >/dev/null && emulator=emulator
  local avd="${AVD:-$("$emulator" -list-avds | grep -i pixel | head -1)}"
  if [ -z "$avd" ]; then
    echo "No running emulator and no Pixel AVD found. Create one in Android Studio, or pass AVD=<name>." >&2
    exit 1
  fi
  echo "Starting emulator $avd" >&2
  "$emulator" -avd "$avd" -no-snapshot-save >/dev/null 2>&1 &
  adb wait-for-device
  until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
  adb devices | awk '/^emulator-[0-9]+\tdevice$/ {print $1; exit}'
}

case "$PLATFORM" in
  ios)
    PROJECT="${2:-store-assets/ios}"
    DEVICE="${DEVICE:-}"
    if [ -z "$DEVICE" ]; then DEVICE=$(ios_udid) || exit 1; fi
    ;;
  android)
    PROJECT="${2:-store-assets/android}"
    DEVICE="${DEVICE:-}"
    if [ -z "$DEVICE" ]; then DEVICE=$(android_serial) || exit 1; fi
    ;;
  *)
    echo "usage: store_shots.sh <ios|android> [project-dir]" >&2
    exit 2
    ;;
esac

STORESHOTS="$PROJECT" LOCALE="${LOCALE:-en}" \
  bash "$SCRIPT_DIR/capture_screens.sh" "$DEVICE" screenshots
