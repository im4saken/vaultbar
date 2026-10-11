import AppKit

final class SettingsPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = false
        level = .normal
        isOpaque = true
        backgroundColor = .windowBackgroundColor
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        title = "设置"
        titleVisibility = .visible
        titlebarAppearsTransparent = false
        standardWindowButton(.zoomButton)?.isHidden = true
        setContentSize(contentRect.size)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func close() {
        orderOut(nil)
    }

    /// Every way of hiding this window (close button, Done button, Cmd+W) ends up here,
    /// so views can re-mask any revealed API key.
    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        NotificationCenter.default.post(name: .vaultBarSettingsHidden, object: nil)
    }

    func centerOnActiveScreen() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }
        setFrameOrigin(
            NSPoint(
                x: visibleFrame.midX - frame.width / 2,
                y: visibleFrame.midY - frame.height / 2
            )
        )
    }
}
