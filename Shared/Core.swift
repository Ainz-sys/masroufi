import Foundation

// MARK: - Models

enum TxKind: String, Codable { case debit, credit }
enum TxSource: String, Codable { case sms, manual }
enum Lang: String, Codable, CaseIterable { case ar, en }

struct Transaction: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var date: Date
    var noTime: Bool = false
    var addedAt: Date = Date()
    var amount: Double
    var currency: String = "QAR"
    var amountHome: Double
    var kind: TxKind = .debit
    var merchant: String = ""
    var merchantKey: String = ""
    var categoryID: String = "other"
    var card: String = ""
    var account: String = ""
    var balance: Double? = nil
    var bank: String = ""
    var raw: String = ""
    var source: TxSource = .manual
    var excluded: Bool = false
    var note: String = ""

    /// Counts toward spending (expenses that were not excluded).
    var counts: Bool { kind == .debit && !excluded }
}

struct Category: Codable, Identifiable, Hashable {
    var id: String
    var nameAR: String
    var nameEN: String
    /// Name of the 3D icon (asset "i3d-<symbol>").
    var symbol: String
    var color: String = "#A19DA8"
    var monthlyBudget: Double? = nil
    var alertAt80: Bool = true
    var builtIn: Bool = false

    init(id: String, nameAR: String, nameEN: String, symbol: String, color: String = "#A19DA8", monthlyBudget: Double? = nil,
         alertAt80: Bool = true, builtIn: Bool = false) {
        self.id = id; self.nameAR = nameAR; self.nameEN = nameEN; self.symbol = symbol; self.color = color
        self.monthlyBudget = monthlyBudget; self.alertAt80 = alertAt80; self.builtIn = builtIn
    }

    init(from decoder: Decoder) throws { // also migrates the first version, which stored SF Symbol names
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nameAR = try c.decodeIfPresent(String.self, forKey: .nameAR) ?? id
        nameEN = try c.decodeIfPresent(String.self, forKey: .nameEN) ?? id
        let raw = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "other"
        symbol = Category.legacySymbols[raw] ?? raw
        let fallback = Category.defaults.first { $0.id == id }
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? fallback?.color ?? "#A19DA8"
        monthlyBudget = try c.decodeIfPresent(Double.self, forKey: .monthlyBudget)
        alertAt80 = try c.decodeIfPresent(Bool.self, forKey: .alertAt80) ?? true
        builtIn = try c.decodeIfPresent(Bool.self, forKey: .builtIn) ?? false
    }

    func name(_ lang: Lang) -> String { lang == .ar ? nameAR : nameEN }

    static let defaults: [Category] = {
        let raw: [(String, String, String, String, String)] = [
            ("fuel", "وقود", "Fuel", "fuel", "#F2A93B"), ("grocery", "بقالة", "Groceries", "grocery", "#34C38F"),
            ("food", "مطاعم", "Restaurants", "food", "#FF7E67"), ("coffee", "مقاهي", "Coffee", "coffee", "#C8925A"),
            ("transport", "مواصلات", "Transport", "car", "#4D9CFF"), ("shopping", "تسوّق", "Shopping", "shopping", "#B57CFF"),
            ("bills", "فواتير واتصالات", "Bills", "phone", "#5BC0EB"), ("health", "صحة", "Health", "health", "#FF6B8B"),
            ("travel", "سفر", "Travel", "travel", "#6EA8FE"), ("entertainment", "ترفيه", "Entertainment", "games", "#9D7BFF"),
            ("education", "تعليم", "Education", "edu", "#F7BC5C"), ("kids", "أطفال", "Kids", "kids", "#FFB3C7"),
            ("home", "البيت", "Home", "home", "#E8A87C"), ("gifts", "هدايا", "Gifts", "gift", "#FF8FA3"),
            ("cash", "سحب نقدي", "Cash", "cash", "#5DD39E"), ("transfer", "تحويلات", "Transfers", "transfer", "#7FB7FF"),
            ("income", "دخل", "Income", "budget", "#5DD39E"), ("other", "أخرى", "Other", "other", "#A19DA8"),
        ]
        return raw.map { Category(id: $0.0, nameAR: $0.1, nameEN: $0.2, symbol: $0.3, color: $0.4, builtIn: true) }
    }()

    static let symbolChoices = ["gym", "gift", "edu", "travel", "health", "home", "kids", "clothes", "games", "phone", "car", "coffee",
                                "food", "grocery", "fuel", "shopping", "taxi", "cash", "bank", "receipt", "bulb", "calendar", "cloud", "palette"]
    static let colorChoices = ["#CB2A5C", "#E8CB94", "#2BB389", "#3B82F6", "#8B5CF6", "#7C8798"]

