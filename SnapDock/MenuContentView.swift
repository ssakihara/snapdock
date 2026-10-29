import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var folder: ScreenshotFolder
    @EnvironmentObject private var store: ScreenshotStore
    @EnvironmentObject private var launchAtLogin: LaunchAtLogin
    @EnvironmentObject private var hotKey: DoubleOptionHotKey

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

            Toggle("ログイン時に起動", isOn: Binding(
                get: { launchAtLogin.isEnabled || launchAtLogin.requiresApproval },
                set: { launchAtLogin.setEnabled($0) }
            ))
            .toggleStyle(.checkbox)

            if launchAtLogin.requiresApproval {
                Button("システム設定でログイン項目を許可") { launchAtLogin.openSystemSettings() }
                    .font(.caption)
            }

            if let error = launchAtLogin.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle("⌥ を 2 回押して最新のスクショをコピー", isOn: Binding(
                get: { hotKey.isEnabled },
                set: { hotKey.setEnabled($0) }
            ))
            .toggleStyle(.checkbox)

            if hotKey.isEnabled && !hotKey.isTrusted {
                Text("使うにはアクセシビリティの許可が必要です")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("システム設定でアクセシビリティを許可") { hotKey.requestAccess() }
                    .font(.caption)
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
            launchAtLogin.refresh()
            hotKey.refresh()
        }
    }
}
