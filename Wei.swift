import Foundation

/// Minimal unsigned big-integer helpers on big-endian byte arrays (enough for uint256 wei math).
/// Values are normalised: no leading zero bytes; zero is an empty array.
enum Wei {
    static func normalize(_ data: Data) -> [UInt8] {
        Array(data.drop(while: { $0 == 0 }))
    }

    static func isZero(_ data: Data) -> Bool { normalize(data).isEmpty }

    static func compare(_ a: Data, _ b: Data) -> ComparisonResult {
        let x = normalize(a), y = normalize(b)
        if x.count != y.count { return x.count < y.count ? .orderedAscending : .orderedDescending }
        for (p, q) in zip(x, y) where p != q { return p < q ? .orderedAscending : .orderedDescending }
        return .orderedSame
    }

    static func add(_ a: Data, _ b: Data) -> Data {
        let x = normalize(a), y = normalize(b)
        if x.isEmpty { return Data(y) }
        if y.isEmpty { return Data(x) }

        let width = max(x.count, y.count)
        var left = x
        var right = y
        while left.count < width { left.insert(0, at: 0) }
        while right.count < width { right.insert(0, at: 0) }

        var out = [UInt8](repeating: 0, count: width + 1)
        var carry: UInt32 = 0
        var i = left.count - 1
        var j = right.count - 1
        var k = out.count - 1

        while i >= 0 || j >= 0 || carry > 0 {
            var total: UInt32 = carry
            if i >= 0 { total += UInt32(left[i]); i -= 1 }
            if j >= 0 { total += UInt32(right[j]); j -= 1 }
            out[k] = UInt8(total & 0xff)
            carry = total >> 8
            k -= 1
        }

        if let firstNonZero = out.firstIndex(where: { $0 != 0 }) {
            return Data(out[firstNonZero...])
        }
        return Data()
    }

    static func multiply(_ a: Data, _ b: Data) -> Data {
        let x = normalize(a), y = normalize(b)
        if x.isEmpty || y.isEmpty { return Data() }

        var result = [UInt32](repeating: 0, count: x.count + y.count + 1)
        for i in stride(from: x.count - 1, through: 0, by: -1) {
            var carry: UInt32 = 0
            for j in stride(from: y.count - 1, through: 0, by: -1) {
                let idx = i + j + 1
                let total = result[idx] + UInt32(x[i]) * UInt32(y[j]) + carry
                result[idx] = total & 0xff
                carry = total >> 8
            }
            var k = i
            while carry > 0 {
                let total = UInt32(result[k]) + carry
                result[k] = total & 0xff
                carry = total >> 8
                if k == 0 { break }
                k -= 1
            }
        }

        if let firstNonZero = result.firstIndex(where: { $0 != 0 }) {
            return Data(Array(result[firstNonZero...]))
        }
        return Data()
    }

    static func from(_ value: UInt64) -> Data {
        var v = value; var out = [UInt8]()
        while v > 0 { out.append(UInt8(v & 0xff)); v >>= 8 }
        return Data(out.reversed())
    }

    /// Unsigned subtraction (a - b). Returns nil on underflow (when a < b).
    static func subtract(_ a: Data, _ b: Data) -> Data? {
        guard compare(a, b) != .orderedAscending else { return nil }
        let x = normalize(a), y = normalize(b)
        let width = max(x.count, y.count)
        var left = x, right = y
        while left.count < width { left.insert(0, at: 0) }
        while right.count < width { right.insert(0, at: 0) }

        var out = [UInt8](repeating: 0, count: width)
        var borrow = 0
        for idx in stride(from: width - 1, through: 0, by: -1) {
            let diff = Int(left[idx]) - Int(right[idx]) - borrow
            if diff < 0 {
                out[idx] = UInt8(diff + 256)
                borrow = 1
            } else {
                out[idx] = UInt8(diff)
                borrow = 0
            }
        }

        if let firstNonZero = out.firstIndex(where: { $0 != 0 }) {
            return Data(Array(out[firstNonZero...]))
        }
        return Data()
    }

    /// Converts big-endian byte Data to UInt64 (returns nil if larger than 8 bytes).
    static func toUInt64(_ data: Data) -> UInt64? {
        let n = normalize(data)
        guard n.count <= 8 else { return nil }
        var result: UInt64 = 0
        for byte in n {
            result = (result << 8) | UInt64(byte)
        }
        return result
    }

    /// Divides big-endian byte Data by a non-zero UInt64 scalar.
    static func divide(_ data: Data, by divisor: UInt64) -> Data {
        guard divisor > 0 else { return Data() }
        let norm = normalize(data)
        if norm.isEmpty { return Data() }
        var quotient = [UInt8]()
        var remainder: UInt64 = 0
        for byte in norm {
            let current = (remainder << 8) | UInt64(byte)
            let q = current / divisor
            remainder = current % divisor
            quotient.append(UInt8(q & 0xff))
        }
        return Data(normalize(Data(quotient)))
    }
}
