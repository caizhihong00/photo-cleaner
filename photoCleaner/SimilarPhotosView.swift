import Photos
import SwiftUI
import UIKit

// MARK: - Public Entry

/// Similar Photos feature:
/// - Finds burst-like sets (burstIdentifier when available, otherwise grouped by time window)
/// - Lets user review one set at a time (swipe left = delete, right = keep)
struct SimilarPhotosView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = SimilarPhotosViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            Group {
                if vm.isAuthorizedForReading {
                    content
                } else {
                    permission
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { vm.refreshAuthorizationStatus() }
        .sheet(isPresented: $vm.showInfoSheet) {
            SimilarInfoSheet()
        }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .confirmationDialog("Delete selected photos?", isPresented: $vm.showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await vm.deleteMarkedInCurrentSet() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove photos you marked as Delete from your library.")
        }
    }

    private var permission: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 30)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Photo access required")
                .font(.title2.bold())

            Text("We need access to scan your library for similar photos. Scanning is performed on-device.")
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

    @ViewBuilder
    private var content: some View {
        if vm.isScanning {
            VStack(spacing: 0) {
                SimilarTopBar(title: "Similar Photos", onBack: { dismiss() }, onInfo: { vm.showInfoSheet = true })
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                SimilarScanningView(progress: vm.scanProgress, scanned: vm.scannedCount, total: vm.totalCount) {
                    vm.cancelScan()
                }
            }
        } else if let set = vm.currentSet {
            SimilarSetReviewView(
                similarSet: set,
                state: $vm.currentReviewState,
                imageProvider: vm.previewImage(for:targetSize:),
                thumbProvider: vm.thumbnail(for:targetSize:),
                fileSizeProvider: vm.fileSizeBytes(for:),
                onBack: { vm.leaveSet() },
                onInfo: { vm.showInfoSheet = true },
                onDone: { vm.showDeleteConfirm = true }
            )
        } else {
            VStack(spacing: 0) {
                SimilarTopBar(title: "Similar Photos", onBack: { dismiss() }, onInfo: { vm.showInfoSheet = true })
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                SimilarEmptyStateView(setCount: vm.sets.count, onScan: {
                    Task { await vm.scan() }
                })
            }
        }
    }
}

// MARK: - Scanning State UI

private struct SimilarScanningView: View {
    let progress: Double
    let scanned: Int
    let total: Int
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ProgressView(value: progress)
                .tint(Color(red: 0.00, green: 0.67, blue: 0.95))
                .frame(width: 240)
            Text("Scanning… \(scanned)/\(max(total, 1))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Stop", action: onStop)
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }
}

private struct SimilarEmptyStateView: View {
    let setCount: Int
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)
            Text("Similar Photos")
                .font(.system(size: 28, weight: .bold))
            Text(setCount > 0 ? "\(setCount) sets found" : "No sets yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Scan Similar Sets", action: onScan)
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            Spacer()
        }
        .padding(.horizontal, 18)
    }
}

// MARK: - Set Review UI (matches similiar.png)

private struct SimilarSetReviewView: View {
    let similarSet: SimilarSet
    @Binding var state: SimilarReviewState
    let imageProvider: (String, CGSize) async -> UIImage?
    let thumbProvider: (String, CGSize) async -> UIImage?
    let fileSizeProvider: (String) async -> Int64?
    let onBack: () -> Void
    let onInfo: () -> Void
    let onDone: () -> Void

    private let accent = Color(red: 0.00, green: 0.67, blue: 0.95)

