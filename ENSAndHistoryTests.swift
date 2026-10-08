import XCTest
@testable import VaultETH

final class ENSAndHistoryTests: XCTestCase {

    func testLooksLikeENS() {
        XCTAssertTrue(ENSResolver.looksLikeENS("vitalik.eth"))
        XCTAssertTrue(ENSResolver.looksLikeENS("foo.bar.eth"))
        XCTAssertTrue(ENSResolver.looksLikeENS("a.eth"))
        XCTAssertTrue(ENSResolver.looksLikeENS("test.xyz"))
        XCTAssertTrue(ENSResolver.looksLikeENS("ethereum:vitalik.eth"))
        XCTAssertTrue(ENSResolver.looksLikeENS("ethereum:pay-vitalik.eth@1?value=1000000000000000000"))

        XCTAssertFalse(ENSResolver.looksLikeENS(""))
        XCTAssertFalse(ENSResolver.looksLikeENS("   "))
        XCTAssertFalse(ENSResolver.looksLikeENS("0x9858EfFD232B4033E47d90003D41EC34EcaEda94"))
        XCTAssertFalse(ENSResolver.looksLikeENS("ethereum:0x9858EfFD232B4033E47d90003D41EC34EcaEda94"))
        XCTAssertFalse(ENSResolver.looksLikeENS("notanensname"))
        XCTAssertFalse(ENSResolver.looksLikeENS("foo.123"))
    }

    func testDecodeABIString() {
        // ABI encoding for "vitalik.eth" (11 chars)
        // Word 0 (offset): 32 bytes (0x20)
        // Word 1 (length): 32 bytes (11 = 0x0b)
        // Word 2: "vitalik.eth" padded with zeros to 32 bytes
        let word0 = String(repeating: "0", count: 62) + "20"
        let word1 = String(repeating: "0", count: 62) + "0b"
        let content = "vitalik.eth".data(using: .utf8)!.map { String(format: "%02x", $0) }.joined()
        let padding = String(repeating: "0", count: 64 - content.count)
        let hex = "0x" + word0 + word1 + content + padding

        let decoded = ENSResolver.decodeABIString(hex)
        XCTAssertEqual(decoded, "vitalik.eth")

        // Malformed inputs
        XCTAssertNil(ENSResolver.decodeABIString("0x"))
        XCTAssertNil(ENSResolver.decodeABIString("0x1234"))
        XCTAssertNil(ENSResolver.decodeABIString(""))
    }

    func testNamehashEmptyString() {
        // EIP-137: namehash("") is 32 zero bytes
        let emptyHash = ENSResolver.namehash("")
        XCTAssertEqual(emptyHash.count, 32)
        XCTAssertTrue(emptyHash.allSatisfy { $0 == 0 })
    }

    func testSentTransactionCodable() throws {
        let tx = SentTransaction(
            id: UUID(),
            walletAddress: "0x9858EfFD232B4033E47d90003D41EC34EcaEda94",
            toAddress: "0x3535353535353535353535353535353535353535",
            toENSName: "vitalik.eth",
            amountETH: "1.5",
            hash: "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            date: Date(timeIntervalSince1970: 1700000000),
            status: .pending
        )

        let data = try JSONEncoder().encode(tx)
        let decoded = try JSONDecoder().decode(SentTransaction.self, from: data)

        XCTAssertEqual(decoded.id, tx.id)
        XCTAssertEqual(decoded.walletAddress, tx.walletAddress)
        XCTAssertEqual(decoded.toAddress, tx.toAddress)
        XCTAssertEqual(decoded.toENSName, "vitalik.eth")
        XCTAssertEqual(decoded.amountETH, "1.5")
        XCTAssertEqual(decoded.hash, tx.hash)
        XCTAssertEqual(decoded.status, .pending)
    }

    func testBlockchainNetworkDefaults() {
        let networks = BlockchainNetwork.defaultNetworks
        XCTAssertTrue(networks.contains(where: { $0.id == "ethereum" && $0.chainID == 1 }))
        XCTAssertTrue(networks.contains(where: { $0.id == "arbitrum" && $0.chainID == 42161 }))
        XCTAssertTrue(networks.contains(where: { $0.id == "base" && $0.chainID == 8453 }))
        XCTAssertTrue(networks.contains(where: { $0.id == "polygon" && $0.chainID == 137 }))
        XCTAssertTrue(networks.contains(where: { $0.id == "bsc" && $0.chainID == 56 }))
        XCTAssertTrue(networks.contains(where: { $0.id == "avalanche" && $0.chainID == 43114 }))

        // Chain ID data serialization check
        XCTAssertEqual(BlockchainNetwork.ethereum.chainIDData, Data([1]))
    }
}
