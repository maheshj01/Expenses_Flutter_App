# NOTE: THESE commands are good during development and QA releases.
#
# IV3Mobile Automation Tooling
# ----------------------------
# This Makefile uses a Dart-based CLI tool for complex automation tasks.
# The tooling is located in the `tooling/` directory and provides:
#   - Version management (update, increment)
#   - Release automation (build, commit, MR creation)
#   - GitLab integration (merge request creation)
#
# For more information, see: tooling/README.md
#
current_dir := $(shell 'pwd')
# Set the path to your Flutter SDK
FLUTTER := $(shell which flutter)
DART := $(shell which dart)

# Secrets live in env.json (gitignored). Copy env.example.json -> env.json and
# fill in real values. Keeping them in a file (not inline here) is what lets
# this Makefile be committed to an open-source repo. Override the file with
# `make run ENV_FILE=env.staging.json`.
ENV_FILE ?= env.json

FLUTTER_VERSION := 3.44.4

# Fast host widget tests (no device/emulator) — this is the CI gate.
# Runs on Flutter's headless engine in seconds.
widget-test:
	$(FLUTTER) test test/

# Integration-test screenshots — two commands, nothing else to remember:
#   make capture-screens      DEVICE=<serial>   # screens WITH a device frame
#   make capture-screens-raw  DEVICE=<serial>   # bare screens, no frame
#
# Both run the new-user onboarding -> add-event flow on the given device and save
# one PNG per screen (plus a meta/<name>.json sidecar). Raw shots go to
# screenshots/raw/<device>/ and framed shots to screenshots/framed/<device>/, so
# a run on one device never erases another's. DEVICE is an adb serial / emulator,
# or an iOS simulator UDID. Local/manual only; not run in CI.
capture-screens:
	@if [ -z "$(DEVICE)" ]; then echo "No device found. Pass DEVICE=<serial>."; exit 1; fi
	bash tool/capture_screens.sh $(DEVICE) screenshots

capture-screens-raw:
	@if [ -z "$(DEVICE)" ]; then echo "No device found. Pass DEVICE=<serial>."; exit 1; fi
	FRAME=0 bash tool/capture_screens.sh $(DEVICE) screenshots

# Store screenshots, straight into the storeshots projects (raw shots plus a
# <name>.json description each, in <project>/captures/<LOCALE>/). Also writes
# the usual screenshots/raw and screenshots/framed output.
#   make store-shots-ios                  # iPhone 17 Pro Max -> store-assets/ios/
#   make store-shots-android              # Pixel emulator   -> store-assets/android/
#   make store-shots-ios LOCALE=de
LOCALE ?= en

store-shots-ios:
	LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LOCALE=$(LOCALE) bash tool/store_shots.sh ios store-assets/ios

store-shots-android:
	LOCALE=$(LOCALE) bash tool/store_shots.sh android store-assets/android

