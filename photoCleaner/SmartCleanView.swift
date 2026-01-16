import Photos
import SwiftUI
import UIKit

struct SmartCleanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = SmartCleanViewModel()
    @State private var showResults: Bool = false

    private let accent = Color(red: 0.00, green: 0.67, blue: 0.95)

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                Spacer().frame(height: 8)

                if vm.isAuthorizedForReading {
                    scanningContent
                } else {
                    permissionContent
                }
            }
        }
        .task {
            await vm.ensureAuthorizedAndStart()
        }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showResults) {
            if let summary = vm.scanSummary {
                SmartCleanResultsView(summary: summary)
            } else {
                SmartCleanResultsView(
                    summary: SmartCleanScanSummary(
                        similarCount: 0, similarBytes: 0,
                        duplicatesCount: 0, duplicatesBytes: 0,
                        screenshotsCount: 0, screenshotsBytes: 0,
                        largeVideosCount: 0, largeVideosBytes: 0,
                        duplicateDeleteIDs: [], screenshotIDs: [], largeVideoIDs: []
                    )
                )
            }
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }

            Text("SMART CLEAN")
                .font(.system(size: 22, weight: .heavy))
                .tracking(4)
        }
    }

    private var permissionContent: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 24)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Photo access required")
                .font(.title2.bold())

            Text("We need access to scan your library and suggest items to clean. Scanning is performed on-device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Request Access") { Task { await vm.requestAuthorization() } }
                    .buttonStyle(.borderedProminent)

                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 18)
    }

    private var scanningContent: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                VStack(spacing: 18) {
                    SmartCleanRing(progress: vm.overallProgress, accent: accent, isComplete: vm.isScanComplete)
                        .frame(width: min(geo.size.width, 320), height: min(geo.size.width, 320))
                        .padding(.top, 10)

                    VStack(spacing: 10) {
                        Text("CURRENT ACTIVITY")
                            .font(.system(size: 18, weight: .heavy))
                            .tracking(3)
                            .foregroundStyle(Color(.secondaryLabel))

                        Text(vm.currentActivityTitle)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text(vm.currentActivitySubtitle)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                            .italic()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.top, 6)

                    overallProgressBar

                    summaryCards

                    Spacer(minLength: 0)

                    stopButton

                    Text("SCANNING ENGINE V4.2 • SECURED WITH ON-DEVICE AI")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Color(.systemGray3))
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 18)
    }

    private var overallProgressBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Overall Progress")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(vm.scannedCount) / \(max(vm.totalCount, 1)) files")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            ProgressView(value: vm.overallProgress)
                .tint(accent)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
        .padding(.top, 14)
    }

    private var summaryCards: some View {
        HStack(spacing: 14) {
            SmartCleanMiniCard(
                icon: "doc.on.doc",
                title: "DUPLICATES",
                value: "\(vm.duplicatesDeletableCount)",
                accent: accent
            )
            SmartCleanMiniCard(
                icon: "video",
                title: "LARGE",
                value: vm.largeVideosTotalText,
                accent: accent
            )
            SmartCleanMiniCard(
                icon: "viewfinder",
                title: "SCREENSHOTS",
                value: "\(vm.screenshotCount)",
                accent: accent
            )
        }
        .padding(.top, 16)
    }

    private var stopButton: some View {
        Button {
            if vm.isScanComplete {
                showResults = true
            } else if vm.isScanning {
                vm.cancelScan()
            } else {
                vm.startScanFromUI()
            }
        } label: {
            Text(vm.isScanning ? "STOP INTELLIGENT SCAN" : (vm.isScanComplete ? "CLEAN" : "START INTELLIGENT SCAN"))
                .font(.system(size: 20, weight: .heavy))
                .tracking(3)
                .foregroundStyle(Color(.secondaryLabel))
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 16)
        .disabled(vm.isScanning == false && vm.totalCount == 0 && !vm.isScanComplete)
    }
}

// MARK: - Components

private struct SmartCleanRing: View {
    let progress: Double // 0...1
    let accent: Color
    var isComplete: Bool = false

    var body: some View {
        ZStack {
            // Soft background ring
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.92, green: 0.98, blue: 1.0), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle().stroke(Color(.systemGray5), lineWidth: 6)
                }

            // Inner thin circles
            ForEach([0.70, 0.52, 0.36], id: \.self) { s in
                Circle()
                    .stroke(Color(red: 0.00, green: 0.67, blue: 0.95).opacity(0.25), lineWidth: 2)
                    .scaleEffect(s)
            }

            // Progress arc
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(6)

            VStack(spacing: 8) {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.primary)
                Text(isComplete ? "COMPLETE" : "ANALYZING")
                    .font(.system(size: 18, weight: .heavy))
                    .tracking(4)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }
}

private struct SmartCleanMiniCard: View {
    let icon: String
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(accent)

            Text(title)
                .font(.system(size: 16, weight: .heavy))
                .tracking(2)
                .foregroundStyle(.primary)

            Text(value)
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
    }
}

// MARK: - ViewModel / Scan Logic

