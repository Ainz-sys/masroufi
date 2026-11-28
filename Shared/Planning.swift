import Foundation

// Apple Pay logging, the review queue, the flexible budget and the numbers behind the analytics screens.

extension Ledger {
    // MARK: Apple Pay (Shortcuts → Wallet "Transaction" automation)

    /// An Apple Pay purchase of this amount logged in the last 30 minutes that has no bank message yet.
    static func applePayMatch(_ d: AppData, amountHome: Double, now: Date) -> Int? {
        d.transactions.lastIndex { x in
            x.source == .applePay && x.raw.isEmpty && x.kind == .debit && abs(x.amountHome - amountHome) < 0.011
                && abs(x.addedAt.timeIntervalSince(now)) < 1800
        }
    }

    /// Logs a purchase the moment it is paid with Apple Pay. If the bank's SMS was already logged, nothing is added.
    static func logApplePay(amount: String, merchant: String, card: String, into d: inout AppData, now: Date = Date()) -> LogResult {
        var r = LogResult()
        d.lastAutoRun = now
        guard let a = SMSParser.parseAmount(amount) else { r.status = "ignored"; return r }
        let smsTwin = d.transactions.contains { x in
            x.source == .sms && x.kind == .debit && abs(x.amountHome - a.home) < 0.011 && abs(x.addedAt.timeIntervalSince(now)) < 1800
        }
        if smsTwin { r.status = "duplicate"; d.lastApplePay = now; return r }
        let name = SMSParser.cleanMerchant(merchant.trimmingCharacters(in: .whitespacesAndNewlines))
        let key = SMSParser.merchantKey(name)
        var cat = d.merchantMap[key] ?? SMSParser.categorize(merchant: name)
        if !d.categories.contains(where: { $0.id == cat }) { cat = "other" }
        let digits = card.filter(\.isNumber)
        let tx = Transaction(date: now, addedAt: now, amount: a.value, currency: a.currency, amountHome: a.home, kind: .debit,
                             merchant: name, merchantKey: key, categoryID: cat, card: String(digits.suffix(4)),
                             bank: "Apple Pay", source: .applePay, title: d.merchantNames[key], reviewed: false)
        d.transactions.append(tx)
        r.added = [tx]
        d.lastApplePay = now
        d.lastAuto = now
        r.alerts = checkAlerts(&d, now: now)
        r.status = "logged"
        return r
    }

    // MARK: Review queue

    static func reviewQueue(_ d: AppData) -> [Transaction] {
        d.transactions.filter { $0.needsReview && !$0.isRefund }.sorted { $0.date > $1.date }
    }

    /// How many earlier transactions from the same merchant ended up in this category (the "why" of a suggestion).
    static func sameMerchantCount(_ d: AppData, _ tx: Transaction) -> Int {
        guard !tx.merchantKey.isEmpty else { return 0 }
        return d.transactions.filter { $0.id != tx.id && $0.merchantKey == tx.merchantKey && $0.categoryID == tx.categoryID && !$0.needsReview }.count
    }

    // MARK: Spending by category / group

    static func spentByCategory(_ d: AppData, from: Date, to: Date) -> [String: Double] {
        var out: [String: Double] = [:]
        for x in d.transactions where x.counts && x.date >= from && x.date < to { out[x.categoryID, default: 0] += x.spentHome }
        return out
    }

    static func previousCycle(_ d: AppData, before start: Date) -> (start: Date, end: Date, days: Int) {
        cycle(salaryDay: d.settings.salaryDay, ref: cal.date(byAdding: .day, value: -1, to: start) ?? start)
    }

    enum Group: String { case fixed, flex, nonMonthly }

    static func group(of categoryID: String, in d: AppData) -> Group {
        if d.planned.contains(where: { $0.categoryID == categoryID }) { return .nonMonthly }
        return d.category(categoryID).isFixed ? .fixed : .flex
    }

    // MARK: Flexible budget (fixed + flexible + non-monthly)

    struct FlexPlan {
        var budget: Double
        var fixedPlanned: Double, fixedSpent: Double
        var nonMonthly: Double, nonMonthlySpent: Double
        var flexBudget: Double, flexSpent: Double
        var daysLeft: Int
        var flexRemaining: Double { flexBudget - flexSpent }
        var flexPerDay: Double { max(0, flexRemaining) / Double(max(1, daysLeft)) }
        var fixedEstimated: Bool
    }

