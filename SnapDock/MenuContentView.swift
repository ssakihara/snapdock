import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var folder: ScreenshotFolder

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SnapDock")
                .font(.headline)

            // ステップ2でここに最新5件のサムネイルを並べる
            Text("スクリーンショットはまだありません")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)

            Divider()

            if folder.isSystemLocation {
                Label("保存先: ~/SnapDock", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("スクショの保存先が SnapDock ではありません", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("保存先を ~/SnapDock に変更") {
                    folder.makeSystemLocation()
                }
            }

            if let error = folder.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("フォルダを開く") { folder.openInFinder() }
                Spacer()
                Button("終了") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { folder.refresh() }
    }
}
