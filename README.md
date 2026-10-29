# SnapDock

スクショを撮ってから貼り付けるまでの手間をなくす macOS メニューバーアプリです。
メニューバーから最新 5 件のスクリーンショットを選び、Web ページや Claude Desktop にドラッグ＆ドロップするだけで貼り付けられます。

スクリーンショットは専用フォルダ `~/SnapDock` に保存されます（初回起動時に作成し、メニューから macOS の保存先を切り替えられます）。

## 動作環境

- macOS 13 Ventura 以降

## ビルド

プロジェクトファイルは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で生成します。

```sh
brew install xcodegen
xcodegen generate
open SnapDock.xcodeproj
```

Xcode で Signing & Capabilities の Team を選んでから実行してください。