    @State private var mainImage: UIImage?
    @State private var dragOffset: CGSize = .zero
    @State private var currentFileSizeBytes: Int64? = nil

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 10)

                VStack(spacing: 8) {
                    titleBlock
                    progressBar
                    Text("\(min(state.index + 1, similarSet.assets.count)) of \(similarSet.assets.count)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                        .padding(.top, 4)
                }
                .padding(.top, 4)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        mainCard(cardHeight: cardHeight(for: geo.size))
                            .padding(.top, 18)
                            .padding(.horizontal, 18)

                        recommendationBlock
                            .padding(.horizontal, 18)

                        swipeHint
                            .padding(.top, 10)

                        actionButtons(scale: buttonScale(for: geo.size))
                            .padding(.top, 14)

                        Spacer().frame(height: 18)
                    }
                    .padding(.bottom, 84)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomSaveBar
        }
        .task {
            await loadMainImage()
        }
        .onChange(of: state.index) { _, _ in
            Task { await loadMainImage() }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Button(action: onInfo) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .overlay { Circle().stroke(Color(.systemGray4), lineWidth: 1) }
                    Text("i")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .frame(width: 36, height: 36)
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text("Similar Photos")
                .font(.system(size: 30, weight: .bold))
            Text(similarSet.subtitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.top, 2)
    }

    private var progressBar: some View {
        HStack(spacing: 12) {
            ForEach(0..<max(progressSegmentCount, 1), id: \.self) { i in
                Capsule()
                    .fill(i == activeSegmentIndex ? accent : Color(.systemGray4))
                    .frame(height: 10)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
    }

    private func mainCard(cardHeight: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 12)

                ZStack {
                    if let mainImage {
                        Image(uiImage: mainImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.12))
                            .overlay { ProgressView() }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if isBestResult {
                        bestPill
                            .padding(.top, 16)
                            .padding(.leading, 16)
                    }
                }
                .overlay(alignment: .bottom) {
                    metaOverlay
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
                .offset(x: dragOffset.width, y: 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { v in
                            dragOffset = CGSize(width: v.translation.width, height: 0)
                        }
                        .onEnded { v in
                            handleSwipeEnd(translation: v.translation.width)
                        }
                )
            }
            .frame(height: cardHeight)
        }
    }

    private var bestPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
            Text("BEST RESULT")
                .font(.system(size: 18, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(accent)
        .clipShape(Capsule())
    }

    private var metaOverlay: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "photo")
                Text("\(currentAsset.pixelWidth) × \(currentAsset.pixelHeight)")
                    .font(.system(size: 18, weight: .semibold))
            }
            Spacer()
            Text(currentFileSizeBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "")
                .font(.system(size: 18, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.black.opacity(0.60))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var recommendationBlock: some View {
        VStack(spacing: 8) {
            Text("RECOMMENDED TO KEEP")
                .font(.system(size: 20, weight: .heavy))
                .tracking(3)
                .foregroundStyle(accent)
            Text("Identified on-device as the best photo in this set.")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(.top, 8)
    }

    private var swipeHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.draw")
                .foregroundStyle(Color(.secondaryLabel))
            Text("Swipe left to delete, right to keep")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
            Image(systemName: "hand.draw")
                .foregroundStyle(Color(.secondaryLabel))
                .scaleEffect(x: -1, y: 1)
        }
    }

    private func actionButtons(scale: CGFloat) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 22 * scale) {
                CircleButton(icon: "arrow.uturn.left", tint: Color(.systemGray), size: 58 * scale) {
                    state.undoLast()
                }

                CircleButton(icon: "xmark", tint: Color.red.opacity(0.75), fill: Color.red.opacity(0.12), size: 74 * scale) {
                    mark(.delete)
                }

                CircleButton(icon: "checkmark", tint: accent, fill: accent.opacity(0.12), size: 74 * scale) {
                    mark(.keep)
                }

                CircleButton(icon: "star.fill", tint: Color(.systemGray), size: 58 * scale) {
                    state.toggleStar(for: currentAsset.id)
                }
            }
            .padding(.top, 4)

            // Fallback for very small screens: split into 2 rows
            VStack(spacing: 14) {
                HStack(spacing: 22 * scale) {
                    CircleButton(icon: "arrow.uturn.left", tint: Color(.systemGray), size: 58 * scale) { state.undoLast() }
                    CircleButton(icon: "star.fill", tint: Color(.systemGray), size: 58 * scale) { state.toggleStar(for: currentAsset.id) }
                }
                HStack(spacing: 22 * scale) {
                    CircleButton(icon: "xmark", tint: Color.red.opacity(0.75), fill: Color.red.opacity(0.12), size: 74 * scale) { mark(.delete) }
                    CircleButton(icon: "checkmark", tint: accent, fill: accent.opacity(0.12), size: 74 * scale) { mark(.keep) }
                }
            }
            .padding(.top, 4)
        }
    }

    private var bottomSaveBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Image(systemName: "opticaldisc")
                    .foregroundStyle(accent)
                Text("Cleaning this set will save")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
                Text(state.savedSizeText)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(state.markedForDeletionIDs.isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .overlay(Rectangle().fill(Color(.systemGray5)).frame(height: 1), alignment: .top)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "opticaldisc")
                        .foregroundStyle(accent)
                    Text("Cleaning this set will save \(state.savedSizeText)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                }
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .disabled(state.markedForDeletionIDs.isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .overlay(Rectangle().fill(Color(.systemGray5)).frame(height: 1), alignment: .top)
        }
    }

    private var currentAsset: SimilarAsset {
        similarSet.assets[min(state.index, similarSet.assets.count - 1)]
    }

    private var isBestResult: Bool {
        currentAsset.id == similarSet.bestAssetID
    }

    private func loadMainImage() async {
        mainImage = nil
        currentFileSizeBytes = nil
        let size = CGSize(width: 1200, height: 1200)
        mainImage = await imageProvider(currentAsset.id, size)
        currentFileSizeBytes = await fileSizeProvider(currentAsset.id)
    }

    private func handleSwipeEnd(translation: CGFloat) {
        let threshold: CGFloat = 90
        if translation <= -threshold {
            mark(.delete)
        } else if translation >= threshold {
            mark(.keep)
        }
        dragOffset = .zero
    }

    private func mark(_ decision: SimilarDecision) {
        state.apply(decision: decision, for: currentAsset.id, fileSizeBytes: currentFileSizeBytes ?? 0)
        state.advance(max: similarSet.assets.count)
    }

    private var progressSegmentCount: Int {
        min(5, max(similarSet.assets.count, 1))
    }

    private var activeSegmentIndex: Int {
        let n = max(similarSet.assets.count - 1, 1)
        let segments = max(progressSegmentCount - 1, 1)
        let t = Double(min(max(state.index, 0), n)) / Double(n)
        return Int((t * Double(segments)).rounded(.down))
    }

    private func cardHeight(for size: CGSize) -> CGFloat {
        // Aim to fit small devices: cap height and keep enough room for controls.
        let maxH: CGFloat = 520
        let minH: CGFloat = 360
        let proposed = size.height * 0.56
        return min(maxH, max(minH, proposed))
    }

    private func buttonScale(for size: CGSize) -> CGFloat {
        // 390 is iPhone 14 width baseline.
        let s = size.width / 390.0
        return min(1.0, max(0.82, s))
    }
}

