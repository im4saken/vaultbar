import AppKit
import XCTest
@testable import VaultBar

@MainActor
final class SettingsPanelHideTests: XCTestCase {
    func testOrderOutNotifiesSoRevealedSecretsGetMasked() {
        let panel = SettingsPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420))
        let expectation = XCTNSNotificationExpectation(name: .vaultBarSettingsHidden)

        panel.orderOut(nil)

        wait(for: [expectation], timeout: 1)
    }

    func testCloseAlsoNotifies() {
        let panel = SettingsPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420))
        let expectation = XCTNSNotificationExpectation(name: .vaultBarSettingsHidden)

        panel.close()

        wait(for: [expectation], timeout: 1)
    }
}
