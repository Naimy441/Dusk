#!/bin/bash
# Builds Dusk.app into ./build.
#
#   ./build.sh             build an ad-hoc signed app (local use)
#   ./build.sh --install   build, copy to /Applications and launch
#   ./build.sh --release   build, sign with Developer ID, notarize, and package
#                          build/Dusk.dmg + build/Dusk.zip
#
# Release mode reads:
#   SIGN_IDENTITY   e.g. "Developer ID Application: Your Name (TEAMID)"
#                   (defaults to the first Developer ID Application identity found)
#   NOTARY_PROFILE  a keychain profile created with `xcrun notarytool store-credentials`
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Dusk"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"
MODE="${1:-}"

echo "▸ Compiling (release)…"
if swift build -c release --arch arm64 --arch x86_64 >/dev/null 2>&1; then
    BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
    echo "  universal binary (arm64 + x86_64)"
else
    swift build -c release
    BIN_DIR=$(swift build -c release --show-bin-path)
    echo "  native binary"
fi

echo "▸ Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "▸ Rendering icon…"
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
swift Tools/make-icon.swift "$ICONSET" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

if [[ "$MODE" == "--release" ]]; then
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool keychain profile}"
    if [[ -z "${SIGN_IDENTITY:-}" ]]; then
        SIGN_IDENTITY=$(security find-identity -v -p codesigning \
            | grep -o '"Developer ID Application: [^"]*"' | head -1 | tr -d '"')
    fi
    [[ -n "$SIGN_IDENTITY" ]] || { echo "No Developer ID Application identity found"; exit 1; }

    echo "▸ Signing with Developer ID (hardened runtime)…"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
    codesign --verify --strict --verbose=2 "$APP"

    echo "▸ Notarizing app…"
    ZIP="$BUILD_DIR/$APP_NAME.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"

    echo "▸ Building DMG…"
    DMG="$BUILD_DIR/$APP_NAME.dmg"
    STAGE="$BUILD_DIR/dmg"
    rm -rf "$STAGE" "$DMG"
    mkdir -p "$STAGE"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
    rm -rf "$STAGE"
    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

    echo "▸ Notarizing DMG…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"

    spctl --assess --type execute --verbose "$APP"
    echo "✓ Release ready: $DMG, $ZIP"
else
    echo "▸ Signing (ad-hoc)…"
    codesign --force --deep --sign - "$APP" >/dev/null 2>&1
    echo "✓ Built $APP"
fi

if [[ "$MODE" == "--install" || "$MODE" == "--release" ]]; then
    pkill -x "$APP_NAME" 2>/dev/null || true
    rm -rf "/Applications/$APP_NAME.app"
    cp -R "$APP" /Applications/
    echo "✓ Installed to /Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
fi
