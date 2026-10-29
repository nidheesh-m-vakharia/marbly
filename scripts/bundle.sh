#!/usr/bin/env bash
# Builds a release binary and wraps it in build/Marbly.app.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/Marbly.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Marbly "$APP/Contents/MacOS/Marbly"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Sources/Marbly/Resources/Sounds "$APP/Contents/Resources/Sounds"
cp -R Sources/Marbly/Resources/Fonts "$APP/Contents/Resources/Fonts"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"
