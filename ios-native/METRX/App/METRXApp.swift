import SwiftUI
import UIKit

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
        .onChange(of: phase) { _, p in
            // everything typed is on disk before the app can be closed in the background
            if p != .active { Store.shared.flush() }
            // the real laser: no scans or reconnecting in the background, the link let go soon (other phones may take
            // it); back in front, the remembered laser is tried again at once
            if p == .background { LzBgTime.begin(); RealLaser.shared.background() }
            if p == .active { RealLaser.shared.foreground(); LzBgTime.end() }
        }
    }
}

/// A little time in the background, so the laser's link can be let go there (RealLaser.bgGraceS) rather than when the
/// app comes back; iOS ends it by itself after about half a minute.
enum LzBgTime {
    private static var task: UIBackgroundTaskIdentifier = .invalid
    private static var gen = 0

    static func begin() {
        end()
        gen += 1
        let g = gen
        task = UIApplication.shared.beginBackgroundTask(withName: "metrx.laser") { LzBgTime.end() }
        // the link is let go after bgGraceS: the time is given back just after
        DispatchQueue.main.asyncAfter(deadline: .now() + RealLaser.bgGraceS + 1) { if g == LzBgTime.gen { LzBgTime.end() } }
    }

    static func end() {
        if task == .invalid { return }
        UIApplication.shared.endBackgroundTask(task)
        task = .invalid
    }
}
