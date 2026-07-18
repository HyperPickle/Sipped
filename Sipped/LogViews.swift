import SwiftData
import SwiftUI

struct LogSnapshot {
    let logID: String
    let loggedAt: Date
    let orderIndex: Double
    let sourceDefinitionID: String?
    let drinkName: String
    let category: DrinkCategory
    let artworkID: String
    let containerID: String?
    let containerName: String
    let containerCapacityML: Double
    let consumedML: Double
    let caffeineMG: Double
    let inherentSugarG: Double
    let addedSugarG: Double
    let rawAlcoholML: Double
    let alcoholByVolume: Double
    let shots: Int
    let milkType: String
    let calculationBasis: String

    init(_ log: DrinkLog) {
        logID = log.logID; loggedAt = log.loggedAt; orderIndex = log.orderIndex
        sourceDefinitionID = log.sourceDefinitionID; drinkName = log.drinkName; category = log.category
        artworkID = log.artworkID; containerID = log.containerID; containerName = log.containerName
        containerCapacityML = log.containerCapacityML; consumedML = log.consumedML; caffeineMG = log.caffeineMG
        inherentSugarG = log.inherentSugarG; addedSugarG = log.addedSugarG; rawAlcoholML = log.rawAlcoholML
        alcoholByVolume = log.alcoholByVolume; shots = log.shots; milkType = log.milkType; calculationBasis = log.calculationBasis
    }

    func restoredLog() -> DrinkLog {
        DrinkLog(logID: logID, loggedAt: loggedAt, orderIndex: orderIndex, sourceDefinitionID: sourceDefinitionID,
                 drinkName: drinkName, category: category, artworkID: artworkID, containerID: containerID,
                 containerName: containerName, containerCapacityML: containerCapacityML, consumedML: consumedML,
                 caffeineMG: caffeineMG, inherentSugarG: inherentSugarG, addedSugarG: addedSugarG,
                 rawAlcoholML: rawAlcoholML, alcoholByVolume: alcoholByVolume, shots: shots,
                 milkType: milkType, calculationBasis: calculationBasis)
    }
}

struct LogEntryRow: View {
    let log: DrinkLog
    let preferences: UserPreferences

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(log.category.tint.opacity(0.13)).frame(width: 56, height: 64)
                DrinkArtwork(category: log.category, artworkID: log.artworkID, definitionID: log.sourceDefinitionID).frame(width: 34, height: 48)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(log.drinkName).font(.headline).lineLimit(2)
                Text("\(DisplayFormatter.volume(log.consumedML, units: preferences.units)) • \(log.containerName)")
                    .font(.subheadline).foregroundStyle(SippedTheme.secondaryInk).lineLimit(1)
                HStack(spacing: 10) {
                    if log.caffeineMG > 0 { miniMetric(.caffeine, log.caffeineMG) }
                    if log.sugarG > 0 { miniMetric(.sugar, log.sugarG) }
                    if log.alcoholByVolume > 0 { miniMetric(.alcohol, log.standardDrinks(using: preferences.alcoholStandard)) }
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(SippedTheme.secondaryInk)
        }
        .sippedCard(padding: 11)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("log.\(log.logID)")
    }

    private func miniMetric(_ measure: MeasureKind, _ value: Double) -> some View {
        Label(DisplayFormatter.value(value, measure: measure, units: preferences.units), systemImage: measure.symbol)
            .font(.caption2.weight(.semibold)).foregroundStyle(measure.color).lineLimit(1)
    }
}

struct EntryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let log: DrinkLog
    @Bindable var preferences: UserPreferences
    let onDelete: (DrinkLog) -> Void
    @State private var editing = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        DrinkArtwork(category: log.category, artworkID: log.artworkID, definitionID: log.sourceDefinitionID)
                            .frame(height: 148)
                        Text(DisplayFormatter.volume(log.consumedML, units: preferences.units))
                            .font(.title2.bold().monospacedDigit())
                        Text(log.containerName).font(.subheadline).foregroundStyle(SippedTheme.secondaryInk)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity)
                    .background(log.category.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    VStack(spacing: 12) {
                        detail("Amount", DisplayFormatter.volume(log.consumedML, units: preferences.units))
                            .accessibilityIdentifier("entry.detail.amount")
                        detail("Container", "\(log.containerName) • \(DisplayFormatter.volume(log.containerCapacityML, units: preferences.units))")
                        detail("Fluid", DisplayFormatter.volume(log.consumedML, units: preferences.units))
                        detail("Caffeine", "\(log.caffeineMG.formatted(.number.precision(.fractionLength(0...1)))) mg")
                        detail("Inherent sugar", "\(log.inherentSugarG.formatted(.number.precision(.fractionLength(0...1)))) g")
                        detail("Added sugar", "\(log.addedSugarG.formatted(.number.precision(.fractionLength(0...1)))) g")
                        detail("Total sugar", "\(log.sugarG.formatted(.number.precision(.fractionLength(0...1)))) g")
                        if log.alcoholByVolume > 0 {
                            detail("Alcohol", "\(log.standardDrinks(using: preferences.alcoholStandard).formatted(.number.precision(.fractionLength(2)))) standard drinks")
                            detail("Raw inputs", "\(log.alcoholByVolume.formatted())% ABV • \(log.rawAlcoholML.formatted(.number.precision(.fractionLength(1)))) mL alcohol")
                        }
                        if log.shots > 0 && log.category == .coffee { detail("Coffee", "\(log.shots) shot\(log.shots == 1 ? "" : "s")\(log.milkType.isEmpty ? "" : " • \(log.milkType)")") }
                    }.sippedCard()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimate basis").font(.headline)
                        Text(log.calculationBasis).font(.subheadline).foregroundStyle(SippedTheme.secondaryInk).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading).sippedCard()
                    Button("Delete entry", role: .destructive) { confirmDelete = true }.frame(minHeight: 44)
                }.padding(16)
            }
            .background(SippedTheme.canvas)
            .navigationTitle(log.drinkName).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Edit") { editing = true }.accessibilityIdentifier("entry.edit") }
            }
            .sheet(isPresented: $editing) { EditLogView(log: log) }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { dismiss(); onDelete(log) }
            } message: { Text("You can undo immediately from the previous screen.") }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) { Text(title).foregroundStyle(SippedTheme.secondaryInk); Spacer(); Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing) }
            .accessibilityElement(children: .combine)
    }
}

