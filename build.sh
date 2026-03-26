#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="Daily365"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "🏗️  Building $APP_NAME..."

# Clean previous build
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compile Swift sources
SWIFT_FILES=(
    "$PROJECT_DIR/Sources/Daily365/Daily365App.swift"
    "$PROJECT_DIR/Sources/Daily365/WebViewContainer.swift"
    "$PROJECT_DIR/Sources/Daily365/BridgeHandler.swift"
    "$PROJECT_DIR/Sources/Daily365/FileStore.swift"
    "$PROJECT_DIR/Sources/Daily365/SpeechRecognizer.swift"
)

echo "📦 Compiling Swift files..."
swiftc \
    -o "$MACOS_DIR/$APP_NAME" \
    -target arm64-apple-macosx13.0 \
    -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    -framework SwiftUI \
    -framework WebKit \
    -framework AppKit \
    -framework UniformTypeIdentifiers \
    -framework Speech \
    -framework AVFoundation \
    "${SWIFT_FILES[@]}"

echo "📄 Copying resources..."
cp "$PROJECT_DIR/Sources/Daily365/Resources/index.html" "$RESOURCES_DIR/"

# Generate App Icon (.icns)
echo "🎨 Generating App Icon..."
ICON_SRC_DIR="$PROJECT_DIR/Sources/Daily365/Assets.xcassets/AppIcon.appiconset"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

cp "$ICON_SRC_DIR/icon_16x16.png"      "$ICONSET_DIR/icon_16x16.png"
cp "$ICON_SRC_DIR/icon_16x16@2x.png"   "$ICONSET_DIR/icon_16x16@2x.png"
cp "$ICON_SRC_DIR/icon_32x32.png"       "$ICONSET_DIR/icon_32x32.png"
cp "$ICON_SRC_DIR/icon_32x32@2x.png"   "$ICONSET_DIR/icon_32x32@2x.png"
cp "$ICON_SRC_DIR/icon_128x128.png"     "$ICONSET_DIR/icon_128x128.png"
cp "$ICON_SRC_DIR/icon_128x128@2x.png"  "$ICONSET_DIR/icon_128x128@2x.png"
cp "$ICON_SRC_DIR/icon_256x256.png"     "$ICONSET_DIR/icon_256x256.png"
cp "$ICON_SRC_DIR/icon_256x256@2x.png"  "$ICONSET_DIR/icon_256x256@2x.png"
cp "$ICON_SRC_DIR/icon_512x512.png"     "$ICONSET_DIR/icon_512x512.png"
cp "$ICON_SRC_DIR/icon_512x512@2x.png"  "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns -o "$RESOURCES_DIR/AppIcon.icns" "$ICONSET_DIR"
rm -rf "$ICONSET_DIR"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Daily 365</string>
    <key>CFBundleDisplayName</key>
    <string>Daily 365</string>
    <key>CFBundleIdentifier</key>
    <string>com.daily365.app</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Daily365</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Daily365. All rights reserved.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.lifestyle</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Daily 365 需要使用麦克风进行语音输入，将语音转为文字记录到日记中。</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Daily 365 需要使用语音识别功能，将您的语音转为文字记录到日记中。</string>
</dict>
</plist>
PLIST

# Sign with entitlements (enables microphone permission prompt)
ENTITLEMENTS="$PROJECT_DIR/Sources/Daily365/Daily365.entitlements"
echo "🔑 Signing with entitlements..."
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"

echo "✅ Build complete: $APP_BUNDLE"
echo "🚀 Run with: open $APP_BUNDLE"
