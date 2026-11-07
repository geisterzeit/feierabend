#!/bin/bash

set -euo pipefail

APP="${1:?usage: verify-app.sh <app> <bundle-id> <executable>}"
EXPECTED_BUNDLE_ID="${2:?missing bundle identifier}"
EXECUTABLE_NAME="${3:?missing executable name}"
PLIST="$APP/Contents/Info.plist"

[[ -d "$APP" ]] || { echo "error: missing app bundle: $APP" >&2; exit 1; }
plutil -lint "$PLIST" >/dev/null

actual_bundle_id="$(plutil -extract CFBundleIdentifier raw -o - "$PLIST")"
[[ "$actual_bundle_id" == "$EXPECTED_BUNDLE_ID" ]] || {
  echo "error: bundle identifier is $actual_bundle_id, expected $EXPECTED_BUNDLE_ID" >&2
  exit 1
}

[[ -x "$APP/Contents/MacOS/$EXECUTABLE_NAME" ]] || {
  echo "error: bundle executable is missing or not executable" >&2
  exit 1
}
[[ -f "$APP/Contents/Resources/Assets.car" ]] || {
  echo "error: compiled icon catalog is missing" >&2
  exit 1
}

codesign --verify --deep --strict --verbose=2 "$APP"
echo "Verified $APP"
