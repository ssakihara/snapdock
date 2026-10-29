# SnapDock

スクショを撮ってから貼り付けるまでの手間をなくす macOS メニューバーアプリです。
メニューバーから最新 5 件のスクリーンショットを選び、Web ページや Claude Desktop にドラッグ＆ドロップするだけで貼り付けられます。

スクリーンショットは専用フォルダ `~/SnapDock` に保存されます（初回起動時に作成し、メニューから macOS の保存先を切り替えられます）。

## 動作環境

- macOS 13 Ventura 以降

## ビルド

Xcode 16 以降で `SnapDock.xcodeproj` を開き、Signing & Capabilities の Team を選んでから実行してください。

## リリース（署名済み DMG）

### ローカルで作る

公証用の認証情報を一度だけキーチェーンに保存します（App 用パスワードは appleid.apple.com で発行）。

```sh
xcrun notarytool store-credentials snapdock-notary --apple-id <Apple ID> --team-id <Team ID> --password <App 用パスワード>
```

「Developer ID Application」証明書がキーチェーンに入っている状態で実行します。

```sh
TEAM_ID=<Team ID> NOTARY_PROFILE=snapdock-notary scripts/build-dmg.sh
```

`build/release/SnapDock-<バージョン>.dmg` ができます。

### GitHub Actions で作る

`v0.1.0` のようなタグを push すると、署名・公証した DMG を GitHub Releases に公開します。リポジトリの Secrets に次を登録してください。

| Secret | 内容 |
| --- | --- |
| `APPLE_TEAM_ID` | Team ID |
| `DEVELOPER_ID_P12_BASE64` | 「Developer ID Application」証明書を秘密鍵ごと書き出した .p12 を `base64 -i cert.p12` したもの |
| `DEVELOPER_ID_P12_PASSWORD` | .p12 のパスワード |
| `NOTARY_KEY_P8_BASE64` | App Store Connect API キー（.p8）を base64 したもの |
| `NOTARY_KEY_ID` | API キーの Key ID |
| `NOTARY_ISSUER_ID` | API キーの Issuer ID |
