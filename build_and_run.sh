#!/bin/bash
set -e

cd "$(dirname "$0")"

# Build the executable
swift build -c release

# Create .app bundle structure
BUNDLE=".build/arm64-apple-macosx/release/svc-gui-swift.app"
BINARY=".build/arm64-apple-macosx/release/svc-gui-swift"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

cp "$BINARY" "$BUNDLE/Contents/MacOS/svc-gui-swift"
cp Info.plist "$BUNDLE/Contents/"

# Copy dylib to bundle so it's findable at runtime
mkdir -p "$BUNDLE/Contents/MacOS"
cp ~/.svc-gui/libyingmusic_rust.dylib "$BUNDLE/Contents/MacOS/" 2>/dev/null || true

echo "App bundle created at $BUNDLE"
open "$BUNDLE"
