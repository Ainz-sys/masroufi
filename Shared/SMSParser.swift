import Foundation

/// Result of reading one bank SMS.
struct ParsedSMS {
    var kind: TxKind
    var amount: Double
    var currency: String
    var amountHome: Double
    var merchant: String
    var merchantKey: String
    var card: String
    var account: String
    var balance: Double?
    var date: Date?
    var hasTime: Bool
    var bank: String
    var normalized: String
}

// MARK: - Regex helpers

private func rx(_ pattern: String, caseInsensitive: Bool = true) -> NSRegularExpression {
    // Patterns are constants written below; a failure here is a programming error.
    try! NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : [])
}

private extension NSRegularExpression {
    func first(_ s: String) -> NSTextCheckingResult? {
        firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length))
    }
    func test(_ s: String) -> Bool { first(s) != nil }
    func all(_ s: String) -> [NSTextCheckingResult] {
        matches(in: s, range: NSRange(location: 0, length: (s as NSString).length))
    }
    func replace(_ s: String, with t: String) -> String {
        stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: t)
    }
}

private func group(_ m: NSTextCheckingResult, _ i: Int, in s: String) -> String? {
    guard i < m.numberOfRanges else { return nil }
    let r = m.range(at: i)
    guard r.location != NSNotFound else { return nil }
    return (s as NSString).substring(with: r)
}

// MARK: - Parser

/// Reads English and Arabic bank messages (QNB, QIB, CBQ, Doha Bank and similar Gulf formats).
enum SMSParser {
    static let toQAR: [String: Double] = ["QAR": 1, "USD": 3.64, "SAR": 0.9707, "AED": 0.9912, "KWD": 11.85, "BHD": 9.68,
                                          "OMR": 9.46, "EUR": 3.95, "GBP": 4.62, "EGP": 0.075, "INR": 0.0435, "TRY": 0.106]

    static let curSrc = #"QAR|QR|Q\.R\.?|US\$|USD|SAR|SR|AED|EUR|GBP|KWD|BHD|OMR|EGP|INR|TRY|\$|€|£|₹|₺|ر\.?\s?ق\.?|ر\.?\s?س\.?|ر\.?\s?ع\.?|د\.?\s?إ\.?|د\.?\s?ك\.?|د\.?\s?ب\.?|ج\.?\s?م\.?|ريال\s+قطري|ريال\s+سعودي|ريالات|ريال|درهم|دولار|يورو"#
    static let numSrc = #"\d{1,3}(?:,\d{3})+(?:\.\d{1,3})?|\d+(?:\.\d{1,3})?"#
    static let pairRE = rx("(?:(" + curSrc + ")\\s?(" + numSrc + "))|(?:(" + numSrc + ")\\s?(" + curSrc + ")(?![A-Za-z]))")

