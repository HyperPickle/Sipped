import Foundation
import SwiftData

enum CatalogSeeder {
    static let currentSeedVersion = 3
    static let retiredDrinkIDs: Set<String> = ["other-broth"]

    static let retiredContainerRemap: [String: String] = [
        "water-glass": "glass",
        "milk-glass": "glass",
        "kombucha-glass": "glass",
        "other-medium": "glass",
        "tea-cup": "cup",
        "other-small": "cup",
        "tea-pot": "ceramic-mug",
        "large-can": "tallboy-can",
        "kombucha-can": "standard-can",
        "energy-bottle": "soft-bottle",
        "smoothie-bottle": "juice-bottle",
        "smoothie-jar": "shake-cup",
        "milk-carton": "juice-box",
        "wine-small": "wine-standard",
        "wine-large": "wine-standard",
        "spirit-double": "spirit-shot",
        "spirit-tumbler": "lowball-glass",
        "kombucha-growler": "kombucha-bottle",
        "other-jar": "glass",
        "other-carafe": "large-bottle"
    ]

    static var retiredContainerIDs: Set<String> { Set(retiredContainerRemap.keys) }

    static func seedIfNeeded(context: ModelContext, environment: AppEnvironment) throws {
        let preferences: UserPreferences
        if let existing = try context.fetch(FetchDescriptor<UserPreferences>()).first {
            preferences = existing
            if environment.forceOnboardingComplete == true { preferences.onboardingComplete = true }
        } else {
            preferences = UserPreferences(
                onboardingComplete: environment.forceOnboardingComplete ?? false,
                alcoholStandard: .inferred(regionCode: environment.regionCode)
            )
            context.insert(preferences)
        }

        try upgradeReferenceCatalog(context: context, fromVersion: preferences.catalogSeedVersion)
        preferences.catalogSeedVersion = currentSeedVersion

        if ProcessInfo.processInfo.arguments.contains("--seed-history"),
           try context.fetchCount(FetchDescriptor<DrinkLog>()) == 0 {
            try seedHistory(context: context, environment: environment)
        }
        try context.save()
    }

    static func upgradeReferenceCatalog(context: ModelContext, fromVersion: Int) throws {
        var storedDrinks = try context.fetch(FetchDescriptor<DrinkDefinition>())
        var storedContainers = try context.fetch(FetchDescriptor<ContainerDefinition>())

        if fromVersion < currentSeedVersion {
            for drink in storedDrinks {
                guard let id = drink.defaultContainerID,
                      let successor = retiredContainerRemap[id] else { continue }
                drink.defaultContainerID = successor
            }
            for stored in storedDrinks where stored.isBuiltIn && retiredDrinkIDs.contains(stored.definitionID) {
                context.delete(stored)
            }
            storedDrinks.removeAll { $0.isBuiltIn && retiredDrinkIDs.contains($0.definitionID) }
        }

        let desiredDrinks = builtInDrinks
        for desired in desiredDrinks {
            if let stored = storedDrinks.first(where: { $0.definitionID == desired.definitionID && $0.isBuiltIn }) {
                synchronize(stored, with: desired)
            } else {
                context.insert(desired)
                storedDrinks.append(desired)
            }
        }

        if fromVersion < currentSeedVersion {
            for stored in storedContainers where stored.isBuiltIn && retiredContainerIDs.contains(stored.containerID) {
                context.delete(stored)
            }
            storedContainers.removeAll { $0.isBuiltIn && retiredContainerIDs.contains($0.containerID) }
        }

        let desiredContainers = builtInContainers
        for desired in desiredContainers {
            if let stored = storedContainers.first(where: { $0.containerID == desired.containerID && $0.isBuiltIn }) {
                stored.name = desired.name
                stored.capacityML = desired.capacityML
                stored.artworkID = desired.artworkID
                stored.compatibilityCSV = desired.compatibilityCSV
            } else {
                context.insert(desired)
                storedContainers.append(desired)
            }
        }
    }

