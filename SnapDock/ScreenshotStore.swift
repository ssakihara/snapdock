import Foundation

/// 監視フォルダ内の画像を新しい順に最大 `limit` 件保持する。
@MainActor
final class ScreenshotStore: ObservableObject {
    struct Item: Identifiable, Equatable {
        let url: URL
        let createdAt: Date
        var id: URL { url }
    }

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp", "avif", "gif", "bmp", "tiff", "tif", "pdf"]

    @Published private(set) var items: [Item] = []

    private let folderURL: URL
    private let limit: Int
    private var source: DispatchSourceFileSystemObject?

    init(folderURL: URL, limit: Int = 5) {
        self.folderURL = folderURL
        self.limit = limit
        reload()
        startWatching()
    }

    deinit {
        source?.cancel()
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
