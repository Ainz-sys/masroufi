import SwiftUI
import AppIntents
import UserNotifications
import WidgetKit

@main
struct MasroufiApp: App {
    @StateObject private var store = Store.shared
    @Environment(\.scenePhase) private var phase
    private let notificationDelegate = NotificationDelegate()

    init() { UNUserNotificationCenter.current().delegate = notificationDelegate }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environment(\.layoutDirection, store.lang == .ar ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: store.lang == .ar ? "ar" : "en"))
        }
        .onChange(of: phase) { _, p in if p == .active { store.reload() } }
    }
}

/// Shows notifications while the app is open too.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }
}

// MARK: - Store

@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    @Published private(set) var data: AppData

    private init() { data = Persistence.load() }

    var lang: Lang { data.settings.language }
    func t(_ key: String, _ vars: [String: String] = [:]) -> String { L10n.t(key, lang, vars) }
    func reload() { data = Persistence.load() }

    func update(_ change: (inout AppData) -> Void) {
        var d = Persistence.load() // merge with anything the Shortcuts action saved meanwhile
        if d.transactions.count < data.transactions.count { d = data }
        change(&d)
        data = d
        Persistence.save(d)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setting<T>(_ kp: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { self.data.settings[keyPath: kp] }, set: { v in self.update { $0.settings[keyPath: kp] = v } })
    }

    // Logging from the automation
    @discardableResult
    func logSMS(_ text: String) -> LogResult {
        var d = Persistence.load()
        let r = Ledger.log(text: text, into: &d)
        if !r.added.isEmpty {
            data = d
            Persistence.save(d)
            WidgetCenter.shared.reloadAllTimelines()
            Notifier.announce(r, data: d)
        }
        return r
    }

    // Transactions
    func addPasted(_ text: String) -> Int {
        var n = 0
        update { d in
            for (p, raw) in Ledger.parseMany(text) where !d.transactions.contains(where: { $0.raw == raw.trimmingCharacters(in: .whitespacesAndNewlines) }) {
                d.transactions.append(Ledger.transaction(from: p, raw: raw, data: d, now: Date(), live: false)); n += 1
            }
        }
        return n
    }

    func addManual(amount: Double, merchant: String, categoryID: String, date: Date, kind: TxKind) {
        let m = merchant.trimmingCharacters(in: .whitespaces)
        update { $0.transactions.append(Transaction(date: date, amount: amount, amountHome: amount, kind: kind, merchant: m,
                                                     merchantKey: SMSParser.merchantKey(m), categoryID: categoryID, source: .manual)) }
    }

    func editTx(_ id: String, _ change: @escaping (inout Transaction) -> Void) {
        update { d in if let i = d.transactions.firstIndex(where: { $0.id == id }) { change(&d.transactions[i]) } }
    }

    func setCategory(_ id: String, _ cat: String) {
        update { d in
            guard let i = d.transactions.firstIndex(where: { $0.id == id }) else { return }
            d.transactions[i].categoryID = cat
            let key = d.transactions[i].merchantKey
            if !key.isEmpty, d.merchantMap[key] != nil { d.merchantMap[key] = cat }
        }
    }

    /// Merchant memory: future (and existing) transactions from this merchant get this category.
    func toggleRemember(_ id: String) {
        update { d in
            guard let tx = d.transactions.first(where: { $0.id == id }), !tx.merchantKey.isEmpty else { return }
            if d.merchantMap[tx.merchantKey] == tx.categoryID { d.merchantMap[tx.merchantKey] = nil; return }
            d.merchantMap[tx.merchantKey] = tx.categoryID
            for i in d.transactions.indices where d.transactions[i].merchantKey == tx.merchantKey { d.transactions[i].categoryID = tx.categoryID }
        }
    }

    func deleteTx(_ id: String) { update { $0.transactions.removeAll { $0.id == id } } }

    // Categories
    func saveCategory(_ c: Category) {
        update { d in
            if let i = d.categories.firstIndex(where: { $0.id == c.id }) { d.categories[i] = c }
            else { d.categories.insert(c, at: max(0, d.categories.count - 2)) }
        }
    }

    func deleteCategory(_ id: String) {
        update { d in
            d.categories.removeAll { $0.id == id && !$0.builtIn }
            for i in d.transactions.indices where d.transactions[i].categoryID == id { d.transactions[i].categoryID = "other" }
            d.merchantMap = d.merchantMap.filter { $0.value != id }
        }
    }

    func wipe() {
        update { d in d.transactions = []; d.merchantMap = [:]; d.notified = [:]; d.categories = Category.defaults; d.lastAuto = nil }
    }
}

