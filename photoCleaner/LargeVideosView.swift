import Photos
import SwiftUI
import UIKit

struct LargeVideosView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = LargeVideosViewModel()

    private let accent = Color(red: 0.00, green: 0.67, blue: 0.95)

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        summaryCard
                            .padding(.horizontal, 18)
                            .padding(.top, 18)

                        sectionHeader
                            .padding(.horizontal, 18)
                            .padding(.top, 6)

                        VStack(spacing: 0) {
                            ForEach(vm.items) { item in
                                LargeVideoRow(
                                    item: item,
                                    isSelected: vm.selection.contains(item.id),
                                    thumbnail: vm.thumbnails[item.id],
                                    accent: accent
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { vm.toggleSelection(item.id) }
                                .task { await vm.ensureThumbnail(for: item.id) }

                                Divider().opacity(0.6)
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        }
                        .padding(.horizontal, 18)

                        optimizationTip
                            .padding(.horizontal, 18)
                            .padding(.top, 12)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await vm.ensureAuthorizedAndScan()
        }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .confirmationDialog("Delete selected videos?", isPresented: $vm.showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Selected (\(vm.selection.count))", role: .destructive) {
                Task { await vm.deleteSelected() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the selected videos from your library.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
            }

            Text("Large Videos")
                .font(.system(size: 26, weight: .bold))

            Spacer()

            Button {
                vm.showDeleteConfirm = true
            } label: {
                Text("Delete Selected")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.90, green: 0.97, blue: 1.00))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(vm.selection.isEmpty)
            .opacity(vm.selection.isEmpty ? 0.45 : 1.0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet")
                    .foregroundStyle(Color(.secondaryLabel))
                Text("Total Selected")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
            }

            Text(vm.totalSelectedSizeText)
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("\(vm.selection.count) files identified for cleanup")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 12)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("LARGEST MEDIA")
                .font(.system(size: 18, weight: .heavy))
                .tracking(2)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
        }
    }

    private var optimizationTip: some View {
        Button {
            // Design shows chevron; keep as non-functional tip for now.
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.15))
                    Image(systemName: "trash")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("OPTIMIZATION TIP")
                        .font(.system(size: 16, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(accent)
                    Text("Free up \(vm.totalSelectedSizeText) instantly")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
            }
            .padding(16)
            .background(Color(red: 0.93, green: 0.98, blue: 1.00))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Row

private struct LargeVideoRow: View {
    let item: LargeVideoItem
    let isSelected: Bool
    let thumbnail: UIImage?
    let accent: Color

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.12))
                            .overlay { ProgressView() }
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(item.durationText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.60))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.sizeText)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                Text(item.dateText)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)

                Text(item.filename)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .italic()
                    .lineLimit(1)
            }

            Spacer()

            ZStack {
                Circle()
                    .strokeBorder(Color(.systemGray4), lineWidth: 3)
                    .background(Circle().fill(isSelected ? accent : Color.clear))
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 42, height: 42)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
    }
}

// MARK: - ViewModel

private struct LargeVideoItem: Identifiable {
    let id: String // PHAsset.localIdentifier
    let creationDate: Date
    let duration: TimeInterval
    let filename: String
    let sizeBytes: Int64?

    var sizeText: String {
        guard let b = sizeBytes, b > 0 else { return "—" }
        // Match design: show GB/MB (rounded) without decimals when possible
        if b >= 1024 * 1024 * 1024 {
            let gb = Double(b) / Double(1024 * 1024 * 1024)
            return gb >= 10 ? "\(Int(gb.rounded())) GB" : String(format: "%.1f GB", gb)
        } else {
            let mb = Double(b) / Double(1024 * 1024)
            return mb >= 100 ? "\(Int(mb.rounded())) MB" : String(format: "%.0f MB", mb)
        }
    }

    var dateText: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        return df.string(from: creationDate)
    }

    var durationText: String {
        let total = Int(duration.rounded(.down))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}

@MainActor
private final class LargeVideosViewModel: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var items: [LargeVideoItem] = []
    @Published var selection: Set<String> = []
    @Published var thumbnails: [String: UIImage] = [:]
    @Published var errorMessage: String?
    @Published var showDeleteConfirm: Bool = false

    private let imageManager = PHCachingImageManager()

    var isAuthorizedForReading: Bool {
        switch authorizationStatus {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }

    var totalSelectedSizeBytes: Int64 {
        let map = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.sizeBytes ?? 0) })
        return selection.reduce(0) { $0 + (map[$1] ?? 0) }
    }

    var totalSelectedSizeText: String {
        let b = totalSelectedSizeBytes
        if b <= 0 { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }

    func toggleSelection(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    func ensureAuthorizedAndScan() async {
        refreshAuthorizationStatus()
        if authorizationStatus == .notDetermined {
            await requestAuthorization()
        }
        if isAuthorizedForReading {
            await scan()
        } else {
            errorMessage = "Photo access is required to list videos."
        }
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
    }

    func scan() async {
        errorMessage = nil
        guard isAuthorizedForReading else { return }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetch = PHAsset.fetchAssets(with: .video, options: options)

        var next: [LargeVideoItem] = []
        next.reserveCapacity(fetch.count)

        for i in 0..<fetch.count {
            let asset = fetch.object(at: i)
            guard let date = asset.creationDate else { continue }
            let filename = bestFilename(asset: asset)
            let size = estimatedFileSizeBytes(asset: asset)
            next.append(
                LargeVideoItem(
                    id: asset.localIdentifier,
                    creationDate: date,
                    duration: asset.duration,
                    filename: filename,
                    sizeBytes: size
                )
            )
        }

        // Sort by size desc, unknown sizes last
        next.sort {
            let a = $0.sizeBytes ?? -1
            let b = $1.sizeBytes ?? -1
            return a > b
        }

        items = next

        // Auto-select the top few (like design shows checked)
        selection = Set(items.prefix(3).map(\.id))
    }

    func ensureThumbnail(for id: String) async {
        if thumbnails[id] != nil { return }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetch.firstObject else { return }

        let img = await requestThumbnail(asset: asset, targetSize: CGSize(width: 180, height: 180))
        if let img { thumbnails[id] = img }
    }

    func deleteSelected() async {
        errorMessage = nil
        guard isAuthorizedForReading else { return }
        let ids = Array(selection)
        guard !ids.isEmpty else { return }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        do {
            try await performPhotoChanges {
                PHAssetChangeRequest.deleteAssets(fetch)
            }
            await scan()
        } catch {
            errorMessage = error.localizedDescription
        }
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

    private func bestFilename(asset: PHAsset) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
        if let r = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) {
            return r.originalFilename
        }
        return resources.first?.originalFilename ?? "video.mov"
    }

    private func estimatedFileSizeBytes(asset: PHAsset) -> Int64? {
        // No public fileSize; use KVC best-effort. If it fails, UI will show "—".
        let resources = PHAssetResource.assetResources(for: asset)
        let preferred = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) ?? resources.first
        guard let preferred else { return nil }
        if let n = preferred.value(forKey: "fileSize") as? NSNumber {
            return n.int64Value
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        LargeVideosView()
    }
}




