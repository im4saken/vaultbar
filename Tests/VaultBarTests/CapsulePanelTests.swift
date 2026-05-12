import AppKit
import XCTest
@testable import VaultBar

@MainActor
final class CapsulePanelTests: XCTestCase {
    func testCapsulePanelUsesNonActivatingConfiguration() {
        let panel = CapsulePanel(contentRect: NSRect(x: 0, y: 0, width: 454, height: 232))

        XCTAssertTrue(panel.styleMask.contains(.borderless))
        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertEqual(panel.level, .floating)
        XCTAssertTrue(panel.hidesOnDeactivate)
        XCTAssertTrue(panel.isMovableByWindowBackground)
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.transient))
    }

    func testResignKeyInvokesDismissCallback() {
        let panel = CapsulePanel(contentRect: NSRect(x: 0, y: 0, width: 454, height: 232))
        var didResign = false

        panel.onResignKey = {
            didResign = true
        }

        panel.resignKey()

        XCTAssertTrue(didResign)
    }

    func testSettingsPanelRemainsVisibleOnDeactivate() {
        let panel = SettingsPanel(contentRect: NSRect(x: 0, y: 0, width: 520, height: 420))

        XCTAssertFalse(panel.hidesOnDeactivate)
    }
}
