import SwiftUI
import UIKit
import PhotosUI
import VisionKit

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
    @State private var addingTag = false
    @State private var newTag = ""
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
                        Button { nav.sheet = .rename(tx.id) } label: { // tap the name to rename it
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(tx.displayName.isEmpty ? c.name(lang) : tx.displayName).font(.alx(21, .bold)).foregroundStyle(p.label)
                                    .multilineTextAlignment(.leading)
                                Image(systemName: "pencil").font(.system(size: 15, weight: .semibold)).foregroundStyle(Tok.tintInk)
                            }
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityHint(store.t("rename"))
                        if tx.title != nil, !tx.merchant.isEmpty {
                            Text(tx.merchant).font(.alx(13)).foregroundStyle(p.label3).lineLimit(1)
                        }
                        Text(Fmt.day(tx.date, lang) + (tx.noTime ? "" : " · " + Fmt.time(tx.date))).font(.alx(14.5)).foregroundStyle(p.label2)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 6)
                BigAmount(value: tx.amountHome, color: credit ? Tok.positive : nil, prefix: credit ? "+" : "")
                    .padding(.horizontal, 18).padding(.top, 14)
                if tx.currency != "QAR" {
                    Text("\u{200E}" + tx.currency + " " + Fmt.m(tx.amount)).font(.alx(14)).foregroundStyle(p.label2).padding(.horizontal, 18)
                }
                refundSection(tx)
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
                        ToggleRow(title: store.t("remember", ["c": c.name(lang), "m": tx.displayName.isEmpty ? tx.merchantKey : tx.displayName]), isOn: Binding(
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

                SectionHeader(store.t("tags"), strong: false)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tx.tags ?? [], id: \.self) { t in
                            Button { store.removeTag(txID, t) } label: {
                                HStack(spacing: 6) {
                                    Text("#" + t).font(.alx(15, .medium))
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold)).foregroundStyle(p.label3)
                                }
                                .foregroundStyle(p.label)
                                .padding(.horizontal, 14).frame(height: 40)
                                .background(Capsule().fill(p.surface))
                            }
                            .buttonStyle(PressStyle())
                        }
                        Chip(icon: nil, title: "+ " + store.t("addTag"), dashed: true) { addingTag = true }
                    }
                    .padding(.horizontal, 18)
                }
                .alert(store.t("addTag"), isPresented: $addingTag) {
                    TextField(store.t("tagPh"), text: $newTag)
                    Button(store.t("add")) { store.addTag(txID, newTag); newTag = "" }
                    Button(store.t("cancel"), role: .cancel) { newTag = "" }
                }

                if tx.needsReview {
                    SurfaceGroup {
                        Button { UINotificationFeedbackGenerator().notificationOccurred(.success); store.confirm(txID) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 20))
                                Text(store.t("rvOK") + " · " + store.data.category(tx.categoryID).name(lang)).font(.alx(16, .semibold))
                            }
                            .foregroundStyle(Tok.positive)
                            .frame(maxWidth: .infinity, minHeight: 54)
                        }
                    }
                    .padding(.top, 16)
                }

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

    /// Money that came back for this purchase (or, on incoming money, the purchase it may give back).
    @ViewBuilder func refundSection(_ tx: Transaction) -> some View {
        let lang = store.lang
        if let back = tx.refunded, back > 0 {
            let refunds = Ledger.refunds(store.data, of: tx.id)
            let when = refunds.last.map { dayLabel($0.date, store) + ($0.noTime ? "" : " " + Fmt.time($0.date)) } ?? ""
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 20))
                    Text(store.t(tx.refundedFully ? "refundT" : "refundPartT")).font(.alx(16.5, .semibold))
                }
                .foregroundStyle(Tok.positive)
                Text(tx.refundedFully ? store.t("refundP", ["a": Fmt.m(back), "d": when])
                                      : store.t("refundPartP", ["a": Fmt.m(back), "d": when, "n": Fmt.m(tx.spentHome)]))
                    .font(.alx(14)).foregroundStyle(p.label).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Tok.positive.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 18).padding(.top, 14)
            ForEach(refunds) { r in
                if !r.raw.isEmpty {
                    SectionHeader(store.t("refundMsg"), strong: false)
                    BankBubble(raw: r.raw)
                }
                HStack {
                    TextAction(title: store.t("notRefund"), color: p.label2, weight: .medium) { store.unlinkRefund(r.id) }
                    Spacer()
                }
                .padding(.horizontal, 14)
            }
        } else if let pid = tx.refundOf {
            let purchase = store.data.transactions.first { $0.id == pid }
            VStack(alignment: .leading, spacing: 8) {
                Text(store.t("refundOfT") + " «" + (purchase?.displayName ?? "") + "»").font(.alx(15.5, .semibold)).foregroundStyle(Tok.positive)
                TextAction(title: store.t("notRefund"), color: p.label2, weight: .medium) { store.unlinkRefund(tx.id) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Tok.positive.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 18).padding(.top, 14)
        } else if tx.kind == .credit, tx.notRefund != true, let purchase = Ledger.likelyPurchase(store.data, for: tx) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.t("isRefundQ", ["m": purchase.displayName.isEmpty ? store.data.category(purchase.categoryID).name(lang) : purchase.displayName]))
                    .font(.alx(16, .semibold)).foregroundStyle(p.label)
                Text(store.t("isRefundP", ["d": dayLabel(purchase.date, store)])).font(.alx(13.5)).foregroundStyle(p.label2)
                    .fixedSize(horizontal: false, vertical: true)
                SmallButton(title: store.t("linkRefund")) {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    store.linkRefund(tx.id, to: purchase.id)
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(p.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 18).padding(.top, 14)
        }
    }

    func factRows(_ tx: Transaction) -> [[String]] {
        var rows: [[String]] = []
        if !tx.card.isEmpty { rows.append([store.t("card"), "•••• " + tx.card]) }
        if !tx.account.isEmpty { rows.append([store.t("account"), "•••• " + tx.account]) }
        if let b = tx.balance { rows.append([store.t("balanceAfter"), Fmt.m(b) + " " + store.t("cur")]) }
        if !tx.bank.isEmpty { rows.append([store.t("bank"), tx.bank]) }
        let src: String
        switch tx.source {
        case .sms: src = store.t("sms")
        case .applePay: src = store.t("applePay") + (tx.raw.isEmpty ? "" : " + " + store.t("sms"))
        case .receipt: src = store.t("receipt")
        case .manual: src = store.t("manual")
        }
        rows.append([store.t("source"), src])
        return rows
    }
}

