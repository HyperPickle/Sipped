import XCTest

final class SippedAcceptanceTests: XCTestCase {
    private var app: XCUIApplication!
    private let inventoryFolderName = "SippedRedesignInventory"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testOnboardingExplainsMeasuresUnitsAndCategories() {
        launch(skipOnboarding: false)
        XCTAssertTrue(app.staticTexts["Every drink, clearly recorded"].waitForExistence(timeout: 5))
        for measure in ["Fluid", "Caffeine", "Sugar", "Alcohol"] { XCTAssertTrue(app.staticTexts[measure].exists) }
        app.buttons["onboarding.continue"].tap()
        app.buttons["units.imperial"].tap()
        app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.category.coffee"].tap()
        app.buttons["onboarding.finish"].tap()
        XCTAssertTrue(app.staticTexts["Sipped"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["global.add"].exists)
    }

    func testDrinkContainerAmountOrderingAndBackNavigation() {
        launch()
        app.buttons["global.add"].tap()
        XCTAssertTrue(app.staticTexts["Choose a drink"].waitForExistence(timeout: 3))
        app.buttons["drink.water-still"].tap()
        XCTAssertTrue(app.staticTexts["Choose a container"].waitForExistence(timeout: 3))
        XCTAssertFalse(element("amount.fill").exists)
        app.buttons["logger.back"].tap()
        XCTAssertTrue(app.staticTexts["Choose a drink"].waitForExistence(timeout: 3))
        app.buttons["drink.water-still"].tap()
        selectContainer("glass")
        XCTAssertTrue(element("amount.fill").waitForExistence(timeout: 3))
        app.buttons["logger.back"].tap()
        XCTAssertTrue(app.staticTexts["Choose a container"].waitForExistence(timeout: 3))
        XCTAssertFalse(element("amount.fill").exists)
    }

    func testGenericDrinkStartsAtZeroAndLogsWithOneConfirmation() {
        launch()
        openDrink("drink.water-still")
        XCTAssertFalse(element("amount.fill").exists, "A container selection must be required")
        selectContainer("glass")
        XCTAssertTrue(app.otherElements["amount.fill"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["amount.fill"].value.debugDescription.contains("0"))
        enterAmount("250")
        tapWhenHittable(app.buttons["logger.confirm"])
        XCTAssertTrue(app.staticTexts["Still Water"].waitForExistence(timeout: 3))
        let fluidTotal = element("today.total.fluid")
        XCTAssertTrue(fluidTotal.waitForExistence(timeout: 3))
        XCTAssertTrue(fluidTotal.label.contains("250 mL"))
    }

    func testRepeatDrinkRemembersContainerButResetsAmount() {
        launch()
        openDrink("drink.water-still")
        selectContainer("large-bottle")
        enterAmount("300")
        tapWhenHittable(app.buttons["logger.confirm"])
        openDrink("drink.water-still")
        let gallery = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'container.'"))
        XCTAssertGreaterThan(gallery.count, 0)
        XCTAssertEqual(gallery.element(boundBy: 0).identifier, "container.large-bottle")
        selectContainer("large-bottle")
        XCTAssertTrue(app.otherElements["amount.fill"].value.debugDescription.contains("0"))
    }

    func testCoffeeQuickLogHidesCategoryControlsAndUsesStoredDefaults() {
        launch()
        openDrink("drink.coffee-latte")
        selectContainer("ceramic-mug")
        XCTAssertFalse(app.staticTexts["Shots"].exists)
        XCTAssertFalse(app.staticTexts["Sugar"].isHittable)
        XCTAssertFalse(app.textFields["alcohol.abv"].exists)
        XCTAssertFalse(element("contribution.fluid").exists)
        XCTAssertFalse(app.buttons["Adjust estimates"].exists)
        XCTAssertFalse(app.buttons["amount.basis"].exists)
        enterAmount("200")
        tapWhenHittable(app.buttons["logger.confirm"])
        app.staticTexts["Latte"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Caffeine' AND label CONTAINS '63'")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Inherent sugar' AND label CONTAINS '9.4'")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Added sugar' AND label CONTAINS '0'")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Coffee' AND label CONTAINS '1 shot'")).firstMatch.exists)
    }

    func testAlcoholQuickLogHidesStrengthControlsAndUsesStoredABV() {
        launch(extraArguments: ["--open-drink=wine-red"])
        XCTAssertTrue(app.staticTexts["Choose a container"].waitForExistence(timeout: 4))
        selectContainer("wine-standard")
        XCTAssertFalse(app.textFields["alcohol.abv"].exists)
        XCTAssertFalse(element("contribution.alcohol").exists)
        XCTAssertFalse(app.buttons["Adjust estimates"].exists)
        enterAmount("150")
        tapWhenHittable(app.buttons["logger.confirm"])
        app.staticTexts["Red Wine"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Raw inputs' AND label CONTAINS '13.5% ABV'")).firstMatch.waitForExistence(timeout: 3))
    }

    func testCompatibleContainerFilterCustomAccessAndDeepLink() {
        launch(extraArguments: ["--open-drink=coffee-latte"])
        XCTAssertTrue(app.staticTexts["Choose a container"].waitForExistence(timeout: 4))
        XCTAssertFalse(element("amount.fill").exists)
        XCTAssertTrue(app.buttons["container.espresso-cup"].exists)
        XCTAssertTrue(app.buttons["container.ceramic-mug"].exists)
        XCTAssertFalse(app.buttons["container.beer-pint"].exists)
        app.buttons["logger.newContainer"].tap()
        XCTAssertTrue(app.textFields["customContainer.name"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()
    }

    func testDragFillExactEntryClampingAndLogState() {
        launch(extraArguments: ["--open-drink=water-still"])
        selectContainer("glass")
        let fill = element("amount.fill")
        XCTAssertTrue(fill.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["logger.confirm"].isEnabled)
        let start = fill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
        let end = fill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertTrue(app.buttons["logger.confirm"].isEnabled)
        enterAmount("10000")
        XCTAssertTrue(fill.value.debugDescription.contains("250 millilitres"))
        XCTAssertTrue(fill.value.debugDescription.contains("100 percent"))
    }

    func testAmountStageAtAccessibilityTextDarkModeAndReduceMotion() {
        XCUIDevice.shared.appearance = .dark
        defer { XCUIDevice.shared.appearance = .light }
        launch(extraArguments: [
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
            "-UIAccessibilityReduceMotionEnabled", "YES",
            "--open-drink=water-still"
        ])
        selectContainer("glass")
        XCTAssertTrue(element("amount.fill").isHittable)
        XCTAssertTrue(app.buttons["amount.exact"].isHittable)
        XCTAssertTrue(app.buttons["logger.back"].isHittable)
        XCTAssertTrue(app.buttons["logger.confirm"].exists)
    }

    func testSelectedMeasureChangesSingleGraphWhileTotalsRemain() {
        launch(seedHistory: true)
        XCTAssertTrue(element("today.total.fluid").waitForExistence(timeout: 3))
        XCTAssertTrue(element("today.total.caffeine").exists)
        app.buttons["measure.sugar"].tap()
        XCTAssertTrue(element("today.graph.sugar").waitForExistence(timeout: 2))
        XCTAssertFalse(element("today.graph.fluid").exists)
        XCTAssertTrue(element("today.total.alcohol").exists)
    }

    func testEditDeleteAndUndoRecalculateLedger() {
        launch(seedHistory: true)
        tapWhenHittable(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Red Wine,'")).firstMatch)
        app.buttons["entry.edit"].tap()
        let fill = element("amount.fill")
        XCTAssertTrue(fill.waitForExistence(timeout: 3))
        XCTAssertTrue(fill.value.debugDescription.contains("150 millilitres"))
        setFill(fill, to: 0.8)
        app.buttons["entry.save"].tap()
        let amountDetail = element("entry.detail.amount")
        XCTAssertTrue(amountDetail.waitForExistence(timeout: 3))
        XCTAssertFalse(amountDetail.label.contains("150"), "Amount did not change: \(amountDetail.label)")
        app.buttons["Delete entry"].tap()
        tapLast(app.buttons.matching(identifier: "Delete"))
        XCTAssertTrue(app.buttons["entry.undo"].waitForExistence(timeout: 3))
        app.buttons["entry.undo"].tap()
        XCTAssertTrue(app.staticTexts["Red Wine"].waitForExistence(timeout: 3))
    }

    func testRegionalAlcoholStandardRecalculatesStoredRawInputs() {
        launch(seedHistory: true)
        let alcoholTotal = element("today.total.alcohol")
        XCTAssertTrue(alcoholTotal.waitForExistence(timeout: 3))
        let australianLabel = alcoholTotal.label
        XCTAssertTrue(australianLabel.contains("std"))
        app.buttons["settings.open"].tap()
        let picker = element("settings.alcoholStandard")
        tapWhenHittable(picker)
        let us = app.buttons.matching(NSPredicate(format: "label CONTAINS 'United States'")).firstMatch
        if us.waitForExistence(timeout: 2) { us.tap() }
        app.navigationBars.buttons.firstMatch.tap()
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", australianLabel),
            object: alcoholTotal
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
        XCTAssertTrue(alcoholTotal.label.contains("std"))
    }

    func testDeletingMyDrinkKeepsHistoricalSnapshot() {
        launch(seedHistory: true)
        app.buttons["tab.library"].tap()
        app.segmentedControls.firstMatch.buttons["My Drinks"].tap()
        XCTAssertTrue(app.buttons["drink.test-regular"].waitForExistence(timeout: 3))
        app.buttons["drink.test-regular"].tap()
        app.buttons["myDrink.delete"].tap()
        tapLast(app.buttons.matching(identifier: "myDrink.confirmDelete"))
        tapWhenHittable(app.buttons["tab.today"])
        let historical = element("log.seed-regular")
        scrollUntilExists(historical)
        XCTAssertTrue(historical.exists)
    }

    func testDeleteAllDataReturnsToOnboardingAndClearsHistory() {
        launch(seedHistory: true)
        app.buttons["settings.open"].tap()
        tapWhenHittable(app.buttons["settings.deleteAll"])
        XCTAssertTrue(app.staticTexts["Delete all Sipped data?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'permanently deleted' AND label CONTAINS 'onboarding'" )).firstMatch.exists)
        tapLast(app.buttons.matching(identifier: "settings.confirmDeleteAll"))
        XCTAssertTrue(app.staticTexts["Every drink, clearly recorded"].waitForExistence(timeout: 4))
    }

    func testSevenDayHistoryAndDayDetail() {
        launch(seedHistory: true)
        app.buttons["tab.history"].tap()
        XCTAssertTrue(element("history.graph").waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'drink'")).count, 7)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Today,'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Red Wine"].waitForExistence(timeout: 3))
    }

    func testLibrarySearchContainerGalleryAndSavedDrinkSnapshot() {
        launch(seedHistory: true)
        app.buttons["tab.library"].tap()
        XCTAssertTrue(app.buttons["drink.water-still"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Drink library"].exists)
        app.textFields["library.search"].tap(); app.textFields["library.search"].typeText("espresso")
        XCTAssertTrue(app.buttons["drink.coffee-espresso"].waitForExistence(timeout: 2))
        app.buttons["Clear search"].tap()
        app.segmentedControls.firstMatch.buttons["Containers"].tap()
        app.textFields["library.search"].tap(); app.textFields["library.search"].typeText("Glass")
        XCTAssertTrue(app.buttons["container.glass"].waitForExistence(timeout: 3))
    }

    func testCaptureCompleteRedesignInventory() throws {
        try resetInventoryDirectory()

        launch(skipOnboarding: false)
        waitForText("Every drink, clearly recorded")
        capture("01-onboarding-measures")
        app.buttons["onboarding.continue"].tap()
        waitForText("Amounts that feel familiar")
        capture("02-onboarding-units-metric")
        app.buttons["units.imperial"].tap()
        capture("03-onboarding-units-imperial")
        app.buttons["onboarding.continue"].tap()
        waitForText("Put your favourites first")
        capture("04-onboarding-categories")

        launch()
        XCTAssertTrue(app.buttons["global.add"].waitForExistence(timeout: 5))
        capture("06-today-empty")
        app.buttons["global.add"].tap()
        waitForText("Choose a drink")
        capture("07-logger-choose-drink")
        tapWhenHittable(app.buttons["drink.water-still"])
        waitForText("Choose a container")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        capture("08-logger-water-container")
        selectContainer("glass")
        XCTAssertTrue(element("amount.fill").waitForExistence(timeout: 4))
        capture("09-logger-water-zero")
        enterAmount("250")
        capture("10-logger-water-filled")
        tapWhenHittable(app.buttons["logger.back"])
        waitForText("Choose a container")
        capture("11-logger-water-container-return")

        launch(seedHistory: true)
        XCTAssertTrue(element("log.seed-regular").waitForExistence(timeout: 5))
        capture("12-today-seeded")
        tapWhenHittable(app.buttons["measure.sugar"])
        XCTAssertTrue(element("today.graph.sugar").waitForExistence(timeout: 3))
        capture("13-today-sugar-measure")

        launch(seedHistory: true, extraArguments: ["--start-tab=history"])
        XCTAssertTrue(element("history.graph").waitForExistence(timeout: 5))
        capture("14-history-seven-days")
        let today = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Today,'")).firstMatch
        tapWhenHittable(today)
        XCTAssertTrue(element("log.seed-wine-red").waitForExistence(timeout: 4))
        capture("15-history-day-detail")
        tapWhenHittable(element("log.seed-wine-red"))
        XCTAssertTrue(app.buttons["entry.edit"].waitForExistence(timeout: 4))
        capture("16-entry-detail")
        app.buttons["entry.edit"].tap()
        XCTAssertTrue(app.buttons["entry.save"].waitForExistence(timeout: 4))
        capture("17-entry-edit")
        app.buttons["entry.cancel"].tap()
        XCTAssertTrue(app.buttons["Delete entry"].waitForExistence(timeout: 4))
        app.buttons["Delete entry"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "Delete").firstMatch.waitForExistence(timeout: 3))
        capture("18-delete-entry-dialog")
        tapLast(app.buttons.matching(identifier: "Delete"))
        XCTAssertTrue(app.buttons["entry.undo"].waitForExistence(timeout: 4))
        capture("19-entry-undo-banner")

        launch(seedHistory: true, extraArguments: ["--open-settings"])
        XCTAssertTrue(element("settings.alcoholStandard").waitForExistence(timeout: 5))
        capture("20-settings")
        tapWhenHittable(element("settings.alcoholStandard"))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'United States'")).firstMatch.waitForExistence(timeout: 3))
        capture("21-settings-alcohol-picker")

        launch(seedHistory: true, extraArguments: ["--start-tab=library"])
        XCTAssertTrue(app.buttons["drink.water-still"].waitForExistence(timeout: 5))
        capture("22-library-drinks")
        app.segmentedControls.firstMatch.buttons["My Drinks"].tap()
        XCTAssertTrue(app.buttons["drink.test-regular"].waitForExistence(timeout: 4))
        capture("23-library-my-drinks")
        app.buttons["drink.test-regular"].tap()
        XCTAssertTrue(app.buttons["myDrink.delete"].waitForExistence(timeout: 4))
        capture("24-my-drink-detail")
        app.buttons["myDrink.delete"].tap()
        XCTAssertTrue(app.buttons["myDrink.confirmDelete"].waitForExistence(timeout: 3))
        capture("25-delete-my-drink-dialog")

        launch(seedHistory: true, extraArguments: ["--start-tab=library"])
        XCTAssertTrue(app.textFields["library.search"].waitForExistence(timeout: 5))
        app.textFields["library.search"].tap()
        app.textFields["library.search"].typeText("Latte")
        tapWhenHittable(app.buttons["drink.coffee-latte"])
        XCTAssertTrue(app.navigationBars["Latte"].waitForExistence(timeout: 4))
        capture("26-drink-definition-detail")

        launch(seedHistory: true, extraArguments: ["--start-tab=library"])
        XCTAssertTrue(app.buttons["library.create"].waitForExistence(timeout: 5))
        app.buttons["library.create"].tap()
        XCTAssertTrue(app.textFields["customDrink.name"].waitForExistence(timeout: 4))
        capture("27-custom-drink-form")

        launch(seedHistory: true, extraArguments: ["--start-tab=library"])
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        app.segmentedControls.firstMatch.buttons["Containers"].tap()
        waitForText("Container library")
        capture("28-library-containers")

        launch(seedHistory: true, extraArguments: ["--start-tab=library"])
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        app.segmentedControls.firstMatch.buttons["Containers"].tap()
        app.textFields["library.search"].tap()
        app.textFields["library.search"].typeText("Beer bottle")
        tapWhenHittable(app.buttons["container.beer-bottle"])
        XCTAssertTrue(app.navigationBars["Beer bottle"].waitForExistence(timeout: 4))
        capture("29-container-detail")

        launch(seedHistory: true, extraArguments: ["--start-tab=library"])
        XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
        app.segmentedControls.firstMatch.buttons["Containers"].tap()
        app.buttons["library.create"].tap()
        XCTAssertTrue(app.textFields["customContainer.name"].waitForExistence(timeout: 4))
        capture("30-custom-container-form")

        launch(extraArguments: ["--open-drink=coffee-latte"])
        waitForText("Choose a container")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        capture("31-logger-coffee-container")
        selectContainer("ceramic-mug")
        XCTAssertTrue(element("amount.fill").waitForExistence(timeout: 5))
        capture("32-logger-coffee-zero")
        enterAmount("200")
        capture("33-logger-coffee-filled")

        launch(extraArguments: ["--open-drink=wine-red"])
        selectContainer("wine-standard")
        let wineFill = element("amount.fill")
        XCTAssertTrue(wineFill.waitForExistence(timeout: 5))
        setFill(wineFill, to: 1)
        XCTAssertTrue(wineFill.value.debugDescription.contains("150 millilitres"))
        XCTAssertTrue(waitForLabel(element("amount.percentage"), containing: "100%"))
        XCTAssertFalse(app.textFields["alcohol.abv"].exists)
        capture("34-logger-alcohol-filled")

        launch(seedHistory: true, extraArguments: ["--open-settings"])
        XCTAssertTrue(app.buttons["settings.deleteAll"].waitForExistence(timeout: 5))
        tapWhenHittable(app.buttons["settings.deleteAll"])
        XCTAssertTrue(app.buttons["settings.confirmDeleteAll"].waitForExistence(timeout: 3))
        capture("35-delete-all-data-dialog")

        try Data("complete".utf8).write(to: inventoryDirectory.appendingPathComponent("COMPLETE"), options: .atomic)
    }

    func testCaptureStableNumericInputStates() throws {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SippedStableInputRecaptures", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        launch(extraArguments: ["--open-drink=coffee-latte"])
        waitForText("Choose a container")
        stableCapture("31-logger-coffee-container", in: directory)
        selectContainer("ceramic-mug")
        XCTAssertTrue(element("amount.fill").waitForExistence(timeout: 5))
        enterAmount("200")
        stableCapture("33-logger-coffee-filled", in: directory)

        launch(extraArguments: ["--open-drink=water-still"])
        waitForText("Choose a container")
        stableCapture("08-logger-water-container", in: directory)
        selectContainer("glass")
        XCTAssertTrue(element("amount.fill").waitForExistence(timeout: 5))
        enterAmount("250")
        stableCapture("10-logger-water-filled", in: directory)

        launch(extraArguments: ["--open-drink=wine-red"])
        selectContainer("wine-standard")
        let wineFill = element("amount.fill")
        XCTAssertTrue(wineFill.waitForExistence(timeout: 5))
        setFill(wineFill, to: 1)
        XCTAssertTrue(wineFill.value.debugDescription.contains("150 millilitres"))
        XCTAssertTrue(waitForLabel(element("amount.percentage"), containing: "100%"))
        stableCapture("34-logger-alcohol-filled", in: directory)

        try Data("complete".utf8).write(to: directory.appendingPathComponent("COMPLETE"), options: .atomic)
    }

    func testCaptureInterfaceFixReview() throws {
        defer { XCUIDevice.shared.appearance = .light }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SippedInterfaceFixReview", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        launch(skipOnboarding: false)
        app.buttons["onboarding.continue"].tap()
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.staticTexts["Put your favourites first"].waitForExistence(timeout: 3))
        app.buttons["onboarding.category.coffee"].tap()
        stableCapture("onboarding-categories-light", in: directory)

        launch(seedHistory: true)
        tapWhenHittable(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Red Wine,'")).firstMatch)
        app.buttons["entry.edit"].tap()
        XCTAssertTrue(element("amount.fill").waitForExistence(timeout: 3))
        stableCapture("entry-edit-fill-light", in: directory)

        launch(extraArguments: ["--open-drink=coffee-latte"])
        selectContainer("ceramic-mug")
        setFill(element("amount.fill"), to: 0.67)
        stableCapture("coffee-mug-light", in: directory)

        XCUIDevice.shared.appearance = .dark
        launch(extraArguments: ["--open-drink=coffee-latte"])
        selectContainer("ceramic-mug")
        setFill(element("amount.fill"), to: 0.67)
        stableCapture("coffee-mug-dark", in: directory)

        try Data("complete".utf8).write(to: directory.appendingPathComponent("COMPLETE"), options: .atomic)
    }

    func testCaptureGoldenSixArtworkReview() throws {
        defer { XCUIDevice.shared.appearance = .light }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SippedGoldenArtworkReview", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let goldenSix: [(slug: String, drinkID: String, containerID: String)] = [
            ("cappuccino-mug", "coffee-cappuccino", "ceramic-mug"),
            ("water-bottle", "water-still", "water-bottle"),
            ("cola-can", "soft-cola", "standard-can"),
            ("lager-pint", "beer-lager", "beer-pint"),
            ("red-wine-glass", "wine-red", "wine-standard"),
            ("smoothie-shake-cup", "smoothie-fruit", "shake-cup")
        ]

        for appearance in ["light", "dark"] {
            XCUIDevice.shared.appearance = appearance == "dark" ? .dark : .light

            launch(seedHistory: true, extraArguments: ["--start-tab=library"])
            XCTAssertTrue(app.buttons["drink.water-still"].waitForExistence(timeout: 5))
            captureGolden("\(appearance)-drink-library", in: directory)

            launch(extraArguments: ["--open-drink=coffee-cappuccino"])
            XCTAssertTrue(app.staticTexts["Choose a container"].waitForExistence(timeout: 5))
            captureGolden("\(appearance)-container-picker", in: directory)

            for subject in goldenSix {
                launch(extraArguments: ["--open-drink=\(subject.drinkID)"])
                selectContainer(subject.containerID)
                let fill = element("amount.fill")
                captureGolden("\(appearance)-\(subject.slug)-0", in: directory)
                setFill(fill, to: 0.5)
                XCTAssertTrue(waitForLabel(element("amount.percentage"), containing: "50%"))
                captureGolden("\(appearance)-\(subject.slug)-50", in: directory)
                setFill(fill, to: 1)
                XCTAssertTrue(waitForLabel(element("amount.percentage"), containing: "100%"))
                captureGolden("\(appearance)-\(subject.slug)-100", in: directory)
            }
        }

        launch(extraArguments: [
            "--force-reduce-motion",
            "--open-drink=soft-cola"
        ])
        selectContainer("standard-can")
        setFill(element("amount.fill"), to: 0.5)
        XCTAssertTrue(waitForLabel(element("amount.percentage"), containing: "50%"))
        captureGolden("reduce-motion-cola-can-50", in: directory)

        try Data("complete".utf8).write(to: directory.appendingPathComponent("COMPLETE"), options: .atomic)
    }

    func testCaptureWallThicknessReview() throws {
        defer { XCUIDevice.shared.appearance = .light }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SippedWallThicknessReview", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let families: [(slug: String, drinkID: String, containerID: String)] = [
            ("ceramic-mug", "coffee-latte", "ceramic-mug"),
            ("water-bottle", "water-still", "water-bottle"),
            ("sports-bottle", "water-still", "sports-bottle"),
            ("soft-drink-bottle", "soft-cola", "soft-bottle"),
            ("standard-can", "soft-cola", "standard-can"),
            ("beer-stein", "beer-lager", "beer-stein"),
            ("wine-glass", "wine-red", "wine-standard"),
            ("champagne-flute", "wine-white", "champagne-flute"),
            ("martini-glass", "spirits-gin", "martini-glass")
        ]

        for appearance in ["light", "dark"] {
            XCUIDevice.shared.appearance = appearance == "dark" ? .dark : .light

            launch(seedHistory: true, extraArguments: ["--start-tab=library"])
            XCTAssertTrue(app.segmentedControls.firstMatch.waitForExistence(timeout: 5))
            app.segmentedControls.firstMatch.buttons["Containers"].tap()
            waitForText("Container library")
            captureGolden("\(appearance)-container-cards", in: directory)

            for family in families {
                launch(extraArguments: ["--open-drink=\(family.drinkID)"])
                selectContainer(family.containerID)
                let fill = element("amount.fill")
                setFill(fill, to: 0.65)
                XCTAssertTrue(waitForLabel(element("amount.percentage"), containing: "65%"))
                captureGolden("\(appearance)-\(family.slug)-65", in: directory)
            }
        }

        XCUIDevice.shared.appearance = .light
        launch(extraArguments: ["--open-drink=wine-red"])
        selectContainer("wine-standard")
        let wineFill = element("amount.fill")
        captureGolden("light-wine-glass-0", in: directory)
        setFill(wineFill, to: 1)
        XCTAssertTrue(waitForLabel(element("amount.percentage"), containing: "100%"))
        captureGolden("light-wine-glass-100", in: directory)

        launch(extraArguments: ["--open-drink=water-still"])
        selectContainer("water-bottle")
        let bottleFill = element("amount.fill")
        captureGolden("light-water-bottle-0", in: directory)
        setFill(bottleFill, to: 1)
        XCTAssertTrue(waitForLabel(element("amount.percentage"), containing: "100%"))
        captureGolden("light-water-bottle-100", in: directory)

        try Data("complete".utf8).write(to: directory.appendingPathComponent("COMPLETE"), options: .atomic)
    }

    private func launch(skipOnboarding: Bool = true, seedHistory: Bool = false, extraArguments: [String] = []) {
        if app.state != .notRunning { app.terminate() }
        var arguments = ["--ui-testing", "--now=2026-07-16T02:00:00Z", "--region=AU"]
        if skipOnboarding { arguments.append("--skip-onboarding") }
        if seedHistory { arguments.append("--seed-history") }
        arguments.append(contentsOf: extraArguments)
        app.launchArguments = arguments
        app.launch()
    }

    private func openDrink(_ identifier: String) {
        app.buttons["global.add"].tap()
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 4))
        app.buttons[identifier].tap()
        XCTAssertTrue(app.staticTexts["Choose a container"].waitForExistence(timeout: 4))
    }

    private func selectContainer(_ identifier: String) {
        let container = app.buttons["container.\(identifier)"]
        XCTAssertTrue(container.waitForExistence(timeout: 4), "Missing container: \(identifier)")
        tapWhenHittable(container)
        XCTAssertTrue(element("amount.fill").waitForExistence(timeout: 4))
    }

    private func enterAmount(_ value: String) {
        tapWhenHittable(app.buttons["amount.exact"])
        let field = app.textFields["amount.input"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        tapWhenHittable(field)
        field.press(forDuration: 0.7)
        if app.menuItems["Select All"].waitForExistence(timeout: 1) { app.menuItems["Select All"].tap() }
        field.typeText(value)
        app.keyboards.buttons["Done"].tapIfExists()
        app.buttons["keyboard.done"].tapIfExists()
        app.buttons["Done"].tapIfExists()
        let keyboard = app.keyboards.firstMatch
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: keyboard)
        _ = XCTWaiter.wait(for: [hidden], timeout: 3)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    }

    private func setFill(_ fill: XCUIElement, to fraction: Double) {
        let y = max(0.001, min(0.999, 1 - fraction))
        fill.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    }

    private func tapWhenHittable(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists && element.isHittable { element.tap(); return }
            app.swipeUp()
        }
        XCTFail("Element was not hittable: \(element)")
    }

