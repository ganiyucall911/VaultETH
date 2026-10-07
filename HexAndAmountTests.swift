import XCTest
@testable import VaultETH

final class HexTests: XCTestCase {
    func testParseAndFormat() {
        XCTAssertEqual(Data(vaultHex: "0x0f")?.vaultHex0x, "0x0f")
        XCTAssertEqual(Data(vaultHex: "0x1")?.vaultHex0x, "0x01")          // odd length is left-padded
        XCTAssertEqual(Data(vaultHex: "0xFF")?.vaultHex0x, "0xff")
        XCTAssertEqual(Data(vaultHex: "0x")?.count, 0)
        XCTAssertNil(Data(vaultHex: "0xzz"))
        XCTAssertNil(Data(vaultHex: "0x12g4"))
    }

    func testRpcQuantity() {
        XCTAssertEqual(Data([0x00]).rpcQuantity, "0x0")
        XCTAssertEqual(Data().rpcQuantity, "0x0")
        XCTAssertEqual(Data([0x00, 0x0f]).rpcQuantity, "0xf")
        XCTAssertEqual(Data([0x01, 0x00]).rpcQuantity, "0x100")
    }
}

final class ETHAmountTests: XCTestCase {
    func testWeiVectors() throws {
        XCTAssertEqual(try ETHAmount.wei(from: "1").vaultHexPlain, "0de0b6b3a7640000")
        XCTAssertEqual(try ETHAmount.wei(from: "0.5").vaultHexPlain, "06f05b59d3b20000")
        XCTAssertEqual(try ETHAmount.wei(from: ".5").vaultHexPlain, "06f05b59d3b20000")
        XCTAssertEqual(try ETHAmount.wei(from: " 0.000000000000000001 ").vaultHexPlain, "01")
        XCTAssertEqual(try ETHAmount.wei(from: "123.456789012345678").vaultHexPlain, "06b14e9f812f3668b0")
        XCTAssertEqual(try ETHAmount.wei(from: "1000000").vaultHexPlain, "d3c21bcecceda1000000")
    }

    func testRejectsInvalidAmounts() {
        for bad in ["", " ", "0", "0.0", "-1", "1e3", "abc", "1.2.3", ".", "1,5",
                    "0.0000000000000000001",                       // 19 decimals
                    String(repeating: "9", count: 80)] {           // exceeds uint256
            XCTAssertThrowsError(try ETHAmount.wei(from: bad), "should reject \(bad)")
        }
    }

    func testFormat() {
        XCTAssertEqual(ETHAmount.format(wei: Data()), "0")
        XCTAssertEqual(ETHAmount.format(wei: Data(vaultHex: "0de0b6b3a7640000")!), "1")
        XCTAssertEqual(ETHAmount.format(wei: Data(vaultHex: "06f05b59d3b20000")!), "0.5")
        XCTAssertEqual(ETHAmount.format(wei: Data([0x01])), "0.000000000000000001")
        XCTAssertEqual(ETHAmount.format(wei: Data(vaultHex: "06b14e9f812f3668b0")!), "123.456789012345678")
    }

    func testRoundTrip() throws {
        for s in ["0.1", "2.718281828459045", "42", "0.000000000000000123", "99999999.999999999999999999"] {
            XCTAssertEqual(ETHAmount.format(wei: try ETHAmount.wei(from: s)), s)
        }
    }
}

final class WeiMathTests: XCTestCase {
    func testAddMultiplyCompare() {
        let a = Data(vaultHex: "ffffffffffffffff")!                  // 2^64 - 1
        XCTAssertEqual(Wei.add(a, Data([1])).vaultHexPlain, "010000000000000000")
        XCTAssertEqual(Wei.multiply(Data([0x10]), Data([0x10])).vaultHexPlain, "0100")
        XCTAssertTrue(Wei.multiply(Data(), Data([5])).isEmpty)
        XCTAssertEqual(Wei.compare(Data([0, 0, 1]), Data([1])), .orderedSame)     // leading zeros ignored
        XCTAssertEqual(Wei.compare(Data([2]), Data([1, 0])), .orderedAscending)
        XCTAssertEqual(Wei.compare(Data([1, 0]), Data([2])), .orderedDescending)
    }

    func testMaxFeeMath() {
        // 21000 gas * 30 gwei = 630,000 gwei = 0.00063 ETH
        let fee = Wei.multiply(Wei.from(21_000), Wei.from(30_000_000_000))
        XCTAssertEqual(ETHAmount.format(wei: fee), "0.00063")
    }

    func testSubtract() {
        XCTAssertEqual(Wei.subtract(Data([10]), Data([3]))?.vaultHexPlain, "07")
        XCTAssertEqual(Wei.subtract(Data([5]), Data([5]))?.count, 0)
        XCTAssertNil(Wei.subtract(Data([3]), Data([5])))
        XCTAssertEqual(Wei.subtract(Data(vaultHex: "0100")!, Data([1]))?.vaultHexPlain, "ff")
        let a = Data(vaultHex: "010000000000000000")!
        XCTAssertEqual(Wei.subtract(a, Data([1]))?.vaultHexPlain, "ffffffffffffffff")
    }
}