// MARK: - Rename

/// Give a transaction a name you'll recognise. Optionally for every transaction from that merchant, now and later.
struct RenameSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let txID: String
    @State private var name = ""
    @State private var all = true
    @FocusState private var focused: Bool

    var tx: Transaction? { store.data.transactions.first { $0.id == txID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: store.t("rename")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: {
                    TextAction(title: store.t("save")) { save() }
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        FieldBox(label: store.t("txName")) {
                            TextField("", text: $name, prompt: Text(tx?.merchant ?? "").foregroundColor(p.label3))
                                .font(.alx(17, .medium)).foregroundStyle(p.label)
                                .focused($focused).submitLabel(.done).onSubmit(save)
                        }
                        if let tx, !tx.merchant.isEmpty {
                            Text(store.t("origName", ["m": tx.merchant])).font(.alx(13)).foregroundStyle(p.label2)
                                .padding(.horizontal, 22).padding(.top, 8)
                        }
                        if let tx, !tx.merchantKey.isEmpty {
                            SurfaceGroup { ToggleRow(title: store.t("renameAll"), isOn: $all) }.padding(.top, 16)
                        }
                        if tx?.title != nil {
                            SurfaceGroup {
                                Button { name = ""; save() } label: {
                                    Text(store.t("restoreName")).font(.alx(16)).foregroundStyle(Tok.tintInk).frame(maxWidth: .infinity, minHeight: 52)
                                }
                            }
                            .padding(.top, 14)
                        }
                    }
                    .padding(.bottom, 24)
                }
                BottomBar { PrimaryButton(title: store.t("save")) { save() } }
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                name = Demo.value("-masroufiRename") ?? tx?.title ?? tx?.merchant ?? ""
                if !Demo.active { focused = true }
            }
        }
        .presentationDetents([.medium, .large])
    }

    func save() {
        store.renameTx(txID, to: name, all: all)
        nav.show(store.t("saved"))
        dismiss()
    }
}

// MARK: - Add (keypad first, receipt scan, or pasted SMS)

