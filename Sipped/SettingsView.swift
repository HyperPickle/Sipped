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

                settingsPanel("Alcohol calculation") {
                    HStack(spacing: 12) {
                        Image(systemName: "globe.asia.australia.fill").foregroundStyle(MeasureKind.alcohol.color).frame(width: 24)
                        Text("Regional standard").font(.subheadline.weight(.semibold))
                        Spacer()
                        Picker("Regional standard", selection: Binding(get: { preferences.alcoholStandard }, set: { preferences.alcoholStandard = $0; save() })) {
                            ForEach(AlcoholStandard.allCases) { Text("\($0.name) · \($0.grams.formatted()) g").tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu)
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

                settingsPanel("Privacy") {
                    Label("History stays on this device", systemImage: "iphone.gen3.lock")
                    Divider()
                    Label("No account or network required", systemImage: "wifi.slash")
                }

                Button(role: .destructive) { confirmReset = true } label: {
                    Label("Delete all Sipped data", systemImage: "trash")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityIdentifier("settings.deleteAll")
                Text("Permanently removes history, My Drinks, custom containers, and preferences, then returns to onboarding.")
                    .font(.caption).foregroundStyle(SippedTheme.secondaryInk)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(SippedTheme.canvas)
        .navigationTitle("Settings")
        .confirmationDialog("Delete all local data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Delete All Data", role: .destructive) { resetAll() }.accessibilityIdentifier("settings.confirmDeleteAll")
        } message: { Text("This cannot be undone.") }
    }

    private func settingsPanel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
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