# Build a release for a physical iPhone and install it over the paired
# connection. On a free Personal Team, blank the Sign in with Apple
# entitlement first (see ios/Flutter/Debug.xcconfig):
#   echo 'CODE_SIGN_ENTITLEMENTS =' > ios/Flutter/Local.xcconfig
#   make ios-device                          # first paired iPhone
#   make ios-device IOS_DEVICE=<devicectl id>
ios-device:
	LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 $(FLUTTER) build ios --release --dart-define-from-file=env.json
	xcrun devicectl device install app --device $(or $(IOS_DEVICE),$(shell xcrun devicectl list devices 2>/dev/null | grep 'available (paired)' | grep -Eo '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)) build/ios/iphoneos/Runner.app

# Print the emulator skins the SDK ships, usable as SKIN=<name> below.
#   make list-skins
list-skins:
	python3 tool/frame_screenshot.py --list-skins

# Re-wrap one device's raw screenshots (screenshots/raw/<DEVICE_NAME>/) in a
# phone frame without re-running the flow. Writes to screenshots/framed/<SKIN>
# when SKIN is given (so you can frame one device's shots as another), else to
# screenshots/framed/<DEVICE_NAME>.
#   make frame-screens DEVICE_NAME="pixel 7"                     # -> framed/pixel 7 (own frame)
#   make frame-screens DEVICE_NAME="pixel 7" SKIN=pixel_10_pro   # -> framed/pixel_10_pro
#   make frame-screens DEVICE_NAME="iphone 17 pro" SKIN=ios      # -> framed/ios (Simulator bezel)
frame-screens:
	@if [ -z "$(DEVICE_NAME)" ]; then echo 'Pass DEVICE_NAME="<folder under screenshots/raw>".'; exit 1; fi
	@if ! ls "screenshots/raw/$(DEVICE_NAME)"/*.png >/dev/null 2>&1; then echo 'No screenshots in "screenshots/raw/$(DEVICE_NAME)". Run: make capture-screens DEVICE=<udid|serial>'; exit 1; fi
	python3 tool/frame_screenshot.py "screenshots/raw/$(DEVICE_NAME)"/*.png --out-dir "screenshots/framed/$(if $(SKIN),$(SKIN),$(DEVICE_NAME))" $(if $(SKIN),--skin $(SKIN))

start-devtools:
	$(FLUTTER) pub global run devtools

format:
	$(DART) format --line-length 100 .

format-check:
	$(FLUTTER) format --line-length 100 --set-exit-if-changed .

lint:
	$(FLUTTER) analyze

format-lint: format lint

run:
	$(FLUTTER) run $(if $(RELEASE),--release,$(if $(PROFILE),--profile,))


run-web:
	$(FLUTTER) run -d web-server --dart-define-from-file=$(ENV_FILE) --web-port=63133

# make update_version VERSION=4.0.5+360666
update_version:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make update_version VERSION=x.y.z+build"; \
		exit 1; \
	fi
	$(DART) tooling/iv3_cli.dart version update --version=$(VERSION)

# Auto-increment build number
increment_build:
	$(DART) tooling/iv3_cli.dart version increment

upload_dsym_ios:
	ios/Pods/FirebaseCrashlytics/upload-symbols -gsp ios/Runner/GoogleService-Info.plist -p ios build/ios/archive/Runner.xcarchive/dSYMs

# Upload iOS app to App Store Connect
# Usage: make upload API_KEY=<key> API_ISSUER=<issuer>
# Or: make upload USERNAME=<apple-id> PASSWORD=<app-specific-password>
upload:
	$(DART) tooling/iv3_cli.dart upload $(if $(IPA),--ipa=$(IPA)) $(if $(API_KEY),--api-key=$(API_KEY)) $(if $(API_ISSUER),--api-issuer=$(API_ISSUER)) $(if $(USERNAME),--username=$(USERNAME)) $(if $(PASSWORD),--password=$(PASSWORD)) $(if $(VALIDATE_ONLY),--validate-only)

# make release VERSION=3.36.8+360636
# Or simply: `make release` (will auto-increment build number)
# Note: The release command now uses the Dart CLI tool which handles version updates,
# builds, and automatic commit on release branches
release:
	$(DART) tooling/iv3_cli.dart release $(if $(VERSION),--version=$(VERSION))

release_ios:
	$(FLUTTER) build ipa --dart-define-from-file=$(ENV_FILE)

release_android: clean generate
	$(FLUTTER) build appbundle --dart-define-from-file=$(ENV_FILE)

release_apk:
	$(FLUTTER) build apk --dart-define-from-file=$(ENV_FILE) $(if $(split),--split-per-abi,)

# Create a release for shorebird
shorebird_release_android:
	shorebird release android --flutter-version=$(FLUTTER_VERSION)

shorebird_release_ios:
	shorebird release ios --dart-define-from-file=$(ENV_FILE) --flutter-version=$(FLUTTER_VERSION)

shorebird_release: shorebird_release_ios shorebird_release_android

# Caution when using the patch command, it will patch the current release with the new changes. Ensure you have the flags set correctly.
shorebird_patch_android:
	shorebird patch android --dart-define-from-file=$(ENV_FILE)

shorebird_patch_ios:
	shorebird patch ios --dart-define-from-file=$(ENV_FILE)

generate:
	# generate the hive adapters
	dart run build_runner build --delete-conflicting-outputs
	make format

clean: clean_ios clean_android format

clean_ios:
	$(FLUTTER) clean && rm -rf ios/Podfile.lock && rm -rf Pods && rm -rf ios/Runner.xcarchive && $(FLUTTER) pub get && cd ios && pod install && cd ..

clean_android:
	rm -rf android/unityLibrary/build && rm -rf android/app/build && $(FLUTTER) pub get && cd android && ./gradlew clean && cd ..

generate_env:
	dart run build_runner build --delete-conflicting-outputs

rsa_keys:
	ssh-keygen -t rsa -b 4096 -m PEM -f jwtRS256.key -N ''
	openssl rsa -in jwtRS256.key -pubout -outform PEM -out jwtRS256.key.pub

	mkdir -p deploy/local/signing_keys
	mv jwtRS256.* deploy/local/signing_keys

localenv: rsa_keys

.PHONY: store-shots-ios store-shots-android start-emu start-devtools generate emulator rsa_keys localenv update_version increment_build upload_dsym_ios mr MR upload release