    static let curCodes: [(NSRegularExpression, String)] = [
        (rx(#"^(?:QAR|QR|Q\.R\.?|ر\.?\s?ق\.?|ريال(?:\s+قطري)?|ريالات?)$"#), "QAR"),
        (rx(#"^(?:SAR|SR|ر\.?\s?س\.?|ريال\s+سعودي)$"#), "SAR"),
        (rx(#"^(?:AED|د\.?\s?إ\.?|درهم)$"#), "AED"),
        (rx(#"^(?:USD|\$|US\$|دولار)$"#), "USD"),
        (rx(#"^(?:EUR|€|يورو)$"#), "EUR"),
        (rx(#"^(?:GBP|£)$"#), "GBP"),
        (rx(#"^(?:KWD|د\.?\s?ك\.?)$"#), "KWD"),
        (rx(#"^(?:BHD|د\.?\s?ب\.?)$"#), "BHD"),
        (rx(#"^(?:OMR|ر\.?\s?ع\.?)$"#), "OMR"),
        (rx(#"^(?:EGP|ج\.?\s?م\.?)$"#), "EGP"),
        (rx(#"^(?:INR|₹)$"#), "INR"),
        (rx(#"^(?:TRY|₺)$"#), "TRY"),
    ]

    static let skipRE = rx(#"\b(?:otp|one[\s-]?time\s+(?:password|passcode|pin)|verification\s+code|activation\s+code|do\s+not\s+share|never\s+share)\b|رمز\s+(?:التحقق|التفعيل|الدخول|سري)|كلمة\s+(?:المرور|السر)\s+لمرة|لا\s+تشارك"#)
    static let declinedRE = rx(#"\b(?:declined|unsuccessful|failed|rejected|insufficient|not\s+(?:been\s+)?(?:processed|completed|approved)|could\s+not)\b|مرفوض|رفض|لم\s+تتم|لم\s+يتم|غير\s+ناجح|فشل|رصيد\s+غير\s+كاف"#)
    static let creditRE = rx(#"\b(?:credited|credit(?!\s*card)(?:ed)?\s+(?:of|to|in)|deposit(?:ed)?|received|salary|refund(?:ed)?|reversal|reversed|cash\s*back|inward|transfer\s+from|added\s+to)\b|إيداع|ايداع|أودع|اودع|تمت?\s+إضافة|اضافة\s+مبلغ|راتب|استرداد|استرجاع|مرتجع|حوالة\s+واردة|تحويل\s+وارد|دائن"#)
    static let debitRE = rx(#"\b(?:debit(?:ed)?|purchase[sd]?|spent|paid|payment|withdrawn|withdrawal|atm|pos|used\s+(?:for|at)|charged|transfer(?:red)?\s+to|sent\s+to|outward|deducted)\b|شراء|مشتريات|خصم|سحب|دفع|سداد|مدين|حوالة\s+صادرة|تحويل\s+صادر|استخدام\s+بطاقت|تم\s+استخدام"#)
    static let promoRE = rx(#"\b(?:offer|promo|discount|win|enjoy|get\s+\d+%|cashback\s+up\s+to|apply\s+now|click|visit)\b|عرض|خصم\s+\d+\s?%|اربح|استمتع|سارع"#)
    static let strongRE = rx(#"\b(?:debited|credited|purchase\s+of|was\s+used|transaction\s+of|withdrawal\s+of|transferred|deposited|paid|spent)\b|تم\s+(?:خصم|إيداع|ايداع|سحب|تحويل|استخدام|شراء|دفع)|عملية\s+شراء|بمبلغ"#)
    static let atRE = rx(#"\b(?:at|@)\s"#)
    static let ladaRE = rx("لدى|عند")
    static let debitTxRE = rx(#"\bdebit\s+(?:transaction|card\s+transaction|purchase)"#)
    static let balBeforeRE = rx(#"(?:new\s+balance|avl\.?\s*bal(?:ance)?|available\s+(?:balance|limit|amount)|available|current\s+balance|closing\s+balance|ledger\s+balance|bal(?:ance)?|الرصيد(?:\s+(?:المتاح|المتوفر|الحالي|الجديد|المتبقي))?|رصيدك(?:\s+(?:المتاح|الحالي))?|المتاح|رصيد)\s*(?:is|:|=|-|هو)?\s*$"#)
    static let limitBeforeRE = rx(#"(?:limit|الحد)\s*(?:is|:)?\s*$"#)

    static let stopEN = #"(?:on|from|using|with|via|dated?|for|new\s+balance|avl|available|bal(?:ance)?\b|ref|reference|if\s+you|card|account|acct|a/c|thank|call|txn|\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}|qar\b|qr\b|usd\b|at\s+\d)"#
    static let merchantEN: [NSRegularExpression] = [
        rx(#"\b(?:at|@)\s+(.+?)(?=\s+"# + stopEN + #"|[.,;:!]\s|[;!]|$)"#),
        rx(#"\b(?:paid\s+to|payment\s+to|transfer(?:red)?\s+to|sent\s+to|to)\s+(.+?)(?=\s+"# + stopEN + #"|[.,;:!]\s|[;!]|$)"#),
        rx(#"\b(?:transfer\s+from|received\s+from|from)\s+(?!card|account|acct|a/c|your)(.+?)(?=\s+"# + stopEN + #"|[.,;:!]\s|[;!]|$)"#),
    ]
    static let stopAR = #"(?:بتاريخ|في\s+\d|بمبلغ|بقيمة|الرصيد|رصيد|المتاح|باستخدام|بواسطة|من\s+(?:حساب|بطاقة)|على\s+(?:حساب|بطاقة)|رقم|للاستفسار|يوم|الساعة|\d{1,2}[/.-]\d{1,2})"#
    static let merchantAR: [NSRegularExpression] = [
        rx(#"(?:لدى|عند|من\s+متجر|في\s+متجر|التاجر)\s*:?\s*(.+?)(?=\s+"# + stopAR + #"|[،,.؛]|$)"#),
        rx(#"(?:إلى|الى|لصالح)\s+(?!حساب|بطاقة)(.+?)(?=\s+"# + stopAR + #"|[،,.؛]|$)"#),
        rx(#"(?:في|من)\s+(?!حساب|بطاقة|رصيد|تاريخ|يوم)([A-Za-z][^،,.؛]*?)(?=\s+"# + stopAR + #"|[،,.؛]|$)"#),
    ]
    static let latin3RE = rx("[A-Za-z]{3}")
    static let latinRE = rx("[A-Za-z]")
    static let badStartRE = rx(#"^(?:your|the|you|card|account|qar|\d)"#)
    static let atmRE = rx(#"\batm\b|سحب\s+نقدي|صراف|cash\s*withdrawal"#)
    static let cardRE = rx(#"(?:card|بطاقة|بطاقتك)[^0-9*xX•]{0,24}(?:ending\s+(?:with\s+)?|no\.?\s*|المنتهية\s*(?:ب|بـ)?\s*|رقم\s*)?[*xX•.]*\s?(\d{1,4})\b"#)
    static let accountRE = rx(#"(?:account|acct|a/c|حساب|حسابك)[^0-9*xX]{0,24}[0-9*xX]*?(\d{3,4})\b"#)
    static let banks: [(NSRegularExpression, String)] = [
        (rx(#"\bQNB\b|قطر\s+الوطني"#), "QNB"), (rx(#"\bQIIB\b|الدولي\s+الإسلامي"#), "QIIB"), (rx(#"\bQIB\b|قطر\s+الإسلامي"#), "QIB"),
        (rx(#"\bCBQ\b|commercial\s*bank|التجاري"#), "CBQ"), (rx(#"doha\s*bank|بنك\s+الدوحة"#), "Doha Bank"), (rx("dukhan|دخان"), "Dukhan Bank"),
        (rx(#"al\s*rayan|الريان"#), "Masraf Al Rayan"), (rx(#"\bahli\b|الأهلي"#), "Ahli Bank"),
    ]
    static let trailRE = rx(#"(?:\s+(?:doha|qatar|qat|qa|w\.?l\.?l\.?|l\.?l\.?c\.?|co\.?|est\.?|ltd\.?|wll))+\s*$"#)
    static let dateRE = rx(#"(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})(?:[\s,T]+(?:at\s+)?(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm|ص|م)?)?"#)
    static let isoDateRE = rx(#"(\d{4})-(\d{2})-(\d{2})(?:[\sT]+(\d{1,2}):(\d{2}))?"#)
    static let splitRE = rx(#"\b(?:Debit|Credit|Purchase|Dear\s+Customer|Your\s+(?:card|account)|تم\s|عزيزي|عميلنا)\b"#)
    static let blankLineRE = rx(#"\n\s*\n"#)
    static let spacesRE = rx(#"\s+"#)

    // MARK: Normalisation

    private static let digits: [Character: Character] = [
        "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4", "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
        "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4", "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9",
        "٫": ".", "٬": ",",
    ]

    static func normalize(_ s: String) -> String {
        var out = ""
        for ch in s { out.append(digits[ch] ?? ch) }
        let scalars = out.unicodeScalars.filter { u in
            let v = u.value
            return !((0x200E...0x200F).contains(v) || (0x202A...0x202E).contains(v) || (0x2066...0x2069).contains(v))
        }
        out = String(String.UnicodeScalarView(scalars))
        return spacesRE.replace(out, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func currencyCode(_ token: String) -> String? {
        let t = token.trimmingCharacters(in: .whitespaces)
        for (r, code) in curCodes where r.test(t) { return code }
        return nil
    }

    static func cleanMerchant(_ input: String) -> String {
        var m = input.trimmingCharacters(in: CharacterSet(charactersIn: " :–-\t"))
        m = rx(#"\s{2,}"#).replace(m, with: " ")
        m = trailRE.replace(m, with: "")
        m = rx(#"\s+-\s+"#).replace(m, with: " · ")
        m = m.replacingOccurrences(of: "*", with: " ")
        m = spacesRE.replace(m, with: " ").trimmingCharacters(in: .whitespaces)
        guard latinRE.test(m) else { return m }
        let keepUpper: Set<String> = ["AL", "EL", "THE", "AND", "OF", "CITY", "MALL"]
        let words = m.split(separator: " ").map { w -> String in
            let s = String(w)
            if s == "·" || s.rangeOfCharacter(from: .decimalDigits) != nil { return s }
            if s.count >= 2, s.count <= 5, s == s.uppercased(), s.allSatisfy({ $0.isUppercase || $0 == "&" || $0 == "." }), !keepUpper.contains(s) { return s }
            return s.prefix(1).uppercased() + s.dropFirst().lowercased()
        }
        let joined = words.joined(separator: " ")
        return joined.count > 40 ? String(joined.prefix(40)) + "…" : joined
    }

    static func merchantKey(_ m: String) -> String {
        let up = rx(#"[^A-Z0-9؀-ۿ ]+"#, caseInsensitive: false).replace(m.uppercased(), with: " ")
        let t = up.split(separator: " ").map(String.init)
        guard let first = t.first else { return "" }
        let prefixes: Set<String> = ["AL", "EL", "THE", "ABU", "BIN", "DAR", "BAIT", "BEIT", "LA", "LE"]
        if prefixes.contains(first), t.count > 1 { return first + " " + t[1] }
        return first
    }

    static func findDate(_ s: String) -> (Date, Bool)? {
        var y = 0, mo = 0, d = 0, h = 0, mi = 0, hasTime = false
        if let m = dateRE.first(s) {
            d = Int(group(m, 1, in: s) ?? "") ?? 0
            mo = Int(group(m, 2, in: s) ?? "") ?? 0
            y = Int(group(m, 3, in: s) ?? "") ?? 0
            if y < 100 { y += 2000 }
            if mo > 12 && d <= 12 { swap(&d, &mo) }
            if let hh = group(m, 4, in: s), let h2 = Int(hh), let m2 = Int(group(m, 5, in: s) ?? "") {
                h = h2; mi = m2; hasTime = true
                let ap = (group(m, 7, in: s) ?? "").lowercased()
                if (ap == "pm" || ap == "م") && h < 12 { h += 12 }
                if (ap == "am" || ap == "ص") && h == 12 { h = 0 }
            }
        } else if let m = isoDateRE.first(s) {
            y = Int(group(m, 1, in: s) ?? "") ?? 0
            mo = Int(group(m, 2, in: s) ?? "") ?? 0
            d = Int(group(m, 3, in: s) ?? "") ?? 0
            if let hh = group(m, 4, in: s), let h2 = Int(hh), let m2 = Int(group(m, 5, in: s) ?? "") { h = h2; mi = m2; hasTime = true }
        } else { return nil }
        guard (1...12).contains(mo), (1...31).contains(d) else { return nil }
        let comps = DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)
        guard let date = Calendar.current.date(from: comps) else { return nil }
        return (date, hasTime)
    }

    /// Parses one SMS. Returns nil when it is not a completed money movement (OTP, declined, promo, balance only…).
    static func parse(_ raw: String, home: String = "QAR") -> ParsedSMS? {
        let s = normalize(raw)
        guard s.count >= 12, !skipRE.test(s), !declinedRE.test(s) else { return nil }
        let ns = s as NSString

        struct Pair { var cur: String; var val: Double; var at: Int; var end: Int; var isBal: Bool; var isLimit: Bool }
        var pairs: [Pair] = []
        for m in pairRE.all(s) {
            let curTok = group(m, 1, in: s) ?? group(m, 4, in: s) ?? ""
            let numTok = group(m, 2, in: s) ?? group(m, 3, in: s) ?? ""
            guard let cur = currencyCode(curTok), let val = Double(numTok.replacingOccurrences(of: ",", with: "")), val > 0 else { continue }
            let start = max(0, m.range.location - 32)
            let before = ns.substring(with: NSRange(location: start, length: m.range.location - start))
            pairs.append(Pair(cur: cur, val: val, at: m.range.location, end: m.range.location + m.range.length,
                              isBal: balBeforeRE.test(before), isLimit: limitBeforeRE.test(before)))
        }
        let txPairs = pairs.filter { !$0.isBal && !$0.isLimit }
        guard let main = txPairs.first else { return nil }

        let creditM = creditRE.first(s), debitM = debitRE.first(s)
        if promoRE.test(s) && !strongRE.test(s) { return nil }
        if creditM == nil && debitM == nil && !atRE.test(s) && !ladaRE.test(s) { return nil }

        let homePair = txPairs.first { $0.cur == home }
        let amountHome: Double
        if main.cur == home { amountHome = main.val }
        else if let hp = homePair { amountHome = hp.val }
        else { amountHome = (main.val * (toQAR[main.cur] ?? 1) * 100).rounded() / 100 }

        var kind: TxKind = .debit
        if let c = creditM, debitM == nil || c.range.location < debitM!.range.location { kind = .credit }
        if debitTxRE.test(s) { kind = .debit }

        var merchant = ""
        let pools = [ns.substring(from: main.end), s]
        outer: for pool in pools {
            let lists = latin3RE.test(pool) ? [merchantEN, merchantAR] : [merchantAR, merchantEN]
            for list in lists {
                for r in list {
                    if let mm = r.first(pool), let g = group(mm, 1, in: pool) {
                        let t = g.trimmingCharacters(in: .whitespaces)
                        if !badStartRE.test(t) && t.count >= 2 { merchant = g; break outer }
                    }
                }
            }
        }
        if merchant.isEmpty && atmRE.test(s) { merchant = "ATM" }
        merchant = cleanMerchant(merchant)

        let card = cardRE.first(s).flatMap { group($0, 1, in: s) } ?? ""
        let account = accountRE.first(s).flatMap { group($0, 1, in: s) } ?? ""
        let balance = pairs.first { $0.isBal }?.val
        let date = findDate(s)
        var bank = ""
        for (r, name) in banks where r.test(s) { bank = name; break }

        return ParsedSMS(kind: kind, amount: main.val, currency: main.cur, amountHome: (amountHome * 100).rounded() / 100,
                         merchant: merchant, merchantKey: merchantKey(merchant), card: card, account: account,
                         balance: balance, date: date?.0, hasTime: date?.1 ?? false, bank: bank, normalized: s)
    }

    /// Splits pasted text that may contain several messages.
    static func splitMessages(_ text: String) -> [String] {
        let chunks = blankLineRE.replace(text, with: "\u{1E}").components(separatedBy: "\u{1E}")
        var out: [String] = []
        for c in chunks {
            let ns = c as NSString
            var prev = 0
            for st in splitRE.all(c).map({ $0.range.location }) where st > prev {
                out.append(ns.substring(with: NSRange(location: prev, length: st - prev)))
                prev = st
            }
            out.append(ns.substring(from: prev))
        }
        return out.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.count > 12 }
    }

    // MARK: Categories

    static let rules: [(String, NSRegularExpression)] = [
        ("fuel", rx(#"WOQOD|QATAR\s*FUEL|PETROL|FUEL|GAS\s*STATION|\bPS\b|وقود|بترول|محطة"#)),
        ("grocery", rx(#"CARREFOUR|LULU|MEERA|MONOPRIX|SPINNEYS|FAMILY\s*FOOD|SAFARI|GRAND\s*HYPER|ANSAR|QUALITY|HYPER|SUPERMARKET|MARKET|GROCERY|BAQALA|TALABAT\s*MART|بقالة|سوق|هايبر"#)),
        ("coffee", rx(#"STARBUCKS|COSTA|TIM\s*HORTONS|CARIBOU|%|ARABICA|CAFE|COFFEE|KARAK|BLACK\s*CUP|قهوة|كافيه|كرك"#)),
        ("food", rx(#"TALABAT|SNOONU|DELIVEROO|RAFEEQ|CARRIAGE|MCDONALD|KFC|BURGER|PIZZA|SHAWARMA|SHAWERMA|RESTAURANT|\bREST\b|GRILL|KITCHEN|BAKERY|SUBWAY|HARDEE|SUSHI|مطعم|مطاعم|مشويات|شاورما|طلبات"#)),
        ("transport", rx(#"UBER|CAREEM|KARWA|METRO|QATAR\s*RAIL|BOLT|PARKING|MOWASALAT|TAXI|LIMO|مواصلات|كروة|تاكسي"#)),
        ("bills", rx(#"OOREDOO|VODAFONE|KAHRAMAA|QATAR\s*COOL|BILL|TELECOM|INTERNET|فاتورة|كهرماء|اوريدو|أوريدو|فودافون"#)),
        ("health", rx(#"PHARMACY|PHARMA|CLINIC|HOSPITAL|\bHMC\b|MEDICAL|DENTAL|ASTER|صيدلية|عيادة|مستشفى"#)),
        ("travel", rx(#"QATAR\s*AIRWAYS|AIRWAYS|AIRLINE|BOOKING\.COM|AGODA|EXPEDIA|HOTEL|AIRBNB|FLYDUBAI|FLYNAS|سفر|فندق|طيران"#)),
        ("entertainment", rx(#"NETFLIX|SPOTIFY|\bOSN\b|SHAHID|YOUTUBE|PLAYSTATION|STEAM|XBOX|CINEMA|NOVO|\bVOX\b|APPLE\.COM|ITUNES|GOOGLE\s*\*|ANGHAMI|ترفيه|سينما"#)),
        ("shopping", rx(#"AMAZON|NOON|SHEIN|NAMSHI|IKEA|H\s*&\s*M|ZARA|CENTREPOINT|\bMAX\b|MALL|VILLAGGIO|LANDMARK|APPLE\s*STORE|VIRGIN|JARIR|تسوق|مول"#)),
        ("education", rx(#"SCHOOL|UNIVERSITY|ACADEMY|COLLEGE|COURSE|UDEMY|COURSERA|مدرسة|جامعة|أكاديمية"#)),
        ("cash", rx(#"^ATM$|\bATM\b|CASH\s*WITHDRAWAL|سحب\s+نقدي|صراف"#)),
        ("transfer", rx(#"TRANSFER|FAWRAN|IBAN|تحويل|حوالة|فوران"#)),
    ]

    static func categorize(_ p: ParsedSMS, merchantMap: [String: String]) -> String {
        if !p.merchantKey.isEmpty, let c = merchantMap[p.merchantKey] { return c }
        if p.kind == .credit { return "income" }
        if atmRE.test(p.normalized) { return "cash" }
        return categorize(merchant: p.merchant, context: p.normalized)
    }

    static func categorize(merchant: String, context: String = "") -> String {
        for (id, r) in rules where r.test(merchant) { return id }
        let hay = merchant + " " + context
        for (id, r) in rules where id != "fuel" && r.test(hay) { return id }
        return "other"
    }
}
