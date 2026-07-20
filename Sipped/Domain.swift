import Foundation
import SwiftData
import SwiftUI

enum DrinkCategory: String, Codable, CaseIterable, Identifiable {
    case water, coffee, tea, softDrinks, energyDrinks, juice, milk, smoothies
    case kombucha, beer, wine, spirits, other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .water: "Water"
        case .coffee: "Coffee"
        case .tea: "Tea"
        case .softDrinks: "Soft Drinks"
        case .energyDrinks: "Energy Drinks"
        case .juice: "Juice"
        case .milk: "Milk"
        case .smoothies: "Smoothies"
        case .kombucha: "Kombucha"
        case .beer: "Beer"
        case .wine: "Wine"
        case .spirits: "Spirits"
        case .other: "Other"
        }
    }

    var symbol: String {
        switch self {
        case .water: "drop.fill"
        case .coffee: "mug.fill"
        case .tea: "leaf.fill"
        case .softDrinks: "bubbles.and.sparkles.fill"
        case .energyDrinks: "bolt.fill"
        case .juice: "sun.max.fill"
        case .milk: "moon.fill"
        case .smoothies: "swirl.circle.righthalf.filled"
        case .kombucha: "sparkles"
        case .beer: "takeoutbag.and.cup.and.straw.fill"
        case .wine: "wineglass.fill"
        case .spirits: "flame.fill"
        case .other: "ellipsis"
        }
    }

    var tint: Color {
        switch self {
        case .water: Color(red: 0.18, green: 0.57, blue: 0.68)
        case .coffee: Color(red: 0.48, green: 0.31, blue: 0.20)
        case .tea: Color(red: 0.35, green: 0.55, blue: 0.30)
        case .softDrinks: Color(red: 0.74, green: 0.25, blue: 0.26)
        case .energyDrinks: Color(red: 0.77, green: 0.50, blue: 0.10)
        case .juice: Color(red: 0.90, green: 0.47, blue: 0.10)
        case .milk: Color(red: 0.43, green: 0.49, blue: 0.62)
        case .smoothies: Color(red: 0.70, green: 0.27, blue: 0.48)
        case .kombucha: Color(red: 0.47, green: 0.43, blue: 0.15)
        case .beer: Color(red: 0.75, green: 0.49, blue: 0.08)
        case .wine: Color(red: 0.55, green: 0.16, blue: 0.25)
        case .spirits: Color(red: 0.33, green: 0.39, blue: 0.50)
        case .other: Color(red: 0.38, green: 0.42, blue: 0.41)
        }
    }

    var defaultArtwork: String {
        switch self {
        case .coffee, .tea: "mug"
        case .water, .juice, .milk, .smoothies: "glass"
        case .softDrinks, .energyDrinks: "can"
        case .kombucha, .beer: "bottle"
        case .wine: "wine"
        case .spirits: "tumbler"
        case .other: "glass"
        }
    }

    var isAlcoholic: Bool { self == .beer || self == .wine || self == .spirits }
}

enum MeasureKind: String, CaseIterable, Identifiable {
    case fluid, caffeine, sugar, alcohol
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .fluid: "drop.fill"
        case .caffeine: "bolt.fill"
        case .sugar: "cube.fill"
        case .alcohol: "wineglass.fill"
        }
    }
    var color: Color {
        switch self {
        case .fluid: Color(red: 0.24, green: 0.79, blue: 0.97)
        case .caffeine: Color(red: 0.62, green: 0.32, blue: 0.12)
        case .sugar: Color(red: 0.67, green: 0.18, blue: 0.42)
        case .alcohol: Color(red: 0.36, green: 0.31, blue: 0.66)
        }
    }

    var selectedForegroundColor: Color {
        self == .fluid ? .black.opacity(0.82) : .white
    }
}

enum DisplayUnits: String, CaseIterable, Identifiable {
    case metric, imperial
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

enum AlcoholStandard: String, CaseIterable, Identifiable {
    case australia, unitedStates, unitedKingdom, canada
    var id: String { rawValue }
    var name: String {
        switch self {
        case .australia: "Australia"
        case .unitedStates: "United States"
        case .unitedKingdom: "United Kingdom"
        case .canada: "Canada"
        }
    }
    var grams: Double {
        switch self {
        case .australia: 10
        case .unitedStates: 14
        case .unitedKingdom: 8
        case .canada: 13.6
        }
    }
    static func inferred(regionCode: String?) -> Self {
        switch regionCode?.uppercased() {
        case "US": .unitedStates
        case "GB": .unitedKingdom
        case "CA": .canada
        default: .australia
        }
    }
}

@Model
final class DrinkDefinition {
    @Attribute(.unique) var definitionID: String
    var name: String
    var categoryRaw: String
    var artworkID: String
    var caffeinePer100ML: Double
    var caffeinePerShot: Double
    var sugarPer100ML: Double
    var defaultABV: Double
    var defaultShots: Int
    var milkType: String
    var basis: String
    var isBuiltIn: Bool
    var defaultContainerID: String?
    var createdAt: Date

