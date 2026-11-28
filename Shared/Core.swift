import Foundation

// MARK: - Models

enum TxKind: String, Codable { case debit, credit }
enum TxSource: String, Codable { case sms, manual, applePay, receipt }
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
    /// The person's own name for it (optional, so older saved data still loads).
    var title: String? = nil
    /// "#رحلة_صلالة"-style tags, across categories.
    var tags: [String]? = nil
    /// false = logged automatically and still waiting for the person's look (review queue). nil/true = settled.
    var reviewed: Bool? = nil
    /// On money that came back (a reversal or refund): the purchase it was for.
    var refundOf: String? = nil
    /// On a purchase: how much of it came back, and when.
    var refunded: Double? = nil
    var refundedAt: Date? = nil
    /// The person said this incoming money is not a refund (so it is never linked again).
    var notRefund: Bool? = nil

    var isRefund: Bool { refundOf != nil }
    var refundedFully: Bool { (refunded ?? 0) >= amountHome - 0.011 }
    /// Counts toward spending (expenses that were not excluded or fully refunded).
    var counts: Bool { kind == .debit && !excluded && !refundedFully }
    /// What it costs in the end: the amount minus any refund.
    var spentHome: Double { counts ? max(0, amountHome - (refunded ?? 0)) : 0 }
    var needsReview: Bool { reviewed == false }
    /// Shown everywhere: the person's name for it, else the merchant read from the bank message.
    var displayName: String {
        if let t = title?.trimmingCharacters(in: .whitespaces), !t.isEmpty { return t }
        return merchant
    }
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
    /// "fixed" (rent, bills: the same every month) or "flex". nil = the default for this category.
    var group: String? = nil
    /// Unspent budget moves to the next month.
    var rollover: Bool = false

    init(id: String, nameAR: String, nameEN: String, symbol: String, color: String = "#A19DA8", monthlyBudget: Double? = nil,
         alertAt80: Bool = true, builtIn: Bool = false, group: String? = nil, rollover: Bool = false) {
        self.id = id; self.nameAR = nameAR; self.nameEN = nameEN; self.symbol = symbol; self.color = color
        self.monthlyBudget = monthlyBudget; self.alertAt80 = alertAt80; self.builtIn = builtIn
        self.group = group; self.rollover = rollover
    }

    static let fixedByDefault: Set<String> = ["bills", "rent", "subscriptions", "home"]
    var isFixed: Bool { group.map { $0 == "fixed" } ?? Category.fixedByDefault.contains(id) }

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
        group = try c.decodeIfPresent(String.self, forKey: .group)
        rollover = try c.decodeIfPresent(Bool.self, forKey: .rollover) ?? false
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

    /// Icons offered for categories, in groups (L10n key of the group title, icon names).
    struct IconGroup: Identifiable { let key: String; let icons: [String]; var id: String { key } }

    static let iconGroups: [IconGroup] = [
        IconGroup(key: "igFood", icons: ["food", "grocery", "coffee", "tea", "juice", "burger", "pizza", "shawarma", "chicken", "sushi", "meat", "fruit",
                    "bakery", "dessert", "donut", "cake", "icecream", "popcorn", "takeout"]),
        IconGroup(key: "igShop", icons: ["shopping", "online", "delivery", "card", "clothes", "dress", "shoes", "handbag", "watch", "sunglasses", "jewelry",
                    "ring", "gift", "flowers"]),
        IconGroup(key: "igCare", icons: ["barber", "haircut", "scissors", "nails", "makeup", "skincare", "soap", "toothbrush", "spa"]),
        IconGroup(key: "igSubs", icons: ["subscription", "tv", "movies", "music", "headphones", "games", "joystick", "news", "cloud", "internet", "signal",
                    "phone", "computer", "robot", "camera"]),
        IconGroup(key: "igMove", icons: ["car", "fuel", "taxi", "bus", "metro", "bike", "scooter", "parking", "wrench", "oil", "carwash", "fine", "travel",
                    "plane", "ship"]),
        IconGroup(key: "igHome", icons: ["home", "key", "door", "couch", "bed", "furniture", "plant", "cleaning", "laundry", "repair", "tools", "candle",
                    "bulb", "zap", "plug", "water", "gas", "receipt"]),
        IconGroup(key: "igHealth", icons: ["health", "doctor", "hospital", "dentist", "glasses", "syringe", "bandage", "heart", "gym"]),
        IconGroup(key: "igFamily", icons: ["kids", "baby", "teddy", "edu", "school", "backpack", "books", "pencil", "abacus", "dog", "cat", "pets"]),
        IconGroup(key: "igFun", icons: ["ticket", "theater", "football", "tennis", "bowling", "swim", "tent", "beach", "desert", "camel", "party", "balloon",
                   "puzzle", "guitar", "hotel", "luggage", "map", "kaaba"]),
        IconGroup(key: "igMoney", icons: ["cash", "bank", "coin", "invest", "transfer", "budget", "legal", "id", "mail", "work", "printer", "tax", "loan",
                     "charity", "mosque", "calendar"]),
        IconGroup(key: "igOther", icons: ["other", "smoking", "label", "palette", "shield", "globe", "chart"]),
    ]
    static var symbolChoices: [String] { iconGroups.flatMap { $0.icons } }

    /// Picks an icon from a category name the person types ("حلاق" → barber, "اشتراكات" → subscription, "Netflix" → tv).
    static func suggestIcon(for name: String) -> String? {
        let n = arabicFold(name.lowercased()).trimmingCharacters(in: .whitespaces)
        guard n.count >= 2 else { return nil }
        let words = n.split(whereSeparator: { " -_/,،.".contains($0) }).map(String.init)
        func matches(_ raw: String) -> Bool {
            let kw = arabicFold(raw.lowercased()).trimmingCharacters(in: .whitespaces)
            if kw.contains(" ") { return n.contains(kw) }
            if kw.unicodeScalars.allSatisfy({ $0.isASCII }) { // whole English words, plural allowed ("car" ≠ "card")
                return n.range(of: "\\b" + NSRegularExpression.escapedPattern(for: kw) + "(s|es)?\\b", options: .regularExpression) != nil
            }
            return words.contains { w in // Arabic: the word, with or without "ال", or a longer form of it ("اشتراكات")
                let bare = w.hasPrefix("ال") && w.count > 3 ? String(w.dropFirst(2)) : w
                return w == kw || bare == kw || (kw.count >= 4 && (w.hasPrefix(kw) || bare.hasPrefix(kw)))
            }
        }
        for (kws, icon) in iconKeywords where kws.contains(where: matches) { return icon }
        return nil
    }

    /// Folds Arabic spelling variants (أ/إ/آ → ا, ة → ه, ى → ي) and drops diacritics, so "إشتراك" matches "اشتراك".
    static func arabicFold(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "[\\u064B-\\u0652\\u0640]", with: "", options: .regularExpression)
        for (a, b) in [("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ة", "ه"), ("ى", "ي")] { t = t.replacingOccurrences(of: a, with: b) }
        return t
    }

    /// Checked in order: more specific words first.
    static let iconKeywords: [([String], String)] = [
        (["حلاق", "حلاقه", "صالون", "barber", "salon", "haircut"], "barber"),
        (["اظافر", "مناكير", "nail"], "nails"),
        (["مكياج", "تجميل", "makeup", "beauty", "cosmetic"], "makeup"),
        (["عطور", "عطر", "perfume", "عنايه", "skincare"], "skincare"),
        (["سبا", "مساج", "spa", "massage"], "spa"),
        (["اشتراك", "subscription", "subscriptions"], "subscription"),
        (["تسوق الكتروني", "تسوق اونلاين", "اونلاين", "اون لاين", "الكتروني", "online", "amazon", "امازون", "noon", "نون", "aliexpress", "temu", "shein", "شي ان"], "online"),
        (["توصيل", "delivery", "طلبات", "talabat", "snoonu", "سنونو"], "takeout"),
        (["نتفلكس", "netflix", "osn", "shahid", "شاهد", "تلفزيون", "tv"], "tv"),
        (["سينما", "افلام", "movie", "cinema", "vox", "novo"], "movies"),
        (["موسيقى", "سبوتيفاي", "spotify", "music", "anghami", "انغامي"], "music"),
        (["العاب", "ألعاب", "game", "playstation", "xbox", "steam", "بلايستيشن"], "games"),
        (["انترنت", "واي فاي", "internet", "wifi", "fiber", "فايبر"], "internet"),
        (["جوال", "هاتف", "موبايل", "phone", "mobile", "ooredoo", "اوريدو", "vodafone", "فودافون"], "phone"),
        (["ايكلاود", "icloud", "google one", "تخزين", "storage", "cloud"], "cloud"),
        (["ذكاء اصطناعي", "chatgpt", "claude", "openai", " ai"], "robot"),
        (["قهوه", "كافيه", "كوفي", "coffee", "cafe", "starbucks", "ستاربكس"], "coffee"),
        (["كرك", "شاي", "karak", "tea"], "tea"),
        (["عصير", "juice"], "juice"),
        (["برجر", "burger", "ماكدونالدز", "mcdonald"], "burger"),
        (["بيتزا", "pizza"], "pizza"),
        (["شاورما", "shawarma"], "shawarma"),
        (["حلويات", "حلا", "dessert", "sweets", "كيك", "cake"], "dessert"),
        (["مخبز", "خبز", "bakery", "bread"], "bakery"),
        (["لحم", "ملحمه", "قصاب", "butcher", "meat"], "meat"),
        (["فواكه", "خضار", "fruit", "vegetable"], "fruit"),
        (["مطعم", "مطاعم", "اكل", "طعام", "restaurant", "food", "dining"], "food"),
        (["بقاله", "سوبرماركت", "مقاضي", "grocery", "supermarket", "carrefour", "كارفور", "لولو", "lulu", "ميرة", "meera"], "grocery"),
        (["بطاقه", "بطاقات", "credit card", "card"], "card"),
        (["ملابس", "clothes", "fashion", "ازياء"], "clothes"),
        (["احذيه", "جزم", "shoes", "sneakers"], "shoes"),
        (["شنط", "حقائب", "bags", "handbag"], "handbag"),
        (["ساعات", "watch"], "watch"),
        (["مجوهرات", "ذهب", "jewel", "gold"], "jewelry"),
        (["هدايا", "هديه", "gift"], "gift"),
        (["ورد", "زهور", "flower"], "flowers"),
        (["تسوق", "shopping", "mall", "مول"], "shopping"),
        (["بنزين", "وقود", "fuel", "petrol", "woqod", "وقود"], "fuel"),
        (["تاكسي", "اوبر", "كروه", "taxi", "uber", "careem", "كريم", "karwa"], "taxi"),
        (["باص", "حافله", "bus"], "bus"),
        (["مترو", "metro"], "metro"),
        (["مواقف", "باركنق", "parking"], "parking"),
        (["مخالف", "مخالفات", "fine", "traffic"], "fine"),
        (["غسيل سياره", "car wash", "carwash"], "carwash"),
        (["صيانه", "تصليح", "maintenance", "service", "garage", "كراج"], "wrench"),
        (["سياره", "سيارات", "car", "auto"], "car"),
        (["طيران", "تذاكر طيران", "flight", "airline", "qatar airways"], "plane"),
        (["فندق", "فنادق", "hotel"], "hotel"),
        (["عمره", "حج", "umrah", "hajj"], "kaaba"),
        (["سفر", "رحلات", "رحله", "travel", "trip", "vacation"], "travel"),
        (["ايجار", "اجار", "rent"], "key"),
        (["اثاث", "furniture", "ikea", "ايكيا"], "furniture"),
        (["تنظيف", "خادمه", "cleaning", "maid"], "cleaning"),
        (["مغسله", "غسيل ملابس", "laundry"], "laundry"),
        (["كهرباء", "كهرما", "kahramaa", "electric"], "plug"),
        (["ماء", "مياه", "water"], "water"),
        (["غاز", "gas"], "gas"),
        (["فواتير", "فاتوره", "bills", "bill"], "receipt"),
        (["بيت", "منزل", "home", "house"], "home"),
        (["اسنان", "dentist", "dental"], "dentist"),
        (["نظارات", "عدسات", "optic", "glasses"], "glasses"),
        (["مستشفى", "hospital", "clinic", "عياده"], "hospital"),
        (["دكتور", "طبيب", "doctor"], "doctor"),
        (["صيدليه", "دواء", "ادويه", "pharmacy", "medicine", "صحه", "health"], "health"),
        (["نادي", "جيم", "رياضه", "gym", "fitness", "sport"], "gym"),
        (["رضيع", "حفاضات", "baby", "diaper"], "baby"),
        (["اطفال", "kids", "children", "toys", "العاب اطفال"], "kids"),
        (["مدرسه", "مدارس", "school"], "school"),
        (["كتب", "مكتبه", "books", "library", "jarir", "جرير"], "books"),
        (["دورات", "تعليم", "جامعه", "education", "course", "university"], "edu"),
        (["قطه", "قطط", "cat"], "cat"),
        (["كلب", "dog"], "dog"),
        (["حيوانات", "حيوان", "pet"], "pets"),
        (["تذاكر", "فعاليات", "ticket", "event"], "ticket"),
        (["كوره", "كرة", "football", "soccer"], "football"),
        (["كشته", "تخييم", "camping", "camp"], "tent"),
        (["بحر", "شاطئ", "beach"], "beach"),
        (["حفلات", "حفله", "مناسبات", "party", "wedding", "عرس"], "party"),
        (["ترفيه", "entertainment", "fun"], "theater"),
        (["صدقه", "تبرع", "زكاه", "خيري", "charity", "donation", "zakat"], "charity"),
        (["مسجد", "mosque"], "mosque"),
        (["استثمار", "اسهم", "invest", "stocks"], "invest"),
        (["ادخار", "توفير", "saving"], "coin"),
        (["قرض", "قروض", "اقساط", "loan", "installment"], "loan"),
        (["ضريبه", "رسوم", "tax", "fees"], "tax"),
        (["تحويل", "حوالات", "transfer", "remittance"], "transfer"),
        (["تامين", "insurance"], "shield"),
        (["عمل", "شغل", "مكتب", "work", "office"], "work"),
        (["دخان", "سجاير", "سجائر", "شيشه", "smoking", "cigarette", "vape"], "smoking"),
        (["كاش", "نقد", "cash", "atm", "سحب"], "cash"),
        (["بنك", "bank"], "bank"),
    ]
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
    /// The budget for one budget month (salary day to salary day). 0 = none.
    var monthlyBudget: Double = 0
    /// Older versions had a daily budget; it is only read once, to fill `monthlyBudget`.
    var dailyBudget: Double = 0
    var salaryDay: Int = 1
    var alert80: Bool = true
    var alert100: Bool = true
    var notifyEach: Bool = true
    var onboarded: Bool = false
    var background: String = "wine"
    /// "auto" (follows the iPhone's screen size), "s", "m" or "l".
    var textSize: String = "auto"
    /// "flex" (fixed + flexible + non-monthly) or "category" (a budget per category).
    var budgetMode: String = "flex"
    /// Planned fixed costs per month. 0 = estimate them from last month's fixed categories.
    var fixedPlanned: Double = 0
    /// Your first name, for the greeting ("" = no name).
    var name: String = ""

    init() {}
    init(from decoder: Decoder) throws { // tolerant of missing keys from older versions
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = try c.decodeIfPresent(Lang.self, forKey: .language) ?? .ar
        dailyBudget = try c.decodeIfPresent(Double.self, forKey: .dailyBudget) ?? 0
        if let m = try c.decodeIfPresent(Double.self, forKey: .monthlyBudget) {
            monthlyBudget = m
        } else if dailyBudget > 0 { // from a version with a daily budget: big amounts were really meant per month
            monthlyBudget = dailyBudget >= 1000 ? dailyBudget : (dailyBudget * 30).rounded()
        }
        salaryDay = try c.decodeIfPresent(Int.self, forKey: .salaryDay) ?? 1
        alert80 = try c.decodeIfPresent(Bool.self, forKey: .alert80) ?? true
        alert100 = try c.decodeIfPresent(Bool.self, forKey: .alert100) ?? true
        notifyEach = try c.decodeIfPresent(Bool.self, forKey: .notifyEach) ?? true
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
        background = try c.decodeIfPresent(String.self, forKey: .background) ?? "wine"
        textSize = try c.decodeIfPresent(String.self, forKey: .textSize) ?? "auto"
        budgetMode = try c.decodeIfPresent(String.self, forKey: .budgetMode) ?? "flex"
        fixedPlanned = try c.decodeIfPresent(Double.self, forKey: .fixedPlanned) ?? 0
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    }
}

