import SwiftUI

// MARK: - Onboarding View

/// Shown when Accessibility permissions have not yet been granted.
struct OnboardingView: View {

    @ObservedObject var accessibilityManager: AccessibilityManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)

            // Title
            VStack(spacing: 6) {
                Text("Accessibility Access Required")
                    .font(.system(size: 18, weight: .semibold))

                Text("Clipboard Panel OS needs Accessibility permissions to work properly.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Steps
            VStack(alignment: .leading, spacing: 12) {
                stepRow(number: 1, text: "Open System Settings")
                stepRow(number: 2, text: "Go to Privacy & Security → Accessibility")
                stepRow(number: 3, text: "Find \"Clipboard Panel OS\" and toggle it ON")
                stepRow(number: 4, text: "You may need to unlock settings with your password")
            }
            .padding(.horizontal, 20)

            // Action buttons
            VStack(spacing: 10) {
                Button(action: {
                    accessibilityManager.requestAccessibility()
                }) {
                    Text("Grant Accessibility Access")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)

                Button("Open System Settings Manually") {
                    accessibilityManager.openAccessibilitySettings()
                }
                .controlSize(.small)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            Spacer()

            // Status indicator
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for permission…")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .padding(.bottom, 16)
        }
        .frame(width: 380, height: 420)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .padding(.top, 2)
        }
    }
}
