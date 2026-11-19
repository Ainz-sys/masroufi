import SwiftUI
import UIKit

// MARK: - Small shared pieces

struct ToggleRow: View {
    @Environment(\.palette) private var p
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.alx(15.5)).foregroundStyle(p.label).multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn).labelsHidden().tint(Tok.tint)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }
}

struct SegmentedControl: View {
    @Environment(\.palette) private var p
    let first: String
    let second: String
    @Binding var secondSelected: Bool
    var body: some View {
        HStack(spacing: 0) {
            segment(first, selected: !secondSelected) { secondSelected = false }
            segment(second, selected: secondSelected) { secondSelected = true }
        }
        .padding(3)
        .background(p.surface2, in: Capsule())
        .padding(.horizontal, 18)
    }

    func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeOut(duration: 0.2)) { action() } } label: {
            Text(title).font(.alx(14.5, .medium)).foregroundStyle(selected ? p.label : p.label2)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(selected ? p.surface : Color.clear).shadow(color: .black.opacity(selected ? 0.3 : 0), radius: 2, x: 0, y: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Bank SMS with what the parser read highlighted.
struct BankBubble: View {
    @Environment(\.palette) private var p
    let raw: String
    var body: some View {
        let parsed = SMSParser.parse(raw)
        let text = parsed?.normalized ?? SMSParser.normalize(raw)
        let latin = text.range(of: "[A-Za-z]{3}", options: .regularExpression) != nil
        var attr = AttributedString(text)
        var last = 0
        for m in parsed?.marks ?? [] where m.location >= last {
            if let r = Range(m, in: attr) {
                attr[r].backgroundColor = p.tintContainer
                attr[r].foregroundColor = p.onTintContainer
            }
            last = m.location + m.length
        }
        return Text(attr)
            .font(.alx(15))
            .foregroundStyle(p.label)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 15).padding(.vertical, 12)
            .background(p.surface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .environment(\.layoutDirection, latin ? .leftToRight : .rightToLeft)
            .textSelection(.enabled)
            .padding(.horizontal, 18)
    }
}

// MARK: - Transaction detail

struct DetailScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let txID: String
    @State private var confirmDelete = false
    @State private var note = ""
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            NavBar(title: store.t("tx")) { BackButton() } trailing: { Color.clear.frame(width: 46, height: 46) }
            if let tx = store.data.transactions.first(where: { $0.id == txID }) {
                content(tx)
            } else {
                Spacer()
            }
        }
        .background(p.bg.ignoresSafeArea())
        .onAppear { note = store.data.transactions.first { $0.id == txID }?.note ?? "" }
        .onDisappear(perform: saveNote)
    }

    func saveNote() {
        guard let tx = store.data.transactions.first(where: { $0.id == txID }), tx.note != note else { return }
        let n = note
        store.editTx(txID) { $0.note = n }
    }

    func content(_ tx: Transaction) -> some View {
        let lang = store.lang
        let c = store.data.category(tx.categoryID)
        let credit = tx.kind == .credit
        let sortedCats = store.data.categories.sorted { a, b in a.id == tx.categoryID && b.id != tx.categoryID }
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    Icon3D(name: c.symbol, size: 64, shadow: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tx.merchant.isEmpty ? c.name(lang) : tx.merchant).font(.alx(21, .bold)).foregroundStyle(p.label)
                        Text(Fmt.day(tx.date, lang) + (tx.noTime ? "" : " · " + Fmt.time(tx.date))).font(.alx(14.5)).foregroundStyle(p.label2)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 6)
                BigAmount(value: tx.amountHome, color: credit ? Tok.positive : nil, prefix: credit ? "+" : "")
                    .padding(.horizontal, 18).padding(.top, 14)
                if tx.currency != "QAR" {
                    Text("\u{200E}" + tx.currency + " " + Fmt.m(tx.amount)).font(.alx(14)).foregroundStyle(p.label2).padding(.horizontal, 18)
                }
                SurfaceGroup {
                    let facts = factRows(tx)
                    ForEach(facts, id: \.self) { f in
                        if f != facts.first { RowDivider() }
                        HStack {
                            Text(f[0]).font(.alx(15)).foregroundStyle(p.label2)
                            Spacer()
                            Text("\u{200E}" + f[1]).font(.alx(15, .semibold)).foregroundStyle(p.label)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 56)
                    }
                }
                .padding(.top, 14)

                SectionHeader(store.t("category"))
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Chip(icon: "plus", title: store.t("newCat"), dashed: true) { nav.sheet = .newCategory(forTx: tx.id) }
                                .id("new-category")
                            ForEach(sortedCats) { k in
                                Chip(icon: k.symbol, title: k.name(lang), selected: k.id == tx.categoryID) { store.setCategory(txID, k.id) }
                                    .id(k.id)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .onAppear {
                        DispatchQueue.main.async { proxy.scrollTo("new-category", anchor: .leading) }
                    }
                }

                SurfaceGroup {
                    if !tx.merchantKey.isEmpty {
                        ToggleRow(title: store.t("remember", ["c": c.name(lang), "m": tx.merchantKey]), isOn: Binding(
                            get: { store.data.merchantMap[tx.merchantKey] == tx.categoryID },
                            set: { _ in store.toggleRemember(txID) }))
                        RowDivider()
                    }
                    ToggleRow(title: store.t("include"), isOn: Binding(get: { !tx.excluded }, set: { v in store.editTx(txID) { $0.excluded = !v } }))
                    RowDivider()
                    HStack(spacing: 12) {
                        Text(store.t("note")).font(.alx(15)).foregroundStyle(p.label2)
                        TextField("", text: $note, prompt: Text(store.t("notePh")).foregroundColor(p.label3))
                            .font(.alx(16)).foregroundStyle(p.label).focused($noteFocused).submitLabel(.done)
                            .onSubmit(saveNote)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 56)
                }
                .padding(.top, 14)
                .onChange(of: noteFocused) { _, focused in if !focused { saveNote() } }

                if !tx.raw.isEmpty {
                    SectionHeader(title: store.t("bankMsg")) { Text(store.t("autoRead")).font(.alx(13)).foregroundStyle(p.label2) }
                    BankBubble(raw: tx.raw)
                }

                SurfaceGroup {
                    Button {
                        if confirmDelete { store.deleteTx(txID); dismiss() } else { withAnimation { confirmDelete = true } }
                    } label: {
                        Text(confirmDelete ? store.t("delQ") : store.t("del")).font(.alx(16)).foregroundStyle(Tok.danger)
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                }
                .padding(.top, 22)
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    func factRows(_ tx: Transaction) -> [[String]] {
        var rows: [[String]] = []
        if !tx.card.isEmpty { rows.append([store.t("card"), "•••• " + tx.card]) }
        if !tx.account.isEmpty { rows.append([store.t("account"), "•••• " + tx.account]) }
        if let b = tx.balance { rows.append([store.t("balanceAfter"), Fmt.m(b) + " " + store.t("cur")]) }
        if !tx.bank.isEmpty { rows.append([store.t("bank"), tx.bank]) }
        rows.append([store.t("source"), tx.source == .sms ? store.t("sms") : store.t("manual")])
        return rows
    }
}

