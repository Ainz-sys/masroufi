import SwiftUI
import Charts
import UniformTypeIdentifiers
import UserNotifications

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var store: Store
    @StateObject private var nav = Nav()

    var body: some View {
        let scale = TextScale.factor(for: Demo.value("-masroufiText") ?? store.data.settings.textSize, screenWidth: Layout.screenWidth)
        TextScale.factor = scale   // read by every Font.alx below
        return Group {
            if store.data.settings.onboarded { MainShell() } else { OnboardingFlow() }
        }
        .id(scale)                 // a new text size rebuilds the screens with it
        .environmentObject(nav)
        .environment(\.palette, store.palette)
        .environment(\.layoutDirection, store.lang == .ar ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: store.lang == .ar ? "ar_QA@numbers=latn" : "en_GB"))
        .preferredColorScheme(.dark)
        .tint(Tok.tint)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)   // grows with the user's text size, without breaking words apart
        .onAppear { Demo.apply(nav: nav) }
    }
}

struct MainShell: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @State private var keyboardUp = false

    var body: some View {
        NavigationStack(path: $nav.path) {
            Group {
                switch nav.tab {
                case .home: HomeScreen()
                case .txs: TransactionsScreen()
                case .plan: PlanScreen()
                case .analytics: AnalyticsScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                Group {
                    switch route {
                    case .detail(let id): DetailScreen(txID: id)
                    case .categories: CategoriesScreen()
                    case .guide: GuideScreen()
                    case .salary: SalaryScreen()
                    case .settings: SettingsScreen()
                    case .review: ReviewScreen()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .overlay {
            // Laid out on the whole screen (safe areas ignored) and placed from the real insets of this iPhone,
            // so the bar sits just above the home indicator on every model instead of floating mid-air.
            GeometryReader { geo in
                let top = max(geo.safeAreaInsets.top, Layout.windowInsets.top)
                let gap = Layout.tabBarGap(bottomInset: max(geo.safeAreaInsets.bottom, Layout.windowInsets.bottom))
                let showBar = nav.path.isEmpty && !keyboardUp
                ZStack {
                    // content scrolling under the clock / Dynamic Island fades out instead of colliding with it
                    LinearGradient(stops: [.init(color: p.bg, location: 0), .init(color: p.bg, location: 0.7),
                                           .init(color: p.bg.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                        .frame(height: top + 4)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .allowsHitTesting(false)
                    if showBar {
                        // and fades out behind the floating bar, so nothing shows through below it
                        LinearGradient(stops: [.init(color: p.bg.opacity(0), location: 0), .init(color: p.bg.opacity(0.88), location: 0.55),
                                               .init(color: p.bg, location: 1)], startPoint: .top, endPoint: .bottom)
                            .frame(height: gap + Layout.tabBarHeight + 22)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                        FloatingTabBar()
                            .padding(.bottom, gap)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let t = nav.toast {
                        Toast(text: t)
                            .padding(.bottom, gap + Layout.tabBarHeight + 14)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .animation(.easeOut(duration: 0.2), value: showBar)
            }
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardUp = false }
        .sheet(item: $nav.sheet) { route in SheetHost(route: route) }
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
            case .rename(let id): RenameSheet(txID: id)
            case .planned(let id): PlannedSheet(plannedID: id)
            case .merchantBudget(let id): MerchantBudgetSheet(budgetID: id)
            case .fixedPlan: FixedPlanSheet()
            case .pickCategory(let id, let review): CategoryPickerSheet(txID: id, review: review)
            }
        }
        .environmentObject(store)
        .environmentObject(nav)
        .environment(\.palette, store.palette)
        .environment(\.layoutDirection, store.lang == .ar ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: store.lang == .ar ? "ar_QA@numbers=latn" : "en_GB"))
        .preferredColorScheme(.dark)
        .tint(Tok.tint)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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

/// What is left of this month's budget. Everything dated this month counts, including older transactions added later.
struct RemainingPanel: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    let month: Ledger.Month
    var vsLast: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if month.budget > 0 {
                HStack(alignment: .firstTextBaseline) {
                    Text(store.t("remainingMonth"))
                    Spacer()
                    Text(store.t("of") + " ") + Text(Fmt.m0(month.budget)).foregroundColor(p.label).font(.alx(15, .semibold)) + Text(" " + store.t("cur"))
                }
                .font(.alx(15)).foregroundStyle(p.label2)
                BigAmount(value: abs(month.remaining), color: month.remaining < 0 ? Tok.danger : nil, prefix: month.remaining < 0 ? "-" : "")
                    .padding(.top, 2)
                ProgressBar(fraction: month.fraction).padding(.top, 12)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { pill; comparePill; Spacer(minLength: 0) }
                    VStack(alignment: .leading, spacing: 8) { pill; comparePill }
                }
                .padding(.top, 12)
            } else {
                HStack {
                    Text(store.t("spentMonth")).font(.alx(15)).foregroundStyle(p.label2)
                    Spacer()
                    Button { nav.sheet = .budget } label: {
                        Text(store.t("monthly") + " +").font(.alx(14.5, .medium)).foregroundStyle(Tok.tintInk).frame(minHeight: 44)
                    }
                }
                BigAmount(value: month.spent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 4)
    }

    /// "≈ 510 a day" while on budget (amber when close to the limit), or how much over.
    @ViewBuilder var pill: some View {
        if month.spent > month.budget {
            StatusPill(kind: .over, text: store.t("over") + " " + Fmt.m0(month.spent - month.budget))
        } else {
            StatusPill(kind: month.fraction >= 0.8 ? .warn : .ok, text: store.t("aDay", ["d": Fmt.m0(month.perDay)]))
        }
    }

    /// Spending so far against the same point of last month.
    @ViewBuilder var comparePill: some View {
        if let v = vsLast, abs(v) >= 1 {
            let better = v <= 0
            HStack(spacing: 5) {
                Image(systemName: better ? "arrowtriangle.down.fill" : "arrowtriangle.up.fill").font(.system(size: 9, weight: .bold))
                Text(store.t(better ? "lessLast" : "moreLast", ["n": Fmt.m0(abs(v))])).font(.alx(13, .semibold, relativeTo: .caption))
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(better ? Color(hex: 0x9CCBFF) : Tok.warning)
            .padding(.horizontal, 12)
            .frame(minHeight: 30)
            .background((better ? Color(hex: 0x6DB7FF) : Tok.warning).opacity(0.15), in: Capsule())
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

// MARK: - Transactions

struct TransactionsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @State private var query = ""
    @State private var pendingDelete: String? = nil
    @FocusState private var searching: Bool

    /// `nav.txFilter` value for the review queue (any other value is a category id).
    static let reviewFilter = "@review"

    func matches(_ tx: Transaction, _ q: String) -> Bool {
        if let f = nav.txFilter {
            if f == Self.reviewFilter { if !tx.needsReview { return false } } else if tx.categoryID != f { return false }
        }
        if q.isEmpty { return true }
        let tags = (tx.tags ?? []).map { $0.lowercased() }
        if q.hasPrefix("#") { let t = String(q.dropFirst()); return t.isEmpty ? !tags.isEmpty : tags.contains { $0.hasPrefix(t) } }
        return tx.displayName.lowercased().contains(q) || tx.merchant.lowercased().contains(q) || Fmt.m(tx.amountHome).contains(q)
            || tx.note.lowercased().contains(q) || tags.contains { $0.contains(q) }
            || store.data.category(tx.categoryID).name(store.lang).lowercased().contains(q)
    }

    var groups: [DayGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let list = store.data.transactions.filter { matches($0, q) }
        let g = Dictionary(grouping: list) { Calendar.current.startOfDay(for: $0.date) }
        return g.keys.sorted(by: >).map { DayGroup(id: $0, txs: (g[$0] ?? []).sorted { $0.date > $1.date }) }
    }

    /// Categories in use, the most used first.
    var usedCategories: [Category] {
        var count: [String: Int] = [:]
        for t in store.data.transactions { count[t.categoryID, default: 0] += 1 }
        return store.data.categories.filter { count[$0.id] != nil }.sorted { (count[$0.id] ?? 0) > (count[$1.id] ?? 0) }
    }

    var body: some View {
        let groups = self.groups
        List {
            Section {
                header
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if groups.isEmpty {
                Section {
                    VStack(spacing: 6) {
                        Icon3D(name: "receipt", size: 64, shadow: true).padding(.bottom, 4)
                        Text(store.t("noTxT")).font(.alx(17, .semibold)).foregroundStyle(p.label)
                        Text(store.data.transactions.isEmpty ? store.t("noTodayP") : store.t("noTxP")).font(.alx(14.5)).foregroundStyle(p.label2).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24).padding(.horizontal, 16)
                    .listRowBackground(p.surface)
                }
            }
            ForEach(groups) { g in
                Section {
                    ForEach(g.txs) { tx in row(tx) }
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(dayLabel(g.id, store)).font(.alx(15, .semibold)).foregroundStyle(p.label)
                        Spacer()
                        Text("\u{200E}" + Fmt.m(g.txs.filter(\.counts).reduce(0) { $0 + $1.amountHome })).font(.alx(13.5)).foregroundStyle(p.label2)
                    }
                    .textCase(nil)
                    .padding(.top, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listSectionSpacing(4)
        .environment(\.defaultMinListRowHeight, 10)
        .contentMargins(.bottom, 104, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .confirmationDialog(store.t("delOneQ"), isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button(store.t("delete"), role: .destructive) {
                if let id = pendingDelete { withAnimation { store.deleteTx(id) } }
                pendingDelete = nil
            }
            Button(store.t("cancel"), role: .cancel) { pendingDelete = nil }
        }
    }

    var header: some View {
        let m = Ledger.month(store.data)
        let monthCount = store.data.transactions.filter { $0.date >= m.start && $0.date < m.end }.count
        let reviewCount = store.data.transactions.filter(\.needsReview).count
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.t("txs")).font(.alx(30, .bold, relativeTo: .largeTitle)).foregroundStyle(p.label)
                Text(store.t("txsSub", ["n": "\(monthCount)"])).font(.alx(14, relativeTo: .subheadline)).foregroundStyle(p.label2)
            }
            .padding(.top, 6)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 16, weight: .medium)).foregroundStyle(p.label3)
                TextField("", text: $query, prompt: Text(store.t("searchAll")).foregroundColor(p.label3))
                    .font(.alx(15.5)).foregroundStyle(p.label).focused($searching).submitLabel(.search).autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(p.label3) }
                        .accessibilityLabel(store.t("cancel"))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(p.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 14)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Chip(title: store.t("allCats"), selected: nav.txFilter == nil) { nav.txFilter = nil }
                    if reviewCount > 0 || nav.txFilter == Self.reviewFilter {
                        Chip(title: store.t("toReview") + " \(reviewCount)", selected: nav.txFilter == Self.reviewFilter) { nav.txFilter = Self.reviewFilter }
                    }
                    ForEach(usedCategories) { c in
                        Chip(icon: c.symbol, title: c.name(store.lang), selected: nav.txFilter == c.id) { nav.txFilter = c.id }
                    }
                    ForEach(store.allTags.prefix(6), id: \.self) { t in
                        Chip(title: "#" + t, selected: query == "#" + t.lowercased()) { query = query == "#" + t.lowercased() ? "" : "#" + t.lowercased() }
                    }
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }

    func row(_ tx: Transaction) -> some View {
        Button { nav.path.append(.detail(tx.id)) } label: { TxRow(tx: tx) }
            .buttonStyle(PressStyle())
            .listRowInsets(EdgeInsets())
            .listRowBackground(p.surface)
            .listRowSeparatorTint(p.separator)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button { pendingDelete = tx.id } label: { Label(store.t("delete"), systemImage: "trash") }.tint(Tok.danger)
                Button { nav.sheet = .pickCategory(tx.id, review: false) } label: { Label(store.t("categorize"), systemImage: "tag") }.tint(Color(hex: 0x4D9CFF))
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if tx.needsReview {
                    Button { store.confirm(tx.id) } label: { Label(store.t("markOK"), systemImage: "checkmark") }.tint(Tok.positive)
                }
            }
            .contextMenu {
                if tx.needsReview { Button { store.confirm(tx.id) } label: { Label(store.t("markOK"), systemImage: "checkmark") } }
                Button { nav.sheet = .pickCategory(tx.id, review: false) } label: { Label(store.t("categorize"), systemImage: "tag") }
                Button { nav.sheet = .rename(tx.id) } label: { Label(store.t("rename"), systemImage: "pencil") }
                Button(role: .destructive) { pendingDelete = tx.id } label: { Label(store.t("delete"), systemImage: "trash") }
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

// MARK: - Settings

/// Settings → Text size: automatic (by the iPhone's screen size) or a fixed small / medium / large.
struct TextSizeRow: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    private let options: [(id: String, key: String)] = [("auto", "tsAuto"), ("s", "tsS"), ("m", "tsM"), ("l", "tsL")]

    var body: some View {
        let current = store.data.settings.textSize
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text("Aa").font(.alx(17, .semibold)).foregroundStyle(Tok.gold)
                    .frame(width: 34, height: 34).background(Circle().fill(p.surface2)).accessibilityHidden(true)
                Text(store.t("textSize")).font(.alx(16)).foregroundStyle(p.label)
                Spacer(minLength: 8)
            }
            HStack(spacing: 4) {
                ForEach(options, id: \.id) { o in
                    let selected = current == o.id
                    Button {
                        guard !selected else { return }
                        UISelectionFeedbackGenerator().selectionChanged()
                        store.update { $0.settings.textSize = o.id }
                    } label: {
                        Text(store.t(o.key)).font(.alx(14, .medium)).lineLimit(1).minimumScaleFactor(0.7)
                            .foregroundStyle(selected ? Color.white : p.label)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(Capsule().fill(selected ? Tok.tint : Color.clear))
                    }
                    .buttonStyle(PressStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Capsule().fill(p.surface2))
            if current == "auto" {
                Text(store.t("tsAutoHint")).font(.alx(13)).foregroundStyle(p.label2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

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
    @State private var notifStatus: UNAuthorizationStatus? = nil
    @Environment(\.openURL) private var openURL

    private struct BG: Identifiable { let id: String; let key: String; let color: Color }
    private let backgrounds: [BG] = [BG(id: "wine", key: "bgWine", color: Color(hex: 0x17080F)), BG(id: "navy", key: "bgNavy", color: Color(hex: 0x0B1020)),
                                     BG(id: "graphite", key: "bgGraphite", color: Color(hex: 0x121114))]

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    func saveName() {
        let n = name.trimmingCharacters(in: .whitespaces)
        if n != store.data.settings.name { store.update { $0.settings.name = n } }
    }

    var body: some View {
        let st = store.data.settings
        VStack(spacing: 0) {
        NavBar(title: store.t("settings")) { BackButton() } trailing: { Color.clear.frame(width: 46, height: 46) }
        ScrollViewReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                SurfaceGroup {
                    HStack(spacing: 14) {
                        Icon3D(name: "id", size: 34)
                        Text(store.t("yourName")).font(.alx(16)).foregroundStyle(p.label)
                        TextField("", text: $name, prompt: Text(store.t("namePh")).foregroundColor(p.label3))
                            .font(.alx(15.5)).foregroundStyle(p.label).multilineTextAlignment(.trailing)
                            .focused($nameFocused).submitLabel(.done).onSubmit(saveName)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 56)
                }
                .padding(.top, 4)
                .onChange(of: nameFocused) { _, f in if !f { saveName() } }

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
                    RowDivider()
                    TextSizeRow()
                }

                SectionHeader(store.t("budget"), strong: false)
                SurfaceGroup {
                    Button { nav.sheet = .budget } label: {
                        SettingRow(icon: "budget", title: store.t("monthly")) { Text(st.monthlyBudget > 0 ? "\u{200E}" + Fmt.m0(st.monthlyBudget) + " " + store.t("cur") : "—") }
                    }
                    .buttonStyle(PressStyle())
                    RowDivider()
                    Button { nav.path.append(.salary) } label: {
                        SettingRow(icon: "calendar", title: store.t("salaryDay")) { Text("\(st.salaryDay)") }
                    }
                    .buttonStyle(PressStyle())
                }

                SectionHeader(store.t("notifications"), strong: false).id("notif")
                SurfaceGroup {
                    Button { notifTapped() } label: {
                        SettingRow(icon: "bell", title: store.t("notifStatus"), chevron: !notifOn) {
                            if notifOn {
                                Text(store.t("notifOnS")).font(.alx(15, .semibold)).foregroundStyle(Tok.positive)
                            } else if notifStatus == .denied {
                                Text(store.t("notifOffS")).font(.alx(15, .semibold)).foregroundStyle(Tok.warning)
                            } else {
                                Text(store.t("notifAsk")).font(.alx(15, .semibold)).foregroundStyle(Tok.tintInk)
                            }
                        }
                    }
                    .buttonStyle(PressStyle())
                    if notifStatus == .denied {
                        RowDivider()
                        Button { openSystemSettings() } label: {
                            Text(store.t("notifOff")).font(.alx(14.5)).foregroundStyle(Tok.warning).multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading).padding(.horizontal, 16)
                        }
                    }
                    RowDivider()
                    toggleRow("cash", store.t("alert80d"), \.alert80)
                    RowDivider()
                    toggleRow("zap", store.t("alert100d"), \.alert100)
                    RowDivider()
                    toggleRow("receipt", store.t("perTx"), \.notifyEach)
                    RowDivider()
                    Button { sendTest() } label: { SettingRow(icon: "sms", title: store.t("testNotif"), chevron: false) { EmptyView() } }
                        .buttonStyle(PressStyle())
                }
                Text(store.t("notifFoot")).font(.alx(13)).foregroundStyle(p.label2)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.top, 8)

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
                            if store.data.autoOn { Text(store.t("on")).font(.alx(15, .semibold)).foregroundStyle(Tok.positive) } else { Text(store.t("notYet")) }
                        }
                    }
                    .buttonStyle(PressStyle())
                    if let last = store.data.lastAuto {
                        RowDivider()
                        SettingRow(icon: "calendar", title: store.t("lastAuto"), chevron: false) { Text(Fmt.short(last, store.lang) + " · " + Fmt.time(last)) }
                    } else if let run = store.data.lastAutoRun {
                        RowDivider()
                        SettingRow(icon: "sms", title: store.t("lastRun"), chevron: false) { Text(Fmt.short(run, store.lang) + " · " + Fmt.time(run)) }
                    } else if store.data.autoWaiting && store.data.lastApplePay == nil {
                        RowDivider()
                        SettingRow(icon: "sms", title: store.t("autoWaiting"), chevron: false) { EmptyView() }
                    }
                    if let ap = store.data.lastApplePay {
                        RowDivider()
                        SettingRow(icon: "card", title: store.t("apLast"), chevron: false) { Text(Fmt.short(ap, store.lang) + " · " + Fmt.time(ap)) }
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
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { // screenshot check of the notifications section
            if Demo.screen == "settings-notif" { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { proxy.scrollTo("notif", anchor: .top) } }
        }
        }
        }
        .background(p.bg.ignoresSafeArea())
        .onAppear { name = store.data.settings.name }
        .onDisappear(perform: saveName)
        .task { await refreshNotif() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshNotif() }   // back from iPhone Settings
        }
    }

    var notifOn: Bool {
        guard let s = notifStatus else { return false }
        return s == .authorized || s == .provisional || s == .ephemeral
    }

    func refreshNotif() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        notifStatus = s.authorizationStatus
    }

    func openSystemSettings() {
        if let u = URL(string: UIApplication.openSettingsURLString) { openURL(u) }
    }

    /// Off because never asked: ask now. Turned off in iPhone Settings: open them.
    func notifTapped() {
        if notifStatus == .denied { openSystemSettings(); return }
        guard !notifOn else { return }
        Task { _ = await Notifier.requestPermission(); await refreshNotif() }
    }

    func sendTest() {
        Task {
            if !notifOn { _ = await Notifier.requestPermission(); await refreshNotif() }
            if notifStatus == .denied { openSystemSettings(); return }
            Notifier.send(store.t("testNotifT"), store.t("testNotifB"))
        }
    }

    func toggleRow(_ icon: String, _ title: String, _ kp: WritableKeyPath<Settings, Bool>) -> some View {
        SettingRow(icon: icon, title: title, chevron: false) {
            Toggle("", isOn: store.setting(kp)).labelsHidden().tint(Tok.tint)
        }
    }
}
