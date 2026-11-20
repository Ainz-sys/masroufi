import SwiftUI

/// First-launch tutorial, six steps. Each step is its own view, so nothing typed on one step keeps the keyboard open on the next.
struct OnboardingFlow: View {
    @EnvironmentObject var store: Store
    @Environment(\.palette) private var p
    @Environment(\.openURL) private var openURL
    @State private var step = Demo.obStep
    @State private var forward = true
    @State private var sample = Demo.obStep == 1 ? (Demo.pasteText ?? "") : ""
    @State private var added = false
    @State private var budgetText = ""   // the person types their own monthly figure (or taps a preset)
    @State private var showSalary = false
    @State private var openedShortcuts = false
    @FocusState private var focused: Bool

    private let count = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    Group {
                        switch step {
                        case 0: welcome
                        case 1: tryIt
                        case 2: automation
                        case 3: budget
                        case 4: alerts
                        default: privacy
                        }
                    }
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity), removal: .opacity))
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                footer
            }
            .background(p.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t("done")) { focused = false; hideKeyboard() }.font(.alx(16, .semibold))
                }
            }
            .sheet(isPresented: $showSalary) {
                VStack(spacing: 0) {
                    Text(store.t("salaryDay")).font(.alx(17, .semibold)).foregroundStyle(p.label).padding(.top, 22)
                    Text(store.t("salaryHint")).font(.alx(13.5)).foregroundStyle(p.label2).multilineTextAlignment(.center).padding(.horizontal, 24).padding(.vertical, 10)
                    SalaryGrid(selected: store.data.settings.salaryDay) { d in
                        store.update { $0.settings.salaryDay = d }
                        showSalary = false
                    }
                    Spacer()
                }
                .environment(\.palette, p)
                .presentationDetents([.medium])
                .presentationBackground(p.bg)
                .presentationDragIndicator(.visible)
            }
            .onAppear { if store.data.settings.monthlyBudget > 0 { budgetText = Fmt.m0(store.data.settings.monthlyBudget).replacingOccurrences(of: ",", with: "") } }
        }
    }

    // MARK: Navigation

    func go(_ to: Int) {
        focused = false
        hideKeyboard()
        forward = to > step
        withAnimation(.easeOut(duration: 0.3)) { step = min(max(0, to), count - 1) }
    }

    func finish() {
        hideKeyboard()
        store.update { $0.settings.onboarded = true }
    }

    var dots: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule().fill(i == step ? Tok.tintInk : p.label3.opacity(0.45)).frame(width: i == step ? 22 : 7, height: 7)
            }
        }
        .animation(.easeOut(duration: 0.2), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(step + 1) / \(count)")
    }

    var topBar: some View {
        HStack {
            if step == 0 {
                Spacer()
                Button {
                    store.update { $0.settings.language = $0.settings.language == .ar ? .en : .ar }
                } label: {
                    HStack(spacing: 6) {
                        Icon3D(name: "globe", size: 22)
                        Text(store.lang == .ar ? "English" : "العربية").font(.alx(14, .medium)).foregroundStyle(p.label)
                    }
                    .padding(.horizontal, 14).frame(height: 40)
                    .background(Capsule().fill(p.glass)).overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(PressStyle())
            } else {
                RoundButton(systemImage: "chevron.backward", label: store.t("back")) { go(step - 1) }
                Spacer()
                dots
                Spacer()
                TextAction(title: store.t("skip"), color: p.label2, weight: .medium) { go(step + 1) }
                    .opacity(step == count - 1 ? 0 : 1).disabled(step == count - 1)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 56)
    }

    @ViewBuilder var footer: some View {
        BottomBar {
            switch step {
            case 0:
                dots.padding(.bottom, 10)
                PrimaryButton(title: store.t("start"), systemImage: store.lang == .ar ? "arrow.left" : "arrow.right") { go(1) }
            case 1:
                PrimaryButton(title: store.t("next")) { go(2) }
            case 2:
                if openedShortcuts { // back from Shortcuts: say it's done and move on
                    PrimaryButton(title: store.t("didSetupNext")) { store.confirmAuto(); go(3) }
                    TextAction(title: store.t("openAgain"), color: p.label2, weight: .medium) {
                        if let u = URL(string: "shortcuts://") { openURL(u) }
                    }
                } else {
                    PrimaryButton(title: store.t("openShortcuts"), systemImage: "arrow.up.forward.app") {
                        openedShortcuts = true
                        if let u = URL(string: "shortcuts://") { openURL(u) }
                    }
                    TextAction(title: store.t("later"), color: p.label2, weight: .medium) { go(3) }
                }
            case 3:
                PrimaryButton(title: store.t("next")) {
                    let v = Double(SMSParser.normalize(budgetText).replacingOccurrences(of: ",", with: "")) ?? 0
                    store.update { $0.settings.monthlyBudget = max(0, v); Ledger.resetMonthAlerts(&$0) }
                    go(4)
                }
            case 4:
                PrimaryButton(title: store.t("enableAlerts")) {
                    Task {
                        _ = await Notifier.requestPermission()
                        await MainActor.run {
                            store.update { $0.settings.alert80 = true; $0.settings.alert100 = true; $0.settings.notifyEach = true }
                            go(5)
                        }
                    }
                }
                TextAction(title: store.t("notNow"), color: p.label2, weight: .medium) { go(5) }
            default:
                PrimaryButton(title: store.t("enterApp")) { finish() }
            }
        }
    }

    // MARK: Steps

    func hero(_ icon: String, _ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Icon3D(name: icon, size: 84, shadow: true).padding(.top, 4)
            Text(title).font(.alx(30, .bold, relativeTo: .largeTitle)).foregroundStyle(p.label).fixedSize(horizontal: false, vertical: true)
            Text(text).font(.alx(16.5, .light)).foregroundStyle(p.label2).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
    }

    var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            Card3DView(info: store.cardInfo()).frame(height: 250)
            Text(store.t("ob1t")).font(.alx(30, .bold, relativeTo: .largeTitle)).foregroundStyle(p.label).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 18).padding(.top, 8)
            Text(store.t("ob1p")).font(.alx(16.5, .light)).foregroundStyle(p.label2).lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 18).padding(.top, 8)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(["sms:v1", "label:v2", "lock:v3"], id: \.self) { item in
                    let parts = item.split(separator: ":").map(String.init)
                    HStack(spacing: 14) {
                        Icon3D(name: parts[0], size: 40)
                        Text(store.t(parts[1])).font(.alx(16, .medium)).foregroundStyle(p.label)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.top, 16)
        }
    }

    var tryIt: some View {
        let parsed = sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : SMSParser.parse(sample)
        return VStack(alignment: .leading, spacing: 0) {
            hero("sms", store.t("ob2t"), store.t("ob2p"))
            ZStack(alignment: .topLeading) {
                if sample.isEmpty {
                    Text(store.t("pastePh")).font(.alx(16)).foregroundStyle(p.label3).padding(.horizontal, 20).padding(.vertical, 22)
                }
                TextEditor(text: $sample)
                    .font(.alx(16)).foregroundStyle(p.label)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(12)
                    .onChange(of: sample) { _, _ in added = false }
            }
            .frame(minHeight: 130)
            .background(p.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .environment(\.layoutDirection, .leftToRight)
            .padding(.horizontal, 18).padding(.top, 14)
            if let p0 = parsed {
                SurfaceGroup { TxRow(tx: Ledger.transaction(from: p0, raw: sample, data: store.data, now: Date(), live: false)) }
                    .padding(.top, 14)
                PrimaryButton(title: added ? store.t("added") : store.t("addToMine"), enabled: !added, ghost: true) {
                    _ = store.addPasted(sample)
                    added = true
                    focused = false
                }
                .padding(.horizontal, 18).padding(.top, 12)
            } else if !sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(store.t("notFound")).font(.alx(13.5)).foregroundStyle(p.label2).padding(.horizontal, 22).padding(.top, 10)
            }
        }
    }

    var automation: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero("zap", store.t("ob3t"), store.t("ob3p"))
            GuideSteps()
        }
    }

    var budget: some View {
        let v = Double(SMSParser.normalize(budgetText).replacingOccurrences(of: ",", with: "")) ?? 0
        let days = Ledger.cycle(salaryDay: store.data.settings.salaryDay).days
        return VStack(alignment: .leading, spacing: 0) {
            hero("budget", store.t("ob4t"), store.t("ob4p"))
            BudgetInput(text: $budgetText).focused($focused).padding(.top, 16)
            Presets(values: Presets.monthly, text: $budgetText).padding(.top, 18)
            SurfaceGroup {
                Button { focused = false; showSalary = true } label: {
                    SettingRow(icon: "calendar", title: store.t("salaryDay")) { Text("\(store.data.settings.salaryDay)") }
                }
                .buttonStyle(PressStyle())
                RowDivider()
                SettingRow(icon: "cash", title: store.t("perDayShare"), chevron: false) {
                    Text("\u{200E}≈ " + Fmt.m0(v / Double(days)) + " " + store.t("cur"))
                }
            }
            .padding(.top, 22)
            Text(store.t("salaryHint")).font(.alx(13.5)).foregroundStyle(p.label2).padding(.horizontal, 22).padding(.top, 8)
        }
    }

    var alerts: some View { hero("bell", store.t("ob5t"), store.t("ob5p")) }

    var privacy: some View { hero("lock", store.t("ob6t"), store.t("ob6p")) }
}
