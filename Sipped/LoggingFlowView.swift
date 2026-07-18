import SwiftData
import SwiftUI

private enum LoggingStage: Int {
    case drink
    case container
    case amount
}

private enum LoggingDirection {
    case forward
    case backward
}

private enum DrinkLoggerFilter: Hashable {
    case all
    case recent
    case saved
    case category(DrinkCategory)
}

private enum ContainerLoggerFilter: String, CaseIterable, Identifiable {
    case compatible = "For this drink"
    case saved = "My containers"
    case all = "All"

    var id: String { rawValue }
}

struct LoggingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \DrinkDefinition.name) private var drinks: [DrinkDefinition]
    @Query(sort: \DrinkLog.loggedAt, order: .reverse) private var logs: [DrinkLog]
    @Query(sort: \ContainerDefinition.name) private var containers: [ContainerDefinition]
    @Query private var usages: [DrinkUsagePreference]
    @Bindable var preferences: UserPreferences
    let environment: AppEnvironment

    @State private var stage: LoggingStage = .drink
    @State private var direction: LoggingDirection = .forward
    @State private var selectedDrink: DrinkDefinition?
    @State private var selectedContainer: ContainerDefinition?
    @State private var amountSession = UUID()
    @State private var showingCustomDrink = false
    @State private var showingCustomContainer = false
    @State private var drinkSearch = ""
    @State private var drinkSearchPresented = false
    @State private var drinkFilter: DrinkLoggerFilter = .all
    @State private var containerFilter: ContainerLoggerFilter = .compatible

    var body: some View {
        NavigationStack {
            Group {
                switch stage {
                case .drink:
                    DrinkStageView(
                        drinks: drinks,
                        logs: logs,
                        preferences: preferences,
                        search: $drinkSearch,
                        searchPresented: $drinkSearchPresented,
                        filter: $drinkFilter,
                        close: { dismiss() },
                        createDrink: { showingCustomDrink = true },
                        select: selectDrink
                    )
                case .container:
                    if let selectedDrink {
                        ContainerStageView(
                            containers: containers,
                            drink: selectedDrink,
                            rememberedContainerID: rememberedContainerID(for: selectedDrink),
                            selectedID: selectedContainer?.containerID,
                            units: preferences.units,
                            filter: $containerFilter,
                            back: backToDrinks,
                            createContainer: { showingCustomContainer = true },
                            select: selectContainer
                        )
                    }
                case .amount:
                    if let selectedDrink, let selectedContainer {
                        AmountStageView(
                            drink: selectedDrink,
                            container: selectedContainer,
                            preferences: preferences,
                            environment: environment,
                            back: { move(to: .container, direction: .backward) },
                            completion: { dismiss() }
                        )
                        .id(amountSession)
                    }
                }
            }
            .id(stage)
            .transition(stageTransition)
            .toolbar(.hidden, for: .navigationBar)
            .background(SippedTheme.canvas)
            .sheet(isPresented: $showingCustomDrink) { CustomDrinkForm() }
            .sheet(isPresented: $showingCustomContainer) { CustomContainerForm() }
        }
        .task(openDeepLinkedDrink)
    }

    private var stageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let insertion: Edge = direction == .forward ? .trailing : .leading
        let removal: Edge = direction == .forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertion).combined(with: .opacity),
            removal: .move(edge: removal).combined(with: .opacity)
        )
    }

    private func selectDrink(_ drink: DrinkDefinition) {
        selectedDrink = drink
        selectedContainer = nil
        containerFilter = .compatible
        move(to: .container, direction: .forward)
    }

    private func selectContainer(_ container: ContainerDefinition) {
        selectedContainer = container
        amountSession = UUID()
        move(to: .amount, direction: .forward)
    }

    private func backToDrinks() {
        selectedDrink = nil
        selectedContainer = nil
        move(to: .drink, direction: .backward)
    }

    private func move(to newStage: LoggingStage, direction newDirection: LoggingDirection) {
        direction = newDirection
        let animation: Animation = reduceMotion
            ? .easeInOut(duration: 0.18)
            : .spring(response: 0.40, dampingFraction: 0.90)
        withAnimation(animation) { stage = newStage }
    }

    private func rememberedContainerID(for drink: DrinkDefinition) -> String? {
        usages.first { $0.definitionID == drink.definitionID }?.lastContainerID
    }

    private func openDeepLinkedDrink() async {
        guard stage == .drink,
              let requestedID = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--open-drink=") })
                .flatMap({ $0.split(separator: "=", maxSplits: 1).last.map(String.init) }),
              let drink = drinks.first(where: { $0.definitionID == requestedID })
        else { return }
        selectedDrink = drink
        containerFilter = .compatible
        stage = .container
    }
}

