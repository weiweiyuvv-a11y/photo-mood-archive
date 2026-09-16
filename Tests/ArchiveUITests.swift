import XCTest

final class ArchiveUITests: XCTestCase {
    @MainActor private func openToday() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons.matching(
            NSPredicate(format: "label IN %@", ["允许完全访问", "Allow Full Access"])
        ).firstMatch
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        XCTAssertTrue(app.buttons["Timeline"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Trail"].exists)
        XCTAssertFalse(app.tabBars.buttons["手账"].exists)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let day = app.buttons["archive-day-" + formatter.string(from: Date())]
        XCTAssertTrue(day.waitForExistence(timeout: 15))
        day.tap()
        XCTAssertTrue(app.buttons["add-memory"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func testOriginalUIAndNotePersistence() throws {
        let app = openToday()
        app.buttons["add-memory"].tap()
        app.buttons["Add note"].tap()
        let note = app.textViews["archive-note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText(" Original UI data check")
        app.buttons["Done"].tap()
        app.terminate()
        let reopened = openToday()
        reopened.buttons["add-memory"].tap()
        reopened.buttons["Add note"].tap()
        let saved = reopened.textViews["archive-note"]
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue((saved.value as? String ?? "").contains("Original UI data check"))
        reopened.buttons["Done"].tap()
    }

    @MainActor func testOriginalPhotoViewerFavorite() throws {
        let app = openToday()
        let photo = app.buttons["open-photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.tap()
        let favorite = app.buttons["Favorite"]
        let favorited = app.buttons["Favorited"]
        if favorited.waitForExistence(timeout: 2) { favorited.tap() }
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()
        XCTAssertTrue(favorited.waitForExistence(timeout: 5))
        favorited.tap()
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Delete"].exists)
    }
}