    init(definitionID: String = UUID().uuidString, name: String, category: DrinkCategory,
         artworkID: String? = nil, caffeinePer100ML: Double = 0, caffeinePerShot: Double = 0,
         sugarPer100ML: Double = 0, defaultABV: Double = 0, defaultShots: Int = 1,
         milkType: String = "", basis: String, isBuiltIn: Bool = true,
         defaultContainerID: String? = nil, createdAt: Date = .now) {
        self.definitionID = definitionID
        self.name = name
        self.categoryRaw = category.rawValue
        self.artworkID = artworkID ?? category.defaultArtwork
        self.caffeinePer100ML = caffeinePer100ML
        self.caffeinePerShot = caffeinePerShot
        self.sugarPer100ML = sugarPer100ML
        self.defaultABV = defaultABV
        self.defaultShots = defaultShots
        self.milkType = milkType
        self.basis = basis
        self.isBuiltIn = isBuiltIn
        self.defaultContainerID = defaultContainerID
        self.createdAt = createdAt
    }

    var category: DrinkCategory { DrinkCategory(rawValue: categoryRaw) ?? .other }
}

@Model
final class ContainerDefinition {
    @Attribute(.unique) var containerID: String
    var name: String
    var capacityML: Double
    var artworkID: String
    var compatibilityCSV: String
    var isBuiltIn: Bool
    var createdAt: Date

    init(containerID: String = UUID().uuidString, name: String, capacityML: Double,
         artworkID: String, categories: [DrinkCategory], isBuiltIn: Bool = true,
         createdAt: Date = .now) {
        self.containerID = containerID
        self.name = name
        self.capacityML = capacityML
        self.artworkID = artworkID
        self.compatibilityCSV = categories.map(\.rawValue).joined(separator: ",")
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }

    var categories: [DrinkCategory] {
        compatibilityCSV.split(separator: ",").compactMap { DrinkCategory(rawValue: String($0)) }
    }

    func supports(_ category: DrinkCategory) -> Bool { categories.contains(category) }
}

@Model
final class UserPreferences {
    @Attribute(.unique) var preferencesID: String
    var onboardingComplete: Bool
    var unitsRaw: String
    var preferredCategoriesCSV: String
    var selectedMeasureRaw: String
    var appearanceRaw: String
    var alcoholStandardRaw: String
    var catalogSeedVersion: Int = 0

    init(preferencesID: String = "primary", onboardingComplete: Bool = false,
         units: DisplayUnits = .metric, preferredCategories: [DrinkCategory] = [.water, .coffee],
         selectedMeasure: MeasureKind = .fluid, appearance: AppearancePreference = .system,
         alcoholStandard: AlcoholStandard = .australia, catalogSeedVersion: Int = 0) {
        self.preferencesID = preferencesID
        self.onboardingComplete = onboardingComplete
        self.unitsRaw = units.rawValue
        self.preferredCategoriesCSV = preferredCategories.map(\.rawValue).joined(separator: ",")
        self.selectedMeasureRaw = selectedMeasure.rawValue
        self.appearanceRaw = appearance.rawValue
        self.alcoholStandardRaw = alcoholStandard.rawValue
        self.catalogSeedVersion = catalogSeedVersion
    }

