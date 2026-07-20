import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \UserPreferences.preferencesID) private var preferences: [UserPreferences]
    let environment: AppEnvironment
    @State private var seedError: String?

    var body: some View {
        Group {
            if let preference = preferences.first {
                if preference.onboardingComplete {
                    MainTabView(preferences: preference, environment: environment)
                } else {
                    OnboardingView(preferences: preference)
                }
            } else if let seedError {
                ContentUnavailableView("Unable to open Sipped", systemImage: "exclamationmark.triangle", description: Text(seedError))
            } else {
                ProgressView("Preparing your library")
            }
        }
        .id(rootPhase)
        .sippedBlurReplaceTransition()
        .animation(reduceMotion ? SippedMotion.reduced : SippedMotion.screen, value: rootPhase)
        .tint(SippedTheme.chromeAccent)
        .foregroundStyle(SippedTheme.ink)
        .background(SippedTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(preferences.first?.appearance.colorScheme)
        .task {
            do { try CatalogSeeder.seedIfNeeded(context: modelContext, environment: environment) }
            catch { seedError = error.localizedDescription }
        }
    }

    private var rootPhase: String {
        guard let preference = preferences.first else { return seedError == nil ? "loading" : "error" }
        return preference.onboardingComplete ? "main" : "onboarding"
    }
}
