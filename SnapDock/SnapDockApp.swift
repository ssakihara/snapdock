import SwiftUI

@main
struct SnapDockApp: App {
    @StateObject private var folder: ScreenshotFolder
    @StateObject private var store: ScreenshotStore
    @StateObject private var launchAtLogin = LaunchAtLogin()

    init() {
        let folder = ScreenshotFolder()
        _folder = StateObject(wrappedValue: folder)
        _store = StateObject(wrappedValue: ScreenshotStore(folderURL: folder.url))
    }

    var body: some Scene {
        MenuBarExtra("SnapDock", image: "MenuBarIcon") {
            MenuContentView()
                .environmentObject(folder)
                .environmentObject(store)
                .environmentObject(launchAtLogin)
        }
        .menuBarExtraStyle(.window)
    }
}
