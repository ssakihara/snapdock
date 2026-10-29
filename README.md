# SnapDock

スクショを撮ってから貼り付けるまでの手間をなくす macOS メニューバーアプリです。
メニューバーから最新 5 件のスクリーンショットを選び、Web ページや Claude Desktop にドラッグ＆ドロップするだけで貼り付けられます。

スクリーンショットは専用フォルダ `~/SnapDock` に保存されます（初回起動時に作成し、メニューから macOS の保存先を切り替えられます）。

## 動作環境

- macOS 13 Ventura 以降

## ビルド

Xcode 16 以降で `SnapDock.xcodeproj` を開き、Signing & Capabilities の Team を選んでから実行してください。
