import Foundation
import Combine

@MainActor
final class MoodArchiveStore: ObservableObject {
    @Published private(set) var moods: [String: Int]
    @Published private(set) var notes: [String: String]
    @Published private(set) var soundtracks: [String: SoundtrackMemory]
    private let defaults: UserDefaults
    private let moodsKey = "archive.moods.v1"
    private let notesKey = "archive.notes.v1"
    private let soundtracksKey = "archive.soundtracks.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        moods = Self.load([String: Int].self, key: moodsKey, defaults: defaults) ?? [:]
        notes = Self.load([String: String].self, key: notesKey, defaults: defaults) ?? [:]
        soundtracks = Self.load([String: SoundtrackMemory].self, key: soundtracksKey, defaults: defaults) ?? [:]
    }

    func moodLevel(for date: Date) -> Int? { moods[date.archiveKey()] }
    func note(for date: Date) -> String { notes[date.archiveKey(), default: ""] }
    func soundtrack(for date: Date) -> SoundtrackMemory { soundtracks[date.archiveKey(), default: .empty] }
    func hasMemory(for date: Date) -> Bool {
        moodLevel(for: date) != nil || !note(for: date).isEmpty || !soundtrack(for: date).isEmpty
    }

    var recordedDates: [Date] {
        Set(moods.keys).union(notes.keys).union(soundtracks.keys)
            .compactMap { ArchiveCalendar.date(from: $0) }.sorted(by: >)
    }

    func setMood(_ level: Int?, for date: Date) {
        moods[date.archiveKey()] = level.map { min(max($0, 0), 8) }
        save(moods, key: moodsKey)
    }

    func setNote(_ note: String, for date: Date) {
        notes[date.archiveKey()] = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        save(notes, key: notesKey)
    }

    func setSoundtrack(_ soundtrack: SoundtrackMemory, for date: Date) {
        soundtracks[date.archiveKey()] = soundtrack.isEmpty ? nil : soundtrack
        save(soundtracks, key: soundtracksKey)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
