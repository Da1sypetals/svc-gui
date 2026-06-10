#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release

APP=".build/arm64-apple-macosx/release/svc-gui-swift.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/arm64-apple-macosx/release/svc-gui-swift" "$APP/Contents/MacOS/svc-gui-swift"
cp Info.plist "$APP/Contents/"
cp ~/.svc-gui/libyingmusic.dylib "$APP/Contents/MacOS/" 2>/dev/null || true
cp ~/.svc-gui/librvc.dylib "$APP/Contents/MacOS/" 2>/dev/null || true
echo "Running..."
exec "$APP/Contents/MacOS/svc-gui-swift"
