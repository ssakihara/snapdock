#!/usr/bin/env bash
# SnapDock を Developer ID で署名し、公証済みの DMG を作る。
#
# 必須の環境変数:
#   TEAM_ID            Apple Developer の Team ID（10桁）
# 公証の認証（どちらか一方）:
#   NOTARY_PROFILE     `xcrun notarytool store-credentials` で保存したプロファイル名（ローカル向け）
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID   App Store Connect API キー（CI 向け）
# 任意:
#   VERSION            設定すると MARKETING_VERSION を上書きする（例: 0.2.0）
#   SKIP_NOTARIZE=1    公証をスキップする（署名だけ確かめたいとき）
set -euo pipefail

cd "$(dirname "$0")/.."

: "${TEAM_ID:?TEAM_ID を設定してください}"

APP_NAME="SnapDock"
BUILD_DIR="build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
DMG_STAGING="$BUILD_DIR/dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

version_args=()
if [[ -n "${VERSION:-}" ]]; then
  version_args+=("MARKETING_VERSION=$VERSION")
fi

echo "==> Archive"
xcodebuild archive \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  -destination "generic/platform=macOS" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  ${version_args[@]+"${version_args[@]}"}

echo "==> Export"
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>Developer ID Application</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

APP_PATH="$EXPORT_DIR/$APP_NAME.app"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_PATH="$BUILD_DIR/$APP_NAME-$APP_VERSION.dmg"

echo "==> DMG"
mkdir -p "$DMG_STAGING"
cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -fs HFS+ \
  -format UDZO \
  -ov "$DMG_PATH"
codesign --sign "Developer ID Application" --team-id "$TEAM_ID" --timestamp "$DMG_PATH"

if [[ "${SKIP_NOTARIZE:-}" == "1" ]]; then
  echo "==> 公証をスキップしました: $DMG_PATH"
  exit 0
fi

echo "==> Notarize"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  notary_auth=(--keychain-profile "$NOTARY_PROFILE")
else
  : "${NOTARY_KEY_PATH:?NOTARY_PROFILE か NOTARY_KEY_PATH を設定してください}"
  : "${NOTARY_KEY_ID:?NOTARY_KEY_ID を設定してください}"
  : "${NOTARY_ISSUER_ID:?NOTARY_ISSUER_ID を設定してください}"
  notary_auth=(--key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID")
fi
xcrun notarytool submit "$DMG_PATH" "${notary_auth[@]}" --wait
xcrun stapler staple "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"

echo "==> 完了: $DMG_PATH"
