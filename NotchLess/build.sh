#!/bin/zsh
# Compile NotchLess (universel arm64 + x86_64), assemble le .app et crée le .dmg.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Notch Less.app"
rm -rf build && mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
    swiftc -O -swift-version 5 -target "$arch-apple-macos13.0" \
        -o "build/NotchLess-$arch" Sources/*.swift ../Shared/SuiteIcons.swift ../Shared/SuiteMenu.swift ../Shared/UpdateCheck.swift ../Shared/Welcome.swift ../Shared/Localization.swift
done
lipo -create build/NotchLess-arm64 build/NotchLess-x86_64 -output "$APP/Contents/MacOS/NotchLess"

cp Resources/Info.plist "$APP/Contents/"
cp -R ../Shared/en.lproj ../Shared/fr.lproj "$APP/Contents/Resources/"
swiftc -o build/icon-tool ../Shared/SuiteIcons.swift ../Shared/IconTool/main.swift && build/icon-tool dot build
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

# Signature stable : les autorisations survivent aux recompilations.
../Shared/sign.sh "$APP"

# DMG avec raccourci vers /Applications
STAGE=build/dmg
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Notch Less" -srcfolder "$STAGE" -ov -format UDZO "build/Notch Less.dmg" >/dev/null
echo "OK → build/Notch Less.dmg"
