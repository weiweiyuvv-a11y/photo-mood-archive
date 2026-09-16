import XCTest

final class ArchiveUITests: XCTestCase {
    @MainActor private func launchAuthorizedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let access = app.buttons["photo-access"]
        if access.waitForExistence(timeout: 3) {
            access.tap()
            let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons["允许完全访问"]
            if allow.waitForExistence(timeout: 5) { allow.tap() }
        }
        XCTAssertTrue(app.buttons["month-picker"].waitForExistence(timeout: 15))
        return app
    }
    @MainActor func testMonthNavigationAndJournalPersistence() throws {
        let app = launchAuthorizedApp()
        let today = app.buttons["today"]
        XCTAssertTrue(today.waitForExistence(timeout: 15))
        today.tap()
        let month = app.buttons["month-picker"]
        XCTAssertTrue(month.waitForExistence(timeout: 15))
        app.buttons["上个月"].tap()
        app.buttons["下个月"].tap()
        today.tap()
        let openDay = app.buttons["open-day"]
        if !openDay.isHittable { app.swipeUp() }
        XCTAssertTrue(openDay.waitForExistence(timeout: 5))
        openDay.tap()
        app.buttons["edit-note"].tap()
        let editor = app.textViews["note-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Archive regression memory")
        app.buttons["完成"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Archive regression memory")).firstMatch.waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        app.tabBars.buttons["手账"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Archive regression memory")).firstMatch.waitForExistence(timeout: 5))
    }
    @MainActor func testMoodAndPhotoViewer() throws {
        let app = launchAuthorizedApp()
        app.buttons["today"].tap()
        let openDay = app.buttons["open-day"]
        if !openDay.isHittable { app.swipeUp() }
        openDay.tap()
        app.buttons["edit-mood"].tap()
        app.buttons["开心"].tap()
        XCTAssertTrue(app.buttons["edit-mood"].label.contains("开心"))
        app.buttons["edit-mood"].tap()
        let clear = app.buttons["清除当天心情"]
        if !clear.isHittable { app.swipeUp() }
        clear.tap()
        XCTAssertTrue(app.buttons["edit-mood"].label.contains("记心情"))
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'photo-'")).firstMatch
        if !photo.isHittable { app.swipeUp() }
        XCTAssertTrue(photo.waitForExistence(timeout: 8))
        photo.tap()
        XCTAssertTrue(app.buttons["分享"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["2 / 3"].waitForExistence(timeout: 5))
        app.buttons["收藏"].tap()
        XCTAssertTrue(app.buttons["已收藏"].waitForExistence(timeout: 5))
        app.buttons["已收藏"].tap()
        XCTAssertTrue(app.buttons["收藏"].waitForExistence(timeout: 5))
        app.buttons["删除"].tap()
        XCTAssertTrue(app.buttons["删除照片"].waitForExistence(timeout: 5))
        app.buttons["取消"].tap()
        app.buttons["关闭"].tap()
        XCTAssertTrue(app.buttons["edit-note"].exists)
    }
    @MainActor func testZDeleteFixtureKeepsJournalAndAdvancesPager() throws {
        let app = launchAuthorizedApp()
        app.buttons["today"].tap()
        let openDay = app.buttons["open-day"]
        if !openDay.isHittable { app.swipeUp() }
        openDay.tap()
        let photo = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'photo-'")).firstMatch
        if !photo.isHittable { app.swipeUp() }
        photo.tap()
        XCTAssertTrue(app.staticTexts["1 / 3"].waitForExistence(timeout: 5))
        app.buttons["删除"].tap()
        app.buttons["删除照片"].tap()
        let systemDelete = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons.matching(NSPredicate(format: "label IN %@", ["删除", "删除照片", "Delete", "Delete Photo"])).firstMatch
        if systemDelete.waitForExistence(timeout: 5) { systemDelete.tap() }
        XCTAssertTrue(app.staticTexts["1 / 2"].waitForExistence(timeout: 10))
        app.buttons["关闭"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'photo-'")).count, 2)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Archive regression memory")).firstMatch.exists)
    }

}