    var units: DisplayUnits {
        get { DisplayUnits(rawValue: unitsRaw) ?? .metric }
        set { unitsRaw = newValue.rawValue }
    }
    var preferredCategories: [DrinkCategory] {
        get { preferredCategoriesCSV.split(separator: ",").compactMap { DrinkCategory(rawValue: String($0)) } }
        set { preferredCategoriesCSV = newValue.map(\.rawValue).joined(separator: ",") }
    }
    var selectedMeasure: MeasureKind {
        get { MeasureKind(rawValue: selectedMeasureRaw) ?? .fluid }
        set { selectedMeasureRaw = newValue.rawValue }
    }
    var appearance: AppearancePreference {
        get { AppearancePreference(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }
    var alcoholStandard: AlcoholStandard {
        get { AlcoholStandard(rawValue: alcoholStandardRaw) ?? .australia }
        set { alcoholStandardRaw = newValue.rawValue }
    }
}

enum FillAmountMath {
    static let snapFractions = [0.25, 0.50, 0.75, 1.0]

    static func clampedFraction(_ fraction: Double) -> Double {
        min(1, max(0, fraction.isFinite ? fraction : 0))
    }

    static func millilitres(for fraction: Double, capacityML: Double) -> Double {
        max(0, capacityML.isFinite ? capacityML : 0) * clampedFraction(fraction)
    }

    static func fraction(forMillilitres amountML: Double, capacityML: Double) -> Double {
        guard capacityML.isFinite, capacityML > 0 else { return 0 }
        return clampedFraction(amountML / capacityML)
    }

    static func snapIndex(for fraction: Double, tolerance: Double = 0.018) -> Int? {
        let value = clampedFraction(fraction)
        return snapFractions.firstIndex { abs(value - $0) < tolerance }
    }
}

@Model
final class DrinkUsagePreference {
    @Attribute(.unique) var definitionID: String
    var lastContainerID: String

    init(definitionID: String, lastContainerID: String) {
        self.definitionID = definitionID
        self.lastContainerID = lastContainerID
    }
}

@Model
final class DrinkLog {
    @Attribute(.unique) var logID: String
    var loggedAt: Date
    var orderIndex: Double
    var sourceDefinitionID: String?
    var drinkName: String
    var categoryRaw: String
    var artworkID: String
    var containerID: String?
    var containerName: String
    var containerCapacityML: Double
    var consumedML: Double
    var caffeineMG: Double
    var inherentSugarG: Double
    var addedSugarG: Double
    var rawAlcoholML: Double
    var alcoholByVolume: Double
    var shots: Int
    var milkType: String
    var calculationBasis: String

    init(logID: String = UUID().uuidString, loggedAt: Date, orderIndex: Double,
         sourceDefinitionID: String?, drinkName: String, category: DrinkCategory,
         artworkID: String, containerID: String?, containerName: String,
         containerCapacityML: Double, consumedML: Double, caffeineMG: Double,
         inherentSugarG: Double, addedSugarG: Double, rawAlcoholML: Double,
         alcoholByVolume: Double, shots: Int, milkType: String, calculationBasis: String) {
        self.logID = logID
        self.loggedAt = loggedAt
        self.orderIndex = orderIndex
        self.sourceDefinitionID = sourceDefinitionID
        self.drinkName = drinkName
        self.categoryRaw = category.rawValue
        self.artworkID = artworkID
        self.containerID = containerID
        self.containerName = containerName
        self.containerCapacityML = containerCapacityML
        self.consumedML = consumedML
        self.caffeineMG = caffeineMG
        self.inherentSugarG = inherentSugarG
        self.addedSugarG = addedSugarG
        self.rawAlcoholML = rawAlcoholML
        self.alcoholByVolume = alcoholByVolume
        self.shots = shots
        self.milkType = milkType
        self.calculationBasis = calculationBasis
    }

    var category: DrinkCategory {
        get { DrinkCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    var sugarG: Double { inherentSugarG + addedSugarG }
    func standardDrinks(using standard: AlcoholStandard) -> Double {
        MeasureCalculator.standardDrinks(volumeML: consumedML, abvPercent: alcoholByVolume, gramsPerStandard: standard.grams)
    }
}

struct MeasureContributions: Equatable {
    var fluidML: Double
    var caffeineMG: Double
    var inherentSugarG: Double
    var addedSugarG: Double
    var rawAlcoholML: Double
    var standardDrinks: Double
    var sugarG: Double { inherentSugarG + addedSugarG }
}

enum MeasureCalculator {
    static func contributions(for drink: DrinkDefinition, volumeML: Double, shots: Int,
                              addedSugarServes: Int, standard: AlcoholStandard,
                              abvOverride: Double? = nil) -> MeasureContributions {
        let volume = max(0, volumeML)
        let abv = max(0, min(100, abvOverride ?? drink.defaultABV))
        let caffeine = drink.caffeinePerShot > 0
            ? Double(max(0, shots)) * drink.caffeinePerShot
            : volume / 100 * drink.caffeinePer100ML
        let inherentSugar = volume / 100 * drink.sugarPer100ML
        let addedSugar = Double(max(0, addedSugarServes)) * 4
        return MeasureContributions(
            fluidML: volume,
            caffeineMG: caffeine,
            inherentSugarG: inherentSugar,
            addedSugarG: addedSugar,
            rawAlcoholML: volume * abv / 100,
            standardDrinks: standardDrinks(volumeML: volume, abvPercent: abv, gramsPerStandard: standard.grams)
        )
    }

    static func standardDrinks(volumeML: Double, abvPercent: Double, gramsPerStandard: Double) -> Double {
        guard gramsPerStandard > 0 else { return 0 }
        let ethanolML = max(0, volumeML) * max(0, min(100, abvPercent)) / 100
        return ethanolML * 0.789 / gramsPerStandard
    }
}

struct DailyTotals: Equatable {
    var fluidML: Double = 0
    var caffeineMG: Double = 0
    var sugarG: Double = 0
    var alcohol: Double = 0

    init(logs: [DrinkLog], standard: AlcoholStandard) {
        for log in logs {
            fluidML += log.consumedML
            caffeineMG += log.caffeineMG
            sugarG += log.sugarG
            alcohol += log.standardDrinks(using: standard)
        }
    }

    func value(for measure: MeasureKind) -> Double {
        switch measure {
        case .fluid: fluidML
        case .caffeine: caffeineMG
        case .sugar: sugarG
        case .alcohol: alcohol
        }
    }
}
