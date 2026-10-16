import XCTest

/// Captures App Store screenshots from the real app on CI (GitHub Actions macOS runner).
/// Screenshots are written as `vaulteth-shot-*.png` into the runner process's temp
/// directory, which the workflow copies out of the simulator container and uploads
/// as an artifact.
final class VaultETHUITests: XCTestCase {

    private func snap(_ name: String) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("vaulteth-shot-\(name).png")
        do {
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        } catch {
            XCTFail("Could not write screenshot \(name): \(error)")
        }
    }

    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--vaulteth-demo-vault"]
        app.launch()

        // Wait for the demo vault to import and the dashboard tab bar to appear.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 45), "Dashboard did not appear after demo vault import")

        sleep(6) // let balances settle
        snap("01-vault-home")

        tabBar.buttons["Wallets"].tap()
        sleep(2)
        snap("02-wallets")

        tabBar.buttons["Activity"].tap()
        sleep(2)
        snap("03-activity")

        tabBar.buttons["Settings"].tap()
        sleep(2)
        snap("04-settings")
    }
}