struct PlannedExpense: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var icon: String = "calendar"
    var yearly: Double            // the whole yearly amount
    var month: Int = 1            // month it is due (1–12)
    /// Spending in this category counts here, not in the flexible part.
    var categoryID: String? = nil
    var monthly: Double { yearly / 12 }
}

struct MerchantBudget: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var icon: String = "shopping"
    var keys: [String]            // merchant keys counted together
    var amount: Double
}

struct AppData: Codable {
    var settings = Settings()
    var categories: [Category] = Category.defaults
    var merchantMap: [String: String] = [:]
    /// Names the person gave to merchants (merchant key → name), applied to new transactions from them too.
    var merchantNames: [String: String] = [:]
    var transactions: [Transaction] = []
    var notified: [String: [String]] = [:]
    var lastAuto: Date? = nil          // last transaction logged by the automation
    var lastAutoRun: Date? = nil       // last time the automation ran at all (even for a message that isn't a purchase)
    var autoConfirmed: Date? = nil     // the person said they finished setting the automation up
    var lastApplePay: Date? = nil      // last purchase logged by the Apple Pay (Wallet) automation
    var refundsChecked: Bool? = nil    // older reversals were linked to their purchases (1.3.1)
    /// Costs that don't come every month (car insurance, school fees): set aside a twelfth each month.
    var planned: [PlannedExpense] = []
    /// A budget for one or more merchants together ("Talabat + Snoonu").
    var merchantBudgets: [MerchantBudget] = []

