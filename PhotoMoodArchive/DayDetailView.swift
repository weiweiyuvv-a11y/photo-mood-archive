import SwiftUI
import Photos

struct DayDetailView: View {
    let date: Date
    @EnvironmentObject private var library: PhotoLibraryStore
    @EnvironmentObject private var archive: MoodArchiveStore
    @State private var editor: MemoryEditorKind?
    @State private var selectedPhoto: PhotoAsset?
    @State private var filter: PhotoFilter = .all
    private var photos: [PhotoAsset] { library.assets(for: date, filter: filter) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(ArchiveCalendar.title(date, format: "M月d日"))
                            .font(.system(.largeTitle, design: .serif, weight: .medium))
                        Text(ArchiveCalendar.title(date, format: "yyyy年 · EEEE"))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    MoodDoodleView(theme: ArchiveDesign.theme(for: date), moodLevel: archive.moodLevel(for: date))
                        .frame(width: 72, height: 72).accessibilityHidden(true)
                }
                memoryCard
                HStack {
                    Text("这一天的照片").font(.headline)
                    Spacer()
                    Menu {
                        Picker("照片范围", selection: $filter) {
                            ForEach(PhotoFilter.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                        }
                    } label: { Text("\(filter.rawValue) · \(photos.count)").font(.caption) }
                }
                if !library.hasAccess {
                    PhotoAccessCard()
                } else if photos.isEmpty {
                    ContentUnavailableView("这里暂时没有照片", systemImage: "photo", description: Text("试试切换照片范围，也可以先为这一天记一笔。"))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 5)], spacing: 5) {
                        ForEach(photos) { photo in
                            Button { selectedPhoto = photo } label: {
                                PhotoThumbnailView(photo: photo, size: 220)
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(alignment: .bottomTrailing) {
                                        if library.isFavorite(photo) {
                                            Image(systemName: "heart.fill").font(.caption).foregroundStyle(.white)
                                                .shadow(radius: 3).padding(8)
                                        }
                                    }
                            }.buttonStyle(.plain)
                                .accessibilityLabel("查看 \(ArchiveCalendar.title(photo.creationDate, format: "HH:mm")) 的照片")
                                .accessibilityIdentifier("photo-\(photo.id)")
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 850).frame(maxWidth: .infinity)
        }
        .background(ArchiveDesign.paper)
        .navigationTitle("这一天").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { kind in
            if kind == .mood { MoodEditorView(date: date) }
            else { MemoryEditorView(date: date, kind: kind) }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            PhotoPagerView(photos: photos, initialPhoto: photo)
        }
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                memoryButton(archive.moodLevel(for: date).map(MoodLabel.name) ?? "记心情", icon: "face.smiling", kind: .mood)
                memoryButton("写一笔", icon: "square.and.pencil", kind: .note)
                memoryButton("留首歌", icon: "music.note", kind: .music)
            }
            if !archive.note(for: date).isEmpty {
                Button { editor = .note } label: {
                    Text(archive.note(for: date)).font(.body).foregroundStyle(.primary)
                        .lineSpacing(5).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityLabel("编辑笔记：\(archive.note(for: date))")
            } else {
                Text("今天有什么想留住的？").font(.subheadline).foregroundStyle(.secondary)
            }
            let soundtrack = archive.soundtrack(for: date)
            if !soundtrack.isEmpty {
                Button { editor = .music } label: {
                    Label([soundtrack.title, soundtrack.artist].filter { !$0.isEmpty }.joined(separator: " · "), systemImage: "music.note")
                        .font(.subheadline).multilineTextAlignment(.leading)
                }
            }
        }.padding(18).background(ArchiveDesign.liftedPaper, in: RoundedRectangle(cornerRadius: 20))
    }
    private func memoryButton(_ title: String, icon: String, kind: MemoryEditorKind) -> some View {
        Button { editor = kind } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption.weight(.medium))
            }.frame(maxWidth: .infinity, minHeight: 60)
                .background(ArchiveDesign.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain).foregroundStyle(ArchiveDesign.accent).accessibilityIdentifier("edit-\(kind.rawValue)")
    }
}

enum MemoryEditorKind: String, Identifiable { case mood, note, music; var id: Self { self } }

