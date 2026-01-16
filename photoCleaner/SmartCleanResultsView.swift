import Photos
import SwiftUI
import UIKit

struct SmartCleanResultsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: SmartCleanResultsViewModel

    private let accent = Color(red: 0.00, green: 0.67, blue: 0.95)
    private let green = Color(red: 0.11, green: 0.73, blue: 0.65)

    init(summary: SmartCleanScanSummary) {
        _vm = StateObject(wrappedValue: SmartCleanResultsViewModel(summary: summary))
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        topSummary
                            .padding(.top, 22)
                            .padding(.horizontal, 18)

                        breakdown
                            .padding(.horizontal, 18)
                            .padding(.top, 10)

                        safetyNote
                            .padding(.horizontal, 26)
                            .padding(.top, 6)

                        Spacer().frame(height: 110)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            cleanNowButton
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
        }
        .alert("Error", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in vm.errorMessage = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .confirmationDialog("Clean now?", isPresented: $vm.showCleanConfirm, titleVisibility: .visible) {
            Button("Clean Now", role: .destructive) {
                Task { await vm.cleanNow() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Selected items will be permanently removed from your Photo Library.")
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                }
                Spacer()
            }
            Text("Scan Results")
                .font(.system(size: 22, weight: .semibold))
        }
    }

    private var topSummary: some View {
        VStack(spacing: 12) {
            Text("ANALYSIS COMPLETE")
                .font(.system(size: 16, weight: .heavy))
                .tracking(3)
                .foregroundStyle(green)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(green.opacity(0.15))
                .clipShape(Capsule())

            Text(vm.totalCleanableText)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(green)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("Ready to Clean")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.primary)

            Text("We've safely identified items that are safe to remove without affecting your library.")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.top, 4)
        }
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SMART BREAKDOWN")
                .font(.system(size: 18, weight: .heavy))
                .tracking(3)
                .foregroundStyle(Color(.secondaryLabel))
                .padding(.bottom, 6)

            SmartBreakdownRow.review(
                iconBg: LinearGradient(colors: [Color(red: 0.12, green: 0.78, blue: 0.90), Color(red: 0.98, green: 0.73, blue: 0.44)], startPoint: .topLeading, endPoint: .bottomTrailing),
                title: "Similar Photos",
                subtitle: "\(vm.similarCountText) • \(vm.similarBytesText)",
                actionTitle: "Review",
                action: {
                    vm.openSimilar = true
                }
            )
            .sheet(isPresented: $vm.openSimilar) {
                NavigationStack {
                    SimilarPhotosView()
                        .toolbar(.hidden, for: .navigationBar)
                }
            }

            SmartBreakdownRow.toggle(
                iconBg: LinearGradient(colors: [Color(.systemGray4), Color(.systemGray6)], startPoint: .topLeading, endPoint: .bottomTrailing),
                title: "Duplicates",
                subtitle: "\(vm.summary.duplicatesCount) items • \(vm.summary.duplicatesBytesText)",
                isOn: $vm.includeDuplicates
            )

            SmartBreakdownRow.toggle(
                iconBg: LinearGradient(colors: [Color(red: 0.98, green: 0.78, blue: 0.60), Color(red: 0.98, green: 0.90, blue: 0.78)], startPoint: .topLeading, endPoint: .bottomTrailing),
                title: "Screenshots",
                subtitle: "\(vm.summary.screenshotsCount) items • \(vm.summary.screenshotsBytesText)",
                isOn: $vm.includeScreenshots
            )

            SmartBreakdownRow.toggle(
                iconBg: LinearGradient(colors: [Color(red: 0.85, green: 0.96, blue: 1.0), Color(red: 0.92, green: 0.98, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                title: "Large Videos",
                subtitle: "\(vm.summary.largeVideosCount) items • \(vm.summary.largeVideosBytesText)",
                isOn: $vm.includeLargeVideos
            )
        }
    }

    private var safetyNote: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color(.systemGray2))
            Text("Smart Clean only targets redundant data.\nYour original high-quality photos remain safe.")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var cleanNowButton: some View {
        Button {
            vm.showCleanConfirm = true
        } label: {
            ViewThatFits(in: .horizontal) {
                Text("Clean Now (\(vm.totalCleanableText))")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(green)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text("Clean Now")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(green)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .disabled(vm.totalCleanableBytes == 0 || vm.isCleaning)
        .opacity(vm.totalCleanableBytes == 0 ? 0.45 : 1.0)
    }
}

private enum SmartBreakdownRow {
    static func review(
        iconBg: LinearGradient,
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        SmartBreakdownRowView(
            iconBg: iconBg,
            title: title,
            subtitle: subtitle,
            trailing: .review(title: actionTitle, action: action)
        )
    }

    static func toggle(
        iconBg: LinearGradient,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        SmartBreakdownRowView(
            iconBg: iconBg,
            title: title,
            subtitle: subtitle,
            trailing: .toggle(isOn: isOn)
        )
    }
}

private struct SmartBreakdownRowView: View {
    enum Trailing {
        case review(title: String, action: () -> Void)
        case toggle(isOn: Binding<Bool>)
    }

    let iconBg: LinearGradient
    let title: String
    let subtitle: String
    let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(iconBg)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            switch trailing {
            case let .review(title, action):
                Button(action: action) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            case let .toggle(isOn):
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Color(red: 0.11, green: 0.73, blue: 0.65))
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(.systemGray5), lineWidth: 1)
        }
    }
}

