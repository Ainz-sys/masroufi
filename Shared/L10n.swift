import Foundation

/// In-app Arabic / English strings. `{x}` placeholders are filled by `L10n.t(_:_:_:)`.
enum L10n {
    static let table: [String: (String, String)] = [
        "app": ("مصروفي", "Masroufi"),
        "today": ("اليوم", "Today"), "transactions": ("العمليات", "Transactions"), "insights": ("التحليل", "Insights"), "settings": ("الإعدادات", "Settings"),
        "cur": ("ر.ق", "QAR"),
        "leftToday": ("متبقٍّ لك اليوم", "Left for today"), "spentToday": ("صرفت اليوم", "Spent today"), "of": ("من", "of"),
        "spentOf": ("صرفت {s} من {b}", "Spent {s} of {b}"), "ok": ("ضمن الميزانية", "Within budget"), "near": ("قربت من الحد", "Close to the limit"),
        "overBy": ("تجاوزت بـ {o}", "Over by {o}"), "over": ("تجاوزت", "Over"),
        "todayTx": ("عمليات اليوم", "Today's transactions"), "noTx": ("ما فيه عمليات", "No transactions"),
        "noTxHint": ("أول ما توصلك رسالة من البنك تظهر هنا.", "Bank messages show up here as soon as they arrive."),
        "autoOff": ("فعّل التسجيل التلقائي", "Turn on auto-logging"), "add": ("إضافة", "Add"), "addTx": ("إضافة عملية", "Add transaction"),
        "manual": ("يدوي", "Manual"), "paste": ("لصق رسائل", "Paste messages"), "amount": ("المبلغ", "Amount"), "merchant": ("التاجر أو الوصف", "Merchant or description"),
        "category": ("الفئة", "Category"), "date": ("الوقت", "Time"), "expense": ("مصروف", "Expense"), "income": ("دخل", "Income"), "type": ("النوع", "Type"),
        "pasteHint": ("الصق رسالة أو أكثر من بنكك.", "Paste one or more bank messages."), "found": ("وجدنا {n}", "Found {n}"),
        "notFound": ("ما قدرنا نقرأ عملية من هذا النص", "Couldn't read a transaction from this text"), "addN": ("أضف {n}", "Add {n}"),
        "cancel": ("إلغاء", "Cancel"), "save": ("حفظ", "Save"), "done": ("تم", "Done"), "delete": ("حذف", "Delete"),
        "search": ("ابحث عن تاجر أو مبلغ", "Search merchant or amount"), "all": ("الكل", "All"),
        "card": ("البطاقة", "Card"), "account": ("الحساب", "Account"), "balanceAfter": ("الرصيد بعدها", "Balance after"), "bank": ("البنك", "Bank"),
        "source": ("المصدر", "Source"), "sms": ("رسالة SMS", "SMS"), "remember": ("تذكّر هذه الفئة لكل عمليات {m}", "Use this category for all {m}"),
        "countIt": ("احسبها ضمن المصروف", "Count as spending"), "note": ("ملاحظة", "Note"), "bankMsg": ("رسالة البنك", "Bank message"),
        "deleteTx": ("حذف العملية", "Delete transaction"), "originalAmount": ("المبلغ الأصلي", "Original amount"),
        "cycle": ("دورة الميزانية", "Budget cycle"), "cycleSpent": ("صرفت في الدورة", "Spent this cycle"), "dailyAvg": ("متوسط اليوم", "Daily average"),
        "projected": ("المتوقع للدورة", "Projected"), "vsPrev": ("مقارنة بالدورة السابقة", "vs previous cycle"), "byCategory": ("حسب الفئة", "By category"),
        "topMerchants": ("أكثر التجار", "Top merchants"), "perDay": ("كل يوم", "Per day"), "cycleBudget": ("ميزانية الدورة", "Cycle budget"),
        "language": ("اللغة", "Language"), "budget": ("الميزانية", "Budget"), "dailyBudget": ("الميزانية اليومية", "Daily budget"), "salaryDay": ("يوم نزول الراتب", "Salary day"),
        "salaryHint": ("يبدأ شهر الميزانية من يوم الراتب.", "Your budget month starts on salary day."),
        "alerts": ("التنبيهات", "Alerts"), "alert80": ("تنبيه عند 80٪ من ميزانية اليوم", "Alert at 80% of daily budget"), "alert100": ("تنبيه عند تجاوز الميزانية", "Alert when over budget"),
        "notifyEach": ("إشعار مع كل عملية", "Notify on every transaction"), "categories": ("الفئات", "Categories"), "newCategory": ("فئة جديدة", "New category"),
        "editCategory": ("تعديل الفئة", "Edit category"), "name": ("الاسم", "Name"), "icon": ("الأيقونة", "Icon"),
        "catBudget": ("ميزانية شهرية للفئة (اختياري)", "Monthly budget (optional)"), "catAlert": ("نبّهني عند 80٪ و100٪", "Alert me at 80% and 100%"),
        "deleteCategory": ("حذف الفئة", "Delete category"), "automation": ("التسجيل التلقائي", "Auto-logging"), "guide": ("طريقة الإعداد", "How to set it up"),
        "lastAuto": ("آخر تسجيل تلقائي", "Last auto-logged"), "data": ("البيانات", "Data"), "export": ("تصدير CSV", "Export CSV"),
        "wipe": ("حذف كل البيانات", "Delete all data"), "wipeConfirm": ("سيُحذف كل شيء نهائياً.", "Everything will be deleted permanently."),
        "privacy": ("كل بياناتك محفوظة على جوالك فقط، والتطبيق لا يتصل بالإنترنت.", "All your data stays on your phone. The app never connects to the internet."),
        "replay": ("عرض الشاشات الترحيبية", "Show welcome screens"),
        "ob1t": ("مصروفك اليومي يُحسب لحاله", "Your daily spending, counted for you"),
        "ob1p": ("يقرأ رسائل بنكك ويسجّل كل عملية تلقائياً، ويقول لك كم باقي لك اليوم.", "Reads your bank texts, logs every transaction and tells you what's left for today."),
        "ob2t": ("جرّب بنفسك", "Try it"), "ob2p": ("انسخ رسالة من بنكك والصقها هنا.", "Copy a message from your bank and paste it here."), "addIt": ("أضفها", "Add it"), "added": ("أُضيفت", "Added"),
        "ob3t": ("فعّل التسجيل التلقائي", "Turn on auto-logging"),
        "ob3p": ("الآيفون لا يسمح للتطبيقات بقراءة الرسائل، فنستخدم أتمتة في تطبيق الاختصارات. تُعدّ مرة واحدة.", "iPhone doesn't let apps read messages, so we use an automation in Shortcuts. You set it up once."),
        "st1": ("افتح «الاختصارات» ← الأتمتة ← + ← رسالة.", "Open Shortcuts → Automation → + → Message."),
        "st2": ("في «تحتوي الرسالة على» اكتب QAR، واختر «تشغيل فوراً» وأطفئ «الإشعار عند التشغيل».", "In “Message Contains” type QAR, choose “Run Immediately” and turn off “Notify When Run”."),
        "st3": ("أضف الإجراء «سجّل رسالة البنك» من تطبيق مصروفي.", "Add the “Log bank message” action from Masroufi."),
        "st4": ("اجعل «الرسالة» = «مُدخل الاختصار».", "Set “Message” to “Shortcut Input”."),
        "st5": ("إذا رسائل بنكك بالعربي، كرّر الأتمتة بكلمة ر.ق.", "If your bank texts in Arabic, repeat with the word ر.ق."),
        "openShortcuts": ("افتح الاختصارات", "Open Shortcuts"),
        "ob4t": ("كم ميزانيتك اليومية؟", "What's your daily budget?"), "ob5t": ("التنبيهات", "Alerts"),
        "ob5p": ("إشعار مع كل عملية، وعند 80٪ و100٪ من ميزانيتك.", "A notification for each transaction, and at 80% and 100% of your budget."),
        "enableAlerts": ("فعّل التنبيهات", "Turn on alerts"), "next": ("التالي", "Next"), "skip": ("تخطّي", "Skip"), "start": ("ابدأ", "Start"), "enter": ("ادخل التطبيق", "Enter the app"),
        "ob6t": ("بياناتك لك", "Your data is yours"),
        // notifications
        "nDebit": ("صرفت {a} ر.ق · {c}", "Spent QAR {a} · {c}"), "nCredit": ("وصلك {a} ر.ق · {c}", "Received QAR {a} · {c}"),
        "nLeft": ("متبقٍّ لك اليوم {l} من {b} ر.ق", "Left today: {l} of {b} QAR"), "nOver": ("تجاوزت ميزانية اليوم بـ {o} ر.ق", "Over today's budget by QAR {o}"),
        "nSpent": ("صرفت اليوم {s} ر.ق", "Spent today: QAR {s}"),
        "nNearT": ("قربت من حد اليوم", "Close to today's limit"), "nNearB": ("صرفت {s} من {b} ر.ق · باقي {l}", "Spent {s} of {b} QAR · {l} left"),
        "nOverT": ("تجاوزت ميزانية اليوم", "Over today's budget"), "nOverB": ("صرفت {s} من {b} ر.ق · زيادة {o}", "Spent {s} of {b} QAR · {o} over"),
        "nCatNearT": ("ميزانية «{c}» وصلت 80٪", "“{c}” budget at 80%"), "nCatOverT": ("تجاوزت ميزانية «{c}»", "Over the “{c}” budget"),
        "nCatB": ("صرفت {s} من {b} ر.ق في هذه الدورة", "Spent {s} of {b} QAR this cycle"),
        "week": ("آخر 7 أيام", "Last 7 days"),
    ]

    static func t(_ key: String, _ lang: Lang, _ vars: [String: String] = [:]) -> String {
        guard let pair = table[key] else { return key }
        var s = lang == .ar ? pair.0 : pair.1
        for (k, v) in vars { s = s.replacingOccurrences(of: "{\(k)}", with: v) }
        return s
    }
}