// MARK: - Add (manual or pasted SMS)

struct AddSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State var paste: Bool
    @State private var amountText = ""
    @State private var merchant = ""
    @State private var categoryID = "other"
    @State private var autoCategory = true
    @State private var date = Date()
    @State private var pasted = ""
    @FocusState private var focus: Field?
    enum Field { case amount, merchant, paste }

    var amount: Double? { Double(SMSParser.normalize(amountText).replacingOccurrences(of: ",", with: "")) }
    var found: [(ParsedSMS, String)] { Ledger.parseMany(pasted) }
    var canSave: Bool { paste ? !found.isEmpty : (amount ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: store.t("addTx")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: { Color.clear.frame(width: 44, height: 44) }
                SegmentedControl(first: store.t("manualTab"), second: store.t("paste"), secondSelected: $paste)
                ScrollView {
                    if paste { pasteForm } else { manualForm }
                }
                .scrollDismissesKeyboard(.interactively)
                BottomBar {
                    PrimaryButton(title: paste ? store.t("addN", ["n": found.isEmpty ? "" : "\(found.count)"]) : store.t("add"), enabled: canSave) { save() }
                }
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t("done")) { focus = nil }.font(.alx(16, .semibold))
                }
            }
            .onAppear { if paste && pasted.isEmpty, let demo = Demo.pasteText { pasted = demo } }
        }
    }

    var manualForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            FieldBox(label: store.t("amount")) {
                TextField("", text: $amountText, prompt: Text("0.00").foregroundColor(p.label3))
                    .font(.alx(28, .semibold)).monospacedDigit().foregroundStyle(p.label)
                    .keyboardType(.decimalPad).focused($focus, equals: .amount)
            }
            FieldBox(label: store.t("merchant")) {
                TextField("", text: $merchant).font(.alx(16)).foregroundStyle(p.label)
                    .focused($focus, equals: .merchant).submitLabel(.done).autocorrectionDisabled()
                    .onChange(of: merchant) { _, v in
                        guard autoCategory else { return }
                        let guess = store.data.merchantMap[SMSParser.merchantKey(v)] ?? SMSParser.categorize(merchant: v)
                        if guess != "other" { withAnimation { categoryID = guess } }
                    }
            }
            FieldBox(label: store.t("when")) {
                DatePicker("", selection: $date, in: ...Date()).labelsHidden().tint(Tok.tint)
            }
            SectionHeader(store.t("category"))
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.data.categories.filter { $0.id != "income" }) { c in
                            Chip(icon: c.symbol, title: c.name(store.lang), selected: categoryID == c.id) { categoryID = c.id; autoCategory = false }
                                .id(c.id)
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .onChange(of: categoryID) { _, id in withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
        .padding(.bottom, 24)
    }

    var pasteForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if pasted.isEmpty {
                    Text(store.t("pastePh")).font(.alx(16)).foregroundStyle(p.label3).padding(.horizontal, 20).padding(.vertical, 22)
                }
                TextEditor(text: $pasted)
                    .font(.alx(16)).foregroundStyle(p.label)
                    .scrollContentBackground(.hidden)
                    .focused($focus, equals: .paste)
                    .padding(12)
            }
            .frame(minHeight: 140)
            .background(p.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 18).padding(.top, 14)
            PastePreview(text: pasted)
        }
        .padding(.bottom, 24)
    }

    func save() {
        focus = nil
        if paste {
            let n = store.addPasted(pasted)
            nav.show(store.t("saved") + " · \(n)")
        } else if let a = amount, a > 0 {
            store.addManual(amount: a, merchant: merchant, categoryID: categoryID, date: date, kind: .debit)
            nav.show(store.t("saved"))
        }
        dismiss()
    }
}

