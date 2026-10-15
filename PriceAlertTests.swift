import XCTest
@testable import VaultETH

final class PriceAlertTests: XCTestCase {
    func testPriceAlertProperties() {
        let alert = PriceAlertItem(
            id: "test_alert",
            symbol: "ETH",
            name: "Ethereum",
            targetPrice: 3000.0,
            condition: .above,
            createdPrice: 2500.0,
            createdAt: Date(),
            status: .active,
            note: "Target test",
            soundEnabled: true,
            colorHex: "#627EEA"
        )

        XCTAssertEqual(alert.accentHex, "#627EEA")
        XCTAssertTrue(alert.isEnabled)
    }

    func testPriceAlertConvenienceInit() {
        let alert = PriceAlertItem(
            id: "test_convenience",
            symbol: "BTC",
            name: "Bitcoin",
            targetPrice: 70000.0,
            condition: .below,
            createdPrice: 65000.0,
            status: .paused,
            note: "Dip buy",
            accentHex: "#F7931A"
        )

        XCTAssertEqual(alert.accentHex, "#F7931A")
        XCTAssertEqual(alert.colorHex, "#F7931A")
        XCTAssertFalse(alert.isEnabled)
    }

    func testIsEnabledToggling() {
        var alert = PriceAlertItem(
            id: "test_toggle",
            symbol: "SOL",
            name: "Solana",
            targetPrice: 200.0,
            condition: .above,
            createdPrice: 150.0,
            status: .triggered,
            note: "ATH test",
            accentHex: "#14F195"
        )

        XCTAssertTrue(alert.isEnabled)
        alert.isEnabled = false
        XCTAssertEqual(alert.status, .paused)
        XCTAssertFalse(alert.isEnabled)
        alert.isEnabled = true
        XCTAssertEqual(alert.status, .active)
        XCTAssertTrue(alert.isEnabled)
    }

    @MainActor
    func testWalletStoreToggleAlert() {
        let store = WalletStore()
        guard let first = store.priceAlerts.first else {
            XCTFail("Expected default alerts")
            return
        }

        let initialStatus = first.status
        store.toggleAlert(id: first.id)
        let toggled = store.priceAlerts.first(where: { $0.id == first.id })!
        if initialStatus == .active {
            XCTAssertEqual(toggled.status, .paused)
            XCTAssertFalse(toggled.isEnabled)
        } else if initialStatus == .triggered {
            XCTAssertEqual(toggled.status, .active)
            XCTAssertTrue(toggled.isEnabled)
        }

        // Toggle back
        store.toggleAlert(id: first.id)
        let toggledAgain = store.priceAlerts.first(where: { $0.id == first.id })!
        XCTAssertEqual(toggledAgain.status, .active)
        XCTAssertTrue(toggledAgain.isEnabled)
    }
}
