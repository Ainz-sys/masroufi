import SwiftUI
import UIKit
import Charts

// MARK: - Home

/// One look: what is left this month, whether you're on pace, what needs a look, and today.
struct HomeScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p

    var body: some View {
        let month = Ledger.month(store.data)
        let pace = Ledger.pace(store.data)
        let queue = Ledger.reviewQueue(store.data)
        let txs = Ledger.transactions(store.data, on: Date())
        ScrollView {
            VStack(spacing: 0) {
                greeting(month)
                Card3DView(info: store.cardInfo()).frame(height: 200)
                RemainingPanel(month: month, vsLast: pace.vsLast)
                if !queue.isEmpty { ReviewBanner(queue: queue) }
                if !store.data.autoOn { autoOffBanner }
                if month.budget > 0 || pace.today > 1 { PaceCard(pace: pace) }
                if let ins = Ledger.insight(store.data) { InsightCard(insight: ins) }
                SectionHeader(title: store.t("todayTx")) {
                    if !store.data.transactions.isEmpty {
                        Button { nav.txFilter = nil; nav.tab = .txs } label: {
                            Text(store.t("all") + " (\(store.data.transactions.count))").font(.alx(14, .medium)).foregroundStyle(Tok.tintInk).frame(minHeight: 44)
                        }
                    }
                }
                if txs.isEmpty {
                    EmptyCard(icon: "receipt", title: store.t("noTodayT"), text: store.t("noTodayP"), actions: AnyView(
                        HStack(spacing: 8) {
                            SmallButton(title: store.t("addManual")) { nav.sheet = .add(paste: false) }
                            if !store.data.autoOn { SmallButton(title: store.t("setupAuto"), ghost: true) { nav.path.append(.guide) } }
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
            .padding(.bottom, 104)
        }
        .scrollIndicators(.hidden)
    }

    /// "مساء الخير يا فهد 👋" · date · days to payday, with the settings avatar.
    func greeting(_ month: Ledger.Month) -> some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let g = store.t(hour < 12 ? "gm" : "ge")
        let name = store.data.settings.name.trimmingCharacters(in: .whitespaces)
        let title = (name.isEmpty ? g : store.t("greetName", ["g": g, "n": name])) + " 👋"
        let payday = month.daysLeft <= 1 ? store.t("paydayToday") : store.t("toPayday", ["n": L10n.days(month.daysLeft - 1, store.lang)])
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.alx(24, .bold, relativeTo: .title)).foregroundStyle(p.label).lineLimit(1).minimumScaleFactor(0.7)
                Text(Fmt.day(Date(), store.lang) + " · " + payday).font(.alx(14, relativeTo: .subheadline)).foregroundStyle(p.label2).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Button { nav.path.append(.settings) } label: {
                ZStack {
                    Circle().fill(p.tintContainer)
                    if let first = name.first {
                        Text(String(first)).font(.alx(18, .semibold)).foregroundStyle(Tok.gold)
                    } else {
                        Image(systemName: "person.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(Tok.gold)
                    }
                }
                .frame(width: 46, height: 46)
                .overlay(Circle().strokeBorder(Tok.gold.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel(store.t("settings"))
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .frame(minHeight: 60)
    }

    var autoOffBanner: some View {
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
}

/// "3 new transactions to check" → the review cards.
struct ReviewBanner: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    let queue: [Transaction]

    var body: some View {
        let n = queue.count
        let title = n == 1 ? store.t("review1") : n == 2 ? store.t("review2") : store.t("reviewN", ["n": "\(n)"])
        Button { nav.path.append(.review) } label: {
            HStack(spacing: 12) {
                ZStack {
                    ForEach(Array(queue.prefix(3).enumerated()), id: \.offset) { i, tx in
                        Icon3D(name: store.data.category(tx.categoryID).symbol, size: 30, shadow: true)
                            .offset(x: CGFloat(i) * 14 - 14)
                            .zIndex(Double(3 - i))
                    }
                }
                .frame(width: 54, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.alx(15.5, .semibold)).foregroundStyle(p.label).lineLimit(2).minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(store.t("reviewP")).font(.alx(12.5)).foregroundStyle(p.label2).lineLimit(2).minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Text(store.t("reviewGo")).font(.alx(14.5, .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(height: 36)
                    .background(Capsule().fill(Tok.tint))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(p.tintContainer.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Tok.tint.opacity(0.35), lineWidth: 1))
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .buttonStyle(PressStyle())
    }
}

/// What is left of the month along the days: this month, last month at the same point, and the even pace.
struct PaceCard: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    let pace: Ledger.Pace

    struct Pt: Identifiable { let id: String; let series: String; let x: Double; let y: Double }

    var body: some View {
        let rtl = store.lang == .ar
        let days = Double(max(1, pace.days))
        let hasBudget = pace.budget > 0
        func xv(_ i: Double) -> Double { rtl ? days - i : i }
        func yv(_ cum: Double) -> Double { hasBudget ? pace.budget - cum : cum }
        var cur: [Pt] = [Pt(id: "c0", series: "cur", x: xv(0), y: yv(0))]
        for (i, v) in pace.current.enumerated() { cur.append(Pt(id: "c\(i + 1)", series: "cur", x: xv(Double(i + 1)), y: yv(v))) }
        var last: [Pt] = []
        if !pace.last.isEmpty, (pace.last.last ?? 0) > 0 {
            last.append(Pt(id: "l0", series: "last", x: xv(0), y: yv(0)))
            for (i, v) in pace.last.prefix(pace.days).enumerated() { last.append(Pt(id: "l\(i + 1)", series: "last", x: xv(Double(i + 1)), y: yv(v))) }
        }
        let now = cur.last ?? Pt(id: "now", series: "cur", x: xv(0), y: yv(0))
        let ys = (cur + last).map(\.y) + [hasBudget ? pace.budget : 0, 0]
        let lo = min(0, ys.min() ?? 0), hi = max(1, ys.max() ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text(store.t("pace")).font(.alx(17, .bold)).foregroundStyle(p.label)
            HStack(spacing: 14) {
                legend(store.t("thisMonthL"), Tok.tint, dash: nil)
                if !last.isEmpty { legend(store.t("lastMonthL"), p.label2, dash: [4, 3]) }
                if hasBudget { legend(store.t("budgetL"), Tok.gold, dash: [1.5, 3]) }
                Spacer(minLength: 0)
            }
            .padding(.top, -4)
            Chart {
                if hasBudget {
                    LineMark(x: .value("d", xv(0)), y: .value("v", pace.budget), series: .value("s", "budget"))
                        .foregroundStyle(Tok.gold.opacity(0.8)).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [1.5, 3]))
                    LineMark(x: .value("d", xv(days)), y: .value("v", 0.0), series: .value("s", "budget"))
                        .foregroundStyle(Tok.gold.opacity(0.8)).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [1.5, 3]))
                }
                ForEach(last) { pt in
                    LineMark(x: .value("d", pt.x), y: .value("v", pt.y), series: .value("s", "last"))
                        .foregroundStyle(p.label2.opacity(0.75)).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                ForEach(cur) { pt in
                    AreaMark(x: .value("d", pt.x), yStart: .value("lo", lo), yEnd: .value("v", pt.y))
                        .foregroundStyle(LinearGradient(colors: [Tok.tint.opacity(0.35), Tok.tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("d", pt.x), y: .value("v", pt.y), series: .value("s", "cur"))
                        .foregroundStyle(Color(hex: 0xF2638F)).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                RuleMark(x: .value("d", now.x), yStart: .value("lo", lo), yEnd: .value("v", now.y))
                    .foregroundStyle(Tok.tintInk.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                PointMark(x: .value("d", now.x), y: .value("v", now.y))
                    .symbol { Circle().strokeBorder(Color(hex: 0xF2638F), lineWidth: 2.5).background(Circle().fill(p.surface)).frame(width: 13, height: 13) }
            }
            .chartXScale(domain: 0...days)
            .chartYScale(domain: lo...hi)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .environment(\.layoutDirection, .leftToRight)
            .frame(height: 130)
            .accessibilityElement()
            .accessibilityLabel(Text(store.t("pace")))
            .accessibilityValue(Text(paceSummary))
            if let v = pace.vsLast {
                Text(paceSummary).font(.alx(13)).foregroundStyle(v <= 0 ? Tok.positive : Tok.warning)
            }
        }
        .padding(16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    var paceSummary: String {
        guard let v = pace.vsLast else { return "" }
        return store.t(v <= 0 ? "lessLast" : "moreLast", ["n": Fmt.m0(abs(v)) + " " + store.t("cur")])
    }

    func legend(_ title: String, _ color: Color, dash: [CGFloat]?) -> some View {
        HStack(spacing: 5) {
            Path { path in path.move(to: CGPoint(x: 0, y: 1.5)); path.addLine(to: CGPoint(x: 14, y: 1.5)) }
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, dash: dash ?? []))
                .frame(width: 14, height: 3)
            Text(title).font(.alx(11.5)).foregroundStyle(p.label2).lineLimit(1)
        }
    }
}

/// A short note when something is clearly unusual this week.
struct InsightCard: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    let insight: Ledger.Insight

    var body: some View {
        let c = store.data.category(insight.categoryID)
        Button { nav.txFilter = c.id; nav.tab = .txs } label: {
            HStack(alignment: .center, spacing: 12) {
                Icon3D(name: "bulb", size: 36, shadow: true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.t("insightLine", ["c": c.name(store.lang), "p": "\(insight.pct)"])).font(.alx(15.5, .semibold)).foregroundStyle(p.label)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Text(store.t("insightSub", ["n": "\(insight.count)", "a": Fmt.m0(insight.amount)])).font(.alx(13)).foregroundStyle(p.label2)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward").font(.system(size: 13, weight: .semibold)).foregroundStyle(p.label3)
            }
            .padding(14)
            .background(p.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.top, 12)
        }
        .buttonStyle(PressStyle())
    }
}

// MARK: - Review cards

/// New automatic transactions, one card at a time: swipe right (or ✓) when it's right, change the category, or leave it for later.
struct ReviewScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    @State private var skipped: Set<String> = []
    @State private var total = 0
    @State private var drag: CGSize = .zero
    @State private var always: [String: Bool] = [:]
    @State private var leaving = false

    var queue: [Transaction] { Ledger.reviewQueue(store.data).filter { !skipped.contains($0.id) } }

    var body: some View {
        let q = queue
        let count = max(total, q.count)
        let position = min(count, count - q.count + 1)
        VStack(spacing: 0) {
            ZStack {
                VStack(spacing: 1) {
                    Text(store.t("reviewTitle")).font(.alx(17, .semibold, relativeTo: .headline)).foregroundStyle(p.label)
                    if !q.isEmpty { Text(store.t("nOfM", ["i": "\(position)", "n": "\(count)"])).font(.alx(12.5)).foregroundStyle(p.label2) }
                }
                HStack {
                    Spacer()
                    RoundButton(systemImage: "xmark", label: store.t("done")) { dismiss() }
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)
            if count > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<min(count, 12), id: \.self) { i in
                        Capsule().fill(i < position ? Tok.tint : p.surface2).frame(height: 4)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 4)
            }
            if let tx = q.first {
                Spacer(minLength: 10)
                stack(q)
                Spacer(minLength: 10)
                actions(tx)
                if q.count > 1 {
                    TextAction(title: store.t("confirmAll"), color: p.label2, weight: .medium) {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        store.confirmAll()
                    }
                    .padding(.top, 4)
                }
                Spacer(minLength: 12)
            } else {
                Spacer()
                VStack(spacing: 10) {
                    Icon3D(name: "check", size: 92, shadow: true)
                    Text(store.t("allDone")).font(.alx(22, .bold)).foregroundStyle(p.label)
                    Text(store.t("allDoneP")).font(.alx(15)).foregroundStyle(p.label2).multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                Spacer()
                BottomBar { PrimaryButton(title: store.t("back")) { dismiss() } }
            }
        }
        .background(p.bg.ignoresSafeArea())
        .onAppear { total = max(total, queue.count) }
    }

    /// The top card follows the finger; the next two peek out behind it.
    func stack(_ q: [Transaction]) -> some View {
        ZStack {
            ForEach(Array(q.prefix(3).enumerated().reversed()), id: \.element.id) { i, tx in
                card(tx)
                    .scaleEffect(1 - CGFloat(i) * 0.05)
                    .offset(y: CGFloat(i) * 14)
                    .opacity(i == 0 ? 1 : 0.6)
                    .offset(i == 0 ? drag : .zero)
                    .rotationEffect(.degrees(i == 0 ? Double(drag.width / 22) : 0))
                    .allowsHitTesting(i == 0)
                    .gesture(swipe(tx), including: i == 0 ? .all : .none)
            }
        }
        .environment(\.layoutDirection, .leftToRight)   // a right swipe is "correct" in both languages
        .padding(.horizontal, 22)
    }

    func swipe(_ tx: Transaction) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in if !leaving { drag = v.translation } }
            .onEnded { v in
                if v.translation.width > 110 { confirm(tx) }
                else if v.translation.width < -110 { later(tx) }
                else { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { drag = .zero } }
            }
    }

    func fly(_ dx: CGFloat, then action: @escaping () -> Void) {
        leaving = true
        withAnimation(.easeIn(duration: 0.2)) { drag = CGSize(width: dx, height: drag.height + 30) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            action()
            drag = .zero
            leaving = false
        }
    }

    func confirm(_ tx: Transaction) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let a = always[tx.id] ?? false
        fly(600) { store.confirm(tx.id, category: tx.categoryID, always: a) }
    }

    func later(_ tx: Transaction) {
        UISelectionFeedbackGenerator().selectionChanged()
        fly(-600) { skipped.insert(tx.id) }
    }

    func card(_ tx: Transaction) -> some View {
        let c = store.data.category(tx.categoryID)
        let n = Ledger.sameMerchantCount(store.data, tx)
        let sure = n == 0 ? 60 : min(98, 74 + n * 3)
        let source = tx.source == .applePay ? store.t("fromAP") : (tx.bank.isEmpty ? store.t("fromBank") : store.t("fromSMS", ["b": tx.bank]))
        return VStack(spacing: 0) {
            HStack {
                Text(source).font(.alx(12.5, .semibold)).foregroundStyle(Color(hex: 0x9CCBFF))
                    .padding(.horizontal, 12).frame(height: 28)
                    .background(Capsule().fill(Color(hex: 0x6DB7FF).opacity(0.16)))
                Spacer()
                Text(dayLabel(tx.date, store) + (tx.noTime ? "" : " · " + Fmt.time(tx.date))).font(.alx(12.5)).foregroundStyle(p.label2)
            }
            Icon3D(name: c.symbol, size: 64, shadow: true).padding(.top, 10)
            Text(tx.displayName.isEmpty ? c.name(store.lang) : tx.displayName).font(.alx(24, .bold)).foregroundStyle(p.label)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7).padding(.top, 6)
            if tx.title != nil, !tx.merchant.isEmpty {
                Text(tx.merchant).font(.alx(12.5)).foregroundStyle(p.label3).lineLimit(1)
            }
            BigAmount(value: tx.amountHome, size: 38).padding(.top, 4)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(store.t("suggested")).font(.alx(12.5)).foregroundStyle(p.label2)
                    Spacer()
                    Text(store.t("sure", ["p": "\(sure)"])).font(.alx(12, .semibold)).foregroundStyle(sure >= 80 ? Tok.positive : Tok.warning)
                        .padding(.horizontal, 10).frame(height: 24)
                        .background(Capsule().fill((sure >= 80 ? Tok.positive : Tok.warning).opacity(0.15)))
                }
                HStack(spacing: 10) {
                    Icon3D(name: c.symbol, size: 28)
                    Text(c.name(store.lang)).font(.alx(17, .semibold)).foregroundStyle(p.label)
                    Spacer()
                }
                Text(n == 0 ? store.t("guessed") : n == 1 ? store.t("because1") : store.t("because", ["n": "\(n)"]))
                    .font(.alx(12)).foregroundStyle(p.label3)
            }
            .padding(14)
            .background(p.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 14)
            if !tx.merchantKey.isEmpty {
                HStack(spacing: 10) {
                    Text(store.t("applyAlways", ["m": tx.displayName])).font(.alx(13.5)).foregroundStyle(p.label)
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Spacer(minLength: 6)
                    Toggle("", isOn: Binding(get: { always[tx.id] ?? false }, set: { always[tx.id] = $0 })).labelsHidden().tint(Tok.tint)
                }
                .padding(.top, 12)
            }
        }
        .padding(18)
        .background(LinearGradient(colors: [p.surface2, p.surface], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 12)
        .overlay(alignment: .top) { swipeHint }
        .environment(\.layoutDirection, store.lang == .ar ? .rightToLeft : .leftToRight)
    }

    /// While dragging: ✓ on a right swipe, "later" on a left one.
    @ViewBuilder var swipeHint: some View {
        let w = drag.width
        if abs(w) > 30 {
            let ok = w > 0
            Text(ok ? store.t("rvOK") : store.t("rvLater")).font(.alx(15, .bold))
                .foregroundStyle(ok ? Tok.positive : p.label2)
                .padding(.horizontal, 14).frame(height: 32)
                .background(Capsule().fill((ok ? Tok.positive : p.label2).opacity(0.18)))
                .opacity(min(1, Double(abs(w) - 30) / 60))
                .padding(.top, -16)
        }
    }

    func actions(_ tx: Transaction) -> some View {
        HStack(spacing: 28) {
            roundAction(icon: "pencil", title: store.t("rvEdit"), color: Tok.tintInk, size: 64) { nav.sheet = .pickCategory(tx.id, review: true) }
            roundAction(icon: "checkmark", title: store.t("rvOK"), color: .white, size: 82, fill: Tok.positive) { confirm(tx) }
            roundAction(icon: "clock", title: store.t("rvLater"), color: p.label2, size: 64) { later(tx) }
        }
        .padding(.top, 6)
    }

    func roundAction(icon: String, title: String, color: Color, size: CGFloat, fill: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: size * 0.36, weight: .bold)).foregroundStyle(color)
                    .frame(width: size, height: size)
                    .background(Circle().fill(fill ?? p.surface2))
                    .shadow(color: (fill ?? .clear).opacity(0.45), radius: 14, x: 0, y: 6)
                Text(title).font(.alx(13.5, .medium)).foregroundStyle(fill ?? p.label2)
            }
        }
        .buttonStyle(PressStyle())
        .disabled(leaving)
    }
}