struct PastePreview: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    let text: String
    var body: some View {
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let found = Ledger.parseMany(text)
            if found.isEmpty {
                Text(store.t("notFound")).font(.alx(13.5)).foregroundStyle(p.label2).padding(.horizontal, 22).padding(.top, 10)
            } else {
                SectionHeader(store.t("found", ["n": "\(found.count)"]), strong: false)
                SurfaceGroup {
                    ForEach(Array(found.enumerated()), id: \.offset) { item in
                        if item.offset > 0 { RowDivider() }
                        TxRow(tx: Ledger.transaction(from: item.element.0, raw: item.element.1, data: store.data, now: Date(), live: false))
                    }
                }
            }
        }
    }
}

// MARK: - Categories

struct CategoriesScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p

    var body: some View {
        VStack(spacing: 0) {
            NavBar(title: store.t("categories")) { BackButton() } trailing: {
                RoundButton(systemImage: "plus", label: store.t("newCat")) { nav.sheet = .newCategory(forTx: nil) }
            }
            ScrollView {
                SurfaceGroup {
                    ForEach(store.data.categories) { c in
                        if c.id != store.data.categories.first?.id { RowDivider() }
                        Button { nav.sheet = .editCategory(c.id) } label: {
                            SettingRow(icon: c.symbol, title: c.name(store.lang)) {
                                Text((c.monthlyBudget.map { "\u{200E}" + Fmt.m0($0) + " · " } ?? "") + (c.builtIn ? store.t("builtin") : ""))
                            }
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .background(p.bg.ignoresSafeArea())
    }
}

struct CategoryEditorSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let categoryID: String?
    let forTx: String?
    @State private var name = ""
    @State private var icon = "gym"
    @State private var color = Category.colorChoices[2]
    @State private var budgetText = ""
    @State private var alert = true
    @State private var confirmDelete = false
    @FocusState private var focused: Bool

    var existing: Category? { categoryID.flatMap { id in store.data.categories.first { $0.id == id } } }
    var valid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: existing == nil ? store.t("newCat") : store.t("editCat")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: {
                    TextAction(title: existing == nil ? store.t("add") : store.t("save")) { save() }.disabled(!valid).opacity(valid ? 1 : 0.4)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        token.frame(maxWidth: .infinity).padding(.top, 8)
                        FieldBox(label: store.t("name")) {
                            TextField("", text: $name).font(.alx(16)).foregroundStyle(p.label).focused($focused).submitLabel(.done)
                        }
                        Text(store.t("icon")).font(.alx(13)).foregroundStyle(p.label2).padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 6)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(Category.symbolChoices, id: \.self) { s in
                                Button { withAnimation(.easeOut(duration: 0.15)) { icon = s } } label: {
                                    Icon3D(name: s, size: 34)
                                        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(icon == s ? p.tintContainer : p.surface2))
                                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(icon == s ? Tok.tint : Color.clear, lineWidth: 2))
                                }
                                .buttonStyle(PressStyle())
                            }
                        }
                        .padding(.horizontal, 18)
                        Text(store.t("color")).font(.alx(13)).foregroundStyle(p.label2).padding(.horizontal, 22).padding(.top, 14).padding(.bottom, 6)
                        HStack {
                            ForEach(Category.colorChoices, id: \.self) { hex in
                                Button { color = hex } label: { swatch(hex) }.buttonStyle(PressStyle())
                                if hex != Category.colorChoices.last { Spacer(minLength: 4) }
                            }
                        }
                        .padding(.horizontal, 22)
                        FieldBox(label: store.t("catBudget")) {
                            TextField("", text: $budgetText, prompt: Text("0").foregroundColor(p.label3)).font(.alx(16)).foregroundStyle(p.label).keyboardType(.decimalPad)
                        }
                        SurfaceGroup { ToggleRow(title: store.t("alert80"), isOn: $alert) }.padding(.top, 14)
                        if let c = existing, !c.builtIn {
                            SurfaceGroup {
                                Button {
                                    if confirmDelete { store.deleteCategory(c.id); dismiss() } else { withAnimation { confirmDelete = true } }
                                } label: {
                                    Text(confirmDelete ? store.t("wipeQ") : store.t("delCat")).font(.alx(16)).foregroundStyle(Tok.danger).frame(maxWidth: .infinity, minHeight: 56)
                                }
                            }
                            .padding(.top, 14)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                BottomBar {
                    PrimaryButton(title: existing == nil ? store.t("addCat") : store.t("save"), enabled: valid) { save() }
                }
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t("done")) { hideKeyboard() }.font(.alx(16, .semibold))
                }
            }
            .onAppear(perform: load)
        }
    }

    var token: some View {
        let c = Color(hexString: color)
        return ZStack {
            Circle().fill(RadialGradient(colors: [c, c.opacity(0.75)], center: UnitPoint(x: 0.42, y: 0.36), startRadius: 0, endRadius: 60))
            Circle().fill(RadialGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.45)], center: UnitPoint(x: 0.42, y: 0.36), startRadius: 18, endRadius: 62))
            Circle().fill(RadialGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0)], center: UnitPoint(x: 0.32, y: 0.24), startRadius: 0, endRadius: 26))
            Icon3D(name: icon, size: 54)
        }
        .frame(width: 92, height: 92)
        .shadow(color: c.opacity(0.38), radius: 17, x: 0, y: 16)
        .animation(.easeOut(duration: 0.2), value: color)
    }

    func swatch(_ hex: String) -> some View {
        let c = Color(hexString: hex)
        return ZStack {
            Circle().fill(RadialGradient(colors: [c, c.opacity(0.7)], center: UnitPoint(x: 0.4, y: 0.36), startRadius: 0, endRadius: 24))
            Circle().fill(RadialGradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0)], center: UnitPoint(x: 0.34, y: 0.28), startRadius: 0, endRadius: 12))
        }
        .frame(width: 40, height: 40)
        .padding(2)
        .overlay(Circle().strokeBorder(color == hex ? c : Color.clear, lineWidth: 2).padding(-3))
        .frame(width: 48, height: 48)
        .accessibilityAddTraits(color == hex ? .isSelected : [])
    }

    func load() {
        guard let c = existing else { return }
        name = c.name(store.lang); icon = c.symbol; color = c.color; alert = c.alertAt80
        budgetText = c.monthlyBudget.map { Fmt.m0($0).replacingOccurrences(of: ",", with: "") } ?? ""
    }

    func save() {
        guard valid else { return }
        let n = name.trimmingCharacters(in: .whitespaces)
        let budget = Double(SMSParser.normalize(budgetText).replacingOccurrences(of: ",", with: ""))
        var c = existing ?? Category(id: "c" + String(UUID().uuidString.prefix(8)).lowercased(), nameAR: n, nameEN: n, symbol: icon)
        if c.builtIn { if store.lang == .ar { c.nameAR = n } else { c.nameEN = n } } else { c.nameAR = n; c.nameEN = n }
        c.symbol = icon; c.color = color; c.alertAt80 = alert
        c.monthlyBudget = (budget ?? 0) > 0 ? budget : nil
        store.saveCategory(c)
        if let tx = forTx { store.setCategory(tx, c.id) }
        nav.show(store.t("saved"))
        dismiss()
    }
}

