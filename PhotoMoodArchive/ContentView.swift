import Photos
import MapKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TabView {
            NavigationStack { CalendarHomeView() }
                .tabItem { Label("日历", systemImage: "calendar") }
            NavigationStack { JournalView() }
                .tabItem { Label("手账", systemImage: "book.closed") }
            NavigationStack { PlacesView() }
                .tabItem { Label("足迹", systemImage: "map") }
        }
        .tint(ArchiveDesign.accent)
        .task { await library.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await library.refresh() } }
        }
    }
}

private struct CalendarHomeView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @EnvironmentObject private var archive: MoodArchiveStore
    @State private var month = ArchiveCalendar.monthStart(Date())
    @State private var selectedDate = Date()
    @State private var filter: PhotoFilter = .memories
    @State private var showDatePicker = false
    @State private var pickerDate = Date()
    @State private var showSettings = false
    @State private var didChooseInitialDate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var selectedPhotos: [PhotoAsset] { library.assets(for: selectedDate, filter: filter) }
    private var monthlyPhotos: [PhotoAsset] {
        let interval = ArchiveCalendar.calendar.dateInterval(of: .month, for: month)!
        return library.filtered(filter).filter { interval.contains($0.creationDate) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                introduction
                if !library.hasAccess {
                    PhotoAccessCard()
                } else {
                    if library.authorizationStatus == .limited { limitedBanner }
                    if library.isLoading { ProgressView("正在更新照片…").font(.caption).accessibilityIdentifier("indexing") }
                    monthHeader
                    CalendarMonthView(displayedMonth: $month, selectedDate: $selectedDate, filter: filter)
                    selectedDay
                }
            }
            .padding(20)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(ArchiveDesign.paper)
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("今天") { jump(to: Date()) }.accessibilityIdentifier("today")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("设置", systemImage: "slider.horizontal.3") { showSettings = true }
            }
        }
        .refreshable { await library.refresh() }
        .navigationDestination(for: Date.self) { DayDetailView(date: $0) }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack {
                    DatePicker("选择日期", selection: $pickerDate, displayedComponents: .date)
                        .datePickerStyle(.graphical).padding()
                    Spacer()
                }
                .navigationTitle("去某一天")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("前往") { jump(to: pickerDate); showDatePicker = false }
                } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettings) { ArchiveSettingsView() }
        .onChange(of: library.revision) { _, _ in
            guard !didChooseInitialDate, let newest = library.allAssets.first else { return }
            didChooseInitialDate = true
            jump(to: newest.creationDate)
        }
    }

    private var introduction: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7) {
                Text("把日子，慢慢收藏。")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                Text("照片里的日常，也值得回望。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            MoodDoodleView(theme: ArchiveDesign.theme(for: month), moodLevel: archive.moodLevel(for: selectedDate) ?? 2)
                .frame(width: 52, height: 52).accessibilityHidden(true)
        }.padding(.vertical, 8)
    }
    private var limitedBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "photo.badge.checkmark")
            Text("目前仅显示你允许访问的照片。")
            Spacer(minLength: 0)
            Button("管理") { library.manageLimitedAccess() }
        }.font(.caption).padding(12).background(ArchiveDesign.liftedPaper, in: RoundedRectangle(cornerRadius: 12))
    }
    private var monthHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { pickerDate = selectedDate; showDatePicker = true } label: {
                    HStack(spacing: 8) {
                        Text(ArchiveCalendar.title(month)).font(.title3.bold())
                        Image(systemName: "chevron.down").font(.caption.bold())
                    }.foregroundStyle(.primary)
                }.accessibilityLabel("选择年月").accessibilityIdentifier("month-picker")
                Spacer()
                Button("上个月", systemImage: "chevron.left") { changeMonth(-1) }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                Button("下个月", systemImage: "chevron.right") { changeMonth(1) }.labelStyle(.iconOnly).frame(width: 44, height: 44)
            }
            HStack {
                let photos = monthlyPhotos
                Text("\(photos.count) 张照片 · \(Set(photos.map { $0.creationDate.archiveKey() }).count) 个日子")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Picker("照片范围", selection: $filter) {
                        ForEach(PhotoFilter.allCases) { item in Label(item.rawValue, systemImage: item.icon).tag(item) }
                    }
                } label: { Label(filter.rawValue, systemImage: "line.3.horizontal.decrease").font(.caption.weight(.medium)) }
                .accessibilityIdentifier("photo-filter")
            }
        }
    }
    private var selectedDay: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(ArchiveCalendar.title(selectedDate, format: "M月d日 EEEE")).font(.headline)
                    MemorySummary(date: selectedDate)
                }
                Spacer()
                NavigationLink(value: selectedDate) {
                    Label("打开这一天", systemImage: "arrow.right").labelStyle(.titleOnly).font(.subheadline.weight(.semibold))
                }.accessibilityIdentifier("open-day")
            }
            if selectedPhotos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(filter == .favorites ? "这一天还没有收藏" : "这一天没有符合筛选的照片")
                        .font(.subheadline.weight(.medium))
                    Text("没有照片，也可以写下今天的心情。")
                        .font(.caption).foregroundStyle(.secondary)
                    NavigationLink("记一笔", value: selectedDate).font(.subheadline.weight(.semibold)).padding(.top, 4)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                    .background(ArchiveDesign.liftedPaper, in: RoundedRectangle(cornerRadius: 16))
            } else {
                NavigationLink(value: selectedDate) {
                    HStack(spacing: 6) {
                        ForEach(Array(selectedPhotos.prefix(3))) { photo in
                            PhotoThumbnailView(photo: photo, size: 220)
                                .frame(maxWidth: .infinity).frame(height: 150)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }.buttonStyle(.plain).accessibilityLabel("查看当天 \(selectedPhotos.count) 张照片")
            }
            if !archive.note(for: selectedDate).isEmpty {
                Text(archive.note(for: selectedDate)).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
            }
        }
        .padding(.top, 8)
    }
    private func changeMonth(_ offset: Int) { jump(to: ArchiveCalendar.moving(month, months: offset)) }
    private func jump(to date: Date) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            month = ArchiveCalendar.monthStart(date); selectedDate = date
        }
    }
}

