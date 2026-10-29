import SwiftUI

@main
struct SnapDockApp: App {
    @StateObject private var folder: ScreenshotFolder
    @StateObject private var store: ScreenshotStore
    @StateObject private var launchAtLogin = LaunchAtLogin()
    @StateObject private var hotKey: DoubleOptionHotKey

    init() {
        let folder = ScreenshotFolder()
        _folder = StateObject(wrappedValue: folder)
        let store = ScreenshotStore(folderURL: folder.url)
        _store = StateObject(wrappedValue: store)
        _hotKey = StateObject(wrappedValue: DoubleOptionHotKey { [weak store] in
            if store?.copyLatest() == true {
                NSSound(named: "Pop")?.play()
            } else {
                NSSound.beep()
            }
        })
    }

    var body: some Scene {
        MenuBarExtra("SnapDock", image: "MenuBarIcon") {
            MenuContentView()
                .environmentObject(folder)
                .environmentObject(store)
                .environmentObject(launchAtLogin)
                .environmentObject(hotKey)
        }
        .menuBarExtraStyle(.window)
    }
}
