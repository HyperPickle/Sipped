import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today, history, library
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var symbol: String {
        switch self { case .today: "house"; case .history: "chart.xyaxis.line"; case .library: "books.vertical" }
    }
    var selectedSymbol: String {
        switch self { case .today: "house.fill"; case .history: "chart.xyaxis.line"; case .library: "books.vertical.fill" }
    }
}

struct MainTabView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var preferences: UserPreferences
    let environment: AppEnvironment
    @State private var tab: AppTab = .today
    @State private var showingLog = false
    @State private var showingSettings = false
    @State private var librarySearchFocused = false
    @State private var tabDirection: SippedMotionDirection = .forward
    private var accessibilityLayout: Bool { dynamicTypeSize >= .accessibility1 }
    private var showsBottomChrome: Bool { !showingLog && !librarySearchFocused }

    init(preferences: UserPreferences, environment: AppEnvironment) {
        self.preferences = preferences
        self.environment = environment
        let arguments = ProcessInfo.processInfo.arguments
        let requestedTab = arguments.first(where: { $0.hasPrefix("--start-tab=") })
            .flatMap { $0.split(separator: "=", maxSplits: 1).last.map(String.init) }
        _tab = State(initialValue: requestedTab.flatMap(AppTab.init(rawValue:)) ?? .today)
        _showingLog = State(initialValue: arguments.contains("--open-logger") || arguments.contains(where: { $0.hasPrefix("--open-drink=") }))
        _showingSettings = State(initialValue: arguments.contains("--open-settings"))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .today: TodayView(preferences: preferences, environment: environment, openLogger: { showingLog = true })
                case .history: HistoryView(preferences: preferences, environment: environment)
                case .library: LibraryView(preferences: preferences, isSearchFocused: $librarySearchFocused)
                }
            }
            .id(tab)
            .transition(reduceMotion ? .opacity : SippedMotion.screenTransition(direction: tabDirection))
            .safeAreaPadding(.bottom, showsBottomChrome ? 84 : 0)

            if showsBottomChrome {
                ZStack {
                    Color.clear
                        .frame(height: 64)
                        .contentShape(Rectangle())
                    .accessibilityHidden(true)

                    HStack(spacing: 10) {
                        HStack(spacing: 2) {
                            ForEach(AppTab.allCases) { item in
                                tabControl(for: item)
                            }
                        }
                        .padding(4)
                        .glassEffect(.regular, in: .capsule)
                        .overlay { Capsule().stroke(SippedTheme.line, lineWidth: 1) }
                        .contentShape(Capsule())
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    selectTab(tab(at: value.location.x))
                                }
                        )

                        Button { showingLog = true } label: {
                            Image(systemName: "plus").font(.title2.bold()).foregroundStyle(SippedTheme.onChromeAccent)
                                .frame(width: 64, height: 64)
                        }
                        .buttonStyle(.plain)
                        .background(SippedTheme.chromeAccent, in: Circle())
                        .contentShape(Circle())
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                        .accessibilityLabel("Log a drink")
                        .accessibilityIdentifier("global.add")
                    }
                }
                .padding(.horizontal, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? SippedMotion.reduced : SippedMotion.element, value: showsBottomChrome)
        .background(SippedTheme.canvas.ignoresSafeArea())
        .sheet(isPresented: $showingLog) {
            LoggingFlowView(preferences: preferences, environment: environment)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) { SettingsSheet(preferences: preferences) }
    }

    private func selectTab(_ newTab: AppTab) {
        guard newTab != tab,
              let oldIndex = AppTab.allCases.firstIndex(of: tab),
              let newIndex = AppTab.allCases.firstIndex(of: newTab)
        else { return }
        tabDirection = SippedMotion.direction(from: oldIndex, to: newIndex)
        withAnimation(reduceMotion ? SippedMotion.reduced : SippedMotion.screen) {
            tab = newTab
        }
    }

    private func tabControl(for item: AppTab) -> some View {
        Button { selectTab(item) } label: {
            VStack(spacing: 4) {
                Image(systemName: tab == item ? item.selectedSymbol : item.symbol)
                    .font(.system(size: 17, weight: .semibold))
                if !accessibilityLayout {
                    Text(item.name).font(.caption2.weight(.semibold)).lineLimit(1)
                }
            }
            .foregroundStyle(tab == item ? SippedTheme.onChromeAccent : SippedTheme.secondaryInk)
            .frame(width: 64, height: 56)
            .background(tab == item ? SippedTheme.chromeAccent : .clear, in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(item.rawValue)")
    }

    private func tab(at horizontalLocation: CGFloat) -> AppTab {
        let tabWidth: CGFloat = 64
        let tabSpacing: CGFloat = 2
        let horizontalPadding: CGFloat = 4
        let firstTabCenter = horizontalPadding + tabWidth / 2
        let rawIndex = ((horizontalLocation - firstTabCenter) / (tabWidth + tabSpacing)).rounded()
        let index = min(max(Int(rawIndex), 0), AppTab.allCases.count - 1)
        return AppTab.allCases[index]
    }
}
