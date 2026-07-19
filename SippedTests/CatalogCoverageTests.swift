import XCTest
import SwiftData
@testable import Sipped

@MainActor
final class CatalogCoverageTests: XCTestCase {
    func testApprovedVesselCatalogueIsCompleteUniqueAndRenderable() {
        let containers = CatalogSeeder.builtInContainers

        XCTAssertEqual(containers.count, 32)
        XCTAssertEqual(Set(containers.map(\.containerID)).count, containers.count)
        XCTAssertTrue(containers.allSatisfy { VesselStyleRegistry.resolves($0.artworkID) })
        XCTAssertTrue(CatalogSeeder.builtInDrinks.allSatisfy { VesselStyleRegistry.resolves($0.artworkID) })
    }

    func testRetiredContainerRemapMatchesTheApprovedMigrationContract() {
        let expected: [String: String] = [
            "water-glass": "glass", "milk-glass": "glass", "kombucha-glass": "glass", "other-medium": "glass",
            "tea-cup": "cup", "other-small": "cup", "tea-pot": "ceramic-mug", "large-can": "tallboy-can",
            "kombucha-can": "standard-can", "energy-bottle": "soft-bottle", "smoothie-bottle": "juice-bottle",
            "smoothie-jar": "shake-cup", "milk-carton": "juice-box", "wine-small": "wine-standard",
            "wine-large": "wine-standard", "spirit-double": "spirit-shot", "spirit-tumbler": "lowball-glass",
            "kombucha-growler": "kombucha-bottle", "other-jar": "glass", "other-carafe": "large-bottle"
        ]

        XCTAssertEqual(CatalogSeeder.retiredContainerRemap, expected)
    }

    func testCarbonationProfilesMatchTheApprovedAllowlist() {
        XCTAssertEqual(DrinkVisualSpec.carbonatedIDs, Set([
            "water-sparkling", "soft-cola", "soft-lemonade", "energy-regular", "energy-sugarfree",
            "kombucha-original", "kombucha-ginger", "beer-lager", "beer-ale"
        ]))
    }

    func testEveryCategoryHasDrinksAndAtLeastFourCompatibleContainers() {
        let drinks = CatalogSeeder.builtInDrinks
        let containers = CatalogSeeder.builtInContainers
        for category in DrinkCategory.allCases {
            XCTAssertTrue(drinks.contains { $0.category == category }, "Missing drink for \(category.name)")
            XCTAssertGreaterThanOrEqual(containers.filter { $0.supports(category) }.count, 4,
                                        "\(category.name) needs at least four compatible containers")
        }
    }

    func testCoffeeAndBeerPrimaryCompatibilityExcludesImplausibleVessels() {
        let containers = CatalogSeeder.builtInContainers
        XCTAssertFalse(containers.filter { $0.supports(.coffee) }.contains { $0.artworkID == "pint" || $0.artworkID == "stein" })
        XCTAssertFalse(containers.filter { $0.supports(.beer) }.contains { $0.artworkID == "mug" || $0.artworkID == "espresso" })
    }

    func testRequiredCoffeePreparationsAreSeeded() {
        let coffeeNames = Set(CatalogSeeder.builtInDrinks.filter { $0.category == .coffee }.map(\.name))
        let required = Set(["Espresso", "Long Black", "Flat White", "Latte", "Cappuccino", "Filter Coffee", "Cold Brew", "Iced Coffee"])
        XCTAssertTrue(required.isSubset(of: coffeeNames))
    }

    func testRetiredBrothIsNotPartOfTheBuiltInDrinkLibrary() {
        XCTAssertFalse(CatalogSeeder.builtInDrinks.contains { $0.definitionID == "other-broth" })
        XCTAssertTrue(CatalogSeeder.retiredDrinkIDs.contains("other-broth"))
    }

