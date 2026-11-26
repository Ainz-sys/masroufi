import SwiftUI
import UIKit
import Charts

// MARK: - Analytics: where it went · trends · calendar

struct AnalyticsScreen: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p
    @State private var seg = Demo.screen == "analytics-trends" ? 1 : (Demo.screen == "analytics-cal" ? 2 : 0)
    @State private var selectedDay: Date? = Demo.screen == "analytics-cal"
        ? Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) : nil

    var body: some View {
        let d = store.data
        let m = Ledger.month(d)
        let lang = store.lang
        let subtitle = seg == 1 ? store.t("lastNCycles", ["n": "\(max(1, Ledger.cycleTotals(d, count: 7).count))"])
            : Fmt.short(m.start, lang) + " – " + Fmt.short(m.end.addingTimeInterval(-86400), lang)
        ScrollView {
            VStack(spacing: 0) {
                TopBar(title: store.t("analytics"), subtitle: subtitle) { EmptyView() }
                PillSegments(titles: [store.t("flowTab"), store.t("trendsTab"), store.t("calTab")], selection: $seg)
                if d.transactions.isEmpty {
                    EmptyCard(icon: "chart", title: store.t("noData"), text: store.t("noTodayP")).padding(.top, 14)
                } else {
                    switch seg {
                    case 1: trends(m)
                    case 2: calendar(m)
                    default: flow(m)
                    }
                }
            }
            .padding(.bottom, 104)
        }
        .scrollIndicators(.hidden)
    }

    func openCategory(_ id: String) {
        guard !id.isEmpty, store.data.categories.contains(where: { $0.id == id }) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        nav.txFilter = id
        nav.tab = .txs
    }

    // MARK: Where it went

    @ViewBuilder func flow(_ m: Ledger.Month) -> some View {
        let d = store.data
        let income = d.transactions.filter { $0.kind == .credit && !$0.excluded && $0.date >= m.start && $0.date < m.end }.reduce(0) { $0 + $1.amountHome }
        let base = income > 0 ? income : m.budget
        let left = base - m.spent
        let nodes = Ledger.flow(d, lang: store.lang)
        if base > 0 {
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    figure(store.t(income > 0 ? "incomeL" : "budgetL"), base, p.label)
                    Spacer(minLength: 6)
                    figure(store.t("spentL"), m.spent, Tok.tintInk)
                    Spacer(minLength: 6)
                    figure(store.t("leftL"), left, left < 0 ? Tok.danger : Tok.positive)
                }
                GeometryReader { geo in
                    let share = min(1, m.spent / max(1, base))
                    HStack(spacing: 3) {
                        Capsule().fill(Color(hex: 0xE4457A)).frame(width: max(6, (geo.size.width - 3) * share))
                        if share < 1 { Capsule().fill(Tok.positive.opacity(0.8)) }
                    }
                }
                .frame(height: 12)
            }
            .padding(16)
            .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        SectionHeader(title: store.t("flowTitle")) {
            Text(store.t("tapBranch")).font(.alx(13)).foregroundStyle(p.label2)
        }
        if nodes.isEmpty {
            EmptyCard(icon: "chart", title: store.t("noData"), text: store.t("noTodayP"))
        } else {
            SankeyView(nodes: Self.bucket(nodes, lang: store.lang), rtl: store.lang == .ar, onTap: openCategory)
                .padding(.horizontal, 12).padding(.vertical, 14)
                .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 18)
        }
    }

    func figure(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.alx(12.5)).foregroundStyle(p.label2)
            Text("\u{200E}" + (value < 0 ? "-" : "") + Fmt.m0(abs(value))).font(.alx(17, .bold)).monospacedDigit().foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    /// Keeps the chart readable: the 8 largest categories, the rest folded into "Others" in their group.
    static func bucket(_ nodes: [Ledger.FlowNode], lang: Lang) -> [Ledger.FlowNode] {
        guard nodes.count > 9 else { return nodes }
        let keep = Set(nodes.sorted { $0.amount > $1.amount }.prefix(8).map(\.id))
        var out: [Ledger.FlowNode] = []
        for g in [Ledger.Group.fixed, .nonMonthly, .flex] {
            let inGroup = nodes.filter { $0.group == g }
            out += inGroup.filter { keep.contains($0.id) }
            let rest = inGroup.filter { !keep.contains($0.id) }
            if !rest.isEmpty {
                out.append(Ledger.FlowNode(id: "", name: L10n.t("othersL", lang) + " (\(rest.count))", icon: "other", color: "#A19DA8",
                                           amount: rest.reduce(0) { $0 + $1.amount }, group: g))
            }
        }
        return out
    }

    // MARK: Trends

    @ViewBuilder func trends(_ m: Ledger.Month) -> some View {
        let d = store.data
        let totals = Ledger.cycleTotals(d, count: 7)
        let past = totals.filter { !$0.current }
        let avg = past.isEmpty ? 0 : past.reduce(0) { $0 + $1.total } / Double(past.count)
        let keys = totals.map { cycleKey($0.start) }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.t("perCycle")).font(.alx(17, .bold)).foregroundStyle(p.label)
                Spacer()
                if avg > 0 {
                    Text(store.t("avgK", ["a": short(avg)])).font(.alx(12.5, .semibold)).foregroundStyle(Tok.positive)
                        .padding(.horizontal, 10).frame(height: 28).background(Capsule().fill(Tok.positive.opacity(0.14)))
                }
            }
            Chart {
                ForEach(totals) { c in
                    BarMark(x: .value("cycle", cycleKey(c.start)), y: .value("QAR", c.total), width: .ratio(0.55))
                        .foregroundStyle(c.current ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xF2638F), Color(hex: 0xC42A5C)], startPoint: .top, endPoint: .bottom))
                                                   : AnyShapeStyle(avg > 0 && c.total > avg ? Tok.warning : p.label3.opacity(0.35)))
                        .cornerRadius(7)
                        .annotation(position: .top, spacing: 4) {
                            Text(short(c.total)).font(.alx(10.5)).foregroundStyle(c.current ? Tok.tintInk : p.label2)
                        }
                }
                if avg > 0 {
                    RuleMark(y: .value("avg", avg)).foregroundStyle(Tok.gold.opacity(0.7)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
            }
            .chartXScale(domain: store.lang == .ar ? Array(keys.reversed()) : keys)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { v in
                    AxisValueLabel {
                        if let k = v.as(String.self) { Text(k).font(.alx(11.5)).foregroundStyle(p.label2) }
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .frame(height: 190)
            if past.isEmpty {
                Text(store.t("needHistory")).font(.alx(13)).foregroundStyle(p.label2)
            }
        }
        .padding(16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 14)

        let changes = Array(Ledger.categoryChanges(d, lang: store.lang).prefix(6))
        if !changes.isEmpty {
            SectionHeader(title: store.t("whatChanged")) {
                Text(store.t("changedHint")).font(.alx(12.5)).foregroundStyle(p.label2)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(changes) { c in
                    Button { openCategory(c.id) } label: {
                        HStack(spacing: 10) {
                            Icon3D(name: c.icon, size: 34, shadow: true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(c.name).font(.alx(14.5, .semibold)).foregroundStyle(p.label).lineLimit(1).minimumScaleFactor(0.8)
                                let up = c.pct > 0
                                Text("\u{200E}" + (up ? "+" : "") + "\(c.pct)" + (store.lang == .ar ? "٪" : "%"))
                                    .font(.alx(12, .semibold)).foregroundStyle(up ? Tok.danger : Tok.positive)
                                    .padding(.horizontal, 8).frame(height: 22)
                                    .background(Capsule().fill((up ? Tok.danger : Tok.positive).opacity(0.15)))
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(p.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                }
            }
            .padding(.horizontal, 18)
        }

        let merchants = topMerchants(m)
        if !merchants.isEmpty {
            SectionHeader(store.t("topMerchants"))
            SurfaceGroup {
                ForEach(merchants) { mm in
                    if mm.id != merchants.first?.id { RowDivider() }
                    HStack(spacing: 14) {
                        Icon3D(name: mm.icon, size: 40, shadow: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mm.name).font(.alx(16, .semibold)).foregroundStyle(p.label).lineLimit(1)
                            Text("×\(mm.count)").font(.alx(13.5)).foregroundStyle(p.label2)
                        }
                        Spacer()
                        Text("\u{200E}" + Fmt.m(mm.amount)).font(.alx(17, .semibold)).monospacedDigit().foregroundStyle(p.label)
                    }
                    .padding(.horizontal, 16).frame(minHeight: 64)
                }
            }
        }
    }

    func topMerchants(_ m: Ledger.Month) -> [MerchantStat] {
        let d = store.data
        let inCycle = d.transactions.filter { $0.counts && $0.date >= m.start && $0.date < m.end && !$0.merchant.isEmpty }
        let g = Dictionary(grouping: inCycle, by: { $0.merchantKey.isEmpty ? $0.merchant : $0.merchantKey })
        let stats: [MerchantStat] = g.values.map { (txs: [Transaction]) -> MerchantStat in
            MerchantStat(name: (txs.max { $0.date < $1.date } ?? txs[0]).displayName, icon: d.category(txs[0].categoryID).symbol,
                         amount: txs.reduce(0.0) { $0 + $1.amountHome }, count: txs.count)
        }
        return Array(stats.sorted { $0.amount > $1.amount }.prefix(5))
    }

    /// The month most of the cycle falls in ("نوفمبر").
    func cycleKey(_ start: Date) -> String {
        let mid = Calendar.current.date(byAdding: .day, value: 15, to: start) ?? start
        return monthName(Calendar.current.component(.month, from: mid), store.lang)
    }

    func short(_ v: Double) -> String {
        v >= 1000 ? String(format: "%.1fk", v / 1000) : Fmt.m0(v)
    }

    // MARK: Calendar

    @ViewBuilder func calendar(_ m: Ledger.Month) -> some View {
        let cal = Calendar.current
        let map = Ledger.dayMap(store.data).map { DayCell(day: $0.day, value: $0.value) }
        let top = map.compactMap(\.value).max() ?? 0
        let lead = map.first.map { (cal.component(.weekday, from: $0.day) - cal.firstWeekday + 7) % 7 } ?? 0
        let todayStart = cal.startOfDay(for: Date())
        let f = Self.formatter(store.lang)
        let symbols = f.veryShortStandaloneWeekdaySymbols ?? []
        let ordered = symbols.isEmpty ? [] : (0..<7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.t("dayMap")).font(.alx(17, .bold)).foregroundStyle(p.label)
                Spacer()
                if let w = priciestWeekday(), !f.weekdaySymbols.isEmpty {
                    Text(store.t("topDay", ["d": f.weekdaySymbols[w - 1]])).font(.alx(13, .medium)).foregroundStyle(Tok.tintInk)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                    Text(s).font(.alx(11.5)).foregroundStyle(p.label3).frame(maxWidth: .infinity)
                }
                ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 10) }
                ForEach(map) { item in
                    let selected = selectedDay == item.day
                    Button {
                        guard item.value != nil else { return }
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.easeOut(duration: 0.15)) { selectedDay = selected ? nil : item.day }
                    } label: {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(cellColor(item.value, top: top))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                Text("\(cal.component(.day, from: item.day))").font(.alx(11.5, .medium))
                                    .foregroundStyle(item.value == nil ? p.label3.opacity(0.6) : p.label.opacity(0.9))
                            )
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(selected ? Color.white : (item.day == todayStart ? Tok.tintInk : Color.clear), lineWidth: selected ? 2 : 1.5))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(item.value == nil)
                    .accessibilityLabel(Text(Fmt.day(item.day, store.lang)))
                    .accessibilityValue(Text(item.value.map { Fmt.m($0) + " " + store.t("cur") } ?? ""))
                }
            }
            .environment(\.layoutDirection, store.lang == .ar ? .rightToLeft : .leftToRight)
        }
        .padding(16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
        .padding(.top, 14)

        if let day = selectedDay {
            let txs = Ledger.transactions(store.data, on: day)
            SectionHeader(title: store.t("dayTx", ["d": Fmt.short(day, store.lang)])) {
                Text("\u{200E}" + Fmt.m(txs.filter(\.counts).reduce(0) { $0 + $1.amountHome }) + " " + store.t("cur")).font(.alx(13.5)).foregroundStyle(p.label2)
            }
            if txs.isEmpty {
                Text(store.t("noDayTx")).font(.alx(14)).foregroundStyle(p.label2).padding(.horizontal, 22)
            } else {
                SurfaceGroup {
                    ForEach(txs) { tx in
                        if tx.id != txs.first?.id { RowDivider() }
                        Button { nav.path.append(.detail(tx.id)) } label: { TxRow(tx: tx) }.buttonStyle(PressStyle())
                    }
                }
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "hand.tap").font(.system(size: 13, weight: .semibold))
                Text(store.t("calHint")).font(.alx(13))
            }
            .foregroundStyle(p.label3)
            .padding(.horizontal, 22).padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct DayCell: Identifiable { let day: Date; let value: Double?; var id: Date { day } }

    static func formatter(_ lang: Lang) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang == .ar ? "ar" : "en_GB")
        return f
    }

    func cellColor(_ v: Double?, top: Double) -> Color {
        guard let v else { return p.surface2.opacity(0.35) }
        guard v > 0, top > 0 else { return p.surface2 }
        return Color(hex: 0xE4457A).opacity(0.22 + 0.78 * min(1, v / top))
    }

    /// The weekday with the highest average spending over the last 12 weeks (1 = Sunday).
    func priciestWeekday() -> Int? {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let start = cal.date(byAdding: .day, value: -84, to: end)!
        var sums = [Double](repeating: 0, count: 8)
        for t in store.data.transactions where t.counts && t.date >= start && t.date < end { sums[cal.component(.weekday, from: t.date)] += t.amountHome }
        guard let best = (1...7).max(by: { sums[$0] < sums[$1] }), sums[best] > 0 else { return nil }
        return best
    }
}

