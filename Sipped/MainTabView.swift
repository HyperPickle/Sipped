import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today, history, library
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var symbol: String {
        switch self { case .today: "sun.max"; case .history: "chart.xyaxis.line"; case .library: "books.vertical" }
    }
    var selectedSymbol: String {
        switch self { case .today: "sun.max.fill"; case .history: "chart.xyaxis.line"; case .library: "books.vertical.fill" }
    }
}

struct MainTabView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var preferences: UserPreferences
    let environment: AppEnvironment
    @State private var tab: AppTab = .today
    @State private var showingLog = false
    @State private var showingSettings = false
    private var accessibilityLayout: Bool { dynamicTypeSize >= .accessibility1 }

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
                case .library: LibraryView(preferences: preferences)
                }
            }
            .padding(.bottom, 84)

            HStack(spacing: 10) {
                HStack(spacing: 2) {
                    ForEach(AppTab.allCases) { item in
                        Button { tab = item } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tab == item ? item.selectedSymbol : item.symbol)
                                    .font(.system(size: 17, weight: .semibold))
                                if !accessibilityLayout {
                                    Text(item.name).font(.caption2.weight(.semibold)).lineLimit(1)
                                }
                            }
                            .foregroundStyle(tab == item ? SippedTheme.onChromeAccent : SippedTheme.secondaryInk)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(tab == item ? SippedTheme.chromeAccent : .clear, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tab.\(item.rawValue)")
                    }
                }
                .padding(4)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay { Capsule().stroke(SippedTheme.line, lineWidth: 1) }

                Button { showingLog = true } label: {
                    Image(systemName: "plus").font(.title2.bold()).foregroundStyle(SippedTheme.onChromeAccent)
                        .frame(width: 64, height: 64).background(SippedTheme.chromeAccent, in: Circle())
                        .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
                }
                .accessibilityLabel("Log a drink")
                .accessibilityIdentifier("global.add")
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .background(SippedTheme.canvas.ignoresSafeArea())
        .sheet(isPresented: $showingLog) {
            LoggingFlowView(preferences: preferences, environment: environment)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSettings) { SettingsSheet(preferences: preferences) }
    }
}