    /// The automation counts as on once it has run, or once the person confirmed they set it up.
    var autoOn: Bool { lastAuto != nil || lastAutoRun != nil || autoConfirmed != nil }
    /// Set up, but no bank message has come through it yet.
    var autoWaiting: Bool { autoConfirmed != nil && lastAuto == nil && lastAutoRun == nil }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        categories = try c.decodeIfPresent([Category].self, forKey: .categories) ?? Category.defaults
        if categories.isEmpty { categories = Category.defaults }
        merchantMap = try c.decodeIfPresent([String: String].self, forKey: .merchantMap) ?? [:]
        merchantNames = try c.decodeIfPresent([String: String].self, forKey: .merchantNames) ?? [:]
        transactions = try c.decodeIfPresent([Transaction].self, forKey: .transactions) ?? []
        notified = try c.decodeIfPresent([String: [String]].self, forKey: .notified) ?? [:]
        lastAuto = try c.decodeIfPresent(Date.self, forKey: .lastAuto)
        lastAutoRun = try c.decodeIfPresent(Date.self, forKey: .lastAutoRun)
        autoConfirmed = try c.decodeIfPresent(Date.self, forKey: .autoConfirmed)
        lastApplePay = try c.decodeIfPresent(Date.self, forKey: .lastApplePay)
        refundsChecked = try c.decodeIfPresent(Bool.self, forKey: .refundsChecked)
        planned = try c.decodeIfPresent([PlannedExpense].self, forKey: .planned) ?? []
        merchantBudgets = try c.decodeIfPresent([MerchantBudget].self, forKey: .merchantBudgets) ?? []
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
        d.transactions.filter { $0.counts && $0.date >= from && $0.date < to }.reduce(0) { $0 + $1.spentHome }
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

