import WidgetKit
import SwiftUI

struct BudgetEntry: TimelineEntry {
    let date: Date
    let today: Ledger.Today
    let last: Transaction?
    let lastCategory: Category?
    let week: [Double]
    let lang: Lang
    let background: String
}

struct BudgetProvider: TimelineProvider {
    func make(_ now: Date = Date()) -> BudgetEntry {
        let d = Persistence.load()
        let last = d.transactions.max { $0.date < $1.date }
        let start = Calendar.current.startOfDay(for: now)
        let week: [Double] = (0..<7).reversed().map { (i: Int) -> Double in
            let day = Calendar.current.date(byAdding: .day, value: -i, to: start)!
            let b = Ledger.dayBounds(day)
            return Ledger.spent(d, from: b.start, to: b.end)
        }
        return BudgetEntry(date: now, today: Ledger.today(d, now: now), last: last, lastCategory: last.map { d.category($0.categoryID) },
                           week: week, lang: d.settings.language, background: d.settings.background)
    }

    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: Date(), today: Ledger.Today(spent: 259.25, budget: 300, remaining: 40.75, fraction: 0.86, count: 3),
                    last: nil, lastCategory: nil, week: [80, 140, 60, 200, 90, 30, 259], lang: .ar, background: "wine")
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) { completion(make()) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        // The app also asks WidgetKit to refresh right after every logged transaction.
        completion(Timeline(entries: [make(now)], policy: .after(min(now.addingTimeInterval(1800), midnight.addingTimeInterval(60)))))
    }
}

struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let e: BudgetEntry

    var p: Palette { Palette.named(e.background) }
    func t(_ k: String, _ v: [String: String] = [:]) -> String { L10n.t(k, e.lang, v) }
    var hasBudget: Bool { e.today.budget > 0 }
    var over: Bool { hasBudget && e.today.remaining < 0 }
    var headline: String { hasBudget ? (over ? t("overShort") : t("leftToday")) : t("spentToday") }
    var value: Double { hasBudget ? abs(e.today.remaining) : e.today.spent }
    var valueText: String { abs(value) >= 1000 ? Fmt.m0(value) : Fmt.m(value) }
    var footer: String { hasBudget ? t("spentOf", ["s": Fmt.m0(e.today.spent), "b": Fmt.m0(e.today.budget)]) : "" }
    var ringColor: Color { !hasBudget ? Tok.gold : over ? Tok.danger : e.today.fraction >= 0.8 ? Tok.warning : Tok.tintInk }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(t("app") + ": " + (over ? t("overShort") + " " : "") + Fmt.m0(value) + " " + t("cur"))
        case .accessoryCircular:
            Gauge(value: min(e.today.spent, max(e.today.budget, 0.01)), in: 0...max(e.today.budget, 0.01)) {
                Text(t("cur"))
            } currentValueLabel: {
                Text(Fmt.m0(value)).font(.alx(15, .semibold))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(t("app") + " · " + headline).font(.alx(12, .medium))
                Text("\u{200E}" + Fmt.m(value) + " " + t("cur")).font(.alx(19, .semibold)).minimumScaleFactor(0.6)
                if hasBudget { Text(footer).font(.alx(11)) }
            }
        case .systemMedium:
            HStack(spacing: 14) {
                ring(118)
                VStack(alignment: .leading, spacing: 0) {
                    Text(t("app")).font(.alx(12, .semibold)).foregroundStyle(Tok.gold)
                    Text(hasBudget ? footer : t("spentToday")).font(.alx(13, .medium)).foregroundStyle(p.label).padding(.top, 2)
                    if let last = e.last {
                        HStack(spacing: 8) {
                            Icon3D(name: e.lastCategory?.symbol ?? "receipt", size: 26)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(last.merchant.isEmpty ? (e.lastCategory?.name(e.lang) ?? "") : last.merchant)
                                    .font(.alx(12.5, .medium)).foregroundStyle(p.label).lineLimit(1)
                                Text("\u{200E}" + Fmt.m(last.amountHome) + (last.noTime ? "" : " · " + Fmt.time(last.date)))
                                    .font(.alx(11)).foregroundStyle(p.label2)
                            }
                        }
                        .padding(.top, 9)
                    }
                    Spacer(minLength: 6)
                    weekBars.frame(height: 26)
                    Text(t("week")).font(.alx(10)).foregroundStyle(p.label3).padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            VStack(spacing: 6) {
                Text(headline).font(.alx(12, .medium)).foregroundStyle(p.label2)
                ring(96)
                if hasBudget { Text(footer).font(.alx(11)).foregroundStyle(p.label2).lineLimit(1).minimumScaleFactor(0.7) }
            }
        }
    }

    func ring(_ size: CGFloat) -> some View {
        ZStack {
            Circle().stroke(p.track, lineWidth: size * 0.1)
            Circle().trim(from: 0, to: hasBudget ? min(1, e.today.fraction) : 0)
                .stroke(ringColor, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\u{200E}" + valueText).font(.alx(size * 0.2, .semibold)).monospacedDigit()
                    .minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(over ? Tok.danger : p.label)
                Text(over ? t("overShort") : t("cur")).font(.alx(size * 0.1)).foregroundStyle(p.label2)
            }
            .padding(size * 0.14)
        }
        .frame(width: size, height: size)
    }

    var weekBars: some View {
        let top = max(e.week.max() ?? 0, e.today.budget, 1)
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(e.week.enumerated()), id: \.offset) { item in
                let isToday = item.offset == e.week.count - 1
                RoundedRectangle(cornerRadius: 3)
                    .fill(isToday ? Tok.tint : (hasBudget && item.element > e.today.budget ? Tok.warning : p.label3.opacity(0.55)))
                    .frame(height: max(3, 26 * item.element / top))
            }
        }
    }
}

@main
struct MasroufiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MasroufiWidget", provider: BudgetProvider()) { entry in
            let p = Palette.named(entry.background)
            BudgetWidgetView(e: entry)
                .environment(\.layoutDirection, entry.lang == .ar ? .rightToLeft : .leftToRight)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [p.bgTop, p.bg], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("مصروفي")
        .description("المتبقي من ميزانية اليوم · Today's remaining budget")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
