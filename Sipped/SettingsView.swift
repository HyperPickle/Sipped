import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var preferences: UserPreferences
    @State private var confirmReset = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                settingsPanel("Display") {
                    settingPicker("Units", symbol: "ruler", selection: Binding(get: { preferences.units }, set: { preferences.units = $0; save() }), values: DisplayUnits.allCases)
                    Divider()
                    settingPicker("Appearance", symbol: "circle.lefthalf.filled", selection: Binding(get: { preferences.appearance }, set: { preferences.appearance = $0; save() }), values: AppearancePreference.allCases)
                }

                settingsPanel("Alcohol calculation", spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe.asia.australia.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(MeasureKind.alcohol.color, in: Circle())
                        Text("Regional standard").font(.subheadline.weight(.semibold))
                        Spacer()
                        Menu {
                            ForEach(AlcoholStandard.allCases) { standard in
                                Button {
                                    preferences.alcoholStandard = standard
                                    save()
                                } label: {
                                    if standard == preferences.alcoholStandard {
                                        Label(alcoholStandardLabel(standard), systemImage: "checkmark")
                                    } else {
                                        Text(alcoholStandardLabel(standard))
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(alcoholStandardLabel(preferences.alcoholStandard))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                    .allowsTightening(true)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2.weight(.semibold))
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .accessibilityIdentifier("settings.alcoholStandard")
                    }
                    Text("Standard drinks are recalculated from stored volume and ABV. Sipped never estimates impairment or driving safety.")
                        .font(.caption).foregroundStyle(SippedTheme.secondaryInk).fixedSize(horizontal: false, vertical: true)
                }

                settingsPanel("Preferred categories") {
                FlowLayout(spacing: 7) {
                    ForEach(DrinkCategory.allCases) { category in
                        Button { toggle(category) } label: {
                            SippedChip(
                                title: category.name,
                                symbol: category.symbol,
                                selected: preferences.preferredCategories.contains(category),
                                tint: category.tint,
                                selectedForeground: .white
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("This changes ordering only. Every category remains searchable.")
                    .font(.caption).foregroundStyle(SippedTheme.secondaryInk)
                }

                Button(role: .destructive) { confirmReset = true } label: {
                    Label("Delete all Sipped data", systemImage: "trash")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityIdentifier("settings.deleteAll")
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(SippedTheme.canvas)
        .navigationTitle("Settings")
        .sheet(isPresented: $confirmReset) {
            DeleteAllDataConfirmation(confirm: resetAll)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func settingsPanel<Content: View>(_ title: String, spacing: CGFloat = 13, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title.uppercased()).font(.caption2.bold()).tracking(1.1).foregroundStyle(SippedTheme.secondaryInk)
            content()
        }
        .padding(16)
        .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func settingPicker<Value: Hashable & Identifiable>(_ title: String, symbol: String, selection: Binding<Value>, values: [Value]) -> some View where Value.ID == String {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(SippedTheme.chromeAccent).frame(width: 24)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Picker(title, selection: selection) {
                ForEach(values) { value in
                    Text(String(describing: value.id).capitalized).tag(value)
                }
            }
            .labelsHidden().pickerStyle(.menu)
        }
    }

    private func toggle(_ category: DrinkCategory) {
        var values = preferences.preferredCategories
        if let index = values.firstIndex(of: category) {
            if values.count > 1 { values.remove(at: index) }
        } else { values.append(category) }
        preferences.preferredCategories = values; save()
    }
    private func save() { try? modelContext.save() }

    private func alcoholStandardLabel(_ standard: AlcoholStandard) -> String {
        "\(standard.name) · \(standard.grams.formatted())g"
    }

    private func resetAll() {
        do {
            for log in try modelContext.fetch(FetchDescriptor<DrinkLog>()) { modelContext.delete(log) }
            for usage in try modelContext.fetch(FetchDescriptor<DrinkUsagePreference>()) { modelContext.delete(usage) }
            for drink in try modelContext.fetch(FetchDescriptor<DrinkDefinition>()) { modelContext.delete(drink) }
            for container in try modelContext.fetch(FetchDescriptor<ContainerDefinition>()) { modelContext.delete(container) }
            for item in try modelContext.fetch(FetchDescriptor<UserPreferences>()) { modelContext.delete(item) }
            try modelContext.save()
            CatalogSeeder.builtInDrinks.forEach(modelContext.insert)
            CatalogSeeder.builtInContainers.forEach(modelContext.insert)
            modelContext.insert(UserPreferences(onboardingComplete: false, alcoholStandard: .inferred(regionCode: Locale.current.region?.identifier)))
            try modelContext.save()
        } catch { assertionFailure("Data reset failed: \(error)") }
    }
}

private struct DeleteAllDataConfirmation: View {
    @Environment(\.dismiss) private var dismiss
    let confirm: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "trash.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                    .frame(width: 52, height: 52)
                    .background(Color.red.opacity(0.10), in: Circle())

                VStack(spacing: 9) {
                    Text("Delete all Sipped data?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text("Your drink history, My Drinks, custom containers, and settings will be permanently deleted. This can’t be undone, and you’ll return to onboarding.")
                        .font(.subheadline)
                        .foregroundStyle(SippedTheme.secondaryInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button(role: .destructive) {
                        dismiss()
                        Task { @MainActor in
                            await Task.yield()
                            confirm()
                        }
                    } label: {
                        Text("Delete all data")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(.white)
                            .background(.red, in: RoundedRectangle(cornerRadius: SippedTheme.controlRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.confirmDeleteAll")

                    Button("Cancel") { dismiss() }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SippedTheme.canvas)
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preferences: UserPreferences

    var body: some View {
        NavigationStack {
            SettingsView(preferences: preferences)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
