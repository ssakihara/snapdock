# SnapDock

スクショを撮ってから貼り付けるまでの手間をなくす macOS メニューバーアプリです。
メニューバーから最新 5 件のスクリーンショットを選び、Web ページや Claude Desktop にドラッグ＆ドロップするだけで貼り付けられます。

スクリーンショットは専用フォルダ `~/SnapDock` に保存されます（初回起動時に作成し、メニューから macOS の保存先を切り替えられます）。

初回起動時にログイン項目へ自動登録され、Mac にログインすると自動で起動します。不要ならメニューの「ログイン時に起動」をオフにしてください。

## 動作環境

- macOS 13 Ventura 以降

## ビルド

Xcode 16 以降で `SnapDock.xcodeproj` を開き、Signing & Capabilities の Team を選んでから実行してください。

## リリース（署名済み DMG）

公証用の認証情報を一度だけキーチェーンに保存します（App 用パスワードは appleid.apple.com で発行）。

```sh
xcrun notarytool store-credentials snapdock-notary --apple-id <Apple ID> --team-id <Team ID> --password <App 用パスワード>
```

「Developer ID Application」証明書がキーチェーンに入っている状態で実行します。

```sh
TEAM_ID=<Team ID> NOTARY_PROFILE=snapdock-notary scripts/build-dmg.sh
```

`build/release/SnapDock-<バージョン>.dmg` ができます。

できた DMG は `gh release create v<バージョン> build/release/SnapDock-<バージョン>.dmg --generate-notes` で GitHub Releases に公開します。
