import SwiftData
import SwiftUI

private enum LibrarySection: String, CaseIterable, Identifiable {
    case drinks = "Drinks"
    case saved = "My Drinks"
    case containers = "Containers"
    var id: String { rawValue }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \DrinkDefinition.name) private var drinks: [DrinkDefinition]
    @Query(sort: \ContainerDefinition.name) private var containers: [ContainerDefinition]
    @Bindable var preferences: UserPreferences
    @Binding var isSearchFocused: Bool
    @State private var section: LibrarySection = .drinks
    @State private var searchText = ""
    @State private var selectedCategory: DrinkCategory?
    @State private var showingCustomDrink = false
    @State private var showingCustomContainer = false
    @State private var selectedDrink: DrinkDefinition?
    @State private var selectedContainer: ContainerDefinition?
    @State private var showingSettings = false
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    librarySections

                    SippedSearchField(prompt: section == .containers ? "Search containers" : "Search drinks", text: $searchText)
                        .focused($searchFieldFocused)
                        .accessibilityIdentifier("library.search")

                    if section != .saved { categoryFilters }

                    Group {
                        switch section {
                        case .drinks:
                            galleryHeader("Drink library", subtitle: "Familiar drinks, ready to log")
                            DrinkCardGrid(drinks: filteredDrinks.filter(\.isBuiltIn)) { selectedDrink = $0 }
                        case .saved:
                            galleryHeader("My Drinks", subtitle: "Your repeat preparations")
                            let saved = filteredDrinks.filter { !$0.isBuiltIn }
                            if saved.isEmpty {
                                emptyState("No saved drinks yet", symbol: "bookmark", action: { showingCustomDrink = true })
                            } else {
                                DrinkCardGrid(drinks: saved) { selectedDrink = $0 }
                            }
                        case .containers:
                            galleryHeader("Container library", subtitle: "Find a vessel by shape or capacity")
                            ForEach(containerGroups, id: \.title) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(group.title)
                                        .font(.headline)
                                    ContainerCardGrid(containers: group.containers) { selectedContainer = $0 }
                                }
                            }
                        }
                    }
                    .id(section)
                    .sippedBlurReplaceTransition()
                    .animation(reduceMotion ? SippedMotion.reduced : SippedMotion.screen, value: section)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .contentMargins(
                .bottom,
                isSearchFocused ? 0 : SippedLayout.floatingChromeContentClearance,
                for: .scrollContent
            )
            .safeAreaInset(edge: .bottom) {
                if searchFieldFocused {
                    HStack {
                        Spacer()
                        KeyboardDismissButton { searchFieldFocused = false }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
                }
            }
            .background(SippedTheme.canvas)
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if section == .containers { showingCustomContainer = true } else { showingCustomDrink = true }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel(section == .containers ? "New custom container" : "New custom drink")
                    .accessibilityIdentifier("library.create")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings").accessibilityIdentifier("settings.open")
                }
            }
            .sheet(isPresented: $showingCustomDrink) { CustomDrinkForm() }
            .sheet(isPresented: $showingCustomContainer) { CustomContainerForm() }
            .sheet(item: $selectedDrink) { DrinkDefinitionDetail(drink: $0) }
            .sheet(item: $selectedContainer) { ContainerDefinitionDetail(container: $0) }
            .sheet(isPresented: $showingSettings) { SettingsSheet(preferences: preferences) }
            .onChange(of: searchFieldFocused) { _, focused in isSearchFocused = focused }
            .onDisappear { isSearchFocused = false }
        }
    }

    private var librarySections: some View {
        Picker("Library section", selection: $section) {
            ForEach(LibrarySection.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: section) {
            searchText = ""
            selectedCategory = nil
        }
        .accessibilityIdentifier("library.section")
    }

    private var orderedCategories: [DrinkCategory] {
        preferences.preferredCategories + DrinkCategory.allCases.filter { !preferences.preferredCategories.contains($0) }
    }

    private var filteredDrinks: [DrinkDefinition] {
        drinks.filter { drink in
            (selectedCategory == nil || drink.category == selectedCategory) &&
            (searchText.isEmpty || drink.name.localizedCaseInsensitiveContains(searchText) || drink.category.name.localizedCaseInsensitiveContains(searchText))
        }.sorted { lhs, rhs in
            let li = orderedCategories.firstIndex(of: lhs.category) ?? .max
            let ri = orderedCategories.firstIndex(of: rhs.category) ?? .max
            return li == ri ? lhs.name < rhs.name : li < ri
        }
    }

    private var filteredContainers: [ContainerDefinition] {
        containers.filter { container in
            (selectedCategory.map(container.supports) ?? true) &&
            (searchText.isEmpty || container.name.localizedCaseInsensitiveContains(searchText) || String(Int(container.capacityML)).contains(searchText))
        }
    }

    private var containerGroups: [(title: String, containers: [ContainerDefinition])] {
        let definitions: [(String, Set<String>)] = [
            ("Everyday", ["glass", "tall-glass", "cup", "ceramic-mug", "party-cup"]),
            ("Coffee", ["espresso-cup", "small-takeaway", "large-takeaway"]),
            ("Hydration", ["small-water-bottle", "water-bottle", "large-bottle", "stanley-bottle", "sports-bottle"]),
            ("Juice & shakes", ["juice-box", "juice-bottle", "shake-cup"]),
            ("Cans & soft drinks", ["slim-can", "standard-can", "tallboy-can", "soft-bottle", "kombucha-bottle"]),
            ("Beer", ["beer-bottle", "beer-schooner", "beer-pint", "beer-stein"]),
            ("Wine", ["wine-standard", "wine-bottle", "champagne-flute"]),
            ("Spirits & cocktails", ["spirit-shot", "lowball-glass", "spirit-highball", "martini-glass"])
        ]
        let builtInIDs = Set(definitions.flatMap { $0.1 })
        var groups = definitions.compactMap { title, ids -> (String, [ContainerDefinition])? in
            let matches = filteredContainers.filter { ids.contains($0.containerID) }
            return matches.isEmpty ? nil : (title, matches)
        }
        let custom = filteredContainers.filter { !builtInIDs.contains($0.containerID) }
        if !custom.isEmpty { groups.append(("My containers", custom)) }
        return groups
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button { selectedCategory = nil } label: {
                    SippedChip(title: "All", symbol: "square.grid.2x2", selected: selectedCategory == nil)
                }.buttonStyle(.plain)
                ForEach(orderedCategories) { category in
                    Button { selectedCategory = selectedCategory == category ? nil : category } label: {
                        SippedChip(title: category.name, symbol: category.symbol,
                                   selected: selectedCategory == category, tint: category.tint,
                                   selectedForeground: .white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library.category.\(category.rawValue)")
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func galleryHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.bold))
            Text(subtitle).font(.subheadline).foregroundStyle(SippedTheme.secondaryInk)
        }
    }

    private func emptyState(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.largeTitle).foregroundStyle(SippedTheme.chromeAccent)
                Text(title).font(.headline)
                Text("Create one").font(.subheadline).foregroundStyle(SippedTheme.chromeAccent)
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .sippedCard()
        }.buttonStyle(.plain)
    }
}