@MainActor
private final class SmartCleanViewModel: ObservableObject {
    enum Phase: String {
        case idle
        case duplicates
        case largeVideos
        case screenshots
        case done
    }

    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var isScanning: Bool = false
    @Published var phase: Phase = .idle

    @Published var totalCount: Int = 0
    @Published var scannedCount: Int = 0

    @Published var currentActivityTitle: String = "Preparing…"
    @Published var currentActivitySubtitle: String = ""

    @Published var duplicatesDeletableCount: Int = 0
    @Published var largeVideosTotalBytes: Int64 = 0
    @Published var screenshotCount: Int = 0
    @Published var scanSummary: SmartCleanScanSummary?

    @Published var errorMessage: String?

    private let imageManager = PHCachingImageManager()
    private var scanTask: Task<Void, Never>?

    var isAuthorizedForReading: Bool {
        switch authorizationStatus {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    var overallProgress: Double {
        guard totalCount > 0 else { return 0 }
        return min(1, Double(scannedCount) / Double(totalCount))
    }

    var isScanComplete: Bool {
        phase == .done && totalCount > 0 && scannedCount >= totalCount
    }

    var largeVideosTotalText: String {
        guard largeVideosTotalBytes > 0 else { return "0 B" }
        // Design shows "2.4 GB" style
        let gb = Double(largeVideosTotalBytes) / Double(1024 * 1024 * 1024)
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(largeVideosTotalBytes) / Double(1024 * 1024)
        return mb >= 10 ? "\(Int(mb.rounded())) MB" : String(format: "%.1f MB", mb)
    }

    func ensureAuthorizedAndStart() async {
        refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            await requestAuthorization()
        }
        if isAuthorizedForReading {
            startScan()
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        if isAuthorizedForReading {
            startScan()
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        phase = .idle
        currentActivityTitle = "Scan stopped"
        currentActivitySubtitle = ""
    }

    func startScanFromUI() {
        startScan()
    }

    private func startScan() {
        if isScanning { return }
        isScanning = true
        phase = .duplicates
        scannedCount = 0
        duplicatesDeletableCount = 0
        largeVideosTotalBytes = 0
        screenshotCount = 0
        scanSummary = nil

        scanTask = Task { await runScan() }
    }

    private func runScan() async {
        defer {
            isScanning = false
            scanTask = nil
        }

        // Total files = images + videos (simple & stable; matches "files" label)
        let images = PHAsset.fetchAssets(with: .image, options: nil)
        let videos = PHAsset.fetchAssets(with: .video, options: nil)
        totalCount = images.count + videos.count

        // Phase 1: duplicates & similar (aHash)
        phase = .duplicates
        currentActivityTitle = "Analyzing Duplicates…"
        currentActivitySubtitle = ""

        struct ImgInfo {
            let asset: PHAsset
            let id: String
            let hash: UInt64
            let sizeBytes: Int64
        }

        var imageInfos: [ImgInfo] = []
        imageInfos.reserveCapacity(images.count)

        // Exact hash buckets for duplicates
        var buckets: [UInt64: [ImgInfo]] = [:]
        buckets.reserveCapacity(min(images.count, 4096))

        for i in 0..<images.count {
            if Task.isCancelled { return }
            let asset = images.object(at: i)
            if let name = bestFilename(asset: asset) { currentActivitySubtitle = name }
            if let thumb = await requestHashThumbnail(asset: asset),
               let h = averageHash(of: thumb)
            {
                let bytes = estimatedPhotoFileSizeBytes(asset: asset) ?? 0
                let info = ImgInfo(asset: asset, id: asset.localIdentifier, hash: h, sizeBytes: bytes)
                imageInfos.append(info)
                buckets[h, default: []].append(info)
            }
            scannedCount += 1
        }

        // Build delete list for duplicates: keep 1 (first), delete the rest
        var duplicateDeleteIDs: [String] = []
        var duplicateDeleteBytes: Int64 = 0
        for (_, infos) in buckets where infos.count >= 2 {
            let sorted = infos // already stable enough for MVP
            for info in sorted.dropFirst() {
                duplicateDeleteIDs.append(info.id)
                duplicateDeleteBytes += info.sizeBytes
            }
        }
        duplicatesDeletableCount = duplicateDeleteIDs.count

        // Similar candidates (bucket by prefix then hamming cluster)
        let similarThreshold = 8
        func prefix(_ h: UInt64) -> UInt16 { UInt16((h >> 52) & 0x0FFF) }
        var byPrefix: [UInt16: [ImgInfo]] = [:]
        byPrefix.reserveCapacity(min(imageInfos.count, 4096))
        for info in imageInfos {
            byPrefix[prefix(info.hash), default: []].append(info)
        }
        var similarDeleteIDs: [String] = []
        var similarDeleteBytes: Int64 = 0
        var similarItemCount: Int = 0
        for (_, infos) in byPrefix where infos.count >= 2 {
            if Task.isCancelled { return }
            var clusters: [[ImgInfo]] = []
            for info in infos {
                var placed = false
                for i in clusters.indices {
                    if let rep = clusters[i].first, hammingDistance(rep.hash, info.hash) <= similarThreshold {
                        clusters[i].append(info)
                        placed = true
                        break
                    }
                }
                if !placed { clusters.append([info]) }
            }
            for c in clusters where c.count >= 2 {
                similarItemCount += c.count
                // keep one, delete rest (safe for "redundant" claim when very similar)
                for info in c.dropFirst() {
                    similarDeleteIDs.append(info.id)
                    similarDeleteBytes += info.sizeBytes
                }
            }
        }

        // Phase 2: large videos (sum bytes above threshold)
        phase = .largeVideos
        currentActivityTitle = "Analyzing Large Videos…"

        let largeThreshold: Int64 = 200 * 1024 * 1024 // 200MB
        var largeTotal: Int64 = 0
        var largeIDs: [String] = []
        var largeCount: Int = 0
        for i in 0..<videos.count {
            if Task.isCancelled { return }
            let asset = videos.object(at: i)
            let name = bestFilename(asset: asset) ?? "video"
            let bytes = estimatedFileSizeBytes(asset: asset)
            if let bytes, bytes >= largeThreshold {
                largeTotal += bytes
                largeIDs.append(asset.localIdentifier)
                largeCount += 1
                currentActivitySubtitle = "\(name) (\(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)))"
            } else {
                currentActivitySubtitle = name
            }
            scannedCount += 1
        }
        largeVideosTotalBytes = largeTotal

        // Phase 3: screenshots (fast fetch)
        phase = .screenshots
        currentActivityTitle = "Analyzing Screenshots…"
        currentActivitySubtitle = ""
        let screenshots = fetchScreenshotAssets()
        screenshotCount = screenshots.count
        var screenshotIDs: [String] = []
        var screenshotBytes: Int64 = 0
        for i in 0..<screenshots.count {
            if Task.isCancelled { return }
            let a = screenshots.object(at: i)
            screenshotIDs.append(a.localIdentifier)
            screenshotBytes += estimatedPhotoFileSizeBytes(asset: a) ?? 0
        }

        phase = .done
        currentActivityTitle = "Scan complete"
        currentActivitySubtitle = ""

        scanSummary = SmartCleanScanSummary(
            similarCount: max(0, similarItemCount),
            similarBytes: max(0, similarDeleteBytes),
            duplicatesCount: duplicatesDeletableCount,
            duplicatesBytes: max(0, duplicateDeleteBytes),
            screenshotsCount: screenshotCount,
            screenshotsBytes: max(0, screenshotBytes),
            largeVideosCount: largeCount,
            largeVideosBytes: max(0, largeTotal),
            duplicateDeleteIDs: duplicateDeleteIDs,
            screenshotIDs: screenshotIDs,
            largeVideoIDs: largeIDs
        )
    }

    private func fetchScreenshotAssets() -> PHFetchResult<PHAsset> {
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
        return PHAsset.fetchAssets(with: .image, options: opts)
    }

    private func requestHashThumbnail(asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let opts = PHImageRequestOptions()
            opts.isSynchronous = false
            opts.deliveryMode = .highQualityFormat
            opts.resizeMode = .exact
            opts.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 96, height: 96),
                contentMode: .aspectFit,
                options: opts
            ) { image, info in
                guard !didResume else { return }
                let cancelled = (info?[PHImageCancelledKey] as? NSNumber)?.boolValue ?? false
                if cancelled {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }
                if let _ = info?[PHImageErrorKey] {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }
                if let image {
                    didResume = true
                    continuation.resume(returning: image)
                }
            }
        }
    }

