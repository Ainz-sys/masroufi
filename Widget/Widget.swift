import WidgetKit
import SwiftUI

struct BudgetEntry: TimelineEntry {
    let date: Date
    let today: Ledger.Today
    let last: Transaction?
    let lastCategory: Category?
    let week: [Double]
    let lang: Lang
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
                           week: week, lang: d.settings.language)
    }

    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: Date(), today: Ledger.Today(spent: 120, budget: 300, remaining: 180, fraction: 0.4, count: 2),
                    last: nil, lastCategory: nil, week: [80, 140, 60, 200, 90, 30, 120], lang: .ar)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) { completion(make()) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        // The app also asks WidgetKit to refresh immediately whenever a transaction is logged.
        completion(Timeline(entries: [make(now)], policy: .after(min(now.addingTimeInterval(1800), midnight.addingTimeInterval(60)))))
    }
}

struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let e: BudgetEntry

    func t(_ k: String, _ v: [String: String] = [:]) -> String { L10n.t(k, e.lang, v) }
    var hasBudget: Bool { e.today.budget > 0 }
    var over: Bool { hasBudget && e.today.remaining < 0 }
    var headline: String { hasBudget ? (over ? t("over") : t("leftToday")) : t("spentToday") }
    var value: Double { hasBudget ? abs(e.today.remaining) : e.today.spent }
    var footer: String { hasBudget ? t("spentOf", ["s": Fmt.m0(e.today.spent), "b": Fmt.m0(e.today.budget)]) : "" }
    var ringColor: Color { over ? .red : e.today.fraction >= 0.8 ? .orange : .accentColor }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(t("app") + ": " + (over ? t("over") + " " : "") + Fmt.m0(value) + " " + t("cur"))
        case .accessoryCircular:
            Gauge(value: min(e.today.spent, max(e.today.budget, 0.01)), in: 0...max(e.today.budget, 0.01)) {
                Text(t("cur"))
            } currentValueLabel: {
                Text(Fmt.m0(value))
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(t("app") + " · " + headline).font(.caption)
                Text(Fmt.m(value) + " " + t("cur")).font(.title3.weight(.semibold)).minimumScaleFactor(0.6)
                if hasBudget { Text(footer).font(.caption2) }
            }
        case .systemMedium:
            HStack(spacing: 16) {
                ring.frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 6) {
                    Text(t("app")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    if hasBudget { Text(footer).font(.subheadline.weight(.medium)) }
                    if let last = e.last {
                        HStack(spacing: 6) {
                            Image(systemName: e.lastCategory?.symbol ?? "creditcard")
                            VStack(alignment: .leading, spacing: 0) {
                                Text(last.merchant.isEmpty ? (e.lastCategory?.name(e.lang) ?? "") : last.merchant).font(.caption.weight(.semibold)).lineLimit(1)
                                Text(Fmt.m(last.amountHome) + (last.noTime ? "" : " · " + Fmt.time(last.date))).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    weekBars.frame(height: 26)
                    Text(t("week")).font(.caption2).foregroundStyle(.secondary)
                }
            }
        default:
            VStack(spacing: 4) {
                Text(headline).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                ring.frame(width: 96, height: 96)
                if hasBudget { Text(footer).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7) }
            }
        }
    }

    var ring: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 10)
            Circle().trim(from: 0, to: hasBudget ? min(1, e.today.fraction) : 0)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(Fmt.m(value)).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                    .minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(over ? Color.red : Color.primary)
                Text(t("cur")).font(.caption2).foregroundStyle(.secondary)
            }
            .padding(14)
        }
    }

    var weekBars: some View {
        let top = max(e.week.max() ?? 0, e.today.budget, 1)
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(e.week.enumerated()), id: \.offset) { item in
                RoundedRectangle(cornerRadius: 2)
                    .fill(item.offset == e.week.count - 1 ? Color.accentColor : Color.secondary.opacity(0.5))
                    .frame(height: max(3, 26 * item.element / top))
            }
        }
    }
}

@main
struct MasroufiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MasroufiWidget", provider: BudgetProvider()) { entry in
            BudgetWidgetView(e: entry)
                .environment(\.layoutDirection, entry.lang == .ar ? .rightToLeft : .leftToRight)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("مصروفي")
        .description("المتبقي من ميزانية اليوم · Today's remaining budget")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
