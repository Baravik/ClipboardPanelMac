import AppKit
import Combine
import ApplicationServices

// MARK: - Accessibility Permission Manager

/// Checks and monitors Accessibility permissions required for CGEvent posting and global hotkeys.
final class AccessibilityManager: ObservableObject {

    @Published private(set) var isAccessibilityGranted: Bool = false

    private var timer: Timer?
    private var activationObserver: Any?

    init() {
        checkAccessibility()
        startPolling()
        observeAppActivation()
    }

    deinit {
        timer?.invalidate()
        if let observer = activationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public

    /// Checks the current Accessibility permission status.
    func checkAccessibility() {
        let granted = AXIsProcessTrusted()
        if granted != isAccessibilityGranted {
            isAccessibilityGranted = granted
        }
    }

    /// Prompts the system Accessibility permission dialog.
    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // Re-check immediately in case the system already granted permission
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAccessibility()
        }
    }

    /// Opens System Settings directly to the Accessibility pane.
    func openAccessibilitySettings() {
        // macOS 13+ (Ventura) uses the new System Settings app
        if #available(macOS 13, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Private

    /// Periodically checks if permissions have been granted (user may enable while app is running).
    private func startPolling() {
        // Use RunLoop.common mode so the timer fires even during menu tracking
        let pollTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkAccessibility()
        }
        RunLoop.main.add(pollTimer, forMode: .common)
        timer = pollTimer
    }

    /// Re-check accessibility immediately when the user switches back to the app
    /// (e.g. after granting permission in System Settings).
    private func observeAppActivation() {
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAccessibility()
        }
    }
}
