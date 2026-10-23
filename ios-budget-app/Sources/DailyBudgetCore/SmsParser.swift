import Foundation

/// Turns a bank / UPI message into a ParsedTxn. Nil for OTPs, promos, reminders, collect requests.
public enum SmsParser {
    private static func rx(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p, options: [.caseInsensitive]) }

    private static let amountRe = rx(#"(?:rs\.?|inr|₹)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#)
    private static let debitWords = rx(#"\b(debited|spent|paid|sent|withdrawn|purchase|purchased|payment of|txn of|deducted)\b"#)
    private static let creditWords = rx(#"\b(credited|received|deposited|refund(?:ed)?|salary)\b"#)
    private static let rejectWords = rx(
        #"\b(otp|one[- ]time password|verification code|will be debited|is due|due on|min(?:imum)? amount|statement|requested money|collect request|pre-?approved|loan offer|apply now|avail(?:able)? (?:bal|limit)\b.*\boffer)\b"#)
    private static let vpaRe = rx(#"\bVPA\s+([\w.\-]+)@[\w]+"#)
    private static let targetRe = rx(
        #"\b(?:at|to|towards|info:?)\s+([A-Za-z0-9][A-Za-z0-9&.'\-/ ]{1,30}?)(?=\s+(?:on|ref|via|using|upi|txn|from|avl|bal|not you|if not)\b|[.,;(]|\s*$)"#)
    private static let sourceRe = rx(
        #"\b(?:by|from)\s+(?:neft|imps|upi|rtgs)?[-/ ]*([A-Za-z][A-Za-z0-9&.'\- ]{2,30}?)(?=\s+(?:on|ref|via|txn|avl|bal)\b|[.,;(]|\s*$)"#)
    private static let salaryRe = rx(#"\bsalary\b|\bsal\b"#)
    private static let notMerchant: Set<String> = ["a/c", "ac", "account", "your", "you", "card", "bank", "self"]

    public static func parse(_ body: String, at time: Date = Date()) -> ParsedTxn? {
        let text = body.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if has(rejectWords, text) { return nil }

        guard let m = amountRe.firstMatch(in: text, range: full(text)), let amtStr = group(m, 1, text),
              let amount = toPaise(amtStr), amount > 0 else { return nil }

        let debitAt = debitWords.firstMatch(in: text, range: full(text))?.range.location
        let creditAt = creditWords.firstMatch(in: text, range: full(text))?.range.location
        let type: TxnType
        switch (debitAt, creditAt) {
        case (nil, nil): return nil
        case (_, nil): type = .debit
        case (nil, _): type = .credit
        case let (d?, c?): type = d < c ? .debit : .credit   // first verb is ours
        }

        // ATM before CARD: "withdrawn from ATM using card" is cash.
        let method: String
        if has(rx(#"\bUPI\b|VPA"#), text) { method = "UPI" }
        else if has(rx(#"\bATM\b|withdrawn"#), text) { method = "ATM" }
        else if has(rx(#"\bcard\b"#), text) { method = "CARD" }
        else if has(rx(#"\bNEFT|IMPS|RTGS"#), text) { method = "BANK" }
        else { method = "OTHER" }

        var merchant: String?
        switch type {
        case .debit:
            if let v = vpaRe.firstMatch(in: text, range: full(text)), let local = group(v, 1, text) {
                merchant = clean(local.replacingOccurrences(of: ".", with: " ")
                    .replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " "))
            }
            if merchant == nil {
                for t in targetRe.matches(in: text, range: full(text)) {
                    if let g = group(t, 1, text), let c = clean(g) { merchant = c; break }
                }
            }
            if merchant == nil && method == "ATM" { merchant = "ATM" }
        case .credit:
            if let s = sourceRe.firstMatch(in: text, range: full(text)), let g = group(s, 1, text) { merchant = clean(g) }
        }

        let isSalary = type == .credit && has(salaryRe, text)
        return ParsedTxn(type: type, amountPaise: amount, merchant: merchant, method: method, time: time, isSalary: isSalary)
    }

    private static func full(_ s: String) -> NSRange { NSRange(s.startIndex..., in: s) }
    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { r.firstMatch(in: s, range: full(s)) != nil }
    private static func group(_ m: NSTextCheckingResult, _ i: Int, _ s: String) -> String? {
        Range(m.range(at: i), in: s).map { String(s[$0]) }
    }

    private static func toPaise(_ s: String) -> Int64? {
        let parts = s.replacingOccurrences(of: ",", with: "").split(separator: ".", omittingEmptySubsequences: false)
        guard let r = Int64(parts[0]) else { return nil }
        var p = parts.count > 1 ? String(parts[1]) : ""
        while p.count < 2 { p += "0" }
        return r * 100 + (Int64(p.prefix(2)) ?? 0)
    }

    private static func clean(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        while let l = s.last, ".-/".contains(l) { s.removeLast() }
        s = s.trimmingCharacters(in: .whitespaces)
        let low = s.lowercased()
        if s.count < 2 || notMerchant.contains(low) || low.hasPrefix("a/c") || low.hasPrefix("your ") { return nil }
        return s.split(separator: " ").map { w in
            let l = w.lowercased(); return l.prefix(1).uppercased() + l.dropFirst()
        }.joined(separator: " ")
    }
}
