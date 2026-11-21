import Foundation

/// Screenshot mode for the simulator (`-masroufiDemo <screen> -masroufiLang ar|en -masroufiBG wine|navy|graphite`).
/// Uses sample data in memory and never touches the real data file.
enum Demo {
    static let args = ProcessInfo.processInfo.arguments

    static func value(_ flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var screen: String? { value("-masroufiDemo") }
    static var active: Bool { screen != nil }

    /// `-masroufiCardPose "flip,yaw,pitch,scale"` freezes the 3D card in one pose, to check in a screenshot that the
    /// widest poses are not cut off (flip in degrees; yaw/pitch are the drag offsets in radians).
    static var cardPose: (flip: Double, yaw: Float, pitch: Float, scale: Double)? {
        guard let v = value("-masroufiCardPose") else { return nil }
        let n = v.split(separator: ",").compactMap { Double($0) }
        guard n.count == 4 else { return nil }
        return (n[0], Float(n[1]), Float(n[2]), n[3])
    }

    static var obStep: Int {
        guard let s = screen, s.hasPrefix("ob"), let n = Int(s.dropFirst(2)) else { return 0 }
        return min(max(n, 0), 5)
    }

    static let sms = "Debit transaction of QAR 180.00 from Card ***5 at WOQOD - AL DAYEEN PS    DOHA from Current Account 01***000008 New Balance: QAR 4,318.40 If you suspect this transaction call 44192022"

    static var pasteText: String? {
        switch screen {
        case "ob1": return sms
        case "add-paste": return "Purchase of QAR 64.00 at SNOONU DOHA using card ***5 on 17/11/2026 13:20\n\nتم خصم مبلغ 92.25 ر.ق من بطاقتك المنتهية بـ 1234 لدى لولو هايبرماركت بتاريخ 17/11/2026"
        default: return nil
        }
    }

    static func data() -> AppData {
        var d = AppData()
        let s = screen ?? ""
        d.settings.language = value("-masroufiLang") == "en" ? .en : .ar
        d.settings.background = value("-masroufiBG") ?? "wine"
        d.settings.onboarded = !s.hasPrefix("ob")
        if s == "today-empty" || s.hasPrefix("ob") { return d }
        d.settings.monthlyBudget = 6000
        d.settings.salaryDay = 27
        d.lastAuto = s == "guide-off" ? nil : Date()

        let cal = Calendar.current, now = Date(), start = cal.startOfDay(for: now)
        let elapsed = now.timeIntervalSince(start)
        func today(_ f: Double) -> Date { start.addingTimeInterval(elapsed * f) }
        func ago(_ days: Int, _ hour: Int, _ minute: Int) -> Date {
            cal.date(byAdding: .day, value: -days, to: start)!.addingTimeInterval(Double(hour * 3600 + minute * 60))
        }
        func tx(_ id: String, _ date: Date, _ amount: Double, _ merchant: String, _ cat: String) -> Transaction {
            Transaction(id: id, date: date, amount: amount, amountHome: amount, merchant: merchant,
                        merchantKey: SMSParser.merchantKey(merchant), categoryID: cat, source: .manual)
        }
        var woqod = Ledger.transaction(from: SMSParser.parse(sms)!, raw: sms, data: d, now: now, live: false)
        woqod.id = "demo-woqod"
        woqod.date = today(0.3)
        d.transactions = [
            tx("d1", today(0.95), 23, "Starbucks · Lusail", "coffee"),
            tx("d2", today(0.75), 198, "Carrefour · City Center", "grocery"),
            tx("d3", today(0.5), 47.5, "Talabat", "food"),
            woqod,
            tx("d5", ago(1, 19, 5), 92.25, "Lulu Hypermarket", "grocery"),
            tx("d6", ago(1, 12, 40), 64, "Snoonu", "food"),
            tx("d7", ago(1, 8, 15), 120.55, "WOQOD · Lusail", "fuel"),
            tx("d8", ago(2, 21, 0), 349, "Ooredoo", "bills"),
            tx("d9", ago(2, 14, 30), 171.25, "Villaggio Mall", "shopping"),
            tx("d10", ago(3, 18, 10), 276.8, "Carrefour · City Center", "grocery"),
            tx("d11", ago(4, 10, 0), 85, "Karwa Taxi", "transport"),
            tx("d12", ago(5, 20, 0), 140, "Novo Cinemas", "entertainment"),
            tx("d13", ago(6, 9, 30), 312, "Al Meera", "grocery"),
            tx("d14", ago(7, 13, 0), 58.5, "Aster Pharmacy", "health"),
        ]
        return d
    }

    @MainActor
    static func apply(nav: Nav) {
        switch screen ?? "" {
        case "txs": nav.tab = .txs
        case "insights", "insights-day": nav.tab = .insights
        case "settings", "settings-notif": nav.tab = .settings
        case "detail": nav.path = [.detail("demo-woqod")]
        case "add": nav.sheet = .add(paste: false)
        case "add-paste": nav.sheet = .add(paste: true)
        case "newcat": nav.sheet = .newCategory(forTx: nil)
        case "budget": nav.sheet = .budget
        case "guide", "guide-off": nav.path = [.guide]
        case "rename": nav.path = [.detail("demo-woqod")]; nav.sheet = .rename("demo-woqod")
        case "newcat-barber": nav.sheet = .newCategory(forTx: nil)
        case "categories": nav.path = [.categories]
        default: break
        }
    }
}
