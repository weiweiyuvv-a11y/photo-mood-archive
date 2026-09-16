import Photos
import PhotosUI
import SwiftUI
import UIKit

private struct LibrarySnapshot: @unchecked Sendable {
    let photos: [PhotoAsset]
    let assets: [String: PHAsset]
    let favorites: Set<String>
}

@MainActor
final class PhotoLibraryStore: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var allAssets: [PhotoAsset] = []
    @Published private(set) var assetsByDay: [String: [PhotoAsset]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var revision = 0
    @Published var errorMessage: String?
    private var assetIndex: [String: PHAsset] = [:]
    private let imageManager = PHCachingImageManager()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private var refreshAgain = false
    private var isRequestingPermission = false
    private var observing = false

    var hasAccess: Bool { authorizationStatus == .authorized || authorizationStatus == .limited }

    override init() {
        super.init()
        thumbnailCache.totalCostLimit = 48 * 1024 * 1024
    }
    deinit { if observing { PHPhotoLibrary.shared().unregisterChangeObserver(self) } }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in await self?.refresh() }
    }

    func requestAccessAndLoad() async {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        await refresh()
    }

    func refresh() async {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard hasAccess else { clearLibrary(); return }
        if !observing { PHPhotoLibrary.shared().register(self); observing = true }
        if isLoading { refreshAgain = true; return }
        isLoading = true
        defer { isLoading = false }
        repeat {
            refreshAgain = false
            let snapshot = await Task.detached(priority: .userInitiated) {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
                let result = PHAsset.fetchAssets(with: options)
                var photos: [PhotoAsset] = []
                var assets: [String: PHAsset] = [:]
                var favorites = Set<String>()
                result.enumerateObjects { asset, _, _ in
                    guard let date = asset.creationDate else { return }
                    assets[asset.localIdentifier] = asset
                    if asset.isFavorite { favorites.insert(asset.localIdentifier) }
                    photos.append(PhotoAsset(id: asset.localIdentifier, creationDate: date,
                                             latitude: asset.location?.coordinate.latitude,
                                             longitude: asset.location?.coordinate.longitude,
                                             isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)))
                }
                return LibrarySnapshot(photos: photos, assets: assets, favorites: favorites)
            }.value
            authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard hasAccess else { clearLibrary(); return }
            // A permission/library change during the scan requires a new authorized snapshot.
            if refreshAgain { continue }
            assetIndex = snapshot.assets
            favorites = snapshot.favorites
            allAssets = snapshot.photos
            assetsByDay = Dictionary(grouping: snapshot.photos, by: { $0.creationDate.archiveKey() })
            thumbnailCache.removeAllObjects()
            revision += 1
        } while refreshAgain
    }

    private func clearLibrary() {
        allAssets = []; assetsByDay = [:]; assetIndex = [:]; favorites = []
        thumbnailCache.removeAllObjects()
        revision += 1
    }

    func assets(for date: Date, filter: PhotoFilter = .all) -> [PhotoAsset] {
        (assetsByDay[date.archiveKey()] ?? []).filter { filter.includes($0, favorite: favorites.contains($0.id)) }
    }
    func filtered(_ filter: PhotoFilter) -> [PhotoAsset] {
        allAssets.filter { filter.includes($0, favorite: favorites.contains($0.id)) }
    }
    func isFavorite(_ photo: PhotoAsset) -> Bool { favorites.contains(photo.id) }

    func image(for photo: PhotoAsset, size: CGSize, preview: Bool = false, network: Bool = false) async throws -> UIImage {
        let generation = revision
        let key = "\(photo.id)-\(Int(size.width))-\(Int(size.height))-\(preview)-\(network)" as NSString
        if !preview, let cached = thumbnailCache.object(forKey: key) { return cached }
        guard hasAccess, let asset = assetIndex[photo.id] else { throw PhotoLoadError.unavailable }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = network || preview
        let request = PhotoImageRequest(manager: imageManager)
        let image = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                request.begin(continuation)
                let id = imageManager.requestImage(for: asset, targetSize: size,
                    contentMode: preview ? .aspectFit : .aspectFill, options: options) { @Sendable image, info in
                    if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                    if (info?[PHImageCancelledKey] as? Bool) == true {
                        request.finish(.failure(CancellationError()))
                    } else if let image {
                        request.finish(.success(image))
                    } else {
                        request.finish(.failure(PhotoLoadError.unavailable))
                    }
                }
                request.register(id)
            }
        } onCancel: { request.cancel() }
        try Task.checkCancellation()
        guard hasAccess, revision == generation else { throw CancellationError() }
        if !preview {
            thumbnailCache.setObject(image, forKey: key, cost: Int(image.size.width * image.size.height * image.scale * image.scale * 4))
        }
        return image
    }

    func toggleFavorite(_ photo: PhotoAsset) async {
        guard let asset = assetIndex[photo.id] else { return }
        let nextValue = !favorites.contains(photo.id)
        do {
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                PHAssetChangeRequest(for: asset).isFavorite = nextValue
            }
            if nextValue { favorites.insert(photo.id) } else { favorites.remove(photo.id) }
        } catch { errorMessage = "收藏未完成：\(error.localizedDescription)" }
    }

    func deletePhoto(_ photo: PhotoAsset) async -> Bool {
        guard let asset = assetIndex[photo.id] else { return false }
        do {
            try await PHPhotoLibrary.shared().performChanges { @Sendable in
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
            }
            allAssets.removeAll { $0.id == photo.id }
            assetsByDay[photo.creationDate.archiveKey()]?.removeAll { $0.id == photo.id }
            assetIndex[photo.id] = nil
            favorites.remove(photo.id)
            return true
        } catch {
            errorMessage = "删除未完成：\(error.localizedDescription)"
            return false
        }
    }

    func manageLimitedAccess() {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var controller = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
        while let presented = controller.presentedViewController { controller = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller) { @Sendable [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }
}

enum PhotoLoadError: Error { case unavailable }

// PhotoKit callbacks may arrive on any queue and cancellation can race completion.
// This gate resumes exactly once, and cancels the underlying request even if the
// Swift task was cancelled before PhotoKit supplied its request identifier.
private final class PhotoImageRequest: @unchecked Sendable {
    private let lock = NSLock()
    private let manager: PHImageManager
    private var continuation: CheckedContinuation<UIImage, Error>?
    private var requestID: PHImageRequestID?
    private var cancelled = false
    private var finished = false
    init(manager: PHImageManager) { self.manager = manager }
    func begin(_ continuation: CheckedContinuation<UIImage, Error>) {
        lock.lock()
        if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
        self.continuation = continuation
        lock.unlock()
    }
    func register(_ id: PHImageRequestID) {
        lock.lock(); requestID = id; let shouldCancel = cancelled; lock.unlock()
        if shouldCancel { manager.cancelImageRequest(id) }
    }
    func finish(_ result: Result<UIImage, Error>) {
        lock.lock()
        guard !finished, !cancelled else { lock.unlock(); return }
        finished = true
        let pending = continuation; continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
    func cancel() {
        lock.lock()
        cancelled = true
        let pending = continuation; continuation = nil
        let id = requestID
        lock.unlock()
        pending?.resume(throwing: CancellationError())
        if let id { manager.cancelImageRequest(id) }
    }
}

struct PhotoThumbnailView: View {
    let photo: PhotoAsset
    var size: CGFloat = 160
    var allowsNetworkAccess = false
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.tertiarySystemFill)
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else {
                    Image(systemName: failed ? "icloud" : "photo")
                        .foregroundStyle(.secondary).font(.caption)
                }
            }
        }
        .clipped()
        .task(id: "\(photo.id)-\(library.revision)") {
            image = nil; failed = false
            do {
                let fetched = try await library.image(for: photo, size: CGSize(width: size * 2, height: size * 2), network: allowsNetworkAccess)
                try Task.checkCancellation()
                image = fetched
            } catch is CancellationError {} catch { failed = true }
        }
        .accessibilityHidden(true)
    }
}
