import Foundation
import SwiftData

enum CatalogSeeder {
    static func seedIfNeeded(context: ModelContext, environment: AppEnvironment) throws {
        if try context.fetchCount(FetchDescriptor<DrinkDefinition>()) == 0 {
            builtInDrinks.forEach(context.insert)
        }
        if try context.fetchCount(FetchDescriptor<ContainerDefinition>()) == 0 {
            builtInContainers.forEach(context.insert)
        }
        if try context.fetchCount(FetchDescriptor<UserPreferences>()) == 0 {
            let preferences = UserPreferences(
                onboardingComplete: environment.forceOnboardingComplete ?? false,
                alcoholStandard: .inferred(regionCode: environment.regionCode)
            )
            context.insert(preferences)
        } else if environment.forceOnboardingComplete == true {
            let preferences = try context.fetch(FetchDescriptor<UserPreferences>())
            preferences.first?.onboardingComplete = true
        }
        if ProcessInfo.processInfo.arguments.contains("--seed-history"),
           try context.fetchCount(FetchDescriptor<DrinkLog>()) == 0 {
            try seedHistory(context: context, environment: environment)
        }
        try context.save()
    }

    static var builtInDrinks: [DrinkDefinition] { [
        drink("water-still", "Still Water", .water, "bottle", 0, 0, 0, 0, "Fluid volume only; no hydration multiplier."),
        drink("water-sparkling", "Sparkling Water", .water, "glass", 0, 0, 0, 0, "Fluid volume only; unsweetened estimate."),
        drink("coffee-espresso", "Espresso", .coffee, "espresso", 0, 63, 0, 0, "63 mg caffeine per espresso shot; sugar excludes additions."),
        drink("coffee-long-black", "Long Black", .coffee, "mug", 0, 63, 0, 0, "63 mg caffeine per espresso shot; sugar excludes additions."),
        drink("coffee-flat-white", "Flat White", .coffee, "mug", 0, 63, 4.6, 0, "63 mg caffeine per shot; 4.6 g milk sugar per 100 mL."),
        drink("coffee-latte", "Latte", .coffee, "glass", 0, 63, 4.7, 0, "63 mg caffeine per shot; 4.7 g milk sugar per 100 mL."),
        drink("coffee-cappuccino", "Cappuccino", .coffee, "mug", 0, 63, 3.8, 0, "63 mg caffeine per shot; 3.8 g milk sugar per 100 mL."),
        drink("coffee-filter", "Filter Coffee", .coffee, "mug", 40, 0, 0, 0, "40 mg caffeine per 100 mL brewed coffee."),
        drink("coffee-cold-brew", "Cold Brew", .coffee, "tallGlass", 55, 0, 0, 0, "55 mg caffeine per 100 mL cold brew estimate."),
        drink("coffee-iced", "Iced Coffee", .coffee, "tallGlass", 0, 63, 5.2, 0, "63 mg caffeine per shot; 5.2 g inherent sugar per 100 mL."),
        drink("tea-black", "Black Tea", .tea, "cup", 20, 0, 0, 0, "20 mg caffeine per 100 mL brewed tea."),
        drink("tea-green", "Green Tea", .tea, "cup", 12, 0, 0, 0, "12 mg caffeine per 100 mL brewed tea."),
        drink("tea-chai", "Chai with Milk", .tea, "mug", 14, 0, 4.8, 0, "14 mg caffeine and 4.8 g inherent sugar per 100 mL."),
        drink("soft-cola", "Cola", .softDrinks, "can", 9.5, 0, 10.6, 0, "9.5 mg caffeine and 10.6 g sugar per 100 mL."),
        drink("soft-lemonade", "Lemonade", .softDrinks, "can", 0, 0, 10.2, 0, "10.2 g sugar per 100 mL generic estimate."),
        drink("energy-regular", "Energy Drink", .energyDrinks, "can", 32, 0, 11, 0, "32 mg caffeine and 11 g sugar per 100 mL."),
        drink("energy-sugarfree", "Sugar-free Energy", .energyDrinks, "can", 32, 0, 0, 0, "32 mg caffeine per 100 mL; zero-sugar estimate."),
        drink("juice-orange", "Orange Juice", .juice, "glass", 0, 0, 8.4, 0, "8.4 g naturally occurring sugar per 100 mL."),
        drink("juice-apple", "Apple Juice", .juice, "glass", 0, 0, 10.3, 0, "10.3 g naturally occurring sugar per 100 mL."),
        drink("milk-dairy", "Dairy Milk", .milk, "glass", 0, 0, 4.8, 0, "4.8 g naturally occurring lactose per 100 mL."),
        drink("milk-oat", "Oat Milk", .milk, "carton", 0, 0, 4.0, 0, "4 g sugar per 100 mL generic oat milk estimate."),
        drink("smoothie-fruit", "Fruit Smoothie", .smoothies, "tallGlass", 0, 0, 11.5, 0, "11.5 g sugar per 100 mL generic fruit smoothie estimate."),
        drink("smoothie-green", "Green Smoothie", .smoothies, "tallGlass", 0, 0, 7.0, 0, "7 g sugar per 100 mL generic green smoothie estimate."),
        drink("kombucha-original", "Kombucha", .kombucha, "bottle", 4, 0, 3.2, 0.5, "4 mg caffeine, 3.2 g sugar per 100 mL; 0.5% ABV estimate."),
        drink("kombucha-ginger", "Ginger Kombucha", .kombucha, "bottle", 4, 0, 3.5, 0.5, "4 mg caffeine, 3.5 g sugar per 100 mL; 0.5% ABV estimate."),
        drink("beer-lager", "Lager", .beer, "pint", 0, 0, 0.4, 4.5, "4.5% ABV and 0.4 g sugar per 100 mL generic lager."),
        drink("beer-ale", "Pale Ale", .beer, "pint", 0, 0, 0.4, 5.2, "5.2% ABV and 0.4 g sugar per 100 mL generic ale."),
        drink("wine-red", "Red Wine", .wine, "wine", 0, 0, 0.6, 13.5, "13.5% ABV and 0.6 g sugar per 100 mL generic dry red."),
        drink("wine-white", "White Wine", .wine, "wine", 0, 0, 0.7, 12.5, "12.5% ABV and 0.7 g sugar per 100 mL generic dry white."),
        drink("spirits-whisky", "Whisky", .spirits, "tumbler", 0, 0, 0, 40, "40% ABV generic spirit estimate."),
        drink("spirits-gin", "Gin", .spirits, "tumbler", 0, 0, 0, 40, "40% ABV generic spirit estimate."),
        drink("other-broth", "Broth", .other, "mug", 0, 0, 0.5, 0, "Fluid and sugar estimated per 100 mL."),
        drink("other-custom", "Other Drink", .other, "glass", 0, 0, 0, 0, "Values start at zero and can be edited for this log.")
    ] }