    static let legacySymbols: [String: String] = [
        "fuelpump": "fuel", "cart": "grocery", "fork.knife": "food", "cup.and.saucer": "coffee", "bag": "shopping",
        "cross.case": "health", "airplane": "travel", "gamecontroller": "games", "graduationcap": "edu",
        "figure.and.child.holdinghands": "kids", "house": "home", "banknote": "cash", "arrow.left.arrow.right": "transfer",
        "arrow.down.circle": "budget", "square.grid.2x2": "other", "star": "other", "dumbbell": "gym", "pawprint": "other",
        "tshirt": "clothes", "book": "edu", "wrench.and.screwdriver": "home", "heart": "health", "creditcard": "bank",
        "building.columns": "bank", "leaf": "other", "music.note": "games",
    ]
}

struct Settings: Codable {
    var language: Lang = .ar
    var dailyBudget: Double = 0
    var salaryDay: Int = 1
    var alert80: Bool = true
    var alert100: Bool = true
    var notifyEach: Bool = true
    var onboarded: Bool = false
    var background: String = "wine"

    init() {}
    init(from decoder: Decoder) throws { // tolerant of missing keys from older versions
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = try c.decodeIfPresent(Lang.self, forKey: .language) ?? .ar
        dailyBudget = try c.decodeIfPresent(Double.self, forKey: .dailyBudget) ?? 0
        salaryDay = try c.decodeIfPresent(Int.self, forKey: .salaryDay) ?? 1
        alert80 = try c.decodeIfPresent(Bool.self, forKey: .alert80) ?? true
        alert100 = try c.decodeIfPresent(Bool.self, forKey: .alert100) ?? true
        notifyEach = try c.decodeIfPresent(Bool.self, forKey: .notifyEach) ?? true
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        background = try c.decodeIfPresent(String.self, forKey: .background) ?? "wine"
    }
}

struct AppData: Codable {
    var settings = Settings()
    var categories: [Category] = Category.defaults
    var merchantMap: [String: String] = [:]
    var transactions: [Transaction] = []
    var notified: [String: [String]] = [:]
    var lastAuto: Date? = nil

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        categories = try c.decodeIfPresent([Category].self, forKey: .categories) ?? Category.defaults
        if categories.isEmpty { categories = Category.defaults }
        merchantMap = try c.decodeIfPresent([String: String].self, forKey: .merchantMap) ?? [:]
        transactions = try c.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        notified = try c.decodeIfPresent([String: [String]].self, forKey: .notified) ?? [:]
        lastAuto = try c.decodeIfPresent(Date.self, forKey: .lastAuto)
    }

    func category(_ id: String) -> Category {
        categories.first { $0.id == id } ?? categories.first { $0.id == "other" } ?? Category.defaults.last!
    }
}

// MARK: - Storage (shared with the widget through an App Group)

enum Persistence {
    static var groupID: String { Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? "group.com.masroufi.app" }

    static var fileURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("masroufi.json")
    }

    static func load() -> AppData {
        guard let data = try? Data(contentsOf: fileURL) else { return AppData() }
        if let d = try? JSONDecoder().decode(AppData.self, from: data) { return d }
        // Keep the unreadable file instead of overwriting it.
        try? data.write(to: fileURL.deletingLastPathComponent().appendingPathComponent("masroufi-unreadable-\(Int(Date().timeIntervalSince1970)).json"))
        return AppData()
    }

    static func save(_ d: AppData) {
        guard let data = try? JSONEncoder().encode(d) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

// MARK: - Formatting

enum Fmt {
    private static let money: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()
    private static let whole: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()
    static func m(_ v: Double) -> String { money.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v) }
    static func m0(_ v: Double) -> String { whole.string(from: NSNumber(value: v.rounded())) ?? String(Int(v)) }
    static func time(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_GB"); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
    static func day(_ d: Date, _ lang: Lang) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: lang == .ar ? "ar_QA@numbers=latn" : "en_GB"); f.dateFormat = "EEEE d MMMM"; return f.string(from: d)
    }
    static func short(_ d: Date, _ lang: Lang) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: lang == .ar ? "ar_QA@numbers=latn" : "en_GB"); f.dateFormat = "d MMM"; return f.string(from: d)
    }
}

// MARK: - Spending logic (used by the app, the Shortcuts action and the widget)

