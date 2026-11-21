import SwiftUI
import UIKit

// MARK: - Navigation state

enum AppTab: Hashable { case today, txs, insights, settings }
enum Route: Hashable { case detail(String), categories, guide, salary }

enum SheetRoute: Identifiable {
    case add(paste: Bool)
    case newCategory(forTx: String?)
    case editCategory(String)
    case budget
    case rename(String)

    var id: String {
        switch self {
        case .add(let p): return "add-\(p)"
        case .newCategory(let t): return "new-\(t ?? "")"
        case .editCategory(let c): return "edit-\(c)"
        case .budget: return "budget"
        case .rename(let t): return "rename-\(t)"
        }
    }
}

@MainActor
final class Nav: ObservableObject {
    @Published var tab: AppTab = .today
    @Published var path: [Route] = []
    @Published var sheet: SheetRoute? = nil
    @Published var toast: String? = nil
    @Published var txFilter: String? = nil

    func show(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard let self, self.toast == message else { return }
            withAnimation(.easeIn(duration: 0.15)) { self.toast = nil }
        }
    }
}

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// Keeps the edge swipe-back gesture working with our custom (hidden) navigation bars.
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

// MARK: - Building blocks

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct RoundButton: View {
    @Environment(\.palette) private var p
    let systemImage: String
    var label: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.title3, weight: .semibold))
                .foregroundStyle(p.label)
                .frame(width: 46, height: 46)
                .background(Circle().fill(.ultraThinMaterial))
                .background(Circle().fill(p.glass))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(label)
    }
}

/// Back chevron that points the right way in Arabic and English.
struct BackButton: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        RoundButton(systemImage: "chevron.backward", label: store.t("back")) { dismiss() }
    }
}

struct TopBar<Trailing: View>: View {
    @Environment(\.palette) private var p
    let title: String
    var subtitle: String? = nil
    /// Space before the first block. Screens whose first block brings its own top margin pass less.
    var bottom: CGFloat = 14
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.alx(30, .bold, relativeTo: .largeTitle)).foregroundStyle(p.label)
                if let subtitle { Text(subtitle).font(.alx(14, relativeTo: .subheadline)).foregroundStyle(p.label2) }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .frame(minHeight: 60)
        .padding(.bottom, bottom)
    }
}

/// Centered title bar used by pushed pages and sheets.
struct NavBar<Leading: View, Trailing: View>: View {
    @Environment(\.palette) private var p
    let title: String
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            Text(title).font(.alx(17, .semibold, relativeTo: .headline)).foregroundStyle(p.label)
            HStack { leading(); Spacer(); trailing() }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }
}

struct TextAction: View {
    let title: String
    var color: Color = Tok.tintInk
    var weight: AlxWeight = .semibold
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.alx(16, weight)).foregroundStyle(color).frame(minWidth: 44, minHeight: 44)
        }
    }
}

struct SurfaceGroup<Content: View>: View {
    @Environment(\.palette) private var p
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0, content: content)
            .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 18)
    }
}

struct RowDivider: View {
    @Environment(\.palette) private var p
    var body: some View { Rectangle().fill(p.separator).frame(height: 1) }
}

struct SectionHeader<Trailing: View>: View {
    @Environment(\.palette) private var p
    let title: String
    var strong: Bool = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(strong ? .alx(18, .bold, relativeTo: .headline) : .alx(14, relativeTo: .subheadline))
                .foregroundStyle(strong ? p.label : p.label2)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, strong: Bool = true) { self.init(title: title, strong: strong) { EmptyView() } }
}

