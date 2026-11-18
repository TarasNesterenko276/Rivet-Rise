import XCTest

/// Shared launch and lookup helpers. The app runs with `--uitesting`: in-memory save,
/// silent audio, manual marked as read and 1,000 bolts seeded.
class RivetRiseUITestCase: XCTestCase {
    var app: XCUIApplication!

    func launch(_ extra: [String] = []) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + extra
        app.launch()
        XCTAssertTrue(element("site.screen").waitForExistence(timeout: 10), "Site did not appear")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func waitFor(_ identifier: String, timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(identifier).waitForExistence(timeout: timeout), "Expected \(identifier)", file: file, line: line)
    }

    func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Digits of an element's value or label, so "1.000" and "1,000" compare the same.
    func digits(_ element: XCUIElement) -> Int? {
        let text = (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
        return Int(text.filter(\.isNumber))
    }

    /// Presses a hoist pendant button and waits for the section.
    func ride(to floor: String, expecting screen: String) {
        let button = element("pendant.\(floor)")
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Pendant button \(floor) missing")
        button.tap()
        waitFor(screen)
    }

    func rideDown() {
        let ground = element("hoist.ground")
        XCTAssertTrue(ground.waitForExistence(timeout: 3))
        ground.tap()
        XCTAssertTrue(ground.waitForNonExistence(timeout: 4), "Hoist did not come down")
    }

    func waitForToast(prefix: String, file: StaticString = #filePath, line: UInt = #line) {
        // One query for identifier and text avoids racing the toast's own dismissal.
        let toast = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ AND label BEGINSWITH %@", "toast", prefix))
            .firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5), "No toast starting with '\(prefix)'", file: file, line: line)
    }

    /// The first row of the web board, rendered from the JSON payload by the HTML template.
    func rankOneRow() -> XCUIElement {
        app.webViews.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Rank 1,")).firstMatch
    }

    /// Clocks in from the site and waits until the countdown is over.
    func startShift() {
        element("site.clockIn").tap()
        waitFor("game.screen")
        let start = element("game.start")
        XCTAssertTrue(start.waitForExistence(timeout: 6))
        start.tap()
        // The 3-2-1 countdown can finish while XCUITest waits for the animating scene to idle,
        // so the shift counts as started once the pause button is tappable.
        XCTAssertTrue(start.waitForNonExistence(timeout: 6), "Briefing never closed")
        XCTAssertTrue(waitForHittable(element("game.pause"), timeout: 12), "Shift never started")
    }
}

final class RivetRiseUITests: RivetRiseUITestCase {
    // MARK: - Site

    @MainActor
    func testSiteShowsTheClockAndEveryPendantButton() {
        launch()
        for id in ["site.clockIn", "site.bolts", "site.best", "site.foreman", "pendant.yard", "pendant.lockers", "pendant.log", "pendant.manual", "pendant.office", "pendant.board"] {
            XCTAssertTrue(element(id).exists, "\(id) missing")
        }
        XCTAssertEqual(digits(element("site.bolts")), 1_000)
    }

    @MainActor
    func testHoistRidesToEveryFloorAndBack() {
        launch()
        ride(to: "yard", expecting: "yard.screen")
        rideDown()
        ride(to: "lockers", expecting: "lockers.screen")
        rideDown()
        ride(to: "log", expecting: "log.screen")
        rideDown()
        ride(to: "manual", expecting: "manual.screen")
        rideDown()
        ride(to: "office", expecting: "office.screen")
        rideDown()
        ride(to: "board", expecting: "board.screen")
        rideDown()
        // The foreman tag is a shortcut to the lockers.
        element("site.foreman").tap()
        waitFor("lockers.screen")
        rideDown()
    }

    // MARK: - Rigging yard

