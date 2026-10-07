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
        let x = Array(normalize(a).reversed()), y = Array(normalize(b).reversed())
        var out = [UInt8](); var carry = 0
        for i in 0..<max(x.count, y.count) {
            let sum = (i < x.count ? Int(x[i]) : 0) + (i < y.count ? Int(y[i]) : 0) + carry
            out.append(UInt8(sum & 0xff)); carry = sum >> 8
        }
        if carry > 0 { out.append(UInt8(carry)) }
        return Data(out.reversed())
    }

    static func multiply(_ a: Data, _ b: Data) -> Data {
        let x = Array(normalize(a).reversed()), y = Array(normalize(b).reversed())
        if x.isEmpty || y.isEmpty { return Data() }
        var acc = [Int](repeating: 0, count: x.count + y.count)
        for i in 0..<x.count { for j in 0..<y.count { acc[i + j] += Int(x[i]) * Int(y[j]) } }
        var out = [UInt8](); var carry = 0
        for v in acc { let t = v + carry; out.append(UInt8(t & 0xff)); carry = t >> 8 }
        while carry > 0 { out.append(UInt8(carry & 0xff)); carry >>= 8 }
        return Data(normalize(Data(out.reversed())))
    }

    static func from(_ value: UInt64) -> Data {
        var v = value; var out = [UInt8]()
        while v > 0 { out.append(UInt8(v & 0xff)); v >>= 8 }
        return Data(out.reversed())
    }
}
