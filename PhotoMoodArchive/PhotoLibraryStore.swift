import ImageIO
import Photos
import SwiftUI
import UIKit

@MainActor
final class PhotoLibraryStore: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    @Published private(set) var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var assetsByDay: [String: [PhotoAsset]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var indexedAssetCount = 0
    @Published private(set) var totalAssetCount = 0
    @Published private(set) var favoriteStateByID: [String: Bool] = [:]

    private let imageManager = PHCachingImageManager()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private var assetIndex: [String: PHAsset] = [:]
    private var pendingThumbnailRequests: [String: [(UIImage?) -> Void]] = [:]
    private var didLoadAssets = false
    private var cachedSourceAssetCount = 0
    private var cachedLatestSourceAssetID = ""
    private var cachedSourceFingerprint: [String] = []
    private let cacheVersion = 4
    private let sourceFingerprintLimit = 40

    private struct CachedPhotoIndex: Codable {
        let version: Int
        let sourceAssetCount: Int
        let latestSourceAssetID: String
        let sourceFingerprint: [String]
        let savedAt: Date
        let assets: [PhotoAsset]
    }

    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            await handlePhotoLibraryChange()
        }
    }

    func requestAccessAndLoad() async {
        if isLoading || didLoadAssets { return }

        let didRestoreCache = restoreCachedIndex()
        let status = await requestAuthorization()
        authorizationStatus = status
        guard status == .authorized || status == .limited else { return }

        if didRestoreCache {
            await refreshCacheIfNeededSilently()
        } else {
            await loadAssets(showLoading: true)
        }
    }

    func loadAssets(showLoading: Bool) async {
        if isLoading { return }

        if showLoading {
            isLoading = true
        }
        indexedAssetCount = 0
        totalAssetCount = 0
        defer {
            if showLoading {
                isLoading = false
            }
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        totalAssetCount = result.count
        let sourceFingerprint = sourceFingerprint(from: result)

        var grouped: [String: [PhotoAsset]] = [:]
        var indexedAssets: [String: PHAsset] = [:]
        var favorites: [String: Bool] = [:]
        for index in 0..<result.count {
            if Task.isCancelled { return }

            let asset = result.object(at: index)
            guard await Self.shouldIncludeCameraPhoto(asset) else {
                if index.isMultiple(of: 100) {
                    indexedAssetCount = index + 1
                    await Task.yield()
                }
                continue
            }
            guard let date = asset.creationDate else { continue }
            indexedAssets[asset.localIdentifier] = asset
            favorites[asset.localIdentifier] = asset.isFavorite
            grouped[date.archiveKey(), default: []].append(
                PhotoAsset(
                    id: asset.localIdentifier,
                    creationDate: date,
                    latitude: asset.location?.coordinate.latitude,
                    longitude: asset.location?.coordinate.longitude
                )
            )

            if index.isMultiple(of: 100) {
                indexedAssetCount = index + 1
                await Task.yield()
            }
        }
        indexedAssetCount = result.count
        assetIndex = indexedAssets
        assetsByDay = grouped
        favoriteStateByID = favorites
        didLoadAssets = true
        cachedSourceAssetCount = result.count
        cachedLatestSourceAssetID = result.firstObject?.localIdentifier ?? ""
        cachedSourceFingerprint = sourceFingerprint
        saveCachedIndex(
            sourceAssetCount: result.count,
            latestSourceAssetID: cachedLatestSourceAssetID,
            sourceFingerprint: sourceFingerprint,
            assets: grouped.values.flatMap { $0 }
        )
    }

    private func restoreCachedIndex() -> Bool {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(CachedPhotoIndex.self, from: data),
              cache.version == cacheVersion,
              !cache.assets.isEmpty else {
            return false
        }

        assetsByDay = Dictionary(grouping: cache.assets, by: { $0.creationDate.archiveKey() })
        cachedSourceAssetCount = cache.sourceAssetCount
        cachedLatestSourceAssetID = cache.latestSourceAssetID
        cachedSourceFingerprint = cache.sourceFingerprint
        indexedAssetCount = cache.assets.count
        totalAssetCount = cache.sourceAssetCount
        didLoadAssets = true
        return true
    }

    private func saveCachedIndex(
        sourceAssetCount: Int,
        latestSourceAssetID: String,
        sourceFingerprint: [String],
        assets: [PhotoAsset]
    ) {
        let cache = CachedPhotoIndex(
            version: cacheVersion,
            sourceAssetCount: sourceAssetCount,
            latestSourceAssetID: latestSourceAssetID,
            sourceFingerprint: sourceFingerprint,
            savedAt: Date(),
            assets: assets.sorted { $0.creationDate > $1.creationDate }
        )

        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheURL, options: [.atomic])
        } catch {
            // Cache failures should never block the archive itself.
        }
    }

    private var cacheURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("PhotoMoodArchive", isDirectory: true)
            .appendingPathComponent("photo-index-v\(cacheVersion).json")
    }

    private func refreshCacheIfNeededSilently() async {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)
        let currentSourceAssetCount = result.count
        let currentLatestSourceAssetID = result.firstObject?.localIdentifier ?? ""
        let currentSourceFingerprint = sourceFingerprint(from: result)
        guard currentSourceAssetCount != cachedSourceAssetCount ||
            currentLatestSourceAssetID != cachedLatestSourceAssetID ||
            currentSourceFingerprint != cachedSourceFingerprint else { return }

        await mergePhotoLibraryChanges(from: result)
    }

    private func mergePhotoLibraryChanges(from result: PHFetchResult<PHAsset>) async {
        let cachedAssetsByID = Dictionary(uniqueKeysWithValues: allAssets.map { ($0.id, $0) })
        var knownIDs = Set(cachedAssetsByID.keys)
        var liveIDs = Set<String>()
        var grouped: [String: [PhotoAsset]] = [:]
        var indexedAssets = assetIndex
        var favorites = favoriteStateByID
        var indexedCount = 0

        totalAssetCount = result.count

        for index in 0..<result.count {
            if Task.isCancelled { return }

            let asset = result.object(at: index)
            let id = asset.localIdentifier
            liveIDs.insert(id)
            indexedAssets[id] = asset
            favorites[id] = asset.isFavorite

            if let cached = cachedAssetsByID[id] {
                grouped[cached.creationDate.archiveKey(), default: []].append(cached)
            } else if await Self.shouldIncludeCameraPhoto(asset), let date = asset.creationDate {
                grouped[date.archiveKey(), default: []].append(
                    PhotoAsset(
                        id: id,
                        creationDate: date,
                        latitude: asset.location?.coordinate.latitude,
                        longitude: asset.location?.coordinate.longitude
                    )
                )
            }

            indexedCount = index + 1
            if index.isMultiple(of: 100) {
                indexedAssetCount = indexedCount
                await Task.yield()
            }
        }

        knownIDs.subtract(liveIDs)
        for removedID in knownIDs {
            indexedAssets[removedID] = nil
            favorites[removedID] = nil
        }

        assetIndex = indexedAssets
        assetsByDay = grouped
        favoriteStateByID = favorites
        indexedAssetCount = indexedCount
        cachedSourceAssetCount = result.count
        cachedLatestSourceAssetID = result.firstObject?.localIdentifier ?? ""
        cachedSourceFingerprint = sourceFingerprint(from: result)
        saveCachedIndex(
            sourceAssetCount: cachedSourceAssetCount,
            latestSourceAssetID: cachedLatestSourceAssetID,
            sourceFingerprint: cachedSourceFingerprint,
            assets: grouped.values.flatMap { $0 }
        )
    }

    private func sourceFingerprint(from result: PHFetchResult<PHAsset>) -> [String] {
        let count = min(result.count, sourceFingerprintLimit)
        guard count > 0 else { return [] }
        return (0..<count).map { result.object(at: $0).localIdentifier }
    }

    private func handlePhotoLibraryChange() async {
        guard didLoadAssets, !isLoading else { return }
        guard authorizationStatus == .authorized || authorizationStatus == .limited else { return }
        await refreshCacheIfNeededSilently()
    }

    private static func shouldIncludeCameraPhoto(_ asset: PHAsset) async -> Bool {
        guard asset.mediaType == .image else { return false }

        if asset.mediaSubtypes.contains(.photoScreenshot) {
            return false
        }

        if asset.mediaSubtypes.contains(.photoLive) {
            return true
        }

        let photoResources = PHAssetResource.assetResources(for: asset).filter { resource in
            resource.type == .photo || resource.type == .fullSizePhoto || resource.type == .alternatePhoto
        }

        guard photoResources.contains(where: { isImageResourceName($0.originalFilename) }) else {
            return false
        }

        return await hasCameraMetadata(asset)
    }

    private static func isImageResourceName(_ filename: String) -> Bool {
        let uppercasedName = filename.uppercased()
        let extensionName = (uppercasedName as NSString).pathExtension

        let cameraExtensions: Set<String> = [
            "HEIC", "HEIF", "JPG", "JPEG", "DNG", "TIFF", "TIF"
        ]
        return cameraExtensions.contains(extensionName)
    }

    private static func hasCameraMetadata(_ asset: PHAsset) async -> Bool {
        await withCheckedContinuation { continuation in
            var didResume = false
            let resumeOnce: (Bool) -> Void = { value in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = false
            asset.requestContentEditingInput(with: options) { input, _ in
                guard let url = input?.fullSizeImageURL,
                      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
                    resumeOnce(false)
                    return
                }

                let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
                let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
                let hasMake = nonEmptyString(tiff?[kCGImagePropertyTIFFMake])
                let hasModel = nonEmptyString(tiff?[kCGImagePropertyTIFFModel])
                let hasLensModel = nonEmptyString(exif?[kCGImagePropertyExifLensModel])
                resumeOnce(hasMake || hasModel || hasLensModel)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                resumeOnce(false)
            }
        }
    }

    private static func nonEmptyString(_ value: Any?) -> Bool {
        guard let string = value as? String else { return false }
        return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func assets(for date: Date) -> [PhotoAsset] {
        assetsByDay[date.archiveKey(), default: []]
    }

    var allAssets: [PhotoAsset] {
        assetsByDay.values.flatMap { $0 }
    }

    var latestAssetMonth: Date? {
        let calendar = Calendar.current
        return allAssets.compactMap { asset in
            calendar.dateInterval(of: .month, for: asset.creationDate)?.start
        }
        .max()
    }

    func requestImage(for photo: PhotoAsset, size: CGSize, allowsNetworkAccess: Bool = false, completion: @escaping (UIImage?) -> Void) {
        let normalizedSize = CGSize(
            width: min(max(size.width, 80), 900),
            height: min(max(size.height, 80), 900)
        )
        let cacheKey = "\(photo.id)-\(Int(normalizedSize.width))x\(Int(normalizedSize.height))-\(allowsNetworkAccess)" as NSString

        if let cached = thumbnailCache.object(forKey: cacheKey) {
            completion(cached)
            return
        }

        guard let asset = photoKitAsset(for: photo.id) else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = allowsNetworkAccess

        if pendingThumbnailRequests[cacheKey as String] != nil {
            pendingThumbnailRequests[cacheKey as String]?.append(completion)
            return
        }

        pendingThumbnailRequests[cacheKey as String] = [completion]
        imageManager.requestImage(
            for: asset,
            targetSize: normalizedSize,
            contentMode: .aspectFill,
            options: options
        ) { [thumbnailCache] image, info in
            DispatchQueue.main.async {
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                let callbacks = self.pendingThumbnailRequests[cacheKey as String] ?? []

                if isDegraded {
                    callbacks.forEach { $0(image) }
                    return
                }

                if let image {
                    thumbnailCache.setObject(image, forKey: cacheKey)
                }
                let finalCallbacks = self.pendingThumbnailRequests.removeValue(forKey: cacheKey as String) ?? []
                finalCallbacks.forEach { $0(image) }
            }
        }
    }

    func requestPreviewImage(for photo: PhotoAsset, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard let asset = photoKitAsset(for: photo.id) else {
            completion(nil)
            return
        }

        let normalizedSize = CGSize(
            width: min(max(size.width, 320), 2400),
            height: min(max(size.height, 320), 2400)
        )
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        imageManager.requestImage(
            for: asset,
            targetSize: normalizedSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func isFavorite(_ photo: PhotoAsset) -> Bool {
        favoriteStateByID[photo.id] ?? photoKitAsset(for: photo.id)?.isFavorite ?? false
    }

    func toggleFavorite(_ photo: PhotoAsset) async {
        guard let asset = photoKitAsset(for: photo.id) else { return }
        let nextValue = !isFavorite(photo)
        let success = await performPhotoChange {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = nextValue
        }

        if success {
            favoriteStateByID[photo.id] = nextValue
        }
    }

    func deletePhoto(_ photo: PhotoAsset) async -> Bool {
        guard let asset = photoKitAsset(for: photo.id) else { return false }
        let success = await performPhotoChange {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }

        if success {
            assetIndex[photo.id] = nil
            favoriteStateByID[photo.id] = nil
            assetsByDay[photo.creationDate.archiveKey()]?.removeAll { $0.id == photo.id }
            cachedSourceAssetCount = max(cachedSourceAssetCount - 1, 0)
            cachedLatestSourceAssetID = allAssets.sorted { $0.creationDate > $1.creationDate }.first?.id ?? ""
            cachedSourceFingerprint.removeAll { $0 == photo.id }
            saveCachedIndex(
                sourceAssetCount: cachedSourceAssetCount,
                latestSourceAssetID: cachedLatestSourceAssetID,
                sourceFingerprint: cachedSourceFingerprint,
                assets: allAssets
            )
        }

        return success
    }

    func openInPhotos(_ photo: PhotoAsset) {
        let uuid = photo.id.components(separatedBy: "/").first ?? photo.id
        guard let encoded = uuid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "photos-redirect://asset?uuid=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    private func performPhotoChange(_ change: @escaping () -> Void) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges(change) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func photoKitAsset(for id: String) -> PHAsset? {
        if let asset = assetIndex[id] {
            return asset
        }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = result.firstObject else { return nil }
        assetIndex[id] = asset
        favoriteStateByID[id] = asset.isFavorite
        return asset
    }
}

struct PhotoThumbnailView: View {
    let photo: PhotoAsset
    let size: CGFloat
    var allowsNetworkAccess = false

    @EnvironmentObject private var photoLibrary: PhotoLibraryStore
    @State private var image: UIImage?
    @State private var didAttemptLoad = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if didAttemptLoad {
                Rectangle()
                    .fill(.thinMaterial)
                    .overlay {
                        Image(systemName: "icloud")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ArchiveDesign.secondaryInk.opacity(0.55))
                    }
            } else {
                Rectangle()
                    .fill(.thinMaterial)
                    .overlay(ProgressView().scaleEffect(0.72))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: photo.id) {
            didAttemptLoad = false
            photoLibrary.requestImage(
                for: photo,
                size: CGSize(width: size * 3, height: size * 3),
                allowsNetworkAccess: allowsNetworkAccess
            ) { fetched in
                image = fetched
                didAttemptLoad = true
            }
        }
    }
}
