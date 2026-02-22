import AppKit
import SwiftUI
import Combine

// MARK: - App Delegate

/// Manages the menu bar status item, floating panel, and coordinates all managers.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Managers

    private let clipboardMonitor = ClipboardMonitor()
    private let accessibilityManager = AccessibilityManager()
    private let hotkeyManager = HotkeyManager()

    // MARK: - UI

    private var statusItem: NSStatusItem!
    private var floatingPanel: FloatingPanel?
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotkey()
        observeAccessibility()
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "Clipboard Panel OS")
            button.image?.size = NSSize(width: 16, height: 16)
            button.image?.isTemplate = true
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(withTitle: "Show Clipboard History", action: #selector(showPanel), keyEquivalent: "")
            .target = self

        menu.addItem(.separator())

        let recentHeader = NSMenuItem(title: "Recent Items", action: nil, keyEquivalent: "")
        recentHeader.isEnabled = false
        menu.addItem(recentHeader)

        // Show up to 5 recent items in the menu
        let recentItems = Array(clipboardMonitor.items.prefix(5))
        if recentItems.isEmpty {
            let emptyItem = NSMenuItem(title: "No clipboard history yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, item) in recentItems.enumerated() {
                let menuItem = NSMenuItem(
                    title: item.preview,
                    action: #selector(quickPaste(_:)),
                    keyEquivalent: "\(index + 1)"
                )
                menuItem.keyEquivalentModifierMask = [.command]
                menuItem.representedObject = item
                menuItem.target = self
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())

        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
            .target = self

        menu.addItem(.separator())

        if !clipboardMonitor.items.isEmpty {
            menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
                .target = self
            menu.addItem(.separator())
        }

        menu.addItem(withTitle: "Quit Clipboard Panel OS", action: #selector(quitApp), keyEquivalent: "q")
            .target = self

        // Rebuild menu each time it opens to update recent items
        menu.delegate = self

        return menu
    }

    // MARK: - Hotkey Setup

    private func setupHotkey() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.togglePanel()
        }
    }

    // MARK: - Accessibility Observer

    private func observeAccessibility() {
        accessibilityManager.$isAccessibilityGranted
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                // If panel is showing onboarding and permission is granted, refresh it
                if granted {
                    self?.refreshPanelIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Panel Management

    private func togglePanel() {
        if let panel = floatingPanel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    @objc private func showPanel() {
        // Dismiss existing panel if any
        hidePanel()

        let panelSize = NSSize(width: 380, height: 420)
        let panelOrigin = panelOriginAtCursor(size: panelSize)
        let contentRect = NSRect(origin: panelOrigin, size: panelSize)

        let panel = FloatingPanel(contentRect: contentRect)
        floatingPanel = panel

        // Observe when the panel resigns key (user clicked outside) to clean up
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )

        let contentView: AnyView
        if accessibilityManager.isAccessibilityGranted {
            contentView = AnyView(
                MainView(
                    clipboardMonitor: clipboardMonitor,
                    onItemSelected: { [weak self] item in
                        self?.hidePanel()
                        // Small delay to allow panel to close before pasting
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            self?.clipboardMonitor.pasteItem(item)
                        }
                    },
                    onDismiss: { [weak self] in
                        self?.hidePanel()
                    }
                )
            )
        } else {
            contentView = AnyView(
                OnboardingView(accessibilityManager: accessibilityManager)
            )
        }

        panel.contentView = NSHostingView(rootView: contentView)
        panel.makeKeyAndOrderFront(nil)

        // Activate the app briefly so the panel can become key
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func panelDidResignKey(_ notification: Notification) {
        // User clicked outside the panel — dismiss and clean up
        hidePanel()
    }

    private func hidePanel() {
        if let panel = floatingPanel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: panel)
            panel.orderOut(nil)
            panel.close()
        }
        floatingPanel = nil
    }

    private func refreshPanelIfNeeded() {
        if let panel = floatingPanel, panel.isVisible {
            // Re-show with updated content
            showPanel()
        }
    }

    /// Calculates panel origin so it appears near the mouse cursor, clamped to screen bounds.
    private func panelOriginAtCursor(size: NSSize) -> NSPoint {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!

        let visibleFrame = screen.visibleFrame
        let cursorOffset: CGFloat = 8

        var x = mouseLocation.x - size.width / 2
        var y = mouseLocation.y - size.height - cursorOffset

        // Clamp to screen bounds
        x = max(visibleFrame.minX + 4, min(x, visibleFrame.maxX - size.width - 4))
        y = max(visibleFrame.minY + 4, min(y, visibleFrame.maxY - size.height - 4))

        return NSPoint(x: x, y: y)
    }

    // MARK: - Settings Window

    @objc private func showSettings() {
        if let settingsWindow = settingsWindow, settingsWindow.isVisible {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            hotkeyManager: hotkeyManager,
            accessibilityManager: accessibilityManager
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clipboard Panel OS Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    // MARK: - Actions

    @objc private func quickPaste(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        clipboardMonitor.pasteItem(item)
    }

    @objc private func clearHistory() {
        clipboardMonitor.clearHistory()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Rebuild menu with fresh recent items each time it opens
        menu.removeAllItems()
        let updated = buildMenu()
        for item in updated.items {
            updated.removeItem(item)
            menu.addItem(item)
        }
    }
}