    /// This budget month (salary day to salary day) against the monthly budget.
    /// Every counted transaction dated inside the month comes off the budget, whenever it was added:
    /// older bank messages pasted later, or a manual entry with an earlier date, are deducted too.
    struct Month: Equatable {
        var start: Date, end: Date
        var budget: Double          // 0 = no monthly budget
        var spent: Double
        var todaySpent: Double
        var todayCount: Int
        var daysLeft: Int           // today included
        var remaining: Double { budget - spent }
        var fraction: Double { budget > 0 ? spent / budget : 0 }
        /// What can still be spent per day for the rest of the month, today included.
        var perDay: Double { max(0, remaining) / Double(max(1, daysLeft)) }
    }

    static func month(_ d: AppData, now: Date = Date()) -> Month {
        let cy = cycle(salaryDay: d.settings.salaryDay, ref: now)
        let b = dayBounds(now)
        return Month(start: cy.start, end: cy.end, budget: max(0, d.settings.monthlyBudget),
                     spent: spent(d, from: cy.start, to: cy.end),
                     todaySpent: spent(d, from: b.start, to: b.end),
                     todayCount: d.transactions.filter { $0.date >= b.start && $0.date < b.end }.count,
                     daysLeft: max(1, cal.dateComponents([.day], from: b.start, to: cy.end).day ?? 1))
    }

