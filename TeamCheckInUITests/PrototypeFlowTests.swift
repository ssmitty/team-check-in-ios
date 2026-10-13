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
        XCTAssertTrue(app.staticTexts["Check-in shared in demo"].waitForExistence(timeout: 5))
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
    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 3)
        for _ in 0..<10 {
            if element.exists && element.isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
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
