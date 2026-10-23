import Foundation

public enum TxnType: String, Codable { case debit, credit }

/// All money is in paise (1/100 rupee) to avoid floating point drift.
public struct ParsedTxn: Equatable {
    public var type: TxnType
    public var amountPaise: Int64
    public var merchant: String?
    public var method: String
    public var time: Date
    public var isSalary: Bool
    public var isRefund: Bool = false
}

public func rupeeString(_ paise: Int64) -> String {
    let neg = paise < 0
    let absV = paise < 0 ? -paise : paise
    let rupees = absV / 100, p = absV % 100
    let s = String(rupees)
    var grouped = s
    if s.count > 3 {
        let tail = String(s.suffix(3))
        let head = Array(String(s.dropLast(3)).reversed())
        var parts: [String] = []
        var i = 0
        while i < head.count { parts.append(String(head[i..<min(i + 2, head.count)])); i += 2 }
        grouped = String(parts.joined(separator: ",").reversed()) + "," + tail
    }
    let body = p == 0 ? grouped : grouped + "." + (p < 10 ? "0\(p)" : "\(p)")
    return (neg ? "-" : "") + "₹" + body
}