// MARK: - Budget & salary day

struct BudgetSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var value: Double { Double(SMSParser.normalize(text).replacingOccurrences(of: ",", with: "")) ?? 0 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: store.t("daily")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: {
                    TextAction(title: store.t("save")) { save() }
                }
                ScrollView {
                    VStack(spacing: 0) {
                        BudgetInput(text: $text).padding(.top, 14)
                        Presets(values: [150, 200, 300, 500, 800], text: $text).padding(.top, 18)
                        SurfaceGroup {
                            SettingRow(icon: "cash", title: store.t("monthBudget"), chevron: false) {
                                Text("\u{200E}≈ " + Fmt.m0(value * Double(Ledger.cycle(salaryDay: store.data.settings.salaryDay).days)) + " " + store.t("cur"))
                            }
                        }
                        .padding(.top, 24)
                    }
                }
                BottomBar { PrimaryButton(title: store.t("save")) { save() } }
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t("done")) { hideKeyboard() }.font(.alx(16, .semibold))
                }
            }
            .onAppear { let b = store.data.settings.dailyBudget; text = b > 0 ? Fmt.m0(b).replacingOccurrences(of: ",", with: "") : "" }
        }
        .presentationDetents([.medium, .large])
    }

    func save() {
        let v = max(0, value)
        store.update { $0.settings.dailyBudget = v }
        nav.show(store.t("saved"))
        dismiss()
    }
}

