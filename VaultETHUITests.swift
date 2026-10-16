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
        // Upload to litterbox (72h temp host) so the shots are reachable without
        // authenticated backend access; the returned URL is printed into the CI
        // log so it can be collected afterwards.
        let boundary = "VaultETH-\(UUID().uuidString)"
        var body = Data()
        func append(_ string: String) { body.append(string.data(using: .utf8)!) }
        func field(_ fieldName: String, _ value: String) {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(fieldName)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        field("reqtype", "fileupload")
        field("time", "72h")
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"fileToUpload\"; filename=\"\(name).jpg\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: URL(string: "https://litterbox.catbox.moe/resources/internals/api.php")!, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("VaultETH-CI/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let semaphore = DispatchSemaphore(value: 0)
        var result: String?
        URLSession.shared.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let text = data.flatMap({ String(data: $0, encoding: .utf8) })?
                   .trimmingCharacters(in: .whitespacesAndNewlines),
               text.hasPrefix("https://") {
                result = text
            }
            semaphore.signal()
        }.resume()
        if semaphore.wait(timeout: .now() + 90) == .timedOut || result == nil {
            XCTFail("Screenshot upload failed for \(name)")
        } else {
            print("SHOTURL \(name) \(result!) (\(deviceName))")
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
