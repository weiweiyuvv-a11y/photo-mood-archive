import CoreLocation
import Foundation
import SwiftUI

struct MonthTheme: Identifiable, Hashable {
    let id: Int
    let name: String
    let shortName: String
    let hue: Double
    let doodle: DoodleKind

    var baseColor: Color {
        Color(hue: hue / 360, saturation: 0.68, brightness: 0.94)
    }

    var quietColor: Color {
        Color(hue: hue / 360, saturation: 0.18, brightness: 0.98)
    }

    func moodColor(level: Int) -> Color {
        Color(
            hue: hue / 360,
            saturation: 0.24 + Double(level) * 0.07,
            brightness: 0.98 - Double(level) * 0.012
        )
    }
}

enum DoodleKind: String, CaseIterable, Hashable {
    case snow
    case heart
    case sprout
    case rain
    case leaf
    case sun
    case wave
    case peach
    case pencil
    case star
    case moon
    case ribbon
}

struct PhotoAsset: Identifiable, Hashable, Codable {
    let id: String
    let creationDate: Date
    let latitude: Double?
    let longitude: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct SoundtrackMemory: Codable, Equatable {
    var title: String
    var artist: String

    static let empty = SoundtrackMemory(title: "", artist: "")

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct DayCellModel: Identifiable, Hashable {
    let id: String
    let date: Date
    let isInDisplayedMonth: Bool
}

enum ArchiveDesign {
    static let months: [MonthTheme] = [
        .init(id: 1, name: "January", shortName: "Jan", hue: 214, doodle: .snow),
        .init(id: 2, name: "February", shortName: "Feb", hue: 350, doodle: .heart),
        .init(id: 3, name: "March", shortName: "Mar", hue: 48, doodle: .sprout),
        .init(id: 4, name: "April", shortName: "Apr", hue: 202, doodle: .rain),
        .init(id: 5, name: "May", shortName: "May", hue: 336, doodle: .leaf),
        .init(id: 6, name: "June", shortName: "Jun", hue: 52, doodle: .sun),
        .init(id: 7, name: "July", shortName: "Jul", hue: 196, doodle: .wave),
        .init(id: 8, name: "August", shortName: "Aug", hue: 355, doodle: .peach),
        .init(id: 9, name: "September", shortName: "Sep", hue: 44, doodle: .pencil),
        .init(id: 10, name: "October", shortName: "Oct", hue: 206, doodle: .star),
        .init(id: 11, name: "November", shortName: "Nov", hue: 254, doodle: .moon),
        .init(id: 12, name: "December", shortName: "Dec", hue: 344, doodle: .ribbon)
    ]

    static let prismBlue = Color(red: 0.02, green: 0.55, blue: 1.00)
    static let prismRed = Color(red: 1.00, green: 0.04, blue: 0.25)
    static let prismYellow = Color(red: 1.00, green: 0.86, blue: 0.06)
    static let glassLavender = Color(red: 0.78, green: 0.76, blue: 0.88)

    static let ink = Color(red: 0.14, green: 0.13, blue: 0.22)
    static let secondaryInk = Color(red: 0.47, green: 0.45, blue: 0.58)
    static let paper = Color(red: 0.91, green: 0.90, blue: 0.96)
    static let liftedPaper = Color(red: 0.975, green: 0.965, blue: 1.0)
    static let hairline = Color(red: 0.34, green: 0.32, blue: 0.50).opacity(0.14)

    static func moodBlobColor(level: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.63, green: 0.62, blue: 0.78),
            Color(red: 0.35, green: 0.67, blue: 0.96),
            Color(red: 0.02, green: 0.55, blue: 1.00),
            Color(red: 0.98, green: 0.16, blue: 0.36),
            Color(red: 1.00, green: 0.04, blue: 0.25),
            Color(red: 1.00, green: 0.38, blue: 0.14),
            Color(red: 1.00, green: 0.70, blue: 0.05),
            Color(red: 1.00, green: 0.86, blue: 0.06),
            Color(red: 0.57, green: 0.83, blue: 1.00)
        ]
        return palette[min(max(level, 0), palette.count - 1)]
    }

    static func moodRingColor(level: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.48, green: 0.47, blue: 0.62),
            Color(red: 0.30, green: 0.55, blue: 0.78),
            Color(red: 0.02, green: 0.45, blue: 0.86),
            Color(red: 0.78, green: 0.20, blue: 0.38),
            Color(red: 0.86, green: 0.06, blue: 0.22),
            Color(red: 0.90, green: 0.38, blue: 0.14),
            Color(red: 0.88, green: 0.62, blue: 0.10),
            Color(red: 0.92, green: 0.78, blue: 0.10),
            Color(red: 0.35, green: 0.65, blue: 0.86)
        ]
        return palette[min(max(level, 0), palette.count - 1)]
    }

    static func theme(for date: Date, calendar: Calendar = .current) -> MonthTheme {
        let month = calendar.component(.month, from: date)
        return months[month - 1]
    }
}

extension Date {
    func archiveKey(calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: self)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