private struct CircleButton: View {
    let icon: String
    let tint: Color
    var fill: Color = Color(.systemGray6)
    var size: CGFloat = 58
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(fill)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(tint)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }
}

private struct SimilarInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How it works") {
                    Text("This feature groups burst-like photos (same burst identifier or taken close in time), then lets you keep the best one and delete the rest.")
                    Text("All analysis is done on-device. No photos are uploaded.")
                }
            }
            .navigationTitle("About Similar Photos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct SimilarTopBar: View {
    let title: String
    let onBack: () -> Void
    let onInfo: () -> Void

    var body: some View {
        ZStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                }
                Spacer()
                Button(action: onInfo) {
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .overlay { Circle().stroke(Color(.systemGray4), lineWidth: 1) }
                        Text("i")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .frame(width: 36, height: 36)
                }
            }
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding(.bottom, 6)
    }
}

// MARK: - ViewModel / Scanning

@MainActor
private final class SimilarPhotosViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    @Published var isScanning: Bool = false
    @Published var totalCount: Int = 0
    @Published var scannedCount: Int = 0

    @Published var sets: [SimilarSet] = []
    @Published var currentSetIndex: Int? = nil

    @Published var currentReviewState: SimilarReviewState = .init()

    @Published var errorMessage: String?
    @Published var showInfoSheet: Bool = false
    @Published var showDeleteConfirm: Bool = false

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

    var scanProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(scannedCount) / Double(totalCount)
    }

    var currentSet: SimilarSet? {
        guard let idx = currentSetIndex, sets.indices.contains(idx) else { return nil }
        return sets[idx]
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = newStatus
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
    }

    func leaveSet() {
        currentSetIndex = nil
        currentReviewState = .init()
        showDeleteConfirm = false
    }

    func scan() async {
        errorMessage = nil
        refreshAuthorizationStatus()
        guard isAuthorizedForReading else {
            errorMessage = "No photo permission."
            return
        }

        cancelScan()
        isScanning = true
        scannedCount = 0
        totalCount = 0
        sets = []
        currentSetIndex = nil
        currentReviewState = .init()

        scanTask = Task { await runScan() }
        await scanTask?.value
    }

    private func runScan() async {
        defer {
            isScanning = false
            scanTask = nil
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetch = PHAsset.fetchAssets(with: .image, options: options)

        totalCount = fetch.count
        guard totalCount > 0 else { return }

        // Pass 1: compute aHash for every image (on-device) and bucket by a short prefix.
        // Then cluster within bucket by Hamming distance to catch burst-like similar photos
        // and also exact duplicates/copies even if taken far apart in time.
        struct Info {
            let asset: PHAsset
            let id: String
            let date: Date
            let w: Int
            let h: Int
            let hash: UInt64
        }

        // Prefix-bucketing reduces O(n^2) comparisons while keeping high recall.
        // Using top 12 bits is a decent trade-off for mobile.
        typealias Prefix = UInt16
        func prefix(of hash: UInt64) -> Prefix { Prefix((hash >> 52) & 0x0FFF) }

        var byPrefix: [Prefix: [Info]] = [:]
        byPrefix.reserveCapacity(min(fetch.count, 4096))

        for i in 0..<fetch.count {
            if Task.isCancelled { return }
            let asset = fetch.object(at: i)
            guard let date = asset.creationDate else {
                scannedCount = i + 1
                continue
            }
            if let thumb = await requestHashThumbnail(asset: asset),
               let h = averageHash(of: thumb)
            {
                let info = Info(asset: asset, id: asset.localIdentifier, date: date, w: asset.pixelWidth, h: asset.pixelHeight, hash: h)
                byPrefix[prefix(of: h), default: []].append(info)
            }
            scannedCount = i + 1
        }

        var nextSets: [SimilarSet] = []
        nextSets.reserveCapacity(256)

        // Cluster within each prefix-bucket by Hamming distance.
        // Threshold tuned for "very similar / burst-like" photos.
        let threshold = 8
        for (_, infosRaw) in byPrefix where infosRaw.count >= 2 {
            if Task.isCancelled { return }
            let infos = infosRaw.sorted { $0.date < $1.date }

            var clusters: [[Info]] = []
            clusters.reserveCapacity(8)

            for info in infos {
                var placed = false
                for i in clusters.indices {
                    if let rep = clusters[i].first, hammingDistance(rep.hash, info.hash) <= threshold {
                        clusters[i].append(info)
                        placed = true
                        break
                    }
                }
                if !placed { clusters.append([info]) }
            }

            for c in clusters where c.count >= 2 {
                let sorted = c.sorted { $0.date > $1.date } // newest first for review UX
                let start = sorted.last?.date ?? Date.distantPast
                let subtitle = "Burst - \(formatSetSubtitleSmart(date: start))"

                // Best: prefer largest resolution, then newest
                let best = sorted.max { a, b in
                    let ap = a.w * a.h
                    let bp = b.w * b.h
                    if ap != bp { return ap < bp }
                    return a.date < b.date
                }
                guard let best else { continue }

                let assetsOut: [SimilarAsset] = sorted.map {
                    SimilarAsset(
                        id: $0.id,
                        creationDate: $0.date,
                        pixelWidth: $0.w,
                        pixelHeight: $0.h,
                        fileSizeBytes: nil
                    )
                }

                nextSets.append(
                    SimilarSet(
                        id: UUID(),
                        subtitle: subtitle,
                        startDate: start,
                        assets: assetsOut,
                        bestAssetID: best.id
                    )
                )
            }
        }

        nextSets.sort { $0.startDate > $1.startDate }
        sets = nextSets

        if !sets.isEmpty {
            currentSetIndex = 0
            currentReviewState = SimilarReviewState.forInitial(bestID: sets[0].bestAssetID, assets: sets[0].assets)
        }
    }

    private func bucketByTimeWindow(_ assets: [PHAsset], maxGapSeconds: TimeInterval) -> [[PHAsset]] {
        var out: [[PHAsset]] = []
        var current: [PHAsset] = []

        func flush() {
            if current.count >= 2 { out.append(current) }
            current.removeAll(keepingCapacity: true)
        }

        var prevDate: Date?
        for a in assets {
            guard let d = a.creationDate else { continue }
            if let p = prevDate, d.timeIntervalSince(p) > maxGapSeconds {
                flush()
            }
            current.append(a)
            prevDate = d
        }
        flush()
        return out
    }

    // Previously we built sets only inside burst/time windows; now we bucket globally by hash first.

    func deleteMarkedInCurrentSet() async {
        guard let set = currentSet else { return }
        let ids = Array(currentReviewState.markedForDeletionIDs)
        guard !ids.isEmpty else { return }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        do {
            try await performPhotoChanges {
                PHAssetChangeRequest.deleteAssets(fetch)
            }
            // After delete, move to next set (or exit)
            if let idx = currentSetIndex {
                let nextIdx = idx + 1
                if sets.indices.contains(nextIdx) {
                    currentSetIndex = nextIdx
                    currentReviewState = SimilarReviewState.forInitial(bestID: sets[nextIdx].bestAssetID, assets: sets[nextIdx].assets)
                } else {
                    currentSetIndex = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Image helpers

    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetch.firstObject else { return nil }
        return await requestThumbnail(asset: asset, targetSize: targetSize)
    }

    func previewImage(for id: String, targetSize: CGSize) async -> UIImage? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetch.firstObject else { return nil }
        return await requestThumbnail(asset: asset, targetSize: targetSize) // MVP: reuse requestImage
    }

    private func requestThumbnail(asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var didResume = false
            let opts = PHImageRequestOptions()
            opts.isSynchronous = false
            opts.deliveryMode = .opportunistic
            opts.resizeMode = .fast
            opts.isNetworkAccessAllowed = true

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: opts
            ) { image, info in
                guard !didResume else { return }

                // Ignore early nil/degraded callbacks; wait for a usable image or a terminal error.
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

    private func requestHashThumbnail(asset: PHAsset) async -> UIImage? {
        // For hashing we want a stable representation: avoid cropping (aspectFit) and request exact size.
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

    func fileSizeBytes(for id: String) async -> Int64? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetch.firstObject else { return nil }
        return await fileSizeBytes(asset: asset)
    }

    private func fileSizeBytes(asset: PHAsset) async -> Int64? {
        // PHAsset does not expose file size via public API.
        // To display "MB" like the design and compute "saved space", we stream the asset resource
        // using PHAssetResourceManager and count bytes (on-device; may take time for large photos).
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else { return nil }

        // Prefer the main photo resource if possible
        let preferred = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto || $0.type == .alternatePhoto }) ?? resources[0]

        let opts = PHAssetResourceRequestOptions()
        opts.isNetworkAccessAllowed = true

        return await withCheckedContinuation { continuation in
            var didResume = false
            var total: Int64 = 0

            PHAssetResourceManager.default().requestData(
                for: preferred,
                options: opts,
                dataReceivedHandler: { data in
                    total += Int64(data.count)
                },
                completionHandler: { error in
                    guard !didResume else { return }
                    didResume = true
                    if error != nil {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: total > 0 ? total : nil)
                    }
                }
            )
        }
    }

    private func performPhotoChanges(_ changes: @escaping () -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges(changes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: NSError(domain: "photoCleaner", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "The system did not complete the deletion."
                    ]))
                }
            }
        }
    }
}

