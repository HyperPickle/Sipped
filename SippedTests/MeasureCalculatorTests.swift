import XCTest
@testable import Sipped

@MainActor
final class MeasureCalculatorTests: XCTestCase {
    func testDigitBlurRespondsToPerDigitVelocityWithinTastefulBounds() {
        let slow = DigitMotionMath.blurRadius(previousDigit: 1, currentDigit: 2, elapsed: 0.30)
        let fast = DigitMotionMath.blurRadius(previousDigit: 1, currentDigit: 2, elapsed: 1 / 60)

        XCTAssertGreaterThan(slow, 0)
        XCTAssertGreaterThan(fast, slow)
        XCTAssertLessThanOrEqual(fast, 0.28)
    }

    func testUnchangedDigitsStaySharpAndWraparoundUsesShortestDistance() {
        let unchanged = DigitMotionMath.blurRadius(previousDigit: 4, currentDigit: 4, elapsed: 1 / 60)
        let increment = DigitMotionMath.blurRadius(previousDigit: 0, currentDigit: 1, elapsed: 1 / 60)
        let wraparound = DigitMotionMath.blurRadius(previousDigit: 9, currentDigit: 0, elapsed: 1 / 60)

        XCTAssertEqual(unchanged, 0)
        XCTAssertEqual(wraparound, increment, accuracy: 0.0001)
    }

    func testTabMotionDirectionFollowsVisualOrder() {
        XCTAssertEqual(SippedMotion.direction(from: 0, to: 2), .forward)
        XCTAssertEqual(SippedMotion.direction(from: 2, to: 0), .backward)
        XCTAssertEqual(SippedMotion.direction(from: 1, to: 1), .forward)
    }

    func testZeroAndFullContainerAmounts() {
        let drink = DrinkDefinition(name: "Test", category: .water, basis: "Test")
        let zero = MeasureCalculator.contributions(for: drink, volumeML: 0, shots: 1, addedSugarServes: 0, standard: .australia)
        let full = MeasureCalculator.contributions(for: drink, volumeML: 600, shots: 1, addedSugarServes: 0, standard: .australia)
        XCTAssertEqual(zero.fluidML, 0)
        XCTAssertEqual(full.fluidML, 600)
    }

    func testDecimalPerHundredMillilitreScaling() {
        let drink = DrinkDefinition(name: "Juice", category: .juice, sugarPer100ML: 8.4, basis: "Test")
        let result = MeasureCalculator.contributions(for: drink, volumeML: 250, shots: 1, addedSugarServes: 0, standard: .australia)
        XCTAssertEqual(result.inherentSugarG, 21, accuracy: 0.0001)
    }

    func testCaffeineUsesShotBasisWhenPresent() {
        let drink = DrinkDefinition(name: "Coffee", category: .coffee, caffeinePer100ML: 20, caffeinePerShot: 63, basis: "Test")
        let result = MeasureCalculator.contributions(for: drink, volumeML: 300, shots: 3, addedSugarServes: 0, standard: .australia)
        XCTAssertEqual(result.caffeineMG, 189)
    }

    func testAddedSugarIsStoredSeparately() {
        let drink = DrinkDefinition(name: "Latte", category: .coffee, sugarPer100ML: 4.7, basis: "Test")
        let result = MeasureCalculator.contributions(for: drink, volumeML: 200, shots: 1, addedSugarServes: 2, standard: .australia)
        XCTAssertEqual(result.inherentSugarG, 9.4, accuracy: 0.0001)
        XCTAssertEqual(result.addedSugarG, 8)
        XCTAssertEqual(result.sugarG, 17.4, accuracy: 0.0001)
    }

    func testAlcoholBoundariesAreClamped() {
        XCTAssertEqual(MeasureCalculator.standardDrinks(volumeML: 330, abvPercent: -5, gramsPerStandard: 10), 0)
        XCTAssertEqual(MeasureCalculator.standardDrinks(volumeML: 100, abvPercent: 120, gramsPerStandard: 10), 7.89, accuracy: 0.0001)
        XCTAssertEqual(MeasureCalculator.standardDrinks(volumeML: 100, abvPercent: 40, gramsPerStandard: 0), 0)
    }

    func testRegionalStandardChangesDerivedValueFromSameRawInputs() {
        let australian = MeasureCalculator.standardDrinks(volumeML: 375, abvPercent: 5, gramsPerStandard: AlcoholStandard.australia.grams)
        let unitedStates = MeasureCalculator.standardDrinks(volumeML: 375, abvPercent: 5, gramsPerStandard: AlcoholStandard.unitedStates.grams)
        XCTAssertEqual(australian, 1.479375, accuracy: 0.000001)
        XCTAssertEqual(unitedStates, 1.056696, accuracy: 0.000001)
        XCTAssertGreaterThan(australian, unitedStates)
    }

    func testLiteralFluidDoesNotSubtractAlcohol() {
        let drink = DrinkDefinition(name: "Wine", category: .wine, defaultABV: 13.5, basis: "Test")
        let result = MeasureCalculator.contributions(for: drink, volumeML: 150, shots: 0, addedSugarServes: 0, standard: .australia)
        XCTAssertEqual(result.fluidML, 150)
        XCTAssertEqual(result.rawAlcoholML, 20.25, accuracy: 0.0001)
    }

    func testQuickLoggingUsesStoredCoffeeDefaultsAndZeroAddedSugar() {
        let drink = DrinkDefinition(
            name: "Regular Latte",
            category: .coffee,
            caffeinePerShot: 63,
            sugarPer100ML: 4.7,
            defaultShots: 2,
            milkType: "Oat",
            basis: "Stored preparation"
        )
        let result = MeasureCalculator.contributions(
            for: drink,
            volumeML: 200,
            shots: drink.defaultShots,
            addedSugarServes: 0,
            standard: .australia,
            abvOverride: drink.defaultABV
        )
        XCTAssertEqual(result.caffeineMG, 126)
        XCTAssertEqual(result.inherentSugarG, 9.4, accuracy: 0.0001)
        XCTAssertEqual(result.addedSugarG, 0)
    }

    func testQuickLoggingUsesStoredAlcoholStrength() {
        let drink = DrinkDefinition(name: "Red Wine", category: .wine, defaultABV: 13.5, basis: "Stored estimate")
        let result = MeasureCalculator.contributions(
            for: drink,
            volumeML: 150,
            shots: drink.defaultShots,
            addedSugarServes: 0,
            standard: .australia,
            abvOverride: drink.defaultABV
        )
        XCTAssertEqual(result.rawAlcoholML, 20.25, accuracy: 0.0001)
        XCTAssertEqual(result.standardDrinks, 1.597725, accuracy: 0.000001)
    }
}
