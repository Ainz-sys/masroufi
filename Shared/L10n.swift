import Foundation

/// In-app Arabic / English strings (same copy as the approved design). `{x}` placeholders are filled by `L10n.t`.
enum L10n {
    static let table: [String: (String, String)] = [
        "app": ("مصروفي", "Masroufi"),
        "today": ("اليوم", "Today"), "txs": ("العمليات", "Transactions"), "insights": ("التحليل", "Insights"), "settings": ("الإعدادات", "Settings"),
        "cur": ("ر.ق", "QAR"), "of": ("من", "of"), "spent": ("صرفت", "Spent"),
        "spentToday": ("مصروف اليوم", "Spent today"), "remainingToday": ("متبقٍّ لك اليوم", "Left for today"), "leftToday": ("متبقٍّ اليوم", "Left today"),
        "remainingMonth": ("متبقٍّ لك هذا الشهر", "Left this month"), "leftMonth": ("متبقٍّ هذا الشهر", "Left this month"),
        "spentMonth": ("صرفت هذا الشهر", "Spent this month"), "monthly": ("الميزانية الشهرية", "Monthly budget"),
        "perDayLeft": ("≈ {d} ر.ق لكل يوم · باقي {n}", "≈ QAR {d} a day · {n} left"), "renewsIn": ("تتجدد الميزانية بعد {n}", "Budget renews in {n}"),
        "perDayShare": ("حصة كل يوم", "Per day"),
        "didSetup": ("أعددتها ✓", "I’ve set it up ✓"), "didSetupNext": ("أعددتها ✓ التالي", "I’ve set it up ✓ Next"),
        "openAgain": ("افتح الاختصارات مرة ثانية", "Open Shortcuts again"), "alreadySet": ("أعددتها من قبل", "I’ve already set it up"),
        "autoMarked": ("تمام! أول رسالة شراء من بنكك تتسجّل تلقائياً", "All set: your next purchase message is logged automatically"),
        "autoWaiting": ("مفعّل · بانتظار أول رسالة", "On · waiting for the first message"), "lastRun": ("آخر رسالة وصلت", "Last message received"),
        "textSize": ("حجم الخط", "Text size"), "tsAuto": ("تلقائي", "Auto"), "tsS": ("صغير", "Small"), "tsM": ("متوسط", "Medium"), "tsL": ("كبير", "Large"),
        "tsAutoHint": ("يكبر في الآيفونات الكبيرة ويصغر في الصغيرة.", "Larger on bigger iPhones, smaller on smaller ones."),
        "iconHint": ("نختارها لك من الاسم، وتقدر تغيّرها", "picked from the name, change it anytime"),
        "igFood": ("أكل ومشروبات", "Food & drinks"), "igShop": ("تسوق", "Shopping"), "igCare": ("عناية شخصية", "Personal care"),
        "igSubs": ("اشتراكات وتقنية", "Subscriptions & tech"), "igMove": ("مواصلات وسيارة", "Transport & car"),
        "igHome": ("البيت والفواتير", "Home & bills"), "igHealth": ("صحة", "Health"), "igFamily": ("عائلة وتعليم", "Family & education"),
        "igFun": ("ترفيه وسفر", "Fun & travel"), "igMoney": ("مال وعمل", "Money & work"), "igOther": ("أخرى", "Other"),
        "rename": ("تغيير الاسم", "Rename"), "txName": ("اسم العملية", "Transaction name"),
        "origName": ("الاسم في رسالة البنك: {m}", "Name in the bank message: {m}"),
        "renameAll": ("استخدم هذا الاسم لكل عمليات هذا التاجر، الحالية واللي بتجي", "Use this name for every transaction from this merchant, now and later"),
        "restoreName": ("رجّع الاسم الأصلي", "Restore the original name"),
        "chartHint": ("اضغط على أي يوم لتشوف عملياته", "Tap a day to see its transactions"),
        "txCount": ("{n} عمليات", "{n} transactions"), "dayTx": ("عمليات {d}", "Transactions on {d}"), "noDayTx": ("ما فيه عمليات في هذا اليوم", "No transactions that day"),
        "notifications": ("الإشعارات", "Notifications"), "notifStatus": ("إشعارات مصروفي", "Masroufi notifications"),
        "notifOnS": ("مفعّلة", "On"), "notifOffS": ("مطفأة", "Off"), "notifAsk": ("فعّلها", "Turn on"),
        "testNotif": ("أرسل إشعار تجربة", "Send a test notification"), "testNotifT": ("مصروفي", "Masroufi"),
        "testNotifB": ("هذا شكل الإشعار اللي يوصلك مع كل عملية ✓", "This is how each transaction will reach you ✓"),
        "notifFoot": ("تنبيهات ميزانية كل فئة تضبطها من صفحة الفئة نفسها.", "Budget alerts for each category are set on that category’s page."), "undatedDay": ("تاريخ الرسائل اللي ما فيها تاريخ", "Date for messages without one"), "monthHint": ("كل عملية في هذا الشهر تنخصم منها، حتى العمليات القديمة اللي تضيفها بعدين بتاريخها.", "Every transaction this month comes off it, including older ones you add later with their date."),
        "ok": ("ضمن الميزانية", "Within budget"), "near": ("قربت من الحد", "Close to limit"), "over": ("تجاوزت بـ", "Over by"), "overShort": ("تجاوزت", "Over"),
        "spentOf": ("صرفت {s} من {b}", "Spent {s} of {b}"),
        "todayTx": ("عمليات اليوم", "Today's transactions"), "all": ("الكل", "All"),
        "noTodayT": ("ما فيه عمليات اليوم", "No transactions today"),
        "noTodayP": ("أول ما توصلك رسالة من البنك تظهر هنا تلقائياً.", "As soon as your bank texts you, it shows up here automatically."),
        "addManual": ("أضف يدوياً", "Add manually"), "setupAuto": ("فعّل التسجيل التلقائي", "Turn on auto-logging"),
        "autoOff": ("التسجيل التلقائي غير مفعّل بعد", "Auto-logging is not on yet"),
        "search": ("ابحث عن تاجر أو مبلغ", "Search merchant or amount"), "allCats": ("الكل", "All"), "yesterday": ("أمس", "Yesterday"),
        "noTxT": ("ما فيه عمليات", "No transactions"), "noTxP": ("جرّب تغيير البحث أو الفئة.", "Try another search or category."),
        "tx": ("العملية", "Transaction"), "card": ("البطاقة", "Card"), "account": ("الحساب", "Account"), "balanceAfter": ("الرصيد بعدها", "Balance after"),
        "bank": ("البنك", "Bank"), "source": ("المصدر", "Source"), "sms": ("رسالة SMS", "SMS"), "manual": ("يدوي", "Manual"),
        "category": ("الفئة", "Category"), "newCat": ("فئة جديدة", "New category"),
        "remember": ("تذكّر «{c}» لكل عمليات {m}", "Remember “{c}” for all {m}"), "include": ("احسبها ضمن المصروف", "Count as spending"),
        "note": ("ملاحظة", "Note"), "notePh": ("أضف ملاحظة…", "Add a note…"), "bankMsg": ("رسالة البنك", "Bank message"),
        "autoRead": ("المظلَّل قُرئ تلقائياً", "Highlighted = read automatically"),
        "del": ("حذف العملية", "Delete transaction"), "delQ": ("متأكد؟ اضغط مرة ثانية للحذف", "Sure? Tap again to delete"),
        "expense": ("مصروف", "Expense"), "income": ("دخل", "Income"), "cancel": ("إلغاء", "Cancel"), "add": ("إضافة", "Add"),
        "save": ("حفظ", "Save"), "done": ("تم", "Done"), "name": ("الاسم", "Name"), "icon": ("الأيقونة", "Icon"), "color": ("اللون", "Color"),
        "catBudget": ("ميزانية شهرية للفئة (اختياري)", "Monthly budget (optional)"), "alert80": ("نبّهني عند 80٪ من ميزانيتها", "Alert me at 80% of it"),
        "addCat": ("إضافة الفئة", "Add category"), "addTx": ("إضافة عملية", "Add transaction"), "amount": ("المبلغ", "Amount"),
        "merchant": ("التاجر أو الوصف", "Merchant or description"), "when": ("الوقت", "Time"), "paste": ("لصق رسالة", "Paste SMS"),
        "manualTab": ("يدوي", "Manual"), "pastePh": ("الصق رسالة أو أكثر من بنكك هنا…", "Paste one or more bank messages here…"),
        "found": ("وجدنا {n} عمليات", "Found {n} transactions"), "addN": ("أضف {n} عمليات", "Add {n} transactions"),
        "notFound": ("ما قدرنا نقرأ عملية من هذا النص", "Couldn't read a transaction from this text"),
        "appearance": ("المظهر", "Appearance"), "bg": ("الخلفية", "Background"), "bgWine": ("عنابي عميق", "Deep maroon"),
        "bgNavy": ("كحلي ليلي", "Night navy"), "bgGraphite": ("فحمي دافئ", "Warm graphite"), "language": ("اللغة", "Language"),
        "budget": ("الميزانية", "Budget"), "daily": ("الميزانية اليومية", "Daily budget"), "salaryDay": ("يوم نزول الراتب", "Salary day"),
        "alerts": ("التنبيهات", "Alerts"), "perTx": ("إشعار مع كل عملية", "Notify on every transaction"), "categories": ("الفئات", "Categories"),
        "auto": ("التسجيل التلقائي", "Auto-logging"), "guide": ("دليل الإعداد", "Setup guide"), "data": ("البيانات", "Data"),
        "export": ("تصدير CSV", "Export CSV"), "pasteOld": ("لصق رسائل قديمة", "Paste old messages"), "on": ("مفعّل", "On"), "notYet": ("غير مفعّل بعد", "Not on yet"),
        "lastAuto": ("آخر تسجيل تلقائي", "Last auto-logged"), "cycle": ("دورة الميزانية", "Budget cycle"), "cycleSpent": ("صرفت في الدورة", "Spent this cycle"),
        "dailyAvg": ("متوسط اليوم", "Daily average"), "projected": ("المتوقع للدورة", "Projected"), "vsPrev": ("مقارنة بالدورة السابقة", "vs previous cycle"),
        "byCat": ("حسب الفئة", "By category"), "topMerchants": ("أكثر التجار", "Top merchants"), "perDay": ("كل يوم", "Per day"),
        "budgetLine": ("الخط = ميزانية الشهر ÷ أيامه", "Line = monthly budget ÷ days"), "noData": ("ما فيه بيانات كافية بعد", "Not enough data yet"),
        "start": ("ابدأ", "Start"), "next": ("التالي", "Next"), "skip": ("تخطّي", "Skip"), "later": ("سأفعلها لاحقاً", "I'll do it later"),
        "openShortcuts": ("افتح الاختصارات", "Open Shortcuts"), "enterApp": ("ادخل التطبيق", "Enter the app"),
        "enableAlerts": ("فعّل التنبيهات", "Turn on alerts"), "notNow": ("ليس الآن", "Not now"),
        "ob1t": ("مصروفك اليومي…\nيُحسب لحاله", "Your daily spending…\ncounted for you"),
        "ob1p": ("يقرأ رسائل بنكك ويسجّل كل عملية تلقائياً، ويقول لك كم باقي من ميزانية الشهر.", "Reads your bank texts, logs every transaction automatically, and tells you what is left of this month's budget."),
        "v1": ("بدون إدخال يدوي", "No manual entry"), "v2": ("فئاتك وميزانيتك أنت تحددها", "Your own categories and budget"), "v3": ("بياناتك على جهازك فقط", "Your data stays on your phone"),
        "ob2t": ("جرّب بنفسك", "Try it"), "ob2p": ("انسخ أي رسالة من بنكك والصقها هنا، وشوفها تتحوّل لعملية.", "Copy any message from your bank and paste it here to see it become a transaction."),
        "addToMine": ("أضفها لعملياتي", "Add it to my transactions"), "added": ("أُضيفت ✓", "Added ✓"),
        "ob3t": ("فعّل التسجيل التلقائي", "Turn on auto-logging"),
        "ob3p": ("الآيفون لا يسمح للتطبيقات بقراءة الرسائل، فنستخدم «أتمتة» في تطبيق الاختصارات. تُعدّ مرة واحدة وتأخذ دقيقة.", "iPhone doesn't let apps read messages, so we use an automation in the Shortcuts app. Set it up once — it takes a minute."),
        "st1": ("في «الاختصارات» افتح «الأتمتة» ثم + واختر «رسالة».", "In Shortcuts, open Automation, tap + and choose Message."),
        "st2": ("في «المرسل» اختر اسم أو رقم بنكك (مثل QNB)، ثم اختر «تشغيل فوراً».", "Under Sender, choose your bank’s name or number (e.g. QNB), then choose Run Immediately."),
        "st3": ("اختياري: في «تحتوي الرسالة على» اكتب كلمة تجي بس في رسائل الشراء (مثل New Balance)، عشان ما تشتغل مع رسائل رمز التحقق.", "Optional: under Message Contains, type a word that only appears in purchase messages (e.g. New Balance), so it doesn’t run on verification-code messages."),
        "st4": ("أضف الإجراء «سجّل رسالة البنك» من مصروفي.", "Add the “Log bank message” action from Masroufi."),
        "st5": ("اضغط «الرسالة» واختر «مُدخل الاختصار»، ثم اضغط عليه مرة ثانية واختر «المحتوى».", "Tap Message and choose Shortcut Input, then tap it again and choose Content."),
        "st6": ("عندك أكثر من بنك؟ كرّر الأتمتة لكل مرسل.", "More than one bank? Repeat it for each sender."),
        "tip": ("نصيحة: أطفئ «الإشعار عند التشغيل» في الأتمتة؛ مصروفي يرسل لك إشعاره الخاص.", "Tip: turn off “Notify When Run” — Masroufi sends its own notification."),
        "ob4t": ("كم ميزانيتك الشهرية؟", "What is your monthly budget?"), "ob4p": ("كل عملية تنخصم منها، حتى العمليات القديمة اللي تضيفها بعدين. تقدر تغيّرها بأي وقت.", "Every transaction comes off it, including older ones you add later. Change it anytime."),
        "monthBudget": ("ميزانية الدورة", "Cycle budget"),
        "salaryHint": ("يبدأ شهر الميزانية من يوم الراتب، فتعرف كم باقي لين الراتب الجاي.", "Your budget month starts on salary day, so you know what is left until the next one."),
        "ob5t": ("نبّهني قبل ما أتجاوز", "Warn me before I overspend"),
        "ob5p": ("إشعار عند 80٪ و100٪ من ميزانية الشهر، وتأكيد مع كل عملية.", "A notification at 80% and 100% of your monthly budget, plus a confirmation for each transaction."),
        "ob6t": ("بياناتك لك", "Your data is yours"),
        "ob6p": ("كل شيء محفوظ على جوالك فقط. لا خوادم، لا حسابات، والتطبيق لا يتصل بالإنترنت. وتقدر تصدّرها CSV متى شئت.", "Everything stays on your phone. No servers, no accounts, and the app never goes online. Export to CSV anytime."),
        "saved": ("تم الحفظ", "Saved"), "testIt": ("اختبر قراءة رسالة", "Test reading a message"),
        "credits": ("الأيقونات: Microsoft Fluent Emoji 3D (MIT) · الخط: Alexandria (OFL)", "Icons: Microsoft Fluent Emoji 3D (MIT) · Font: Alexandria (OFL)"),
        "version": ("الإصدار 1.3.1", "Version 1.3.1"), "wipe": ("حذف كل البيانات", "Delete all data"),
        "wipeQ": ("سيُحذف كل شيء نهائياً. اضغط مرة ثانية للتأكيد", "Everything will be deleted. Tap again to confirm"),
        "editCat": ("تعديل الفئة", "Edit category"), "delCat": ("حذف الفئة", "Delete category"), "builtin": ("أساسية", "Built-in"),
        "thisCycle": ("هذه الدورة", "This cycle"), "alert80d": ("تنبيه عند 80٪ من ميزانية الشهر", "Alert at 80% of monthly budget"),
        "alert100d": ("تنبيه عند تجاوز الميزانية", "Alert when over budget"), "overBy2": ("فوق الميزانية بـ {n}", "{n} over budget"),
        "underBy2": ("تحت الميزانية بـ {n}", "{n} under budget"), "replay": ("إعادة الشاشات الترحيبية", "Replay welcome screens"),
        "week": ("آخر 7 أيام", "Last 7 days"),
        "notifOff": ("التنبيهات مطفأة من إعدادات الآيفون — اضغط هنا لتفعيلها", "Notifications are off in iPhone Settings — tap to turn them on"), "back": ("رجوع", "Back"),
        // notifications
        "nDebit": ("صرفت {a} ر.ق · {c}", "Spent QAR {a} · {c}"), "nCredit": ("وصلك {a} ر.ق · {c}", "Received QAR {a} · {c}"),
        "nLeft": ("متبقٍّ لك هذا الشهر {l} من {b} ر.ق", "Left this month: {l} of {b} QAR"), "nOver": ("تجاوزت ميزانية الشهر بـ {o} ر.ق", "Over this month's budget by QAR {o}"),
        "nSpent": ("صرفت هذا الشهر {s} ر.ق", "Spent this month: QAR {s}"),
        "nNearT": ("قربت من حد الشهر", "Close to this month's limit"), "nNearB": ("صرفت {s} من {b} ر.ق · باقي {l}", "Spent {s} of {b} QAR · {l} left"),
        "nOverT": ("تجاوزت ميزانية الشهر", "Over this month's budget"), "nOverB": ("صرفت {s} من {b} ر.ق · زيادة {o}", "Spent {s} of {b} QAR · {o} over"),
        "nCatNearT": ("ميزانية «{c}» وصلت 80٪", "“{c}” budget at 80%"), "nCatOverT": ("تجاوزت ميزانية «{c}»", "Over the “{c}” budget"),
        "nCatB": ("صرفت {s} من {b} ر.ق في هذه الدورة", "Spent {s} of {b} QAR this cycle"),
    ]

    /// "7 أيام" / "يومين" / "7 days".
    static func days(_ n: Int, _ lang: Lang) -> String {
        if lang == .en { return n == 1 ? "1 day" : "\(n) days" }
        switch n {
        case 1: return "يوم واحد"
        case 2: return "يومين"
        case 3...10: return "\(n) أيام"
        default: return "\(n) يوم"
        }
    }

    static func t(_ key: String, _ lang: Lang, _ vars: [String: String] = [:]) -> String {
        guard let pair = table[key] ?? v13[key] else { return key }
        var s = lang == .ar ? pair.0 : pair.1
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }
}
