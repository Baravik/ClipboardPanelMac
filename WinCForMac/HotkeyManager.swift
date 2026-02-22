import AppKit
import Carbon.HIToolbox
import Combine

// MARK: - Recorded Shortcut

/// Represents a user-configured keyboard shortcut, persistable via UserDefaults.
struct RecordedShortcut: Codable, Equatable {
    let keyCode: UInt16
    let modifierFlags: UInt  // Raw value of NSEvent.ModifierFlags

    /// Human-readable display string (e.g. "⌘⇧V").
    var displayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifierFlags))
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        let keyName = Self.keyCodeToString(keyCode)
        parts.append(keyName)
        return parts.joined()
    }

    /// Converts a virtual key code to a readable string.
    static func keyCodeToString(_ keyCode: UInt16) -> String {
        let knownKeys: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H",
            0x05: "G", 0x06: "Z", 0x07: "X", 0x08: "C", 0x09: "V",
            0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R",
            0x10: "Y", 0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3",
            0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=", 0x19: "9",
            0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]",
            0x1F: "O", 0x20: "U", 0x21: "[", 0x22: "I", 0x23: "P",
            0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M",
            0x2F: ".", 0x30: "Tab", 0x31: "Space", 0x33: "Delete",
            0x35: "Esc", 0x24: "Return",
            0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4",
            0x60: "F5", 0x61: "F6", 0x62: "F7", 0x64: "F8",
            0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        ]
        return knownKeys[keyCode] ?? "Key\(keyCode)"
    }

    /// Validates that the shortcut won't conflict with common system shortcuts.
    /// Requires at least two modifier keys, or a non-Command modifier.
    var isValid: Bool {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(modifierFlags))
        let hasCommand = flags.contains(.command)
        let hasShift   = flags.contains(.shift)
        let hasControl = flags.contains(.control)
        let hasOption  = flags.contains(.option)

        var modCount = 0
        if hasCommand { modCount += 1 }
        if hasShift   { modCount += 1 }
        if hasControl { modCount += 1 }
        if hasOption  { modCount += 1 }

        // Must have at least one modifier
        guard modCount >= 1 else { return false }

        // Cmd-alone + key is too likely to conflict with system shortcuts
        if modCount == 1 && hasCommand { return false }

        return true
    }
}

// MARK: - Hotkey Manager

/// Manages a global keyboard shortcut that triggers the clipboard panel.
final class HotkeyManager: ObservableObject {

    // MARK: - UserDefaults Key

    private static let shortcutKey = "com.wincformac.globalShortcut.v2"

    // The modifier keys we care about for matching — ignores capsLock, numericPad, function, etc.
    private static let significantModifiers: NSEvent.ModifierFlags = [.command, .shift, .control, .option]

    // MARK: - Published State

    @Published var currentShortcut: RecordedShortcut?
    @Published var isRecording: Bool = false

    // MARK: - Callbacks

    var onHotkeyPressed: (() -> Void)?

    // MARK: - Private

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var recordingMonitor: Any?

    // MARK: - Init

    init() {
        loadShortcut()
    }

    deinit {
        unregisterAll()
    }

    // MARK: - Shortcut Persistence

    func saveShortcut(_ shortcut: RecordedShortcut) {
        currentShortcut = shortcut
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: Self.shortcutKey)
        }
        registerGlobalHotkey()
    }

    func clearShortcut() {
        unregisterAll()
        currentShortcut = nil
        UserDefaults.standard.removeObject(forKey: Self.shortcutKey)
    }

    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: Self.shortcutKey),
           let shortcut = try? JSONDecoder().decode(RecordedShortcut.self, from: data),
           shortcut.isValid {
            currentShortcut = shortcut
            registerGlobalHotkey()
            return
        }

        // Default: Cmd+Shift+V — build flags from the set, not from raw value OR
        let defaultFlags = NSEvent.ModifierFlags([.command, .shift])
        let defaultShortcut = RecordedShortcut(
            keyCode: 0x09, // V
            modifierFlags: UInt(defaultFlags.rawValue)
        )
        saveShortcut(defaultShortcut)
    }

    // MARK: - Recording

    /// Starts listening for a new shortcut key combination.
    func startRecording() {
        isRecording = true
        unregisterAll()

        // Monitor local events (when app is focused) for recording
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedEvent(event)
            return nil // Swallow the event during recording
        }

        // Also monitor global events for recording
        recordingMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleRecordedEvent(event)
        }
    }

    /// Cancels recording without saving.
    func cancelRecording() {
        isRecording = false
        removeRecordingMonitors()
        if currentShortcut != nil {
            registerGlobalHotkey()
        }
    }

    private func handleRecordedEvent(_ event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == 0x35 {
            cancelRecording()
            return
        }

        let cleanFlags = event.modifierFlags.intersection(Self.significantModifiers)

        // Require at least one modifier (Cmd, Ctrl, Option) — prevents bare keys
        let requiredModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        guard !cleanFlags.intersection(requiredModifiers).isEmpty else { return }

        // Require at least two modifiers OR (Ctrl/Option + key) to avoid clashing with system shortcuts
        let modCount = Self.countModifiers(cleanFlags)
        let hasOnlyCommand = cleanFlags == .command
        if modCount < 2 && hasOnlyCommand {
            // Reject Cmd+<key> without additional modifiers — too likely to conflict
            return
        }

        let shortcut = RecordedShortcut(
            keyCode: event.keyCode,
            modifierFlags: UInt(cleanFlags.rawValue)
        )

        isRecording = false
        removeRecordingMonitors()
        saveShortcut(shortcut)
    }

    private static func countModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var count = 0
        if flags.contains(.command) { count += 1 }
        if flags.contains(.shift)   { count += 1 }
        if flags.contains(.control) { count += 1 }
        if flags.contains(.option)  { count += 1 }
        return count
    }

    private func removeRecordingMonitors() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
    }

    // MARK: - Global Hotkey Registration

    private func registerGlobalHotkey() {
        unregisterAll()

        guard let shortcut = currentShortcut else { return }

        // Only compare the four meaningful modifier keys
        let targetFlags = NSEvent.ModifierFlags(rawValue: shortcut.modifierFlags)
            .intersection(Self.significantModifiers)

        // Global monitor — fires when app is NOT focused
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventFlags = event.modifierFlags.intersection(Self.significantModifiers)
            if event.keyCode == shortcut.keyCode && eventFlags == targetFlags {
                DispatchQueue.main.async {
                    self?.onHotkeyPressed?()
                }
            }
        }

        // Local monitor — fires when app IS focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let eventFlags = event.modifierFlags.intersection(Self.significantModifiers)
            if event.keyCode == shortcut.keyCode && eventFlags == targetFlags {
                DispatchQueue.main.async {
                    self?.onHotkeyPressed?()
                }
                return nil // Swallow the event
            }
            return event
        }
    }

    private func unregisterAll() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        removeRecordingMonitors()
    }
}
