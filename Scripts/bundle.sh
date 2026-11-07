#!/bin/bash

set -euo pipefail

CONFIG="${1:?usage: bundle.sh <debug|release> <app-name> <executable> <bundle-id> <deployment-target>}"
APP_NAME="${2:?missing app name}"
EXECUTABLE_NAME="${3:?missing executable name}"
BUNDLE_ID="${4:?missing bundle identifier}"
DEPLOYMENT_TARGET="${5:?missing deployment target}"

if [[ "$CONFIG" != "debug" && "$CONFIG" != "release" ]]; then
  echo "error: configuration must be debug or release" >&2
  exit 64
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$ROOT/Sources/$EXECUTABLE_NAME"
APP="$ROOT/build/$APP_NAME.app"

echo "==> Building ($CONFIG)"
swift build --package-path "$ROOT" -c "$CONFIG"

BIN_DIR="$(swift build --package-path "$ROOT" -c "$CONFIG" --show-bin-path)"
BINARY="$BIN_DIR/$EXECUTABLE_NAME"
if [[ ! -x "$BINARY" ]]; then
  echo "error: built executable not found at $BINARY" >&2
  exit 1
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/$EXECUTABLE_NAME"
cp "$SOURCE_ROOT/Info.plist" "$APP/Contents/Info.plist"

for bundle in "$BIN_DIR"/*.bundle; do
  [[ -e "$bundle" ]] || continue
  bundle_name="$(basename "$bundle")"
  if strings "$BINARY" | grep -F "$bundle_name" >/dev/null; then
    # SwiftPM's generated Bundle.module accessor resolves beside Bundle.main.bundleURL,
    # which is the .app directory for an executable bundle.
    ditto "$bundle" "$APP/$bundle_name"
  fi
done

ICON_SOURCE="$ROOT/Resources/AppIcon.icon"
if [[ ! -d "$ICON_SOURCE" ]]; then
  echo "error: icon source not found at $ICON_SOURCE; run 'make icon'" >&2
  exit 1
fi

echo "==> Compiling Liquid Glass icon"
ICON_LOG="$(xcrun actool "$ICON_SOURCE" \
  --compile "$APP/Contents/Resources" \
  --app-icon AppIcon \
  --platform macosx \
  --minimum-deployment-target "$DEPLOYMENT_TARGET" \
  --output-partial-info-plist "$APP/Contents/Resources/.icon-partial.plist" 2>&1)"

if grep -q "com.apple.actool.errors" <<<"$ICON_LOG"; then
  echo "error: actool failed to compile $ICON_SOURCE" >&2
  echo "$ICON_LOG" >&2
  exit 1
fi
rm -f "$APP/Contents/Resources/.icon-partial.plist"

if [[ ! -f "$APP/Contents/Resources/Assets.car" ]]; then
  echo "error: actool produced no Assets.car" >&2
  exit 1
fi

echo "==> Signing for local development"
codesign --force --sign - \
  --identifier "$BUNDLE_ID" \
  --entitlements "$SOURCE_ROOT/App.entitlements" \
  --timestamp=none \
  "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
echo "Built $APP"
