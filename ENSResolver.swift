import Foundation
import WalletCore

/// Resolves ENS names (e.g. "vitalik.eth") to EIP-55 checksummed Ethereum addresses
/// using the canonical on-chain ENS registry deployed on Ethereum Mainnet.
///
/// Resolution is read-only: two `eth_call` RPC calls, no signing, no keys.
enum ENSResolver {
    /// The ENS Registry contract — fixed on Ethereum Mainnet.
    private static let registryAddress = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e"

    // MARK: - Public API

    /// Returns `true` when the trimmed string looks like an ENS name the app should
    /// attempt to resolve (has a dot, no 0x prefix, letters-only TLD).
    static func looksLikeENS(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.hasPrefix("0x"), s.contains("."), s.count >= 7 else { return false }
        let tld = s.split(separator: ".").last ?? Substring("")
        return !tld.isEmpty && tld.allSatisfy(\.isLetter)
    }

    /// Resolves an ENS name to its EIP-55 checksummed Ethereum address.
    ///
    /// Steps (EIP-137):
    ///   1. Compute the name's `namehash`.
    ///   2. Call `resolver(bytes32)` on the ENS registry → resolver contract address.
    ///   3. Call `addr(bytes32)` on the resolver → Ethereum address.
    ///
    /// Throws `WalletError.ensNotFound` if the name is unregistered or has no address record.
    static func resolve(name: String, rpc: EthereumRPC) async throws -> String {
        let normalised = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let nodeHex = namehash(normalised).vaultHexPlain   // 64 lower-hex chars

        // Step 1: resolver(bytes32 node) → address   (selector 0x0178b8bf)
        let resolverResult = try await rpc.ethCall(
            to: registryAddress,
            data: "0x0178b8bf" + nodeHex)
        guard let resolverData = Data(vaultHex: resolverResult), resolverData.count >= 20 else {
            throw WalletError.ensNotFound
        }
        let resolverBytes = resolverData.suffix(20)
        guard !resolverBytes.allSatisfy({ $0 == 0 }) else { throw WalletError.ensNotFound }
        let resolverAddress = "0x" + resolverBytes.vaultHexPlain

        // Step 2: addr(bytes32 node) → address   (selector 0x3b3b57de)
        let addrResult = try await rpc.ethCall(
            to: resolverAddress,
            data: "0x3b3b57de" + nodeHex)
        guard let addrData = Data(vaultHex: addrResult), addrData.count >= 20 else {
            throw WalletError.ensNotFound
        }
        let addrBytes = addrData.suffix(20)
        guard !addrBytes.allSatisfy({ $0 == 0 }) else { throw WalletError.ensNotFound }
        let rawAddress = "0x" + addrBytes.vaultHexPlain

        // Canonicalise through WalletEngine: EIP-55 checksum + burn-address guard.
        return try WalletEngine.validateRecipient(rawAddress)
    }

    // MARK: - Namehash (EIP-137)

    /// Computes the ENS namehash of a fully-qualified, lower-case domain name.
    ///
    ///     namehash("")          = 0x00…00  (32 zero bytes)
    ///     namehash("eth")       = keccak256(namehash("") ++ keccak256("eth"))
    ///     namehash("foo.eth")   = keccak256(namehash("eth") ++ keccak256("foo"))
    static func namehash(_ name: String) -> Data {
        var node = Data(repeating: 0, count: 32)
        guard !name.isEmpty else { return node }
        for label in name.split(separator: ".").reversed() {
            let labelHash = Hash.keccak256(data: Data(label.utf8))
            node = Hash.keccak256(data: node + labelHash)
        }
        return node
    }
}
