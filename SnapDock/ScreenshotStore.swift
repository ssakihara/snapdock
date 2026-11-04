import AppKit
import Foundation

/// 監視フォルダ内の画像を新しい順に最大 `limit` 件保持する。
@MainActor
final class ScreenshotStore: ObservableObject {
    struct Item: Identifiable, Equatable {
        let url: URL
        let createdAt: Date
        var id: URL { url }

        /// ファイルと画像の両方をクリップボードに載せる（貼り付け先が受け取れる方を使う）。
        func copyToPasteboard() {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([url as NSURL])
            if let image = NSImage(contentsOf: url) {
                pasteboard.writeObjects([image])
            }
        }
    }

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp", "avif", "gif", "bmp", "tiff", "tif", "pdf"]
    /// 自動でゴミ箱へ移す対象（スクショと画面収録）
    static let expirableExtensions: Set<String> = imageExtensions.union(["mov", "mp4"])

    static let autoTrashEnabledKey = "autoTrashEnabled"
    /// 作成からこの時間が経ったファイルをゴミ箱へ移す
    static let expiration: TimeInterval = 3 * 24 * 60 * 60
    /// 期限切れの確認間隔
    static let autoTrashInterval: TimeInterval = 60 * 60

    @Published private(set) var items: [Item] = []
    @Published private(set) var isAutoTrashEnabled: Bool

    private let folderURL: URL
    private let limit: Int
    private let defaults: UserDefaults
    private var source: DispatchSourceFileSystemObject?
    private var autoTrashTimer: Timer?

    init(folderURL: URL, limit: Int = 5, defaults: UserDefaults = .standard) {
        self.folderURL = folderURL
        self.limit = limit
        self.defaults = defaults
        isAutoTrashEnabled = defaults.object(forKey: Self.autoTrashEnabledKey) as? Bool ?? true
        if isAutoTrashEnabled {
            startAutoTrash()
        }
        reload()
        startWatching()
    }

    deinit {
        source?.cancel()
        autoTrashTimer?.invalidate()
    }

    func setAutoTrashEnabled(_ enabled: Bool) {
        isAutoTrashEnabled = enabled
        defaults.set(enabled, forKey: Self.autoTrashEnabledKey)
        if enabled {
            startAutoTrash()
        } else {
            autoTrashTimer?.invalidate()
            autoTrashTimer = nil
        }
    }

    /// 作成から `expiration` 以上経ったスクショをゴミ箱へ移す（完全には削除しない）。
    func trashExpired(now: Date = Date()) {
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        let cutoff = now.addingTimeInterval(-Self.expiration)
        for url in urls {
            guard Self.expirableExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let createdAt = values.creationDate, // 作成日時が取れないものは触らない
                  createdAt < cutoff else { continue }
            try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }

    /// 起動時（有効化時）に一度、その後は定期的に期限切れを確認する。
    private func startAutoTrash() {
        trashExpired()
        guard autoTrashTimer == nil else { return }
        let timer = Timer(timeInterval: Self.autoTrashInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.trashExpired() }
        }
        timer.tolerance = 60
        RunLoop.main.add(timer, forMode: .common)
        autoTrashTimer = timer
    }

    func reload() {
        let keys: [URLResourceKey] = [.creationDateKey, .isRegularFileKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles] // 撮影中の一時ファイル（.Screenshot...）を除外
        )) ?? []

        let newItems = urls.compactMap { url -> Item? in
            guard Self.imageExtensions.contains(url.pathExtension.lowercased()),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { return nil }
            return Item(url: url, createdAt: values.creationDate ?? .distantPast)
        }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(limit)

        if Array(newItems) != items {
            items = Array(newItems)
        }
    }

    /// 最新のスクショをクリップボードにコピーする。コピーできたら true。
    @discardableResult
    func copyLatest() -> Bool {
        reload()
        guard let latest = items.first else { return false }
        latest.copyToPasteboard()
        return true
    }

    /// フォルダの書き込み（追加・削除・リネーム）を監視して一覧を更新する。
    private func startWatching() {
        let fd = open(folderURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        self.source = source
    }
}