// MARK: - Sankey

/// Spending → fixed / flexible / non-monthly → each category, with ribbons as wide as the money.
struct SankeyView: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    let nodes: [Ledger.FlowNode]
    let rtl: Bool
    let onTap: (String) -> Void

    struct Slot { let node: Ledger.FlowNode; let y: CGFloat; let h: CGFloat; let slotY: CGFloat; let slotH: CGFloat }
    struct GroupBox { let group: Ledger.Group; let amount: Double; let y: CGFloat; let h: CGFloat; let slots: [Int] }
    struct Plan { var slots: [Slot] = []; var groups: [GroupBox] = []; var totalY: CGFloat = 0; var totalH: CGFloat = 0; var height: CGFloat = 0 }

    static let top: CGFloat = 34
    static let barW: CGFloat = 10

    var total: Double { nodes.reduce(0) { $0 + $1.amount } }

    func plan() -> Plan {
        var out = Plan()
        let T = max(0.01, total)
        let totalH = min(300, max(130, CGFloat(nodes.count) * 34))
        let k = totalH / CGFloat(T)
        var y = Self.top
        for n in nodes {
            let h = max(3, CGFloat(n.amount) * k)
            let slotH = max(h, 44)
            out.slots.append(Slot(node: n, y: y + (slotH - h) / 2, h: h, slotY: y, slotH: slotH))
            y += slotH + 6
        }
        let catBottom = y - 6
        var prevBottom = Self.top - 14
        var order: [Ledger.Group] = []
        for n in nodes where !order.contains(n.group) { order.append(n.group) }
        for g in order {
            let idx = out.slots.indices.filter { out.slots[$0].node.group == g }
            let amount = idx.reduce(0.0) { $0 + out.slots[$1].node.amount }
            let h = max(4, CGFloat(amount) * k)
            let first = out.slots[idx.first!], last = out.slots[idx.last!]
            let center = (first.slotY + last.slotY + last.slotH) / 2
            let gy = max(center - h / 2, prevBottom + 14)
            out.groups.append(GroupBox(group: g, amount: amount, y: gy, h: h, slots: idx))
            prevBottom = gy + h
        }
        out.height = max(catBottom, prevBottom, Self.top + totalH) + 4
        out.totalH = totalH
        out.totalY = Self.top
        return out
    }

    func ribbon(_ x0: CGFloat, _ a0: CGFloat, _ a1: CGFloat, _ x1: CGFloat, _ b0: CGFloat, _ b1: CGFloat) -> Path {
        var path = Path()
        let cx = (x0 + x1) / 2
        path.move(to: CGPoint(x: x0, y: a0))
        path.addCurve(to: CGPoint(x: x1, y: b0), control1: CGPoint(x: cx, y: a0), control2: CGPoint(x: cx, y: b0))
        path.addLine(to: CGPoint(x: x1, y: b1))
        path.addCurve(to: CGPoint(x: x0, y: a1), control1: CGPoint(x: cx, y: b1), control2: CGPoint(x: cx, y: a1))
        path.closeSubpath()
        return path
    }

    func groupName(_ g: Ledger.Group) -> String { store.t(g == .fixed ? "fixed" : g == .flex ? "flex" : "nonMonthly") }

    var body: some View {
        let pl = plan()
        GeometryReader { geo in
            let W = geo.size.width
            let labelW = min(150, W * 0.42)
            let barW = Self.barW
            let totalX: CGFloat = 0
            let catX = W - labelW - barW
            let groupX = (totalX + barW + catX) / 2 - barW / 2
            let flip = CGAffineTransform(a: rtl ? -1 : 1, b: 0, c: 0, d: 1, tx: rtl ? W : 0, ty: 0)
            let mx: (CGFloat) -> CGFloat = { x in rtl ? W - x : x }
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    var offT = pl.totalY
                    for g in pl.groups {
                        let color = GroupColor.of(g.group)
                        ctx.fill(ribbon(totalX + barW, offT, offT + g.h, groupX, g.y, g.y + g.h).applying(flip), with: .color(color.opacity(0.28)))
                        var offG = g.y
                        for i in g.slots {
                            let s = pl.slots[i]
                            let hh = max(2, CGFloat(s.node.amount) / CGFloat(max(0.01, g.amount)) * g.h)
                            let c = Color(hexString: s.node.color)
                            ctx.fill(ribbon(groupX + barW, offG, offG + hh, catX, s.y, s.y + s.h).applying(flip), with: .color(c.opacity(0.32)))
                            offG += hh
                        }
                        ctx.fill(Path(roundedRect: CGRect(x: totalX, y: offT, width: barW, height: g.h), cornerRadius: 2).applying(flip), with: .color(p.label.opacity(0.92)))
                        ctx.fill(Path(roundedRect: CGRect(x: groupX, y: g.y, width: barW, height: g.h), cornerRadius: 3).applying(flip), with: .color(color))
                        offT += g.h
                    }
                    for s in pl.slots {
                        ctx.fill(Path(roundedRect: CGRect(x: catX, y: s.y, width: barW, height: s.h), cornerRadius: 3).applying(flip),
                                 with: .color(Color(hexString: s.node.color)))
                    }
                }
                // total
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.t("spendingL")).font(.alx(12.5, .semibold)).foregroundStyle(p.label)
                    Text("\u{200E}" + Fmt.m0(total)).font(.alx(11.5)).foregroundStyle(p.label2)
                }
                .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                .fixedSize()
                .position(x: mx(totalX + 30), y: pl.totalY - 17)
                // groups
                ForEach(pl.groups.indices, id: \.self) { i in
                    let g = pl.groups[i]
                    VStack(spacing: 0) {
                        Text(groupName(g.group)).font(.alx(12.5, .semibold)).foregroundStyle(GroupColor.of(g.group))
                        Text("\u{200E}" + Fmt.m0(g.amount)).font(.alx(11.5)).foregroundStyle(p.label)
                    }
                    .shadow(color: .black.opacity(0.6), radius: 3)
                    .fixedSize()
                    .position(x: mx(groupX + barW + (catX - groupX - barW) / 2), y: g.y + g.h / 2)
                    .allowsHitTesting(false)
                }
                // categories
                ForEach(pl.slots.indices, id: \.self) { i in
                    let s = pl.slots[i]
                    Button { onTap(s.node.id) } label: {
                        HStack(spacing: 6) {
                            Icon3D(name: s.node.icon, size: 26)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(s.node.name).font(.alx(12.5, .semibold)).foregroundStyle(p.label).lineLimit(2).minimumScaleFactor(0.75)
                                Text("\u{200E}" + Fmt.m0(s.node.amount)).font(.alx(11.5)).foregroundStyle(p.label2)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(width: labelW - 4, height: s.slotH)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressStyle())
                    .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                    .position(x: mx(catX + barW + 4 + (labelW - 4) / 2), y: s.slotY + s.slotH / 2)
                    .accessibilityLabel(Text(s.node.name + " " + Fmt.m0(s.node.amount) + " " + store.t("cur")))
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .frame(height: pl.height)
    }
}
