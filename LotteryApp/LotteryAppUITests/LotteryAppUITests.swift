import XCTest

final class LotteryAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSidebarDestinationsAndPrimaryControlsExist() throws {
        let app = XCUIApplication()
        app.launch()

        try requireAccessibleWindow(in: app)

        select("sidebar_verify", in: app)
        XCTAssertTrue(app.buttons["chooseImageButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["recognizeTicketButton"].exists)
        XCTAssertTrue(app.buttons["verifyTicketButton"].exists)
        XCTAssertFalse(app.buttons["复式/胆拖（开发中）"].exists)
        XCTAssertFalse(app.staticTexts["复式/胆拖（开发中）"].exists)

        select("sidebar_tickets", in: app)
        XCTAssertTrue(app.windows.firstMatch.exists)

        select("sidebar_results", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["categoryFilterPicker"].waitForExistence(timeout: 2))

        select("sidebar_stats", in: app)
        XCTAssertTrue(app.windows.firstMatch.exists)

        select("sidebar_settings", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["webServiceEnabledToggle"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["保存"].exists)
    }

    @MainActor
    func testVerifyButtonRequiresEditableTicketNumbers() throws {
        let app = XCUIApplication()
        app.launch()

        try requireAccessibleWindow(in: app)
        select("sidebar_verify", in: app)

        let verifyButton = app.buttons["verifyTicketButton"]
        XCTAssertTrue(verifyButton.waitForExistence(timeout: 2))
        XCTAssertFalse(verifyButton.isEnabled)

        app.textFields["issueField"].click()
        app.textFields["issueField"].typeText("2026001")
        app.textFields["frontNumbersField"].click()
        app.textFields["frontNumbersField"].typeText("01 02 03 04 05 06")
        app.textFields["backNumbersField"].click()
        app.textFields["backNumbersField"].typeText("07")

        XCTAssertTrue(verifyButton.isEnabled)
    }

    @MainActor
    private func select(_ identifier: String, in app: XCUIApplication) {
        let item = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(item.waitForExistence(timeout: 4), "Missing sidebar item: \(identifier)")
        item.click()
    }

    @MainActor
    private func requireAccessibleWindow(in app: XCUIApplication) throws {
        if !app.windows.firstMatch.waitForExistence(timeout: 5) {
            throw XCTSkip("The app launched, but this macOS runner did not expose an accessible window.")
        }
    }
}
