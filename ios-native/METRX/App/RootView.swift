import SwiftUI

/// The whole app: the opening animation over the first screen, the sign-in flow on a first start, then the tabs with
/// their pages, the floating tab bar, the open sheet and the toast.
struct RootView: View {
    @State private var app = AppModel.shared
    @State private var splash = true
    @State private var splashFade = 1.0
    @State private var welcomeRise = true

    private var settings: AppSettings { AppSettings.shared }
    private var inAuth: Bool { !app.auth.isEmpty || app.editMe }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // the first screen is laid out under the animation from the start, so nothing flashes when it fades
                (inAuth ? Color.white : G.paper).ignoresSafeArea()
                screens
                if splash {
                    RoomHops(dockTo: dock(geo), onDone: endSplash).opacity(splashFade)
                }
            }
        }
        .preferredColorScheme(splash || (settings.dark && !inAuth) ? .dark : .light)
        .onChange(of: inAuth, initial: true) { _, v in Theme.shared.inAuth = v }
        .onAppear { if !settings.firstRunDone && app.auth.isEmpty { app.auth = [.welcome] } }
    }

    /// The animation docks its tile where the next screen's header logo is.
    private func dock(_ geo: GeometryProxy) -> CGRect {
        let top = geo.safeAreaInsets.top
        return inAuth ? CGRect(x: 20, y: top + 14, width: 28, height: 28) : CGRect(x: 20, y: top + 13, width: 38, height: 38)
    }

    private func endSplash() {
        app.splashDone = true
        withAnimation(.linear(duration: 0.22)) { splashFade = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { splash = false }
    }

    private var authNav: AuthNav {
        AuthNav(
            signUp: { push(.signUp) },
            logIn: { push(.logIn) },
            local: {
                if app.authFromProfile { withAnimation { app.auth = []; app.authFromProfile = false } } else { push(.local) }
            },
            back: {
                withAnimation(.easeOut(duration: 0.26)) {
                    if app.editMe { app.editMe = false }
                    else if app.auth.count > 1 { app.auth.removeLast() }
                    else if app.authFromProfile { app.auth = []; app.authFromProfile = false }
                }
            },
            done: {
                if app.editMe { withAnimation { app.editMe = false }; app.say("common.save"); return }
                // the first run asks for the industry once, after sign-in (furniture plan section 3)
                if settings.industry == nil { app.soon = false; push(.industry); return }
                settings.finishFirstRun()
                withAnimation(.easeOut(duration: 0.26)) { app.auth = []; app.authFromProfile = false; app.soon = false }
            },
            soon: { app.soon = true }
        )
    }
    private func push(_ s: AuthStep) { welcomeRise = false; withAnimation(.easeOut(duration: 0.26)) { app.auth.append(s) } }

    @ViewBuilder private var screens: some View {
        ZStack {
            if app.editMe {
                LocalScreen(nav: authNav, title: tr("fr.builderTitle")).transition(.move(edge: .trailing))
            } else if let step = app.auth.last {
                Group {
                    switch step {
                    case .welcome: WelcomeScreen(nav: authNav, fromSplash: welcomeRise && !app.authFromProfile)
                    case .signUp: SignUpScreen(nav: authNav)
                    case .logIn: LogInScreen(nav: authNav)
                    case .local: LocalScreen(nav: authNav)
                    case .industry:
                        ZStack {
                            Aurora()
                            IndustryScreen(app: app, onBack: authNav.back) { k in settings.setIndustryKind(k); authNav.done() }
                        }
                    }
                }
                .id(app.auth.count)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            } else {
                main
            }
            if let sh = app.sheet { sheetView(sh).zIndex(5) }
            if app.soon { SoonSheet(onLocal: { app.soon = false; authNav.local() }, onClose: { app.soon = false }).zIndex(6) }
            ToastHost(msg: app.toast) { app.toast = nil }.zIndex(7)
        }
    }

    private var main: some View {
        ZStack(alignment: .bottom) {
            Aurora()
            page
                .id("\(app.tab)-\(app.stack.count)-\(app.top.pageKey)")
                // the page sliding away takes no taps, so a second tap cannot create or go back twice
                .transition((app.dir > 0 ? AnyTransition.push(from: .trailing) : .push(from: .leading))
                    .combined(with: .modifier(active: TapsOff(off: true), identity: TapsOff(off: false))))
            // iPhone's back gesture: a swipe from the left edge closes the page
            if app.stack.count > 1 && app.sheet == nil {
                Color.clear.frame(width: 20).frame(maxHeight: .infinity).contentShape(Rectangle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gesture(DragGesture(minimumDistance: 10).onEnded { v in if v.translation.width > 70 { if let b = app.backOverride { b() } else { app.pop() } } })
            }
            // the tab bar shows on the tab pages and the project page; it steps away under a sheet
            if app.sheet == nil && (app.top == .root || { switch app.top { case .project, .measure: return true; default: return false } }()) {
                // it stays at the bottom when the keyboard opens (the keyboard covers it, as in other iPhone apps)
                GlassNav(cur: app.tab) { app.selectTab($0) }.transition(.opacity).ignoresSafeArea(.keyboard)
            }
        }
    }

    @ViewBuilder private var page: some View {
        switch app.top {
        case .root:
            switch app.tab {
            case .home: HomeScreen(app: app)
            case .projects: ProjectsList(app: app)
            case .profile: ProfileScreen(app: app)
            }
        case .settingsMore: SettingsMoreScreen(app: app)
        case .subscription: SubscriptionScreen(app: app)
        case .workshop: WorkshopScreen(app: app)
        case .materials: MaterialsScreen(app: app)
        case .newProject(let e):
            // a furniture maker's new order asks only who it is for (furniture orders UX, 20 Oct 2026)
            if e == nil && AppSettings.shared.furniture { NewOrderScreen(app: app) } else { NewProjectScreen(app: app, editId: e) }
        case .project(let id, let tab, let view, let floor): ProjectScreen(app: app, id: id, tab: tab, view: view, floor: floor)
        case .space(let pid, let wid): SpaceScreen(app: app, pid: pid, wid: wid)
        case .note(let pid, let wid, let iid): NoteScreen(app: app, pid: pid, wid: wid, iid: iid)
        case .editor(let pid, let rid, let mode): EditorScreen(app: app, pid: pid, rid: rid, mode: mode)
        case .wallView(let pid, let rid, let wall): WallViewScreen(app: app, pid: pid, rid: rid, wall: wall)
        case .sketch(let pid, let wid, let name): SketchScreen(app: app, pid: pid, wid: wid, name: name)
        case .report(let pid, let no): ReportScreen(app: app, pid: pid, no: no)
        case .measure(let calc): MeasureScreen(app: app, calcTitle: calc)
        case .markup(let pid, let iid): MarkupScreen(app: app, pid: pid, iid: iid)
        case .liveCam: LiveCamScreen(app: app)
        case .kitchen(let pid, let fid, let wall, let d3): KitchenScreen(app: app, pid: pid, fid: fid, wall: wall, d3: d3)
        case .wardrobe(let pid, let fid, let step, let sec, let d3): WardrobeScreen(app: app, pid: pid, fid: fid, step: step, sec: sec, d3: d3)
        case .fCut(let pid): CutScreen(app: app, pid: pid)
        case .fPack(let pid): PackScreen(app: app, pid: pid)
        case .fGallery(let pid, let rid, let fromNew): FGalleryScreen(app: app, pid: pid, rid: rid, fromNew: fromNew)
        case .fSteps(let pid, let model, let fid, let vals): FStepsScreen(app: app, pid: pid, model: model, fid: fid, vals: vals)
        case .fWhere(let pid, let model, let vals): FWhereScreen(app: app, pid: pid, model: model, vals: vals)
        case .fPlace(let pid, let fid, let rid, let model, let vals): FPlaceScreen(app: app, pid: pid, fid: fid, rid: rid, model: model, vals: vals)
        }
    }

    @ViewBuilder private func sheetView(_ s: Sheet) -> some View {
        switch s {
        case .language: LanguageSheet(app: app)
        case .device: DeviceSheet(app: app)
        default:
            if OrderFlowSheet.handles(s) { OrderFlowSheet(app: app, sheet: s) }
            else if TradeSheet.handles(s) { TradeSheet(app: app, sheet: s) }
            else if FurnitureSheet.handles(s) { FurnitureSheet(app: app, sheet: s) }
            else if WorkshopSheet.handles(s) { WorkshopSheet(app: app, sheet: s) }
            else if KitchenSheet.handles(s) { KitchenSheet(app: app, sheet: s) }
            else if WardrobeSheet.handles(s) { WardrobeSheet(app: app, sheet: s) }
            else if PriceSheet.handles(s) { PriceSheet(app: app, sheet: s) }
            else if EditorSheet.handles(s) { EditorSheet(app: app, sheet: s) }
            else if EstimateSheet.handles(s) { EstimateSheet(app: app, sheet: s) }
            else if ReportSheet.handles(s) { ReportSheet(app: app, sheet: s) }
            else if QuickSheet.handles(s) { QuickSheet(app: app, sheet: s) }
            else if MarkupSheet.handles(s) { MarkupSheet(app: app, sheet: s) }
            else if case .lcManual = s { LcManualSheet(app: app) }
            else if ProjectSheet.handles(s) { ProjectSheet(app: app, sheet: s) } else { ProfileSheet(app: app, sheet: s) }
        }
    }
}

/// Off: the view takes no taps (a page while it slides away).
private struct TapsOff: ViewModifier {
    let off: Bool
    func body(content: Content) -> some View { content.allowsHitTesting(!off) }
}