    @MainActor
    func testHoistingAnUpgradeSpendsBolts() {
        launch()
        ride(to: "yard", expecting: "yard.screen")
        let level = element("yard.level.rivetGun")
        XCTAssertEqual(level.label, "Level 0 of 5")
        element("yard.hoist.rivetGun").tap()
        waitForToast(prefix: "Rivet Gun is now level 1")
        XCTAssertEqual(level.label, "Level 1 of 5")
        rideDown()
        XCTAssertEqual(digits(element("site.bolts")), 1_000 - 60)
    }

    @MainActor
    func testHoistingIsRefusedWithoutBolts() {
        launch(["--broke"])
        ride(to: "yard", expecting: "yard.screen")
        element("yard.hoist.rivetGun").tap()
        waitForToast(prefix: "You need 60 more bolts")
        XCTAssertEqual(element("yard.level.rivetGun").label, "Level 0 of 5")
    }

    // MARK: - Crew lockers

    @MainActor
    func testHiringAForemanAndPuttingGusBack() {
        launch()
        ride(to: "lockers", expecting: "lockers.screen")
        element("lockers.foreman.mira").tap()
        XCTAssertEqual(element("lockers.selectedName").label, "Mira")
        element("lockers.action").tap()
        waitForToast(prefix: "Mira joined the crew")
        element("lockers.foreman.gus").tap()
        XCTAssertTrue(element("lockers.action").label.localizedCaseInsensitiveContains("put in the cab"))
        element("lockers.action").tap()
        waitForToast(prefix: "Gus is in the cab")
        rideDown()
        XCTAssertEqual(digits(element("site.bolts")), 1_000 - 400)
        XCTAssertTrue(element("site.foreman").label.contains("Gus"))
    }

    @MainActor
    func testExpensiveForemanCannotBeHired() {
        launch()
        ride(to: "lockers", expecting: "lockers.screen")
        let ola = element("lockers.foreman.ola")
        // The lockers sit in a horizontal row; Ola's is the last one, off screen on iPhone.
        // (Querying hittability of an off-screen element throws, so scroll unconditionally.)
        element("lockers.foreman.mira").swipeLeft()
        element("lockers.foreman.kenji").swipeLeft()
        ola.tap()
        element("lockers.action").tap()
        waitForToast(prefix: "You need")
        XCTAssertEqual(digits(element("lockers.selectedName")), nil)
        XCTAssertEqual(element("lockers.selectedName").label, "Ola")
    }

    // MARK: - Site log

    @MainActor
    func testEmptyLogThenHistory() {
        launch()
        ride(to: "log", expecting: "log.screen")
        XCTAssertTrue(element("log.empty").waitForExistence(timeout: 3))
        app.terminate()

        launch(["--history"])
        ride(to: "log", expecting: "log.screen")
        XCTAssertFalse(element("log.empty").exists)
        XCTAssertEqual(digits(element("log.bestScore")), 2_240)
        XCTAssertTrue(element("log.stickers").exists)
    }

    // MARK: - Manual and office

    @MainActor
    func testManualPagesThroughToTheEnd() {
        launch()
        ride(to: "manual", expecting: "manual.screen")
        for _ in 0..<6 {
            let next = element("manual.next")
            XCTAssertTrue(next.waitForExistence(timeout: 3))
            next.tap()
        }
        let done = element("manual.done")
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
        XCTAssertTrue(element("manual.screen").waitForNonExistence(timeout: 4))
    }

    @MainActor
    func testFirstClockInShowsTheManualThenTheShift() {
        launch(["--show-manual"])
        element("site.clockIn").tap()
        waitFor("manual.screen")
        for _ in 0..<6 { element("manual.next").tap() }
        element("manual.done").tap()
        waitFor("game.screen")
        XCTAssertTrue(element("game.start").waitForExistence(timeout: 6))
    }

