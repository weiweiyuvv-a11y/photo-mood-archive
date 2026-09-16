import SwiftUI

struct CalendarMonthView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date

    @EnvironmentObject private var photoLibrary: PhotoLibraryStore
    @EnvironmentObject private var archiveStore: MoodArchiveStore
    @State private var isScrubbing = false
    @State private var scrubY: CGFloat = 80
    @State private var scrubHideTask: Task<Void, Never>?
    @State private var hasAutoScrolledToLatest = false

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    LazyVStack(spacing: 96) {
                        ForEach(monthsToShow, id: \.archiveKey) { month in
                            InstagramMonthSection(
                                month: month,
                                selectedDate: $selectedDate
                            )
                            .environmentObject(photoLibrary)
                            .environmentObject(archiveStore)
                            .id(month.archiveKey)
                            .background {
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: VisibleMonthPreferenceKey.self,
                                        value: [month: geometry.frame(in: .named("calendarScroll")).minY]
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 56)
                    .padding(.bottom, 132)
                }

                GeometryReader { geometry in
                    rightScrubRail(height: geometry.size.height, proxy: proxy)
                }
            }
            .coordinateSpace(name: "calendarScroll")
            .background(Color.white)
            .onAppear {
                autoScrollToLatestIfNeeded(proxy: proxy, animated: false)
            }
            .onChange(of: photoLibrary.allAssets.count) { oldValue, newValue in
                guard oldValue == 0, newValue > 0 else { return }
                autoScrollToLatestIfNeeded(proxy: proxy, animated: false)
            }
            .onPreferenceChange(VisibleMonthPreferenceKey.self) { values in
                guard let visible = values.min(by: { abs($0.value - 24) < abs($1.value - 24) })?.key else { return }
                if !Calendar.current.isDate(visible, equalTo: displayedMonth, toGranularity: .month) {
                    displayedMonth = visible
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .archiveMonthJumpRequested)) { notification in
                guard let key = notification.object as? String else { return }
                withAnimation(.snappy(duration: 0.28)) {
                    proxy.scrollTo(key, anchor: .top)
                }
            }
        }
    }

    private var monthsToShow: [Date] {
        let calendar = Calendar.current
        let monthStarts = Set(photoLibrary.allAssets.compactMap { asset in
            calendar.dateInterval(of: .month, for: asset.creationDate)?.start
        })

        let sortedMonths = monthStarts.sorted()
        if !sortedMonths.isEmpty {
            return sortedMonths
        }

        return [calendar.dateInterval(of: .month, for: displayedMonth)?.start ?? displayedMonth]
    }

    private var visibleTargetMonth: Date {
        return monthsToShow.last ?? displayedMonth
    }

    private func autoScrollToLatestIfNeeded(proxy: ScrollViewProxy, animated: Bool) {
        guard !hasAutoScrolledToLatest, !photoLibrary.allAssets.isEmpty else { return }
        guard let latestMonth = monthsToShow.last else { return }

        hasAutoScrolledToLatest = true
        displayedMonth = latestMonth
        selectedDate = latestMonth

        Task { @MainActor in
            // Give LazyVStack one pass to realize the newly loaded month ids before scrolling.
            try? await Task.sleep(for: .milliseconds(80))
            if animated {
                withAnimation(.snappy(duration: 0.28)) {
                    proxy.scrollTo(latestMonth.archiveKey, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(latestMonth.archiveKey, anchor: .bottom)
            }
        }
    }

    private func rightScrubRail(height: CGFloat, proxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .topTrailing) {
            Capsule()
                .fill(Color.black.opacity(isScrubbing ? 0.14 : 0.06))
                .frame(width: 4, height: max(height - 176, 80))
                .padding(.top, 34)
                .padding(.trailing, 6)

            if isScrubbing {
                ScrubMonthBubble(month: displayedMonth)
                    .offset(x: -22, y: min(max(scrubY - 18, 20), max(height - 72, 20)))
                    .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
            }

            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .frame(width: 52, height: height)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            updateScrub(to: value.location.y, height: height, proxy: proxy)
                        }
                        .onEnded { _ in
                            scheduleScrubHide()
                        }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func updateScrub(to y: CGFloat, height: CGFloat, proxy: ScrollViewProxy) {
        guard !monthsToShow.isEmpty else { return }
        scrubHideTask?.cancel()
        scrubY = min(max(y, 34), max(height - 34, 34))

        let normalized = max(0, min(1, (scrubY - 34) / max(height - 68, 1)))
        let targetIndex = min(Int((normalized * CGFloat(monthsToShow.count)).rounded(.down)), monthsToShow.count - 1)
        let targetMonth = monthsToShow[targetIndex]
        withAnimation(.snappy(duration: 0.16)) {
            isScrubbing = true
            displayedMonth = targetMonth
            proxy.scrollTo(targetMonth.archiveKey, anchor: .top)
        }
    }

    private func scheduleScrubHide() {
        scrubHideTask?.cancel()
        scrubHideTask = Task {
            try? await Task.sleep(for: .milliseconds(620))
            await MainActor.run {
                withAnimation(.snappy(duration: 0.2)) {
                    isScrubbing = false
                }
            }
        }
    }
}

extension Notification.Name {
    static let archiveMonthJumpRequested = Notification.Name("archiveMonthJumpRequested")
}

private struct InstagramMonthSection: View {
    let month: Date
    @Binding var selectedDate: Date

    @EnvironmentObject private var photoLibrary: PhotoLibraryStore
    @EnvironmentObject private var archiveStore: MoodArchiveStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 42) {
            Text(month.instagramMonthTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.black)

            VStack(spacing: 30) {
                weekdayHeader

                LazyVGrid(columns: columns, spacing: 36) {
                    ForEach(days) { day in
                        NavigationLink(value: day.date) {
                            InstagramDayDot(
                                day: day,
                                photos: photoLibrary.assets(for: day.date),
                                moodLevel: archiveStore.moodLevel(for: day.date)
                            )
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded {
                            selectedDate = day.date
                        })
                    }
                }
            }
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                Text(day)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var days: [DayCellModel] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, duration: 0)
        let firstDay = interval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let mondayOffset = (weekday + 5) % 7
        let gridStart = calendar.date(byAdding: .day, value: -mondayOffset, to: firstDay) ?? firstDay
        let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 31
        let rows = Int(ceil(Double(mondayOffset + daysInMonth) / 7.0))

        return (0..<(rows * 7)).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index, to: gridStart) else { return nil }
            return DayCellModel(
                id: date.archiveKey(),
                date: date,
                isInDisplayedMonth: calendar.isDate(date, equalTo: month, toGranularity: .month)
            )
        }
    }
}

