import AppKit

// MARK: - Floating Panel

/// A borderless, floating NSPanel that appears at the cursor location.
/// Used as the clipboard history popup window.
final class FloatingPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Panel behavior configuration
        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Hide standard window buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // Allow the panel to become key without activating the owning app
        isMovableByWindowBackground = false
        hidesOnDeactivate = true

        // Visual effect
        hasShadow = true

        // Animate
        animationBehavior = .utilityWindow

        // Respond to Escape to close
        isReleasedWhenClosed = false
    }

    // Allow the panel to become the key window so it receives keyboard input
    override var canBecomeKey: Bool { true }

    // Close on Escape key
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
