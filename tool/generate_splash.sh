#!/usr/bin/env bash
# Regenerates the native launch screens (iOS and Android) from
# flutter_native_splash.yaml and the logos in branding/.
#
#     tool/generate_splash.sh
#
# flutter_native_splash is added only for the run: its Android plugin doesn't
# build against this project (it compiles against API 31), and newer releases
# conflict with the excel package. The app never needs it at runtime.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 tool/generate_splash.py
flutter pub add dev:flutter_native_splash:2.4.4 >/dev/null
trap 'flutter pub remove flutter_native_splash >/dev/null' EXIT
# It rewrites Info.plist only to re-indent it and add a default key.
cp ios/Runner/Info.plist /tmp/three_bucks_Info.plist
dart run flutter_native_splash:create
cp /tmp/three_bucks_Info.plist ios/Runner/Info.plist