// MARK: - Notifications

enum Notifier {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func send(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default; c.threadIdentifier = "masroufi"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    static func alertText(_ a: BudgetAlert, _ d: AppData) -> (String, String) {
        let lang = d.settings.language
        let v = ["s": Fmt.m(a.spent), "b": Fmt.m0(a.budget), "l": Fmt.m(a.budget - a.spent), "o": Fmt.m(a.spent - a.budget),
                 "c": a.categoryID.map { d.category($0).name(lang) } ?? ""]
        switch a.kind {
        case .near: return (L10n.t("nNearT", lang), L10n.t("nNearB", lang, v))
        case .over: return (L10n.t("nOverT", lang), L10n.t("nOverB", lang, v))
        case .categoryNear: return (L10n.t("nCatNearT", lang, v), L10n.t("nCatB", lang, v))
        case .categoryOver: return (L10n.t("nCatOverT", lang, v), L10n.t("nCatB", lang, v))
        }
    }

    static func todayLine(_ d: AppData) -> String {
        let lang = d.settings.language, t = Ledger.today(d)
        if t.budget <= 0 { return L10n.t("nSpent", lang, ["s": Fmt.m(t.spent)]) }
        return t.remaining < 0 ? L10n.t("nOver", lang, ["o": Fmt.m(-t.remaining)]) : L10n.t("nLeft", lang, ["l": Fmt.m(t.remaining), "b": Fmt.m0(t.budget)])
    }

    static func announce(_ r: LogResult, data d: AppData) {
        guard let tx = r.added.last else { return }
        let lang = d.settings.language
        let title = L10n.t(tx.kind == .credit ? "nCredit" : "nDebit", lang, ["a": Fmt.m(tx.amountHome), "c": d.category(tx.categoryID).name(lang)])
        if let first = r.alerts.first {
            let (t0, b0) = alertText(first, d)
            send(t0, b0 + "\n" + title)
            for a in r.alerts.dropFirst() { let (t1, b1) = alertText(a, d); send(t1, b1) }
        } else if d.settings.notifyEach {
            send(title, (tx.merchant.isEmpty ? "" : tx.merchant + "\n") + todayLine(d))
        }
    }
}

// MARK: - Shortcuts action used by the Message automation

struct LogBankMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "سجّل رسالة البنك"
    static var description = IntentDescription("يقرأ رسالة البنك ويسجّل العملية في مصروفي. Reads a bank SMS and logs the transaction.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "الرسالة")
    var message: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let r = Store.shared.logSMS(message)
        guard let tx = r.added.last else { return .result(value: r.status) }
        return .result(value: "logged \(Fmt.m(tx.amountHome)) QAR · \(tx.merchant)")
    }
}

struct TodaySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "كم باقي لي اليوم؟"
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let line = Notifier.todayLine(Persistence.load())
        return .result(dialog: "\(line)")
    }
}

struct MasroufiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogBankMessageIntent(), phrases: ["سجّل رسالة البنك في \(.applicationName)", "Log a bank message in \(.applicationName)"],
                    shortTitle: "سجّل رسالة البنك", systemImageName: "message")
        AppShortcut(intent: TodaySummaryIntent(), phrases: ["كم باقي لي اليوم في \(.applicationName)", "What's left today in \(.applicationName)"],
                    shortTitle: "كم باقي لي اليوم؟", systemImageName: "wallet.pass")
    }
}
