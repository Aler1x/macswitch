#!/bin/zsh
# Builds a universal build/MacSwitch.app.
#   --install  also copies it to ~/Applications and starts it
#   --zip      also creates dist/MacSwitch.zip for sharing
set -euo pipefail
cd "$(dirname "$0")"

APP=build/MacSwitch.app
TMP=build/tmp
ICONSET=$TMP/AppIcon.iconset

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"

for arch in arm64 x86_64; do
    swiftc -swift-version 5 -O -target "$arch-apple-macos13.0" macswitch.swift -o "$TMP/macswitch-$arch"
done
lipo -create "$TMP"/macswitch-* -output "$APP/Contents/MacOS/macswitch"
cp Info.plist "$APP/Contents/Info.plist"
VERSION=$(<VERSION)
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"

swiftc -swift-version 5 scripts/make-icon.swift -o "$TMP/make-icon"
"$TMP/make-icon" "$TMP/icon.png"
for size in 16 32 128 256 512; do
    sips -z $size $size "$TMP/icon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$TMP/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"
echo "Built $PWD/$APP"

if [[ " $* " == *" --zip "* ]]; then
    mkdir -p dist
    ditto -c -k --keepParent "$APP" dist/MacSwitch.zip
    echo "Created $PWD/dist/MacSwitch.zip"
fi

if [[ " $* " == *" --install "* ]]; then
    pkill -x macswitch || true
    rm -rf ~/Applications/MacSwitch.app
    mkdir -p ~/Applications
    cp -R "$APP" ~/Applications/
    open ~/Applications/MacSwitch.app
    echo "Installed to ~/Applications"
fi