    @MainActor
    func testResetProgressClearsBolts() {
        launch()
        ride(to: "office", expecting: "office.screen")
        element("office.reset").tap()
        let confirm = app.buttons.matching(identifier: "office.resetConfirm").firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        waitForToast(prefix: "The site is cleared")
        rideDown()
        XCTAssertEqual(digits(element("site.bolts")), 0)
    }

    @MainActor
    func testBreakersToggle() {
        launch()
        ride(to: "office", expecting: "office.screen")
        let sound = element("office.sound")
        let before = sound.value as? String
        sound.tap()
        XCTAssertNotEqual(sound.value as? String, before)
    }

    // MARK: - Top players

    @MainActor
    func testTopPlayersShowsTheBoardAndPaysAWeeklyOrder() {
        // Without shifts this week, orders refuse politely.
        launch()
        ride(to: "board", expecting: "board.screen")
        XCTAssertTrue(element("board.web").waitForExistence(timeout: 5))
        // The bundled HTML template renders the mock top 5.
        XCTAssertTrue(rankOneRow().waitForExistence(timeout: 8), "Web board did not render")
        XCTAssertTrue(element("board.league").label.contains("League"))
        app.segmentedControls.buttons.element(boundBy: 1).tap()
        waitFor("board.orders")
        element("board.order.rivets40").buttons.firstMatch.tap()
        waitForToast(prefix: "This site order is not finished")
        app.terminate()

        // The seeded history drove 70 rivets this week, so "Rivet Crew" is ready to collect.
        launch(["--history"])
        ride(to: "board", expecting: "board.screen")
        app.segmentedControls.buttons.element(boundBy: 1).tap()
        let rivetOrder = element("board.order.rivets40")
        XCTAssertTrue(rivetOrder.waitForExistence(timeout: 4))
        // The hi-vis button style uppercases its text, so compare case-insensitively.
        let collect = rivetOrder.buttons.firstMatch
        XCTAssertEqual((collect.value as? String)?.lowercased(), "ready")
        collect.tap()
        waitForToast(prefix: "Rivet Crew paid")
        XCTAssertFalse(rivetOrder.buttons.firstMatch.exists, "A paid order shows a label, not a button")
        rideDown()
        XCTAssertEqual(digits(element("site.bolts")), 1_000 + 120)
    }

    // MARK: - Shift

    @MainActor
    func testBriefingCanBeLeft() {
        launch()
        element("site.clockIn").tap()
        waitFor("game.start")
        element("game.leave").tap()
        XCTAssertTrue(element("game.screen").waitForNonExistence(timeout: 5))
        waitFor("site.screen")
    }

    @MainActor
    func testStartPauseResumeAndClockOut() {
        launch()
        startShift()
        let pause = element("game.pause")
        XCTAssertTrue(waitForHittable(pause), "Pause never became tappable")
        // Drop one module so the shift is under way.
        element("game.tapArea").tap()
        pause.tap()
        waitFor("game.resume")
        element("game.resume").tap()
        XCTAssertTrue(waitForHittable(pause))
        pause.tap()
        element("game.quit").tap()
        XCTAssertTrue(element("game.screen").waitForNonExistence(timeout: 5))
        waitFor("site.screen")
    }

    @MainActor
    func testWithoutInputTheHookKeepsSwingingAndNothingLands() {
        launch()
        startShift()
        XCTAssertTrue(waitForHittable(element("game.pause")))
        sleep(3)
        XCTAssertEqual(digits(element("hud.floors")), 0)
        XCTAssertEqual(digits(element("hud.score")), 0)
    }

    @MainActor
    func testAutopilotShiftEndsWithAPayEnvelope() {
        launch(["--autopilot"])
        startShift()
        XCTAssertTrue(element("game.envelope").waitForExistence(timeout: 240), "The shift never ended")
        element("game.toYard").tap()
        waitFor("yard.screen")
        XCTAssertGreaterThan(digits(element("yard.screen").descendants(matching: .any)["Bolts"].firstMatch) ?? 0, 1_000)
    }
}