    static var builtInDrinks: [DrinkDefinition] { [
        drink("water-still", "Still Water", .water, "bottle", "water-bottle", 0, 0, 0, 0, "Fluid volume only; no hydration multiplier."),
        drink("water-sparkling", "Sparkling Water", .water, "glass", "glass", 0, 0, 0, 0, "Fluid volume only; unsweetened estimate."),
        drink("coffee-espresso", "Espresso", .coffee, "espresso", "espresso-cup", 0, 63, 0, 0, "63 mg caffeine per espresso shot; sugar excludes additions."),
        drink("coffee-long-black", "Long Black", .coffee, "mug", "ceramic-mug", 0, 63, 0, 0, "63 mg caffeine per espresso shot; sugar excludes additions."),
        drink("coffee-flat-white", "Flat White", .coffee, "mug", "ceramic-mug", 0, 63, 4.6, 0, "63 mg caffeine per shot; 4.6 g milk sugar per 100 mL."),
        drink("coffee-latte", "Latte", .coffee, "tallGlass", "tall-glass", 0, 63, 4.7, 0, "63 mg caffeine per shot; 4.7 g milk sugar per 100 mL."),
        drink("coffee-cappuccino", "Cappuccino", .coffee, "mug", "ceramic-mug", 0, 63, 3.8, 0, "63 mg caffeine per shot; 3.8 g milk sugar per 100 mL."),
        drink("coffee-filter", "Filter Coffee", .coffee, "mug", "ceramic-mug", 40, 0, 0, 0, "40 mg caffeine per 100 mL brewed coffee."),
        drink("coffee-cold-brew", "Cold Brew", .coffee, "tallGlass", "tall-glass", 55, 0, 0, 0, "55 mg caffeine per 100 mL cold brew estimate."),
        drink("coffee-iced", "Iced Coffee", .coffee, "tallGlass", "tall-glass", 0, 63, 5.2, 0, "63 mg caffeine per shot; 5.2 g inherent sugar per 100 mL."),
        drink("tea-black", "Black Tea", .tea, "cup", "cup", 20, 0, 0, 0, "20 mg caffeine per 100 mL brewed tea."),
        drink("tea-green", "Green Tea", .tea, "cup", "cup", 12, 0, 0, 0, "12 mg caffeine per 100 mL brewed tea."),
        drink("tea-chai", "Chai with Milk", .tea, "mug", "ceramic-mug", 14, 0, 4.8, 0, "14 mg caffeine and 4.8 g inherent sugar per 100 mL."),
        drink("soft-cola", "Cola", .softDrinks, "can", "standard-can", 9.5, 0, 10.6, 0, "9.5 mg caffeine and 10.6 g sugar per 100 mL."),
        drink("soft-lemonade", "Lemonade", .softDrinks, "can", "standard-can", 0, 0, 10.2, 0, "10.2 g sugar per 100 mL generic estimate."),
        drink("energy-regular", "Energy Drink", .energyDrinks, "slimCan", "slim-can", 32, 0, 11, 0, "32 mg caffeine and 11 g sugar per 100 mL."),
        drink("energy-sugarfree", "Sugar-free Energy", .energyDrinks, "slimCan", "slim-can", 32, 0, 0, 0, "32 mg caffeine per 100 mL; zero-sugar estimate."),
        drink("juice-orange", "Orange Juice", .juice, "glass", "glass", 0, 0, 8.4, 0, "8.4 g naturally occurring sugar per 100 mL."),
        drink("juice-apple", "Apple Juice", .juice, "glass", "glass", 0, 0, 10.3, 0, "10.3 g naturally occurring sugar per 100 mL."),
        drink("milk-dairy", "Dairy Milk", .milk, "glass", "glass", 0, 0, 4.8, 0, "4.8 g naturally occurring lactose per 100 mL."),
        drink("milk-oat", "Oat Milk", .milk, "glass", "glass", 0, 0, 4.0, 0, "4 g sugar per 100 mL generic oat milk estimate."),
        drink("smoothie-fruit", "Fruit Smoothie", .smoothies, "shake", "shake-cup", 0, 0, 11.5, 0, "11.5 g sugar per 100 mL generic fruit smoothie estimate."),
        drink("smoothie-green", "Green Smoothie", .smoothies, "shake", "shake-cup", 0, 0, 7.0, 0, "7 g sugar per 100 mL generic green smoothie estimate."),
        drink("kombucha-original", "Kombucha", .kombucha, "beerBottle", "kombucha-bottle", 4, 0, 3.2, 0.5, "4 mg caffeine, 3.2 g sugar per 100 mL; 0.5% ABV estimate."),
        drink("kombucha-ginger", "Ginger Kombucha", .kombucha, "beerBottle", "kombucha-bottle", 4, 0, 3.5, 0.5, "4 mg caffeine, 3.5 g sugar per 100 mL; 0.5% ABV estimate."),
        drink("beer-lager", "Lager", .beer, "pint", "beer-pint", 0, 0, 0.4, 4.5, "4.5% ABV and 0.4 g sugar per 100 mL generic lager."),
        drink("beer-ale", "Pale Ale", .beer, "pint", "beer-pint", 0, 0, 0.4, 5.2, "5.2% ABV and 0.4 g sugar per 100 mL generic ale."),
        drink("wine-red", "Red Wine", .wine, "wine", "wine-standard", 0, 0, 0.6, 13.5, "13.5% ABV and 0.6 g sugar per 100 mL generic dry red."),
        drink("wine-white", "White Wine", .wine, "wine", "wine-standard", 0, 0, 0.7, 12.5, "12.5% ABV and 0.7 g sugar per 100 mL generic dry white."),
        drink("spirits-whisky", "Whisky", .spirits, "lowball", "lowball-glass", 0, 0, 0, 40, "40% ABV generic spirit estimate."),
        drink("spirits-gin", "Gin", .spirits, "lowball", "lowball-glass", 0, 0, 0, 40, "40% ABV generic spirit estimate."),
        drink("other-custom", "Other Drink", .other, "glass", "glass", 0, 0, 0, 0, "Values start at zero and can be edited for this log.")
    ] }