// MARK: - Data & Review State

private struct SimilarSet: Identifiable {
    let id: UUID
    let subtitle: String
    let startDate: Date
    let assets: [SimilarAsset]
    let bestAssetID: String
}

private struct SimilarAsset: Identifiable {
    let id: String // PHAsset.localIdentifier
    let creationDate: Date
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSizeBytes: Int64?

    var fileSizeText: String? {
        guard let b = fileSizeBytes, b > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }
}

private enum SimilarDecision {
    case keep
    case delete
}

private struct SimilarReviewState {
    var index: Int = 0
    var decisions: [String: SimilarDecision] = [:]
    var starred: Set<String> = []

    // Size tracking for "saved"
    var deleteBytesByID: [String: Int64] = [:]
    var history: [(id: String, previous: SimilarDecision?, previousBytes: Int64?, new: SimilarDecision, newBytes: Int64)] = []

    static func forInitial(bestID: String, assets: [SimilarAsset]) -> SimilarReviewState {
        var s = SimilarReviewState()
        // Default: keep best, delete others (user can override)
        for a in assets {
            if a.id == bestID {
                s.decisions[a.id] = .keep
            } else {
                s.decisions[a.id] = .delete
                if let bytes = a.fileSizeBytes { s.deleteBytesByID[a.id] = bytes }
            }
        }
        s.index = 0
        s.history.removeAll()
        return s
    }

