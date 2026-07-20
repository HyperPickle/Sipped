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

    func testSugarFreeEnergyUsesTheRequestedNameAndRegularEnergyColour() throws {
        let regular = try XCTUnwrap(CatalogSeeder.builtInDrinks.first { $0.definitionID == "energy-regular" })
        let sugarFree = try XCTUnwrap(CatalogSeeder.builtInDrinks.first { $0.definitionID == "energy-sugarfree" })

        XCTAssertEqual(sugarFree.name, "Energy Drink Sugar Free")
        XCTAssertEqual(
            DrinkVisualSpec.profile(definitionID: regular.definitionID, category: regular.category).liquid,
            DrinkVisualSpec.profile(definitionID: sugarFree.definitionID, category: sugarFree.category).liquid
        )
    }

    func testBubbleMotionOffsetsAreStableAndStaggered() {
        let energyOffset = BubbleMotion.phaseOffset(for: "energy-regular-slim-can")
        let sparklingOffset = BubbleMotion.phaseOffset(for: "water-sparkling-glass")

        XCTAssertEqual(energyOffset, BubbleMotion.phaseOffset(for: "energy-regular-slim-can"))
        XCTAssertNotEqual(energyOffset, sparklingOffset)
        XCTAssertTrue((0...1).contains(energyOffset))
        XCTAssertTrue((0...1).contains(sparklingOffset))
    }

    func testFullFillSurfaceBandSitsBelowTheVesselInnerTopStroke() {
        let baseline = SurfaceBandMath.visualBaseline(
            interiorTop: 20,
            interiorBottom: 140,
            wallWidth: 6,
            fraction: 1
        )

        XCTAssertEqual(baseline, 26)
        XCTAssertGreaterThan(baseline, 20)
    }

    func testSurfaceBandPreservesVolumeWhenTheVesselNarrows() {
        let wideHeight = SurfaceBandMath.volumePreservingHeight(
            referenceWidth: 60,
            relativeHeight: 0.1,
            maximumHeight: 40,
            widthAtDepth: { _ in 60 }
        )
        let narrowHeight = SurfaceBandMath.volumePreservingHeight(
            referenceWidth: 60,
            relativeHeight: 0.1,
            maximumHeight: 40,
            widthAtDepth: { _ in 30 }
        )

        XCTAssertEqual(wideHeight, 6, accuracy: 0.01)
        XCTAssertEqual(narrowHeight, 12, accuracy: 0.01)
        XCTAssertGreaterThan(narrowHeight, wideHeight)
    }

    func testSlopedSurfaceClearsTheTopStrokeAcrossItsWholeWidth() {
        let baseline = SurfaceBandMath.visualBaseline(
            interiorTop: 20,
            interiorBottom: 140,
            wallWidth: 6,
            fraction: 1,
            verticalExcursion: 4
        )

        XCTAssertEqual(baseline, 30)
    }

    func testAmountPresentationFitsDifferentVesselFamiliesWithUniformScaling() {
        let stage = CGSize(width: 320, height: 350)
        let artworkIDs = ["bottle", "glass", "mug", "shot"]

        for artworkID in artworkIDs {
            let metrics = VesselPresentationMath.metrics(
                for: artworkID,
                in: stage,
                fit: .visibleBounds
            )

            XCTAssertEqual(
                metrics.canvasSize.width / 120,
                metrics.canvasSize.height / 160,
                accuracy: 0.000_001,
                "\(artworkID) must use one linear scale on both axes"
            )
            XCTAssertLessThanOrEqual(metrics.visibleSize.width, stage.width * 0.82 + 0.01)
            XCTAssertLessThanOrEqual(metrics.visibleSize.height, stage.height * 0.90 + 0.01)
            XCTAssertGreaterThan(
                max(metrics.visibleSize.width, metrics.visibleSize.height),
                stage.height * 0.74,
                "\(artworkID) should remain visually dominant on the amount screen"
            )
        }

        let bottle = VesselPresentationMath.metrics(for: "bottle", in: stage, fit: .visibleBounds)
        let glass = VesselPresentationMath.metrics(for: "glass", in: stage, fit: .visibleBounds)
        XCTAssertEqual(bottle.visibleSize.height, glass.visibleSize.height, accuracy: 0.01)
    }

    func testDefaultVesselPresentationKeepsTheOriginalDesignCanvas() {
        let metrics = VesselPresentationMath.metrics(
            for: "glass",
            in: CGSize(width: 120, height: 160),
            fit: .designCanvas
        )

        XCTAssertEqual(metrics.canvasSize, CGSize(width: 120, height: 160))
        XCTAssertEqual(metrics.canvasCenter, CGPoint(x: 60, y: 80))
    }

    func testOtherDrinkIsCustomOnlyAndLegacyPresentationRemainsSupported() {
        XCTAssertFalse(CatalogSeeder.builtInDrinks.contains { $0.definitionID == "other-custom" })
        XCTAssertTrue(CatalogSeeder.retiredDrinkIDs.contains("other-custom"))
        XCTAssertEqual(
            DrinkArtworkPresentation.resolve(definitionID: "other-custom", category: .other),
            .emptyQuestionMark
        )
        XCTAssertEqual(
            DrinkArtworkPresentation.resolve(definitionID: "my-other-drink", category: .other),
            .filled
        )
        XCTAssertEqual(
            DrinkArtworkPresentation.resolve(definitionID: nil, category: .other),
            .filled
        )
    }

    func testTodayTabUsesTheHomeSymbolPair() {
        XCTAssertEqual(AppTab.today.symbol, "house")
        XCTAssertEqual(AppTab.today.selectedSymbol, "house.fill")
    }

    func testEveryCategoryHasDrinksAndAtLeastFourCompatibleContainers() {
        let drinks = CatalogSeeder.builtInDrinks
        let containers = CatalogSeeder.builtInContainers
        for category in DrinkCategory.allCases where category != .other {
            XCTAssertTrue(drinks.contains { $0.category == category }, "Missing drink for \(category.name)")
            XCTAssertGreaterThanOrEqual(containers.filter { $0.supports(category) }.count, 4,
                                        "\(category.name) needs at least four compatible containers")
        }
        XCTAssertFalse(drinks.contains { $0.category == .other })
    }

    func testCoffeeAndBeerPrimaryCompatibilityExcludesImplausibleVessels() {
        let containers = CatalogSeeder.builtInContainers
        XCTAssertFalse(containers.filter { $0.supports(.coffee) }.contains { $0.artworkID == "pint" || $0.artworkID == "stein" })
        XCTAssertFalse(containers.filter { $0.supports(.coffee) }.contains { $0.containerID == "tall-glass" })
        XCTAssertFalse(containers.filter { $0.supports(.beer) }.contains { $0.artworkID == "mug" || $0.artworkID == "espresso" })
    }

    func testBuiltInCoffeeUsesCupMugOrTakeawayVessels() {
        let coffee = CatalogSeeder.builtInDrinks.filter { $0.category == .coffee }
        let approvedArtwork = Set(["cup", "mug", "takeawaySmall", "takeawayLarge"])
        let approvedContainers = Set(["cup", "ceramic-mug", "espresso-cup", "small-takeaway", "large-takeaway"])

        XCTAssertEqual(coffee.count, 8)
        for drink in coffee {
            XCTAssertTrue(approvedArtwork.contains(drink.artworkID), "Unexpected coffee artwork for \(drink.name)")
            XCTAssertTrue(approvedContainers.contains(drink.defaultContainerID ?? ""), "Unexpected coffee container for \(drink.name)")
        }
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
        let retiredOtherDrink = DrinkDefinition(
            definitionID: "other-custom", name: "Other Drink", category: .other,
            artworkID: "glass", basis: "Retired drink", isBuiltIn: true,
            defaultContainerID: "glass"
        )
        context.insert(retired)
        context.insert(customDrink)
        context.insert(historicalLog)
        context.insert(retiredDrink)
        context.insert(retiredOtherDrink)
        try context.save()

        try CatalogSeeder.upgradeReferenceCatalog(context: context, fromVersion: 1)
        try context.save()

        XCTAssertEqual(customDrink.defaultContainerID, "glass")
        XCTAssertFalse(try context.fetch(FetchDescriptor<ContainerDefinition>()).contains { $0.containerID == "water-glass" })
        XCTAssertTrue(try context.fetch(FetchDescriptor<ContainerDefinition>()).contains { $0.containerID == "glass" })
        XCTAssertFalse(try context.fetch(FetchDescriptor<DrinkDefinition>()).contains { $0.definitionID == "other-broth" })
        XCTAssertFalse(try context.fetch(FetchDescriptor<DrinkDefinition>()).contains { $0.definitionID == "other-custom" })

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
