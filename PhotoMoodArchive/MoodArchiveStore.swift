import Foundation

@MainActor
final class MoodArchiveStore: ObservableObject {
    @Published private(set) var moods: [String: Int]
    @Published private(set) var notes: [String: String]
    @Published private(set) var soundtracks: [String: SoundtrackMemory]

    private let moodsKey = "archive.moods.v1"
    private let notesKey = "archive.notes.v1"
    private let soundtracksKey = "archive.soundtracks.v1"

    init() {
        moods = Self.load([String: Int].self, key: moodsKey) ?? [:]
        notes = Self.load([String: String].self, key: notesKey) ?? [:]
        soundtracks = Self.load([String: SoundtrackMemory].self, key: soundtracksKey) ?? [:]
    }

    func moodLevel(for date: Date) -> Int? {
        moods[date.archiveKey()]
    }

    func note(for date: Date) -> String {
        notes[date.archiveKey(), default: ""]
    }

    func soundtrack(for date: Date) -> SoundtrackMemory {
        soundtracks[date.archiveKey(), default: .empty]
    }

    func setMood(_ level: Int, for date: Date) {
        moods[date.archiveKey()] = level
        save(moods, key: moodsKey)
    }

    func setNote(_ note: String, for date: Date) {
        notes[date.archiveKey()] = note
        save(notes, key: notesKey)
    }

    func setSoundtrack(_ soundtrack: SoundtrackMemory, for date: Date) {
        let key = date.archiveKey()
        if soundtrack.isEmpty {
            soundtracks.removeValue(forKey: key)
        } else {
            soundtracks[key] = soundtrack
        }
        save(soundtracks, key: soundtracksKey)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
