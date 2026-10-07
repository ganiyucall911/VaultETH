import Foundation

/// Exact decimal <-> wei conversion using integer digit arithmetic only (no Double/Decimal rounding).
enum ETHAmount {
    static let decimals = 18

    /// Parses a user-entered ETH amount ("1", "0.5", ".25") into big-endian wei bytes.
    /// Throws for empty, negative, non-numeric, zero, more than 18 decimals, or values above uint256.
    static func wei(from text: String) throws -> Data {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard !s.isEmpty, parts.count <= 2 else { throw WalletError.invalidAmount }
        let whole = String(parts[0])
        let frac = parts.count == 2 ? String(parts[1]) : ""
        guard !(whole.isEmpty && frac.isEmpty),
              whole.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              frac.utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              frac.count <= decimals else { throw WalletError.invalidAmount }

        let padded = frac + String(repeating: "0", count: decimals - frac.count)
        var digits = Array((whole + padded).utf8.map { Int($0) - 48 }.drop(while: { $0 == 0 }))
        guard !digits.isEmpty else { throw WalletError.invalidAmount }   // zero is not a valid send amount

        var out = [UInt8]()                                              // little-endian base-256
        while !digits.isEmpty {
            var rem = 0
            var next = [Int](); next.reserveCapacity(digits.count)
            for d in digits {
                let cur = rem * 10 + d
                let q = cur / 256
                rem = cur % 256
                if !(next.isEmpty && q == 0) { next.append(q) }
            }
            out.append(UInt8(rem))
            digits = next
        }
        guard out.count <= 32 else { throw WalletError.invalidAmount }
        return Data(out.reversed())
    }

    /// Formats wei bytes as a decimal ETH string without trailing zeros, e.g. "0.5", "1", "0".
    static func format(wei data: Data) -> String {
        var bytes = Wei.normalize(data)
        var dec = [UInt8]()                                              // little-endian decimal digits
        while !bytes.isEmpty {
            var rem = 0
            var next = [UInt8](); next.reserveCapacity(bytes.count)
            for b in bytes {
                let cur = rem * 256 + Int(b)
                let q = cur / 10
                rem = cur % 10
                if !(next.isEmpty && q == 0) { next.append(UInt8(q)) }
            }
            dec.append(UInt8(rem))
            bytes = next
        }
        var s = dec.reversed().map { String($0) }.joined()
        if s.isEmpty { return "0" }
        if s.count <= decimals { s = String(repeating: "0", count: decimals + 1 - s.count) + s }
        let whole = String(s.dropLast(decimals))
        let frac = String(s.suffix(decimals)).replacingOccurrences(of: "0+$", with: "", options: .regularExpression)
        return frac.isEmpty ? whole : "\(whole).\(frac)"
    }
}
