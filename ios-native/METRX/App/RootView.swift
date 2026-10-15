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
                if !splash || splashFade < 1 { screens }
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
                .id("\(app.tab)-\(app.stack.count)")
                .transition(app.dir > 0 ? .push(from: .trailing) : .push(from: .leading))
            // iPhone's back gesture: a swipe from the left edge closes the page
            if app.stack.count > 1 && app.sheet == nil {
                Color.clear.frame(width: 20).frame(maxHeight: .infinity).contentShape(Rectangle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .gesture(DragGesture(minimumDistance: 10).onEnded { v in if v.translation.width > 70 { app.pop() } })
            }
            // the tab bar shows on the tab pages; it steps away under a sheet
            if app.sheet == nil && app.top == .root {
                GlassNav(cur: app.tab) { app.selectTab($0) }.transition(.opacity)
            }
        }
    }

    @ViewBuilder private var page: some View {
        switch app.top {
        case .root:
            switch app.tab {
            case .home: HomeScreen(app: app)
            case .projects: ProjectsScreen(app: app)
            case .profile: ProfileScreen(app: app)
            }
        case .settingsMore: SettingsMoreScreen(app: app)
        case .subscription: SubscriptionScreen(app: app)
        }
    }

    @ViewBuilder private func sheetView(_ s: Sheet) -> some View {
        switch s {
        case .language: LanguageSheet(app: app)
        case .device: DeviceSheet(app: app)
        default: ProfileSheet(app: app, sheet: s)
        }
    }
}