struct TxRow: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    let tx: Transaction

    var body: some View {
        let c = store.data.category(tx.categoryID)
        let credit = tx.kind == .credit
        HStack(spacing: 14) {
            Icon3D(name: c.symbol, size: 46, shadow: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(tx.displayName.isEmpty ? c.name(store.lang) : tx.displayName)
                    .font(.alx(16.5, .semibold)).foregroundStyle(p.label).lineLimit(2).multilineTextAlignment(.leading)
                Text(c.name(store.lang) + (tx.noTime ? "" : " · " + Fmt.time(tx.date)))
                    .font(.alx(14, relativeTo: .subheadline)).foregroundStyle(p.label2).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text((credit ? "+" : "") + Fmt.m(tx.amountHome))
                    .font(.alx(18, .semibold)).monospacedDigit().foregroundStyle(credit ? Tok.positive : p.label)
                    .environment(\.layoutDirection, .leftToRight)
                Text(store.t("cur")).font(.alx(12.5, relativeTo: .caption)).foregroundStyle(p.label2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 72)
        .opacity(tx.excluded ? 0.5 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

enum PillKind { case ok, warn, over }

struct StatusPill: View {
    let kind: PillKind
    let text: String
    var body: some View {
        let color: Color = kind == .ok ? Tok.positive : kind == .warn ? Tok.warning : Tok.danger
        HStack(spacing: 6) {
            Icon3D(name: kind == .ok ? "check" : "bell", size: 18)
            Text(text).font(.alx(13, .semibold, relativeTo: .caption)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .frame(minHeight: 30)
        .fixedSize(horizontal: false, vertical: true)
        .background(color.opacity(0.15), in: Capsule())
    }
}

struct ProgressBar: View {
    @Environment(\.palette) private var p
    let fraction: Double
    var height: CGFloat = 8
    var colors: [Color] = [Tok.warning, Tok.tint]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(p.track)
                Capsule().fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
                    .opacity(fraction > 0 ? 1 : 0)
            }
        }
        .frame(height: height)
        .animation(.easeOut(duration: 0.6), value: fraction)
    }
}

struct Chip: View {
    @Environment(\.palette) private var p
    var icon: String? = nil
    let title: String
    var selected: Bool = false
    var dashed: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Icon3D(name: icon, size: 24) }
                Text(title).font(.alx(15, .medium)).lineLimit(1)
            }
            .foregroundStyle(selected ? Color.white : dashed ? Tok.tintInk : p.label)
            .padding(.leading, icon == nil ? 16 : 12)
            .padding(.trailing, 16)
            .frame(height: 44)
            .background(Capsule().fill(selected ? Tok.tint : dashed ? Color.clear : p.surface))
            .overlay(Capsule().strokeBorder(dashed ? Tok.tintInk.opacity(0.65) : Color.clear, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(PressStyle())
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    var ghost: Bool = false
    let action: () -> Void
    @Environment(\.palette) private var p

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(.body, weight: .semibold)) }
                Text(title).font(.alx(17, .semibold, relativeTo: .headline))
            }
            .foregroundStyle(ghost ? p.label : Color.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(ghost ? p.surface2 : Tok.tint))
            .shadow(color: ghost ? .clear : Tok.tint.opacity(0.32), radius: 15, x: 0, y: 12)
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}

/// Fixed bottom area for a sheet's main action.
struct BottomBar<Content: View>: View {
    @Environment(\.palette) private var p
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 4, content: content)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(LinearGradient(colors: [p.bg.opacity(0), p.bg, p.bg], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }
}

struct FieldBox<Content: View>: View {
    @Environment(\.palette) private var p
    let label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.alx(13, relativeTo: .caption)).foregroundStyle(p.label2).padding(.horizontal, 4)
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(p.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }
}

struct SettingRow<Value: View>: View {
    @Environment(\.palette) private var p
    let icon: String
    let title: String
    var chevron: Bool = true
    @ViewBuilder var value: () -> Value

