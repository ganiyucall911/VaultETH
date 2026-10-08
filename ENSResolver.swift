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
        let s = WalletEngine.parsePaymentURI(raw).recipient.lowercased()
        guard !s.hasPrefix("0x"), s.contains("."), s.count >= 4 else { return false }
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
        let target = WalletEngine.parsePaymentURI(name).recipient
        let normalised = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

    /// Resolves an Ethereum address to its primary ENS name (reverse resolution).
    ///
    /// Steps:
    ///   1. Query `<address_without_0x>.addr.reverse` on the ENS registry for the resolver.
    ///   2. Call `name(bytes32)` (selector `0x691f3431`) on the resolver.
    ///   3. Decode the returned ABI string.
    ///   4. Verify forward resolution to protect against reverse record spoofing.
    ///
    /// Returns `nil` when no reverse record exists or when forward verification fails.
    static func resolveAddress(_ rawAddress: String, rpc: EthereumRPC) async throws -> String? {
        let clean = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let body = clean.hasPrefix("0x") ? String(clean.dropFirst(2)) : clean
        guard body.count == 40 else { return nil }
        let reverseName = body + ".addr.reverse"
        let nodeHex = namehash(reverseName).vaultHexPlain

        // Step 1: resolver(bytes32 node) on registry
        guard let resolverResult = try? await rpc.ethCall(to: registryAddress, data: "0x0178b8bf" + nodeHex),
              let resolverData = Data(vaultHex: resolverResult), resolverData.count >= 20 else {
            return nil
        }
        let resolverBytes = resolverData.suffix(20)
        guard !resolverBytes.allSatisfy({ $0 == 0 }) else { return nil }
        let resolverAddress = "0x" + resolverBytes.vaultHexPlain

        // Step 2: name(bytes32 node) on resolver (selector 0x691f3431)
        guard let nameResult = try? await rpc.ethCall(to: resolverAddress, data: "0x691f3431" + nodeHex),
              let candidate = decodeABIString(nameResult),
              !candidate.isEmpty else {
            return nil
        }

        // Step 3: Forward resolution check (crucial security against reverse spoofing)
        do {
            let forwardAddress = try await resolve(name: candidate, rpc: rpc)
            guard forwardAddress.lowercased() == ("0x" + body).lowercased() else { return nil }
            return candidate
        } catch {
            return nil
        }
    }

    /// Decodes an ABI-encoded dynamic string returned from an eth_call.
    static func decodeABIString(_ hexString: String) -> String? {
        guard let data = Data(vaultHex: hexString), data.count >= 64 else { return nil }
        var offset: Int = 0
        for b in data[0..<32] {
            offset = (offset << 8) | Int(b)
            if offset > 1024 { break }
        }
        let lengthOffset = (offset > 0 && offset + 32 <= data.count) ? offset : 32
        guard data.count >= lengthOffset + 32 else { return nil }
        var length: Int = 0
        for b in data[lengthOffset..<(lengthOffset + 32)] {
            length = (length << 8) | Int(b)
            if length > 512 { return nil }
        }
        guard length > 0, data.count >= lengthOffset + 32 + length else { return nil }
        let stringData = data[(lengthOffset + 32)..<(lengthOffset + 32 + length)]
        return String(data: stringData, encoding: .utf8)
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
