import SwiftUI

@main
struct METRXApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                // very large text sizes would break the glass layouts; up to xxLarge follows the phone's setting
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
    }
}