    var markedForDeletionIDs: Set<String> {
        Set(decisions.compactMap { $0.value == .delete ? $0.key : nil })
    }

    var savedBytes: Int64 {
        deleteBytesByID.values.reduce(0, +)
    }

    var savedSizeText: String {
        ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)
    }

    mutating func apply(decision: SimilarDecision, for id: String, fileSizeBytes: Int64) {
        let prev = decisions[id]
        let prevBytes = deleteBytesByID[id]

        decisions[id] = decision
        history.append((id: id, previous: prev, previousBytes: prevBytes, new: decision, newBytes: fileSizeBytes))
        if decision == .delete {
            deleteBytesByID[id] = fileSizeBytes
        } else {
            deleteBytesByID[id] = nil
        }
    }

    mutating func advance(max: Int) {
        index = min(index + 1, max - 1)
    }

    mutating func undoLast() {
        guard let last = history.popLast() else { return }
        if let prev = last.previous {
            decisions[last.id] = prev
        } else {
            decisions[last.id] = nil
        }
        if let prevBytes = last.previousBytes {
            deleteBytesByID[last.id] = prevBytes
        } else {
            deleteBytesByID[last.id] = nil
        }
    }

    mutating func toggleStar(for id: String) {
        if starred.contains(id) { starred.remove(id) } else { starred.insert(id) }
    }
}

// MARK: - Hash helpers

private func averageHash(of image: UIImage) -> UInt64? {
    // Normalize orientation first to improve stability across camera shots.
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

private func formatSetSubtitle(date: Date) -> String {
    let df = DateFormatter()
    df.dateFormat = "MMM d, h:mm a"
    return df.string(from: date)
}

private func formatSetSubtitleSmart(date: Date) -> String {
    let cal = Calendar.current
    let tf = DateFormatter()
    tf.dateFormat = "h:mm a"

    if cal.isDateInToday(date) {
        return "Today, \(tf.string(from: date))"
    }
    if cal.isDateInYesterday(date) {
        return "Yesterday, \(tf.string(from: date))"
    }
    let df = DateFormatter()
    df.dateFormat = "MMM d, h:mm a"
    return df.string(from: date)
}

private func normalizeOrientation(_ image: UIImage) -> UIImage {
    if image.imageOrientation == .up { return image }
    let renderer = UIGraphicsImageRenderer(size: image.size)
    return renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: image.size))
    }
}

#Preview {
    NavigationStack {
        SimilarPhotosView()
    }
}