    static func flexPlan(_ d: AppData, now: Date = Date()) -> FlexPlan {
        let m = month(d, now: now)
        let byCat = spentByCategory(d, from: m.start, to: m.end)
        var fixed = 0.0, flex = 0.0, non = 0.0
        for (id, v) in byCat {
            switch group(of: id, in: d) { case .fixed: fixed += v; case .flex: flex += v; case .nonMonthly: non += v }
        }
        var planned = d.settings.fixedPlanned, estimated = false
        if planned <= 0 {
            let prev = previousCycle(d, before: m.start)
            let last = spentByCategory(d, from: prev.start, to: prev.end).filter { group(of: $0.key, in: d) == .fixed }.values.reduce(0, +)
            planned = max(last, fixed)
            estimated = true
        }
        let nonMonthly = d.planned.reduce(0) { $0 + $1.monthly }
        return FlexPlan(budget: m.budget, fixedPlanned: planned, fixedSpent: fixed, nonMonthly: nonMonthly, nonMonthlySpent: non,
                        flexBudget: max(0, m.budget - planned - nonMonthly), flexSpent: flex, daysLeft: m.daysLeft, fixedEstimated: estimated)
    }

    // MARK: Category and merchant budgets (with rollover)

    struct BudgetLine: Identifiable {
        var id: String
        var name: String, icon: String, color: String
        var budget: Double, carried: Double, spent: Double
        var total: Double { budget + carried }
        var fraction: Double { total > 0 ? spent / total : 0 }
        var isMerchant: Bool
    }

    static func budgetLines(_ d: AppData, lang: Lang, now: Date = Date()) -> [BudgetLine] {
        let m = month(d, now: now)
        let prev = previousCycle(d, before: m.start)
        let now_ = spentByCategory(d, from: m.start, to: m.end)
        let before = spentByCategory(d, from: prev.start, to: prev.end)
        var out: [BudgetLine] = d.categories.compactMap { c in
            guard let b = c.monthlyBudget, b > 0 else { return nil }
            let carried = c.rollover ? max(0, b - (before[c.id] ?? 0)) : 0
            return BudgetLine(id: c.id, name: c.name(lang), icon: c.symbol, color: c.color, budget: b, carried: carried, spent: now_[c.id] ?? 0, isMerchant: false)
        }
        for mb in d.merchantBudgets {
            let keys = Set(mb.keys)
            let spent = d.transactions.filter { $0.counts && keys.contains($0.merchantKey) && $0.date >= m.start && $0.date < m.end }.reduce(0) { $0 + $1.spentHome }
            out.append(BudgetLine(id: mb.id, name: mb.name, icon: mb.icon, color: "#FF7B7B", budget: mb.amount, carried: 0, spent: spent, isMerchant: true))
        }
        return out.sorted { $0.fraction > $1.fraction }
    }

    // MARK: Pace (cumulative spending, this month against last month)

    struct Pace { var current: [Double]; var last: [Double]; var days: Int; var today: Int; var budget: Double
        /// Spent so far minus what had been spent at the same point last month (negative = better).
        var vsLast: Double? {
            guard today >= 1, today <= last.count, today <= current.count, last[today - 1] > 0 else { return nil }
            return current[today - 1] - last[today - 1]
        }
    }

    static func pace(_ d: AppData, now: Date = Date()) -> Pace {
        let m = month(d, now: now)
        let prev = previousCycle(d, before: m.start)
        func cumulative(from start: Date, days: Int, upTo: Int) -> [Double] {
            var out: [Double] = [], t = 0.0
            for i in 0..<min(days, upTo) {
                let s = cal.date(byAdding: .day, value: i, to: start)!, e = cal.date(byAdding: .day, value: 1, to: s)!
                t += spent(d, from: s, to: e); out.append(t)
            }
            return out
        }
        let days = cal.dateComponents([.day], from: m.start, to: m.end).day ?? 30
        let today = (cal.dateComponents([.day], from: m.start, to: cal.startOfDay(for: now)).day ?? 0) + 1
        return Pace(current: cumulative(from: m.start, days: days, upTo: today), last: cumulative(from: prev.start, days: prev.days, upTo: prev.days),
                    days: days, today: today, budget: m.budget)
    }

    // MARK: One-line insight for the home screen

    struct Insight { var categoryID: String; var pct: Int; var amount: Double; var count: Int }

