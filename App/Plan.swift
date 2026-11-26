import SwiftUI
import UIKit

// MARK: - Segments

/// Two or three options in a row; the selected one is filled with the accent.
struct PillSegments: View {
    @Environment(\.palette) private var p
    let titles: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(titles.indices, id: \.self) { i in
                let selected = selection == i
                Button {
                    guard !selected else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.easeOut(duration: 0.2)) { selection = i }
                } label: {
                    Text(titles[i]).font(.alx(14.5, .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(selected ? Color.white : p.label2)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Tok.tint : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 18)
    }
}

enum GroupColor {
    static let fixed = Color(hex: 0xE4457A)
    static let flex = Color(hex: 0xF7BC5C)
    static let nonMonthly = Color(hex: 0xB39DFF)
    static func of(_ g: Ledger.Group) -> Color { g == .fixed ? fixed : g == .flex ? flex : nonMonthly }
}

func monthName(_ m: Int, _ lang: Lang) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: lang == .ar ? "ar" : "en_GB")
    let names = f.standaloneMonthSymbols ?? []
    return names.indices.contains(m - 1) ? names[m - 1] : "\(m)"
}

/// A ring split into parts; each part shows how much of it is used.
struct SplitRing: View {
    @Environment(\.palette) private var p
    struct Part { let color: Color; let total: Double; let used: Double }
    let parts: [Part]
    var lineWidth: CGFloat = 18

