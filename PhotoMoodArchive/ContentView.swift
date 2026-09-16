import Photos
import MapKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var photoLibrary: PhotoLibraryStore
    @State private var displayedMonth = Date()
    @State private var selectedDate = Date()
    @State private var mode: ArchiveMode = .timeline

    private var theme: MonthTheme {
        ArchiveDesign.theme(for: displayedMonth)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    if mode == .timeline {
                        archiveTopBar
                    }

                    if photoLibrary.authorizationStatus == .authorized || photoLibrary.authorizationStatus == .limited {
                        if photoLibrary.isLoading && photoLibrary.allAssets.isEmpty {
                            loadingArchiveCard
                                .padding(18)
                            Spacer()
                        } else if mode == .timeline {
                            CalendarMonthView(displayedMonth: $displayedMonth, selectedDate: $selectedDate)
                                .environmentObject(photoLibrary)
                        } else {
                            ScrollView {
                                TrajectoryView(assets: photoLibrary.allAssets, theme: theme)
                                    .padding(18)
                                    .padding(.bottom, 92)
                            }
                        }
                    } else {
                        permissionCard
                            .padding(18)
                        Spacer()
                    }
                }

                bottomModeSwitcher
                    .padding(.horizontal, 56)
                    .padding(.bottom, 10)

                if photoLibrary.isLoading && !photoLibrary.allAssets.isEmpty {
                    indexingOverlay
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(Color.white.ignoresSafeArea())
            .navigationDestination(for: Date.self) { date in
                DayDetailView(date: date)
                    .environmentObject(photoLibrary)
            }
            .task {
                await photoLibrary.requestAccessAndLoad()
            }
        }
    }

    private var loadingArchiveCard: some View {
        VStack(spacing: 18) {
            MoodDoodleView(theme: theme, moodLevel: 5)
                .frame(width: 74, height: 74)

            VStack(spacing: 6) {
                Text("Indexing camera photos")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ArchiveDesign.ink)

                Text("正在轻量读取拍摄日期，只索引相机照片，不下载 iCloud 原图。")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ArchiveDesign.secondaryInk)
            }

            ProgressView(value: loadingProgress)
                .tint(theme.baseColor)

            Text(loadingStatusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(ArchiveDesign.secondaryInk)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(ArchiveDesign.liftedPaper.opacity(0.82), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(ArchiveDesign.hairline))
    }

    private var indexingOverlay: some View {
        HStack(spacing: 12) {
            ProgressView(value: loadingProgress)
                .progressViewStyle(.circular)
                .tint(theme.baseColor)

            VStack(alignment: .leading, spacing: 3) {
                Text("Updating timeline")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ArchiveDesign.ink)

                Text(loadingStatusText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ArchiveDesign.secondaryInk)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.58), lineWidth: 1))
        .shadow(color: .black.opacity(0.10), radius: 14, y: 8)
    }

    private var loadingProgress: Double {
        guard photoLibrary.totalAssetCount > 0 else { return 0 }
        return min(Double(photoLibrary.indexedAssetCount) / Double(photoLibrary.totalAssetCount), 1)
    }

    private var loadingStatusText: String {
        guard photoLibrary.totalAssetCount > 0 else { return "Preparing photo library..." }
        return "\(photoLibrary.indexedAssetCount) / \(photoLibrary.totalAssetCount)"
    }

    private var archiveTopBar: some View {
        VStack(spacing: 0) {
            MonthStrip(displayedMonth: $displayedMonth)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .padding(.horizontal, 18)
        .background(.white.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.12))
                .frame(height: 0.5)
        }
    }

    private var bottomModeSwitcher: some View {
        HStack(spacing: 6) {
            ForEach(ArchiveMode.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        mode = item
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: item.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                    }
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .padding(.horizontal, 8)
                        .foregroundStyle(mode == item ? Color.black : Color(red: 0.45, green: 0.49, blue: 0.53))
                        .background(mode == item ? Color.white.opacity(0.52) : Color.clear, in: Capsule())
                        .overlay(Capsule().stroke(mode == item ? .white.opacity(0.76) : .clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.82), .white.opacity(0.22), .black.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
        .shadow(color: theme.baseColor.opacity(0.10), radius: 18, y: 5)
    }

    private var permissionCard: some View {
        VStack(spacing: 16) {
            MoodDoodleView(theme: theme, moodLevel: 2)
                .frame(width: 92, height: 92)

            Text("Open your local archive")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ArchiveDesign.ink)

            Text("We only read photo dates on this device to build your calendar. Nothing is uploaded.")
                .multilineTextAlignment(.center)
                .foregroundStyle(ArchiveDesign.secondaryInk)

            Button {
                Task { await photoLibrary.requestAccessAndLoad() }
            } label: {
                Label("允许访问相册", systemImage: "photo.on.rectangle.angled")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ArchiveDesign.liftedPaper.opacity(0.82), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(ArchiveDesign.hairline))
    }

}

private enum ArchiveMode: String, CaseIterable, Identifiable {
    case timeline
    case trail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: "Timeline"
        case .trail: "Trail"
        }
    }

    var icon: String {
        switch self {
        case .timeline: "calendar"
        case .trail: "map"
        }
    }
}

