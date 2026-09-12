#!/bin/bash
# Builds Oboor.app and installs it to the Desktop.
set -e

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$HOME/Desktop/Oboor.app"

cd "$SRC_DIR"
swiftc -O main.swift -o Oboor

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Oboor "$APP/Contents/MacOS/Oboor"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp CoreIcon.png "$APP/Contents/Resources/CoreIcon.png"

# Signed with a stable local identity (not ad-hoc) so Screen Recording,
# Contacts, and Calendar permission grants survive rebuilds instead of
# resetting every time.
codesign --force --sign "Omar Local Code Signing" --timestamp=none "$APP"

echo "built $APP"