struct DrinkCardGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let drinks: [DrinkDefinition]
    let action: (DrinkDefinition) -> Void
    private var accessibilityLayout: Bool { dynamicTypeSize >= .accessibility1 }
    private var columns: [GridItem] {
        accessibilityLayout
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(drinks) { drink in
                Button { action(drink) } label: {
                    VStack(spacing: 12) {
                        DrinkArtwork(category: drink.category, artworkID: drink.artworkID, definitionID: drink.definitionID)
                            .frame(height: accessibilityLayout ? 190 : 132)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(drink.definitionID == "water-still" ? 0.9 : 1)
                        Text(drink.name)
                            .font(GalleryStyle.titleFont)
                            .multilineTextAlignment(.center)
                            .lineLimit(accessibilityLayout ? 3 : 2)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: accessibilityLayout ? 96 : 44,
                                alignment: .top
                            )
                    }
                    .padding(accessibilityLayout ? 20 : 12)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: accessibilityLayout ? 338 : 212, alignment: .top)
                    .background(drink.category.tint.opacity(0.115), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .sippedBlurReplaceTransition()
                .accessibilityLabel("\(drink.name), \(drink.category.name)")
                .accessibilityIdentifier("drink.\(drink.definitionID)")
            }
        }
        .animation(reduceMotion ? SippedMotion.reduced : SippedMotion.element, value: drinks.map(\.definitionID))
    }
}