struct BudgetInput: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    @Binding var text: String
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("", text: $text, prompt: Text("0").foregroundColor(p.label3))
                .font(.alx(64, .semibold, relativeTo: .largeTitle)).monospacedDigit()
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundStyle(p.label)
                .frame(width: 200)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) { Rectangle().fill(Tok.tintInk).frame(height: 2) }
                .environment(\.layoutDirection, .leftToRight)
            Text(store.t("cur")).font(.alx(20)).foregroundStyle(p.label2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct Presets: View {
    let values: [Double]
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            ForEach(values, id: \.self) { v in
                let s = Fmt.m0(v)
                Chip(title: s, selected: text == s) { text = s }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SalaryGrid: View {
    @Environment(\.palette) private var p
    let selected: Int
    let pick: (Int) -> Void
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(1...28, id: \.self) { d in
                Button { pick(d) } label: {
                    Text("\(d)").font(.alx(16, .medium)).monospacedDigit()
                        .foregroundStyle(d == selected ? Color.white : p.label)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(d == selected ? Tok.tint : p.surface))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, 18)
    }
}

struct SalaryScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            NavBar(title: store.t("salaryDay")) { BackButton() } trailing: { Color.clear.frame(width: 46, height: 46) }
            ScrollView {
                Text(store.t("salaryHint")).font(.alx(13.5)).foregroundStyle(p.label2).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.vertical, 8)
                SalaryGrid(selected: store.data.settings.salaryDay) { d in
                    store.update { $0.settings.salaryDay = d }
                    dismiss()
                }
            }
        }
        .background(p.bg.ignoresSafeArea())
    }
}

// MARK: - Auto-logging guide

struct GuideSteps: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(1...5, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i)").font(.alx(13.5, .semibold)).foregroundStyle(p.label)
                        .frame(width: 26, height: 26).background(Circle().fill(p.surface2))
                    Text(store.t("st\(i)")).font(.alx(15)).foregroundStyle(p.label).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
            }
            Text(store.t("tip")).font(.alx(13.5)).foregroundStyle(p.label2).lineSpacing(3).padding(.top, 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}

struct GuideScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(spacing: 0) {
            NavBar(title: store.t("guide")) { BackButton() } trailing: { Color.clear.frame(width: 46, height: 46) }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Icon3D(name: "zap", size: 84, shadow: true).padding(.horizontal, 18).padding(.top, 4)
                    Text(store.t("ob3t")).font(.alx(26, .bold)).foregroundStyle(p.label).padding(.horizontal, 18).padding(.top, 8)
                    Text(store.t("ob3p")).font(.alx(15.5, .light)).foregroundStyle(p.label2).lineSpacing(5).padding(.horizontal, 18).padding(.top, 8)
                    GuideSteps()
                    SurfaceGroup {
                        Button { nav.sheet = .add(paste: true) } label: { SettingRow(icon: "sms", title: store.t("testIt")) { EmptyView() } }
                            .buttonStyle(PressStyle())
                    }
                    .padding(.top, 18)
                }
                .padding(.bottom, 24)
            }
            BottomBar {
                PrimaryButton(title: store.t("openShortcuts"), systemImage: "arrow.up.forward.app") {
                    if let u = URL(string: "shortcuts://") { openURL(u) }
                }
            }
        }
        .background(p.bg.ignoresSafeArea())
    }
}
