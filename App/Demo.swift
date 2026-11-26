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
        let ar = value("-masroufiLang") != "en"
        d.settings.language = ar ? .ar : .en
        d.settings.background = value("-masroufiBG") ?? "wine"
        d.settings.onboarded = !s.hasPrefix("ob")
        if s == "today-empty" || s.hasPrefix("ob") { return d }

        let cal = Calendar.current, now = Date(), start = cal.startOfDay(for: now)
        // a budget month that started 13 days ago, so every screen shows a month in progress
        let cycleStartDay = cal.component(.day, from: cal.date(byAdding: .day, value: -13, to: start)!)
        d.settings.salaryDay = min(28, cycleStartDay)
        d.settings.monthlyBudget = 15000
        d.settings.name = ar ? "بو فهد" : "Fahad"
        d.lastAuto = s == "guide-off" ? nil : now
        d.lastApplePay = now.addingTimeInterval(-3600)

        d.categories.insert(Category(id: "cbarber", nameAR: "حلاق وعناية", nameEN: "Barber & care", symbol: "barber", color: "#3CC6B5", monthlyBudget: 250), at: 6)
        d.categories.insert(Category(id: "cins", nameAR: "تأمين", nameEN: "Insurance", symbol: "shield", color: "#B39DFF"), at: 7)
        for i in d.categories.indices {
            switch d.categories[i].id {
            case "food": d.categories[i].monthlyBudget = 1000
            case "grocery": d.categories[i].monthlyBudget = 1800; d.categories[i].rollover = true
            default: break
            }
        }
        d.planned = [PlannedExpense(id: "demo-ins", name: ar ? "تأمين السيارة" : "Car insurance", icon: "car", yearly: 2400, month: 3, categoryID: "cins")]
        d.merchantBudgets = [MerchantBudget(id: "demo-mb", name: ar ? "توصيل (طلبات + سنونو)" : "Delivery (Talabat + Snoonu)", icon: "takeout",
                                            keys: [SMSParser.merchantKey("Talabat"), SMSParser.merchantKey("Snoonu")], amount: 300)]

        var seed: UInt64 = 7
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
        func amt(_ lo: Double, _ hi: Double) -> Double { ((lo + (hi - lo) * rnd()) * 4).rounded() / 4 }
        var txs: [Transaction] = []
        var n = 0
        func add(_ date: Date, _ amount: Double, _ merchant: String, _ cat: String, kind: TxKind = .debit, source: TxSource = .sms,
                 title: String? = nil, tags: [String]? = nil, reviewed: Bool? = nil, id: String? = nil) {
            n += 1
            txs.append(Transaction(id: id ?? "demo\(n)", date: date, amount: amount, amountHome: amount, kind: kind, merchant: merchant,
                                   merchantKey: SMSParser.merchantKey(merchant), categoryID: cat, card: "4458", bank: source == .applePay ? "Apple Pay" : "QNB",
                                   source: source, title: title, tags: tags, reviewed: reviewed))
        }
        let names: [String: String] = ar ? ["Snoonu": "سنونو", "Talabat": "طلبات", "Karak Al Doha": "كرك الضحى", "Elegance Salon": "صالون الأناقة"] : [:]
        func at(_ day: Date, _ h: Int, _ m: Int) -> Date { day.addingTimeInterval(Double(h * 3600 + m * 60)) }

        // the current budget month and the three before it
        var cy = Ledger.cycle(salaryDay: d.settings.salaryDay, ref: now)
        for back in 0..<4 {
            let k = back == 0 ? 0.92 : 1.0 + 0.06 * Double(back % 2)   // a slightly calmer month this time
            add(at(cy.start, 7, 0), 22500, "Salary", "income", kind: .credit, title: ar ? "الراتب" : "Salary")
            add(at(cy.start, 10, 0), 4500, "Rent Al Sadd", "home", title: ar ? "الإيجار" : "Rent")
            if let d3 = cal.date(byAdding: .day, value: 2, to: cy.start), d3 < now { add(at(d3, 9, 0), 349, "Ooredoo", "bills") }
            if let d5 = cal.date(byAdding: .day, value: 4, to: cy.start), d5 < now { add(at(d5, 1, 10), 56, "Netflix", "bills") }
            for i in 0..<cy.days {
                guard let day = cal.date(byAdding: .day, value: i, to: cy.start), day <= start else { break }
                let isToday = day == start
                if isToday { continue }   // today's transactions are added below
                if rnd() < 0.75 { let m = rnd() < 0.5 ? "Starbucks Lusail" : "Karak Al Doha"; add(at(day, 8, Int(rnd() * 50)), amt(3, 26), m, "coffee", source: .applePay, title: names[m]) }
                if i % 2 == 0 { add(at(day, 19, 10), amt(70, 320) * k, ["Carrefour City Center", "Lulu Hypermarket", "Al Meera", "Monoprix"][Int(rnd() * 4)], "grocery") }
                if i % 3 == 1 { let m = rnd() < 0.5 ? "Talabat" : "Snoonu"; add(at(day, 13, 20), amt(35, 95) * k, m, "food", title: names[m]) }
                if i % 7 == 3 { add(at(day, 7, 15), amt(120, 180), "WOQOD Al Dayeen", "fuel") }
                if i % 9 == 5 { add(at(day, 17, 40), amt(150, 460) * k, rnd() < 0.5 ? "Villaggio Mall" : "Amazon", "shopping", tags: back == 2 ? ["رحلة_صلالة"] : nil) }
                if i % 6 == 2 { add(at(day, 22, 5), amt(25, 85), "Karwa Taxi", "transport") }
                if i % 12 == 8 { add(at(day, 20, 30), amt(90, 220), "Novo Cinemas", "entertainment") }
                if i % 14 == 4 { add(at(day, 18, 0), 60, "Elegance Salon", "cbarber", source: .applePay, title: names["Elegance Salon"]) }
                if i % 10 == 6 { add(at(day, 11, 0), amt(40, 160), "Aster Pharmacy", "health") }
                // a busier delivery week right now (for the home screen's note)
                if back == 0 && i >= cy.days - 30 && cal.dateComponents([.day], from: day, to: start).day ?? 9 <= 6 && i % 3 != 1 {
                    let m = rnd() < 0.5 ? "Snoonu" : "Talabat"
                    add(at(day, 21, 0), amt(45, 90), m, "food", title: names[m])
                }
            }
            cy = Ledger.previousCycle(d, before: cy.start)
        }

        // today: three still waiting for a look, and the bank message used on the detail screen
        let elapsed = now.timeIntervalSince(start)
        func today(_ f: Double) -> Date { start.addingTimeInterval(elapsed * f) }
        var woqod = Ledger.transaction(from: SMSParser.parse(sms)!, raw: sms, data: d, now: now, live: false)
        woqod.id = "demo-woqod"
        woqod.date = today(0.3)
        txs.append(woqod)
        add(today(0.9), 64, "Snoonu", "food", title: names["Snoonu"], reviewed: false, id: "demo-snoonu")
        add(today(0.6), 3, "Karak Al Doha", "coffee", source: .applePay, title: names["Karak Al Doha"], reviewed: false)
        add(today(0.45), 60, "Elegance Salon", "cbarber", source: .applePay, title: names["Elegance Salon"], reviewed: false)
        d.transactions = txs
        d.merchantMap[SMSParser.merchantKey("Snoonu")] = "food"
        return d
    }

    @MainActor
    static func apply(nav: Nav) {
        switch screen ?? "" {
        case "txs": nav.tab = .txs
        case "txs-review": nav.tab = .txs; nav.txFilter = "@review"
        case "plan": nav.tab = .plan
        case "planned": nav.tab = .plan; nav.sheet = .planned("demo-ins")
        case "mb": nav.tab = .plan; nav.sheet = .merchantBudget("demo-mb")
        case "fixed": nav.tab = .plan; nav.sheet = .fixedPlan
        case "analytics", "analytics-trends", "analytics-cal", "insights", "insights-day": nav.tab = .analytics
        case "settings", "settings-notif": nav.path = [.settings]
        case "review": nav.path = [.review]
        case "pick": nav.path = [.review]; nav.sheet = .pickCategory("demo-snoonu", review: true)
        case "detail": nav.path = [.detail("demo-woqod")]
        case "add", "add-receipt": nav.sheet = .add(paste: false)
        case "add-paste": nav.sheet = .add(paste: true)
        case "newcat": nav.sheet = .newCategory(forTx: nil)
        case "editcat": nav.sheet = .editCategory("grocery")
        case "budget": nav.sheet = .budget
        case "guide", "guide-off": nav.path = [.guide]
        case "rename": nav.path = [.detail("demo-woqod")]; nav.sheet = .rename("demo-woqod")
        case "newcat-barber": nav.sheet = .newCategory(forTx: nil)
        case "categories": nav.path = [.categories]
        default: break
        }
    }
}
