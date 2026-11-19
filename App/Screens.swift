import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var store: Store
    @StateObject private var nav = Nav()

    var body: some View {
        Group {
            if store.data.settings.onboarded { MainShell() } else { OnboardingFlow() }
        }
        .environmentObject(nav)
        .environment(\.palette, store.palette)
        .environment(\.layoutDirection, store.lang == .ar ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: store.lang == .ar ? "ar_QA@numbers=latn" : "en_GB"))
        .preferredColorScheme(.dark)
        .tint(Tok.tint)
        .onAppear { Demo.apply(nav: nav) }
    }
}

struct MainShell: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p

    var body: some View {
        NavigationStack(path: $nav.path) {
            ZStack(alignment: .bottom) {
                Group {
                    switch nav.tab {
                    case .today: TodayScreen()
                    case .txs: TransactionsScreen()
                    case .insights: InsightsScreen()
                    case .settings: SettingsScreen()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                FloatingTabBar()
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                Group {
                    switch route {
                    case .detail(let id): DetailScreen(txID: id)
                    case .categories: CategoriesScreen()
                    case .guide: GuideScreen()
                    case .salary: SalaryScreen()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .sheet(item: $nav.sheet) { route in SheetHost(route: route) }
        .overlay(alignment: .bottom) {
            if let t = nav.toast { Toast(text: t).padding(.bottom, 96).transition(.opacity.combined(with: .move(edge: .bottom))) }
        }
    }
}

/// Re-injects the environment into sheets and gives them the app background.
struct SheetHost: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    let route: SheetRoute

    var body: some View {
        Group {
            switch route {
            case .add(let paste): AddSheet(paste: paste)
            case .newCategory(let tx): CategoryEditorSheet(categoryID: nil, forTx: tx)
            case .editCategory(let id): CategoryEditorSheet(categoryID: id, forTx: nil)
            case .budget: BudgetSheet()
            }
        }
        .environmentObject(store)
        .environmentObject(nav)
        .environment(\.palette, store.palette)
        .environment(\.layoutDirection, store.lang == .ar ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: store.lang == .ar ? "ar_QA@numbers=latn" : "en_GB"))
        .preferredColorScheme(.dark)
        .tint(Tok.tint)
        .presentationBackground(store.palette.bg)
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Shared pieces

struct BigAmount: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    let value: Double
    var color: Color? = nil
    var size: CGFloat = 54
    var prefix: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\u{200E}" + prefix + Fmt.m(value))
                .font(.alx(size, .semibold, relativeTo: .largeTitle)).monospacedDigit()
                .foregroundStyle(color ?? p.label)
                .contentTransition(.numericText(value: value))
            Text(store.t("cur")).font(.alx(17, relativeTo: .body)).foregroundStyle(p.label2)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

struct RemainingPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    let today: Ledger.Today

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if today.budget > 0 {
                HStack(alignment: .firstTextBaseline) {
                    Text(store.t("remainingToday"))
                    Spacer()
                    Text(store.t("of") + " ") + Text(Fmt.m0(today.budget)).foregroundColor(p.label).font(.alx(15, .semibold)) + Text(" " + store.t("cur"))
                }
                .font(.alx(15)).foregroundStyle(p.label2)
                BigAmount(value: abs(today.remaining), color: today.remaining < 0 ? Tok.danger : nil, prefix: today.remaining < 0 ? "-" : "")
                    .padding(.top, 2)
                ProgressBar(fraction: today.fraction).padding(.top, 12)
                HStack(spacing: 8) {
                    Text(store.t("spent") + " ") + Text(Fmt.m(today.spent)).foregroundColor(p.label).font(.alx(15, .semibold)) + Text(" " + store.t("cur"))
                    Spacer(minLength: 4)
                    pill
                }
                .font(.alx(14.5)).foregroundStyle(p.label2)
                .padding(.top, 10)
            } else {
                HStack {
                    Text(store.t("spentToday")).font(.alx(15)).foregroundStyle(p.label2)
                    Spacer()
                    Button { nav.sheet = .budget } label: {
                        Text(store.t("daily") + " +").font(.alx(14.5, .medium)).foregroundStyle(Tok.tintInk).frame(minHeight: 44)
                    }
                }
                BigAmount(value: today.spent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    @ViewBuilder var pill: some View {
        if today.spent > today.budget {
            StatusPill(kind: .over, text: store.t("over") + " " + Fmt.m(today.spent - today.budget))
        } else if today.fraction >= 0.8 {
            StatusPill(kind: .warn, text: store.t("near"))
        } else {
            StatusPill(kind: .ok, text: store.t("ok"))
        }
    }
}

struct DayGroup: Identifiable {
    let id: Date
    let txs: [Transaction]
}

@MainActor
func dayLabel(_ d: Date, _ store: Store) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(d) { return store.t("today") }
    if cal.isDateInYesterday(d) { return store.t("yesterday") }
    return Fmt.day(d, store.lang)
}

// MARK: - Today

struct TodayScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p

    var body: some View {
        let today = Ledger.today(store.data)
        let txs = Ledger.transactions(store.data, on: Date())
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: store.t("today"), subtitle: Fmt.day(Date(), store.lang)) {
                    RoundButton(systemImage: "plus", label: store.t("addTx")) { nav.sheet = .add(paste: false) }
                }
                Card3DView(info: store.cardInfo()).frame(height: 200)
                RemainingPanel(today: today)
                if store.data.lastAuto == nil {
                    Button { nav.path.append(.guide) } label: {
                        HStack(spacing: 14) {
                            Icon3D(name: "zap", size: 30)
                            Text(store.t("autoOff")).font(.alx(16)).foregroundStyle(p.onTintContainer)
                            Spacer()
                            Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(p.onTintContainer.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 56)
                        .background(p.tintContainer, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                    }
                    .buttonStyle(PressStyle())
                }
                SectionHeader(title: store.t("todayTx")) {
                    if !store.data.transactions.isEmpty {
                        Button { nav.tab = .txs } label: {
                            Text(store.t("all") + " (\(store.data.transactions.count))").font(.alx(14, .medium)).foregroundStyle(Tok.tintInk).frame(minHeight: 44)
                        }
                    }
                }
                if txs.isEmpty {
                    EmptyCard(icon: "receipt", title: store.t("noTodayT"), text: store.t("noTodayP"), actions: AnyView(
                        HStack(spacing: 8) {
                            SmallButton(title: store.t("addManual")) { nav.sheet = .add(paste: false) }
                            if store.data.lastAuto == nil { SmallButton(title: store.t("setupAuto"), ghost: true) { nav.path.append(.guide) } }
                        }))
                } else {
                    SurfaceGroup {
                        ForEach(txs) { tx in
                            if tx.id != txs.first?.id { RowDivider() }
                            Button { nav.path.append(.detail(tx.id)) } label: { TxRow(tx: tx) }.buttonStyle(PressStyle())
                        }
                    }
                }
            }
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Transactions

struct TransactionsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @State private var query = ""
    @FocusState private var searching: Bool

    var groups: [DayGroup] {
        let lang = store.lang, q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = store.data.transactions.filter { tx in
            if let f = nav.txFilter, tx.categoryID != f { return false }
            if q.isEmpty { return true }
            return tx.merchant.lowercased().contains(q) || Fmt.m(tx.amountHome).contains(q) || tx.note.lowercased().contains(q)
                || store.data.category(tx.categoryID).name(lang).lowercased().contains(q)
        }
        let g = Dictionary(grouping: list) { Calendar.current.startOfDay(for: $0.date) }
        return g.keys.sorted(by: >).map { DayGroup(id: $0, txs: (g[$0] ?? []).sorted { $0.date > $1.date }) }
    }

    var usedCategories: [Category] {
        let used = Set(store.data.transactions.map(\.categoryID))
        return store.data.categories.filter { used.contains($0.id) }
    }

    var body: some View {
        let groups = self.groups
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: store.t("txs")) {
                    RoundButton(systemImage: "plus", label: store.t("addTx")) { nav.sheet = .add(paste: false) }
                }
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .medium)).foregroundStyle(p.label3)
                    TextField("", text: $query, prompt: Text(store.t("search")).foregroundColor(p.label3))
                        .font(.alx(16)).foregroundStyle(p.label).focused($searching).submitLabel(.search).autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(p.label3) }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(p.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 18)
                .padding(.top, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: store.t("allCats"), selected: nav.txFilter == nil) { nav.txFilter = nil }
                        ForEach(usedCategories) { c in
                            Chip(icon: c.symbol, title: c.name(store.lang), selected: nav.txFilter == c.id) { nav.txFilter = c.id }
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .padding(.top, 12)
                if groups.isEmpty {
                    EmptyCard(icon: "receipt", title: store.t("noTxT"), text: store.data.transactions.isEmpty ? store.t("noTodayP") : store.t("noTxP"))
                        .padding(.top, 16)
                }
                ForEach(groups) { g in
                    HStack(alignment: .firstTextBaseline) {
                        Text(dayLabel(g.id, store)).font(.alx(15, .semibold)).foregroundStyle(p.label)
                        Spacer()
                        Text("\u{200E}" + Fmt.m(g.txs.filter(\.counts).reduce(0) { $0 + $1.amountHome }) + " " + store.t("cur"))
                            .font(.alx(14)).foregroundStyle(p.label2)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                    SurfaceGroup {
                        ForEach(g.txs) { tx in
                            if tx.id != g.txs.first?.id { RowDivider() }
                            Button { nav.path.append(.detail(tx.id)) } label: { TxRow(tx: tx) }.buttonStyle(PressStyle())
                        }
                    }
                }
            }
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
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
    let icon: String
    let amount: Double
    let count: Int
    var id: String { name }
}

struct DayValue: Identifiable {
    var id: Date { day }
    let day: Date
    let value: Double
}

struct InsightsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p

    struct Stats {
        var start = Date(), cycleStart = Date(), end = Date(), days = 30
        var spent = 0.0, budget = 0.0, avg = 0.0, projected = 0.0, income = 0.0
        var delta: Double? = nil
        var perDay: [DayValue] = []
        var byCategory: [CategoryStat] = []
        var merchants: [MerchantStat] = []
    }

    func stats() -> Stats {
        let d = store.data, cal = Calendar.current, now = Date()
        let cy = Ledger.cycle(salaryDay: d.settings.salaryDay, ref: now)
        var s = Stats()
        s.start = cy.start; s.cycleStart = cy.start; s.end = cy.end; s.days = cy.days
        s.spent = Ledger.spent(d, from: cy.start, to: cy.end)
        s.budget = d.settings.dailyBudget * Double(cy.days)
        let from = Ledger.trackingStart(d, cycleStart: cy.start)
        let elapsed = max(1, (cal.dateComponents([.day], from: from, to: min(now, cy.end)).day ?? 0) + 1)
        let remainingDays = max(0, cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cy.end).day ?? 0) - 1
        s.avg = s.spent / Double(elapsed)
        s.projected = s.spent + s.avg * Double(max(0, remainingDays))
        s.start = from
        s.income = d.transactions.filter { $0.kind == .credit && !$0.excluded && $0.date >= cy.start && $0.date < cy.end }.reduce(0) { $0 + $1.amountHome }
        let prev = Ledger.cycle(salaryDay: d.settings.salaryDay, ref: cal.date(byAdding: .day, value: -1, to: cy.start) ?? cy.start)
        let prevSpent = Ledger.spent(d, from: prev.start, to: prev.start.addingTimeInterval(min(now, cy.end).timeIntervalSince(cy.start)))
        s.delta = prevSpent > 0 ? (s.spent - prevSpent) / prevSpent : nil
        s.perDay = (0..<cy.days).compactMap { (i: Int) -> DayValue? in
            guard let day = cal.date(byAdding: .day, value: i, to: from), day <= now, day < cy.end else { return nil }
            let b = Ledger.dayBounds(day)
            return DayValue(day: day, value: Ledger.spent(d, from: b.start, to: b.end))
        }
        let inCycle = d.transactions.filter { $0.counts && $0.date >= cy.start && $0.date < cy.end }
        let byCat = Dictionary(grouping: inCycle, by: { $0.categoryID }).mapValues { $0.reduce(0) { $0 + $1.amountHome } }
        s.byCategory = byCat.map { CategoryStat(category: d.category($0.key), amount: $0.value) }.sorted { $0.amount > $1.amount }
        let byMerchant = Dictionary(grouping: inCycle.filter { !$0.merchant.isEmpty }, by: { $0.merchantKey.isEmpty ? $0.merchant : $0.merchantKey })
        let stats: [MerchantStat] = byMerchant.values.map { (txs: [Transaction]) -> MerchantStat in
            MerchantStat(name: txs[0].merchant, icon: d.category(txs[0].categoryID).symbol, amount: txs.reduce(0.0) { $0 + $1.amountHome }, count: txs.count)
        }
        s.merchants = Array(stats.sorted { $0.amount > $1.amount }.prefix(5))
        return s
    }

    var body: some View {
        let s = stats()
        let lang = store.lang
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: store.t("insights"), subtitle: store.t("cycle") + ": " + Fmt.short(s.cycleStart, lang) + " – " + Fmt.short(s.end.addingTimeInterval(-86400), lang)) { EmptyView() }
                if store.data.transactions.isEmpty {
                    EmptyCard(icon: "chart", title: store.t("noData"), text: store.t("noTodayP"))
                } else {
                    cyclePanel(s)
                    kpis(s)
                    SectionHeader(title: store.t("perDay")) {
                        if store.data.settings.dailyBudget > 0 { Text(store.t("budgetLine")).font(.alx(13)).foregroundStyle(p.label2) }
                    }
                    chart(s)
                    if !s.byCategory.isEmpty {
                        SectionHeader(store.t("byCat"))
                        SurfaceGroup {
                            ForEach(s.byCategory) { item in
                                if item.id != s.byCategory.first?.id { RowDivider() }
                                Button { nav.txFilter = item.category.id; nav.tab = .txs } label: { categoryRow(item, total: s.spent) }.buttonStyle(PressStyle())
                            }
                        }
                    }
                    if !s.merchants.isEmpty {
                        SectionHeader(store.t("topMerchants"))
                        SurfaceGroup {
                            ForEach(s.merchants) { m in
                                if m.id != s.merchants.first?.id { RowDivider() }
                                HStack(spacing: 14) {
                                    Icon3D(name: m.icon, size: 40, shadow: true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.name).font(.alx(16, .semibold)).foregroundStyle(p.label).lineLimit(1)
                                        Text("×\(m.count)").font(.alx(13.5)).foregroundStyle(p.label2)
                                    }
                                    Spacer()
                                    Text("\u{200E}" + Fmt.m(m.amount)).font(.alx(17, .semibold)).monospacedDigit().foregroundStyle(p.label)
                                }
                                .padding(.horizontal, 16).frame(minHeight: 64)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    func cyclePanel(_ s: Stats) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.t("cycleSpent"))
                Spacer()
                if s.budget > 0 { Text(store.t("of") + " ") + Text(Fmt.m0(s.budget)).foregroundColor(p.label).font(.alx(15, .semibold)) + Text(" " + store.t("cur")) }
            }
            .font(.alx(15)).foregroundStyle(p.label2)
            BigAmount(value: s.spent).padding(.top, 2)
            if s.budget > 0 { ProgressBar(fraction: s.spent / s.budget).padding(.top, 12) }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
    }

    func kpis(_ s: Stats) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            kpi(store.t("dailyAvg"), Fmt.m(s.avg), nil, nil)
            if s.budget > 0 {
                let over = s.projected > s.budget
                kpi(store.t("projected"), Fmt.m0(s.projected),
                    (over ? "▲ " : "▼ ") + store.t(over ? "overBy2" : "underBy2", ["n": Fmt.m0(abs(s.projected - s.budget))]), over ? Tok.danger : Tok.positive)
            } else {
                kpi(store.t("projected"), Fmt.m0(s.projected), nil, nil)
            }
            if let d = s.delta {
                kpi(store.t("vsPrev"), (d > 0 ? "+" : "") + String(format: "%.0f%%", d * 100), nil, nil, valueColor: d > 0 ? Tok.danger : Tok.positive)
            } else {
                kpi(store.t("vsPrev"), "—", nil, nil)
            }
            kpi(store.t("income"), Fmt.m0(s.income), nil, nil, valueColor: Tok.positive)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    func kpi(_ title: String, _ value: String, _ note: String?, _ noteColor: Color?, valueColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.alx(13)).foregroundStyle(p.label2)
            Text("\u{200E}" + value).font(.alx(24, .semibold)).monospacedDigit().foregroundStyle(valueColor ?? p.label).lineLimit(1).minimumScaleFactor(0.6)
            if let note { Text(note).font(.alx(12)).foregroundStyle(noteColor ?? p.label2).lineLimit(1).minimumScaleFactor(0.7) }
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func chart(_ s: Stats) -> some View {
        let budget = store.data.settings.dailyBudget
        let todayStart = Calendar.current.startOfDay(for: Date())
        return Chart {
            ForEach(s.perDay) { item in
                BarMark(x: .value("Day", item.day, unit: .day), y: .value("QAR", item.value))
                    .foregroundStyle(item.day == todayStart ? Tok.tint : (budget > 0 && item.value > budget ? Tok.warning : p.label3.opacity(0.7)))
                    .cornerRadius(3)
            }
            if budget > 0 {
                RuleMark(y: .value("Budget", budget))
                    .foregroundStyle(p.label2)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXScale(domain: s.start...s.end)
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .frame(height: 150)
        .overlay(alignment: .bottom) {
            HStack {
                Text(Fmt.short(s.start, store.lang))
                Spacer()
                Text(Fmt.short(s.end.addingTimeInterval(-86400), store.lang))
            }
            .font(.alx(12)).foregroundStyle(p.label3)
            .offset(y: 20)
        }
        .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 30)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
    }

    func categoryRow(_ item: CategoryStat, total: Double) -> some View {
        let share = total > 0 ? item.amount / total : 0
        let pct = Int((share * 100).rounded())
        let budgetNote = item.category.monthlyBudget.map { " · " + store.t("of") + " " + Fmt.m0($0) } ?? ""
        return HStack(spacing: 12) {
            Icon3D(name: item.category.symbol, size: 40, shadow: true)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.category.name(store.lang)).font(.alx(15.5, .medium)).foregroundStyle(p.label)
                    Spacer()
                    Text("\u{200E}" + Fmt.m(item.amount)).font(.alx(15.5, .medium)).monospacedDigit().foregroundStyle(p.label)
                }
                ProgressBar(fraction: share, height: 7, colors: [Color(hexString: item.category.color), Color(hexString: item.category.color)])
                Text("\(pct)" + (store.lang == .ar ? "٪" : "%") + budgetNote).font(.alx(12.5)).foregroundStyle(p.label2)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .contentShape(Rectangle())
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

struct SettingsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @State private var confirmWipe = false

    private struct BG: Identifiable { let id: String; let key: String; let color: Color }
    private let backgrounds: [BG] = [BG(id: "wine", key: "bgWine", color: Color(hex: 0x17080F)), BG(id: "navy", key: "bgNavy", color: Color(hex: 0x0B1020)),
                                     BG(id: "graphite", key: "bgGraphite", color: Color(hex: 0x121114))]

    var body: some View {
        let st = store.data.settings
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: store.t("settings")) { EmptyView() }

                SectionHeader(store.t("appearance"), strong: false)
                SurfaceGroup {
                    SettingRow(icon: "palette", title: store.t("bg"), chevron: false) {
                        HStack(spacing: 10) {
                            ForEach(backgrounds) { b in
                                Button { store.update { $0.settings.background = b.id } } label: {
                                    Circle().fill(b.color).frame(width: 30, height: 30)
                                        .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 2))
                                        .padding(3)
                                        .overlay(Circle().strokeBorder(st.background == b.id ? Tok.tintInk : Color.clear, lineWidth: 2))
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel(store.t(b.key))
                                .accessibilityAddTraits(st.background == b.id ? .isSelected : [])
                            }
                        }
                    }
                    RowDivider()
                    Button { store.update { $0.settings.language = $0.settings.language == .ar ? .en : .ar } } label: {
                        SettingRow(icon: "globe", title: store.t("language")) { Text(st.language == .ar ? "العربية" : "English") }
                    }
                    .buttonStyle(PressStyle())
                }

                SectionHeader(store.t("budget"), strong: false)
                SurfaceGroup {
                    Button { nav.sheet = .budget } label: {
                        SettingRow(icon: "budget", title: store.t("daily")) { Text(st.dailyBudget > 0 ? "\u{200E}" + Fmt.m0(st.dailyBudget) + " " + store.t("cur") : "—") }
                    }
                    .buttonStyle(PressStyle())
                    RowDivider()
                    Button { nav.path.append(.salary) } label: {
                        SettingRow(icon: "calendar", title: store.t("salaryDay")) { Text("\(st.salaryDay)") }
                    }
                    .buttonStyle(PressStyle())
                    RowDivider()
                    toggleRow("bell", store.t("alert80d"), \.alert80)
                    RowDivider()
                    toggleRow("bell", store.t("alert100d"), \.alert100)
                    RowDivider()
                    toggleRow("sms", store.t("perTx"), \.notifyEach)
                }

                SectionHeader(store.t("categories"), strong: false)
                SurfaceGroup {
                    Button { nav.path.append(.categories) } label: {
                        SettingRow(icon: "label", title: store.t("categories")) { Text("\(store.data.categories.count)") }
                    }
                    .buttonStyle(PressStyle())
                }

                SectionHeader(store.t("auto"), strong: false)
                SurfaceGroup {
                    Button { nav.path.append(.guide) } label: {
                        SettingRow(icon: "zap", title: store.t("guide")) {
                            if store.data.lastAuto != nil { Text(store.t("on")).font(.alx(15, .semibold)).foregroundStyle(Tok.positive) } else { Text(store.t("notYet")) }
                        }
                    }
                    .buttonStyle(PressStyle())
                    if let last = store.data.lastAuto {
                        RowDivider()
                        SettingRow(icon: "calendar", title: store.t("lastAuto"), chevron: false) { Text(Fmt.short(last, store.lang) + " · " + Fmt.time(last)) }
                    }
                    RowDivider()
                    Button { store.update { $0.settings.onboarded = false } } label: {
                        SettingRow(icon: "bulb", title: store.t("replay")) { EmptyView() }
                    }
                    .buttonStyle(PressStyle())
                }

                SectionHeader(store.t("data"), strong: false)
                SurfaceGroup {
                    Button { nav.sheet = .add(paste: false) } label: { SettingRow(icon: "receipt", title: store.t("addManual")) { EmptyView() } }
                        .buttonStyle(PressStyle())
                    RowDivider()
                    Button { nav.sheet = .add(paste: true) } label: { SettingRow(icon: "sms", title: store.t("pasteOld")) { EmptyView() } }
                        .buttonStyle(PressStyle())
                    RowDivider()
                    ShareLink(item: CSVFile(text: Ledger.csv(store.data)), preview: SharePreview("masroufi.csv")) {
                        SettingRow(icon: "export", title: store.t("export")) { EmptyView() }
                    }
                    RowDivider()
                    Button {
                        if confirmWipe { store.wipe(); confirmWipe = false } else { withAnimation { confirmWipe = true } }
                    } label: {
                        Text(confirmWipe ? store.t("wipeQ") : store.t("wipe")).font(.alx(16)).foregroundStyle(Tok.danger)
                            .frame(maxWidth: .infinity, minHeight: 56).padding(.horizontal, 16)
                    }
                }

                VStack(spacing: 4) {
                    Text(store.t("version"))
                    Text(store.t("credits")).multilineTextAlignment(.center)
                }
                .font(.alx(12.5)).foregroundStyle(p.label3)
                .padding(.horizontal, 24).padding(.top, 22)
            }
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    func toggleRow(_ icon: String, _ title: String, _ kp: WritableKeyPath<Settings, Bool>) -> some View {
        SettingRow(icon: icon, title: title, chevron: false) {
            Toggle("", isOn: store.setting(kp)).labelsHidden().tint(Tok.tint)
        }
    }
}
