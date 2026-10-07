import Foundation

extension Data {
    /// Parses a hex string with or without a `0x` prefix. Odd-length input is left-padded with a zero
    /// (JSON-RPC quantities such as "0x1" are odd length). Returns nil on any non-hex character.
    /// Named `vaultHex` so it can never be confused with WalletCore's own `Data(hexString:)`.
    init?(vaultHex: String) {
        var s = vaultHex
        if s.hasPrefix("0x") || s.hasPrefix("0X") { s = String(s.dropFirst(2)) }
        if s.utf8.count % 2 != 0 { s = "0" + s }
        var bytes = [UInt8]()
        bytes.reserveCapacity(s.utf8.count / 2)
        var high: UInt8?
        for c in s.utf8 {
            guard let v = Data.nibble(c) else { return nil }
            if let h = high { bytes.append(h << 4 | v); high = nil } else { high = v }
        }
        self.init(bytes)
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 48...57: return c - 48      // 0-9
        case 97...102: return c - 87     // a-f
        case 65...70: return c - 55      // A-F
        default: return nil
        }
    }

    /// Lowercase hex with `0x` prefix, e.g. "0x0f".
    var vaultHex0x: String { "0x" + map { String(format: "%02x", $0) }.joined() }

    /// Lowercase hex without prefix.
    var vaultHexPlain: String { map { String(format: "%02x", $0) }.joined() }

    /// JSON-RPC "quantity" encoding: `0x` + hex with no leading zeros, `0x0` for zero.
    var rpcQuantity: String {
        let hex = vaultHexPlain.drop(while: { $0 == "0" })
        return hex.isEmpty ? "0x0" : "0x" + hex
    }
}
