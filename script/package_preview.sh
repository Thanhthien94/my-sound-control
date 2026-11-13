#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source script/toolchain.sh
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  echo 'Package previews from a clean committed tree.' >&2; exit 1
fi
VERSION="$(cat VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+-preview\.[1-9][0-9]*$ ]] || { echo 'Expected preview version' >&2; exit 1; }
MSC_CONFIGURATION=release MSC_BUILD_ARCH=arm64 ./script/build_and_run.sh --build-only
APP="$ROOT_DIR/dist/MySoundControl.app"
[[ "$(/usr/bin/lipo -archs "$APP/Contents/MacOS/MySoundControl")" == arm64 ]] || { echo 'Preview supports arm64 only' >&2; exit 1; }
/usr/bin/codesign --verify --deep --strict "$APP"
STAGE="$(mktemp -d "$ROOT_DIR/dist/package-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
/usr/bin/ditto --norsrc --noextattr --noacl "$APP" "$STAGE/MySoundControl.app"
/usr/bin/codesign --verify --deep --strict "$STAGE/MySoundControl.app"
ln -s /Applications "$STAGE/Applications"
cp INSTALL.md "$STAGE/START HERE.md"
cp LICENSE THIRD_PARTY_NOTICES.md PRIVACY.md "$STAGE/"
DMG="$ROOT_DIR/dist/MySoundControl-$VERSION-arm64.dmg"
ZIP="$ROOT_DIR/dist/MySoundControl-$VERSION-arm64.zip"
# Do not silently replace previously packaged assets for the same version.
[[ ! -e "$DMG" && ! -e "$ZIP" ]] || { echo 'Assets already exist; bump VERSION or move the previous assets.' >&2; exit 1; }
/usr/bin/hdiutil create -quiet -volname 'My Sound Control Preview' -srcfolder "$STAGE" -format UDZO "$DMG"
/usr/bin/ditto -c -k --norsrc --noextattr --noacl --keepParent "$STAGE/MySoundControl.app" "$ZIP"
(cd dist && shasum -a 256 "$(basename "$DMG")" "$(basename "$ZIP")" > SHA256SUMS.txt)
echo "$DMG"
echo "$ZIP"