    var body: some View {
        let sum = max(0.0001, parts.reduce(0) { $0 + max(0, $1.total) })
        let gap = parts.filter { $0.total > 0 }.count > 1 ? 0.012 : 0
        var acc = 0.0
        let arcs: [(Color, Double, Double, Double)] = parts.compactMap { part in
            guard part.total > 0 else { return nil }
            let from = acc + gap / 2, to = acc + part.total / sum - gap / 2
            acc += part.total / sum
            let used = from + min(1, max(0, part.used / part.total)) * (to - from)
            return (part.color, from, max(from, to), used)
        }
        return ZStack {
            Circle().stroke(p.track.opacity(0.6), lineWidth: lineWidth)
            ForEach(arcs.indices, id: \.self) { i in
                let a = arcs[i]
                Circle().trim(from: a.1, to: a.2).stroke(a.0.opacity(0.26), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                Circle().trim(from: a.1, to: a.3).stroke(a.0, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2)
    }
}

// MARK: - Planning

struct PlanScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p

    var body: some View {
        let d = store.data
        let m = Ledger.month(d)
        let lang = store.lang
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: store.t("plan"), subtitle: store.t("cycleRange", ["a": Fmt.short(m.start, lang), "b": Fmt.short(m.end.addingTimeInterval(-86400), lang)])) {
                    EmptyView()
                }
                if m.budget <= 0 {
                    EmptyCard(icon: "budget", title: store.t("noBudgetT"), text: store.t("noBudgetP"), actions: AnyView(
                        SmallButton(title: store.t("setBudget")) { nav.sheet = .budget }))
                } else if d.settings.budgetMode == "category" {
                    categoryCard(m)
                } else {
                    flexCard(Ledger.flexPlan(d), month: m)
                }
                linesSection
                plannedSection
            }
            .padding(.bottom, 104)
        }
        .scrollIndicators(.hidden)
    }

    func modeSwitch(_ toCategory: Bool) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.easeOut(duration: 0.2)) { store.update { $0.settings.budgetMode = toCategory ? "category" : "flex" } }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 11, weight: .semibold))
                Text(store.t(toCategory ? "catMode" : "flexModeL")).font(.alx(13, .medium))
            }
            .foregroundStyle(p.label2)
            .padding(.horizontal, 12).frame(minHeight: 34)
            .background(Capsule().fill(p.surface2))
        }
        .buttonStyle(PressStyle())
    }

    // Flexible: fixed costs set aside, non-monthly costs spread over the year, the rest is flexible.
    func flexCard(_ fp: Ledger.FlexPlan, month m: Ledger.Month) -> some View {
        let lang = store.lang
        let plannedHint = store.data.planned.prefix(2).map { $0.name + " · " + monthName($0.month, lang) }.joined(separator: "، ")
        let ring = SplitRing(parts: [
            .init(color: GroupColor.fixed, total: fp.fixedPlanned, used: fp.fixedSpent),
            .init(color: GroupColor.flex, total: fp.flexBudget, used: fp.flexSpent),
            .init(color: GroupColor.nonMonthly, total: fp.nonMonthly, used: fp.nonMonthlySpent),
        ])
        .overlay {
            VStack(spacing: 0) {
                Text(store.t("leftL")).font(.alx(12.5)).foregroundStyle(p.label2)
                Text("\u{200E}" + (m.remaining < 0 ? "-" : "") + Fmt.m0(abs(m.remaining))).font(.alx(22, .bold)).monospacedDigit()
                    .foregroundStyle(m.remaining < 0 ? Tok.danger : p.label).lineLimit(1).minimumScaleFactor(0.6)
                Text(store.t("of") + " " + Fmt.m0(m.budget)).font(.alx(11.5)).foregroundStyle(p.label3)
            }
            .padding(30)
        }
        .frame(width: 138, height: 138)
        let legend = VStack(alignment: .leading, spacing: 12) {
            Button { nav.sheet = .fixedPlan } label: {
                legendRow(GroupColor.fixed, store.t("fixed"), store.t("fixedHint") + (fp.fixedEstimated ? " · " + store.t("estimated") : ""), fp.fixedSpent, fp.fixedPlanned, edit: true)
            }
            .buttonStyle(PressStyle())
            legendRow(GroupColor.flex, store.t("flex"), store.t("flexHint"), fp.flexSpent, fp.flexBudget, edit: false)
            if fp.nonMonthly > 0 {
                legendRow(GroupColor.nonMonthly, store.t("nonMonthly"), plannedHint, fp.nonMonthlySpent, fp.nonMonthly, edit: false)
            }
        }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(store.t("flexBudget")).font(.alx(17, .bold)).foregroundStyle(p.label)
                Spacer()
                modeSwitch(true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { ring; legend }
                VStack(spacing: 14) { ring; legend }
            }
            let over = fp.flexRemaining < 0
            Text(over ? store.t("flexOver", ["o": Fmt.m0(-fp.flexRemaining)])
                      : store.t("flexLeft", ["l": Fmt.m0(fp.flexRemaining), "d": Fmt.m0(fp.flexPerDay)]))
                .font(.alx(14, .semibold)).foregroundStyle(over ? Tok.danger : Tok.warning)
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(Capsule().fill((over ? Tok.danger : Tok.warning).opacity(0.13)))
        }
        .padding(16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
    }

    func legendRow(_ color: Color, _ title: String, _ hint: String, _ spent: Double, _ planned: Double, edit: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle().fill(color).frame(width: 9, height: 9).padding(.top, 6)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(title).font(.alx(15, .semibold)).foregroundStyle(p.label).lineLimit(1)
                    if edit { Image(systemName: "pencil").font(.system(size: 10, weight: .semibold)).foregroundStyle(p.label3) }
                    Spacer(minLength: 6)
                    Text("\u{200E}" + Fmt.m0(spent) + " / " + Fmt.m0(planned)).font(.alx(13)).monospacedDigit()
                        .foregroundStyle(spent > planned && planned > 0 ? Tok.danger : p.label2).lineLimit(1)
                }
                if !hint.isEmpty {
                    Text(hint).font(.alx(12)).foregroundStyle(p.label3).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
        }
        .frame(minWidth: 150)
        .contentShape(Rectangle())
    }

    // By category: the month's budget against what was given to each category.
    func categoryCard(_ m: Ledger.Month) -> some View {
        let given = store.data.categories.compactMap(\.monthlyBudget).reduce(0, +)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.t("catBudgetT")).font(.alx(17, .bold)).foregroundStyle(p.label)
                Spacer()
                modeSwitch(false)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(store.t("leftL")).font(.alx(14)).foregroundStyle(p.label2)
                Spacer()
                Text(store.t("of") + " " + Fmt.m0(m.budget)).font(.alx(13)).foregroundStyle(p.label2)
            }
            BigAmount(value: abs(m.remaining), color: m.remaining < 0 ? Tok.danger : nil, size: 40, prefix: m.remaining < 0 ? "-" : "")
            ProgressBar(fraction: m.fraction)
            Text(store.t("catBudgets") + ": " + Fmt.m0(given) + " / " + Fmt.m0(m.budget)).font(.alx(13)).foregroundStyle(p.label2)
        }
        .padding(16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
    }

    // Category and merchant budgets, fullest first.
    @ViewBuilder var linesSection: some View {
        let lines = Ledger.budgetLines(store.data, lang: store.lang)
        SectionHeader(title: store.t("catBudgets")) {
            Button { nav.path.append(.categories) } label: {
                Text(store.t("edit")).font(.alx(14, .medium)).foregroundStyle(Tok.tintInk).frame(minHeight: 44)
            }
        }
        if lines.isEmpty {
            Text(store.t("noLines")).font(.alx(14)).foregroundStyle(p.label2).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 18)
        } else {
            SurfaceGroup {
                ForEach(lines) { line in
                    if line.id != lines.first?.id { RowDivider() }
                    Button { nav.sheet = line.isMerchant ? .merchantBudget(line.id) : .editCategory(line.id) } label: { lineRow(line) }
                        .buttonStyle(PressStyle())
                }
            }
        }
        HStack(spacing: 8) {
            SmallButton(title: "+ " + store.t("addCatBudget"), ghost: true) { nav.path.append(.categories) }
            SmallButton(title: "+ " + store.t("addMerchantBudget"), ghost: true) { nav.sheet = .merchantBudget(nil) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).padding(.top, 10)
    }

    func lineRow(_ line: Ledger.BudgetLine) -> some View {
        let over = line.spent > line.total
        let color: Color = over ? Tok.danger : line.fraction >= 0.8 ? Tok.warning : Color(hexString: line.color)
        let pct = Int((line.fraction * 100).rounded())
        return HStack(spacing: 12) {
            ZStack {
                Circle().stroke(p.track, lineWidth: 4)
                Circle().trim(from: 0, to: min(1, line.fraction)).stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                Icon3D(name: line.icon, size: 26)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(line.name).font(.alx(16, .semibold)).foregroundStyle(p.label).lineLimit(1)
                    if line.carried > 0 {
                        Text(store.t("carried", ["n": Fmt.m0(line.carried)])).font(.alx(11, .semibold)).foregroundStyle(Color(hex: 0x9CCBFF))
                            .padding(.horizontal, 7).frame(height: 20).background(Capsule().fill(Color(hex: 0x6DB7FF).opacity(0.16))).fixedSize()
                    }
                    if over {
                        Text(store.t("overChip")).font(.alx(11, .semibold)).foregroundStyle(Tok.danger)
                            .padding(.horizontal, 7).frame(height: 20).background(Capsule().fill(Tok.danger.opacity(0.16))).fixedSize()
                    }
                }
                Text(store.t("leftOf", ["l": Fmt.m0(max(0, line.total - line.spent)), "b": Fmt.m0(line.total)])).font(.alx(13)).foregroundStyle(p.label2)
            }
            Spacer(minLength: 6)
            Text("\u{200E}\(pct)" + (store.lang == .ar ? "٪" : "%")).font(.alx(15, .semibold)).monospacedDigit().foregroundStyle(over ? Tok.danger : p.label)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .frame(minHeight: 68)
        .contentShape(Rectangle())
    }

    @ViewBuilder var plannedSection: some View {
        let lang = store.lang
        SectionHeader(store.t("plannedT"))
        Text(store.t("plannedHint")).font(.alx(13)).foregroundStyle(p.label2).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.bottom, 8)
        SurfaceGroup {
            ForEach(store.data.planned) { pl in
                Button { nav.sheet = .planned(pl.id) } label: {
                    HStack(spacing: 14) {
                        Icon3D(name: pl.icon, size: 40, shadow: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pl.name).font(.alx(16, .semibold)).foregroundStyle(p.label).lineLimit(1)
                            Text(store.t("plannedSub", ["y": Fmt.m0(pl.yearly), "m": Fmt.m0(pl.monthly), "mo": monthName(pl.month, lang)]))
                                .font(.alx(13)).foregroundStyle(p.label2).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward").font(.system(.footnote, weight: .semibold)).foregroundStyle(p.label3)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 64).contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                RowDivider()
            }
            Button { nav.sheet = .planned(nil) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                    Text(store.t("addPlanned")).font(.alx(15.5, .medium))
                    Spacer()
                }
                .foregroundStyle(Tok.tintInk)
                .padding(.horizontal, 16).frame(minHeight: 54).contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
    }
}

// MARK: - Fixed costs

struct FixedPlanSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var auto = true

    var estimate: Double { var d = store.data; d.settings.fixedPlanned = 0; return Ledger.flexPlan(d).fixedPlanned }
    var value: Double? { Double(SMSParser.normalize(text).replacingOccurrences(of: ",", with: "")) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: store.t("fixedPlanT")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: { TextAction(title: store.t("save")) { save() } }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(store.t("fixedPlanP")).font(.alx(14.5)).foregroundStyle(p.label2).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 22).padding(.top, 4)
                        SurfaceGroup {
                            ToggleRow(title: store.t("fixedAuto", ["n": Fmt.m0(estimate)]), isOn: $auto)
                        }
                        .padding(.top, 14)
                        if !auto {
                            FieldBox(label: store.t("fixedPlanT")) {
                                TextField("", text: $text, prompt: Text(Fmt.m0(estimate)).foregroundColor(p.label3))
                                    .font(.alx(24, .semibold)).monospacedDigit().foregroundStyle(p.label).keyboardType(.decimalPad)
                            }
                        }
                    }
                }
                BottomBar { PrimaryButton(title: store.t("save"), enabled: auto || (value ?? 0) > 0) { save() } }
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                let v = store.data.settings.fixedPlanned
                auto = v <= 0
                text = v > 0 ? Fmt.m0(v).replacingOccurrences(of: ",", with: "") : ""
            }
        }
        .presentationDetents([.medium, .large])
    }

    func save() {
        let v = auto ? 0 : (value ?? 0)
        store.update { $0.settings.fixedPlanned = max(0, v) }
        nav.show(store.t("saved"))
        dismiss()
    }
}