private struct InstagramDayDot: View {
    let day: DayCellModel
    let photos: [PhotoAsset]
    let moodLevel: Int?

    private var theme: MonthTheme {
        ArchiveDesign.theme(for: day.date)
    }

    var body: some View {
        ZStack {
            if day.isInDisplayedMonth {
                if let firstPhoto = photos.first {
                    ZStack(alignment: .bottomTrailing) {
                        PhotoThumbnailView(photo: firstPhoto, size: 58)
                            .clipShape(Circle())
                            .overlay {
                                Circle().fill(.black.opacity(0.18))
                            }
                            .overlay {
                                Text(dayNumber)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                        if let moodLevel {
                            MoodPetalStamp(theme: theme, level: moodLevel)
                                .frame(width: 18, height: 18)
                                .offset(x: 4, y: 4)
                        }
                    }
                    .frame(width: 64, height: 74)
                } else {
                    ZStack(alignment: .bottom) {
                        Text(dayNumber)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(red: 0.55, green: 0.59, blue: 0.63))
                            .frame(width: 58, height: 58)

                        if let moodLevel {
                            MoodPetalStamp(theme: theme, level: moodLevel)
                                .frame(width: 14, height: 14)
                                .offset(y: 10)
                        }
                    }
                    .frame(height: 74)
                }
            } else {
                Color.clear
                    .frame(width: 58, height: 74)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: day.date))"
    }
}

private struct MoodPetalStamp: View {
    let theme: MonthTheme
    let level: Int

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 7,
            bottomLeadingRadius: 5,
            bottomTrailingRadius: 8,
            topTrailingRadius: 6,
            style: .continuous
        )
        .fill(theme.moodColor(level: level))
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: 7,
                bottomLeadingRadius: 5,
                bottomTrailingRadius: 8,
                topTrailingRadius: 6,
                style: .continuous
            )
            .stroke(.white.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: theme.moodColor(level: level).opacity(0.24), radius: 5, y: 2)
    }
}

private struct VisibleMonthPreferenceKey: PreferenceKey {
    static let defaultValue: [Date: CGFloat] = [:]

    static func reduce(value: inout [Date: CGFloat], nextValue: () -> [Date: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct ScrubMonthBubble: View {
    let month: Date

    var body: some View {
        Text(month.instagramMonthTitle)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.76), in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
    }
}

private extension Date {
    var archiveKey: String {
        formatted(.dateTime.year().month())
    }

    var instagramMonthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
}
