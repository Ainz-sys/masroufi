import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        if store.data.settings.onboarded { MainTabs() } else { OnboardingView() }
    }
}

struct MainTabs: View {
    @EnvironmentObject var store: Store
    var body: some View {
        TabView {
            TodayView().tabItem { Label(store.t("today"), systemImage: "sun.max") }
            TransactionsView().tabItem { Label(store.t("transactions"), systemImage: "list.bullet.rectangle") }
            InsightsView().tabItem { Label(store.t("insights"), systemImage: "chart.bar") }
            SettingsView().tabItem { Label(store.t("settings"), systemImage: "gearshape") }
        }
    }
}

// MARK: - Shared rows

struct TxRow: View {
    @EnvironmentObject var store: Store
    let tx: Transaction
    var body: some View {
        let c = store.data.category(tx.categoryID)
        HStack(spacing: 12) {
            Image(systemName: c.symbol).font(.title3).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.merchant.isEmpty ? c.name(store.lang) : tx.merchant).font(.body.weight(.semibold)).lineLimit(2)
                Text(c.name(store.lang) + (tx.noTime ? "" : " · " + Fmt.time(tx.date))).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text((tx.kind == .credit ? "+" : "") + Fmt.m(tx.amountHome))
                    .font(.body.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(tx.kind == .credit ? Color.green : Color.primary)
                Text(store.t("cur")).font(.caption).foregroundStyle(.secondary)
            }
        }
        .opacity(tx.excluded ? 0.5 : 1)
    }
}

struct DayGroup: Identifiable {
    let id: Date
    let txs: [Transaction]
}

// MARK: - Today

