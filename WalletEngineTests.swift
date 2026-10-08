import XCTest
@testable import VaultETH

final class WalletEngineTests: XCTestCase {
    // Well-known BIP-39 test mnemonic; first Ethereum address on m/44'/60'/0'/0/0.
    private let testMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    func testDerivesKnownAddress() {
        XCTAssertEqual(WalletEngine.address(forMnemonic: testMnemonic), "0x9858EfFD232B4033E47d90003D41EC34EcaEda94")
    }

    func testMnemonicNormalizationAndValidation() {
        XCTAssertEqual(WalletEngine.address(forMnemonic: "  ABANDON abandon\nabandon abandon abandon abandon abandon abandon abandon abandon abandon ABOUT "),
                       "0x9858EfFD232B4033E47d90003D41EC34EcaEda94")
        XCTAssertNil(WalletEngine.address(forMnemonic: "abandon abandon abandon"))
        XCTAssertNil(WalletEngine.address(forMnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon")) // bad checksum
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
        XCTAssertEqual(try WalletEngine.validateRecipient(checksummed.lowercased()), checksummed)  // all-lowercase accepted, canonicalised
        XCTAssertEqual(try WalletEngine.validateRecipient("  \(checksummed)\n"), checksummed)
        XCTAssertEqual(try WalletEngine.validateRecipient("ethereum:\(checksummed)"), checksummed)
        XCTAssertEqual(try WalletEngine.validateRecipient("ethereum:pay-\(checksummed)@1?value=1e18"), checksummed)

        XCTAssertThrowsError(try WalletEngine.validateRecipient("0x9D8A62f656a8d1615C1294fd71e9CFb3E4855A4F")) {   // one letter's case flipped
            XCTAssertEqual($0 as? WalletError, .invalidChecksum)
        }
        XCTAssertThrowsError(try WalletEngine.validateRecipient("0x1234")) { XCTAssertEqual($0 as? WalletError, .invalidAddress) }
        XCTAssertThrowsError(try WalletEngine.validateRecipient("9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F")) { XCTAssertEqual($0 as? WalletError, .invalidAddress) }
        XCTAssertThrowsError(try WalletEngine.validateRecipient("0xZZ8A62f656a8d1615C1294fd71e9CFb3E4855A4F")) { XCTAssertEqual($0 as? WalletError, .invalidAddress) }
        XCTAssertThrowsError(try WalletEngine.validateRecipient("0x0000000000000000000000000000000000000000")) { XCTAssertEqual($0 as? WalletError, .burnAddress) }
    }

    /// Expected bytes generated independently with Python eth-account (RFC 6979 deterministic signature).
    func testSignsKnownEIP1559Transfer() throws {
        let fee = FeeQuote(gasLimit: Data(vaultHex: "5208")!,
                           maxFeePerGas: Data(vaultHex: "06fc23ac00")!,          // 30 gwei
                           maxPriorityFeePerGas: Data(vaultHex: "77359400")!)    // 2 gwei
        let transfer = PreparedTransfer(from: "0x9d8A62f656a8d1615C1294fd71e9CFb3E4855A4F",
                                        to: "0x3535353535353535353535353535353535353535",
                                        valueWei: try ETHAmount.wei(from: "1"),
                                        nonce: Data([9]), chainID: Data([1]), fee: fee, recipientIsContract: false)
        let key = Data(vaultHex: "0x4646464646464646464646464646464646464646464646464646464646464646")!
        let raw = try WalletEngine.sign(transfer, privateKey: key)
        XCTAssertEqual(raw, "0x02f873010984773594008506fc23ac00825208943535353535353535353535353535353535353535880de0b6b3a764000080c080a02b03b67e070f45175ce9d07c4512720168bd468a24edb6997977a53d48c87a12a0733d775fdd689d306e08ac8ab399f34b5a0253b47ed81b8bf2d2a6ea607fcac7")
    }
}
