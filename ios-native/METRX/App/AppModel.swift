import SwiftUI
import Observation

enum Tab: CaseIterable { case home, projects, profile
    var icon: String { ["home", "folder", "user"][index] }
    var label: String { ["tab.home", "tab.projects", "tab.profile"][index] }
    private var index: Int { Tab.allCases.firstIndex(of: self)! }
}

/// A page on a tab's stack (prototype: S.nav.stacks[tab] = [{s:'projects'}, {s:'project', id, tab}, …]).
enum Route: Hashable {
    case root, settingsMore, subscription
    /// New project, or edit project editId.
    case newProject(editId: String?)
    /// A project page with its tab: "rooms", "estimate", "quotes" or "info".
    case project(id: String, tab: String)
    case space(pid: String, wid: String)
    case note(pid: String, wid: String, iid: String)

    /// The same page with another tab does not slide.
    var pageKey: String {
        switch self {
        case .project(let id, _): return "project:" + id
        default: return "\(self)"
        }
    }
}

/// Bottom sheets. One at a time, like the prototype's U.sheet.
enum Sheet: Equatable {
    case language, device, reportLang, units, roomLabel, about, currency
    case projectMenu(pid: String), projectDelete(pid: String)
    case newSpace(pid: String, editWid: String?), spaceMenu(pid: String, wid: String), spaceDelete(pid: String, wid: String)
    /// "+" in a workspace: step "root", "sketch" or "photo".
    case addItem(pid: String, wid: String, step: String)
    case itemMenu(pid: String, wid: String, iid: String), itemRename(pid: String, wid: String, iid: String), itemMove(pid: String, wid: String, iid: String)
}

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
    /// The launch animation has handed over (the welcome screen rises then).
    var splashDone = false

    var stack: [Route] { stacks[tab] ?? [.root] }
    var top: Route { stack.last ?? .root }

    var store: Store { Store.shared }

    func push(_ r: Route) { dir = 1; withAnimation(.easeOut(duration: 0.28)) { stacks[tab, default: [.root]].append(r) } }
    @discardableResult func pop() -> Bool {
        guard stack.count > 1 else { return false }
        dir = -1; withAnimation(.easeOut(duration: 0.28)) { _ = stacks[tab]?.popLast() }
        return true
    }
    func replaceTop(_ r: Route) { dir = 1; withAnimation(.easeOut(duration: 0.28)) { stacks[tab, default: [.root]][stack.count - 1] = r } }
    /// Changes what the top page shows without moving to another page (the project's tab).
    func setTop(_ r: Route) { stacks[tab, default: [.root]][stack.count - 1] = r }
    func setProjectTab(_ t: String) { if case .project(let id, _) = top { setTop(.project(id: id, tab: t)) } }

    /// Leaves pages of a project, workspace or note that no longer exists (after a delete).
    func dropMissing() {
        for (t, st) in stacks {
            let keep = st.filter { r in
                switch r {
                case .project(let id, _): return store.get(id) != nil
                case .newProject(let e): return e == nil || store.get(e) != nil
                case .space(let pid, let wid): return store.get(pid)?.floors.contains { $0.id == wid } == true
                case .note(let pid, let wid, let iid): return store.get(pid)?.floors.first { $0.id == wid }?.items.contains { $0.id == iid } == true
                default: return true
                }
            }
            if keep.count != st.count { stacks[t] = keep }
        }
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