    private func scrollUntilExists(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.exists { return }
            app.swipeUp()
        }
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func tapLast(_ query: XCUIElementQuery) {
        XCTAssertGreaterThan(query.count, 0)
        query.element(boundBy: max(0, query.count - 1)).tap()
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: element)
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }

    private var inventoryDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(inventoryFolderName, isDirectory: true)
    }

    private func resetInventoryDirectory() throws {
        try? FileManager.default.removeItem(at: inventoryDirectory)
        try FileManager.default.createDirectory(at: inventoryDirectory, withIntermediateDirectories: true)
    }

    private func capture(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        let screenshot = XCUIScreen.main.screenshot()
        do {
            try screenshot.pngRepresentation.write(to: inventoryDirectory.appendingPathComponent(name + ".png"), options: .atomic)
        } catch {
            XCTFail("Could not write inventory screenshot \(name): \(error)", file: file, line: line)
        }
    }

    private func stableCapture(_ name: String, in directory: URL, file: StaticString = #filePath, line: UInt = #line) {
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        do {
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
        } catch {
            XCTFail("Could not write stable screenshot \(name): \(error)", file: file, line: line)
        }
    }

    private func captureGolden(_ name: String, in directory: URL, file: StaticString = #filePath, line: UInt = #line) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        do {
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
        } catch {
            XCTFail("Could not write golden artwork screenshot \(name): \(error)", file: file, line: line)
        }
    }

    private func waitForText(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5), "Missing text: \(text)", file: file, line: line)
    }
}

private extension XCUIElement {
    func tapIfExists() { if exists { tap() } }
}