struct AddSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Int          // 0 keypad, 1 receipt, 2 paste
    @State private var amountText = ""
    @State private var merchant = ""
    @State private var categoryID = "other"
    @State private var autoCategory = true
    @State private var date = Date()
    @State private var pasted = ""
    @State private var undatedDay = Date()
    @State private var source: TxSource = .manual
    @State private var receiptNote: String? = nil
    @State private var scanning = false
    @State private var reading = false
    @State private var photoItem: PhotosPickerItem? = nil
    @FocusState private var focus: Field?
    enum Field { case merchant, paste }

    init(paste: Bool) {
        _mode = State(initialValue: paste ? 2 : (Demo.screen == "add-receipt" ? 1 : 0))
    }

    var amount: Double? { Double(amountText) }
    var found: [(ParsedSMS, String)] { Ledger.parseMany(pasted) }
    var canSave: Bool { mode == 2 ? !found.isEmpty : (amount ?? 0) > 0 }
    var small: Bool { UIScreen.main.bounds.height < 700 }

    /// Categories you use most come first.
    var categories: [Category] {
        var count: [String: Int] = [:]
        for t in store.data.transactions where t.kind == .debit { count[t.categoryID, default: 0] += 1 }
        let list = store.data.categories.filter { $0.id != "income" }
        return list.enumerated().sorted { a, b in
            let ca = count[a.element.id] ?? 0, cb = count[b.element.id] ?? 0
            return ca != cb ? ca > cb : a.offset < b.offset
        }.map(\.element)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: store.t("addTx")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: {
                    TextAction(title: store.t("save")) { save() }.disabled(!canSave || mode == 1).opacity(canSave && mode != 1 ? 1 : 0.35)
                }
                PillSegments(titles: [store.t("manualTab"), store.t("receiptTab"), store.t("pasteTab")], selection: $mode)
                    .padding(.bottom, 4)
                switch mode {
                case 1: receiptForm
                case 2:
                    ScrollView { pasteForm }.scrollDismissesKeyboard(.interactively)
                    BottomBar {
                        PrimaryButton(title: store.t("addN", ["n": found.isEmpty ? "" : "\(found.count)"]), enabled: canSave) { save() }
                    }
                default: keypadForm
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
            .onAppear {
                if mode == 2 && pasted.isEmpty, let demo = Demo.pasteText { pasted = demo }
                if Demo.screen == "add" { amountText = "64"; merchant = "سنونو"; categoryID = "food"; autoCategory = false }
            }
            .fullScreenCover(isPresented: $scanning) {
                DocumentScanner { image in
                    scanning = false
                    if let image { readReceipt(image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { readReceipt(img) }
                    photoItem = nil
                }
            }
        }
    }

    // MARK: keypad

    var keypadForm: some View {
        VStack(spacing: 0) {
            VStack(spacing: small ? 8 : 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if store.lang == .ar { Text(store.t("cur")).font(.alx(18)).foregroundStyle(p.label2) }
                    Text(amountText.isEmpty ? "0" : amountText)
                        .font(.alx(small ? 46 : 56, .semibold, relativeTo: .largeTitle)).monospacedDigit()
                        .foregroundStyle(amountText.isEmpty ? p.label3 : p.label)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Capsule().fill(Tok.tint).frame(width: 3, height: small ? 38 : 46)
                    if store.lang != .ar { Text(store.t("cur")).font(.alx(18)).foregroundStyle(p.label2) }
                }
                .environment(\.layoutDirection, .leftToRight)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(store.t("amount")))
                .accessibilityValue(Text((amountText.isEmpty ? "0" : amountText) + " " + store.t("cur")))
                HStack(spacing: 8) {
                    DatePicker("", selection: $date, in: ...Date()).labelsHidden().tint(Tok.tint)
                    if source == .receipt {
                        Label(store.t("receipt"), systemImage: "doc.text.viewfinder").font(.alx(12.5, .medium)).foregroundStyle(Color(hex: 0x9CCBFF))
                            .padding(.horizontal, 10).frame(height: 30).background(Capsule().fill(Color(hex: 0x6DB7FF).opacity(0.15)))
                    }
                }
                if let note = receiptNote {
                    Text(note).font(.alx(12.5)).foregroundStyle(amount == nil ? Tok.warning : Tok.positive)
                }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories) { c in
                                Chip(icon: c.symbol, title: c.name(store.lang), selected: categoryID == c.id) { categoryID = c.id; autoCategory = false }
                                    .id(c.id)
                            }
                        }
                        .padding(.horizontal, 18)
                    }
                    .onChange(of: categoryID) { _, id in withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
                TextField("", text: $merchant, prompt: Text(store.t("merchant")).foregroundColor(p.label3))
                    .font(.alx(16)).foregroundStyle(p.label)
                    .focused($focus, equals: .merchant).submitLabel(.done).autocorrectionDisabled()
                    .padding(.horizontal, 16).frame(height: small ? 46 : 50)
                    .background(p.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 18)
                    .onChange(of: merchant) { _, v in
                        guard autoCategory else { return }
                        let guess = store.data.merchantMap[SMSParser.merchantKey(v)] ?? SMSParser.categorize(merchant: v)
                        if guess != "other" { withAnimation { categoryID = guess } }
                    }
            }
            .padding(.top, small ? 6 : 12)
            Spacer(minLength: 8)
            keypad
            PrimaryButton(title: canSave ? store.t("saveAmt", ["a": Fmt.m(amount ?? 0)]) : store.t("save"), enabled: canSave) { save() }
                .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 8)
        }
    }

    var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "del"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { k in
                Button { press(k) } label: {
                    Group {
                        if k == "del" { Image(systemName: "delete.left").font(.system(size: 21, weight: .medium)) }
                        else { Text(k).font(.alx(24, .medium)) }
                    }
                    .foregroundStyle(p.label)
                    .frame(maxWidth: .infinity, minHeight: small ? 46 : 54)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(k == "." || k == "del" ? Color.clear : p.surface))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressStyle())
                .accessibilityLabel(k == "del" ? Text("⌫") : Text(k))
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 18)
    }

    func press(_ k: String) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if source == .receipt && receiptNote != nil { receiptNote = nil }
        switch k {
        case "del": if !amountText.isEmpty { amountText.removeLast() }
        case ".": if !amountText.contains(".") { amountText = (amountText.isEmpty ? "0" : amountText) + "." }
        default:
            if let dot = amountText.firstIndex(of: ".") {
                if amountText[amountText.index(after: dot)...].count >= 2 { return }
            } else if amountText.count >= 7 { return }
            amountText = amountText == "0" ? k : amountText + k
        }
    }

    // MARK: receipt

    var receiptForm: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 10)
            Icon3D(name: "receipt", size: 92, shadow: true)
            Text(store.t("receiptHint")).font(.alx(15)).foregroundStyle(p.label2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 30)
            if reading {
                HStack(spacing: 8) { ProgressView().tint(Tok.tintInk); Text(store.t("reading")).font(.alx(14)).foregroundStyle(p.label2) }
            }
            Spacer(minLength: 10)
            VStack(spacing: 10) {
                PrimaryButton(title: store.t("scanCam"), systemImage: "camera.viewfinder", enabled: !reading) {
                    if VNDocumentCameraViewController.isSupported { scanning = true } else { receiptNote = store.t("noCamera") }
                }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle").font(.system(.body, weight: .semibold))
                        Text(store.t("pickPhoto")).font(.alx(17, .semibold, relativeTo: .headline))
                    }
                    .foregroundStyle(p.label)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(p.surface2))
                }
                .disabled(reading)
                if let note = receiptNote, mode == 1 {
                    Text(note).font(.alx(13)).foregroundStyle(Tok.warning)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 12)
        }
    }

    func readReceipt(_ image: UIImage) {
        reading = true
        Task {
            let r = await ReceiptReader.read(image)
            reading = false
            if let a = r.amount {
                amountText = a == a.rounded() ? String(Int(a)) : String(format: "%.2f", a)
            }
            if !r.merchant.isEmpty {
                merchant = r.merchant
                autoCategory = true
                let guess = store.data.merchantMap[SMSParser.merchantKey(r.merchant)] ?? SMSParser.categorize(merchant: r.merchant)
                if guess != "other" { categoryID = guess }
            }
            if let d = r.date { date = d }
            source = .receipt
            receiptNote = store.t(r.amount == nil ? "receiptFail" : "receiptRead")
            withAnimation(.easeOut(duration: 0.2)) { mode = 0 }
        }
    }

    // MARK: paste

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
            if found.contains(where: { $0.0.date == nil }) { // older messages without a date: pick the day they happened
                FieldBox(label: store.t("undatedDay")) {
                    DatePicker("", selection: $undatedDay, in: ...Date(), displayedComponents: .date).labelsHidden().tint(Tok.tint)
                }
            }
            PastePreview(text: pasted, undated: undatedDay)
        }
        .padding(.bottom, 24)
    }

    func save() {
        focus = nil
        if mode == 2 {
            let n = store.addPasted(pasted, undated: undatedDay)
            nav.show(store.t("saved") + " · \(n)")
        } else if let a = amount, a > 0 {
            store.addManual(amount: a, merchant: merchant, categoryID: categoryID, date: date, kind: .debit, source: source)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            nav.show(store.t("saved"))
        } else { return }
        dismiss()
    }
}

