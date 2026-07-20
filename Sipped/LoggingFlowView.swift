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
    @State private var drinkFilter: DrinkLoggerFilter = .all
    @State private var containerFilter: ContainerLoggerFilter = .compatible

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    switch stage {
                    case .drink:
                        DrinkStageView(
                            drinks: drinks,
                            logs: logs,
                            preferences: preferences,
                            search: $drinkSearch,
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar(.hidden, for: .navigationBar)
            .background(SippedTheme.canvas)
            .sheet(isPresented: $showingCustomDrink) { CustomDrinkForm() }
            .sheet(isPresented: $showingCustomContainer) { CustomContainerForm() }
        }
        .task(openDeepLinkedDrink)
    }

    private var stageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return SippedMotion.screenTransition(
            direction: direction == .forward ? .forward : .backward
        )
    }

    private func selectDrink(_ drink: DrinkDefinition) {
        move(to: .container, direction: .forward) {
            selectedDrink = drink
            selectedContainer = nil
            containerFilter = .compatible
        }
    }

    private func selectContainer(_ container: ContainerDefinition) {
        move(to: .amount, direction: .forward) {
            selectedContainer = container
            amountSession = UUID()
        }
    }

    private func backToDrinks() {
        move(to: .drink, direction: .backward) {
            selectedContainer = nil
        }
    }

    private func move(
        to newStage: LoggingStage,
        direction newDirection: LoggingDirection,
        updates: () -> Void = {}
    ) {
        direction = newDirection
        let animation = reduceMotion ? SippedMotion.reduced : SippedMotion.screen
        withAnimation(animation) {
            updates()
            stage = newStage
        }
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
    let drinks: [DrinkDefinition]
    let logs: [DrinkLog]
    @Bindable var preferences: UserPreferences
    @Binding var search: String
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
        ScrollView {
            VStack(spacing: 0) {
                SippedSearchField(prompt: "Search all drinks", text: $search)
                    .focused($searchFocused)
                    .accessibilityIdentifier("logger.search")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

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

                if filtered.isEmpty {
                    emptyState
                } else {
                    DrinkCardGrid(drinks: filtered, action: select)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom) {
            if searchFocused {
                HStack {
                    Spacer()
                    KeyboardDismissButton { searchFocused = false }
                }
                .padding(.trailing, 20)
                .padding(.bottom, 8)
            }
        }
        .background(SippedTheme.canvas)
    }

    private var header: some View {
        LoggerHeader(
            title: "Choose a drink",
            leadingSymbol: "xmark",
            leadingLabel: "Close",
            leadingIdentifier: "logger.close",
            leadingAction: close,
            trailingLabel: "Create custom drink",
            trailingIdentifier: "logger.newDrink",
            trailingAction: createDrink
        )
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
    @State private var search = ""

    private var validRememberedID: String? {
        guard let rememberedContainerID,
              containers.contains(where: { $0.containerID == rememberedContainerID && $0.supports(drink.category) })
        else { return nil }
        return rememberedContainerID
    }

    private var filtered: [ContainerDefinition] {
        containers.filter { container in
            let matchesSearch = search.isEmpty
                || container.name.localizedCaseInsensitiveContains(search)
                || String(Int(container.capacityML)).contains(search)
            guard matchesSearch else { return false }
            return switch filter {
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

    private var visualSpec: DrinkVisualSpec {
        DrinkVisualSpec.profile(definitionID: drink.definitionID, category: drink.category)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SippedSearchField(prompt: "Search containers", text: $search)
                    .accessibilityIdentifier("logger.containerSearch")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

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

                if filtered.isEmpty {
                    emptyState
                } else {
                    ContainerCardGrid(
                        containers: filtered,
                        action: select,
                        selectedID: selectedID,
                        liquidColor: visualSpec.liquid,
                        surfaceBand: visualSpec.band,
                        showsParticles: visualSpec.isCarbonated,
                        particleSeed: drink.definitionID,
                        tint: drink.category.tint,
                        units: units
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .background(SippedTheme.canvas)
    }

    private var header: some View {
        LoggerHeader(
            title: "Choose a container",
            leadingSymbol: "chevron.left",
            leadingLabel: "Back to drinks",
            leadingIdentifier: "logger.back",
            leadingAction: back,
            trailingLabel: "New container",
            trailingIdentifier: "logger.newContainer",
            trailingAction: createContainer
        )
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            VesselArtwork(
                style: drink.category.defaultArtwork,
                liquidColor: visualSpec.liquid,
                fillFraction: 0.55,
                showDetails: true,
                surfaceBand: visualSpec.band,
                showsParticles: visualSpec.isCarbonated,
                particleSeed: "\(drink.definitionID)-empty"
            )
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

private struct LoggerHeader: View {
    let title: String
    let leadingSymbol: String
    let leadingLabel: String
    let leadingIdentifier: String
    let leadingAction: () -> Void
    let trailingLabel: String
    let trailingIdentifier: String
    let trailingAction: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 52)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("logger.header")

            HStack {
                headerButton(
                    symbol: leadingSymbol,
                    label: leadingLabel,
                    identifier: leadingIdentifier,
                    action: leadingAction
                )
                Spacer(minLength: 0)
                headerButton(
                    symbol: "plus",
                    label: trailingLabel,
                    identifier: trailingIdentifier,
                    action: trailingAction
                )
            }
        }
        .padding(6)
        .glassEffect(
            .regular.tint(.gray.opacity(0.24)),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SippedTheme.line, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private func headerButton(
        symbol: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(.white.opacity(0.001))
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

private struct AmountStageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var usages: [DrinkUsagePreference]
    let drink: DrinkDefinition
    let container: ContainerDefinition
    @Bindable var preferences: UserPreferences
    let environment: AppEnvironment
    let back: () -> Void
    let completion: () -> Void

    private var visualSpec: DrinkVisualSpec {
        DrinkVisualSpec.profile(definitionID: drink.definitionID, category: drink.category)
    }

    var body: some View {
        AmountFillView(
            artworkID: container.artworkID,
            visualSpec: visualSpec,
            capacityML: container.capacityML,
            initialAmountML: 0,
            confirmationTitle: "Log \(drink.name)",
            confirmationIdentifier: "logger.confirm",
            backLabel: "Back to containers",
            backIdentifier: "logger.back",
            back: back,
            confirm: logDrink
        )
    }

    private func logDrink(amountML: Double) {
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

    private var capacity: Double { max(0, container.capacityML) }
}

struct AmountFillView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let artworkID: String
    let visualSpec: DrinkVisualSpec
    let capacityML: Double
    let confirmationTitle: String
    let confirmationIdentifier: String
    let backLabel: String
    let backIdentifier: String
    let back: () -> Void
    let confirm: (Double) -> Void

    @State private var amountML: Double
    @State private var snapTrigger = 0
    @State private var lastSnap = -1
    @State private var editingExactAmount = false
    @FocusState private var exactAmountFocused: Bool

    init(
        artworkID: String,
        visualSpec: DrinkVisualSpec,
        capacityML: Double,
        initialAmountML: Double,
        confirmationTitle: String,
        confirmationIdentifier: String,
        backLabel: String,
        backIdentifier: String,
        back: @escaping () -> Void,
        confirm: @escaping (Double) -> Void
    ) {
        self.artworkID = artworkID
        self.visualSpec = visualSpec
        self.capacityML = max(0, capacityML)
        self.confirmationTitle = confirmationTitle
        self.confirmationIdentifier = confirmationIdentifier
        self.backLabel = backLabel
        self.backIdentifier = backIdentifier
        self.back = back
        self.confirm = confirm
        _amountML = State(initialValue: min(max(0, capacityML), max(0, initialAmountML)))
    }

    private var capacity: Double { max(0, capacityML) }
    private var fraction: Double { FillAmountMath.fraction(forMillilitres: amountML, capacityML: capacity) }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700 || dynamicTypeSize.isAccessibilitySize
            VStack(spacing: 0) {
                header

                VStack(spacing: compact ? 6 : 12) {
                    fillVessel
                        .frame(
                            width: min(proxy.size.width * 0.82, compact ? 260 : 320),
                            height: min(proxy.size.height * (compact ? 0.38 : 0.43), compact ? 280 : 350)
                        )
                        .frame(maxWidth: .infinity)

                    amountValue(compact: compact)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: compact ? 0 : 24)

                Button { confirm(amountML) } label: {
                    Text(confirmationTitle)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(SippedPrimaryButtonStyle(tint: visualSpec.liquid, foreground: actionForeground))
                .disabled(amountML <= 0)
                .opacity(amountML <= 0 ? 0.42 : 1)
                .accessibilityIdentifier(confirmationIdentifier)
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
                Button("Done") {
                    exactAmountFocused = false
                    editingExactAmount = false
                }
                .accessibilityIdentifier("keyboard.done")
            }
        }
    }

    private var header: some View {
        Button(action: back) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(SippedTheme.surface, in: Circle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(backLabel)
        .accessibilityIdentifier(backIdentifier)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fillVessel: some View {
        ZStack {
            VesselArtwork(
                style: artworkID,
                liquidColor: visualSpec.liquid,
                fillFraction: fraction,
                showDetails: true,
                surfaceBand: visualSpec.band,
                showsParticles: visualSpec.isCarbonated,
                particleSeed: "amount-\(artworkID)",
                fit: .visibleBounds
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
        .accessibilityValue("\(Int(amountML.rounded())) millilitres, \(Int((fraction * 100).rounded())) percent")
        .accessibilityHint("Swipe up or down to adjust the amount")
        .accessibilityAdjustableAction { direction in
            setFraction(fraction + (direction == .increment ? 0.05 : -0.05))
        }
        .accessibilityIdentifier("amount.fill")
    }

    private func amountValue(compact: Bool) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if editingExactAmount {
                    TextField("0", value: exactAmountBinding, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: compact ? 46 : 58, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 96, maxWidth: 210)
                        .fixedSize(horizontal: true, vertical: false)
                        .focused($exactAmountFocused)
                        .accessibilityLabel("Exact amount in millilitres")
                        .accessibilityIdentifier("amount.input")
                } else {
                    Button {
                        editingExactAmount = true
                        Task { @MainActor in
                            await Task.yield()
                            exactAmountFocused = true
                        }
                    } label: {
                        SippedAnimatedNumericText(text: Int(amountML.rounded()).formatted())
                            .font(.system(size: compact ? 46 : 58, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Int(amountML.rounded())) millilitres. Edit exact amount")
                    .accessibilityIdentifier("amount.exact")
                }
                Text("mL")
                    .font(.title2.bold())
                    .foregroundStyle(SippedTheme.secondaryInk)
            }

            SippedAnimatedNumericText(text: "\(Int((fraction * 100).rounded()))%")
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(SippedTheme.secondaryInk)
                .accessibilityIdentifier("amount.percentage")
        }
        .accessibilityElement(children: .contain)
    }

    private var exactAmountBinding: Binding<Double> {
        Binding(get: { amountML }, set: { setAmount($0) })
    }

    private var actionForeground: Color {
        visualSpec.prefersDarkText ? .black.opacity(0.82) : .white
    }

    private func setFraction(_ rawFraction: Double) {
        setAmount(FillAmountMath.millilitres(for: rawFraction, capacityML: capacity).rounded())
    }

    private func setAmount(_ rawAmount: Double) {
        amountML = min(capacity, max(0, rawAmount.isFinite ? rawAmount : 0))
        let snap = FillAmountMath.snapIndex(for: fraction) ?? -1
        if snap >= 0 && snap != lastSnap {
            lastSnap = snap
            snapTrigger += 1
        } else if snap < 0 {
            lastSnap = -1
        }
    }
}
