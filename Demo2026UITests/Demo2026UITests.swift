//
//  Demo2026UITests.swift
//  TestAppUITests
//
//  Created by Wei Lin on 20/9/2025.
//

import XCTest

final class Demo2026UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTabBarSwitchesBetweenHomeAndSettings() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Easy Life"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Today's Expense"].exists)
        XCTAssertTrue(app.buttons["Scan"].exists)

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 2))

        app.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["Easy Life"].waitForExistence(timeout: 2))
    }

    func testHomeListNavigatesToDetailView() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["Easy Life"].waitForExistence(timeout: 2))

        app.staticTexts["Lunch bowl"].tap()

        XCTAssertTrue(app.staticTexts["Detail Screen"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["You selected: Lunch bowl"].exists)
    }
}
