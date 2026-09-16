import XCTest
import Photos
import UIKit
@testable import PhotoMoodArchive

final class ArchiveTests: XCTestCase {
    func testLeapMonthAndMondayAlignment() throws {
        let month = try XCTUnwrap(ArchiveCalendar.date(from: "2024-02-01"))
        let days = ArchiveCalendar.days(in: month)
        XCTAssertEqual(days.prefix(while: { $0 == nil }).count, 3)
        XCTAssertEqual(days.compactMap { $0 }.count, 29)
        XCTAssertEqual(days.compactMap { $0 }.last?.archiveKey(), "2024-02-29")
    }
    func testYearBoundaryAndInvalidDate() throws {
        let date = try XCTUnwrap(ArchiveCalendar.date(from: "2025-12-31"))
        XCTAssertEqual(ArchiveCalendar.moving(date, months: 1).archiveKey(), "2026-01-01")
        XCTAssertEqual(ArchiveCalendar.moving(date, months: -12).archiveKey(), "2024-12-01")
        XCTAssertNil(ArchiveCalendar.date(from: "2025-02-29"))
        XCTAssertNil(ArchiveCalendar.date(from: "garbage"))
    }
    func testFiltersDoNotLoseNonCameraPhotos() {
        let photo = PhotoAsset(id: "download", creationDate: Date(), latitude: nil, longitude: nil)
        let screenshot = PhotoAsset(id: "screen", creationDate: Date(), latitude: nil, longitude: nil, isScreenshot: true)
        XCTAssertTrue(PhotoFilter.memories.includes(photo, favorite: false))
        XCTAssertFalse(PhotoFilter.memories.includes(screenshot, favorite: false))
        XCTAssertTrue(PhotoFilter.all.includes(screenshot, favorite: false))
        XCTAssertTrue(PhotoFilter.screenshots.includes(screenshot, favorite: false))
        XCTAssertFalse(PhotoFilter.favorites.includes(photo, favorite: false))
        XCTAssertTrue(PhotoFilter.favorites.includes(photo, favorite: true))
    }
    @MainActor func testLegacyPersistenceAndClearing() throws {
        let suite = "ArchiveTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let date = try XCTUnwrap(ArchiveCalendar.date(from: "2026-05-06"))
        defaults.set(try JSONEncoder().encode(["2026-05-06": 8]), forKey: "archive.moods.v1")
        defaults.set(try JSONEncoder().encode(["2026-05-06": "旧版的回忆"]), forKey: "archive.notes.v1")
        let store = MoodArchiveStore(defaults: defaults)
        XCTAssertEqual(store.moodLevel(for: date), 8)
        XCTAssertEqual(store.note(for: date), "旧版的回忆")
        store.setNote("新增\n第二行", for: date)
        store.setSoundtrack(SoundtrackMemory(title: "晴天", artist: "周杰伦"), for: date)
        let reopened = MoodArchiveStore(defaults: defaults)
        XCTAssertEqual(reopened.note(for: date), "新增\n第二行")
        XCTAssertEqual(reopened.soundtrack(for: date).title, "晴天")
        XCTAssertEqual(reopened.recordedDates.map { $0.archiveKey() }, ["2026-05-06"])
        reopened.setMood(nil, for: date)
        reopened.setNote(" \n ", for: date)
        reopened.setSoundtrack(.empty, for: date)
        XCTAssertFalse(reopened.hasMemory(for: date))
        XCTAssertTrue(reopened.recordedDates.isEmpty)
    }
    @MainActor func testNotesExistWithoutPhotosAndMoodBounds() throws {
        let suite = "ArchiveTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MoodArchiveStore(defaults: defaults)
        let date = Date()
        store.setNote("没有照片的一天", for: date)
        store.setMood(100, for: date)
        XCTAssertEqual(store.moodLevel(for: date), 8)
        XCTAssertEqual(store.recordedDates.count, 1)
        store.setMood(-4, for: date)
        XCTAssertEqual(store.moodLevel(for: date), 0)
    }
    @MainActor func testRealPhotoKitRefreshFavoriteAndDateChange() async throws {
        #if targetEnvironment(simulator)
        guard PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized else {
            throw XCTSkip("Grant Photos access to the app in the disposable test simulator first.")
        }
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            UIColor.systemTeal.setFill(); context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        }
        let beforeResult = PHAsset.fetchAssets(with: .image, options: nil)
        let before = Set(beforeResult.objects(at: IndexSet(integersIn: 0..<beforeResult.count)).map(\.localIdentifier))
        let originalDate = try XCTUnwrap(ArchiveCalendar.date(from: "2024-02-29"))
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            PHAssetChangeRequest.creationRequestForAsset(from: image).creationDate = originalDate
        }
        let library = PhotoLibraryStore()
        await library.refresh()
        let photo = try XCTUnwrap(library.allAssets.first { !before.contains($0.id) })
        XCTAssertEqual(photo.creationDate.archiveKey(), "2024-02-29")
        await library.toggleFavorite(photo)
        XCTAssertTrue(library.isFavorite(photo))
        // An observer refresh invalidates in-flight images; the SwiftUI view retries
        // using its revision task ID. Exercise the same documented retry contract.
        var fetched: UIImage?
        for _ in 0..<5 {
            do {
                fetched = try await library.image(for: photo, size: CGSize(width: 80, height: 80))
                break
            } catch is CancellationError {
                try await Task.sleep(for: .milliseconds(80))
            }
        }
        XCTAssertGreaterThan(try XCTUnwrap(fetched).size.width, 0)
        let changedDate = try XCTUnwrap(ArchiveCalendar.date(from: "2026-01-01"))
        let asset = try XCTUnwrap(PHAsset.fetchAssets(withLocalIdentifiers: [photo.id], options: nil).firstObject)
        try await PHPhotoLibrary.shared().performChanges { @Sendable in PHAssetChangeRequest(for: asset).creationDate = changedDate }
        await library.refresh()
        // Coalesced observer refreshes may still be settling after performChanges.
        while library.isLoading { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertFalse(library.assets(for: originalDate).contains { $0.id == photo.id })
        XCTAssertTrue(library.assets(for: changedDate).contains { $0.id == photo.id })
        #else
        throw XCTSkip("Photo mutation integration tests run only in a disposable simulator.")
        #endif
    }
}
