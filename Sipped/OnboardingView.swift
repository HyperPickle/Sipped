import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var preferences: UserPreferences
    @State private var page = 0
    @State private var units: DisplayUnits
    @State private var selectedCategories: Set<DrinkCategory>

    init(preferences: UserPreferences) {
        self.preferences = preferences
        _units = State(initialValue: preferences.units)
        _selectedCategories = State(initialValue: Set(preferences.preferredCategories))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule().fill(index == page ? SippedTheme.chromeAccent : SippedTheme.line)
                        .frame(width: index == page ? 28 : 8, height: 6)
                }
            }
            .animation(animationsEnabled ? SippedMotion.screen : nil, value: page)
            .padding(.top, 18)
            .accessibilityHidden(true)

            currentPage
                .id(page)
                .transition(reduceMotion ? .opacity : SippedMotion.screenTransition(direction: .forward))

            Button(action: advance) {
                Text(page == 2 ? "Open Today" : "Continue")
            }
            .buttonStyle(SippedPrimaryButtonStyle())
            .disabled(page == 2 && selectedCategories.isEmpty)
            .opacity(page == 2 && selectedCategories.isEmpty ? 0.45 : 1)
            .accessibilityIdentifier(page == 2 ? "onboarding.finish" : "onboarding.continue")
            .padding(20)
        }
        .background(SippedTheme.canvas.ignoresSafeArea())
    }

    private var animationsEnabled: Bool {
        !reduceMotion && !ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    @ViewBuilder private var currentPage: some View {
        switch page {
        case 0: measuresPage
        case 1: unitsPage
        default: categoriesPage
        }
    }

    private var measuresPage: some View {
        OnboardingPage(title: "Every drink, clearly recorded", subtitle: "Sipped keeps four contributions separate. They are a factual record, not a score.") {
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
        OnboardingPage(title: "Amounts that feel familiar", subtitle: "You can change display units later in Settings. Stored calculations remain precise.") {
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

    private var categoriesPage: some View {
        OnboardingPage(title: "Put your favourites first", subtitle: "Choose at least one. Every category stays available in search and the full library.") {
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
        guard page < 2 else {
            preferences.units = units
            preferences.preferredCategories = DrinkCategory.allCases.filter(selectedCategories.contains)
            preferences.onboardingComplete = true
            try? modelContext.save()
            return
        }
        if animationsEnabled { withAnimation(SippedMotion.screen) { page += 1 } }
        else { page += 1 }
    }

    private func measureDescription(_ measure: MeasureKind) -> String {
        switch measure {
        case .fluid: "Literal beverage volume"
        case .caffeine: "Cumulative consumed mass"
        case .sugar: "Inherent plus added sugar"
        case .alcohol: "Regional standard drinks"
        }
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
    }
}