@MainActor
private final class SmartCleanResultsViewModel: ObservableObject {
    let summary: SmartCleanScanSummary

    @Published var includeDuplicates: Bool = true
    @Published var includeScreenshots: Bool = true
    @Published var includeLargeVideos: Bool = true

    @Published var isCleaning: Bool = false
    @Published var showCleanConfirm: Bool = false
    @Published var errorMessage: String?
    @Published var openSimilar: Bool = false

    init(summary: SmartCleanScanSummary) {
        self.summary = summary
    }

    var similarCountText: String { "\(summary.similarCount) items" }
    var similarBytesText: String { summary.similarBytesText }

    var totalCleanableBytes: Int64 {
        var total: Int64 = 0
        if includeDuplicates { total += summary.duplicatesBytes }
        if includeScreenshots { total += summary.screenshotsBytes }
        if includeLargeVideos { total += summary.largeVideosBytes }
        return total
    }

    var totalCleanableText: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)
    }

    func cleanNow() async {
        guard !isCleaning else { return }
        isCleaning = true
        defer { isCleaning = false }

        var idsToDelete: [String] = []
        if includeDuplicates { idsToDelete.append(contentsOf: summary.duplicateDeleteIDs) }
        if includeScreenshots { idsToDelete.append(contentsOf: summary.screenshotIDs) }
        if includeLargeVideos { idsToDelete.append(contentsOf: summary.largeVideoIDs) }

        // De-dupe identifiers
        let unique = Array(Set(idsToDelete))
        guard !unique.isEmpty else { return }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: unique, options: nil)
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(fetch)
                }, completionHandler: { success, error in
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
                })
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct SmartCleanScanSummary {
    let similarCount: Int
    let similarBytes: Int64
    let duplicatesCount: Int
    let duplicatesBytes: Int64
    let screenshotsCount: Int
    let screenshotsBytes: Int64
    let largeVideosCount: Int
    let largeVideosBytes: Int64

    let duplicateDeleteIDs: [String]
    let screenshotIDs: [String]
    let largeVideoIDs: [String]

    var similarBytesText: String { ByteCountFormatter.string(fromByteCount: similarBytes, countStyle: .file) }
    var duplicatesBytesText: String { ByteCountFormatter.string(fromByteCount: duplicatesBytes, countStyle: .file) }
    var screenshotsBytesText: String { ByteCountFormatter.string(fromByteCount: screenshotsBytes, countStyle: .file) }
    var largeVideosBytesText: String { ByteCountFormatter.string(fromByteCount: largeVideosBytes, countStyle: .file) }
}

#Preview {
    SmartCleanResultsView(
        summary: SmartCleanScanSummary(
            similarCount: 240,
            similarBytes: Int64(1.2 * 1024 * 1024 * 1024),
            duplicatesCount: 128,
            duplicatesBytes: Int64(120 * 1024 * 1024),
            screenshotsCount: 85,
            screenshotsBytes: Int64(210 * 1024 * 1024),
            largeVideosCount: 3,
            largeVideosBytes: Int64(405 * 1024 * 1024),
            duplicateDeleteIDs: [],
            screenshotIDs: [],
            largeVideoIDs: []
        )
    )
}



