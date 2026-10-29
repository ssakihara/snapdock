import AppKit
import Foundation

/// アプリ専用のスクリーンショットフォルダ（~/SnapDock）と、macOS のスクショ保存先設定を管理する。
@MainActor
final class ScreenshotFolder: ObservableObject {
    static let screencaptureDomain = "com.apple.screencapture"

    let url: URL

    /// macOS のスクショ保存先がこのフォルダになっているか
    @Published private(set) var isSystemLocation = false
    @Published private(set) var lastError: String?

    init(url: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("SnapDock", isDirectory: true)) {
        self.url = url
        createIfNeeded()
        refresh()
    }

    func createIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            lastError = "フォルダを作成できませんでした: \(error.localizedDescription)"
        }
    }

    func refresh() {
        isSystemLocation = currentSystemLocation().map { $0.standardizedFileURL == url.standardizedFileURL } ?? false
    }

    /// `defaults read com.apple.screencapture location` 相当。未設定ならデスクトップ。
    func currentSystemLocation() -> URL? {
        guard let path = CFPreferencesCopyAppValue("location" as CFString, Self.screencaptureDomain as CFString) as? String else {
            return nil
        }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }

    /// macOS のスクショ保存先をこのフォルダに切り替える。
    func makeSystemLocation() {
        createIfNeeded()
        do {
            try run("/usr/bin/defaults", ["write", Self.screencaptureDomain, "location", url.path])
            // 設定を即時反映させる（失敗しても次回ログイン時には反映される）
            try? run("/usr/bin/killall", ["SystemUIServer"])
            lastError = nil
        } catch {
            lastError = "保存先を変更できませんでした: \(error.localizedDescription)"
        }
        refresh()
    }

    func openInFinder() {
        NSWorkspace.shared.open(url)
    }

    private func run(_ launchPath: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "SnapDock", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(launchPath) が終了コード \(process.terminationStatus) で失敗しました"])
        }
    }
}
