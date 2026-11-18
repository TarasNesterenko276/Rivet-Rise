import XCTest

/// Walks every screen and keeps full-resolution screenshots as attachments
/// (exported for the website and the store listing with `xcresulttool export attachments`).
final class ScreenshotTourTests: RivetRiseUITestCase {
    @MainActor
    func testTourEveryScreen() {
        launch(["--history", "--autopilot"])
        shoot("01-site")

        ride(to: "yard", expecting: "yard.screen")
        element("yard.hoist.boom").tap()
        waitForToast(prefix: "Long Boom is now level 1")
        XCTAssertTrue(element("toast").waitForNonExistence(timeout: 5))
        shoot("02-rigging-yard")
        rideDown()

        ride(to: "lockers", expecting: "lockers.screen")
        element("lockers.foreman.dolores").tap()
        shoot("03-crew-lockers")
        rideDown()

        ride(to: "log", expecting: "log.screen")
        shoot("04-site-log")
        rideDown()

        ride(to: "manual", expecting: "manual.screen")
        element("manual.next").tap()
        element("manual.next").tap()
        shoot("05-manual-rivet")
        rideDown()

        ride(to: "board", expecting: "board.screen")
        XCTAssertTrue(rankOneRow().waitForExistence(timeout: 8))
        shoot("06a-top-players")
        rideDown()

        ride(to: "office", expecting: "office.screen")
        shoot("06-site-office")
        rideDown()

        element("site.clockIn").tap()
        XCTAssertTrue(element("game.start").waitForExistence(timeout: 6))
        shoot("07-briefing")
        element("game.start").tap()
        XCTAssertTrue(waitForHittable(element("game.pause"), timeout: 12))
        sleep(14)
        shoot("08-shift-early")
        sleep(16)
        shoot("09-shift-mid")
        sleep(16)
        shoot("10-shift-high")
        XCTAssertTrue(element("game.envelope").waitForExistence(timeout: 240))
        sleep(2)
        shoot("11-pay-envelope")
    }

    private func shoot(_ name: String) {
        // Let springs and fades settle.
        usleep(600_000)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
