// PrototypeFlowTests.swift
// Purpose: Exercise the labeled simulator demo and accessibility audit without real accounts or photos.
import XCTest

final class PrototypeFlowTests: XCTestCase {
    @MainActor
    func testOptionalCheckInAndWarmupAcknowledgment() throws {
        continueAfterFailure = false
        let app = demoApp()
        completeCheckIn(in: app)
        tap(app.buttons["View teammate responses"], in: app)
        tap(app.buttons["Find me at warmups"], in: app)
        XCTAssertTrue(app.staticTexts["Warmup request sent in demo"].waitForExistence(timeout: 5))
        tap(app.buttons["Simulate Jordan: I'll find you"], in: app)
        XCTAssertTrue(app.staticTexts["Jordan will find you."].exists)
    }

    @MainActor
    func testCaptainCanAddEditAndCancelDemoGame() throws {
        continueAfterFailure = false
        let app = demoApp()
        tap(app.buttons["Join demo team"], in: app)
        tap(app.tabBars.buttons["Team"], in: app)
        let captain = app.switches["Captain demo"]
        tap(captain.switches.firstMatch, in: app)
        XCTAssertEqual(captain.value as? String, "1")
        scrollView(in: app).swipeDown()
        scrollView(in: app).swipeDown()
        tap(app.buttons["Add game"], in: app)
        let title = app.textFields["Opponent or game title"]
        tap(title, in: app)
        title.typeText("Review match")
        tap(app.buttons["Save"], in: app)
        XCTAssertTrue(app.staticTexts["Review match"].waitForExistence(timeout: 5))
        let row = app.cells.containing(.staticText, identifier: "Review match").firstMatch
        tap(row.buttons["Edit"], in: app)
        let location = app.textFields["Meeting location (optional)"]
        tap(location, in: app)
        location.typeText("North entrance")
        tap(app.buttons["Save"], in: app)
        tap(row.buttons["Edit"], in: app)
        XCTAssertEqual(location.value as? String, "North entrance")
        tap(app.buttons["Close"], in: app)
        tap(row.buttons["Cancel"], in: app)
        tap(app.buttons["Cancel game"], in: app)
        XCTAssertTrue(row.staticTexts["Canceled"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWelcomeAccessibilityAudit() throws {
        continueAfterFailure = false
        let app = demoApp()
        XCTAssertTrue(app.buttons["Join demo team"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit { issue in
            print(
                "Accessibility audit: " + issue.compactDescription + ": "
                    + (issue.element?.label ?? "unavailable element"))
            return false
        }
    }

    @MainActor
    func testLargeTextDarkCheckInIsReachable() throws {
        continueAfterFailure = false
        let app = demoApp(dark: true, large: true)
        completeCheckIn(in: app)
        let frame = XCTAttachment(screenshot: app.screenshot())
        frame.lifetime = .keepAlways
        add(frame)
    }

    @MainActor
    private func completeCheckIn(in app: XCUIApplication) {
        tap(app.buttons["Join demo team"], in: app)
        tap(app.buttons["Start check-in"], in: app)
        tap(app.buttons["feeling.Nervous"], in: app)
        tap(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", "Encouragement")
            ).firstMatch, in: app)
        tap(app.buttons["Share check-in"], in: app)
        let shared = app.staticTexts["Check-in shared in demo"]
        for _ in 0..<5 {
            if shared.exists { break }
            scrollView(in: app).swipeUp()
        }
        XCTAssertTrue(shared.waitForExistence(timeout: 5))
    }

    @MainActor
    private func demoApp(dark: Bool = false, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-ui-test", dark ? "--dark-ui-test" : "--light-ui-test"]
        if large { app.launchArguments.append("--large-text-ui-test") }
        app.launch()
        return app
    }

    @MainActor
    private func scrollView(in app: XCUIApplication) -> XCUIElement {
        if app.collectionViews.firstMatch.exists { return app.collectionViews.firstMatch }
        return app.scrollViews.firstMatch
    }

    @MainActor
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 3)
        for _ in 0..<10 {
            if element.exists && element.isHittable { break }
            scrollView(in: app).swipeUp()
        }
        if !element.exists {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCTAssertTrue(element.exists, "Expected control is available")
        XCTAssertTrue(element.isHittable, "Expected control is reachable")
        element.tap()
    }
}