private struct MonthStrip: View {
    @Binding var displayedMonth: Date

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ArchiveDesign.months) { month in
                        Button {
                            setMonth(month.id)
                        } label: {
                            Text(month.shortName)
                                .font(.system(size: 14, weight: isSelected(month.id) ? .bold : .semibold))
                                .foregroundStyle(isSelected(month.id) ? Color.black : Color(red: 0.50, green: 0.54, blue: 0.58))
                                .frame(width: 46, height: 32)
                                .background(isSelected(month.id) ? Color.black.opacity(0.06) : .clear, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .id(month.id)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onAppear {
                proxy.scrollTo(Calendar.current.component(.month, from: displayedMonth), anchor: .center)
            }
            .onChange(of: Calendar.current.component(.month, from: displayedMonth)) { _, month in
                withAnimation(.snappy(duration: 0.2)) {
                    proxy.scrollTo(month, anchor: .center)
                }
            }
        }
    }

    private func isSelected(_ month: Int) -> Bool {
        Calendar.current.component(.month, from: displayedMonth) == month
    }

    private func setMonth(_ month: Int) {
        var components = Calendar.current.dateComponents([.year], from: displayedMonth)
        components.month = month
        components.day = 1
        displayedMonth = Calendar.current.date(from: components) ?? displayedMonth
        NotificationCenter.default.post(name: .archiveMonthJumpRequested, object: displayedMonth.archiveKey())
    }
}

private struct TrajectoryView: View {
    let assets: [PhotoAsset]
    let theme: MonthTheme

    @EnvironmentObject private var photoLibrary: PhotoLibraryStore
    @State private var position: MapCameraPosition = .automatic

    private var clusters: [PhotoLocationCluster] {
        let located = assets.compactMap { asset -> (PhotoAsset, CLLocationCoordinate2D)? in
            guard let coordinate = asset.coordinate else { return nil }
            return (asset, coordinate)
        }

        let grouped = Dictionary(grouping: located) { item in
            "\(round(item.1.latitude * 10) / 10),\(round(item.1.longitude * 10) / 10)"
        }

        return grouped.values.compactMap { items in
            guard let first = items.first else { return nil }
            let latitude = items.map { $0.1.latitude }.reduce(0, +) / Double(items.count)
            let longitude = items.map { $0.1.longitude }.reduce(0, +) / Double(items.count)
            return PhotoLocationCluster(
                id: first.0.id,
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                count: items.count,
                photo: first.0
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trail")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(ArchiveDesign.ink)
                    Text("A quiet map of where your days happened.")
                        .font(.caption)
                        .foregroundStyle(ArchiveDesign.secondaryInk)
                }
                Spacer()
                Text("\(clusters.reduce(0) { $0 + $1.count })")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.baseColor)
            }

            if clusters.isEmpty {
                ContentUnavailableView(
                    "No location trail yet",
                    systemImage: "map",
                    description: Text("Photos with saved location metadata will appear here. Timeline stays the main archive.")
                )
                .frame(maxWidth: .infinity, minHeight: 420)
            } else {
                Map(position: $position) {
                    ForEach(clusters) { cluster in
                        Annotation("", coordinate: cluster.coordinate) {
                            LocationPin(cluster: cluster, theme: theme)
                                .environmentObject(photoLibrary)
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(ArchiveDesign.hairline))
                .frame(minHeight: 440)
            }
        }
        .padding(14)
        .background(ArchiveDesign.liftedPaper.opacity(0.72), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(ArchiveDesign.hairline))
    }
}

private struct PhotoLocationCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let photo: PhotoAsset
}

private struct LocationPin: View {
    let cluster: PhotoLocationCluster
    let theme: MonthTheme

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PhotoThumbnailView(photo: cluster.photo, size: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white, lineWidth: 2))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)

            Text("\(cluster.count)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(theme.baseColor, in: Capsule())
                .offset(x: 10, y: -10)
        }
    }
}

private struct BackgroundWash: View {
    let theme: MonthTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ArchiveDesign.glassLavender.opacity(0.42),
                    ArchiveDesign.paper,
                    Color(red: 0.84, green: 0.84, blue: 0.94)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [ArchiveDesign.prismBlue.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [ArchiveDesign.prismRed.opacity(0.12), .clear],
                center: .center,
                startRadius: 10,
                endRadius: 320
            )

            RadialGradient(
                colors: [ArchiveDesign.prismYellow.opacity(0.16), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 300
            )

            Canvas { context, size in
                for index in 0..<90 {
                    let x = CGFloat((index * 19) % 101) / 100 * size.width
                    let rect = CGRect(x: x, y: 0, width: 1, height: size.height)
                    context.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(.white.opacity(index.isMultiple(of: 3) ? 0.16 : 0.055)))
                }
            }
        }
    }
}

struct ArchiveIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(width: 38, height: 38)
            .foregroundStyle(ArchiveDesign.ink)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(configuration.isPressed ? 0.36 : 0.68)))
            .shadow(color: ArchiveDesign.prismBlue.opacity(0.10), radius: 12, y: 5)
    }
}