private struct MoodEditorView: View {
    let date: Date
    @EnvironmentObject private var archive: MoodArchiveStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("为这一天选一种颜色").font(.title2.bold())
                    Text("没有好坏，只是记录此刻的感觉。").font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ForEach(0..<9, id: \.self) { level in
                            let selected = archive.moodLevel(for: date) == level
                            Button {
                                archive.setMood(level, for: date); dismiss()
                            } label: {
                                VStack(spacing: 10) {
                                    Circle().fill(ArchiveDesign.moodBlobColor(level: level)).frame(width: 32, height: 32)
                                        .overlay { if selected { Image(systemName: "checkmark").foregroundStyle(.black.opacity(0.7)) } }
                                    Text(MoodLabel.name(level)).font(.subheadline)
                                }.frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(selected ? ArchiveDesign.accent.opacity(0.12) : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    if archive.moodLevel(for: date) != nil {
                        Button("清除当天心情", role: .destructive) { archive.setMood(nil, for: date); dismiss() }
                            .padding(.vertical, 12)
                    }
                }.padding(24)
            }.navigationTitle("当天心情").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}

private struct MemoryEditorView: View {
    let date: Date
    let kind: MemoryEditorKind
    @EnvironmentObject private var archive: MoodArchiveStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var note = ""
    @State private var title = ""
    @State private var artist = ""
    @State private var didLoad = false
    @State private var voiceBase = ""
    @State private var voiceSession = false
    @State private var saved = false
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            Form {
                if kind == .note {
                    Section {
                        ZStack(alignment: .topLeading) {
                            if note.isEmpty { Text("写下今天的一件小事…").foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 4).allowsHitTesting(false) }
                            TextEditor(text: $note).frame(minHeight: 220).focused($focused)
                                .disabled(recorder.isRecording || recorder.isStarting)
                                .accessibilityLabel("当天笔记").accessibilityIdentifier("note-editor")
                        }
                    }
                    Section {
                        Button {
                            focused = false
                            if recorder.isRecording || recorder.isStarting { recorder.stop() }
                            else {
                                voiceBase = note; voiceSession = true
                                Task { await recorder.start() }
                            }
                        } label: {
                            Label(recorder.isStarting ? "正在准备…" : recorder.isRecording ? "结束语音输入" : "用语音补充",
                                  systemImage: recorder.isRecording ? "stop.circle.fill" : "mic")
                        }
                        if !recorder.statusText.isEmpty { Text(recorder.statusText).font(.caption).foregroundStyle(.secondary) }
                    } footer: { Text("识别结果会接在原有文字后面。语音仅在本机识别，音频不保存。") }
                } else {
                    Section {
                        TextField("歌名", text: $title).accessibilityIdentifier("song-title")
                        TextField("歌手 / 一句回忆", text: $artist)
                    } header: { Text("这一天的背景音乐") } footer: { Text("留下一首歌的名字，下次看到时想起这一天。") }
                }
                Section { Label(saved ? "已自动保存到本机" : "编辑后自动保存", systemImage: saved ? "checkmark.circle" : "internaldrive").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle(kind == .note ? "当天笔记" : "当天歌曲").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { recorder.stop(); dismiss() } } }
            .onAppear {
                guard !didLoad else { return }
                note = archive.note(for: date)
                let track = archive.soundtrack(for: date); title = track.title; artist = track.artist
                didLoad = true
            }
            .onChange(of: note) { _, value in
                guard didLoad else { return }; archive.setNote(value, for: date); saved = true
            }
            .onChange(of: title) { _, _ in saveTrack() }
            .onChange(of: artist) { _, _ in saveTrack() }
            .onChange(of: recorder.transcript) { _, transcript in
                guard voiceSession, !transcript.isEmpty else { return }
                note = voiceBase + (voiceBase.isEmpty ? "" : "\n") + transcript
            }
            .onChange(of: scenePhase) { _, phase in if phase == .background { recorder.stop() } }
            .onDisappear { recorder.stop() }
        }
    }
    private func saveTrack() {
        guard didLoad else { return }
        archive.setSoundtrack(SoundtrackMemory(title: title, artist: artist), for: date); saved = true
    }
}

