// AccountScreenTests.swift
// Purpose: Check native account entry and accessibility without transmitting credentials.
import XCTest

/// Uses the shipped account screen with a side-effect-free preview service in Debug only.
final class AccountScreenTests: XCTestCase {
    @MainActor
    func testSecureEntryAndAccountChoiceAtLargestText() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--account-ui-test", "--dark-ui-test", "--large-text-ui-test"]
        app.launch()
        let email = app.textFields["Email"]
        reveal(email, in: app)
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Sign in"].isEnabled)
        email.tap()
        email.typeText("screen-review@example.test")
        let password = app.secureTextFields["Password"]
        reveal(password, in: app)
        password.tap()
        password.typeText("Synthetic-UI-only-2026")
        XCTAssertEqual(app.secureTextFields.count, 1)
        app.toolbars.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Sign in"].isEnabled)
        let choice = app.switches["Create a new account"]
        reveal(choice, in: app)
        let innerSwitch = choice.switches.firstMatch
        if innerSwitch.exists { innerSwitch.tap() } else { choice.tap() }
        reveal(app.buttons["Create account"], in: app)
        XCTAssertTrue(app.buttons["Create account"].isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(scrollView(in: app).waitForExistence(timeout: 10))
        for _ in 0..<6 {
            if element.exists && element.isHittable { return }
            scrollView(in: app).swipeUp()
        }
    }

    @MainActor
    private func scrollView(in app: XCUIApplication) -> XCUIElement {
        if app.collectionViews.firstMatch.exists { return app.collectionViews.firstMatch }
        return app.scrollViews.firstMatch
    }

    @MainActor
    func testAccountAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--account-ui-test", "--light-ui-test"]
        app.launch()
        XCTAssertTrue(app.textFields["Email"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit { issue in
            print(
                "Account audit: " + issue.compactDescription + ": "
                    + (issue.element?.label ?? "unavailable"))
            return false
        }
    }
}
