import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let repository = KeyRepository()
    private var statusItem: NSStatusItem?
    private var capsuleWindow: CapsulePanel?
    private var settingsWindow: SettingsPanel?
    private lazy var statusMenu: NSMenu = makeStatusMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        repository.load()
        configureStatusItem()
        configureCapsuleWindow()
        configureSettingsWindow()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettingsRequested),
            name: .vaultBarOpenSettings,
            object: nil
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func toggleCapsule() {
        guard let capsuleWindow else { return }
        if capsuleWindow.isVisible {
            capsuleWindow.orderOut(nil)
        } else {
            showCapsule()
        }
    }

    func showAddKey() {
        showCapsule()
        capsuleWindow?.openAddKey()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = statusBarIcon()
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
    }

    private func configureCapsuleWindow() {
        let panel = CapsulePanel(contentRect: NSRect(x: 0, y: 0, width: 454, height: 232))
        let view = CapsuleSearchView(
            repository: repository,
            onWindowResign: { [weak panel] in
                panel?.orderOut(nil)
            }
        )
        let hostingController = NSHostingController(rootView: view)
        panel.contentViewController = hostingController
        panel.onCommandN = { [weak self] in self?.showAddKey() }
        panel.onEscape = { [weak panel] in panel?.orderOut(nil) }
        panel.onEnter = { [weak self, weak panel] in
            if self?.repository.copySelectedOrTopResult() == true {
                panel?.orderOut(nil)
            }
        }
        panel.onArrowDown = { [weak self] in self?.repository.moveSelection(delta: 1) }
        panel.onArrowUp = { [weak self] in self?.repository.moveSelection(delta: -1) }
        panel.onResignKey = { [weak self] in
            self?.repository.searchText = ""
        }
        capsuleWindow = panel
    }

    private func showCapsule() {
        guard let capsuleWindow else { return }
        repository.resetSelectionToTop()
        capsuleWindow.positionBelowMenuBar(anchorWindow: statusItem?.button?.window)
        capsuleWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else {
            toggleCapsule()
            return
        }

        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            toggleCapsule()
        }
    }

    @objc private func settingsClicked() {
        showSettings()
    }

    @objc private func quitClicked() {
        NSApp.terminate(nil)
    }

    private func showStatusMenu() {
        guard let button = statusItem?.button else { return }
        statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(settingsClicked), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 app", action: #selector(quitClicked), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    private func statusBarIcon() -> NSImage? {
        let image = Bundle.main.url(forResource: "AppIconMenu", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "key.horizontal", accessibilityDescription: "VaultBar")
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false
        return image
    }

    private func configureSettingsWindow() {
        let panel = SettingsPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420))
        let view = SettingsView(repository: repository) { [weak panel] in
            panel?.orderOut(nil)
        }
        panel.contentViewController = NSHostingController(rootView: view)
        panel.setContentSize(NSSize(width: 520, height: 420))
        settingsWindow = panel
    }

    private func showSettings() {
        guard let settingsWindow else { return }
        if !settingsWindow.isVisible {
            settingsWindow.centerOnActiveScreen()
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    @objc private func openSettingsRequested() {
        showSettings()
    }
}