// MARK: - Category picker (review "change", swipe "category")

struct CategoryPickerSheet: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @Environment(\.dismiss) private var dismiss
    let txID: String
    let review: Bool
    @State private var always = false

    var body: some View {
        let tx = store.data.transactions.first { $0.id == txID }
        let cats = store.data.categories.filter { tx?.kind == .credit || $0.id != "income" }
        NavigationStack {
            VStack(spacing: 0) {
                NavBar(title: store.t("pickCat")) {
                    TextAction(title: store.t("cancel"), color: p.label2, weight: .medium) { dismiss() }
                } trailing: { Color.clear.frame(width: 44, height: 44) }
                ScrollView {
                    VStack(spacing: 0) {
                        if let tx, !tx.merchantKey.isEmpty {
                            SurfaceGroup { ToggleRow(title: store.t("applyAlways", ["m": tx.displayName]), isOn: $always) }
                                .padding(.bottom, 12)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(cats) { c in
                                let selected = c.id == tx?.categoryID
                                Button { pick(c.id) } label: {
                                    VStack(spacing: 6) {
                                        Icon3D(name: c.symbol, size: 38)
                                        Text(c.name(store.lang)).font(.alx(13, .medium)).foregroundStyle(p.label).lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 86)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(selected ? p.tintContainer : p.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(selected ? Tok.tint : Color.clear, lineWidth: 2))
                                }
                                .buttonStyle(PressStyle())
                                .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                            Button { nav.sheet = .newCategory(forTx: txID) } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "plus").font(.system(size: 22, weight: .semibold)).foregroundStyle(Tok.tintInk).frame(height: 38)
                                    Text(store.t("newCat")).font(.alx(13, .medium)).foregroundStyle(Tok.tintInk).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity, minHeight: 86)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Tok.tintInk.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                            }
                            .buttonStyle(PressStyle())
                        }
                        .padding(.horizontal, 18)
                    }
                    .padding(.top, 6).padding(.bottom, 30)
                }
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { if let tx { always = store.data.merchantMap[tx.merchantKey] != nil } }
        }
        .presentationDetents([.medium, .large])
    }

    func pick(_ id: String) {
        UISelectionFeedbackGenerator().selectionChanged()
        store.confirm(txID, category: id, always: always)
        nav.show(store.t("saved"))
        dismiss()
    }
}