struct BudgetAlert {
    enum Kind { case near, over, categoryNear, categoryOver }
    var kind: Kind
    var spent: Double
    var budget: Double
    var categoryID: String? = nil
}

struct LogResult {
    var added: [Transaction] = []
    var alerts: [BudgetAlert] = []
    var status: String = "ignored" // logged | duplicate | ignored
}

enum Ledger {
    static var cal: Calendar { Calendar.current }

    static func spent(_ d: AppData, from: Date, to: Date) -> Double {
        d.transactions.filter { $0.counts && $0.date >= from && $0.date < to }.reduce(0) { $0 + $1.amountHome }
    }

    static func dayBounds(_ date: Date) -> (start: Date, end: Date) {
        let s = cal.startOfDay(for: date)
        return (s, cal.date(byAdding: .day, value: 1, to: s)!)
    }

    /// The budget month starts on salary day.
    static func cycle(salaryDay: Int, ref: Date = Date()) -> (start: Date, end: Date, days: Int) {
        let sd = min(28, max(1, salaryDay))
        var comps = cal.dateComponents([.year, .month], from: ref)
        comps.day = sd
        var start = cal.date(from: comps)!
        if start > ref { start = cal.date(byAdding: .month, value: -1, to: start)! }
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        return (start, end, cal.dateComponents([.day], from: start, to: end).day ?? 30)
    }

    struct Today { var spent: Double; var budget: Double; var remaining: Double; var fraction: Double; var count: Int }

    static func today(_ d: AppData, now: Date = Date()) -> Today {
        let b = dayBounds(now)
        let s = spent(d, from: b.start, to: b.end)
        let budget = d.settings.dailyBudget
        return Today(spent: s, budget: budget, remaining: budget - s, fraction: budget > 0 ? s / budget : 0,
                     count: d.transactions.filter { $0.date >= b.start && $0.date < b.end }.count)
    }

    static func transactions(_ d: AppData, on day: Date) -> [Transaction] {
        let b = dayBounds(day)
        return d.transactions.filter { $0.date >= b.start && $0.date < b.end }.sorted { $0.date > $1.date }
    }

    /// Builds a transaction from a parsed SMS. `live` = arriving now from the automation.
    static func transaction(from p: ParsedSMS, raw: String, data: AppData, now: Date, live: Bool) -> Transaction {
        var date = now, noTime = false
        if let pd = p.date {
            if p.hasTime {
                if !live || abs(pd.timeIntervalSince(now)) < 36 * 3600 { date = pd }
            } else if !live && !cal.isDate(pd, inSameDayAs: now) {
                date = cal.date(byAdding: .hour, value: 12, to: cal.startOfDay(for: pd)) ?? pd
                noTime = true
            }
        }
        var cat = SMSParser.categorize(p, merchantMap: data.merchantMap)
        if !data.categories.contains(where: { $0.id == cat }) { cat = "other" }
        return Transaction(date: date, noTime: noTime, addedAt: now, amount: p.amount, currency: p.currency, amountHome: p.amountHome,
                           kind: p.kind, merchant: p.merchant, merchantKey: p.merchantKey, categoryID: cat, card: p.card,
                           account: p.account, balance: p.balance, bank: p.bank, raw: raw.trimmingCharacters(in: .whitespacesAndNewlines),
                           source: .sms)
    }

    static func isDuplicate(_ d: AppData, _ p: ParsedSMS, now: Date) -> Bool {
        d.transactions.contains { x in
            guard !x.raw.isEmpty, SMSParser.normalize(x.raw) == p.normalized else { return false }
            return abs(x.addedAt.timeIntervalSince(now)) < 600 || (p.hasTime && p.date == x.date)
        }
    }

    /// Logs a message coming from the Shortcuts automation.
    static func log(text: String, into d: inout AppData, now: Date = Date()) -> LogResult {
        var items: [(ParsedSMS, String)] = []
        if let whole = SMSParser.parse(text) { items = [(whole, text)] } else { items = parseMany(text) }
        var r = LogResult()
        for (p, raw) in items where !isDuplicate(d, p, now: now) {
            let tx = transaction(from: p, raw: raw, data: d, now: now, live: true)
            d.transactions.append(tx)
            r.added.append(tx)
        }
        if r.added.isEmpty { r.status = items.isEmpty ? "ignored" : "duplicate"; return r }
        d.lastAuto = now
        r.alerts = checkAlerts(&d, now: now)
        r.status = "logged"
        return r
    }