struct EditLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DrinkDefinition.name) private var drinks: [DrinkDefinition]
    @Query(sort: \ContainerDefinition.name) private var containers: [ContainerDefinition]
    @Bindable var log: DrinkLog

    var body: some View {
        NavigationStack {
            Form {
                Section("Beverage") {
                    Picker("Definition", selection: Binding(get: { log.sourceDefinitionID ?? "custom" }, set: applyDrink)) {
                        Text("Custom snapshot").tag("custom")
                        ForEach(drinks) { Text($0.name).tag($0.definitionID) }
                    }
                    TextField("Name", text: $log.drinkName)
                    Picker("Category", selection: Binding(get: { log.category }, set: { log.category = $0 })) {
                        ForEach(DrinkCategory.allCases) { Text($0.name).tag($0) }
                    }
                }.sippedFormRows()
                Section("Container and amount") {
                    Picker("Container", selection: Binding(get: { log.containerID ?? "snapshot" }, set: applyContainer)) {
                        Text(log.containerName).tag("snapshot")
                        ForEach(containers.filter { $0.supports(log.category) }) { Text("\($0.name) (\(Int($0.capacityML)) mL)").tag($0.containerID) }
                    }
                    LabeledContent("Capacity (mL)") { numeric($log.containerCapacityML, id: "entry.capacity") }
                    LabeledContent("Consumed (mL)") { numeric($log.consumedML, id: "entry.consumed") }
                    Slider(value: $log.consumedML, in: 0...max(1, log.containerCapacityML), step: 1) {
                        Text("Consumed amount")
                    }
                    .accessibilityValue("\(Int(log.consumedML)) millilitres")
                    .accessibilityIdentifier("entry.amountSlider")
                }.sippedFormRows()
                Section("Contributions") {
                    LabeledContent("Caffeine (mg)") { numeric($log.caffeineMG, id: "entry.caffeine") }
                    LabeledContent("Inherent sugar (g)") { numeric($log.inherentSugarG, id: "entry.inherentSugar") }
                    LabeledContent("Added sugar (g)") { numeric($log.addedSugarG, id: "entry.addedSugar") }
                    LabeledContent("Alcohol by volume (%)") { numeric($log.alcoholByVolume, id: "entry.abv") }
                }.sippedFormRows()
            }
            .sippedFormCanvas()
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { modelContext.rollback(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { normalizeAndSave() }.accessibilityIdentifier("entry.save") }
            }
        }
    }

    private func numeric(_ binding: Binding<Double>, id: String) -> some View {
        TextField("0", value: binding, format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
            .accessibilityIdentifier(id)
    }

    private func applyDrink(_ id: String) {
        guard let drink = drinks.first(where: { $0.definitionID == id }) else { log.sourceDefinitionID = nil; return }
        log.sourceDefinitionID = drink.definitionID; log.drinkName = drink.name; log.category = drink.category
        log.artworkID = drink.artworkID; log.calculationBasis = drink.basis
        let values = MeasureCalculator.contributions(for: drink, volumeML: log.consumedML, shots: max(1, log.shots), addedSugarServes: Int(log.addedSugarG / 4), standard: .australia)
        log.caffeineMG = values.caffeineMG; log.inherentSugarG = values.inherentSugarG
        log.alcoholByVolume = drink.defaultABV; log.rawAlcoholML = values.rawAlcoholML
    }

    private func applyContainer(_ id: String) {
        guard let container = containers.first(where: { $0.containerID == id }) else { return }
        log.containerID = container.containerID; log.containerName = container.name; log.containerCapacityML = container.capacityML
        log.consumedML = min(log.consumedML, container.capacityML)
    }

    private func normalizeAndSave() {
        log.containerCapacityML = max(0, log.containerCapacityML); log.consumedML = max(0, min(log.consumedML, log.containerCapacityML))
        log.caffeineMG = max(0, log.caffeineMG); log.inherentSugarG = max(0, log.inherentSugarG); log.addedSugarG = max(0, log.addedSugarG)
        log.alcoholByVolume = max(0, min(100, log.alcoholByVolume)); log.rawAlcoholML = log.consumedML * log.alcoholByVolume / 100
        try? modelContext.save(); dismiss()
    }
}

struct UndoBanner: View {
    let action: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "trash").foregroundStyle(.white)
            Text("Entry deleted").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            Spacer()
            Button("Undo", action: action).font(.subheadline.bold()).foregroundStyle(Color(red: 0.55, green: 0.90, blue: 0.77)).frame(minHeight: 44)
                .accessibilityIdentifier("entry.undo")
        }
        .padding(.horizontal, 16).frame(minHeight: 54)
        .background(Color.black.opacity(0.90), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