// MARK: - Non-monthly cost

struct PlannedSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let plannedID: String?
    @State private var name = ""
    @State private var icon = "calendar"
    @State private var autoIcon = true
    @State private var yearlyText = ""
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var categoryID: String? = nil
    @State private var confirmDelete = false

    var existing: PlannedExpense? { plannedID.flatMap { id in store.data.planned.first { $0.id == id } } }
    var yearly: Double? { Double(SMSParser.normalize(yearlyText).replacingOccurrences(of: ",", with: "")) }
    var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && (yearly ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: store.t(existing == nil ? "addPlanned" : "plannedT")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: { TextAction(title: store.t("save")) { save() }.disabled(!valid).opacity(valid ? 1 : 0.4) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Icon3D(name: icon, size: 64, shadow: true).frame(maxWidth: .infinity).padding(.top, 6)
                        FieldBox(label: store.t("name")) {
                            TextField("", text: $name).font(.alx(16)).foregroundStyle(p.label).submitLabel(.done)
                                .onChange(of: name) { _, v in
                                    guard autoIcon, let s = Category.suggestIcon(for: v) else { return }
                                    icon = s
                                }
                        }
                        FieldBox(label: store.t("yearly")) {
                            HStack {
                                TextField("", text: $yearlyText, prompt: Text("0").foregroundColor(p.label3))
                                    .font(.alx(22, .semibold)).monospacedDigit().foregroundStyle(p.label).keyboardType(.decimalPad)
                                if let y = yearly, y > 0 {
                                    Text(store.t("aMonth", ["d": Fmt.m0(y / 12)])).font(.alx(13)).foregroundStyle(p.label2).lineLimit(1)
                                }
                            }
                        }
                        Text(store.t("dueMonth")).font(.alx(13)).foregroundStyle(p.label2).padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 6)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(1...12, id: \.self) { m in
                                Button { month = m } label: {
                                    Text(monthName(m, store.lang)).font(.alx(13.5, .medium)).lineLimit(1).minimumScaleFactor(0.7)
                                        .foregroundStyle(month == m ? Color.white : p.label)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(month == m ? Tok.tint : p.surface2))
                                }
                                .buttonStyle(PressStyle())
                                .accessibilityAddTraits(month == m ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal, 18)
                        Text(store.t("linkCat")).font(.alx(13)).foregroundStyle(p.label2).padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 6)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Chip(title: store.t("noneCat"), selected: categoryID == nil) { categoryID = nil }
                                ForEach(store.data.categories.filter { $0.id != "income" }) { c in
                                    Chip(icon: c.symbol, title: c.name(store.lang), selected: categoryID == c.id) {
                                        categoryID = c.id
                                        if autoIcon { icon = c.symbol }
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                        }
                        if let e = existing {
                            SurfaceGroup {
                                Button {
                                    if confirmDelete { store.deletePlanned(e.id); dismiss() } else { withAnimation { confirmDelete = true } }
                                } label: {
                                    Text(confirmDelete ? store.t("delQ") : store.t("deleteIt")).font(.alx(16)).foregroundStyle(Tok.danger).frame(maxWidth: .infinity, minHeight: 56)
                                }
                            }
                            .padding(.top, 22)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                BottomBar { PrimaryButton(title: store.t("save"), enabled: valid) { save() } }
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t("done")) { hideKeyboard() }.font(.alx(16, .semibold))
                }
            }
            .onAppear {
                guard let e = existing else { return }
                autoIcon = false
                name = e.name; icon = e.icon; month = e.month; categoryID = e.categoryID
                yearlyText = Fmt.m0(e.yearly).replacingOccurrences(of: ",", with: "")
            }
        }
    }

    func save() {
        guard valid, let y = yearly else { return }
        var pl = existing ?? PlannedExpense(name: "", yearly: 0)
        pl.name = name.trimmingCharacters(in: .whitespaces)
        pl.icon = icon; pl.yearly = y; pl.month = month; pl.categoryID = categoryID
        store.savePlanned(pl)
        nav.show(store.t("saved"))
        dismiss()
    }
}

