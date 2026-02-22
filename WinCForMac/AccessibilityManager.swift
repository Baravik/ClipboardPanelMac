import AppKit
import Combine
import ApplicationServices

// MARK: - Accessibility Permission Manager

/// Checks and monitors Accessibility permissions required for CGEvent posting and global hotkeys.
final class AccessibilityManager: ObservableObject {

    @Published private(set) var isAccessibilityGranted: Bool = false

    private var timer: Timer?

    init() {
        checkAccessibility()
        startPolling()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Public

    /// Checks the current Accessibility permission status.
    func checkAccessibility() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    /// Prompts the system Accessibility permission dialog.
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Opens System Settings directly to the Accessibility pane.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    /// Periodically checks if permissions have been granted (user may enable while app is running).
    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAccessibility()
        }
    }
}