    static func transactions(_ d: AppData, on day: Date) -> [Transaction] {
        let b = dayBounds(day)
        return d.transactions.filter { !$0.isRefund && $0.date >= b.start && $0.date < b.end }.sorted { $0.date > $1.date }
    }

    /// Builds a transaction from a parsed SMS. `live` = arriving now from the automation.
    /// `undated`: the day to use when an older, pasted message carries no date of its own.
    static func transaction(from p: ParsedSMS, raw: String, data: AppData, now: Date, live: Bool, undated: Date? = nil) -> Transaction {
        var date = now, noTime = false
        if p.date == nil, let day = undated, !cal.isDate(day, inSameDayAs: now) {
            date = cal.date(byAdding: .hour, value: 12, to: cal.startOfDay(for: day)) ?? day
            noTime = true
        }
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
                           source: .sms, title: data.merchantNames[p.merchantKey], reviewed: live ? false : nil)
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
        var merged = false
        for (p, raw) in items where !isDuplicate(d, p, now: now) {
            // the same purchase was already logged a moment ago by Apple Pay: add the bank's details to it instead
            if p.kind == .debit, let i = applePayMatch(d, amountHome: p.amountHome, now: now) {
                d.transactions[i].raw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                d.transactions[i].bank = p.bank
                if d.transactions[i].card.isEmpty { d.transactions[i].card = p.card }
                d.transactions[i].account = p.account
                d.transactions[i].balance = p.balance
                merged = true
                continue
            }
            let tx = transaction(from: p, raw: raw, data: d, now: now, live: true)
            d.transactions.append(tx)
            // money coming back for a purchase (a reversal or refund): linked to it, so it isn't spending or income
            if tx.kind == .credit { _ = linkRefund(&d, credit: d.transactions.count - 1, keyword: SMSParser.isRefundText(raw)) }
            r.added.append(d.transactions[d.transactions.count - 1])
        }
        if r.added.isEmpty {
            if merged { d.lastAuto = now; r.status = "merged"; return r }
            r.status = items.isEmpty ? "ignored" : "duplicate"; return r
        }
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

