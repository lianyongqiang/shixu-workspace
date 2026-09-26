#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/native-env.sh"
mkdir -p dist
"$SHIXU_SWIFTC" "${SHIXU_FLAGS[@]}" -O -parse-as-library -I .build/direct -L .build/direct -lDeskCore -framework SwiftUI -framework AppKit -framework Carbon Sources/Shixu/*.swift -o .build/direct/Shixu
APP_PATH="$SHIXU_ROOT/dist/拾序工作台.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp .build/direct/Shixu "$APP_PATH/Contents/MacOS/Shixu"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
"$SHIXU_SWIFTC" "${SHIXU_FLAGS[@]}" scripts/make-icon.swift -o .build/direct/make-icon
.build/direct/make-icon "$SHIXU_ROOT/.build/AppIcon.iconset"
iconutil -c icns "$SHIXU_ROOT/.build/AppIcon.iconset" -o "$APP_PATH/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP_PATH"
codesign --verify --strict "$APP_PATH"
plutil -lint "$APP_PATH/Contents/Info.plist"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$SHIXU_ROOT/dist/拾序工作台-1.0.0-$SHIXU_ARCH.zip"
printf '已生成：%s\n' "$APP_PATH"
