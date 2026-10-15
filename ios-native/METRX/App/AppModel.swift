import SwiftUI
import Observation

enum Tab: CaseIterable { case home, projects, profile
    var icon: String { ["home", "folder", "user"][index] }
    var label: String { ["tab.home", "tab.projects", "tab.profile"][index] }
    private var index: Int { Tab.allCases.firstIndex(of: self)! }
}

/// A page on a tab's stack (prototype: S.nav.stacks[tab] = [{s:'projects'}, …]). Project pages arrive in part 2.
enum Route: Hashable { case root, settingsMore, subscription }

/// Bottom sheets. One at a time, like the prototype's U.sheet.
enum Sheet: Equatable { case language, device, reportLang, units, roomLabel, about }

/// Screens of the sign-in flow.
enum AuthStep { case welcome, signUp, logIn, local }

/// Everything the screens share: where each tab is, the open sheet, the toast, the sign-in flow.
@Observable
final class AppModel {
    static let shared = AppModel()
    var tab: Tab = .home
    var stacks: [Tab: [Route]] = [.home: [.root], .projects: [.root], .profile: [.root]]
    /// +1 when the last change pushed a page, -1 when it popped one: the slide direction.
    var dir = 1
    var sheet: Sheet? = nil
    var toast: ToastMsg? = nil
    var auth: [AuthStep] = []
    var authFromProfile = false
    var editMe = false
    var soon = false

    var stack: [Route] { stacks[tab] ?? [.root] }
    var top: Route { stack.last ?? .root }

    func push(_ r: Route) { dir = 1; withAnimation(.easeOut(duration: 0.28)) { stacks[tab, default: [.root]].append(r) } }
    @discardableResult func pop() -> Bool {
        guard stack.count > 1 else { return false }
        dir = -1; withAnimation(.easeOut(duration: 0.28)) { _ = stacks[tab]?.popLast() }
        return true
    }
    /// Tapping the current tab again goes back to its first page.
    func selectTab(_ t: Tab) {
        if t == tab { if stack.count > 1 { dir = -1; withAnimation(.easeOut(duration: 0.28)) { stacks[t] = [.root] } } }
        else { withAnimation(.easeOut(duration: 0.18)) { tab = t } }
    }

    func say(_ key: String, _ vars: [String: Any]? = nil, kind: ToastKind = .ok, action: String? = nil, onAction: (() -> Void)? = nil) {
        toast = ToastMsg(text: tr(key, vars), kind: kind, action: action.map { tr($0) }, onAction: onAction)
    }

    /// The simulated laser: searching takes a moment, then finds the simulator.
    func searchLaser() {
        AppSettings.shared.laser = .searching
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { if AppSettings.shared.laser == .searching { AppSettings.shared.laser = .found } }
    }
}