    static var builtInContainers: [ContainerDefinition] { [
        container("espresso-cup", "Espresso cup", 90, "espresso", [.coffee]),
        container("ceramic-mug", "Ceramic mug", 300, "mug", [.coffee, .tea, .other]),
        container("small-takeaway", "Small takeaway", 240, "takeaway", [.coffee, .tea]),
        container("large-takeaway", "Large takeaway", 470, "takeaway", [.coffee, .tea]),
        container("tea-cup", "Tea cup", 220, "cup", [.tea, .coffee]),
        container("tea-pot", "Tea pot", 600, "carafe", [.tea]),
        container("water-glass", "Water glass", 300, "glass", [.water, .juice, .milk, .softDrinks, .other]),
        container("tall-glass", "Tall glass", 400, "tallGlass", [.water, .juice, .milk, .smoothies, .softDrinks, .coffee, .other]),
        container("water-bottle", "Water bottle", 600, "bottle", [.water, .juice, .other]),
        container("large-bottle", "Large bottle", 1000, "bottle", [.water, .other]),
        container("juice-box", "Juice box", 250, "carton", [.juice, .milk]),
        container("juice-bottle", "Juice bottle", 350, "bottle", [.juice, .smoothies]),
        container("milk-glass", "Milk glass", 250, "glass", [.milk, .smoothies]),
        container("milk-carton", "Small carton", 300, "carton", [.milk, .juice]),
        container("shake-cup", "Shake cup", 450, "tallGlass", [.smoothies, .milk]),
        container("smoothie-bottle", "Smoothie bottle", 350, "bottle", [.smoothies, .juice]),
        container("smoothie-jar", "Smoothie jar", 500, "jar", [.smoothies]),
        container("slim-can", "Slim can", 250, "can", [.energyDrinks, .softDrinks]),
        container("standard-can", "Standard can", 330, "can", [.softDrinks, .energyDrinks, .beer]),
        container("large-can", "Large can", 500, "can", [.softDrinks, .energyDrinks, .beer]),
        container("soft-bottle", "Soft drink bottle", 600, "bottle", [.softDrinks, .energyDrinks]),
        container("energy-bottle", "Energy bottle", 350, "bottle", [.energyDrinks]),
        container("kombucha-bottle", "Kombucha bottle", 330, "bottle", [.kombucha]),
        container("kombucha-glass", "Kombucha glass", 250, "glass", [.kombucha]),
        container("kombucha-can", "Kombucha can", 330, "can", [.kombucha]),
        container("kombucha-growler", "Kombucha growler", 750, "carafe", [.kombucha]),
        container("beer-bottle", "Beer bottle", 330, "bottle", [.beer]),
        container("beer-schooner", "Schooner", 425, "pint", [.beer]),
        container("beer-pint", "Pint glass", 570, "pint", [.beer]),
        container("beer-stein", "Stein", 500, "stein", [.beer]),
        container("wine-small", "Small wine glass", 100, "wine", [.wine]),
        container("wine-standard", "Wine glass", 150, "wine", [.wine]),
        container("wine-large", "Large wine glass", 250, "wine", [.wine]),
        container("wine-bottle", "Wine bottle", 750, "bottle", [.wine]),
        container("spirit-shot", "Shot glass", 30, "shot", [.spirits]),
        container("spirit-double", "Double measure", 60, "shot", [.spirits]),
        container("spirit-tumbler", "Tumbler", 250, "tumbler", [.spirits]),
        container("spirit-highball", "Highball", 300, "tallGlass", [.spirits]),
        container("other-small", "Small cup", 200, "cup", [.other]),
        container("other-medium", "Medium glass", 350, "glass", [.other]),
        container("other-jar", "Jar", 500, "jar", [.other]),
        container("other-carafe", "Carafe", 750, "carafe", [.other])
    ] }

