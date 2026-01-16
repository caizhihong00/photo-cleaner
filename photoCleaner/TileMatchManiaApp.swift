import SwiftUI

@main
struct TileMatchManiaApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                StorageDashboardView()
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
    }
}


