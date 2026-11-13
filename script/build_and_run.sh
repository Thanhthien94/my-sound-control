#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
source script/toolchain.sh
MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--debug|--logs|--telemetry) ;; *) echo "Usage: $0 [run|--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2;; esac
APP_NAME=MySoundControl
BUNDLE_ID=vn.thiendev.mysoundcontrol
APP_RELEASE="$(cat VERSION)"
[[ "$APP_RELEASE" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$ ]] || { echo 'Invalid VERSION' >&2; exit 1; }
CONFIGURATION="${MSC_CONFIGURATION:-debug}"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
# Never replace an app bundle while its audio engine is running, even for build-only.
if /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then
  /usr/bin/osascript -e 'tell application id "vn.thiendev.mysoundcontrol" to quit'
  for ((i=0; i<30; i++)); do
    if ! /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then break; fi
    sleep 0.2
  done
  if /usr/bin/pgrep -x "$APP_NAME" >/dev/null; then echo 'Quit My Sound Control before rebuilding.' >&2; exit 1; fi
fi
if [[ -n "${MSC_BUILD_ARCH:-}" ]]; then
  case "$MSC_BUILD_ARCH" in arm64|x86_64) ;; *) echo 'Invalid MSC_BUILD_ARCH' >&2; exit 2;; esac
  MSC_SWIFT_ARGS+=(--arch "$MSC_BUILD_ARCH")
fi
swift build --configuration "$CONFIGURATION" ${MSC_SWIFT_ARGS[@]+"${MSC_SWIFT_ARGS[@]}"}
BIN_DIR="$(swift build --configuration "$CONFIGURATION" ${MSC_SWIFT_ARGS[@]+"${MSC_SWIFT_ARGS[@]}"} --show-bin-path)"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp LICENSE PRIVACY.md THIRD_PARTY_NOTICES.md "$APP_BUNDLE/Contents/Resources/"
APP_BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
SOURCE_REVISION="$(git rev-parse --verify HEAD 2>/dev/null || echo uncommitted)"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>My Sound Control</string>
<key>CFBundleDisplayName</key><string>My Sound Control</string>
<key>CFBundleShortVersionString</key><string>${APP_RELEASE%%-*}</string>
<key>CFBundleVersion</key><string>$APP_BUILD_NUMBER</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>15.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSAudioCaptureUsageDescription</key><string>My Sound Control cần thu âm thanh của ứng dụng bạn chọn để điều chỉnh âm lượng và phát tới thiết bị của bạn. Âm thanh được xử lý trên máy, không ghi hoặc tải lên mạng.</string>
<key>MSCReleaseLabel</key><string>$APP_RELEASE</string>
<key>MSCSourceRevision</key><string>$SOURCE_REVISION</string>
</dict></plist>
PLIST
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
/usr/bin/codesign --force --sign - "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"
case "$MODE" in
  --build-only) echo "$APP_BUNDLE" ;;
  --verify) /usr/bin/open -n "$APP_BUNDLE"; sleep 2; /usr/bin/pgrep -x "$APP_NAME" ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "MySoundControl"' ;;
  --telemetry) /usr/bin/open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "vn.thiendev.mysoundcontrol"' ;;
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
esac
