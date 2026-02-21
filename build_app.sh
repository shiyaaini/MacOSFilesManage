#!/usr/bin/env bash
set -euo pipefail
SCHEME="${SCHEME:-FilesManage}"
CONFIG="${CONFIG:-Release}"
PROJECT="${PROJECT:-FilesManage.xcodeproj}"
DERIVED="${DERIVED:-}"
OUT="${OUT:-./dist}"
APP_NAME="${APP_NAME:-FilesManage.app}"
ZIP_NAME="${ZIP_NAME:-FilesManage.zip}"
BUNDLE_ID="${BUNDLE_ID:-qrhc.FilesManage}"
SIGN_ID="${SIGN_ID:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme) SCHEME="$2"; shift 2;;
    --config) CONFIG="$2"; shift 2;;
    --project) PROJECT="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --derived) DERIVED="$2"; shift 2;;
    --zip) ZIP_NAME="$2"; shift 2;;
    --clean) CLEAN=1; shift;;
    --dmg) DMG=1; shift;;
    --pkg) PKG=1; shift;;
    --desktop) DESKTOP=1; shift;;
    *) shift;;
  esac
done
CLEAN="${CLEAN:-0}"
DMG="${DMG:-0}"
PKG="${PKG:-0}"
DESKTOP="${DESKTOP:-0}"
mkdir -p "$OUT"
if [[ "$CLEAN" == "1" ]]; then
  if [[ -n "$DERIVED" ]]; then
    xcodebuild clean -project "$PROJECT" -scheme "$SCHEME"
  else
    xcodebuild clean -project "$PROJECT" -scheme "$SCHEME"
  fi
fi
if [[ -n "$DERIVED" ]]; then
  mkdir -p "$DERIVED"
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" -derivedDataPath "$DERIVED" build
  APP_PATH="$DERIVED/Build/Products/$CONFIG/$APP_NAME"
else
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" build
  APP_PATH="$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*Build/Products/'"$CONFIG"'/'"$APP_NAME" -type d -print -quit 2>/dev/null || true)"
fi
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Build output not found" >&2
  exit 1
fi
rm -rf "$OUT/$APP_NAME" "$OUT/$ZIP_NAME" "$OUT/FilesManage.dmg" "$OUT/FilesManage.pkg" "$OUT/dmgroot"
cp -R "$APP_PATH" "$OUT/"
ditto -c -k --keepParent "$OUT/$APP_NAME" "$OUT/$ZIP_NAME"
if [[ "$DMG" == "1" ]]; then
  mkdir -p "$OUT/dmgroot"
  cp -R "$OUT/$APP_NAME" "$OUT/dmgroot/"
  ln -sf /Applications "$OUT/dmgroot/Applications"
  hdiutil create -volname "FilesManage" -srcfolder "$OUT/dmgroot" -ov -format UDZO "$OUT/FilesManage.dmg"
fi
if [[ "$PKG" == "1" ]]; then
  if [[ -n "$SIGN_ID" ]]; then
    pkgbuild --identifier "$BUNDLE_ID" --install-location "/Applications" --component "$OUT/$APP_NAME" --sign "$SIGN_ID" "$OUT/FilesManage.pkg"
  else
    pkgbuild --identifier "$BUNDLE_ID" --install-location "/Applications" --component "$OUT/$APP_NAME" "$OUT/FilesManage.pkg"
  fi
fi
if [[ "$DESKTOP" == "1" ]]; then
  DESKTOP_DIR="$HOME/Desktop"
  if [[ -d "$DESKTOP_DIR" ]]; then
    cp -R "$OUT/$APP_NAME" "$DESKTOP_DIR/" || true
    cp "$OUT/$ZIP_NAME" "$DESKTOP_DIR/" || true
    if [[ -f "$OUT/FilesManage.dmg" ]]; then cp "$OUT/FilesManage.dmg" "$DESKTOP_DIR/" || true; fi
    if [[ -f "$OUT/FilesManage.pkg" ]]; then cp "$OUT/FilesManage.pkg" "$DESKTOP_DIR/" || true; fi
  fi
fi
echo "App: $OUT/$APP_NAME"
echo "Zip: $OUT/$ZIP_NAME"
if [[ "$DMG" == "1" ]]; then echo "DMG: $OUT/FilesManage.dmg"; fi
if [[ "$PKG" == "1" ]]; then echo "PKG: $OUT/FilesManage.pkg"; fi
