import AppKit
import QuickLookThumbnailing
import SwiftUI

/// サムネイル1枚。ドラッグするとファイルとして他のアプリに渡せる。
struct ScreenshotThumbnail: View {
    let item: ScreenshotStore.Item

    @State private var image: NSImage?

    private let size = CGSize(width: 136, height: 88)

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .frame(width: size.width, height: size.height)

            Text(item.createdAt, format: .dateTime.month().day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .help(item.url.lastPathComponent)
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("コピー") { item.copyToPasteboard() }
            Button("Finder で表示") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
        .task(id: item.url) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: size, scale: scale, representationTypes: .thumbnail)
        if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            image = representation.nsImage
        } else {
            image = NSImage(contentsOf: item.url)
        }
    }
}