    /// 80% / 100% of the monthly budget, and of each category's monthly budget. Each alert fires once per budget month.
    static func checkAlerts(_ d: inout AppData, now: Date) -> [BudgetAlert] {
        var out: [BudgetAlert] = []
        let m = month(d, now: now)
        let cy = cycle(salaryDay: d.settings.salaryDay, ref: now)
        let cycleKey = "cycle-" + key(cy.start)
        var catFlags = Set(d.notified[cycleKey] ?? [])
        if m.budget > 0 {
            if m.spent > m.budget {
                if d.settings.alert100 && !catFlags.contains(monthOver) {
                    catFlags.formUnion([monthNear, monthOver]); out.append(BudgetAlert(kind: .over, spent: m.spent, budget: m.budget))
                }
            } else if m.spent >= 0.8 * m.budget && d.settings.alert80 && !catFlags.contains(monthNear) {
                catFlags.insert(monthNear); out.append(BudgetAlert(kind: .near, spent: m.spent, budget: m.budget))
            }
        }
        for c in d.categories {
            guard let budget = c.monthlyBudget, budget > 0, c.alertAt80 else { continue }
            let s = d.transactions.filter { $0.categoryID == c.id && $0.counts && $0.date >= cy.start && $0.date < cy.end }.reduce(0) { $0 + $1.spentHome }
            if s > budget {
                if !catFlags.contains(c.id + ":100") { catFlags.formUnion([c.id + ":80", c.id + ":100"]); out.append(BudgetAlert(kind: .categoryOver, spent: s, budget: budget, categoryID: c.id)) }
            } else if s >= 0.8 * budget && !catFlags.contains(c.id + ":80") {
                catFlags.insert(c.id + ":80"); out.append(BudgetAlert(kind: .categoryNear, spent: s, budget: budget, categoryID: c.id))
            }
        }
        d.notified[cycleKey] = Array(catFlags)
        for k in d.notified.keys where k.hasPrefix("day-") { d.notified[k] = nil }   // daily-budget flags of older versions
        let keys = d.notified.keys.sorted()   // "cycle-YYYY-MM-DD": oldest first
        if keys.count > 24 { for k in keys.prefix(keys.count - 24) { d.notified[k] = nil } }
        return out
    }