    private func bestFilename(asset: PHAsset) -> String? {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.originalFilename
    }

    private func estimatedFileSizeBytes(asset: PHAsset) -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        let preferred = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) ?? resources.first
        guard let preferred else { return nil }
        if let n = preferred.value(forKey: "fileSize") as? NSNumber {
            return n.int64Value
        }
        return nil
    }

    private func estimatedPhotoFileSizeBytes(asset: PHAsset) -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        let preferred = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto || $0.type == .alternatePhoto }) ?? resources.first
        guard let preferred else { return nil }
        if let n = preferred.value(forKey: "fileSize") as? NSNumber {
            return n.int64Value
        }
        return nil
    }
}

private func averageHash(of image: UIImage) -> UInt64? {
    let normalized = normalizeOrientation(image)
    guard let cgImage = normalized.cgImage else { return nil }

    let width = 8
    let height = 8
    let bytesPerRow = width
    var pixels = [UInt8](repeating: 0, count: width * height)

    guard let ctx = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .high
    ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    let sum = pixels.reduce(0) { $0 + Int($1) }
    let avg = UInt8(sum / pixels.count)

    var hash: UInt64 = 0
    for i in 0..<pixels.count {
        if pixels[i] >= avg {
            hash |= (1 << (63 - UInt64(i)))
        }
    }
    return hash
}

private func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
    (a ^ b).nonzeroBitCount
}

private func normalizeOrientation(_ image: UIImage) -> UIImage {
    if image.imageOrientation == .up { return image }
    let renderer = UIGraphicsImageRenderer(size: image.size)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: image.size))
    }
}

#Preview {
    SmartCleanView()
}


