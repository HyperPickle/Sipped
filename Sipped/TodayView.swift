import Charts
import SwiftData
import SwiftUI

private struct TodayGraphPoint: Identifiable {
    let id: String
    let index: Int
    let value: Double
    let category: DrinkCategory
    let name: String
}

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DrinkLog.orderIndex) private var allLogs: [DrinkLog]
    @Bindable var preferences: UserPreferences
    let environment: AppEnvironment
    let openLogger: () -> Void
    @State private var selectedLog: DrinkLog?
    @State private var deletedSnapshot: LogSnapshot?
    @State private var showingSettings = false

    private var logs: [DrinkLog] { allLogs.filter { environment.isDate($0.loggedAt, inSameDayAs: environment.now) } }
    private var totals: DailyTotals { DailyTotals(logs: logs, standard: preferences.alcoholStandard) }
    private var graphPoints: [TodayGraphPoint] {
        var runningTotal = 0.0
        return logs.enumerated().compactMap { index, log in
            let value: Double
            switch preferences.selectedMeasure {
            case .fluid: value = log.consumedML
            case .caffeine: value = log.caffeineMG
            case .sugar: value = log.sugarG
            case .alcohol: value = log.standardDrinks(using: preferences.alcoholStandard)
            }
            guard value > 0 else { return nil }
            runningTotal += value
            return TodayGraphPoint(id: log.logID, index: index, value: runningTotal, category: log.category, name: log.drinkName)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TODAY").font(.caption2.bold()).tracking(1.2).foregroundStyle(SippedTheme.chromeAccent)
                        Text(environment.now.formatted(.dateTime.weekday(.wide).day().month(.wide))).font(.title2.weight(.bold))
                    }
                    totalsGrid
                    MeasureSelector(selection: Binding(get: { preferences.selectedMeasure }, set: { preferences.selectedMeasure = $0; try? modelContext.save() }))
                    graph
                    SippedSectionHeading(eyebrow: nil, title: "Drinks", trailing: "\(logs.count)")
                    if logs.isEmpty { emptyState } else {
                        LazyVStack(spacing: 10) {
                            ForEach(logs.reversed()) { log in Button { selectedLog = log } label: { LogEntryRow(log: log, preferences: preferences) }.buttonStyle(.plain) }
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
            }
            .background(SippedTheme.canvas)
            .navigationTitle("Sipped").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings").accessibilityIdentifier("settings.open") } }
            .sheet(item: $selectedLog) { EntryDetailView(log: $0, preferences: preferences, onDelete: delete) }
            .sheet(isPresented: $showingSettings) { SettingsSheet(preferences: preferences) }
            .overlay(alignment: .bottom) { if deletedSnapshot != nil { UndoBanner(action: undo).padding(.bottom, 4) } }
        }
    }

    private var totalsGrid: some View {
        HStack(spacing: 0) {
            ForEach(Array(MeasureKind.allCases.enumerated()), id: \.element.id) { index, measure in
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: measure.symbol).font(.caption.weight(.semibold)).foregroundStyle(measure.color)
                    Text(DisplayFormatter.value(totals.value(for: measure), measure: measure, units: preferences.units))
                        .font(.subheadline.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.55)
                    Text(measure.name).font(.caption2).foregroundStyle(SippedTheme.secondaryInk).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, index == 0 ? 0 : 10)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("today.total.\(measure.rawValue)")
                if index < MeasureKind.allCases.count - 1 {
                    Divider().frame(height: 44)
                }
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 14)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var graph: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(preferences.selectedMeasure.name) by drink", systemImage: preferences.selectedMeasure.symbol).font(.headline).foregroundStyle(preferences.selectedMeasure.color)
                Spacer(); Text(DisplayFormatter.value(totals.value(for: preferences.selectedMeasure), measure: preferences.selectedMeasure, units: preferences.units)).font(.subheadline.bold().monospacedDigit())
            }
            if graphPoints.isEmpty {
                ContentUnavailableView("No \(preferences.selectedMeasure.name.lowercased()) contributions", systemImage: preferences.selectedMeasure.symbol)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(graphPoints) { point in
                    AreaMark(x: .value("Drink", point.index), y: .value(preferences.selectedMeasure.name, point.value))
                        .foregroundStyle(LinearGradient(colors: [preferences.selectedMeasure.color.opacity(0.24), preferences.selectedMeasure.color.opacity(0.015)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Drink", point.index), y: .value(preferences.selectedMeasure.name, point.value))
                        .foregroundStyle(preferences.selectedMeasure.color)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Drink", point.index), y: .value(preferences.selectedMeasure.name, point.value))
                        .foregroundStyle(point.category.tint)
                        .symbolSize(72)
                        .annotation(position: .top) {
                            Image(systemName: point.category.symbol).font(.caption2.weight(.bold)).foregroundStyle(point.category.tint).accessibilityHidden(true)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(position: .leading) { _ in AxisGridLine().foregroundStyle(SippedTheme.line); AxisValueLabel() } }
                .frame(height: 170)
                .accessibilityIdentifier("today.graph.\(preferences.selectedMeasure.rawValue)")
            }
        }
        .padding(16)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyState: some View {
        Button(action: openLogger) {
            VStack(spacing: 12) {
                Image(systemName: "drop.fill").font(.system(size: 34, weight: .light)).foregroundStyle(SippedTheme.chromeAccent)
                Text("Your drink record starts here").font(.headline)
                Text("Log a drink").font(.subheadline.bold()).foregroundStyle(SippedTheme.chromeAccent)
            }
            .frame(maxWidth: .infinity, minHeight: 154)
            .background(SippedTheme.chromeAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }.buttonStyle(.plain).accessibilityIdentifier("today.empty.add")
    }

    private func delete(_ log: DrinkLog) {
        deletedSnapshot = LogSnapshot(log); modelContext.delete(log); try? modelContext.save()
        Task { try? await Task.sleep(for: .seconds(5)); withAnimation { deletedSnapshot = nil } }
    }
    private func undo() {
        guard let snapshot = deletedSnapshot else { return }; modelContext.insert(snapshot.restoredLog()); try? modelContext.save(); withAnimation { deletedSnapshot = nil }
    }
}

struct MeasureSelector: View {
    @Binding var selection: MeasureKind
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MeasureKind.allCases) { measure in
                Button { selection = measure } label: {
                    HStack(spacing: 5) {
                        Image(systemName: measure.symbol).font(.caption)
                        Text(measure.name).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
                    }
                        .foregroundStyle(selection == measure ? .white : SippedTheme.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(selection == measure ? measure.color : .clear, in: Capsule())
                }.buttonStyle(.plain).accessibilityIdentifier("measure.\(measure.rawValue)")
            }
        }
        .padding(4)
        .background(SippedTheme.surface, in: Capsule())
    }
}
