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
    /// Profile → the workshop's rules, and its boards and hardware (furniture makers).
    case workshop, materials
    /// New project, or edit project editId.
    case newProject(editId: String?)
    /// A project page with its tab: "rooms", "estimate", "quotes" or "info"; the Workspaces tab's view "list", "2d" or
    /// "3d", and the workspace its 3D view shows.
    case project(id: String, tab: String, view: String = "list", floor: String? = nil)
    case space(pid: String, wid: String)
    case note(pid: String, wid: String, iid: String)
    /// The room editor; mode "plan" or "3d" (prototype top().mode).
    case editor(pid: String, rid: String, mode: String)
    case wallView(pid: String, rid: String, wall: String)
    /// Drawing a new room's outline (prototype PAGES.sketch).
    case sketch(pid: String, wid: String, name: String)
    /// The draft report (no nil) or issued quote № no.
    case report(pid: String, no: Int?)
    /// The Measure page, from Home's "O‘lchash" or, scrolled to the calculator, "Kalkulyator" (prototype tab 'measure').
    case measure(calc: Bool)
    /// A free drawing or a photo (prototype PAGES.draw / PAGES.photo); pid nil: a picture of the Measure page.
    case markup(pid: String?, iid: String)
    /// The Measure page's live camera (prototype PAGES.liveCam).
    case liveCam
    /// Furniture makers: the kitchen designer on wall (nil: the first).
    case kitchen(pid: String, fid: String, wall: String?, d3: Bool = false)
    /// The wardrobe designer at step 1–5 (place, sizes, doors, inside, material), section sec picked.
    case wardrobe(pid: String, fid: String, step: Int, sec: Int, d3: Bool = false)
    /// Furniture orders: the parts and sheet layout, and the workshop pack.
    case fCut(pid: String), fPack(pid: String)
    /// Adding furniture (gallery v5, 21 Oct 2026; Android Gallery.kt): the models by room (rid a room it is for,
    /// fromNew right after a new order); a model's sizes step by step (fid: changing a piece's); which room; into a room.
    /// fPlace places piece fid, or a new piece of model with the sizes vals ("s0=3000,h=2700"; nil: sizes from the room).
    case fGallery(pid: String, rid: String? = nil, fromNew: Bool = false)
    /// vals: the sizes typed so far ("s0=3400,h=2700"), kept while "Which room?" is on top; the steps open on the summary.
    case fSteps(pid: String, model: String, fid: String? = nil, vals: String? = nil)
    case fWhere(pid: String, model: String, vals: String)
    case fPlace(pid: String, fid: String?, rid: String, model: String? = nil, vals: String? = nil)

    /// The same page with another tab does not slide.
    var pageKey: String {
        switch self {
        case .project(let id, _, _, _): return "project:" + id
        case .editor(let pid, let rid, _): return "editor:" + pid + ":" + rid
        case .kitchen(let pid, let fid, _, _): return "kitchen:" + pid + ":" + fid
        case .wardrobe(let pid, let fid, _, _, _): return "wardrobe:" + pid + ":" + fid
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
    /// The room editor's sheets: a new room, typing a measurement, doors and windows, the room's info, rename, the
    /// readings tray, a room card's menu and move, adding from the wall view (the wall fixed).
    case newRoom(pid: String, wid: String)
    case measure(pid: String, rid: String, k: String)
    case addOpening(pid: String, rid: String)
    case openingForm(pid: String, rid: String, oid: String?, type: String, wall: String?)
    case roomInfo(pid: String, rid: String), roomRename(pid: String, rid: String), tray(pid: String, rid: String)
    case roomMenu(pid: String, rid: String), roomMove(pid: String, rid: String)
    case wallAdd(pid: String, rid: String, wall: String)
    /// The Smeta tab's sheets: the rooms' areas, and a material or labour row (kind "mat" or "lab"; id nil for a new
    /// one, which may start with a suggested name and unit).
    case areas(pid: String)
    case row(pid: String, kind: String, id: String? = nil, name: String? = nil, unit: String? = nil)
    /// The report's set-up (language, rooms, extras, views, note) and issuing a quote (builderOnly: only the builder).
    case reportSetup(pid: String)
    case issue(pid: String, builderOnly: Bool = false)
    /// The Measure page: typing a reading, the brick settings, sending a reading to a room.
    case qmManual, brickSet
    case sendReading(id: String)
    /// Profile: the PDF's parts and the door and window sizes new openings start from.
    case pdfParts, defaults
    /// The markup editor: a line's length, a text mark, the photo's caption; a Measure page picture's menu, deleting it,
    /// moving it into a project; the camera choice; the live camera's typed length.
    case mkDim(eid: String)
    case mkText(eid: String?, x: Double, y: Double)
    case mkCaption, shotMenu, shotDel, shotTo, cameraPick, lcManual
    /// Profile → Soha; a furniture order: approving it (agreed price and prepayment), adding a payment.
    case industry, fApprove(pid: String), fPay(pid: String)
    /// A site point on a wall of a furniture order's room: a new one (id nil) on wall, or an existing one.
    case pointForm(pid: String, rid: String, wall: String, id: String?)
    /// Profile → workshop: one rule's value; a board or banding (nil: a new one); a hardware item.
    case wsField(key: String), matForm(id: String?), hwForm(id: String?)
    /// Furniture: new furniture in a workspace, its menu, name and boards; a unit's settings; the unit library (group
    /// module, appl or space) for a wall.
    case fMenu(pid: String, fid: String), fRename(pid: String, fid: String), fMats(pid: String, fid: String)
    /// Furniture orders: a new room (kind the furniture it is for; fid a room-less piece that goes in once it is
    /// measured), the install date, which room a room-less piece goes into.
    case fNewRoom(pid: String, kind: String? = nil, fid: String? = nil), fInstall(pid: String), fPickRoom(pid: String, fid: String)
    /// The trades' calculator settings; a column or a niche (fid nil: a new one).
    case tradeCalc(pid: String), featureForm(pid: String, rid: String, fid: String?, type: String)
    case fModule(pid: String, fid: String, mid: String), fLibrary(pid: String, fid: String, wall: String, group: String)
    /// A kitchen's legs' height.
    case kLegs(pid: String, fid: String)
    /// The wardrobe: one size (key w, h, d, x or secW of section sec), an insert, more inserts for a section.
    /// Narx tab: a price, a rate or the lead time (key fixed, rRun, rTall or days).
    case fPriceField(pid: String, key: String)
    case wField(pid: String, fid: String, key: String, sec: Int), wInsert(pid: String, fid: String, sec: Int, idx: Int), wMore(pid: String, fid: String, sec: Int)
}

/// Screens of the sign-in flow.
enum AuthStep { case welcome, signUp, logIn, local, industry }

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
    /// A room being measured for a room-less piece (room id, furniture id): when it is done, the piece goes in.
    var placeAfter: (rid: String, fid: String)? = nil

    var stack: [Route] { stacks[tab] ?? [.root] }
    var top: Route { stack.last ?? .root }

    var store: Store { Store.shared }

    /// The same page is not opened twice on top of itself (a double tap).
    func push(_ r: Route) { if top == r { return }; dir = 1; withAnimation(.easeOut(duration: 0.28)) { stacks[tab, default: [.root]].append(r) } }
    @ObservationIgnored private var lastAct = Date.distantPast
    /// A page that steps back inside itself (the size steps) takes the edge swipe while it shows.
    @ObservationIgnored var backOverride: (() -> Void)? = nil
    /// False for a second tap within 0.6 s, so a double tap cannot create or save something twice.
    func once() -> Bool { let now = Date(); if now.timeIntervalSince(lastAct) < 0.6 { return false }; lastAct = now; return true }
    @discardableResult func pop() -> Bool {
        guard stack.count > 1 else { return false }
        dir = -1; withAnimation(.easeOut(duration: 0.28)) { _ = stacks[tab]?.popLast() }
        return true
    }
    func replaceTop(_ r: Route) { dir = 1; withAnimation(.easeOut(duration: 0.28)) { stacks[tab, default: [.root]][stack.count - 1] = r } }
    /// Changes what the top page shows without moving to another page (the project's tab).
    func setTop(_ r: Route) { stacks[tab, default: [.root]][stack.count - 1] = r }
    func setProjectTab(_ t: String) { if case .project(let id, _, let v, let f) = top { setTop(.project(id: id, tab: t, view: v, floor: f)) } }
    /// The Workspaces tab's view (list, 2D, 3D) and the workspace the 3D view shows.
    func setProjectView(_ v: String, floor: String? = nil) { if case .project(let id, let t, _, let f) = top { setTop(.project(id: id, tab: t, view: v, floor: floor ?? f)) } }

    /// Leaves pages of a project, workspace or note that no longer exists (after a delete).
    func dropMissing() {
        for (t, st) in stacks {
            let keep = st.filter { r in
                switch r {
                case .project(let id, _, _, _): return store.get(id) != nil
                case .newProject(let e): return e == nil || store.get(e) != nil
                case .space(let pid, let wid): return store.get(pid)?.floors.contains { $0.id == wid } == true
                case .note(let pid, let wid, let iid): return store.get(pid)?.floors.first { $0.id == wid }?.items.contains { $0.id == iid } == true
                case .editor(let pid, let rid, _), .wallView(let pid, let rid, _): return store.get(pid)?.rooms.contains { $0.id == rid } == true
                case .sketch(let pid, let wid, _): return store.get(pid)?.floors.contains { $0.id == wid } == true
                case .markup(let pid, let iid):
                    return pid.map { store.get($0)?.floors.contains { w in w.items.contains { $0.id == iid } } == true } ?? AppSettings.shared.shots.contains { $0.id == iid }
                case .report(let pid, let no): return store.get(pid).map { p in no == nil || p.quotes.contains { $0.no == no } } == true
                case .kitchen(let pid, let fid, _, _), .wardrobe(let pid, let fid, _, _, _): return store.get(pid)?.furniture.contains { $0.id == fid } == true
                case .fCut(let pid), .fPack(let pid), .fWhere(let pid, _, _): return store.get(pid) != nil
                case .fGallery(let pid, let rid, _): return store.get(pid).map { p in rid == nil || p.rooms.contains { $0.id == rid } } == true
                case .fSteps(let pid, _, let fid, _): return store.get(pid).map { p in fid == nil || p.furniture.contains { $0.id == fid } } == true
                case .fPlace(let pid, let fid, let rid, _, _): return store.get(pid).map { p in (fid == nil || p.furniture.contains { $0.id == fid }) && p.rooms.contains { $0.id == rid } } == true
                default: return true
                }
            }
            if keep.count != st.count { stacks[t] = keep }
        }
    }

    /// Back until a page that matches (or the first page).
    func popTo(_ match: (Route) -> Bool) {
        dir = -1
        withAnimation(.easeOut(duration: 0.28)) { while stack.count > 1 && !match(top) { stacks[tab]?.removeLast() } }
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
