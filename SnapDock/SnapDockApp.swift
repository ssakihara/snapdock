import SwiftUI

@main
struct SnapDockApp: App {
    @StateObject private var folder = ScreenshotFolder()

    var body: some Scene {
        MenuBarExtra("SnapDock", systemImage: "photo.on.rectangle.angled") {
            MenuContentView()
                .environmentObject(folder)
        }
        .menuBarExtraStyle(.window)
    }
}
