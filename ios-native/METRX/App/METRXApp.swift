import SwiftUI

@main
struct METRXApp: App {
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView()
                // very large text sizes would break the glass layouts; up to xxLarge follows the phone's setting
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        // everything typed is on disk before the app can be closed in the background
        .onChange(of: phase) { _, p in if p != .active { Store.shared.flush() } }
    }
}