    var body: some View {
        HStack(spacing: 14) {
            Icon3D(name: icon, size: 34)
            Text(title).font(.alx(16)).foregroundStyle(p.label).multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            value().font(.alx(15)).foregroundStyle(p.label2)
            if chevron { Image(systemName: "chevron.forward").font(.system(.footnote, weight: .semibold)).foregroundStyle(p.label3).accessibilityHidden(true) }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

struct EmptyCard: View {
    @Environment(\.palette) private var p
    let icon: String
    let title: String
    let text: String
    var actions: AnyView? = nil

    var body: some View {
        VStack(spacing: 6) {
            Icon3D(name: icon, size: 64, shadow: true).padding(.bottom, 4)
            Text(title).font(.alx(17, .semibold)).foregroundStyle(p.label)
            Text(text).font(.alx(14.5)).foregroundStyle(p.label2).multilineTextAlignment(.center)
            if let actions { actions.padding(.top, 10) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 18)
    }
}

struct SmallButton: View {
    @Environment(\.palette) private var p
    let title: String
    var ghost: Bool = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).font(.alx(15, .semibold)).foregroundStyle(ghost ? p.label : .white)
                .padding(.horizontal, 18).frame(height: 44)
                .background(Capsule().fill(ghost ? p.surface2 : Tok.tint))
        }
        .buttonStyle(PressStyle())
    }
}

struct Toast: View {
    @Environment(\.palette) private var p
    let text: String
    var body: some View {
        Text(text).font(.alx(14.5)).foregroundStyle(p.label)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(p.surface2, in: Capsule())
            .shadow(color: .black.opacity(0.45), radius: 15, x: 0, y: 12)
    }
}

// MARK: - Tab bar

struct FloatingTabBar: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var nav: Nav
    @Environment(\.palette) private var p

    private struct Item: Identifiable { let tab: AppTab; let icon: String; let key: String; var id: String { key } }
    private let items: [Item] = [Item(tab: .today, icon: "calendar", key: "today"), Item(tab: .txs, icon: "receipt", key: "txs"),
                                 Item(tab: .insights, icon: "chart", key: "insights"), Item(tab: .settings, icon: "gear", key: "settings")]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let selected = nav.tab == item.tab
                Button {
                    if nav.tab != item.tab { UISelectionFeedbackGenerator().selectionChanged() }
                    withAnimation(.easeOut(duration: 0.2)) { nav.tab = item.tab }
                } label: {
                    VStack(spacing: 1) {
                        Icon3D(name: item.icon, size: 27)
                            .grayscale(selected ? 0 : 1)
                            .opacity(selected ? 1 : 0.55)
                            .shadow(color: .black.opacity(selected ? 0.45 : 0), radius: 3, x: 0, y: 3)
                        Text(store.t(item.key)).font(.alx(11, .medium, relativeTo: .caption2)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selected ? p.label : p.label2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Capsule().fill(Color.white.opacity(selected ? 0.1 : 0)))
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(height: Layout.tabBarHeight)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .background(Capsule().fill(.ultraThinMaterial))
        .background(Capsule().fill(p.glass))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 12)
        .padding(.horizontal, 16)
    }
}

enum Layout {
    static let tabBarHeight: CGFloat = 66

    /// Width of this iPhone's screen in points (portrait).
    @MainActor static var screenWidth: CGFloat {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let b = scene?.screen.bounds, b.width > 0 else { return 402 }
        return min(b.width, b.height)
    }

    /// The window's own safe-area insets (status bar / Dynamic Island, home indicator), as a cross-check.
    @MainActor static var windowInsets: UIEdgeInsets {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        return (windows.first { $0.isKeyWindow } ?? windows.first)?.safeAreaInsets ?? .zero
    }

    /// Distance from the physical bottom of the screen to the floating tab bar.
    /// Face ID iPhones (34 pt home-indicator inset): 21 pt, which leaves ~8 pt above the indicator, like the system bar.
    /// Home-button iPhones (no inset): 10 pt.
    static func tabBarGap(bottomInset: CGFloat) -> CGFloat {
        bottomInset > 0 ? max(10, bottomInset - 13) : 10
    }
}