    /// The category whose last 7 days are furthest above its usual week (at least +25% and 50 QAR).
    static func insight(_ d: AppData, now: Date = Date()) -> Insight? {
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
        let weekStart = cal.date(byAdding: .day, value: -7, to: end)!
        let histStart = cal.date(byAdding: .day, value: -63, to: end)!
        var week: [String: (Double, Int)] = [:], hist: [String: Double] = [:]
        for x in d.transactions where x.counts && x.date >= histStart && x.date < end {
            if x.date >= weekStart { let v = week[x.categoryID] ?? (0, 0); week[x.categoryID] = (v.0 + x.spentHome, v.1 + 1) }
            else { hist[x.categoryID, default: 0] += x.spentHome }
        }
        var best: Insight? = nil
        for (id, w) in week {
            let usual = (hist[id] ?? 0) / 8
            guard usual > 0, w.0 >= 50 else { continue }
            let pct = Int(((w.0 / usual) - 1) * 100)
            if pct >= 25, pct > (best?.pct ?? 0) { best = Insight(categoryID: id, pct: pct, amount: w.0, count: w.1) }
        }
        return best
    }

    // MARK: Analytics

    struct FlowNode: Identifiable { var id: String; var name: String; var icon: String; var color: String; var amount: Double; var group: Group }

    /// This month's spending: groups (fixed / flexible / non-monthly) → categories, largest first.
    static func flow(_ d: AppData, lang: Lang, now: Date = Date()) -> [FlowNode] {
        let m = month(d, now: now)
        return spentByCategory(d, from: m.start, to: m.end).map { id, v in
            let c = d.category(id)
            return FlowNode(id: id, name: c.name(lang), icon: c.symbol, color: c.color, amount: v, group: group(of: id, in: d))
        }
        .sorted { a, b in a.group == b.group ? a.amount > b.amount : (a.group == .fixed || (a.group == .nonMonthly && b.group == .flex)) }
    }

    struct CycleTotal: Identifiable { var id: Date { start }; var start: Date; var total: Double; var current: Bool }

    static func cycleTotals(_ d: AppData, count: Int = 7, now: Date = Date()) -> [CycleTotal] {
        var out: [CycleTotal] = []
        var c = cycle(salaryDay: d.settings.salaryDay, ref: now)
        let first = d.transactions.map(\.date).min() ?? now
        for i in 0..<count {
            if i > 0 && c.end <= first { break }
            out.append(CycleTotal(start: c.start, total: spent(d, from: c.start, to: c.end), current: i == 0))
            c = previousCycle(d, before: c.start)
        }
        return out.reversed()
    }

    struct CategoryChange: Identifiable { var id: String; var name: String; var icon: String; var pct: Int; var now: Double }

    /// Each category this month (so far, scaled to the same number of days) against its average over the 3 previous months.
    static func categoryChanges(_ d: AppData, lang: Lang, now: Date = Date()) -> [CategoryChange] {
        let m = month(d, now: now)
        let elapsed = Double(max(1, (cal.dateComponents([.day], from: m.start, to: now).day ?? 0) + 1))
        let total = Double(max(1, cal.dateComponents([.day], from: m.start, to: m.end).day ?? 30))
        let cur = spentByCategory(d, from: m.start, to: m.end)
        var sums: [String: Double] = [:]; var n = 0
        var c = previousCycle(d, before: m.start)
        let first = d.transactions.map(\.date).min() ?? now
        while n < 3 && c.end > first {
            for (k, v) in spentByCategory(d, from: c.start, to: c.end) { sums[k, default: 0] += v }
            n += 1; c = previousCycle(d, before: c.start)
        }
        guard n > 0 else { return [] }
        return cur.compactMap { id, v in
            let avg = (sums[id] ?? 0) / Double(n)
            guard avg >= 50, elapsed >= 5 else { return nil }
            // flexible spending is scaled to the whole month; rent and bills are already paid in full
            let projected = group(of: id, in: d) == .flex ? v / elapsed * total : v
            let cat = d.category(id)
            return CategoryChange(id: id, name: cat.name(lang), icon: cat.symbol, pct: Int(((projected / avg) - 1) * 100), now: v)
        }
        .sorted { abs($0.pct) > abs($1.pct) }
    }

    /// Spending per day of this budget month (nil for days still to come).
    static func dayMap(_ d: AppData, now: Date = Date()) -> [(day: Date, value: Double?)] {
        let m = month(d, now: now)
        let todayStart = cal.startOfDay(for: now)
        var out: [(Date, Double?)] = []
        var s = m.start
        while s < m.end {
            let e = cal.date(byAdding: .day, value: 1, to: s)!
            out.append((s, s > todayStart ? nil : spent(d, from: s, to: e)))
            s = e
        }
        return out
    }
}
