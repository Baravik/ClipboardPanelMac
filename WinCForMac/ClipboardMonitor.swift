import AppKit
import Combine

// MARK: - Clipboard Monitor Service

/// Monitors NSPasteboard.general for changes and maintains an in-memory history.
final class ClipboardMonitor: ObservableObject {

    // MARK: - Configuration

    static let maxItems = 50
    private static let pollInterval: TimeInterval = 0.5

    // MARK: - Published State

    @Published private(set) var items: [ClipboardItem] = []

    // MARK: - Private

    private var lastChangeCount: Int
    private var timer: Timer?

    // MARK: - Init

    init() {
        self.lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.pollInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Clipboard Interaction

    /// Copies the selected item back to the pasteboard and simulates Cmd+V.
    func pasteItem(_ item: ClipboardItem) {
        // Temporarily stop monitoring so we don't re-capture our own paste
        stopMonitoring()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        lastChangeCount = pasteboard.changeCount

        // Small delay to ensure the pasteboard is updated before simulating the keystroke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.simulateCmdV()
            // Resume monitoring after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.lastChangeCount = NSPasteboard.general.changeCount
                self?.startMonitoring()
            }
        }
    }

    /// Clears all history.
    func clearHistory() {
        items.removeAll()
    }

    /// Removes a single item from history.
    func removeItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
    }

    // MARK: - Private Helpers

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let newString = pasteboard.string(forType: .string),
              !newString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // Avoid duplicates at the top
        if let first = items.first, first.content == newString {
            return
        }

        let newItem = ClipboardItem(content: newString)

        // Remove any older duplicate
        items.removeAll { $0.content == newString }

        // Insert at the front
        items.insert(newItem, at: 0)

        // Enforce maximum capacity
        if items.count > Self.maxItems {
            items = Array(items.prefix(Self.maxItems))
        }
    }

    /// Simulates a Cmd+V keystroke via CGEvent.
    private func simulateCmdV() {
        // Virtual key code for 'V' is 0x09
        let vKeyCode: CGKeyCode = 0x09

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
