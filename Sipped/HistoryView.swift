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
    @State private var selectedDayDate: Date

    init(preferences: UserPreferences, environment: AppEnvironment) {
        self.preferences = preferences
        self.environment = environment
        _selectedDayDate = State(initialValue: environment.startOfDay(environment.now))
    }

    private var days: [HistoryDay] {
        (0..<7).reversed().map { offset in
            let date = environment.date(byAddingDays: -offset, to: environment.now)
            let logs = allLogs.filter { environment.isDate($0.loggedAt, inSameDayAs: date) }
            return HistoryDay(date: environment.startOfDay(date), logs: logs, totals: DailyTotals(logs: logs, standard: preferences.alcoholStandard))
        }
    }

    private var selectedDay: HistoryDay {
        days.first(where: { environment.isDate($0.date, inSameDayAs: selectedDayDate) }) ?? days.last!
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("A calm view of the last seven days").font(.subheadline).foregroundStyle(SippedTheme.secondaryInk)
                    MeasureSelector(selection: Binding(get: { preferences.selectedMeasure }, set: { preferences.selectedMeasure = $0; try? modelContext.save() }))
                    historyChart
                    selectedDayInspector
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Seven-day \(preferences.selectedMeasure.name.lowercased())", systemImage: preferences.selectedMeasure.symbol)
                    .font(.headline)
                    .foregroundStyle(preferences.selectedMeasure.color)
                Spacer()
                if preferences.selectedMeasure == .fluid, let goal = preferences.validDailyFluidGoalML {
                    Text("Goal \(DisplayFormatter.volume(goal, units: preferences.units))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SippedTheme.secondaryInk)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassEffect(.regular, in: .capsule)
                }
            }
            LiquidColumnsChart(
                columns: days.map { day in
                    let isToday = environment.isDate(day.date, inSameDayAs: environment.now)
                    let value = day.totals.value(for: preferences.selectedMeasure)
                    let percentage = preferences.selectedMeasure == .fluid
                        ? DailyFluidGoalMath.percentage(for: day.totals.fluidML, goalML: preferences.validDailyFluidGoalML)
                        : nil
                    return LiquidColumn(id: day.date,
                                        label: day.date.formatted(.dateTime.weekday(.narrow)),
                                        value: value,
                                        isToday: isToday,
                                        percentage: percentage,
                                        isOverGoal: percentage.map { $0 > 100 } ?? false,
                                        accessibilityDateLabel: isToday
                                            ? "Today"
                                            : day.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                },
                color: preferences.selectedMeasure.color,
                valueLabel: { DisplayFormatter.value($0, measure: preferences.selectedMeasure, units: preferences.units) },
                scaleMaximum: preferences.selectedMeasure == .fluid ? preferences.validDailyFluidGoalML : nil,
                selectedID: selectedDay.date,
                onSelect: { selectedDayDate = $0 })
            .id(preferences.selectedMeasure)
            .sippedBlurReplaceTransition()
            .frame(height: 190).accessibilityIdentifier("history.graph")
        }
        .padding(16)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var selectedDayInspector: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(environment.isDate(selectedDay.date, inSameDayAs: environment.now) ? "Today" : selectedDay.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .font(.title3.weight(.bold))
                        .accessibilityIdentifier("history.selectedDay")
                    Text("\(selectedDay.logs.count) recorded drink\(selectedDay.logs.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(SippedTheme.secondaryInk)
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(MeasureKind.allCases) { measure in
                    VStack(alignment: .leading, spacing: 4) {
                        Label(measure.name, systemImage: measure.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(measure.color)
                        Text(DisplayFormatter.value(selectedDay.totals.value(for: measure), measure: measure, units: preferences.units))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if measure == .fluid,
                           let percentage = DailyFluidGoalMath.percentage(for: selectedDay.totals.fluidML, goalML: preferences.validDailyFluidGoalML) {
                            Text("\(percentage.formatted(.number.precision(.fractionLength(0...1))))% of goal")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(selectedDay.totals.fluidML > (preferences.validDailyFluidGoalML ?? .greatestFiniteMagnitude) ? .orange : SippedTheme.secondaryInk)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("history.inspector.\(measure.rawValue)")
                }
            }

            if selectedDay.logs.isEmpty {
                Text("No drinks recorded")
                    .font(.subheadline)
                    .foregroundStyle(SippedTheme.secondaryInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("history.inspector.empty")
            } else {
                NavigationLink {
                    HistoryDayDetail(day: selectedDay, preferences: preferences)
                } label: {
                    Text("View drinks")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SippedTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityIdentifier("history.viewDrinks")
            }
        }
        .padding(16)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityIdentifier("history.inspector")
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
