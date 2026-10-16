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

    private func postMultipart(to url: URL, fileField: String, fileName: String, data: Data) -> (Int, String)? {
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
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        append("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("VaultETH-CI/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = body

        let semaphore = DispatchSemaphore(value: 0)
        var status = 0
        var responseBody = ""
        URLSession.shared.dataTask(with: request) { data, response, _ in
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
            responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            semaphore.signal()
        }.resume()
        if semaphore.wait(timeout: .now() + 90) == .timedOut {
            return nil
        }
        return (status, responseBody)
    }

    private func upload(name: String, data: Data) -> String? {
        // Upload to a public temp file host so the shots are reachable without
        // authenticated backend access; the returned URL is printed into the CI
        // log (tagged SHOTURL) for collection afterwards. Litterbox keeps files
        // 72h; tmpfiles keeps them 60 minutes but serves as a fallback when the
        // primary host is rate-limiting or briefly down.
        let hosts: [(url: URL, field: String)] = [
            (URL(string: "https://litterbox.catbox.moe/resources/internals/api.php")!, "fileToUpload"),
            (URL(string: "https://tmpfiles.org/api/v1/upload")!, "file")
        ]
        for host in hosts {
            for _ in 0..<2 {
                guard let (status, body) = postMultipart(to: host.url, fileField: host.field, fileName: "\(name).jpg", data: data) else { break }
                if status != 200 { continue }
                let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.hasPrefix("https://") {
                    return text
                }
                if let dataRange = text.range(of: "\"url\":\"https://tmpfiles.org/"),
                   let lineEnd = text[text.index(after: dataRange.upperBound)...].firstIndex(of: "\"") {
                    // tmpfiles returns a page URL; direct download is /dl/
                    let page = String(text[dataRange.upperBound..<lineEnd])
                    let parts = page.split(separator: "/", omittingEmptySubsequences: true)
                    if parts.count >= 2 {
                        return "https://tmpfiles.org/dl/\(parts[0])/\(parts[1])"
                    }
                }
                sleep(3)
            }
        }
        return nil
    }

    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--vaulteth-demo-vault"]
        app.launch()

        // In CI mode the store seeds the demo account within moments of launch,
        // which dismisses the first-launch welcome overlay. Wait until the demo
        // account ("Main Vault") is visible, which proves the overlay is gone
        // and the tab bar is tappable.
        let demoAccountLabel = app.staticTexts["Main Vault"]
        XCTAssertTrue(demoAccountLabel.waitForExistence(timeout: 60), "Demo vault did not appear; welcome overlay may still be up")

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
