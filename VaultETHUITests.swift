import XCTest
import UIKit
import CryptoKit

/// Captures App Store screenshots from the real app running on CI (GitHub Actions
/// macOS runner) and uploads them as JPEG to a temp file host (72h retention),
/// printing the returned URLs into the CI log tagged SHOTURL for collection.
final class VaultETHUITests: XCTestCase {

    private var deviceName: String {
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.model
    }

    private func upload(name: String, data: Data) -> String? {
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
        if semaphore.wait(timeout: .now() + 90) == .timedOut {
            return nil
        }
        return result
    }

    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--vaulteth-demo-vault"]
        app.launch()

        // The demo vault imports asynchronously while the first-launch welcome
        // overlay covers the UI, and the tab bar is still visible in the
        // hierarchy underneath it. Wait for the tab bar to actually become
        // hittable, which only happens once the overlay is gone.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 30), "Tab bar did not appear")
        let hittable = NSPredicate(format: "isHittable == true")
        expectation(for: hittable, evaluatedWith: tabBar)
        waitForExpectations(timeout: 120, handler: nil)

        var lastDigest = ""

        func snap(_ name: String) {
            guard let image = UIImage(data: XCUIScreen.main.screenshot().pngRepresentation),
                  let data = image.jpegData(compressionQuality: 0.92) else {
                XCTFail("Could not encode screenshot \(name)")
                return
            }
            let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            if digest == lastDigest {
                print("SHOTDUP \(name) — screen did not change after the last tap")
                print("SHOTHIERARCHY-BEGIN")
                print(app.debugDescription)
                print("SHOTHIERARCHY-END")
                XCTFail("Screen did not change after tapping to \(name)")
            }
            lastDigest = digest

            if let url = upload(name: name, data: data) {
                print("SHOTURL \(name) \(url) (\(deviceName))")
            } else {
                XCTFail("Screenshot upload failed for \(name)")
            }
        }

        sleep(6) // let balances settle
        snap("01-vault-home")

        let tabs: [(String, String)] = [
            ("Wallets", "02-wallets"),
            ("Activity", "03-activity"),
            ("Settings", "04-settings")
        ]
        for (tabName, shotName) in tabs {
            let button = app.tabBars.firstMatch.buttons[tabName]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "Missing tab \(tabName)")
            button.tap()
            sleep(2)
            snap(shotName)
        }
    }
}
