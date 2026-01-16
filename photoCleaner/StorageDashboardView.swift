import Foundation
import Photos
import SwiftUI

struct StorageDashboardView: View {
    private let accent = Color(red: 0.00, green: 0.67, blue: 0.95) // 接近设计稿的蓝色
    @State private var showSmartClean: Bool = false

    @StateObject private var vm = StorageDashboardViewModel()

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            RingProgressView(progress: vm.usedFraction, tint: accent)
                                .frame(width: 260, height: 260)
                                .padding(.top, 8)

                            Text(vm.usedText)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.top, 6)

                            Text(vm.optimizationText)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(Color(.secondaryLabel))
                        }

                        HStack(spacing: 16) {
                            StatCard(
                                title: "AVAILABLE",
                                value: vm.availableText,
                                valueColor: .primary
                            )
                            StatCard(
                                title: "RECOVERABLE",
                                value: vm.recoverableText,
                                valueColor: accent
                            )
                        }
                        .padding(.horizontal, 22)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Cleaning Categories")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.primary)

                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                                NavigationLink {
                                    SimilarPhotosView()
                                } label: {
                                    CategoryCard(
                                        icon: "square.on.square",
                                        iconTint: accent,
                                        iconBg: Color(red: 0.90, green: 0.97, blue: 1.00),
                                        title: "Similar",
                                        subtitle: "Tap to scan"
                                    )
                                }
                                .buttonStyle(.plain)
                                NavigationLink {
                                    DuplicatesView()
                                } label: {
                                    CategoryCard(
                                        icon: "doc.on.doc",
                                        iconTint: Color(red: 1.00, green: 0.48, blue: 0.05),
                                        iconBg: Color(red: 1.00, green: 0.94, blue: 0.87),
                                        title: "Duplicates",
                                        subtitle: "Tap to scan"
                                    )
                                }
                                .buttonStyle(.plain)
                                NavigationLink {
                                    LargeVideosView()
                                } label: {
                                    CategoryCard(
                                        icon: "video",
                                        iconTint: Color(red: 0.62, green: 0.28, blue: 1.00),
                                        iconBg: Color(red: 0.95, green: 0.90, blue: 1.00),
                                        title: "Large Videos",
                                        subtitle: "Tap to scan"
                                    )
                                }
                                .buttonStyle(.plain)
                                CategoryCard(
                                    icon: "viewfinder",
                                    iconTint: Color(red: 0.16, green: 0.77, blue: 0.33),
                                    iconBg: Color(red: 0.88, green: 0.98, blue: 0.90),
                                    title: "Screenshots",
                                    subtitle: {
                                        if let n = vm.screenshotCount {
                                            return "\(n) items found"
                                        }
                                        return "Tap to scan"
                                    }()
                                )
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                        .padding(.bottom, 110) // 给底部按钮留空间
                    }
                }
                .refreshable {
                    await vm.refresh()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            smartCleanButton
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
        }
        .task {
            await vm.refresh()
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                Button {
                    // TODO: settings
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                }

                Spacer()

                Button {
                    // TODO: help
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .overlay {
                                Circle().stroke(Color(.systemGray4), lineWidth: 1)
                            }
                        Image(systemName: "questionmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    .frame(width: 34, height: 34)
                }
            }

            Text("Storage")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private var smartCleanButton: some View {
        Button {
            showSmartClean = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 18, weight: .semibold))
                Text("Smart Clean")
                    .font(.system(size: 22, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(accent)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showSmartClean) {
            SmartCleanView()
        }
    }
}

@MainActor
private final class StorageDashboardViewModel: ObservableObject {
    @Published var usedFraction: Double = 0
    @Published var usedText: String = "—"
    @Published var availableText: String = "—"
    @Published var recoverableText: String = "—"
    @Published var optimizationText: String = ""
    @Published var screenshotCount: Int? = nil

    func refresh() async {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]

        do {
            let values = try url.resourceValues(forKeys: keys)

            // NOTE: URLResourceValues uses a mix of Int? / Int64? across these keys depending on OS.
            // Avoid chaining ?? across mismatched numeric types by normalizing to Int64 manually.
            let total: Int64 = {
                if let v = values.volumeTotalCapacity { return Int64(v) }
                return 0
            }()

            let availBasic: Int64 = {
                if let v = values.volumeAvailableCapacity { return Int64(v) }
                return 0
            }()

            let availImportant: Int64 = {
                if let v = values.volumeAvailableCapacityForImportantUsage { return Int64(v) }
                return availBasic
            }()

            let availOpportunistic: Int64 = {
                if let v = values.volumeAvailableCapacityForOpportunisticUsage { return Int64(v) }
                return availImportant
            }()

            guard total > 0 else {
                usedFraction = 0
                usedText = "—"
                availableText = "—"
                recoverableText = "—"
                optimizationText = ""
                return
            }

            let used = max(Int64(0), total - availImportant)
            usedFraction = min(1, max(0, Double(used) / Double(total)))

            usedText = "\(formatGB(used)) / \(formatGB(total))"
            availableText = formatGB(availImportant)

            // "Recoverable" is not a perfect OS concept; use the delta between opportunistic and important.
            let recoverable = max(Int64(0), availOpportunistic - availImportant)
            recoverableText = formatGB(recoverable)

            optimizationText = usedFraction >= 0.80 ? "Optimization recommended" : "Storage looks good"
        } catch {
            usedText = "—"
            availableText = "—"
            recoverableText = "—"
            optimizationText = ""
        }

        refreshScreenshotCountIfAuthorized()
    }

    private func formatGB(_ bytes: Int64) -> String {
        // Use decimal GB to match common storage marketing numbers and the design sample.
        let gb = Double(bytes) / 1_000_000_000.0
        if gb >= 100 {
            return "\(Int(gb.rounded())) GB"
        }
        // Prefer 1 decimal like "108.8 GB"
        return String(format: "%.1f GB", gb)
    }

    private func refreshScreenshotCountIfAuthorized() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            screenshotCount = nil
            return
        }

        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(format: "mediaSubtype == %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
        let count = PHAsset.fetchAssets(with: .image, options: opts).count
        screenshotCount = count
    }
}

private struct RingProgressView: View {
    let progress: Double // 0...1
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 18)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.primary)
                Text("Used")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.secondaryLabel))
            Text(value)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                }
        )
    }
}

private struct CategoryCard: View {
    let icon: String
    let iconTint: Color
    let iconBg: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            .frame(width: 54, height: 54)

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                }
        )
    }
}

#Preview {
    StorageDashboardView()
}



