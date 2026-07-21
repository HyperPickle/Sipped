import Foundation

struct AppEnvironment {
    let now: Date
    let calendar: Calendar
    let regionCode: String
    let forceOnboardingComplete: Bool?
    let forcedDailyFluidGoalML: Double?
    let forceGoalSetupOnly: Bool

    static var live: AppEnvironment {
        let arguments = ProcessInfo.processInfo.arguments
        let testing = arguments.contains("--ui-testing")
        var calendar = Calendar(identifier: .gregorian)
        if testing { calendar.timeZone = TimeZone(secondsFromGMT: 0)! }

        let now: Date = {
            guard testing,
                  let value = arguments.first(where: { $0.hasPrefix("--now=") })?.split(separator: "=", maxSplits: 1).last
            else { return .now }
            return ISO8601DateFormatter().date(from: String(value)) ?? .now
        }()

        let region = arguments.first(where: { $0.hasPrefix("--region=") })
            .flatMap { $0.split(separator: "=", maxSplits: 1).last.map(String.init) }
            ?? Locale.current.region?.identifier ?? "AU"

        let goalSetupOnly = arguments.contains("--goal-setup-only")
        let onboarding: Bool? = arguments.contains("--skip-onboarding") || goalSetupOnly ? true : nil
        let forcedGoal = arguments.first(where: { $0.hasPrefix("--daily-fluid-goal=") })
            .flatMap { $0.split(separator: "=", maxSplits: 1).last.flatMap { Double($0) } }
        return AppEnvironment(now: now, calendar: calendar, regionCode: region,
                              forceOnboardingComplete: onboarding,
                              forcedDailyFluidGoalML: forcedGoal,
                              forceGoalSetupOnly: goalSetupOnly)
    }

    func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    func date(byAddingDays days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    func isDate(_ date: Date, inSameDayAs other: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: other)
    }
}