struct PhotoPagerView: View {
    let photos: [PhotoAsset]
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String
    @State private var busy = false
    @State private var confirmDelete = false
    @State private var sharedImage: ShareImage?
    @State private var shareTask: Task<Void, Never>?
    init(photos: [PhotoAsset], initialPhoto: PhotoAsset) {
        self.photos = photos
        _selectedID = State(initialValue: initialPhoto.id)
    }
    private var visible: [PhotoAsset] {
        let live = Set(library.allAssets.map(\.id))
        return photos.filter { live.contains($0.id) }
    }
    private var current: PhotoAsset? { visible.first { $0.id == selectedID } }
    private var position: Int { (visible.firstIndex { $0.id == selectedID } ?? 0) + 1 }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("关闭", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                Spacer()
                VStack(spacing: 3) {
                    if let current { Text(ArchiveCalendar.title(current.creationDate, format: "M月d日 HH:mm")).font(.subheadline) }
                    Text("\(visible.isEmpty ? 0 : position) / \(visible.count)").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }.padding(.horizontal, 14).padding(.top, 4)
            TabView(selection: $selectedID) {
                ForEach(visible) { photo in
                    PhotoPreviewPage(photo: photo, isSelected: selectedID == photo.id).tag(photo.id)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never))
            HStack {
                Button { shareCurrent() } label: { Label("分享", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 52) }
                Button {
                    guard let photo = current else { return }
                    busy = true
                    Task { await library.toggleFavorite(photo); busy = false }
                } label: {
                    let favorite = current.map { library.isFavorite($0) } ?? false
                    Label(favorite ? "已收藏" : "收藏", systemImage: favorite ? "heart.fill" : "heart").frame(maxWidth: .infinity, minHeight: 52)
                }
                Button { confirmDelete = true } label: { Label("删除", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 52) }
            }.font(.subheadline).disabled(busy || current == nil).padding(.horizontal, 14)
            if busy { ProgressView().tint(.white).padding(6).accessibilityLabel("正在处理照片") }
        }
        .foregroundStyle(.white).background(.black).preferredColorScheme(.dark)
        .alert("从系统相册删除这张照片？", isPresented: $confirmDelete) {
            Button("删除照片", role: .destructive) {
                guard let photo = current else { return }
                busy = true
                Task { _ = await library.deletePhoto(photo); busy = false }
            }
            Button("取消", role: .cancel) {}
        } message: { Text("删除会同步到系统相册及 iCloud 照片，可在系统相册的“最近删除”中恢复。当天的笔记和心情会保留。") }
        .alert("操作未完成", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
            Button("好") { library.errorMessage = nil }
        } message: { Text(library.errorMessage ?? "") }
        .sheet(item: $sharedImage) { ShareSheet(image: $0.image) }
        .onChange(of: visible.map(\.id)) { old, new in
            if new.isEmpty { dismiss() }
            else if !new.contains(selectedID) {
                let previousIndex = old.firstIndex(of: selectedID) ?? 0
                selectedID = new[min(previousIndex, new.count - 1)]
            }
        }
        .onDisappear { shareTask?.cancel() }
    }
    private func shareCurrent() {
        guard let photo = current else { return }
        busy = true
        shareTask = Task {
            defer { busy = false }
            do {
                let image = try await library.image(for: photo, size: CGSize(width: 2400, height: 2400), preview: true)
                try Task.checkCancellation()
                sharedImage = ShareImage(image: image)
            } catch is CancellationError {} catch { library.errorMessage = "暂时无法下载照片，请检查网络后重试。" }
        }
    }
}
private struct ShareImage: Identifiable { let id = UUID(); let image: UIImage }
private struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [image], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct PhotoPreviewPage: View {
    let photo: PhotoAsset
    let isSelected: Bool
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var image: UIImage?
    @State private var failed = false
    @State private var retry = 0
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image { ZoomablePhoto(image: image).id(photo.id) }
                else if failed {
                    VStack(spacing: 16) {
                        Image(systemName: "icloud.slash").font(.largeTitle)
                        Text("暂时无法加载照片").font(.headline)
                        Text("照片可能在 iCloud 中，请检查网络后重试。").font(.caption).foregroundStyle(.secondary)
                        Button("重新加载") { retry += 1 }.buttonStyle(.bordered)
                    }.padding().multilineTextAlignment(.center)
                } else { ProgressView("正在加载照片…").tint(.white) }
            }
            .task(id: "\(isSelected)-\(retry)-\(library.revision)") {
                guard isSelected else { image = nil; return }
                failed = false
                do {
                    image = try await library.image(for: photo,
                        size: CGSize(width: max(geometry.size.width * 3, 1200), height: max(geometry.size.height * 3, 1200)), preview: true)
                } catch is CancellationError {} catch { failed = true }
            }
        }
    }
}

private struct ZoomablePhoto: UIViewRepresentable {
    let image: UIImage
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = FittingScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1; scroll.maximumZoomScale = 4
        scroll.showsHorizontalScrollIndicator = false; scroll.showsVerticalScrollIndicator = false
        scroll.bouncesZoom = true; scroll.backgroundColor = .black
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "照片，可双指缩放或双击放大"
        scroll.addSubview(imageView)
        scroll.imageView = imageView
        context.coordinator.imageView = imageView
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2; scroll.addGestureRecognizer(tap)
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) { context.coordinator.imageView?.image = image }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? UIScrollView else { return }
            if scroll.zoomScale > 1.01 { scroll.setZoomScale(1, animated: true) }
            else {
                let point = gesture.location(in: imageView)
                let size = CGSize(width: scroll.bounds.width / 2.5, height: scroll.bounds.height / 2.5)
                scroll.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
            }
        }
    }
    final class FittingScrollView: UIScrollView {
        weak var imageView: UIImageView?
        private var lastSize = CGSize.zero
        override func layoutSubviews() {
            super.layoutSubviews()
            if bounds.size != lastSize {
                lastSize = bounds.size
                setZoomScale(1, animated: false)
                imageView?.frame = CGRect(origin: .zero, size: bounds.size)
                contentSize = bounds.size
            }
        }
    }
}
