import CoreLocation
import SwiftUI
import UIKit

struct DayDetailView: View {
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var photoLibrary: PhotoLibraryStore
    @EnvironmentObject private var archiveStore: MoodArchiveStore
    @StateObject private var voiceRecorder = VoiceNoteRecorder()
    @State private var draftNote = ""
    @State private var draftTrackTitle = ""
    @State private var draftTrackArtist = ""
    @State private var isAddMenuPresented = false
    @State private var activeEditor: DayDetailEditor?
    @State private var isMoodPickerExpanded = false
    @State private var locationLabel: String?
    @State private var selectedPhoto: PhotoAsset?

    private let photoColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var theme: MonthTheme {
        ArchiveDesign.theme(for: date)
    }

    private var photos: [PhotoAsset] {
        photoLibrary.assets(for: date)
    }

    private var firstCoordinate: CLLocationCoordinate2D? {
        photos.compactMap(\.coordinate).first
    }

    private var locationLookupKey: String {
        guard let coordinate = firstCoordinate else { return "none-\(date.archiveKey())" }
        return "\(date.archiveKey())-\(coordinate.latitude)-\(coordinate.longitude)"
    }

    var body: some View {
        ZStack(alignment: .top) {
            topMoodBackdrop

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topMoodHeader
                        .zIndex(1)
                    photoSection
                        .padding(.top, isMoodPickerExpanded ? 18 : 0)
                        .allowsHitTesting(!isMoodPickerExpanded)
                        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isMoodPickerExpanded)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
        }
        .background(Color.white.ignoresSafeArea())
        .simultaneousGesture(edgeSwipeBackGesture)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            draftNote = archiveStore.note(for: date)
            let soundtrack = archiveStore.soundtrack(for: date)
            draftTrackTitle = soundtrack.title
            draftTrackArtist = soundtrack.artist
        }
        .onChange(of: voiceRecorder.transcript) { _, transcript in
            guard !transcript.isEmpty else { return }
            draftNote = transcript
            archiveStore.setNote(transcript, for: date)
        }
        .task(id: locationLookupKey) {
            await loadLocationLabel()
        }
        .confirmationDialog("Add a memory layer", isPresented: $isAddMenuPresented, titleVisibility: .visible) {
            Button("Add note") {
                activeEditor = .note
            }
            Button("Add music") {
                activeEditor = .music
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $activeEditor) { editor in
            NavigationStack {
                editorSheet(for: editor)
                    .navigationTitle(editor.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                activeEditor = nil
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoPreviewPagerView(photos: photos, initialPhoto: photo) {
                selectedPhoto = nil
            }
            .environmentObject(photoLibrary)
        }
    }

    private var topMoodBackdrop: some View {
        VStack(spacing: 0) {
            moodGradient
                .frame(height: isMoodPickerExpanded ? 250 : 210)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 86)
                }
            Spacer()
        }
        .ignoresSafeArea(edges: .top)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: isMoodPickerExpanded)
    }

    private var topMoodHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            customNavigationRow
                .padding(.top, 8)

            header
            dayFunctionArea
        }
    }

    private var customNavigationRow: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ArchiveDesign.ink)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                isAddMenuPresented = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(ArchiveDesign.ink)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.wide)))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.4)
                    .foregroundStyle(ArchiveDesign.secondaryInk)
                Text(date.formatted(.dateTime.year().month(.wide).day()))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)

                HStack(spacing: 9) {
                    Text(photos.isEmpty ? "No photos yet" : "\(photos.count) photos")

                    if let locationLabel {
                        Text("·")
                            .foregroundStyle(ArchiveDesign.secondaryInk.opacity(0.55))

                        Label(locationLabel, systemImage: "location.fill")
                            .labelStyle(.titleAndIcon)
                            .lineLimit(1)
                    }
                }
                .font(.callout)
                .foregroundStyle(ArchiveDesign.secondaryInk)
            }

            Spacer()

            if let moodLevel = archiveStore.moodLevel(for: date) {
                MoodDoodleView(theme: theme, moodLevel: moodLevel)
                    .frame(width: 54, height: 54)
            }
        }
    }

    private var dayFunctionArea: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    isMoodPickerExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(moodSummary)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(ArchiveDesign.ink.opacity(0.56))

                    HStack(spacing: 8) {
                        Text("Mood of the day")
                            .font(.headline)
                            .foregroundStyle(ArchiveDesign.ink)

                        Image(systemName: isMoodPickerExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ArchiveDesign.ink.opacity(0.46))
                    }
                }
            }
            .buttonStyle(.plain)

            if isMoodPickerExpanded {
                moodTool
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            memoryCapsules
        }
        .padding(14)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(.white.opacity(0.30), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.72), lineWidth: 1))
    }

    private var moodTool: some View {
        HStack(spacing: 8) {
            ForEach(0..<9, id: \.self) { level in
                Button {
                    archiveStore.setMood(level, for: date)
                } label: {
                    MoodBead(theme: theme, level: level, isSelected: archiveStore.moodLevel(for: date) == level)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var memoryCapsules: some View {
        HStack(spacing: 8) {
            if !draftNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                MemoryCapsule(icon: "text.bubble.fill", text: notePreview) {
                    activeEditor = .note
                }
            }

            if !SoundtrackMemory(title: draftTrackTitle, artist: draftTrackArtist).isEmpty {
                MemoryCapsule(icon: "music.note", text: musicPreview) {
                    activeEditor = .music
                }
            }
        }
    }

    private var selectedMoodColor: Color {
        theme.moodColor(level: archiveStore.moodLevel(for: date) ?? 3)
    }

    private var moodGradient: LinearGradient {
        LinearGradient(
            colors: [
                selectedMoodColor.opacity(0.92),
                theme.quietColor.opacity(0.78),
                Color.white.opacity(0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var moodSummary: String {
        guard let level = archiveStore.moodLevel(for: date) else { return "not set" }
        return ["misty", "soft", "quiet", "okay", "warm", "bright", "sunny", "glowy", "burst"][level]
    }

    private var notePreview: String {
        let trimmed = draftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 18 {
            return String(trimmed.prefix(18)) + "..."
        }
        return trimmed
    }

    private var musicPreview: String {
        if !draftTrackTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return draftTrackTitle
        }
        return draftTrackArtist
    }

    @ViewBuilder
    private func editorSheet(for editor: DayDetailEditor) -> some View {
        switch editor {
        case .note:
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Secret note")
                        .font(.headline)
                        .foregroundStyle(ArchiveDesign.ink)

                    Spacer()

                    Button {
                        voiceRecorder.toggle()
                    } label: {
                        Label(voiceRecorder.isRecording ? "Stop" : "Voice", systemImage: voiceRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(voiceRecorder.isRecording ? .red.opacity(0.78) : theme.baseColor)
                    }
                    .buttonStyle(.plain)
                }

                TextEditor(text: $draftNote)
                    .frame(minHeight: 180)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(ArchiveDesign.paper.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ArchiveDesign.hairline))
                    .onChange(of: draftNote) { _, value in
                        archiveStore.setNote(value, for: date)
                    }

                if !voiceRecorder.statusText.isEmpty {
                    Text(voiceRecorder.statusText)
                        .font(.footnote)
                        .foregroundStyle(ArchiveDesign.secondaryInk)
                }
            }
            .padding(18)

        case .music:
            VStack(alignment: .leading, spacing: 14) {
                Text("Soundtrack of the day")
                    .font(.headline)
                    .foregroundStyle(ArchiveDesign.ink)

                TextField("Song title", text: $draftTrackTitle)
                    .textFieldStyle(ArchiveTextFieldStyle())
                    .onChange(of: draftTrackTitle) { _, _ in saveSoundtrack() }

                TextField("Artist or memory note", text: $draftTrackArtist)
                    .textFieldStyle(ArchiveTextFieldStyle())
                    .onChange(of: draftTrackArtist) { _, _ in saveSoundtrack() }

                Text("First version is manual. Later we can add Apple Music now-playing capture; NetEase is better as share-link/manual.")
                    .font(.footnote)
                    .foregroundStyle(ArchiveDesign.secondaryInk)

                Spacer()
            }
            .padding(18)
        }
    }

    private var moodEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did that day feel?")
                .font(.headline)
                .foregroundStyle(ArchiveDesign.ink)

            MoodOrbitPicker(
                theme: theme,
                selectedLevel: archiveStore.moodLevel(for: date),
                onSelect: { level in archiveStore.setMood(level, for: date) }
            )
            .frame(height: 280)
        }
        .archiveCard()
    }

    private var noteEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Secret note")
                    .font(.headline)
                    .foregroundStyle(ArchiveDesign.ink)
                Spacer()
                Button {
                    voiceRecorder.toggle()
                } label: {
                    Image(systemName: voiceRecorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(voiceRecorder.isRecording ? .red.opacity(0.72) : theme.baseColor)
                }
                .accessibilityLabel("语音输入")
            }

            TextEditor(text: $draftNote)
                .frame(minHeight: 150)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(ArchiveDesign.paper.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: draftNote) { _, value in
                    archiveStore.setNote(value, for: date)
                }

            if !voiceRecorder.statusText.isEmpty {
                Text(voiceRecorder.statusText)
                    .font(.footnote)
                    .foregroundStyle(ArchiveDesign.secondaryInk)
            }
        }
        .archiveCard()
    }

    private var soundtrackEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .foregroundStyle(theme.baseColor)
                Text("Soundtrack of the day")
                    .font(.headline)
                    .foregroundStyle(ArchiveDesign.ink)
            }

            TextField("Song title", text: $draftTrackTitle)
                .textFieldStyle(ArchiveTextFieldStyle())
                .onChange(of: draftTrackTitle) { _, _ in saveSoundtrack() }

            TextField("Artist or memory note", text: $draftTrackArtist)
                .textFieldStyle(ArchiveTextFieldStyle())
                .onChange(of: draftTrackArtist) { _, _ in saveSoundtrack() }

            Text("First version is manual. Later we can add Apple Music now-playing capture; NetEase is better as share-link/manual.")
                .font(.footnote)
                .foregroundStyle(ArchiveDesign.secondaryInk)
        }
        .archiveCard()
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if photos.isEmpty {
                ContentUnavailableView("这天还没有照片", systemImage: "photo", description: Text("相册里有照片后会自动按拍摄日期出现。"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                Button {
                    selectedPhoto = photos[0]
                } label: {
                    PhotoThumbnailView(photo: photos[0], size: UIScreen.main.bounds.width - 36, allowsNetworkAccess: true)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)

                if photos.count > 1 {
                    LazyVGrid(columns: photoColumns, spacing: 8) {
                        ForEach(photos.dropFirst()) { photo in
                            Button {
                                selectedPhoto = photo
                            } label: {
                                PhotoThumbnailView(photo: photo, size: 108)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var edgeSwipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onEnded { value in
                guard value.startLocation.x < 28 else { return }
                guard value.translation.width > 82, abs(value.translation.height) < 90 else { return }
                dismiss()
            }
    }

    private func moodColor(_ level: Int) -> Color {
        theme.moodColor(level: level)
    }

    private func saveSoundtrack() {
        archiveStore.setSoundtrack(
            SoundtrackMemory(title: draftTrackTitle, artist: draftTrackArtist),
            for: date
        )
    }

    private func loadLocationLabel() async {
        guard let coordinate = firstCoordinate else {
            locationLabel = nil
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            locationLabel = placemarks.first?.archiveDisplayName
        } catch {
            locationLabel = nil
        }
    }
}

private struct PhotoPreviewPagerView: View {
    let photos: [PhotoAsset]
    let initialPhoto: PhotoAsset
    let onDismiss: () -> Void

    @EnvironmentObject private var photoLibrary: PhotoLibraryStore
    @State private var visiblePhotos: [PhotoAsset] = []
    @State private var selectedPhotoID: String
    @State private var isDeleting = false
    @State private var isDeleteConfirmationPresented = false

    init(photos: [PhotoAsset], initialPhoto: PhotoAsset, onDismiss: @escaping () -> Void) {
        self.photos = photos
        self.initialPhoto = initialPhoto
        self.onDismiss = onDismiss
        _selectedPhotoID = State(initialValue: initialPhoto.id)
    }

    private var currentPhoto: PhotoAsset? {
        visiblePhotos.first { $0.id == selectedPhotoID } ?? visiblePhotos.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if visiblePhotos.isEmpty {
                ContentUnavailableView("No photos", systemImage: "photo")
                    .foregroundStyle(.white)
            } else {
                TabView(selection: $selectedPhotoID) {
                    ForEach(visiblePhotos) { photo in
                        PhotoPreviewPage(photo: photo)
                            .environmentObject(photoLibrary)
                            .tag(photo.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.white.opacity(0.16), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if let currentPhoto {
                        Button {
                            photoLibrary.openInPhotos(currentPhoto)
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 42, height: 42)
                                .background(.white.opacity(0.16), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer()

                bottomActionCapsule
                    .padding(.bottom, 18)
            }
        }
        .onAppear {
            visiblePhotos = photos
            selectedPhotoID = initialPhoto.id
        }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    let isIntentionalDownSwipe = value.translation.height > 80 &&
                        value.translation.height > abs(value.translation.width) * 1.45
                    if isIntentionalDownSwipe {
                        onDismiss()
                    }
                }
        )
        .confirmationDialog("Delete this photo?", isPresented: $isDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("Delete from Library", role: .destructive) {
                guard let currentPhoto else { return }
                Task {
                    isDeleting = true
                    let deleted = await photoLibrary.deletePhoto(currentPhoto)
                    isDeleting = false
                    if deleted {
                        removeDeletedPhoto(currentPhoto)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the photo from your system photo library.")
        }
    }

    private var bottomActionCapsule: some View {
        HStack(spacing: 10) {
            Button {
                isDeleteConfirmationPresented = true
            } label: {
                Label(isDeleting ? "Deleting" : "Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .disabled(isDeleting)

            Divider()
                .frame(height: 24)
                .overlay(.white.opacity(0.24))

            Button {
                guard let currentPhoto else { return }
                Task { await photoLibrary.toggleFavorite(currentPhoto) }
            } label: {
                let isFavorite = currentPhoto.map { photoLibrary.isFavorite($0) } ?? false
                Label(isFavorite ? "Favorited" : "Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.24), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private func removeDeletedPhoto(_ deletedPhoto: PhotoAsset) {
        guard let deletedIndex = visiblePhotos.firstIndex(of: deletedPhoto) else { return }
        visiblePhotos.remove(at: deletedIndex)

        if visiblePhotos.isEmpty {
            onDismiss()
            return
        }

        let nextIndex = min(deletedIndex, visiblePhotos.count - 1)
        selectedPhotoID = visiblePhotos[nextIndex].id
    }
}

private struct PhotoPreviewPage: View {
    let photo: PhotoAsset

    @EnvironmentObject private var photoLibrary: PhotoLibraryStore
    @State private var image: UIImage?
    @State private var hasLoaded = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text(hasLoaded ? "Waiting for iCloud photo" : "Loading photo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
        .padding(.vertical, 72)
        .task(id: photo.id) {
            image = nil
            hasLoaded = false
            let scale = UIScreen.main.scale
            let bounds = UIScreen.main.bounds
            photoLibrary.requestPreviewImage(
                for: photo,
                size: CGSize(width: bounds.width * scale, height: bounds.height * scale)
            ) { fetched in
                if let fetched {
                    image = fetched
                }
                hasLoaded = true
            }
        }
    }
}

private extension CLPlacemark {
    var archiveDisplayName: String? {
        let candidates = [
            locality,
            subAdministrativeArea,
            administrativeArea,
            country
        ]
        let uniqueParts = candidates.compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .reduce(into: [String]()) { result, value in
            if !result.contains(value) {
                result.append(value)
            }
        }

        if !uniqueParts.isEmpty {
            return uniqueParts.prefix(2).joined(separator: ", ")
        }

        return name
    }
}

private struct BackgroundTint: View {
    let theme: MonthTheme

    var body: some View {
        LinearGradient(
            colors: [
                theme.quietColor,
                ArchiveDesign.paper
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private enum DayDetailEditor: String, Identifiable {
    case note
    case music

    var id: String { rawValue }

    var title: String {
        switch self {
        case .note: "Note"
        case .music: "Music"
        }
    }
}

private struct MemoryCapsule: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(text)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(ArchiveDesign.ink.opacity(0.74))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(.white.opacity(0.54), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.76), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func archiveCard() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ArchiveDesign.liftedPaper.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(ArchiveDesign.hairline))
    }
}

private struct MoodOrbitPicker: View {
    let theme: MonthTheme
    let selectedLevel: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.34

            ZStack {
                Text("那天的心情\n是怎样?")
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ArchiveDesign.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.quietColor.opacity(0.82), in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 4, bottomLeading: 14, bottomTrailing: 4, topTrailing: 14)))

                ForEach(0..<9, id: \.self) { level in
                    let angle = -Double.pi / 2 + Double(level) * (2 * Double.pi / 9)
                    let point = CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    )

                    Button {
                        onSelect(level)
                    } label: {
                        MoodBlobButton(theme: theme, level: level, isSelected: selectedLevel == level)
                    }
                    .buttonStyle(.plain)
                    .position(point)
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }
}

private struct MoodBlobButton: View {
    let theme: MonthTheme
    let level: Int
    let isSelected: Bool

    var body: some View {
        MoodDoodleView(theme: theme, moodLevel: level)
            .frame(width: isSelected ? 72 : 62, height: isSelected ? 72 : 62)
            .background(theme.quietColor.opacity(0.22), in: Circle())
            .overlay(Circle().stroke(isSelected ? theme.moodColor(level: level).opacity(0.72) : .white.opacity(0.22), lineWidth: isSelected ? 2 : 1))
            .shadow(color: isSelected ? theme.moodColor(level: level).opacity(0.24) : .clear, radius: 12, y: 6)
            .animation(.spring(response: 0.28, dampingFraction: 0.74), value: isSelected)
    }
}

private struct MoodBead: View {
    let theme: MonthTheme
    let level: Int
    let isSelected: Bool

    var body: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: isSelected ? 13 : 11,
            bottomLeadingRadius: isSelected ? 9 : 8,
            bottomTrailingRadius: isSelected ? 14 : 12,
            topTrailingRadius: isSelected ? 10 : 9,
            style: .continuous
        )
        .fill(theme.moodColor(level: level))
        .frame(width: isSelected ? 34 : 29, height: isSelected ? 34 : 29)
        .overlay {
            UnevenRoundedRectangle(
                topLeadingRadius: isSelected ? 13 : 11,
                bottomLeadingRadius: isSelected ? 9 : 8,
                bottomTrailingRadius: isSelected ? 14 : 12,
                topTrailingRadius: isSelected ? 10 : 9,
                style: .continuous
            )
            .stroke(isSelected ? ArchiveDesign.ink.opacity(0.28) : .white.opacity(0.66), lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: isSelected ? theme.moodColor(level: level).opacity(0.24) : .clear, radius: 8, y: 4)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isSelected)
    }
}

private struct ArchiveTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(ArchiveDesign.paper.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ArchiveDesign.hairline))
    }
}

private struct CompactArchiveTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.callout)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(.white.opacity(0.66), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ArchiveDesign.hairline))
    }
}