    private static func seedHistory(context: ModelContext, environment: AppEnvironment) throws {
        let drinks = try context.fetch(FetchDescriptor<DrinkDefinition>())
        let containers = try context.fetch(FetchDescriptor<ContainerDefinition>())
        let ids = ["water-still", "coffee-latte", "juice-orange", "beer-lager", "tea-green", "soft-cola", "wine-red"]
        for (index, id) in ids.enumerated() {
            guard let drink = drinks.first(where: { $0.definitionID == id }),
                  let container = containers.first(where: { $0.supports(drink.category) }) else { continue }
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
                              _ caffeine100: Double, _ caffeineShot: Double, _ sugar100: Double,
                              _ abv: Double, _ basis: String) -> DrinkDefinition {
        DrinkDefinition(definitionID: id, name: name, category: category, artworkID: artwork,
                        caffeinePer100ML: caffeine100, caffeinePerShot: caffeineShot,
                        sugarPer100ML: sugar100, defaultABV: abv, basis: basis)
    }

    private static func container(_ id: String, _ name: String, _ capacity: Double,
                                  _ artwork: String, _ categories: [DrinkCategory]) -> ContainerDefinition {
        ContainerDefinition(containerID: id, name: name, capacityML: capacity,
                            artworkID: artwork, categories: categories)
    }
}