struct PastePreview: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    let text: String
    var undated: Date? = nil
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
                        TxRow(tx: Ledger.transaction(from: item.element.0, raw: item.element.1, data: store.data, now: Date(), live: false, undated: undated))
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
    @State private var icon = "other"
    @State private var autoIcon = true     // follows the name until the person picks an icon
    @State private var color = Category.colorChoices[2]
    @State private var budgetText = ""
    @State private var alert = true
    @State private var group = 0          // 0 auto, 1 fixed, 2 flexible
    @State private var rollover = false
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
                                .onChange(of: name) { _, v in
                                    guard autoIcon, let s = Category.suggestIcon(for: v), s != icon else { return }
                                    withAnimation(.easeOut(duration: 0.2)) { icon = s }
                                }
                        }
                        Text(store.t("icon") + " · " + store.t("iconHint")).font(.alx(13)).foregroundStyle(p.label2)
                            .padding(.horizontal, 22).padding(.top, 14)
                        ForEach(Category.iconGroups) { group in
                            Text(store.t(group.key)).font(.alx(12.5, .medium)).foregroundStyle(p.label3)
                                .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 6)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                                ForEach(group.icons, id: \.self) { s in
                                    Button { autoIcon = false; withAnimation(.easeOut(duration: 0.15)) { icon = s } } label: {
                                        Icon3D(name: s, size: 34)
                                            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(icon == s ? p.tintContainer : p.surface2))
                                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(icon == s ? Tok.tint : Color.clear, lineWidth: 2))
                                    }
                                    .buttonStyle(PressStyle())
                                    .accessibilityLabel(s)
                                    .accessibilityAddTraits(icon == s ? .isSelected : [])
                                }
                            }
                            .padding(.horizontal, 18)
                        }
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
                        SurfaceGroup {
                            ToggleRow(title: store.t("alert80"), isOn: $alert)
                            RowDivider()
                            ToggleRow(title: store.t("rolloverT"), isOn: $rollover)
                        }
                        .padding(.top, 14)
                        Text(store.t("groupT")).font(.alx(13)).foregroundStyle(p.label2).padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 6)
                        PillSegments(titles: [store.t("autoL"), store.t("fixed"), store.t("flex")], selection: $group)
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
        if let demo = Demo.value("-masroufiCatName") { name = demo }   // screenshot check of the icon suggestion
        guard let c = existing else { return }
        autoIcon = false
        name = c.name(store.lang); icon = c.symbol; color = c.color; alert = c.alertAt80
        group = c.group == "fixed" ? 1 : c.group == "flex" ? 2 : 0
        rollover = c.rollover
        budgetText = c.monthlyBudget.map { Fmt.m0($0).replacingOccurrences(of: ",", with: "") } ?? ""
    }

    func save() {
        guard valid else { return }
        let n = name.trimmingCharacters(in: .whitespaces)
        let budget = Double(SMSParser.normalize(budgetText).replacingOccurrences(of: ",", with: ""))
        var c = existing ?? Category(id: "c" + String(UUID().uuidString.prefix(8)).lowercased(), nameAR: n, nameEN: n, symbol: icon)
        if c.builtIn { if store.lang == .ar { c.nameAR = n } else { c.nameEN = n } } else { c.nameAR = n; c.nameEN = n }
        c.symbol = icon; c.color = color; c.alertAt80 = alert
        c.group = group == 1 ? "fixed" : group == 2 ? "flex" : nil
        c.rollover = rollover
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
                NavBar(title: store.t("monthly")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: {
                    TextAction(title: store.t("save")) { save() }
                }
                ScrollView {
                    VStack(spacing: 0) {
                        BudgetInput(text: $text).padding(.top, 14)
                        Presets(values: Presets.monthly, text: $text).padding(.top, 18)
                        SurfaceGroup {
                            SettingRow(icon: "cash", title: store.t("perDayShare"), chevron: false) {
                                Text("\u{200E}≈ " + Fmt.m0(value / Double(Ledger.cycle(salaryDay: store.data.settings.salaryDay).days)) + " " + store.t("cur"))
                            }
                        }
                        .padding(.top, 24)
                        Text(store.t("monthHint")).font(.alx(13.5)).foregroundStyle(p.label2)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.top, 8)
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
            .onAppear { let b = store.data.settings.monthlyBudget; text = b > 0 ? Fmt.m0(b).replacingOccurrences(of: ",", with: "") : "" }
        }
        .presentationDetents([.medium, .large])
    }

    func save() {
        let v = max(0, value)
        store.update { $0.settings.monthlyBudget = v; Ledger.resetMonthAlerts(&$0) }
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
                .font(.alx(56, .semibold, relativeTo: .largeTitle)).monospacedDigit()
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .foregroundStyle(p.label)
                .minimumScaleFactor(0.6)
                .frame(width: 240)
                .padding(.bottom, 4)
                .overlay(alignment: .bottom) { Rectangle().fill(Tok.tintInk).frame(height: 2) }
                .environment(\.layoutDirection, .leftToRight)
            Text(store.t("cur")).font(.alx(20)).foregroundStyle(p.label2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct Presets: View {
    static let monthly: [Double] = [3000, 5000, 10000, 15000]
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
            ForEach(1...6, id: \.self) { i in
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

/// Second, optional automation: Wallet "Transaction" → «سجّل دفعة Apple Pay».
struct ApplePaySteps: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Icon3D(name: "card", size: 30)
                Text(store.t("apT")).font(.alx(18, .bold)).foregroundStyle(p.label)
            }
            Text(store.t("apP")).font(.alx(14.5, .light)).foregroundStyle(p.label2).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            if let last = store.data.lastApplePay {
                StatusPill(kind: .ok, text: store.t("apLast") + " · " + Fmt.short(last, store.lang))
            }
            ForEach(1...4, id: \.self) { i in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i)").font(.alx(13.5, .semibold)).foregroundStyle(p.label)
                        .frame(width: 26, height: 26).background(Circle().fill(p.surface2))
                    Text(store.t("ap\(i)")).font(.alx(15)).foregroundStyle(p.label).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Tok.positive)
                Text(store.t("ap5")).font(.alx(13.5)).foregroundStyle(p.label2).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 26)
    }
}

