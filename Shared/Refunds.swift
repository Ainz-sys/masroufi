import Foundation

// Money that comes back for a purchase (a cancelled Uber, a reversed card payment, a refund):
// linked to the purchase, so it is neither spending nor income.

extension SMSParser {
    private static func matches(_ re: NSRegularExpression, _ s: String) -> Bool {
        re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
    }

    static let refundRE = try! NSRegularExpression(pattern: #"\b(?:refund(?:ed)?|reversal|reversed|revers(?:e|ing)|chargeback|cancel(?:l?ed|lation)?|void(?:ed)?)\b|استرداد|استرجاع|مسترد|مرتجع|عكس|عكسية|إلغاء|الغاء|ملغا"#, options: [.caseInsensitive])
    static let transferRE = try! NSRegularExpression(pattern: #"\b(?:salary|transfer(?:red)?\s+from|inward|remittance|deposit(?:ed)?\s+by)\b|راتب|حوالة|تحويل\s+وارد|تحويل\s+من"#, options: [.caseInsensitive])

    /// The bank message says the money is a refund or a reversal.
    static func isRefundText(_ raw: String) -> Bool {
        guard !raw.isEmpty else { return false }
        return matches(refundRE, normalize(raw))
    }

    static func isTransferText(_ raw: String) -> Bool {
        guard !raw.isEmpty else { return false }
        return matches(transferRE, normalize(raw))
    }
}

extension Ledger {
    /// Still has money that could come back (not excluded, not already refunded in full).
    static func refundable(_ x: Transaction) -> Bool {
        x.kind == .debit && !x.excluded && x.refundOf == nil && x.amountHome - (x.refunded ?? 0) > 0.011
    }

    /// The purchase this incoming money gives back, if it clearly is one:
    /// 1. from the same merchant (in the 45 days before), the same amount first, else a partial refund; or
    /// 2. the same amount on the same card shortly before: within 6 hours (7 days when the bank calls it a reversal/refund).
    static func refundTarget(_ d: AppData, credit c: Transaction, keyword: Bool) -> Int? {
        guard c.kind == .credit, c.notRefund != true, c.refundOf == nil else { return nil }
        let a = c.amountHome
        let candidates = d.transactions.indices.filter { i in
            let x = d.transactions[i]
            let gap = c.date.timeIntervalSince(x.date)
            return x.id != c.id && refundable(x) && x.amountHome - (x.refunded ?? 0) >= a - 0.011 && gap >= -900 && gap <= 45 * 86400
        }
        func latest(_ list: [Int]) -> Int? { list.max { d.transactions[$0].date < d.transactions[$1].date } }
        func exact(_ i: Int) -> Bool { abs(d.transactions[i].amountHome - (d.transactions[i].refunded ?? 0) - a) < 0.011 }
        if !c.merchantKey.isEmpty {
            let same = candidates.filter { d.transactions[$0].merchantKey == c.merchantKey }
            if let i = latest(same.filter(exact)) ?? latest(same) { return i }
        }
        if !keyword && SMSParser.isTransferText(c.raw) { return nil }   // a salary or a transfer is real income
        let window: TimeInterval = keyword ? 7 * 86400 : 6 * 3600
        let sameAmount = candidates.filter { i in
            let x = d.transactions[i]
            let sameCard = c.card.isEmpty || x.card.isEmpty || c.card.hasSuffix(x.card) || x.card.hasSuffix(c.card)   // "5" and "4458" can be the same card
            return exact(i) && sameCard && c.date.timeIntervalSince(x.date) <= window
        }
        return latest(sameAmount)
    }

    /// Links the incoming transaction at `ci` to the purchase it refunds. Returns the purchase's index.
    @discardableResult
    static func linkRefund(_ d: inout AppData, credit ci: Int, keyword: Bool) -> Int? {
        guard d.transactions.indices.contains(ci), let ti = refundTarget(d, credit: d.transactions[ci], keyword: keyword) else { return nil }
        link(&d, credit: ci, purchase: ti)
        return ti
    }

    static func link(_ d: inout AppData, credit ci: Int, purchase ti: Int) {
        let c = d.transactions[ci]
        d.transactions[ci].refundOf = d.transactions[ti].id
        d.transactions[ci].categoryID = d.transactions[ti].categoryID
        d.transactions[ci].reviewed = nil
        d.transactions[ci].notRefund = nil
        d.transactions[ti].refunded = min(d.transactions[ti].amountHome, (d.transactions[ti].refunded ?? 0) + c.amountHome)
        d.transactions[ti].refundedAt = c.date
    }

    /// "Not a refund": the incoming money goes back to being income, and the purchase counts again.
    static func unlinkRefund(_ d: inout AppData, credit id: String) {
        guard let ci = d.transactions.firstIndex(where: { $0.id == id }), let pid = d.transactions[ci].refundOf else { return }
        let a = d.transactions[ci].amountHome
        d.transactions[ci].refundOf = nil
        d.transactions[ci].notRefund = true
        d.transactions[ci].categoryID = "income"
        if let ti = d.transactions.firstIndex(where: { $0.id == pid }) {
            let left = (d.transactions[ti].refunded ?? 0) - a
            d.transactions[ti].refunded = left > 0.011 ? left : nil
            if d.transactions[ti].refunded == nil { d.transactions[ti].refundedAt = nil }
        }
    }

    /// The refunds linked to a purchase, oldest first.
    static func refunds(_ d: AppData, of id: String) -> [Transaction] {
        d.transactions.filter { $0.refundOf == id }.sorted { $0.date < $1.date }
    }

    /// For incoming money that wasn't linked automatically: the purchase it most likely gives back
    /// (the same amount in the 45 days before), offered to the person as a one-tap link.
    static func likelyPurchase(_ d: AppData, for c: Transaction) -> Transaction? {
        guard c.kind == .credit, c.refundOf == nil else { return nil }
        let list = d.transactions.filter { x in
            let gap = c.date.timeIntervalSince(x.date)
            return refundable(x) && abs(x.amountHome - (x.refunded ?? 0) - c.amountHome) < 0.011 && gap >= -900 && gap <= 45 * 86400
        }
        return list.max { $0.date < $1.date }
    }
}
