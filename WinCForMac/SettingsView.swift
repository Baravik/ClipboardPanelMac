import SwiftUI

// MARK: - Settings View

/// Settings panel for configuring the global hotkey and other preferences.
struct SettingsView: View {

    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var accessibilityManager: AccessibilityManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Hotkey Section
                    hotkeySection

                    Divider()

                    // Accessibility Section
                    accessibilitySection

                    Divider()

                    // About Section
                    aboutSection
                }
                .padding(20)
            }
        }
        .frame(width: 360, height: 440)
    }

    // MARK: - Hotkey Section

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Global Shortcut", systemImage: "keyboard")
                .font(.system(size: 13, weight: .semibold))

            Text("Press this shortcut anywhere to open the clipboard history.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack {
                // Current shortcut display / recording button
                shortcutButton

                Spacer()

                if hotkeyManager.currentShortcut != nil && !hotkeyManager.isRecording {
                    Button("Reset") {
                        hotkeyManager.clearShortcut()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private var shortcutButton: some View {
        Button(action: {
            if hotkeyManager.isRecording {
                hotkeyManager.cancelRecording()
            } else {
                hotkeyManager.startRecording()
            }
        }) {
            HStack(spacing: 8) {
                if hotkeyManager.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Press a key combo…")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                } else if let shortcut = hotkeyManager.currentShortcut {
                    Text(shortcut.displayString)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Text("Click to record")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minWidth: 160)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hotkeyManager.isRecording ? Color.red.opacity(0.1) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(hotkeyManager.isRecording ? Color.red.opacity(0.5) : Color.primary.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Accessibility Section

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Accessibility", systemImage: "lock.shield")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 10) {
                Circle()
                    .fill(accessibilityManager.isAccessibilityGranted ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)

                Text(accessibilityManager.isAccessibilityGranted
                     ? "Accessibility permission granted"
                     : "Accessibility permission required")
                    .font(.system(size: 12))
                    .foregroundColor(accessibilityManager.isAccessibilityGranted ? .secondary : .primary)
            }

            if !accessibilityManager.isAccessibilityGranted {
                Text("Clipboard Panel OS needs Accessibility access to simulate paste keystrokes and detect global shortcuts.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Open Accessibility Settings") {
                    accessibilityManager.openAccessibilitySettings()
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("About", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("Clipboard Panel OS")
                    .font(.system(size: 12, weight: .medium))
                Text("Clipboard History Manager")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Keeps the last 50 clipboard items in memory.\nHistory is cleared when the app quits.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
