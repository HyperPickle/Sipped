import SwiftData
import SwiftUI

private struct HistoryDay: Identifiable {
    let date: Date
    let logs: [DrinkLog]
    let totals: DailyTotals
    var id: Date { date }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DrinkLog.loggedAt) private var allLogs: [DrinkLog]
    @Bindable var preferences: UserPreferences
    let environment: AppEnvironment
    @State private var showingSettings = false

    private var days: [HistoryDay] {
        (0..<7).reversed().map { offset in
            let date = environment.date(byAddingDays: -offset, to: environment.now)
            let logs = allLogs.filter { environment.isDate($0.loggedAt, inSameDayAs: date) }
            return HistoryDay(date: environment.startOfDay(date), logs: logs, totals: DailyTotals(logs: logs, standard: preferences.alcoholStandard))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("A calm view of the last seven days").font(.subheadline).foregroundStyle(SippedTheme.secondaryInk)
                    MeasureSelector(selection: Binding(get: { preferences.selectedMeasure }, set: { preferences.selectedMeasure = $0; try? modelContext.save() }))
                    historyChart
                    SippedSectionHeading(eyebrow: nil, title: "Daily record")
                    LazyVStack(spacing: 10) {
                        ForEach(days.reversed()) { day in
                            NavigationLink { HistoryDayDetail(day: day, preferences: preferences) } label: { HistoryDayRow(day: day, preferences: preferences, isToday: environment.isDate(day.date, inSameDayAs: environment.now)) }.buttonStyle(.plain)
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, SippedLayout.floatingChromeContentClearance, for: .scrollContent)
            .background(SippedTheme.canvas).navigationTitle("History")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings").accessibilityIdentifier("settings.open") } }
            .sheet(isPresented: $showingSettings) { SettingsSheet(preferences: preferences) }
        }
    }

    private var historyChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Seven-day \(preferences.selectedMeasure.name.lowercased())", systemImage: preferences.selectedMeasure.symbol).font(.headline).foregroundStyle(preferences.selectedMeasure.color)
            LiquidColumnsChart(
                columns: days.map { day in
                    LiquidColumn(id: day.date,
                                 label: day.date.formatted(.dateTime.weekday(.narrow)),
                                 value: day.totals.value(for: preferences.selectedMeasure),
                                 isToday: environment.isDate(day.date, inSameDayAs: environment.now))
                },
                color: preferences.selectedMeasure.color,
                valueLabel: { DisplayFormatter.value($0, measure: preferences.selectedMeasure, units: preferences.units) })
            .id(preferences.selectedMeasure)
            .sippedBlurReplaceTransition()
            .frame(height: 190).accessibilityIdentifier("history.graph")
        }
        .padding(16)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct HistoryDayRow: View {
    let day: HistoryDay
    let preferences: UserPreferences
    let isToday: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))).font(.headline); Spacer(); Text("\(day.logs.count) drink\(day.logs.count == 1 ? "" : "s")").font(.caption).foregroundStyle(SippedTheme.secondaryInk); Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(SippedTheme.secondaryInk) }
            HStack(spacing: 8) {
                ForEach(MeasureKind.allCases) { measure in
                    VStack(alignment: .leading, spacing: 3) {
                        Image(systemName: measure.symbol).font(.caption).foregroundStyle(measure.color)
                        SippedAnimatedNumericText(
                            text: DisplayFormatter.value(
                                day.totals.value(for: measure),
                                measure: measure,
                                units: preferences.units
                            )
                        )
                            .font(.caption2.bold())
                            .lineLimit(1).minimumScaleFactor(0.55)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct HistoryDayDetail: View {
    @Environment(\.modelContext) private var modelContext
    let day: HistoryDay
    @Bindable var preferences: UserPreferences
    @State private var selectedLog: DrinkLog?
    @State private var deletedSnapshot: LogSnapshot?
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 6) {
                    ForEach(MeasureKind.allCases) { measure in
                        VStack(spacing: 5) {
                            Image(systemName: measure.symbol).font(.caption).foregroundStyle(measure.color)
                            SippedAnimatedNumericText(
                                text: DisplayFormatter.value(
                                    day.totals.value(for: measure),
                                    measure: measure,
                                    units: preferences.units
                                )
                            )
                                .font(.caption2.bold())
                                .lineLimit(1).minimumScaleFactor(0.55)
                            Text(measure.name).font(.caption2).foregroundStyle(SippedTheme.secondaryInk)
                        }
                        .frame(maxWidth: .infinity, minHeight: 62)
                    }
                }
                .padding(10)
                .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                if day.logs.isEmpty { ContentUnavailableView("No drinks recorded", systemImage: "cup.and.saucer") }
                ForEach(day.logs.reversed()) { log in Button { selectedLog = log } label: { LogEntryRow(log: log, preferences: preferences) }.buttonStyle(.plain) }
            }.padding(16)
        }
        .contentMargins(.bottom, SippedLayout.floatingChromeContentClearance, for: .scrollContent)
        .scrollIndicators(.hidden)
        .background(SippedTheme.canvas).navigationTitle(day.date.formatted(.dateTime.weekday(.wide).day().month())).navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedLog) { EntryDetailView(log: $0, preferences: preferences, onDelete: delete) }
        .overlay(alignment: .bottom) { if deletedSnapshot != nil { UndoBanner(action: undo) } }
    }
    private func delete(_ log: DrinkLog) { deletedSnapshot = LogSnapshot(log); modelContext.delete(log); try? modelContext.save() }
    private func undo() { guard let snapshot = deletedSnapshot else { return }; modelContext.insert(snapshot.restoredLog()); try? modelContext.save(); deletedSnapshot = nil }
}
