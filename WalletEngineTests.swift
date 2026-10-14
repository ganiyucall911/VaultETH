import XCTest
@testable import VaultETH

final class WalletEngineTests: XCTestCase {
    private let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    func testDerivesKnownAddress() {
        XCTAssertEqual(WalletEngine.address(forMnemonic: testMnemonic), "0x9858EfFD232B4033E47d90003D41EC34EcaEda94")
    }

    func testMnemonicNormalizationAndValidation() {
        XCTAssertEqual(WalletEngine.address(forMnemonic: "  ABANDON abandon\nabandon abandon abandon abandon abandon abandon abandon abandon abandon ABOUT "),
                       "0x9858EfFD232B4033E47d90003D41EC34EcaEda94")
        XCTAssertNil(WalletEngine.address(forMnemonic: "abandon abandon abandon"))
        XCTAssertNil(WalletEngine.address(forMnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"))
    }

    func testRPCEndpointValidation() {
        XCTAssertTrue(EthereumRPC.isSecureEndpoint("https://ethereum-rpc.publicnode.com"))
        XCTAssertTrue(EthereumRPC.isSecureEndpoint("http://localhost:8545"))
        XCTAssertFalse(EthereumRPC.isSecureEndpoint("http://example.com"))
        XCTAssertFalse(EthereumRPC.isSecureEndpoint("ftp://example.com"))
        XCTAssertFalse(EthereumRPC.isSecureEndpoint("not-a-url"))
    }

    func testParsePaymentURI() {
        let uri1 = WalletEngine.parsePaymentURI("ethereum:0x9858EfFD232B4033E47d90003D41EC34EcaEda94?value=1000000000000000000")
        XCTAssertEqual(uri1.recipient, "0x9858EfFD232B4033E47d90003D41EC34EcaEda94")
        XCTAssertEqual(uri1.amountETH, "1")

        let uri2 = WalletEngine.parsePaymentURI("ethereum:pay-0x9858EfFD232B4033E47d90003D41EC34EcaEda94@1?value=500000000000000000")
        XCTAssertEqual(uri2.recipient, "0x9858EfFD232B4033E47d90003D41EC34EcaEda94")
        XCTAssertEqual(uri2.amountETH, "0.5")

        let uri3 = WalletEngine.parsePaymentURI("ethereum:vitalik.eth?amount=2.5")
        XCTAssertEqual(uri3.recipient, "vitalik.eth")
        XCTAssertEqual(uri3.amountETH, "2.5")

        let uri4 = WalletEngine.parsePaymentURI("ethereum:0x1234?value=1.5e18")
        XCTAssertEqual(uri4.recipient, "0x1234")
        XCTAssertEqual(uri4.amountETH, "1.5")

        let uri5 = WalletEngine.parsePaymentURI("0x9858EfFD232B4033E47d90003D41EC34EcaEda94")
        XCTAssertEqual(uri5.recipient, "0x9858EfFD232B4033E47d90003D41EC34EcaEda94")
        XCTAssertNil(uri5.amountETH)
    }

    func testRecipientValidation() throws {
        let checksummed = "0x9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F"
        XCTAssertEqual(try WalletEngine.validateRecipient(checksummed), checksummed)
        XCTAssertEqual(try WalletEngine.validateRecipient(checksummed.lowercased()), checksummed)
        XCTAssertEqual(try WalletEngine.validateRecipient("  \(checksummed)\n"), checksummed)
        XCTAssertEqual(try WalletEngine.validateRecipient("ethereum:\(checksummed)"), checksummed)
        XCTAssertEqual(try WalletEngine.validateRecipient("ethereum:pay-\(checksummed)@1?value=1e18"), checksummed)

        XCTAssertThrowsError(try WalletEngine.validateRecipient("0x9D8A62f656a8d1615C1294fd71e9CFb3E4855A4F")) {
            XCTAssertEqual($0 as? WalletError, .invalidChecksum)
        }
        XCTAssertThrowsError(try WalletEngine.validateRecipient("0x1234")) { XCTAssertEqual($0 as? WalletError, .invalidAddress) }
        XCTAssertThrowsError(try WalletEngine.validateRecipient("9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F")) { XCTAssertEqual($0 as? WalletError, .invalidAddress) }
        XCTAssertThrowsError(try WalletEngine.validateRecipient("0xZZ8A62f656a8d1615C1294fd71e9CFb3E4855A4F")) { XCTAssertEqual($0 as? WalletError, .invalidAddress) }
        XCTAssertThrowsError(try WalletEngine.validateRecipient("0x0000000000000000000000000000000000000000")) { XCTAssertEqual($0 as? WalletError, .burnAddress) }
    }

    func testSignsKnownEIP1559Transfer() throws {
        let fee = FeeQuote(gasLimit: Data(vaultHex: "5208")!,
                           maxFeePerGas: Data(vaultHex: "06fc23ac00")!,
                           maxPriorityFeePerGas: Data(vaultHex: "77359400")!)
        let transfer = PreparedTransfer(from: "0x9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F",
                                       to: "0x3535353535353535353535353535353535353535",
                                       valueWei: try ETHAmount.wei(from: "1"),
                                       nonce: Data([9]), chainID: Data([1]), fee: fee, recipientIsContract: false)
        let key = Data(vaultHex: "0x4646464646464646464646464646464646464646464646464646464646464646")!
        let raw = try WalletEngine.sign(transfer, privateKey: key)
        XCTAssertTrue(raw.hasPrefix("0x"))
        XCTAssertGreaterThan(raw.count, 100)
    }

    func testMaximumOutlayIncludesOnlySignedValueAndNetworkFee() throws {
        let fee = FeeQuote(gasLimit: Data(vaultHex: "5208")!,
                           maxFeePerGas: Data(vaultHex: "06fc23ac00")!,
                           maxPriorityFeePerGas: Data(vaultHex: "77359400")!)
        let value = try ETHAmount.wei(from: "1")
        let transfer = PreparedTransfer(from: "0x9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F",
                                        to: "0x3535353535353535353535353535353535353535",
                                        valueWei: value,
                                        nonce: Data([9]),
                                        chainID: Data([1]),
                                        fee: fee,
                                        recipientIsContract: false)

        XCTAssertEqual(transfer.maxTotalWei, Wei.add(value, fee.maxFeeWei))
    }
}