struct ContainerCardGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let containers: [ContainerDefinition]
    let action: (ContainerDefinition) -> Void
    var selectedID: String? = nil
    var liquidColor: Color = SippedTheme.containerPreviewLiquid
    var surfaceBand: SurfaceBandSpec? = nil
    var showsParticles = false
    var particleSeed = ""
    var tint: Color? = nil
    var units: DisplayUnits = .metric
    private var accessibilityLayout: Bool { dynamicTypeSize >= .accessibility1 }
    private var columns: [GridItem] {
        accessibilityLayout
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(containers) { container in
                Button { action(container) } label: {
                    VStack(spacing: 10) {
                        VesselArtwork(
                            style: container.artworkID,
                            liquidColor: liquidColor,
                            fillFraction: 0.68,
                            showDetails: surfaceBand != nil,
                            surfaceBand: surfaceBand,
                            showsParticles: showsParticles,
                            particleSeed: "\(particleSeed)-\(container.containerID)"
                        )
                            .frame(height: artworkHeight(for: container))
                            .frame(height: accessibilityLayout ? 190 : 136, alignment: .bottom)
                        VStack(spacing: 4) {
                            Text(container.name)
                                .font(GalleryStyle.titleFont)
                                .multilineTextAlignment(.center)
                                .lineLimit(accessibilityLayout ? 3 : 2)
                                .frame(maxWidth: .infinity)
                            Text(DisplayFormatter.volume(container.capacityML, units: units))
                                .font(GalleryStyle.capacityFont)
                                .foregroundStyle(cardTint)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(
                            maxWidth: .infinity,
                            minHeight: accessibilityLayout ? 112 : 64,
                            alignment: .top
                        )
                    }
                    .padding(accessibilityLayout ? 20 : 12)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: accessibilityLayout ? 352 : 234, alignment: .top)
                    .background(selectedID == container.containerID ? cardTint.opacity(0.15) : SippedTheme.surface,
                                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        if selectedID == container.containerID {
                            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(cardTint, lineWidth: 2)
                        }
                    }
                }
                .buttonStyle(PressScaleButtonStyle())
                .sippedBlurReplaceTransition()
                .accessibilityLabel("\(container.name), \(DisplayFormatter.volume(container.capacityML, units: units))")
                .accessibilityIdentifier("container.\(container.containerID)")
            }
        }
        .animation(reduceMotion ? SippedMotion.reduced : SippedMotion.element, value: containers.map(\.containerID))
    }

    private var cardTint: Color { tint ?? liquidColor }

    private func artworkHeight(for container: ContainerDefinition) -> CGFloat {
        let normalized = sqrt(min(max(container.capacityML, 0), 1_180) / 1_180)
        let scale = 0.68 + normalized * 0.32
        return (accessibilityLayout ? 190 : 136) * scale
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct DrinkDefinitionDetail: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let drink: DrinkDefinition
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DrinkArtwork(category: drink.category, artworkID: drink.artworkID, definitionID: drink.definitionID)
                        .frame(height: 180)
                        .padding(22)
                        .frame(maxWidth: .infinity)
                        .background(drink.category.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    VStack(alignment: .leading, spacing: 12) {
                        Label(drink.category.name, systemImage: drink.category.symbol).foregroundStyle(drink.category.tint)
                        Text(drink.basis).font(.body).fixedSize(horizontal: false, vertical: true)
                        Divider()
                        contribution("Caffeine", value: drink.caffeinePerShot > 0 ? "\(drink.caffeinePerShot.formatted()) mg per shot" : "\(drink.caffeinePer100ML.formatted()) mg / 100 mL")
                        contribution("Sugar", value: "\(drink.sugarPer100ML.formatted()) g / 100 mL")
                        if drink.category == .coffee { contribution("Added sugar", value: "4 g per teaspoon or sachet") }
                        if drink.defaultABV > 0 { contribution("Alcohol", value: "\(drink.defaultABV.formatted())% ABV") }
                    }.sippedCard()
                    if !drink.isBuiltIn {
                        Button("Delete My Drink", role: .destructive) { confirmDelete = true }
                            .frame(minHeight: 44).accessibilityIdentifier("myDrink.delete")
                    }
                }.padding()
            }
            .scrollIndicators(.hidden)
            .background(SippedTheme.canvas)
            .navigationTitle(drink.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete \(drink.name)?", isPresented: $confirmDelete) {
                Button("Delete My Drink", role: .destructive) {
                    dismiss()
                    Task { @MainActor in
                        await Task.yield()
                        modelContext.delete(drink)
                        try? modelContext.save()
                    }
                }
                    .accessibilityIdentifier("myDrink.confirmDelete")
            } message: { Text("Historical logs keep their saved names and values.") }
        }
    }

    private func contribution(_ label: String, value: String) -> some View {
        HStack { Text(label).foregroundStyle(SippedTheme.secondaryInk); Spacer(); Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing) }
    }
}

