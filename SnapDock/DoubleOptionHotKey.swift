import AppKit
import ApplicationServices
import Foundation

/// Option (⌥) キーを単独で 2 回素早く押したことを検知して `action` を呼ぶ。
/// 他のアプリ上でのキー操作を見るにはアクセシビリティの許可が必要。
@MainActor
final class DoubleOptionHotKey: ObservableObject {
    static let isEnabledKey = "doubleOptionHotKeyEnabled"
    static let didPromptKey = "didPromptAccessibilityForHotKey"

    /// Option を押してから離すまでの上限（長押しはタップとみなさない）
    static let maxPressDuration: TimeInterval = 0.35
    /// 1 回目のタップから 2 回目のタップまでの上限
    static let maxTapInterval: TimeInterval = 0.4
    /// 判定に使う修飾キー（Caps Lock は無視する）
    static let modifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command, .function]

    @Published private(set) var isEnabled: Bool
    /// アクセシビリティが許可されているか
    @Published private(set) var isTrusted = false

    private let defaults: UserDefaults
    private let action: @MainActor () -> Void

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var trustTimer: Timer?

    /// 他のキーや修飾キーを挟まずに Option だけが押されている間、押し始めた時刻
    private var optionDownAt: Date?
    private var lastTapAt: Date?
    /// 他の修飾キーが混ざったので、すべて離されるまで無視する
    private var isInterrupted = false

    init(defaults: UserDefaults = .standard, action: @escaping @MainActor () -> Void) {
        self.defaults = defaults
        self.action = action
        isEnabled = defaults.object(forKey: Self.isEnabledKey) as? Bool ?? true
        isTrusted = AXIsProcessTrusted()
        if isEnabled {
            start()
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.isEnabledKey)
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
        if isEnabled {
            // 許可前に登録したグローバル監視にはキーイベントが届かないので、登録し直す
            installMonitors()
        }
    }

    /// アクセシビリティの許可を求める。初回は macOS の確認ダイアログ、以降はシステム設定を開く。
    func requestAccess() {
        if defaults.bool(forKey: Self.didPromptKey) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        } else {
            defaults.set(true, forKey: Self.didPromptKey)
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            isTrusted = AXIsProcessTrustedWithOptions(options)
        }
        watchTrust()
    }

    private func start() {
        installMonitors()
        guard !AXIsProcessTrusted() else { return }
        if defaults.bool(forKey: Self.didPromptKey) {
            watchTrust()
        } else {
            requestAccess()
        }
    }

    private func stop() {
        removeMonitors()
        trustTimer?.invalidate()
        trustTimer = nil
        reset()
    }

    /// 許可されるまで定期的に確認し、許可されたら監視を登録し直す。
    private func watchTrust() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refresh()
                if self.isTrusted || !self.isEnabled {
                    self.trustTimer?.invalidate()
                    self.trustTimer = nil
                }
            }
        }
    }

    private func installMonitors() {
        removeMonitors()
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        // SnapDock 自身が前面にあるときはグローバル監視に届かないので、ローカル監視も付ける
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    private func removeMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .flagsChanged else {
            // Option の間に他のキーやクリックが入ったら取り消す（⌥+クリック、⌥+文字 など）
            reset()
            isInterrupted = !event.modifierFlags.intersection(Self.modifiers).isEmpty
            return
        }

        let flags = event.modifierFlags.intersection(Self.modifiers)
        let now = Date()

        if flags.isEmpty {
            isInterrupted = false
        }
        guard !isInterrupted else { return }

        if flags == .option {
            optionDownAt = optionDownAt ?? now
        } else if flags.isEmpty, let downAt = optionDownAt {
            optionDownAt = nil
            guard now.timeIntervalSince(downAt) <= Self.maxPressDuration else {
                lastTapAt = nil
                return
            }
            if let lastTapAt, now.timeIntervalSince(lastTapAt) <= Self.maxTapInterval {
                self.lastTapAt = nil
                action()
            } else {
                lastTapAt = now
            }
        } else {
            // Option 以外の修飾キーが混ざった
            reset()
            isInterrupted = !flags.isEmpty
        }
    }

    private func reset() {
        optionDownAt = nil
        lastTapAt = nil
    }
}