    static func parseMany(_ text: String) -> [(ParsedSMS, String)] {
        var seen = Set<String>()
        return SMSParser.splitMessages(text).compactMap { (m: String) -> (ParsedSMS, String)? in
            guard !seen.contains(m), let p = SMSParser.parse(m) else { return nil }
            seen.insert(m)
            return (p, m)
        }
    }

    /// 80% / 100% of the daily budget, and of each category's monthly budget. Each alert fires once per day / cycle.
    static func checkAlerts(_ d: inout AppData, now: Date) -> [BudgetAlert] {
        var out: [BudgetAlert] = []
        let t = today(d, now: now)
        let dayKey = "day-" + key(now)
        var dayFlags = Set(d.notified[dayKey] ?? [])
        if t.budget > 0 {
            if t.spent > t.budget {
                if d.settings.alert100 && !dayFlags.contains("100") { dayFlags.formUnion(["80", "100"]); out.append(BudgetAlert(kind: .over, spent: t.spent, budget: t.budget)) }
            } else if t.spent >= 0.8 * t.budget && d.settings.alert80 && !dayFlags.contains("80") {
                dayFlags.insert("80"); out.append(BudgetAlert(kind: .near, spent: t.spent, budget: t.budget))
            }
        }
        d.notified[dayKey] = Array(dayFlags)

        let cy = cycle(salaryDay: d.settings.salaryDay, ref: now)
        let cycleKey = "cycle-" + key(cy.start)
        var catFlags = Set(d.notified[cycleKey] ?? [])
        for c in d.categories {
            guard let budget = c.monthlyBudget, budget > 0, c.alertAt80 else { continue }
            let s = d.transactions.filter { $0.categoryID == c.id && $0.counts && $0.date >= cy.start && $0.date < cy.end }.reduce(0) { $0 + $1.amountHome }
            if s > budget {
                if !catFlags.contains(c.id + ":100") { catFlags.formUnion([c.id + ":80", c.id + ":100"]); out.append(BudgetAlert(kind: .categoryOver, spent: s, budget: budget, categoryID: c.id)) }
            } else if s >= 0.8 * budget && !catFlags.contains(c.id + ":80") {
                catFlags.insert(c.id + ":80"); out.append(BudgetAlert(kind: .categoryNear, spent: s, budget: budget, categoryID: c.id))
            }
        }
        d.notified[cycleKey] = Array(catFlags)
        let keys = d.notified.keys.sorted()
        if keys.count > 60 { for k in keys.prefix(keys.count - 60) { d.notified[k] = nil } }
        return out
    }

    /// The day tracking really started: the cycle start, or the first transaction if that is later.
    static func trackingStart(_ d: AppData, cycleStart: Date) -> Date {
        guard let first = d.transactions.map(\.date).min() else { return cycleStart }
        return max(cycleStart, cal.startOfDay(for: first))
    }

    /// Re-cleans transactions saved by older versions (merchant names, categories). Returns true if anything changed.
    static func repair(_ d: inout AppData) -> Bool {
        var changed = false
        for i in d.transactions.indices {
            let old = d.transactions[i]
            let clean = SMSParser.cleanMerchant(old.merchant)
            if clean != old.merchant {
                d.transactions[i].merchant = clean
                d.transactions[i].merchantKey = SMSParser.merchantKey(clean)
                changed = true
            }
            if old.categoryID == "other", old.source == .sms, d.merchantMap[d.transactions[i].merchantKey] == nil {
                let guess = SMSParser.categorize(merchant: clean, context: SMSParser.normalize(old.raw))
                if guess != "other", d.categories.contains(where: { $0.id == guess }) { d.transactions[i].categoryID = guess; changed = true }
            }
        }
        return changed
    }

    static func key(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func csv(_ d: AppData) -> String {
        let lang = d.settings.language
        func q(_ v: String) -> String {
            var s = v
            if let f = s.first, "=+-@".contains(f) { s = "'" + s } // stop spreadsheet formulas
            return s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
        }
        var rows = ["Date,Time,Merchant,Category,Amount (QAR),Original amount,Currency,Type,Counted,Card,Account,Bank,Source,Note"]
        for x in d.transactions.sorted(by: { $0.date < $1.date }) {
            rows.append([key(x.date), x.noTime ? "" : Fmt.time(x.date), x.merchant, d.category(x.categoryID).name(lang),
                         String(format: "%.2f", x.amountHome), String(x.amount), x.currency, x.kind.rawValue, x.counts ? "yes" : "no",
                         x.card, x.account, x.bank, x.source.rawValue, x.note].map(q).joined(separator: ","))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n"
    }
}
