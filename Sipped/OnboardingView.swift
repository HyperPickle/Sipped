import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var preferences: UserPreferences
    let goalOnly: Bool
    @State private var showsLanding: Bool
    @State private var page = 0
    @State private var units: DisplayUnits
    @State private var selectedCategories: Set<DrinkCategory>
    @State private var dailyFluidGoalML: Double

    init(preferences: UserPreferences, goalOnly: Bool = false) {
        self.preferences = preferences
        self.goalOnly = goalOnly
        _showsLanding = State(initialValue: !goalOnly)
        _units = State(initialValue: preferences.units)
        _selectedCategories = State(initialValue: Set(preferences.preferredCategories))
        _dailyFluidGoalML = State(initialValue: preferences.validDailyFluidGoalML ?? 0)
    }

    private var stepCount: Int { goalOnly ? 1 : 4 }
    private var isGoalPage: Bool { goalOnly || page == 2 }

    var body: some View {
        Group {
            if showsLanding {
                SippedLandingView {
                    if animationsEnabled {
                        withAnimation(landingHandoffAnimation) { showsLanding = false }
                    } else {
                        showsLanding = false
                    }
                }
                .transition(landingExitTransition)
            } else {
                onboardingFlow
                    .transition(onboardingEntryTransition)
            }
        }
        .animation(animationsEnabled ? landingHandoffAnimation : nil, value: showsLanding)
        .background(SippedTheme.canvas.ignoresSafeArea())
    }

    private var landingHandoffAnimation: Animation {
        .easeInOut(duration: 0.30)
    }

    private var landingExitTransition: AnyTransition {
        guard animationsEnabled else { return .identity }
        return .asymmetric(
            insertion: .opacity,
            removal: .modifier(
                active: SippedBlurTransitionModifier(opacity: 0, blur: 6),
                identity: SippedBlurTransitionModifier()
            )
        )
    }

    private var onboardingEntryTransition: AnyTransition {
        guard animationsEnabled else { return .identity }
        return .asymmetric(insertion: .opacity, removal: .opacity)
    }

    private var onboardingFlow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule().fill(index == page ? SippedTheme.chromeAccent : SippedTheme.line)
                        .frame(width: index == page ? 28 : 8, height: 6)
                }
            }
            .animation(animationsEnabled ? SippedMotion.screen : nil, value: page)
            .padding(.top, 18)
            .accessibilityHidden(true)

            currentPage
                .id(goalOnly ? "goal-only" : page.description)
                .transition(currentPageTransition)

            if !isGoalPage {
                Button(action: advance) {
                    Text("Continue")
                }
                .buttonStyle(SippedPrimaryButtonStyle(font: SippedTypography.onboardingCTA))
                .disabled(page == 3 && selectedCategories.isEmpty)
                .opacity(page == 3 && selectedCategories.isEmpty ? 0.45 : 1)
                .accessibilityIdentifier(page == 3 ? "onboarding.finish" : "onboarding.continue")
                .padding(20)
            }
        }
        .background(SippedTheme.canvas.ignoresSafeArea())
    }

    private var animationsEnabled: Bool {
        !reduceMotion && !ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    private var currentPageTransition: AnyTransition {
        guard animationsEnabled else { return .identity }
        guard isGoalPage else {
            return SippedMotion.screenTransition(direction: .forward)
        }

        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: 24)),
            removal: .opacity.combined(with: .offset(x: -18))
        )
    }

    @ViewBuilder private var currentPage: some View {
        if goalOnly {
            goalPage
        } else {
            switch page {
            case 0: measuresPage
            case 1: unitsPage
            case 2: goalPage
            default: categoriesPage
            }
        }
    }

    private var measuresPage: some View {
        OnboardingPage(title: "See what each drink contains", subtitle: "Sipped records fluid, caffeine, sugar and alcohol separately.") {
            VStack(spacing: 0) {
                ForEach(MeasureKind.allCases) { measure in
                    HStack(spacing: 14) {
                        Image(systemName: measure.symbol).font(.headline).foregroundStyle(measure.color)
                            .frame(width: 44, height: 44).background(measure.color.opacity(0.11), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(measure.name).font(.headline)
                            Text(measureDescription(measure)).font(.subheadline).foregroundStyle(SippedTheme.secondaryInk)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    if measure != MeasureKind.allCases.last { Divider().padding(.leading, 58) }
                }
            }
            .padding(.horizontal, 15)
            .background(SippedTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var unitsPage: some View {
        OnboardingPage(title: "Choose your units", subtitle: "Choose how drink amounts appear. You can change this later in Settings.") {
            VStack(spacing: 12) {
                ForEach(DisplayUnits.allCases) { option in
                    Button { units = option } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option == .metric ? "ruler" : "ruler.fill")
                                .font(.title2).frame(width: 32).foregroundStyle(SippedTheme.chromeAccent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.name).font(.headline)
                                Text(option == .metric ? "Millilitres and litres" : "Fluid ounces")
                                    .font(.subheadline).foregroundStyle(SippedTheme.secondaryInk)
                            }
                            Spacer()
                            Image(systemName: units == option ? "checkmark.circle.fill" : "circle")
                                .font(.title2).foregroundStyle(units == option ? SippedTheme.chromeAccent : SippedTheme.secondaryInk)
                        }
                        .padding(16)
                        .background(units == option ? SippedTheme.chromeAccent.opacity(0.10) : SippedTheme.surface,
                                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            if units == option { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SippedTheme.chromeAccent.opacity(0.4), lineWidth: 1.5) }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("units.\(option.rawValue)")
                }
            }
        }
    }

    private var goalPage: some View {
        DailyFluidGoalSurface(
            goalML: $dailyFluidGoalML,
            units: units,
            actionTitle: "Continue",
            actionIdentifier: "onboarding.continue",
            onSave: advance
        )
    }

    private var categoriesPage: some View {
        OnboardingPage(title: "Choose your drink types", subtitle: "Select at least one. Your choices appear first, but every category remains available.") {
            FlowLayout(spacing: 8) {
                ForEach(DrinkCategory.allCases) { category in
                    Button {
                        if selectedCategories.contains(category) { selectedCategories.remove(category) }
                        else { selectedCategories.insert(category) }
                    } label: {
                        SippedChip(title: category.name, symbol: category.symbol,
                                   selected: selectedCategories.contains(category), tint: category.tint,
                                   selectedForeground: .white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.category.\(category.rawValue)")
                }
            }
        }
    }

    private func advance() {
        if goalOnly || page == 3 {
            guard let goal = DailyFluidGoalMath.validGoal(dailyFluidGoalML) else { return }
            preferences.dailyFluidGoalML = goal
            if !goalOnly {
                preferences.units = units
                preferences.preferredCategories = DrinkCategory.allCases.filter(selectedCategories.contains)
            }
            preferences.onboardingComplete = true
            try? modelContext.save()
            return
        }

        if animationsEnabled { withAnimation(SippedMotion.screen) { page += 1 } }
        else { page += 1 }
    }

    private func measureDescription(_ measure: MeasureKind) -> String {
        switch measure {
        case .fluid: "How much you drank"
        case .caffeine: "Caffeine consumed"
        case .sugar: "Natural and added sugar"
        case .alcohol: "Standard drinks for your region"
        }
    }
}

struct DailyFluidGoalSurface: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var goalML: Double
    let units: DisplayUnits
    let actionTitle: String
    let actionIdentifier: String
    let onSave: () -> Void

    @State private var editingExactAmount = false
    @State private var exactText = ""
    @State private var wheelMajor: Int
    @State private var wheelMinor: Int
    @FocusState private var exactAmountFocused: Bool

    init(goalML: Binding<Double>, units: DisplayUnits, actionTitle: String,
         actionIdentifier: String, onSave: @escaping () -> Void) {
        _goalML = goalML
        self.units = units
        self.actionTitle = actionTitle
        self.actionIdentifier = actionIdentifier
        self.onSave = onSave
        let components = DailyFluidGoalMath.wheelComponents(
            forMillilitres: goalML.wrappedValue,
            units: units
        )
        _wheelMajor = State(initialValue: components.major)
        _wheelMinor = State(initialValue: components.minor)
    }

    private var hasValidGoal: Bool { DailyFluidGoalMath.validGoal(goalML) != nil }
    private var displayedGoal: String { DisplayFormatter.volume(goalML, units: units) }
    private var inputUnit: String { units == .metric ? "ml" : "fl oz" }
    private var majorUnitTitle: String { units == .metric ? "Litres" : "Fluid ounces" }
    private var minorUnitTitle: String { units == .metric ? "Millilitres" : "Tenths" }
    private var majorValues: Range<Int> { units == .metric ? 0..<6 : 0..<170 }
    private var minorValues: Range<Int> { units == .metric ? 0..<20 : 0..<10 }
    private var isMinorWheelEnabled: Bool {
        DailyFluidGoalMath.isMinorWheelEnabled(major: wheelMajor, units: units)
    }
    private var compactInputValue: String {
        let value = DailyFluidGoalMath.displayedValue(forMillilitres: goalML, units: units)
        return units == .metric ? String(Int(value.rounded())) : value.formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SIPPED").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(SippedTheme.chromeAccent)
                        Text("Set a daily fluid goal")
                            .font(.largeTitle.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("History compares your daily fluid total with this amount.")
                            .font(.body)
                            .foregroundStyle(SippedTheme.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                    amountControl
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            Button(action: onSave) {
                Text(actionTitle)
            }
            .buttonStyle(SippedPrimaryButtonStyle(tint: MeasureKind.fluid.color,
                                                   foreground: MeasureKind.fluid.selectedForegroundColor,
                                                   font: SippedTypography.onboardingCTA))
            .disabled(!hasValidGoal)
            .opacity(hasValidGoal ? 1 : 0)
            .allowsHitTesting(hasValidGoal)
            .accessibilityIdentifier(actionIdentifier)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(SippedTheme.canvas.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { commitExactEntry() }
                    .accessibilityIdentifier("keyboard.done")
            }
        }
    }

    @ViewBuilder private var amountControl: some View {
        VStack(spacing: 14) {
            Text("Daily fluid goal")
                .font(.caption.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(SippedTheme.secondaryInk)
                .textCase(.uppercase)

            if editingExactAmount {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("0", text: $exactText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 42 : 58, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 100, maxWidth: 240)
                        .focused($exactAmountFocused)
                        .accessibilityLabel("Exact daily fluid goal in \(inputUnit)")
                        .accessibilityIdentifier("onboarding.goal.input")
                    Text(inputUnit).font(.title2.bold()).foregroundStyle(SippedTheme.secondaryInk)
                }
            } else {
                Button {
                    exactText = compactInputValue
                    editingExactAmount = true
                    Task { @MainActor in
                        await Task.yield()
                        exactAmountFocused = true
                    }
                } label: {
                    Text(displayedGoal)
                        .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 42 : 58, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minHeight: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(displayedGoal). Edit daily fluid goal")
                .accessibilityHint("Swipe up or down to adjust. Double tap to enter an exact amount.")
                .accessibilityAdjustableAction { direction in
                    let step = units == .metric ? DailyFluidGoalMath.metricWheelStepML : DailyFluidGoalMath.millilitresPerFluidOunce / 10
                    let next = goalML + (direction == .increment ? step : -step)
                    goalML = next <= 0 ? 0 : DailyFluidGoalMath.clampedEntry(next)
                    syncWheelsToGoal()
                }
                .accessibilityIdentifier("onboarding.goal.value")

                wheelPicker
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(SippedTheme.canvas.opacity(0.90), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(SippedTheme.line, lineWidth: 1) }
        .onSubmit { commitExactEntry() }
    }

    private var wheelPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(majorUnitTitle)
                Spacer()
                Text(minorUnitTitle)
                    .opacity(isMinorWheelEnabled ? 1 : 0.4)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(SippedTheme.secondaryInk)
            .padding(.horizontal, 34)

            HStack(spacing: 8) {
                Picker(majorUnitTitle, selection: majorSelection) {
                    ForEach(majorValues, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .accessibilityIdentifier("onboarding.goal.major")

                Picker(minorUnitTitle, selection: minorSelection) {
                    ForEach(minorValues, id: \.self) { value in
                        Text(minorLabel(value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .disabled(!isMinorWheelEnabled)
                .opacity(isMinorWheelEnabled ? 1 : 0.4)
                .accessibilityIdentifier("onboarding.goal.minor")
            }
            // Reclaim the two removed helper rows, then add 10% breathing room.
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 270 : 248)
            .clipped()

            if !isMinorWheelEnabled {
                Text("5 L is the maximum daily goal.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SippedTheme.secondaryInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(SippedTheme.surface, in: Capsule())
                    .overlay { Capsule().stroke(SippedTheme.line, lineWidth: 1) }
                    .accessibilityIdentifier("onboarding.goal.maximum")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var majorSelection: Binding<Int> {
        Binding(get: { wheelMajor }, set: { value in
            wheelMajor = value
            commitWheelSelection()
        })
    }

    private var minorSelection: Binding<Int> {
        Binding(get: { wheelMinor }, set: { value in
            wheelMinor = value
            commitWheelSelection()
        })
    }

    private func minorLabel(_ value: Int) -> String {
        units == .metric ? "\(value * Int(DailyFluidGoalMath.metricWheelStepML))" : ".\(value)"
    }

    private func commitWheelSelection() {
        goalML = DailyFluidGoalMath.wheelValue(major: wheelMajor, minor: wheelMinor, units: units)
        syncWheelsToGoal()
    }

    private func syncWheelsToGoal() {
        let components = DailyFluidGoalMath.wheelComponents(forMillilitres: goalML, units: units)
        wheelMajor = components.major
        wheelMinor = components.minor
    }

    private func commitExactEntry() {
        guard let rawValue = Double(exactText.replacingOccurrences(of: ",", with: ".")) else {
            editingExactAmount = false
            exactAmountFocused = false
            return
        }
        let millilitres = DailyFluidGoalMath.millilitres(forDisplayedValue: rawValue, units: units)
        goalML = DailyFluidGoalMath.clampedEntry(millilitres)
        syncWheelsToGoal()
        editingExactAmount = false
        exactAmountFocused = false
    }
}

struct DailyFluidGoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var preferences: UserPreferences
    @State private var goalML: Double

    init(preferences: UserPreferences) {
        self.preferences = preferences
        _goalML = State(initialValue: preferences.validDailyFluidGoalML ?? 0)
    }

    var body: some View {
        DailyFluidGoalSurface(
            goalML: $goalML,
            units: preferences.units,
            actionTitle: "Save goal",
            actionIdentifier: "settings.saveGoal",
            onSave: save
        )
        .background(SippedTheme.canvas)
    }

    private func save() {
        guard let goal = DailyFluidGoalMath.validGoal(goalML) else { return }
        preferences.dailyFluidGoalML = goal
        try? modelContext.save()
        dismiss()
    }
}

private struct OnboardingPage<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SIPPED").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(SippedTheme.chromeAccent)
                    Text(title).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text(subtitle).font(.body).foregroundStyle(SippedTheme.secondaryInk).fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}
