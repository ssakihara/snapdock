import AppKit
import Foundation
import ServiceManagement

/// ログイン時の自動起動（SMAppService.mainApp）を管理する。
/// 初回起動時に一度だけ自動で登録し、以降はメニューのトグルでユーザーが切り替える。
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let didAutoRegisterKey = "didAutoRegisterLaunchAtLogin"

    @Published private(set) var isEnabled = false
    /// 登録済みだがシステム設定でユーザーの承認待ち
    @Published private(set) var requiresApproval = false
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerOnFirstLaunch()
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = "ログイン時の起動を変更できませんでした: \(error.localizedDescription)"
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// 初回起動時だけ自動で登録する。ユーザーが後でオフにしたら、それ以降は勝手に戻さない。
    private func registerOnFirstLaunch() {
        guard !defaults.bool(forKey: Self.didAutoRegisterKey) else { return }
        defaults.set(true, forKey: Self.didAutoRegisterKey)
        if SMAppService.mainApp.status != .enabled {
            setEnabled(true)
        }
    }
}
