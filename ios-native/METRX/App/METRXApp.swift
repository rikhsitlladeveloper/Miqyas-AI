import SwiftUI

@main
struct METRXApp: App {
    @Environment(\.scenePhase) private var phase
    init() {
        // 3D pictures, photos and quotes' copies left behind by rooms, items and projects deleted in an earlier session
        // (a project that could not be read keeps its files: it is still saved and may load in a later version)
        let st = Store.shared
        let ps = st.projects
        ViewFiles.sweep(ps, keepFiles: st.unreadableFiles, keepIds: st.unreadableIds)
        var used = st.unreadableFiles
        for p in ps {
            for w in p.floors { for it in w.items { if let s = it.src { used.insert(s) } } }
            // a quote issued before its photos were copied next to it still names the workspace's own
            for q in p.quotes { for x in q.sn.extras { if let s = x.src { used.insert(s) } } }
        }
        for it in AppSettings.shared.shots { if let s = it.src { used.insert(s) } }
        PhotoFiles.sweep(used)
    }
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
