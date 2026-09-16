import SwiftUI

@main
struct PhotoMoodArchiveApp: App {
    @StateObject private var photoLibrary = PhotoLibraryStore()
    @StateObject private var archiveStore = MoodArchiveStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoLibrary)
                .environmentObject(archiveStore)
        }
    }
}