    static var builtInContainers: [ContainerDefinition] { [
        container("glass", "Glass", 250, "glass", [.water, .juice, .milk, .softDrinks, .kombucha, .smoothies, .other]),
        container("tall-glass", "Tall glass", 400, "tallGlass", [.water, .juice, .milk, .smoothies, .softDrinks, .coffee, .spirits, .other]),
        container("cup", "Cup", 220, "cup", [.tea, .coffee, .other]),
        container("ceramic-mug", "Ceramic mug", 300, "mug", [.coffee, .tea, .other]),
        container("espresso-cup", "Espresso cup", 90, "espresso", [.coffee]),
        container("small-takeaway", "Small takeaway", 240, "takeawaySmall", [.coffee, .tea]),
        container("large-takeaway", "Large takeaway", 470, "takeawayLarge", [.coffee, .tea]),
        container("small-water-bottle", "Small water bottle", 250, "smallWaterBottle", [.water]),
        container("water-bottle", "Water bottle", 600, "bottle", [.water, .juice, .other]),
        container("large-bottle", "Large bottle", 1000, "largeBottle", [.water, .other]),
        container("stanley-bottle", "Stanley bottle", 1180, "stanley", [.water]),
        container("sports-bottle", "Sports bottle", 750, "sports", [.water]),
        container("juice-box", "Juice box", 250, "juiceBox", [.juice, .milk]),
        container("juice-bottle", "Juice bottle", 350, "juiceBottle", [.juice, .smoothies]),
        container("shake-cup", "Shake cup", 450, "shake", [.smoothies, .milk]),
        container("slim-can", "Slim can", 250, "slimCan", [.softDrinks, .energyDrinks, .beer, .kombucha]),
        container("standard-can", "Standard can", 330, "can", [.softDrinks, .energyDrinks, .beer, .kombucha]),
        container("tallboy-can", "Tallboy can", 500, "tallCan", [.softDrinks, .energyDrinks, .beer, .kombucha]),
        container("soft-bottle", "Soft drink bottle", 600, "softBottle", [.softDrinks, .energyDrinks]),
        container("kombucha-bottle", "Kombucha bottle", 330, "beerBottle", [.kombucha]),
        container("beer-bottle", "Beer bottle", 330, "beerBottle", [.beer]),
        container("beer-schooner", "Schooner", 425, "schooner", [.beer]),
        container("beer-pint", "Pint", 570, "pint", [.beer]),
        container("beer-stein", "Stein", 500, "stein", [.beer]),
        container("wine-standard", "Wine glass", 150, "wine", [.wine]),
        container("wine-bottle", "Wine bottle", 750, "wineBottle", [.wine]),
        container("spirit-shot", "Shot glass", 30, "shot", [.spirits]),
        container("lowball-glass", "Lowball glass", 250, "lowball", [.spirits]),
        container("spirit-highball", "Highball", 300, "tallGlass", [.spirits]),
        container("party-cup", "Party cup", 473, "party", [.beer, .spirits, .wine]),
        container("martini-glass", "Martini glass", 200, "martini", [.spirits, .wine]),
        container("champagne-flute", "Champagne flute", 150, "flute", [.spirits, .wine])
    ] }

