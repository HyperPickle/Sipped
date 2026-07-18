import XCTest
@testable import Sipped

@MainActor
final class CatalogCoverageTests: XCTestCase {
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
}