// MARK: - Merchant budget

struct MerchantBudgetSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let budgetID: String?
    @State private var name = ""
    @State private var amountText = ""
    @State private var keys: Set<String> = []
    @State private var confirmDelete = false

    struct Merchant: Identifiable { let id: String; let name: String; let icon: String; let count: Int }

    var existing: MerchantBudget? { budgetID.flatMap { id in store.data.merchantBudgets.first { $0.id == id } } }
    var amount: Double? { Double(SMSParser.normalize(amountText).replacingOccurrences(of: ",", with: "")) }
    var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && (amount ?? 0) > 0 && !keys.isEmpty }

    /// Merchants you've paid, the most frequent first.
    var merchants: [Merchant] {
        let d = store.data
        let g = Dictionary(grouping: d.transactions.filter { $0.kind == .debit && !$0.merchantKey.isEmpty }, by: \.merchantKey)
        return g.map { key, txs in
            let latest = txs.max { $0.date < $1.date } ?? txs[0]
            return Merchant(id: key, name: latest.displayName, icon: d.category(latest.categoryID).symbol, count: txs.count)
        }
        .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        .prefix(40).map { $0 }
    }

    var body: some View {
        let list = merchants
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: store.t("addMerchantBudget")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: { TextAction(title: store.t("save")) { save() }.disabled(!valid).opacity(valid ? 1 : 0.4) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        FieldBox(label: store.t("mbName")) {
                            TextField("", text: $name, prompt: Text(store.t("mbNamePh")).foregroundColor(p.label3)).font(.alx(16)).foregroundStyle(p.label)
                        }
                        FieldBox(label: store.t("mbAmount")) {
                            TextField("", text: $amountText, prompt: Text("0").foregroundColor(p.label3))
                                .font(.alx(22, .semibold)).monospacedDigit().foregroundStyle(p.label).keyboardType(.decimalPad)
                        }
                        SectionHeader(store.t("mbMerchants"), strong: false)
                        if list.isEmpty {
                            Text(store.t("noMerchants")).font(.alx(14)).foregroundStyle(p.label2).padding(.horizontal, 22)
                        } else {
                            SurfaceGroup {
                                ForEach(list) { m in
                                    if m.id != list.first?.id { RowDivider() }
                                    Button { if keys.contains(m.id) { keys.remove(m.id) } else { keys.insert(m.id) } } label: {
                                        HStack(spacing: 12) {
                                            Icon3D(name: m.icon, size: 32)
                                            Text(m.name).font(.alx(15.5)).foregroundStyle(p.label).lineLimit(1)
                                            Text("×\(m.count)").font(.alx(12.5)).foregroundStyle(p.label3)
                                            Spacer()
                                            Image(systemName: keys.contains(m.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 22)).foregroundStyle(keys.contains(m.id) ? Tok.tint : p.label3)
                                        }
                                        .padding(.horizontal, 16).frame(minHeight: 54).contentShape(Rectangle())
                                    }
                                    .buttonStyle(PressStyle())
                                    .accessibilityAddTraits(keys.contains(m.id) ? .isSelected : [])
                                }
                            }
                        }
                        if let e = existing {
                            SurfaceGroup {
                                Button {
                                    if confirmDelete { store.deleteMerchantBudget(e.id); dismiss() } else { withAnimation { confirmDelete = true } }
                                } label: {
                                    Text(confirmDelete ? store.t("delQ") : store.t("deleteIt")).font(.alx(16)).foregroundStyle(Tok.danger).frame(maxWidth: .infinity, minHeight: 56)
                                }
                            }
                            .padding(.top, 22)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                BottomBar { PrimaryButton(title: store.t("save"), enabled: valid) { save() } }
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t("done")) { hideKeyboard() }.font(.alx(16, .semibold))
                }
            }
            .onAppear {
                guard let e = existing else { return }
                name = e.name; keys = Set(e.keys)
                amountText = Fmt.m0(e.amount).replacingOccurrences(of: ",", with: "")
            }
        }
    }

    func save() {
        guard valid, let a = amount else { return }
        var b = existing ?? MerchantBudget(name: "", keys: [], amount: 0)
        b.name = name.trimmingCharacters(in: .whitespaces)
        b.amount = a
        b.keys = Array(keys)
        let icons = merchants.filter { keys.contains($0.id) }.map(\.icon)
        b.icon = Category.suggestIcon(for: b.name) ?? icons.first ?? "shopping"
        store.saveMerchantBudget(b)
        nav.show(store.t("saved"))
        dismiss()
    }
}