    private static func synchronize(_ stored: DrinkDefinition, with desired: DrinkDefinition) {
        stored.name = desired.name
        stored.categoryRaw = desired.categoryRaw
        stored.artworkID = desired.artworkID
        stored.caffeinePer100ML = desired.caffeinePer100ML
        stored.caffeinePerShot = desired.caffeinePerShot
        stored.sugarPer100ML = desired.sugarPer100ML
        stored.defaultABV = desired.defaultABV
        stored.defaultShots = desired.defaultShots
        stored.milkType = desired.milkType
        stored.basis = desired.basis
        stored.defaultContainerID = desired.defaultContainerID
    }

    private static func seedHistory(context: ModelContext, environment: AppEnvironment) throws {
        let drinks = try context.fetch(FetchDescriptor<DrinkDefinition>())
        let containers = try context.fetch(FetchDescriptor<ContainerDefinition>())
        let ids = ["water-still", "coffee-latte", "juice-orange", "beer-lager", "tea-green", "soft-cola", "wine-red"]
        for (index, id) in ids.enumerated() {
            guard let drink = drinks.first(where: { $0.definitionID == id }),
                  let container = containers.first(where: { $0.containerID == drink.defaultContainerID })
                    ?? containers.first(where: { $0.supports(drink.category) }) else { continue }
            let date = environment.date(byAddingDays: index - 6, to: environment.now)
            let volume = min(container.capacityML, drink.category.isAlcoholic ? 150 : 250)
            let values = MeasureCalculator.contributions(for: drink, volumeML: volume, shots: drink.category == .coffee ? 2 : 1,
                                                         addedSugarServes: drink.category == .coffee ? 1 : 0,
                                                         standard: .australia)
            context.insert(DrinkLog(logID: "seed-\(id)", loggedAt: date, orderIndex: date.timeIntervalSinceReferenceDate,
                                    sourceDefinitionID: drink.definitionID, drinkName: drink.name, category: drink.category,
                                    artworkID: drink.artworkID, containerID: container.containerID, containerName: container.name,
                                    containerCapacityML: container.capacityML, consumedML: volume, caffeineMG: values.caffeineMG,
                                    inherentSugarG: values.inherentSugarG, addedSugarG: values.addedSugarG,
                                    rawAlcoholML: values.rawAlcoholML, alcoholByVolume: drink.defaultABV,
                                    shots: drink.category == .coffee ? 2 : 1, milkType: "", calculationBasis: drink.basis))
        }
        let custom = DrinkDefinition(definitionID: "test-regular", name: "Morning Regular", category: .coffee,
                                     artworkID: "mug", caffeinePerShot: 63, sugarPer100ML: 4.7,
                                     defaultShots: 2, milkType: "Oat", basis: "Saved test preparation.",
                                     isBuiltIn: false, defaultContainerID: "ceramic-mug")
        context.insert(custom)
        if let mug = containers.first(where: { $0.containerID == "ceramic-mug" }) {
            let volume = 200.0
            let values = MeasureCalculator.contributions(for: custom, volumeML: volume, shots: 2,
                                                         addedSugarServes: 1, standard: .australia)
            let date = environment.now.addingTimeInterval(60)
            context.insert(DrinkLog(logID: "seed-regular", loggedAt: date, orderIndex: date.timeIntervalSinceReferenceDate,
                                    sourceDefinitionID: custom.definitionID, drinkName: custom.name, category: custom.category,
                                    artworkID: custom.artworkID, containerID: mug.containerID, containerName: mug.name,
                                    containerCapacityML: mug.capacityML, consumedML: volume, caffeineMG: values.caffeineMG,
                                    inherentSugarG: values.inherentSugarG, addedSugarG: values.addedSugarG,
                                    rawAlcoholML: 0, alcoholByVolume: 0, shots: 2, milkType: "Oat",
                                    calculationBasis: custom.basis))
        }
    }

    private static func drink(_ id: String, _ name: String, _ category: DrinkCategory, _ artwork: String,
                              _ defaultContainerID: String, _ caffeine100: Double, _ caffeineShot: Double,
                              _ sugar100: Double, _ abv: Double, _ basis: String) -> DrinkDefinition {
        DrinkDefinition(definitionID: id, name: name, category: category, artworkID: artwork,
                        caffeinePer100ML: caffeine100, caffeinePerShot: caffeineShot,
                        sugarPer100ML: sugar100, defaultABV: abv, basis: basis,
                        defaultContainerID: defaultContainerID)
    }

    private static func container(_ id: String, _ name: String, _ capacity: Double,
                                  _ artwork: String, _ categories: [DrinkCategory]) -> ContainerDefinition {
        ContainerDefinition(containerID: id, name: name, capacityML: capacity,
                            artworkID: artwork, categories: categories)
    }
}