struct PhotoAccessCard: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled").font(.largeTitle).foregroundStyle(ArchiveDesign.accent)
            Text("让照片回到日历里").font(.title2.bold())
            Text("按拍摄日期整理照片，留下当天的心情和小事。你可以只选择部分照片，之后随时调整。")
                .font(.subheadline).foregroundStyle(.secondary)
            if library.authorizationStatus == .restricted {
                Text("相册访问受到系统限制，请检查屏幕使用时间或设备管理设置。")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button(library.authorizationStatus == .denied ? "前往设置开启相册" : "选择可访问的照片") {
                    if library.authorizationStatus == .denied { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                    else { Task { await library.requestAccessAndLoad() } }
                }.buttonStyle(.borderedProminent).accessibilityIdentifier("photo-access")
            }
            Text("照片不会上传到我们的服务器。手账保存在本机。")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(ArchiveDesign.liftedPaper, in: RoundedRectangle(cornerRadius: 22))
    }
}

private struct JournalView: View {
    @EnvironmentObject private var archive: MoodArchiveStore
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var query = ""
    private var dates: [Date] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return archive.recordedDates.filter { date in
            let track = archive.soundtrack(for: date)
            let haystack = [date.archiveKey(), ArchiveCalendar.title(date, format: "yyyy年M月d日"), archive.note(for: date), track.title, track.artist,
                           archive.moodLevel(for: date).map(MoodLabel.name) ?? ""].joined(separator: " ")
            return term.isEmpty || haystack.localizedCaseInsensitiveContains(term)
        }
    }
    var body: some View {
        List {
            if dates.isEmpty {
                ContentUnavailableView(query.isEmpty ? "从今天的一句话开始" : "没有找到这段回忆",
                    systemImage: query.isEmpty ? "book.closed" : "magnifyingglass",
                    description: Text(query.isEmpty ? "写过的心情、笔记和歌曲都会留在这里。" : "试试日期、心情、歌曲或笔记里的词。"))
                if query.isEmpty { NavigationLink("记录今天", value: Date()) }
            }
            ForEach(dates, id: \.self) { date in
                NavigationLink(value: date) {
                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 4) {
                            Text(ArchiveCalendar.title(date, format: "dd")).font(.system(.title, design: .serif, weight: .medium))
                            Text(ArchiveCalendar.title(date, format: "yyyy.MM")).font(.caption2).foregroundStyle(.secondary)
                        }.frame(width: 66)
                        VStack(alignment: .leading, spacing: 8) {
                            MemorySummary(date: date)
                            if !archive.note(for: date).isEmpty { Text(archive.note(for: date)).font(.subheadline).lineLimit(3) }
                            let track = archive.soundtrack(for: date)
                            if !track.isEmpty { Label([track.title, track.artist].filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "music.note").font(.caption).foregroundStyle(.secondary) }
                        }
                    }.padding(.vertical, 10)
                }
            }
        }
        .navigationTitle("手账")
        .searchable(text: $query, prompt: "搜索日期、心情或笔记")
        .navigationDestination(for: Date.self) { DayDetailView(date: $0) }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: Date()) { Label("记今天", systemImage: "square.and.pencil") } } }
    }
}