    static let monthNear = "month:80", monthOver = "month:100"

    /// After the monthly budget changes, its 80% / 100% alerts may fire again this month.
    static func resetMonthAlerts(_ d: inout AppData, now: Date = Date()) {
        let k = "cycle-" + key(cycle(salaryDay: d.settings.salaryDay, ref: now).start)
        d.notified[k]?.removeAll { $0 == monthNear || $0 == monthOver }
    }

    /// The day tracking really started: the cycle start, or the first transaction if that is later.
    static func trackingStart(_ d: AppData, cycleStart: Date) -> Date {
        guard let first = d.transactions.map(\.date).min() else { return cycleStart }
        return max(cycleStart, cal.startOfDay(for: first))
    }

    /// Re-cleans transactions saved by older versions (merchant names, categories). Returns true if anything changed.
    static func repair(_ d: inout AppData) -> Bool {
        var changed = false
        if d.refundsChecked != true { // once: link reversals that were logged as income before version 1.3.1
            d.refundsChecked = true
            changed = true
            let credits = d.transactions.indices.filter { d.transactions[$0].kind == .credit && d.transactions[$0].refundOf == nil }
                .sorted { d.transactions[$0].date < d.transactions[$1].date }
            for i in credits { _ = linkRefund(&d, credit: i, keyword: SMSParser.isRefundText(d.transactions[i].raw)) }
        }
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
        var rows = ["Date,Time,Name,Category,Amount (QAR),Original amount,Currency,Type,Counted,Card,Account,Bank,Source,Note,Merchant in message"]
        for x in d.transactions.sorted(by: { $0.date < $1.date }) {
            rows.append([key(x.date), x.noTime ? "" : Fmt.time(x.date), x.displayName, d.category(x.categoryID).name(lang),
                         String(format: "%.2f", x.amountHome), String(x.amount), x.currency, x.kind.rawValue, x.counts ? "yes" : "no",
                         x.card, x.account, x.bank, x.source.rawValue, x.note, x.merchant].map(q).joined(separator: ","))
        }
        return "\u{FEFF}" + rows.joined(separator: "\r\n") + "\r\n"
    }
}