struct TodayView: View {
    @EnvironmentObject var store: Store
    @State private var showAdd = false
    var body: some View {
        NavigationStack {
            List {
                Section { TodaySummary() }
                if store.data.lastAuto == nil {
                    Section { NavigationLink { AutomationGuideView() } label: { Label(store.t("autoOff"), systemImage: "bolt") } }
                }
                Section(store.t("todayTx")) {
                    let txs = Ledger.transactions(store.data, on: Date())
                    if txs.isEmpty { Text(store.t("noTxHint")).foregroundStyle(.secondary) }
                    ForEach(txs) { tx in NavigationLink(value: tx.id) { TxRow(tx: tx) } }
                }
            }
            .navigationTitle(store.t("today"))
            .navigationDestination(for: String.self) { TransactionDetailView(txID: $0) }
            .toolbar { ToolbarItem(placement: .primaryAction) { Button { showAdd = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showAdd) { AddTransactionView() }
        }
    }
}

struct TodaySummary: View {
    @EnvironmentObject var store: Store
    var body: some View {
        let t = Ledger.today(store.data)
        VStack(alignment: .leading, spacing: 8) {
            Text(t.budget > 0 ? store.t("leftToday") : store.t("spentToday")).foregroundStyle(.secondary)
            Text(Fmt.m(t.budget > 0 ? t.remaining : t.spent) + " " + store.t("cur"))
                .font(.system(size: 42, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(t.budget > 0 && t.remaining < 0 ? Color.red : Color.primary)
                .minimumScaleFactor(0.5).lineLimit(1)
            if t.budget > 0 {
                ProgressView(value: min(max(t.fraction, 0), 1))
                HStack {
                    Text(store.t("spentOf", ["s": Fmt.m(t.spent), "b": Fmt.m0(t.budget)])).font(.subheadline)
                    Spacer()
                    status(t).font(.subheadline.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder func status(_ t: Ledger.Today) -> some View {
        if t.spent > t.budget { Label(store.t("overBy", ["o": Fmt.m(t.spent - t.budget)]), systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
        else if t.fraction >= 0.8 { Label(store.t("near"), systemImage: "bell").foregroundStyle(.orange) }
        else { Label(store.t("ok"), systemImage: "checkmark.circle").foregroundStyle(.green) }
    }
}

// MARK: - Transactions

struct TransactionsView: View {
    @EnvironmentObject var store: Store
    @State private var query = ""
    @State private var filter: String? = nil

    var filtered: [Transaction] {
        let lang = store.lang
        return store.data.transactions.filter { tx in
            guard filter == nil || tx.categoryID == filter else { return false }
            if query.isEmpty { return true }
            return tx.merchant.localizedCaseInsensitiveContains(query) || Fmt.m(tx.amountHome).contains(query)
                || tx.note.localizedCaseInsensitiveContains(query) || store.data.category(tx.categoryID).name(lang).contains(query)
        }
    }

    var groups: [DayGroup] {
        let g = Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.date) }
        return g.keys.sorted(by: >).map { DayGroup(id: $0, txs: (g[$0] ?? []).sorted { $0.date > $1.date }) }
    }

    var usedCategories: [Category] {
        let used = Set(store.data.transactions.map(\.categoryID))
        return store.data.categories.filter { used.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty { ContentUnavailableView(store.t("noTx"), systemImage: "tray", description: Text(store.t("noTxHint"))) }
                ForEach(groups) { group in
                    Section {
                        ForEach(group.txs) { tx in NavigationLink(value: tx.id) { TxRow(tx: tx) } }
                    } header: {
                        HStack {
                            Text(Fmt.day(group.id, store.lang))
                            Spacer()
                            Text(Fmt.m(group.txs.filter(\.counts).reduce(0) { $0 + $1.amountHome })).monospacedDigit()
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: store.t("search"))
            .navigationTitle(store.t("transactions"))
            .navigationDestination(for: String.self) { TransactionDetailView(txID: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(store.t("all")) { filter = nil }
                        ForEach(usedCategories) { c in
                            Button { filter = c.id } label: { Label(c.name(store.lang), systemImage: c.symbol) }
                        }
                    } label: {
                        Image(systemName: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
        }
    }
}

struct TransactionDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    let txID: String
    @State private var confirmDelete = false

    var body: some View {
        if let tx = store.data.transactions.first(where: { $0.id == txID }) {
            form(tx)
        } else {
            ContentUnavailableView(store.t("noTx"), systemImage: "tray")
        }
    }

    @ViewBuilder func form(_ tx: Transaction) -> some View {
        let lang = store.lang
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tx.merchant.isEmpty ? store.data.category(tx.categoryID).name(lang) : tx.merchant).font(.title3.bold())
                    Text(Fmt.day(tx.date, lang) + (tx.noTime ? "" : " · " + Fmt.time(tx.date))).foregroundStyle(.secondary)
                    Text((tx.kind == .credit ? "+" : "") + Fmt.m(tx.amountHome) + " " + store.t("cur"))
                        .font(.system(size: 38, weight: .semibold, design: .rounded)).monospacedDigit()
                }
                if tx.currency != "QAR" { LabeledContent(store.t("originalAmount"), value: tx.currency + " " + Fmt.m(tx.amount)) }
                if !tx.card.isEmpty { LabeledContent(store.t("card"), value: "•••• " + tx.card) }
                if !tx.account.isEmpty { LabeledContent(store.t("account"), value: "•••• " + tx.account) }
                if let b = tx.balance { LabeledContent(store.t("balanceAfter"), value: Fmt.m(b) + " " + store.t("cur")) }
                if !tx.bank.isEmpty { LabeledContent(store.t("bank"), value: tx.bank) }
                LabeledContent(store.t("source"), value: tx.source == .sms ? store.t("sms") : store.t("manual"))
            }
            Section(store.t("category")) {
                Picker(store.t("category"), selection: Binding(get: { tx.categoryID }, set: { store.setCategory(txID, $0) })) {
                    ForEach(store.data.categories) { c in Label(c.name(lang), systemImage: c.symbol).tag(c.id) }
                }
                if !tx.merchantKey.isEmpty {
                    Toggle(store.t("remember", ["m": tx.merchantKey]), isOn: Binding(
                        get: { store.data.merchantMap[tx.merchantKey] == tx.categoryID },
                        set: { _ in store.toggleRemember(txID) }))
                }
                Toggle(store.t("countIt"), isOn: Binding(get: { !tx.excluded }, set: { v in store.editTx(txID) { $0.excluded = !v } }))
                TextField(store.t("note"), text: Binding(get: { tx.note }, set: { v in store.editTx(txID) { $0.note = v } }))
            }
            if !tx.raw.isEmpty {
                Section(store.t("bankMsg")) { Text(tx.raw).font(.callout).textSelection(.enabled) }
            }
            Section {
                Button(store.t("deleteTx"), role: .destructive) { confirmDelete = true }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(store.t("deleteTx"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(store.t("delete"), role: .destructive) { store.deleteTx(txID); dismiss() }
        }
    }
}

// MARK: - Adding

struct AddTransactionView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var mode = 0
    @State private var amount: Double? = nil
    @State private var merchant = ""
    @State private var categoryID = "other"
    @State private var autoCategory = true
    @State private var date = Date()
    @State private var kind: TxKind = .debit
    @State private var pasted = ""

    var canSave: Bool { mode == 0 ? (amount ?? 0) > 0 : !Ledger.parseMany(pasted).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $mode) {
                    Text(store.t("manual")).tag(0)
                    Text(store.t("paste")).tag(1)
                }
                .pickerStyle(.segmented)
                if mode == 0 { manual } else { PasteSection(text: $pasted) }
            }
            .navigationTitle(store.t("addTx"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(store.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(store.t("add")) { save() }.disabled(!canSave) }
            }
        }
    }

    @ViewBuilder var manual: some View {
        Section {
            TextField(store.t("amount"), value: $amount, format: .number).keyboardType(.decimalPad)
            TextField(store.t("merchant"), text: $merchant)
                .onChange(of: merchant) { _, v in
                    guard autoCategory else { return }
                    let c = store.data.merchantMap[SMSParser.merchantKey(v)] ?? SMSParser.categorize(merchant: v)
                    if c != "other" { categoryID = c }
                }
            Picker(store.t("type"), selection: $kind) {
                Text(store.t("expense")).tag(TxKind.debit)
                Text(store.t("income")).tag(TxKind.credit)
            }
            Picker(store.t("category"), selection: Binding(get: { categoryID }, set: { categoryID = $0; autoCategory = false })) {
                ForEach(store.data.categories) { c in Label(c.name(store.lang), systemImage: c.symbol).tag(c.id) }
            }
            DatePicker(store.t("date"), selection: $date)
        }
    }

    func save() {
        if mode == 0, let a = amount, a > 0 {
            store.addManual(amount: a, merchant: merchant, categoryID: kind == .credit && categoryID == "other" ? "income" : categoryID, date: date, kind: kind)
        } else if mode == 1 {
            _ = store.addPasted(pasted)
        }
        dismiss()
    }
}

struct PasteSection: View {
    @EnvironmentObject var store: Store
    @Binding var text: String
    var body: some View {
        Section {
            TextEditor(text: $text).frame(minHeight: 140)
        } footer: { Text(store.t("pasteHint")) }
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let found = Ledger.parseMany(text)
            Section(found.isEmpty ? store.t("notFound") : store.t("found", ["n": "\(found.count)"])) {
                ForEach(Array(found.enumerated()), id: \.offset) { item in
                    TxRow(tx: Ledger.transaction(from: item.element.0, raw: item.element.1, data: store.data, now: Date(), live: false))
                }
            }
        }
    }
}

struct PasteView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    var body: some View {
        Form { PasteSection(text: $text) }
            .navigationTitle(store.t("paste"))
            .toolbar {
                Button(store.t("add")) { _ = store.addPasted(text); dismiss() }.disabled(Ledger.parseMany(text).isEmpty)
            }
    }
}

// MARK: - Insights

struct CategoryStat: Identifiable {
    let category: Category
    let amount: Double
    var id: String { category.id }
}

struct MerchantStat: Identifiable {
    let name: String
    let amount: Double
    let count: Int
    var id: String { name }
}

struct DayValue: Identifiable {
    var id: Date { day }
    let day: Date
    let value: Double
}

struct InsightsView: View {
    @EnvironmentObject var store: Store

    struct Stats {
        var spent = 0.0, budget = 0.0, avg = 0.0, projected = 0.0, income = 0.0
        var prevSpent: Double? = nil
        var perDay: [DayValue] = []
        var byCategory: [CategoryStat] = []
        var merchants: [MerchantStat] = []
        var start = Date(), end = Date()
    }

    func stats() -> Stats {
        let d = store.data, cal = Calendar.current, now = Date()
        let cy = Ledger.cycle(salaryDay: d.settings.salaryDay, ref: now)
        var s = Stats()
        s.start = cy.start; s.end = cy.end
        s.spent = Ledger.spent(d, from: cy.start, to: cy.end)
        s.budget = d.settings.dailyBudget * Double(cy.days)
        let elapsed = max(1, (cal.dateComponents([.day], from: cy.start, to: min(now, cy.end)).day ?? 0) + 1)
        s.avg = s.spent / Double(elapsed)
        s.projected = s.avg * Double(cy.days)
        s.income = d.transactions.filter { $0.kind == .credit && !$0.excluded && $0.date >= cy.start && $0.date < cy.end }.reduce(0) { $0 + $1.amountHome }
        let prev = Ledger.cycle(salaryDay: d.settings.salaryDay, ref: cal.date(byAdding: .day, value: -1, to: cy.start)!)
        let p = Ledger.spent(d, from: prev.start, to: prev.start.addingTimeInterval(min(now, cy.end).timeIntervalSince(cy.start)))
        s.prevSpent = p > 0 ? p : nil
        s.perDay = (0..<cy.days).compactMap { (i: Int) -> DayValue? in
            guard let day = cal.date(byAdding: .day, value: i, to: cy.start), day <= now else { return nil }
            let b = Ledger.dayBounds(day)
            return DayValue(day: day, value: Ledger.spent(d, from: b.start, to: b.end))
        }
        let inCycle = d.transactions.filter { $0.counts && $0.date >= cy.start && $0.date < cy.end }
        let byCat = Dictionary(grouping: inCycle, by: \.categoryID).mapValues { $0.reduce(0) { $0 + $1.amountHome } }
        s.byCategory = byCat.map { CategoryStat(category: d.category($0.key), amount: $0.value) }.sorted { $0.amount > $1.amount }
        let byMerchant = Dictionary(grouping: inCycle.filter { !$0.merchant.isEmpty }, by: { $0.merchantKey.isEmpty ? $0.merchant : $0.merchantKey })
        let merchantStats: [MerchantStat] = byMerchant.values.map { (txs: [Transaction]) -> MerchantStat in
            MerchantStat(name: txs[0].merchant, amount: txs.reduce(0.0) { $0 + $1.amountHome }, count: txs.count)
        }
        s.merchants = Array(merchantStats.sorted { $0.amount > $1.amount }.prefix(5))
        return s
    }

    var body: some View {
        let s = stats()
        let lang = store.lang
        NavigationStack {
            List {
                Section {
                    LabeledContent(store.t("cycleSpent"), value: Fmt.m(s.spent))
                    if s.budget > 0 { LabeledContent(store.t("cycleBudget"), value: Fmt.m0(s.budget)) }
                    LabeledContent(store.t("dailyAvg"), value: Fmt.m(s.avg))
                    LabeledContent(store.t("projected"), value: Fmt.m0(s.projected))
                    LabeledContent(store.t("income"), value: Fmt.m0(s.income))
                    if let p = s.prevSpent {
                        let delta = (s.spent - p) / p * 100
                        LabeledContent(store.t("vsPrev"), value: (delta > 0 ? "+" : "") + String(format: "%.0f%%", delta))
                    }
                } header: {
                    Text(store.t("cycle") + ": " + Fmt.short(s.start, lang) + " – " + Fmt.short(s.end.addingTimeInterval(-86400), lang))
                }
                Section(store.t("perDay")) {
                    Chart {
                        ForEach(s.perDay) { p in
                            BarMark(x: .value("Day", p.day, unit: .day), y: .value("QAR", p.value))
                        }
                        if store.data.settings.dailyBudget > 0 {
                            RuleMark(y: .value("Budget", store.data.settings.dailyBudget)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                    }
                    .frame(height: 180)
                }
                if !s.byCategory.isEmpty {
                    Section(store.t("byCategory")) {
                        ForEach(s.byCategory) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(item.category.name(lang), systemImage: item.category.symbol)
                                    Spacer()
                                    Text(Fmt.m(item.amount)).monospacedDigit()
                                }
                                ProgressView(value: s.spent > 0 ? min(1, item.amount / s.spent) : 0)
                                if let b = item.category.monthlyBudget {
                                    Text(store.t("spentOf", ["s": Fmt.m0(item.amount), "b": Fmt.m0(b)])).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if !s.merchants.isEmpty {
                    Section(store.t("topMerchants")) {
                        ForEach(s.merchants) { m in
                            HStack { Text(m.name); Text("×\(m.count)").foregroundStyle(.secondary); Spacer(); Text(Fmt.m(m.amount)).monospacedDigit() }
                        }
                    }
                }
            }
            .navigationTitle(store.t("insights"))
        }
    }
}

// MARK: - Settings

struct CSVFile: Transferable {
    let text: String
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("masroufi-\(Ledger.key(Date())).csv")
            try Data(file.text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var confirmWipe = false
    var body: some View {
        NavigationStack {
            Form {
                Section(store.t("language")) {
                    Picker(store.t("language"), selection: store.setting(\.language)) {
                        Text("العربية").tag(Lang.ar)
                        Text("English").tag(Lang.en)
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    HStack {
                        Text(store.t("dailyBudget"))
                        Spacer()
                        TextField("0", value: store.setting(\.dailyBudget), format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 120)
                    }
                    Picker(store.t("salaryDay"), selection: store.setting(\.salaryDay)) {
                        ForEach(1...28, id: \.self) { Text("\($0)").tag($0) }
                    }
                } header: { Text(store.t("budget")) } footer: { Text(store.t("salaryHint")) }
                Section(store.t("alerts")) {
                    Toggle(store.t("alert80"), isOn: store.setting(\.alert80))
                    Toggle(store.t("alert100"), isOn: store.setting(\.alert100))
                    Toggle(store.t("notifyEach"), isOn: store.setting(\.notifyEach))
                }
                Section(store.t("categories")) {
                    NavigationLink(store.t("categories")) { CategoriesView() }
                }
                Section(store.t("automation")) {
                    NavigationLink(store.t("guide")) { AutomationGuideView() }
                    if let last = store.data.lastAuto {
                        LabeledContent(store.t("lastAuto"), value: Fmt.short(last, store.lang) + " " + Fmt.time(last))
                    }
                }
                Section(store.t("data")) {
                    NavigationLink(store.t("paste")) { PasteView() }
                    ShareLink(item: CSVFile(text: Ledger.csv(store.data)), preview: SharePreview("masroufi.csv")) {
                        Label(store.t("export"), systemImage: "square.and.arrow.up")
                    }
                    Button(store.t("replay")) { store.update { $0.settings.onboarded = false } }
                    Button(store.t("wipe"), role: .destructive) { confirmWipe = true }
                }
                Section { Text(store.t("privacy")).font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle(store.t("settings"))
            .confirmationDialog(store.t("wipeConfirm"), isPresented: $confirmWipe, titleVisibility: .visible) {
                Button(store.t("wipe"), role: .destructive) { store.wipe() }
            }
        }
    }
}

struct CategoriesView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Category? = nil
    var body: some View {
        List {
            ForEach(store.data.categories) { c in
                Button { editing = c } label: {
                    HStack {
                        Label(c.name(store.lang), systemImage: c.symbol)
                        Spacer()
                        if let b = c.monthlyBudget { Text(Fmt.m0(b)).foregroundStyle(.secondary).monospacedDigit() }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle(store.t("categories"))
        .toolbar {
            Button { editing = Category(id: "c" + String(UUID().uuidString.prefix(8)), nameAR: "", nameEN: "", symbol: "star") } label: { Image(systemName: "plus") }
        }
        .sheet(item: $editing) { CategoryEditor(category: $0) }
    }
}

struct CategoryEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State var category: Category
    @State private var name = ""
    @State private var budget: Double? = nil

    var isNew: Bool { !store.data.categories.contains { $0.id == category.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section(store.t("name")) { TextField(store.t("name"), text: $name) }
                Section(store.t("icon")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(Category.symbolChoices, id: \.self) { s in
                            Button { category.symbol = s } label: {
                                Image(systemName: s).font(.title3).frame(width: 44, height: 44)
                                    .background(category.symbol == s ? Color.accentColor.opacity(0.2) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    TextField(store.t("catBudget"), value: $budget, format: .number).keyboardType(.decimalPad)
                    Toggle(store.t("catAlert"), isOn: $category.alertAt80)
                }
                if !isNew && !category.builtIn {
                    Section { Button(store.t("deleteCategory"), role: .destructive) { store.deleteCategory(category.id); dismiss() } }
                }
            }
            .navigationTitle(isNew ? store.t("newCategory") : store.t("editCategory"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { name = category.name(store.lang); budget = category.monthlyBudget }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(store.t("cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t("save")) {
                        var c = category
                        let n = name.trimmingCharacters(in: .whitespaces)
                        if store.lang == .ar || !c.builtIn { c.nameAR = n }
                        if store.lang == .en || !c.builtIn { c.nameEN = n }
                        c.monthlyBudget = (budget ?? 0) > 0 ? budget : nil
                        store.saveCategory(c)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct AutomationGuideView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        List { AutomationSteps() }
            .navigationTitle(store.t("automation"))
    }
}

struct AutomationSteps: View {
    @EnvironmentObject var store: Store
    var body: some View {
        Section { Text(store.t("ob3p")) }
        Section {
            ForEach(Array(["st1", "st2", "st3", "st4", "st5"].enumerated()), id: \.offset) { item in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(item.offset + 1)").bold().monospacedDigit()
                    Text(store.t(item.element))
                }
            }
        }
        Section {
            Link(destination: URL(string: "shortcuts://")!) { Label(store.t("openShortcuts"), systemImage: "arrow.up.forward.app") }
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject var store: Store
    @State private var page = 0
    @State private var sample = ""
    @State private var added = false
    @State private var budget: Double? = 300
    @State private var salaryDay = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < 5 { Button(store.t("skip")) { advance(skipping: true) } }
            }
            .padding(.horizontal).frame(height: 44)
            TabView(selection: $page) {
                welcome.tag(0)
                tryIt.tag(1)
                List { AutomationSteps() }.tag(2)
                budgetPage.tag(3)
                alertsPage.tag(4)
                privacyPage.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            Button { advance(skipping: false) } label: {
                Text(page == 5 ? store.t("enter") : page == 0 ? store.t("start") : store.t("next")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).padding()
        }
        .onAppear { salaryDay = store.data.settings.salaryDay; if store.data.settings.dailyBudget > 0 { budget = store.data.settings.dailyBudget } }
    }

    func advance(skipping: Bool) {
        if page == 3 && !skipping {
            let b = max(0, budget ?? 0), sd = salaryDay
            store.update { $0.settings.dailyBudget = b; $0.settings.salaryDay = sd }
        }
        if page < 5 { withAnimation { page += 1 } } else { store.update { $0.settings.onboarded = true } }
    }

    func header(_ symbol: String, _ title: String, _ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 56)).padding(.top, 24)
            Text(title).font(.title.bold()).multilineTextAlignment(.center)
            Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal)
    }

    var welcome: some View {
        VStack(spacing: 24) {
            header("creditcard", store.t("ob1t"), store.t("ob1p"))
            Picker(store.t("language"), selection: store.setting(\.language)) {
                Text("العربية").tag(Lang.ar)
                Text("English").tag(Lang.en)
            }
            .pickerStyle(.segmented).padding(.horizontal, 40)
            Spacer()
        }
    }

    var tryIt: some View {
        Form {
            Section { header("message", store.t("ob2t"), store.t("ob2p")).listRowBackground(Color.clear) }
            PasteSection(text: $sample)
            if !Ledger.parseMany(sample).isEmpty {
                Button(added ? store.t("added") : store.t("addIt")) { _ = store.addPasted(sample); added = true }.disabled(added)
            }
        }
        .onChange(of: sample) { _, _ in added = false }
    }

    var budgetPage: some View {
        Form {
            Section { header("target", store.t("ob4t"), store.t("salaryHint")).listRowBackground(Color.clear) }
            Section {
                TextField(store.t("dailyBudget"), value: $budget, format: .number).keyboardType(.decimalPad).font(.title2.weight(.semibold))
                HStack {
                    ForEach([150.0, 200, 300, 500], id: \.self) { v in
                        Button(Fmt.m0(v)) { budget = v }.buttonStyle(.bordered)
                    }
                }
                Picker(store.t("salaryDay"), selection: $salaryDay) { ForEach(1...28, id: \.self) { Text("\($0)").tag($0) } }
            }
        }
    }

    var alertsPage: some View {
        VStack(spacing: 24) {
            header("bell.badge", store.t("ob5t"), store.t("ob5p"))
            Button(store.t("enableAlerts")) { Task { _ = await Notifier.requestPermission() } }.buttonStyle(.bordered)
            Spacer()
        }
    }

    var privacyPage: some View {
        VStack(spacing: 24) {
            header("lock.shield", store.t("ob6t"), store.t("privacy"))
            Spacer()
        }
    }
}
