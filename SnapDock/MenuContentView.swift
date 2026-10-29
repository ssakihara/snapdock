import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var folder: ScreenshotFolder
    @EnvironmentObject private var store: ScreenshotStore

    private let columns = [GridItem(.fixed(136), spacing: 8), GridItem(.fixed(136), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SnapDock")
                .font(.headline)

            if store.items.isEmpty {
                Text("スクリーンショットはまだありません")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(store.items) { item in
                        ScreenshotThumbnail(item: item)
                    }
                }
                Text("ドラッグして貼り付け・右クリックでコピー")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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
        .onAppear {
            folder.refresh()
            store.reload()
        }
    }
}
