import SwiftUI

@main
struct PhotoMoodArchiveApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var photoLibrary = PhotoLibraryStore()
    @StateObject private var archiveStore = MoodArchiveStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(photoLibrary)
                .environmentObject(archiveStore)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await photoLibrary.refresh() } }
                }
        }
    }
}
