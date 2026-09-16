import SwiftUI

struct CalendarMonthView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let filter: PhotoFilter
    @EnvironmentObject private var library: PhotoLibraryStore
    @EnvironmentObject private var archive: MoodArchiveStore
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { day in
                    Text(day).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 9) {
                ForEach(Array(ArchiveCalendar.days(in: displayedMonth).enumerated()), id: \.offset) { _, date in
                    if let date { dayCell(date) }
                    else { Color.clear.frame(minHeight: 52).accessibilityHidden(true) }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let photos = library.assets(for: date, filter: filter)
        let selected = ArchiveCalendar.calendar.isDate(date, inSameDayAs: selectedDate)
        let today = ArchiveCalendar.calendar.isDateInToday(date)
        let mood = archive.moodLevel(for: date)
        return Button { selectedDate = date } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemFill).opacity(0.45))
                    if let photo = photos.first {
                        PhotoThumbnailView(photo: photo, size: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text("\(ArchiveCalendar.calendar.component(.day, from: date))")
                        .font(.system(.callout, design: .rounded, weight: selected || today ? .bold : .medium))
                        .foregroundStyle(photos.isEmpty ? Color.primary : .white)
                        .shadow(color: photos.isEmpty ? .clear : .black.opacity(0.8), radius: 3)
                        .padding(7)
                    if today {
                        Circle().fill(ArchiveDesign.accent).frame(width: 5, height: 5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(7)
                    }
                }
                .aspectRatio(0.88, contentMode: .fit)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? ArchiveDesign.accent : .clear, lineWidth: 2.5))
                HStack(spacing: 3) {
                    if let mood { Circle().fill(ArchiveDesign.moodBlobColor(level: mood)).frame(width: 5, height: 5) }
                    if archive.hasMemory(for: date) { Capsule().fill(Color.secondary.opacity(0.5)).frame(width: 9, height: 3) }
                }.frame(height: 5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ArchiveCalendar.title(date, format: "M月d日"))，\(photos.count) 张照片\(mood.map { "，" + MoodLabel.name($0) } ?? "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("day-\(date.archiveKey())")
    }
}

extension ArchiveDesign {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.78, blue: 0.67, alpha: 1)
            : UIColor(red: 0.19, green: 0.43, blue: 0.37, alpha: 1)
    })
}

struct MemorySummary: View {
    let date: Date
    @EnvironmentObject private var archive: MoodArchiveStore
    var body: some View {
        HStack(spacing: 8) {
            if let level = archive.moodLevel(for: date) {
                Circle().fill(ArchiveDesign.moodBlobColor(level: level)).frame(width: 8, height: 8)
                Text(MoodLabel.name(level))
            }
            if !archive.note(for: date).isEmpty { Image(systemName: "text.alignleft") }
            if !archive.soundtrack(for: date).isEmpty { Image(systemName: "music.note") }
        }.font(.caption).foregroundStyle(.secondary)
    }
}