private struct PlaceCluster: Identifiable {
    let id: String
    let photos: [PhotoAsset]
    var coordinate: CLLocationCoordinate2D { photos[0].coordinate! }
}
private struct PlacesView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var selected: PlaceCluster?
    private var clusters: [PlaceCluster] {
        let located = library.allAssets.filter { $0.coordinate != nil }
        return Dictionary(grouping: located) { photo in
            "\(Int(floor(photo.latitude! * 100))),\(Int(floor(photo.longitude! * 100)))"
        }.map { PlaceCluster(id: $0.key, photos: $0.value.sorted { $0.creationDate > $1.creationDate }) }
            .sorted { $0.id < $1.id }
    }
    var body: some View {
        Group {
            if !library.hasAccess { PhotoAccessCard().padding() }
            else if clusters.isEmpty {
                ContentUnavailableView("还没有足迹", systemImage: "map", description: Text("带有拍摄地点的照片会出现在这里，无需开启实时定位。"))
            } else {
                Map {
                    ForEach(clusters) { cluster in
                        Annotation("\(cluster.photos.count) 张", coordinate: cluster.coordinate) {
                            Button { selected = cluster } label: {
                                VStack(spacing: 2) {
                                    PhotoThumbnailView(photo: cluster.photos[0], size: 60).frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                                    Text("\(cluster.photos.count)").font(.caption2.bold())
                                }.padding(4).background(ArchiveDesign.liftedPaper, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityLabel("查看此处的 \(cluster.photos.count) 张照片")
                        }
                    }
                }.mapStyle(.standard(pointsOfInterest: .excludingAll))
            }
        }
        .navigationTitle("足迹").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { cluster in
            NavigationStack {
                List {
                    ForEach(Array(Set(cluster.photos.map { ArchiveCalendar.calendar.startOfDay(for: $0.creationDate) })).sorted(by: >), id: \.self) { date in
                        NavigationLink(value: date) {
                            Label(ArchiveCalendar.title(date, format: "yyyy年M月d日"), systemImage: "calendar")
                        }
                    }
                }.navigationTitle("这里的回忆")
                    .navigationDestination(for: Date.self) { DayDetailView(date: $0) }
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { selected = nil } } }
            }.presentationDetents([.medium, .large])
        }
    }
}

private struct ArchiveSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var library: PhotoLibraryStore
    var body: some View {
        NavigationStack {
            Form {
                Section("照片") {
                    LabeledContent("可访问照片", value: "\(library.allAssets.count) 张")
                    if library.authorizationStatus == .limited { Button("调整允许访问的照片") { library.manageLimitedAccess() } }
                    Button("打开系统权限设置") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                    Button("重新整理相册") { Task { await library.refresh() } }.disabled(library.isLoading)
                }
                Section("关于你的数据") {
                    Text("照片直接来自系统相册；收藏、删除会同步到系统相册。删除前会再次确认。")
                    Text("心情、笔记和歌曲保存在这台设备，兼容旧版记录。卸载 App 会丢失本地手账，请保留设备备份。")
                    Text("原图预览和分享可能从 iCloud 下载。地图使用 Apple 地图；语音输入仅在设备支持本地识别时可用。")
                }.font(.subheadline)
                Section { LabeledContent("Archive", value: "0.2.0") }
            }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