struct GuideScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var openedShortcuts = false

    func openShortcuts() {
        openedShortcuts = true
        if let u = URL(string: "shortcuts://") { openURL(u) }
    }

    func confirm() {
        store.confirmAuto()
        nav.show(store.t("autoMarked"))
        dismiss()
    }

    var body: some View {
        VStack(spacing: 0) {
            NavBar(title: store.t("guide")) { BackButton() } trailing: { Color.clear.frame(width: 46, height: 46) }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Icon3D(name: "zap", size: 84, shadow: true).padding(.horizontal, 18).padding(.top, 4)
                    Text(store.t("ob3t")).font(.alx(26, .bold)).foregroundStyle(p.label).padding(.horizontal, 18).padding(.top, 8)
                    Text(store.t("ob3p")).font(.alx(15.5, .light)).foregroundStyle(p.label2).lineSpacing(5).padding(.horizontal, 18).padding(.top, 8)
                    if store.data.autoOn {
                        StatusPill(kind: .ok, text: store.data.autoWaiting ? store.t("autoWaiting") : store.t("on"))
                            .padding(.horizontal, 18).padding(.top, 12)
                    }
                    HStack(spacing: 10) {
                        Icon3D(name: "sms", size: 30)
                        Text(store.t("smsSection")).font(.alx(18, .bold)).foregroundStyle(p.label)
                    }
                    .padding(.horizontal, 18).padding(.top, 20)
                    GuideSteps()
                    SurfaceGroup {
                        Button { nav.sheet = .add(paste: true) } label: { SettingRow(icon: "sms", title: store.t("testIt")) { EmptyView() } }
                            .buttonStyle(PressStyle())
                    }
                    .padding(.top, 18)
                    ApplePaySteps()
                }
                .padding(.bottom, 24)
            }
            BottomBar {
                if store.data.autoOn {
                    PrimaryButton(title: store.t("openShortcuts"), systemImage: "arrow.up.forward.app") { openShortcuts() }
                } else if openedShortcuts { // back from Shortcuts: one tap to say it's done
                    PrimaryButton(title: store.t("didSetup")) { confirm() }
                    TextAction(title: store.t("openAgain"), color: p.label2, weight: .medium) { openShortcuts() }
                } else {
                    PrimaryButton(title: store.t("openShortcuts"), systemImage: "arrow.up.forward.app") { openShortcuts() }
                    TextAction(title: store.t("alreadySet"), color: p.label2, weight: .medium) { confirm() }
                }
            }
        }
        .background(p.bg.ignoresSafeArea())
    }
}