private struct DrinkStageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let drinks: [DrinkDefinition]
    let logs: [DrinkLog]
    @Bindable var preferences: UserPreferences
    @Binding var search: String
    @Binding var searchPresented: Bool
    @Binding var filter: DrinkLoggerFilter
    let close: () -> Void
    let createDrink: () -> Void
    let select: (DrinkDefinition) -> Void
    @FocusState private var searchFocused: Bool

    private var orderedCategories: [DrinkCategory] {
        preferences.preferredCategories + DrinkCategory.allCases.filter { !preferences.preferredCategories.contains($0) }
    }

    private var recentIDs: [String] {
        var seen = Set<String>()
        return logs.compactMap(\.sourceDefinitionID).filter { seen.insert($0).inserted }
    }

    private var filtered: [DrinkDefinition] {
        let recent = Set(recentIDs)
        return drinks.filter { drink in
            let matchesSearch = search.isEmpty
                || drink.name.localizedCaseInsensitiveContains(search)
                || drink.category.name.localizedCaseInsensitiveContains(search)
            guard matchesSearch else { return false }
            switch filter {
            case .all: return true
            case .recent: return recent.contains(drink.definitionID)
            case .saved: return !drink.isBuiltIn
            case let .category(category): return drink.category == category
            }
        }
        .sorted(by: comesBefore)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if searchPresented {
                SippedSearchField(prompt: "Search all drinks", text: $search)
                    .focused($searchFocused)
                    .accessibilityIdentifier("logger.search")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    filterButton("All", symbol: "square.grid.2x2", value: .all, id: "all")
                    filterButton("Recents", symbol: "clock", value: .recent, id: "recent")
                    filterButton("My Drinks", symbol: "bookmark", value: .saved, id: "saved")
                    ForEach(orderedCategories) { category in
                        filterButton(
                            category.name,
                            symbol: category.symbol,
                            value: .category(category),
                            id: category.rawValue,
                            tint: category.tint,
                            selectedForeground: .white
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 14)

            ScrollView {
                if filtered.isEmpty {
                    emptyState
                } else {
                    DrinkCardGrid(drinks: filtered, action: select)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(SippedTheme.canvas)
        .onChange(of: searchPresented) { _, presented in
            if presented { searchFocused = true }
            else { search = ""; searchFocused = false }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(SippedTheme.surface, in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Close")
            .accessibilityIdentifier("logger.close")

            VStack(alignment: .leading, spacing: 4) {
                Text("Choose a drink")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("What would you like to log?")
                    .font(.subheadline)
                    .foregroundStyle(SippedTheme.secondaryInk)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Button {
                    let animation: Animation? = reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.30, dampingFraction: 0.90)
                    withAnimation(animation) { searchPresented.toggle() }
                } label: {
                    Image(systemName: searchPresented ? "xmark" : "magnifyingglass")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(searchPresented ? "Close search" : "Search drinks")
                .accessibilityIdentifier("logger.searchToggle")

                Button(action: createDrink) {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Create custom drink")
                .accessibilityIdentifier("logger.newDrink")
            }
            .buttonStyle(PressScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    private func filterButton(
        _ title: String,
        symbol: String?,
        value: DrinkLoggerFilter,
        id: String,
        tint: Color = SippedTheme.chromeAccent,
        selectedForeground: Color = SippedTheme.onChromeAccent
    ) -> some View {
        Button { filter = value } label: {
            SippedChip(
                title: title,
                symbol: symbol,
                selected: filter == value,
                tint: tint,
                selectedForeground: selectedForeground
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(filter == value ? .isSelected : [])
        .accessibilityIdentifier("logger.filter.\(id)")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: search.isEmpty ? "drop" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(SippedTheme.secondaryInk)
            Text(search.isEmpty ? "Nothing here yet" : "No drinks found")
                .font(.title3.bold())
            Text(search.isEmpty ? "Create a drink to add it to your library." : "Try another name or filter.")
                .font(.subheadline)
                .foregroundStyle(SippedTheme.secondaryInk)
                .multilineTextAlignment(.center)
            if search.isEmpty && filter == .saved {
                Button("New Drink", action: createDrink)
                    .buttonStyle(SippedPrimaryButtonStyle())
                    .frame(maxWidth: 220)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding(24)
    }

    private func comesBefore(_ lhs: DrinkDefinition, _ rhs: DrinkDefinition) -> Bool {
        if filter == .all && search.isEmpty {
            let lhsRecent = recentIDs.firstIndex(of: lhs.definitionID)
            let rhsRecent = recentIDs.firstIndex(of: rhs.definitionID)
            if lhsRecent != nil || rhsRecent != nil {
                return (lhsRecent ?? .max) < (rhsRecent ?? .max)
            }
            if lhs.isBuiltIn != rhs.isBuiltIn { return !lhs.isBuiltIn }
        }
        let lhsCategory = orderedCategories.firstIndex(of: lhs.category) ?? .max
        let rhsCategory = orderedCategories.firstIndex(of: rhs.category) ?? .max
        return lhsCategory == rhsCategory ? lhs.name < rhs.name : lhsCategory < rhsCategory
    }
}

private struct ContainerStageView: View {
    let containers: [ContainerDefinition]
    let drink: DrinkDefinition
    let rememberedContainerID: String?
    let selectedID: String?
    let units: DisplayUnits
    @Binding var filter: ContainerLoggerFilter
    let back: () -> Void
    let createContainer: () -> Void
    let select: (ContainerDefinition) -> Void

    private var liquidColor: Color {
        DrinkArtwork(category: drink.category, artworkID: drink.artworkID, definitionID: drink.definitionID).liquidColor
    }

    private var validRememberedID: String? {
        guard let rememberedContainerID,
              containers.contains(where: { $0.containerID == rememberedContainerID && $0.supports(drink.category) })
        else { return nil }
        return rememberedContainerID
    }

    private var filtered: [ContainerDefinition] {
        containers.filter { container in
            switch filter {
            case .compatible: container.supports(drink.category)
            case .saved: !container.isBuiltIn && container.supports(drink.category)
            case .all: true
            }
        }
        .sorted { lhs, rhs in
            if lhs.containerID == validRememberedID { return true }
            if rhs.containerID == validRememberedID { return false }
            if lhs.isBuiltIn != rhs.isBuiltIn { return !lhs.isBuiltIn }
            if lhs.capacityML != rhs.capacityML { return lhs.capacityML < rhs.capacityML }
            return lhs.name < rhs.name
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(ContainerLoggerFilter.allCases) { item in
                        Button { filter = item } label: {
                            SippedChip(
                                title: item.rawValue,
                                symbol: symbol(for: item),
                                selected: filter == item,
                                tint: drink.category.tint,
                                selectedForeground: .white
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(filter == item ? .isSelected : [])
                        .accessibilityIdentifier("logger.containerFilter.\(item == .compatible ? "compatible" : item == .saved ? "saved" : "all")")
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .padding(.bottom, 14)

            ScrollView {
                if filtered.isEmpty {
                    emptyState
                } else {
                    ContainerCardGrid(
                        containers: filtered,
                        action: select,
                        selectedID: selectedID,
                        liquidColor: liquidColor,
                        units: units
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(SippedTheme.canvas)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(SippedTheme.surface, in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Back to drinks")
            .accessibilityIdentifier("logger.back")

            VStack(alignment: .leading, spacing: 4) {
                Text("Choose a container")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("What are you drinking \(drink.name) from?")
                    .font(.subheadline)
                    .foregroundStyle(SippedTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            Button(action: createContainer) {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("New container")
            .accessibilityIdentifier("logger.newContainer")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            VesselArtwork(style: drink.category.defaultArtwork, liquidColor: liquidColor, fillFraction: 0.55)
                .frame(width: 72, height: 110)
            Text(filter == .compatible ? "No compatible containers" : "No containers here yet")
                .font(.title3.bold())
            Text("Create a container with a name, capacity, and suitable drink categories.")
                .font(.subheadline)
                .foregroundStyle(SippedTheme.secondaryInk)
                .multilineTextAlignment(.center)
            Button("New Container", action: createContainer)
                .buttonStyle(SippedPrimaryButtonStyle(tint: drink.category.tint, foreground: actionForeground))
                .accessibilityIdentifier("logger.empty.newContainer")
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding(28)
    }

    private var actionForeground: Color {
        switch drink.category {
        case .water, .energyDrinks, .juice, .beer: .black.opacity(0.82)
        default: .white
        }
    }

    private func symbol(for filter: ContainerLoggerFilter) -> String {
        switch filter {
        case .compatible: "checkmark.circle"
        case .saved: "person.crop.circle"
        case .all: "square.grid.2x2"
        }
    }
}

private struct AmountStageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var usages: [DrinkUsagePreference]
    let drink: DrinkDefinition
    let container: ContainerDefinition
    @Bindable var preferences: UserPreferences
    let environment: AppEnvironment
    let back: () -> Void
    let completion: () -> Void

    @State private var amountML = 0.0
    @State private var snapTrigger = 0
    @State private var lastSnap = -1
    @FocusState private var exactAmountFocused: Bool

    private var capacity: Double { max(0, container.capacityML) }
    private var fraction: Double { capacity > 0 ? amountML / capacity : 0 }
    private var liquidColor: Color {
        DrinkArtwork(category: drink.category, artworkID: drink.artworkID, definitionID: drink.definitionID).liquidColor
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700 || dynamicTypeSize.isAccessibilitySize
            VStack(spacing: compact ? 8 : 12) {
                header

                Spacer(minLength: 4)

                fillVessel
                    .frame(
                        width: min(proxy.size.width * 0.62, compact ? 210 : 280),
                        height: min(proxy.size.height * (compact ? 0.32 : 0.43), compact ? 220 : 330)
                    )
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 2)

                amountValue(compact: compact)

                Spacer(minLength: 2)

                Button(action: logDrink) {
                    Text("Log \(drink.name)")
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(SippedPrimaryButtonStyle(tint: drink.category.tint, foreground: actionForeground))
                .disabled(amountML <= 0)
                .opacity(amountML <= 0 ? 0.42 : 1)
                .accessibilityIdentifier("logger.confirm")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .background(SippedTheme.canvas)
        .sensoryFeedback(.selection, trigger: snapTrigger)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { exactAmountFocused = false }
                    .accessibilityIdentifier("keyboard.done")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: back) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(SippedTheme.surface, in: Circle())
            }
            .buttonStyle(PressScaleButtonStyle())
            .accessibilityLabel("Back to containers")
            .accessibilityIdentifier("logger.back")

            VStack(alignment: .leading, spacing: 4) {
                Text("Set the amount")
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(drink.name) · \(container.name)")
                    .font(.subheadline)
                    .foregroundStyle(SippedTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
    }

    private var fillVessel: some View {
        ZStack {
            VesselArtwork(
                style: container.artworkID,
                liquidColor: liquidColor,
                fillFraction: fraction
            )
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                setFraction(1 - value.location.y / proxy.size.height)
                            }
                    )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amount fill")
        .accessibilityValue("\(DisplayFormatter.volume(amountML, units: preferences.units)), \(Int((fraction * 100).rounded())) percent")
        .accessibilityHint("Swipe up or down to adjust the amount")
        .accessibilityAdjustableAction { direction in
            setFraction(fraction + (direction == .increment ? 0.05 : -0.05))
        }
        .accessibilityIdentifier("amount.fill")
    }

    private func amountValue(compact: Bool) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0", value: exactAmountBinding, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: compact ? 46 : 58, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 96, maxWidth: 210)
                    .fixedSize(horizontal: true, vertical: false)
                    .focused($exactAmountFocused)
                    .accessibilityLabel("Exact amount")
                    .accessibilityIdentifier("amount.exact")
                Text(preferences.units == .metric ? "mL" : "fl oz")
                    .font(.title2.bold())
                    .foregroundStyle(SippedTheme.secondaryInk)
            }
            .contentTransition(.numericText())

            Text("\(Int((fraction * 100).rounded()))%")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(SippedTheme.secondaryInk)
                .accessibilityIdentifier("amount.percentage")
        }
        .accessibilityElement(children: .contain)
    }

    private var exactAmountBinding: Binding<Double> {
        Binding(
            get: { preferences.units == .metric ? amountML : amountML / 29.5735 },
            set: { input in
                let metric = preferences.units == .metric ? input : input * 29.5735
                amountML = max(0, min(capacity, metric))
            }
        )
    }

    private var actionForeground: Color {
        switch drink.category {
        case .water, .energyDrinks, .juice, .beer: .black.opacity(0.82)
        default: .white
        }
    }

    private func setFraction(_ rawFraction: Double) {
        let clamped = max(0, min(1, rawFraction))
        amountML = (capacity * clamped).rounded()
        let current = capacity > 0 ? amountML / capacity : 0
        let snap = [0.25, 0.50, 0.75, 1.0].firstIndex { abs(current - $0) < 0.018 } ?? -1
        if snap >= 0 && snap != lastSnap {
            lastSnap = snap
            snapTrigger += 1
        } else if snap < 0 {
            lastSnap = -1
        }
    }

    private func logDrink() {
        guard amountML > 0, capacity > 0 else { return }
        let values = MeasureCalculator.contributions(
            for: drink,
            volumeML: amountML,
            shots: drink.defaultShots,
            addedSugarServes: 0,
            standard: preferences.alcoholStandard,
            abvOverride: drink.defaultABV
        )
        let log = DrinkLog(
            loggedAt: environment.now,
            orderIndex: environment.now.timeIntervalSinceReferenceDate,
            sourceDefinitionID: drink.definitionID,
            drinkName: drink.name,
            category: drink.category,
            artworkID: drink.artworkID,
            containerID: container.containerID,
            containerName: container.name,
            containerCapacityML: container.capacityML,
            consumedML: amountML,
            caffeineMG: values.caffeineMG,
            inherentSugarG: values.inherentSugarG,
            addedSugarG: values.addedSugarG,
            rawAlcoholML: values.rawAlcoholML,
            alcoholByVolume: drink.defaultABV,
            shots: drink.defaultShots,
            milkType: drink.milkType,
            calculationBasis: drink.basis
        )
        modelContext.insert(log)
        if let usage = usages.first(where: { $0.definitionID == drink.definitionID }) {
            usage.lastContainerID = container.containerID
        } else {
            modelContext.insert(DrinkUsagePreference(definitionID: drink.definitionID, lastContainerID: container.containerID))
        }
        try? modelContext.save()
        completion()
    }
}
