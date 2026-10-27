#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/AI Usage Bar.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
clang -arch arm64 -arch x86_64 -fobjc-arc -O2 QuotaPet.m -o "$APP/Contents/MacOS/QuotaPet" -framework AppKit
cp codex_usage.py claude_usage.py "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>QuotaPet</string>
<key>CFBundleIdentifier</key><string>local.aiusagebar.menu</string>
<key>CFBundleName</key><string>AI 사용량</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
printf '완료: %s\n' "$APP"
