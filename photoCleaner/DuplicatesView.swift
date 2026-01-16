import Photos
import SwiftUI
import UIKit

// MARK: - View

struct DuplicatesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = DuplicatesViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 12) {
                header

                if vm.isAuthorizedForReading {
                    mainContent
                } else {
                    permissionContent
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            vm.refreshAuthorizationStatus()
        }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .confirmationDialog("Delete selected items?", isPresented: $vm.showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete (\(vm.selection.count))", role: .destructive) {
                Task { await vm.deleteSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected photos from your library.")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
            }

            Text("Duplicates")
                .font(.system(size: 22, weight: .bold))

            Spacer()

            if vm.isScanning {
                Button("Stop") { vm.cancelScan() }
                    .buttonStyle(.bordered)
            } else {
                Button("Scan") { Task { await vm.scan() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.isAuthorizedForReading)
            }
        }
        .padding(.vertical, 6)
    }

    private var permissionContent: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 20)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("Photo access required")
                .font(.title2.bold())

            Text("We need access to scan your library for duplicate photos. Scanning is performed on-device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button("Request Access") {
                    Task { await vm.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)

                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.top, 30)
    }

    private var mainContent: some View {
        VStack(spacing: 12) {
            if vm.isScanning {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: vm.scanProgress)
                    Text("Scanning… \(vm.scannedCount)/\(vm.totalCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 2)
            } else {
                HStack {
                    Text("\(vm.groups.count) duplicate sets")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Select duplicates") { vm.selectAllButOnePerGroup() }
                        .disabled(vm.groups.isEmpty)
                    Button("Clear") { vm.selection.removeAll() }
                        .disabled(vm.selection.isEmpty)
                }
                .font(.subheadline)
            }

            if vm.groups.isEmpty {
                Spacer().frame(height: 24)
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text(vm.isScanning ? "Scanning your library…" : "No duplicates found yet")
                        .font(.headline)
                    Text("Tap Scan to find duplicate photos. You can then review and delete them.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 20)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(vm.groups) { group in
                            DuplicateGroupCard(
                                group: group,
                                selection: $vm.selection,
                                thumbnailProvider: vm.thumbnail(for:targetSize:)
                            )
                        }
                    }
                    .padding(.bottom, 110)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected \(vm.selection.count)")
                        .font(.headline)
                    Text("Tip: “Select duplicates” keeps 1 photo per set and selects the rest.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    vm.showDeleteConfirm = true
                } label: {
                    Text("Delete")
                        .frame(minWidth: 84)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.selection.isEmpty || vm.isScanning)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Group Card

private struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    @Binding var selection: Set<String> // localIdentifiers
    let thumbnailProvider: (String, CGSize) async -> UIImage?

    private let thumbSize = CGSize(width: 84, height: 84)

    @State private var thumbs: [String: UIImage] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Set • \(group.assetIDs.count) photos")
                    .font(.subheadline.bold())
                Spacer()
                Button(selectionForThisSetIsAll ? "Unselect set" : "Select set") {
                    toggleSetSelection()
                }
                .font(.subheadline)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(group.assetIDs, id: \.self) { id in
                        let isSelected = selection.contains(id)
                        ZStack(alignment: .topTrailing) {
                            Group {
                                if let image = thumbs[id] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.secondary.opacity(0.15))
                                        .overlay { ProgressView() }
                                }
                            }
                            .frame(width: thumbSize.width, height: thumbSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(isSelected ? Color.accentColor : Color.white.opacity(0.9))
                                .padding(6)
                                .shadow(radius: 2)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelected { selection.remove(id) } else { selection.insert(id) }
                        }
                        .task {
                            if thumbs[id] == nil {
                                if let img = await thumbnailProvider(id, thumbSize) {
                                    thumbs[id] = img
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                }
        )
    }

    private var selectionForThisSetIsAll: Bool {
        !group.assetIDs.isEmpty && group.assetIDs.allSatisfy { selection.contains($0) }
    }

    private func toggleSetSelection() {
        if selectionForThisSetIsAll {
            for id in group.assetIDs { selection.remove(id) }
        } else {
            for id in group.assetIDs { selection.insert(id) }
        }
    }
}

// MARK: - ViewModel

@MainActor
private final class DuplicatesViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var isScanning: Bool = false

    @Published var totalCount: Int = 0
    @Published var scannedCount: Int = 0

    @Published var groups: [DuplicateGroup] = []
    @Published var selection: Set<String> = []

    @Published var errorMessage: String?
    @Published var showDeleteConfirm: Bool = false

    private let imageManager = PHCachingImageManager()
    private var scanTask: Task<Void, Never>?

    var scanProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(scannedCount) / Double(totalCount)
    }

    var isAuthorizedForReading: Bool {
        switch authorizationStatus {
        case .authorized, .limited:
            return true
        default:
            return false
        }
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
        groups = []
        selection.removeAll()

        scanTask = Task {
            await self.runScan()
        }
        await scanTask?.value
    }

    private func runScan() async {
        defer {
            isScanning = false
            scanTask = nil
        }

        // Photos only (duplicates target)
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        totalCount = assets.count
        guard totalCount > 0 else { return }

        // Hash -> asset ids
        var buckets: [UInt64: [String]] = [:]
        buckets.reserveCapacity(min(totalCount, 2048))

        for idx in 0..<assets.count {
            if Task.isCancelled { return }
            let asset = assets.object(at: idx)

            // Small thumbnail is enough for perceptual hash
            let thumb = await requestThumbnail(asset: asset, targetSize: CGSize(width: 64, height: 64))
            if let thumb, let h = averageHash(of: thumb) {
                buckets[h, default: []].append(asset.localIdentifier)
            }

            scannedCount = idx + 1
        }

        var nextGroups: [DuplicateGroup] = buckets
            .filter { $0.value.count > 1 }
            .map { DuplicateGroup(hash: $0.key, assetIDs: $0.value) }
            .sorted { $0.assetIDs.count > $1.assetIDs.count }

        // Keep stable ids
        for i in nextGroups.indices {
            nextGroups[i].id = UUID()
        }

        groups = nextGroups
    }

    func selectAllButOnePerGroup() {
        var next: Set<String> = []
        for g in groups {
            // Keep the first item (newest first due to sort), select the rest
            guard g.assetIDs.count >= 2 else { continue }
            for id in g.assetIDs.dropFirst() {
                next.insert(id)
            }
        }
        selection = next
    }

    func deleteSelected() async {
        errorMessage = nil
        refreshAuthorizationStatus()
        guard isAuthorizedForReading else {
            errorMessage = "No photo permission."
            return
        }
        let ids = Array(selection)
        guard !ids.isEmpty else { return }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        do {
            try await performPhotoChanges {
                PHAssetChangeRequest.deleteAssets(fetch)
            }
            // Refresh by scanning again (fast enough for MVP)
            await scan()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage? {
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetch.firstObject else { return nil }
        return await requestThumbnail(asset: asset, targetSize: targetSize)
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
            ) { image, _ in
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
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

// MARK: - Data Model

private struct DuplicateGroup: Identifiable {
    var id: UUID = UUID()
    let hash: UInt64
    let assetIDs: [String]
}

// MARK: - Perceptual Hash (Average Hash)

private func averageHash(of image: UIImage) -> UInt64? {
    guard let cgImage = image.cgImage else { return nil }

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
    ) else {
        return nil
    }

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

#Preview {
    NavigationStack {
        DuplicatesView()
    }
}





