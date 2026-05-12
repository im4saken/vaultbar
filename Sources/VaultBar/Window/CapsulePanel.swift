import AppKit

final class CapsulePanel: NSPanel {
    var onCommandN: (() -> Void)?
    var onEscape: (() -> Void)?
    var onEnter: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onArrowUp: (() -> Void)?
    var onResignKey: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = true
        isMovableByWindowBackground = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func positionBelowMenuBar(anchorWindow: NSWindow?) {
        let screen = anchorWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }

        let anchorMidX = anchorWindow?.frame.midX ?? visibleFrame.midX
        let x = min(max(anchorMidX - frame.width / 2, visibleFrame.minX + 10), visibleFrame.maxX - frame.width - 10)
        let y = visibleFrame.maxY - frame.height - 6
        let origin = NSPoint(x: x, y: y)
        setFrameOrigin(origin)
    }

    func openAddKey() {
        NotificationCenter.default.post(name: .vaultBarOpenAddKey, object: nil)
    }

    func openSettings() {
        NotificationCenter.default.post(name: .vaultBarOpenSettings, object: nil)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36:
            onEnter?()
        case 53:
            onEscape?()
        case 125:
            onArrowDown?()
        case 126:
            onArrowUp?()
        default:
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "n" {
            onCommandN?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown {
            switch event.keyCode {
            case 125:
                onArrowDown?()
                return
            case 126:
                onArrowUp?()
                return
            default:
                break
            }
        }
        super.sendEvent(event)
    }

    override func resignKey() {
        onResignKey?()
        super.resignKey()
    }
}
