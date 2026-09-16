import SwiftUI

struct MoodDoodleView: View {
    let theme: MonthTheme
    let moodLevel: Int?
    var colorOverride: Color? = nil
    private var color: Color {
        colorOverride ?? moodLevel.map { ArchiveDesign.moodBlobColor(level: $0) } ?? theme.quietColor
    }
    private var symbol: String {
        switch theme.doodle {
        case .snow: "snowflake"
        case .heart: "heart"
        case .sprout: "leaf"
        case .rain: "cloud.rain"
        case .leaf: "leaf"
        case .sun: "sun.max"
        case .wave: "water.waves"
        case .peach: "sun.haze"
        case .pencil: "pencil"
        case .star: "star"
        case .moon: "moon"
        case .ribbon: "gift"
        }
    }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: geometry.size.width * 0.32)
                    .fill(color.opacity(0.22)).rotationEffect(.degrees(-8))
                Image(systemName: symbol)
                    .font(.system(size: geometry.size.width * 0.4, weight: .light))
                    .foregroundStyle(color.opacity(0.9))
            }.padding(4)
        }
        .accessibilityLabel(moodLevel.map(MoodLabel.name) ?? "未记录心情")
    }
}