    func testCatalogueUpgradeRemapsDefinitionsButPreservesImmutableLogSnapshots() throws {
        let schema = Schema([
            DrinkDefinition.self, ContainerDefinition.self, UserPreferences.self,
            DrinkUsagePreference.self, DrinkLog.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let retired = ContainerDefinition(
            containerID: "water-glass", name: "Water glass", capacityML: 300,
            artworkID: "glass", categories: [.water], isBuiltIn: true
        )
        let customDrink = DrinkDefinition(
            definitionID: "migration-custom", name: "Saved water", category: .water,
            artworkID: "glass", basis: "Migration test", isBuiltIn: false,
            defaultContainerID: "water-glass"
        )
        let historicalLog = DrinkLog(
            logID: "immutable-history", loggedAt: .now, orderIndex: 1,
            sourceDefinitionID: customDrink.definitionID, drinkName: "Saved water", category: .water,
            artworkID: "glass", containerID: "water-glass", containerName: "Water glass",
            containerCapacityML: 300, consumedML: 225, caffeineMG: 0,
            inherentSugarG: 0, addedSugarG: 0, rawAlcoholML: 0,
            alcoholByVolume: 0, shots: 0, milkType: "", calculationBasis: "Original snapshot"
        )
        let retiredDrink = DrinkDefinition(
            definitionID: "other-broth", name: "Broth", category: .other,
            artworkID: "mug", basis: "Retired drink", isBuiltIn: true,
            defaultContainerID: "ceramic-mug"
        )
        context.insert(retired)
        context.insert(customDrink)
        context.insert(historicalLog)
        context.insert(retiredDrink)
        try context.save()

        try CatalogSeeder.upgradeReferenceCatalog(context: context, fromVersion: 1)
        try context.save()

        XCTAssertEqual(customDrink.defaultContainerID, "glass")
        XCTAssertFalse(try context.fetch(FetchDescriptor<ContainerDefinition>()).contains { $0.containerID == "water-glass" })
        XCTAssertTrue(try context.fetch(FetchDescriptor<ContainerDefinition>()).contains { $0.containerID == "glass" })
        XCTAssertFalse(try context.fetch(FetchDescriptor<DrinkDefinition>()).contains { $0.definitionID == "other-broth" })

        let savedLog = try XCTUnwrap(
            context.fetch(FetchDescriptor<DrinkLog>()).first { $0.logID == "immutable-history" }
        )
        XCTAssertEqual(savedLog.containerID, "water-glass")
        XCTAssertEqual(savedLog.containerName, "Water glass")
        XCTAssertEqual(savedLog.containerCapacityML, 300)
        XCTAssertEqual(savedLog.consumedML, 225)
        XCTAssertEqual(savedLog.calculationBasis, "Original snapshot")
    }
}

@MainActor
final class FillAmountMathTests: XCTestCase {
    func testFractionAndMillilitresRoundTripAcrossApprovedSnapPoints() {
        for fraction in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let millilitres = FillAmountMath.millilitres(for: fraction, capacityML: 470)
            XCTAssertEqual(FillAmountMath.fraction(forMillilitres: millilitres, capacityML: 470), fraction, accuracy: 0.000_001)
        }
    }

    func testAmountMathClampsInvalidAndOutOfRangeValues() {
        XCTAssertEqual(FillAmountMath.clampedFraction(-1), 0)
        XCTAssertEqual(FillAmountMath.clampedFraction(1.4), 1)
        XCTAssertEqual(FillAmountMath.clampedFraction(.infinity), 0)
        XCTAssertEqual(FillAmountMath.fraction(forMillilitres: 100, capacityML: 0), 0)
        XCTAssertEqual(FillAmountMath.millilitres(for: 0.5, capacityML: -300), 0)
    }

    func testSnapDetectionUsesTheFourApprovedMilestones() {
        XCTAssertEqual(FillAmountMath.snapIndex(for: 0.25), 0)
        XCTAssertEqual(FillAmountMath.snapIndex(for: 0.501), 1)
        XCTAssertEqual(FillAmountMath.snapIndex(for: 0.751), 2)
        XCTAssertEqual(FillAmountMath.snapIndex(for: 1), 3)
        XCTAssertNil(FillAmountMath.snapIndex(for: 0.4))
    }
}
