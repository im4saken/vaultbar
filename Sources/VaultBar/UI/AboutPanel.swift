import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: statusBarIcon())
                .resizable()
                .frame(width: 64, height: 64)

            VStack(spacing: 4) {
                Text("VaultBar")
                    .font(.title2.weight(.semibold))

                if !version.isEmpty {
                    Text("Version \(version)\(buildNumber.isEmpty ? "" : " (\(buildNumber))")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("菜单栏 API Key 管理器")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("本地加密存储 API Keys / Tokens")
                    .font(.caption)
                Text("macOS 原生 Touch ID 解锁 · 模糊搜索 · 一键复制")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.secondary)
                    Text("本地加密存储")
                        .font(.caption)
                }

                HStack(spacing: 16) {
                    Image(systemName: "faceid")
                        .foregroundStyle(.secondary)
                    Text("Touch ID 解锁")
                        .font(.caption)
                }

                HStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    Text("模糊搜索")
                        .font(.caption)
                }

                HStack(spacing: 16) {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(.secondary)
                    Text("一键复制")
                        .font(.caption)
                }
            }

            Divider()

            VStack(spacing: 6) {
                Link("GitHub", destination: URL(string: "https://github.com/im4saken/vaultbar")!)
                    .font(.caption)

                Text("Copyright © 2026 VaultBar contributors")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Built with SwiftUI · Swift Package Manager")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.7))
            }
        }
        .padding(24)
    }

    private func statusBarIcon() -> NSImage {
        if let url = Bundle.main.url(forResource: "AppIconMenu", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 64, height: 64)
            return image
        }

        let icon = NSImage(systemSymbolName: "key.horizontal", accessibilityDescription: "VaultBar") ?? NSImage()
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }
}

final class AboutPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 460),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = true
        backgroundColor = .windowBackgroundColor
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        title = "关于 VaultBar"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.zoomButton)?.isHidden = true
        standardWindowButton(.closeButton)?.isHidden = false
        setContentSize(NSSize(width: 320, height: 460))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false

        let view = AboutView()
        contentViewController = NSHostingController(rootView: view)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

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

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        centerOnActiveScreen()
        makeKeyAndOrderFront(nil)
    }
}