private struct ContainerDefinitionDetail: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let container: ContainerDefinition
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VesselArtwork(style: container.artworkID, liquidColor: SippedTheme.containerPreviewLiquid, fillFraction: 0.72)
                        .frame(width: 160, height: 230)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(SippedTheme.chromeAccent.opacity(0.085), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    VStack(spacing: 12) {
                        detail("Capacity", DisplayFormatter.volume(container.capacityML, units: .metric))
                        Divider()
                        detail("Shape", container.artworkID.replacingOccurrences(of: "tallGlass", with: "Tall glass").capitalized)
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suitable drinks").font(.caption.weight(.bold)).foregroundStyle(SippedTheme.secondaryInk)
                            FlowLayout(spacing: 7) {
                                ForEach(container.categories.sorted { $0.name < $1.name }) { category in
                                    Label(category.name, systemImage: category.symbol)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(category.tint)
                                        .padding(.horizontal, 10).frame(minHeight: 34)
                                        .background(category.tint.opacity(0.10), in: Capsule())
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.sippedCard()
                    if !container.isBuiltIn { Button("Delete custom container", role: .destructive) { confirmDelete = true }.frame(minHeight: 44) }
                }.padding(16)
            }
            .scrollIndicators(.hidden)
            .background(SippedTheme.canvas)
            .navigationTitle(container.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete \(container.name)?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    dismiss()
                    Task { @MainActor in
                        await Task.yield()
                        modelContext.delete(container)
                        try? modelContext.save()
                    }
                }
            } message: { Text("Historical logs keep their container snapshot.") }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(SippedTheme.secondaryInk)
            Spacer()
            Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
        }
    }
}

struct CustomDrinkForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var category: DrinkCategory = .other
    @State private var caffeine = 0.0
    @State private var sugar = 0.0
    @State private var abv = 0.0
    @State private var milkType = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Drink name", text: $name).accessibilityIdentifier("customDrink.name")
                    Picker("Category", selection: $category) { ForEach(DrinkCategory.allCases) { Text($0.name).tag($0) } }
                }.sippedFormRows()
                Section("Per 100 mL") {
                    LabeledContent("Caffeine (mg)") { TextField("0", value: $caffeine, format: .number).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    LabeledContent("Sugar (g)") { TextField("0", value: $sugar, format: .number).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    if category.isAlcoholic { LabeledContent("Alcohol (ABV %)") { TextField("0", value: $abv, format: .number).multilineTextAlignment(.trailing).keyboardType(.decimalPad) } }
                }.sippedFormRows()
                if category == .coffee { Section("Regular preparation") { TextField("Milk type (optional)", text: $milkType) }.sippedFormRows() }
            }
            .scrollIndicators(.hidden)
            .sippedFormCanvas()
            .navigationTitle("New Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).accessibilityIdentifier("customDrink.save")
                }
            }
        }
    }

    private func save() {
        let basis = "User-entered values: \(caffeine.formatted()) mg caffeine and \(sugar.formatted()) g sugar per 100 mL" + (category.isAlcoholic ? ", \(abv.formatted())% ABV." : ".")
        modelContext.insert(DrinkDefinition(name: name.trimmingCharacters(in: .whitespaces), category: category,
                                            caffeinePer100ML: caffeine, sugarPer100ML: sugar, defaultABV: abv,
                                            milkType: milkType, basis: basis, isBuiltIn: false))
        try? modelContext.save(); dismiss()
    }
}

struct CustomContainerForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var capacity = 350.0
    @State private var style = "glass"
    @State private var categories: Set<DrinkCategory> = [.other]
    private let styles = ["glass", "tallGlass", "mug", "bottle", "can"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Container") {
                    TextField("Name", text: $name).accessibilityIdentifier("customContainer.name")
                    LabeledContent("Capacity (mL)") { TextField("350", value: $capacity, format: .number).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    Picker("Shape", selection: $style) { ForEach(styles, id: \.self) { Text($0.capitalized).tag($0) } }
                }.sippedFormRows()
                Section("Suitable drinks") {
                    ForEach(DrinkCategory.allCases) { category in
                        Toggle(category.name, isOn: Binding(
                            get: { categories.contains(category) },
                            set: { on in
                                if on { categories.insert(category) } else { categories.remove(category) }
                            }
                        ))
                    }
                }.sippedFormRows()
            }
            .scrollIndicators(.hidden)
            .sippedFormCanvas()
            .navigationTitle("New Container")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || capacity <= 0).accessibilityIdentifier("customContainer.save") }
            }
        }
    }

    private func save() {
        modelContext.insert(ContainerDefinition(name: name.trimmingCharacters(in: .whitespaces), capacityML: capacity,
                                                artworkID: style, categories: categories.isEmpty ? [.other] : Array(categories), isBuiltIn: false))
        try? modelContext.save(); dismiss()
    }
}
