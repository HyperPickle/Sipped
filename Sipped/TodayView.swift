import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \DrinkLog.orderIndex) private var allLogs: [DrinkLog]
    @Bindable var preferences: UserPreferences
    let environment: AppEnvironment
    let openLogger: () -> Void
    @State private var selectedLog: DrinkLog?
    @State private var deletedSnapshot: LogSnapshot?

    private var logs: [DrinkLog] { allLogs.filter { environment.isDate($0.loggedAt, inSameDayAs: environment.now) } }
    private var totals: DailyTotals { DailyTotals(logs: logs, standard: preferences.alcoholStandard) }
    private var graphPoints: [ReservoirPoint] {
        var runningTotal = 0.0
        return logs.sorted { $0.loggedAt < $1.loggedAt }.compactMap { log in
            let value: Double
            switch preferences.selectedMeasure {
            case .fluid: value = log.consumedML
            case .caffeine: value = log.caffeineMG
            case .sugar: value = log.sugarG
            case .alcohol: value = log.standardDrinks(using: preferences.alcoholStandard)
            }
            guard value > 0 else { return nil }
            runningTotal += value
            return ReservoirPoint(id: log.logID, time: log.loggedAt, level: runningTotal,
                                  tint: log.category.tint, symbol: log.category.symbol)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("TODAY")
                        .font(.caption.bold())
                        .tracking(1.2)
                        .foregroundStyle(SippedTheme.secondaryInk)
                    totalsGrid
                    if logs.isEmpty {
                        emptyState
                    } else {
                        MeasureSelector(selection: Binding(get: { preferences.selectedMeasure }, set: { preferences.selectedMeasure = $0; try? modelContext.save() }))
                        graph
                        SippedSectionHeading(eyebrow: nil, title: "Drinks", trailing: "\(logs.count)")
                        LazyVStack(spacing: 10) {
                            ForEach(logs.reversed()) { log in Button { selectedLog = log } label: { LogEntryRow(log: log, preferences: preferences) }.buttonStyle(.plain) }
                        }
                    }
                }.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, SippedLayout.floatingChromeContentClearance, for: .scrollContent)
            .background(SippedTheme.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selectedLog) { EntryDetailView(log: $0, preferences: preferences, onDelete: delete) }
            .overlay(alignment: .bottom) { if deletedSnapshot != nil { UndoBanner(action: undo).padding(.bottom, 4) } }
        }
    }

    private var totalsGrid: some View {
        Group {
            if dynamicTypeSize >= .accessibility1 {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(MeasureKind.allCases) { measure in
                        totalMetric(for: measure)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(MeasureKind.allCases) { measure in
                        totalMetric(for: measure)
                    }
                }
            }
        }
    }

    private func totalMetric(for measure: MeasureKind) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SippedAnimatedNumericText(
                text: totalCardValue(for: measure)
            )
                .font(.title3.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            Text(measure.name.uppercased())
                .font(.caption2.bold())
                .tracking(0.8)
                .foregroundStyle(measure.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(measure.name), \(DisplayFormatter.value(totals.value(for: measure), measure: measure, units: preferences.units))"
        )
        .accessibilityIdentifier("today.total.\(measure.rawValue)")
    }

    private func totalCardValue(for measure: MeasureKind) -> String {
        let value = totals.value(for: measure)
        if measure == .alcohol {
            return value.formatted(.number.precision(.fractionLength(2)))
        }
        return DisplayFormatter.value(value, measure: measure, units: preferences.units)
    }

    private var graph: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(preferences.selectedMeasure.name) by drink", systemImage: preferences.selectedMeasure.symbol).font(.headline).foregroundStyle(preferences.selectedMeasure.color)
                Spacer()
                SippedAnimatedNumericText(
                    text: DisplayFormatter.value(
                        totals.value(for: preferences.selectedMeasure),
                        measure: preferences.selectedMeasure,
                        units: preferences.units
                    )
                )
                    .font(.subheadline.bold())
            }
            Group {
                if graphPoints.isEmpty {
                    ContentUnavailableView("No \(preferences.selectedMeasure.name.lowercased()) contributions", systemImage: preferences.selectedMeasure.symbol)
                        .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    ReservoirGraph(points: graphPoints, now: environment.now,
                                   color: preferences.selectedMeasure.color,
                                   valueLabel: { DisplayFormatter.value($0, measure: preferences.selectedMeasure, units: preferences.units) })
                    .frame(height: 170)
                    .accessibilityIdentifier("today.graph.\(preferences.selectedMeasure.rawValue)")
                }
            }
            .id(preferences.selectedMeasure)
            .sippedBlurReplaceTransition()
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: MeasureKind
    var body: some View {
        HStack(spacing: 4) {
            ForEach(MeasureKind.allCases) { measure in
                Button {
                    withAnimation(reduceMotion ? SippedMotion.reduced : SippedMotion.element) {
                        selection = measure
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: measure.symbol).font(.caption)
                        Text(measure.name).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.65)
                    }
                        .foregroundStyle(selection == measure ? measure.selectedForegroundColor : SippedTheme.secondaryInk)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(selection == measure ? measure.color : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("measure.\(measure.rawValue)")
            }
        }
        .padding(4)
        .background(SippedTheme.surface, in: Capsule())
    }
}
