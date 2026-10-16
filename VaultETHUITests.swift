import XCTest
import UIKit

/// Captures App Store screenshots from the real app running on CI (GitHub Actions
/// macOS runner) and uploads them as JPEG to the VaultETH screenshot intake endpoint.
/// Each CI run refreshes the same screen names, keeping the captures current.
final class VaultETHUITests: XCTestCase {

    private let endpoint = URL(string: "https://superagent-e3b33393.base44.app/functions/captureAppScreenshot")!
    private let shotToken = "vaulteth-shots-2F8A1C"

    private var deviceName: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.model
    }

    private func upload(name: String, image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            XCTFail("Could not encode screenshot \(name)")
            return
        }
        var request = URLRequest(url: endpoint, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "name": name,
            "device": deviceName,
            "jpg_base64": data.base64EncodedString(),
            "token": shotToken
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let semaphore = DispatchSemaphore(value: 0)
        var ok = false
        URLSession.shared.dataTask(with: request) { _, response, _ in
            ok = (response as? HTTPURLResponse)?.statusCode == 200
            semaphore.signal()
        }.resume()
        if semaphore.wait(timeout: .now() + 45) == .timedOut || !ok {
            XCTFail("Screenshot upload failed for \(name)")
        }
    }

    private func snap(_ name: String) {
        guard let image = UIImage(data: XCUIScreen.main.screenshot().pngRepresentation) else {
            XCTFail("Could not decode screenshot \(name)")
            return
        }
        upload(name: name, image: image)
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
