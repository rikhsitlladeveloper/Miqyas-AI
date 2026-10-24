import SwiftUI

/// App Store v1 (founder, 25 Oct 2026): no accounts. The app opens straight into use: the welcome screen has only
/// "Boshlash" (the builder's name and phone, kept on this phone), then the trade. The sign-up, log-in and Google screens
/// stay in the code for a later version, unreachable while this is false.
enum AuthFlags { static let accounts = false }

/// Where the sign-in flow goes next. Sign-up and log-in are screens only for now: their buttons explain that.
struct AuthNav {
    var signUp: () -> Void
    var logIn: () -> Void
    var local: () -> Void
    var back: () -> Void
    var done: () -> Void
    var soon: () -> Void
}

/// auRise: a group fades in and slides up 10 pt, .45 s, with a delay, when the welcome follows the opening animation.
private struct Rise: ViewModifier {
    let play: Bool
    let delay: Double
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(!play || on ? 1 : 0).offset(y: !play || on ? 0 : 10)
            // it waits for the launch animation to hand over (the screen is already there, under it)
            .onChange(of: AppModel.shared.splashDone, initial: true) { _, done in
                if play && done && !on { withAnimation(.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.45).delay(delay)) { on = true } }
            }
    }
}
private extension View { func rise(_ play: Bool, _ delayMs: Double) -> some View { modifier(Rise(play: play, delay: delayMs / 1000)) } }

/// Welcome: the sample room card, the promise and "Boshlash" (with accounts: three sign-in buttons and "continue
/// without an account").
struct WelcomeScreen: View {
    let nav: AuthNav
    let fromSplash: Bool
    @State private var menu = false

    var body: some View {
        let s = AppSettings.shared
        GeometryReader { geo in
            // the whole screen's height, as on Android (bars included)
            let cardH = min(330, max(158, geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom - 600))
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        HStack(spacing: 9) { LogoTile(size: 28, corner: 8, color: Color(argb: 0xFF374FDD)); Text("METRX").st(mono(17, 700, Au.ink, ls: 0.2)) }
                        Spacer()
                        HStack(spacing: 6) {
                            MIcon("globe", Au.cobalt, 18, 1.8); T(s.lang.shortName, au(13.5, 600)); PathIcon("M6 9.5l6 6 6-6", Au.ink2, 18, 1.8)
                        }
                        .padding(.leading, 12).padding(.trailing, 10).frame(minHeight: 44)
                        .background(Capsule().fill(Color.white)).overlay(Capsule().strokeBorder(Au.line, lineWidth: 1.5))
                        .pressable(0.97) { menu.toggle() }
                        .accessibilityIdentifier("welcome.lang")
                    }
                    .frame(minHeight: 48).rise(fromSplash, 0)
                    SampleCard(height: cardH).rise(fromSplash, 0)
                    VStack(alignment: .leading, spacing: 7) {
                        T(tr("au.welcome"), au(27, 700, Au.ink, lh: 1.18, ls: -0.015)).padding(.top, 4)
                        T(tr("au.tagline"), au(15, 400, Au.ink2, lh: 1.45))
                    }
                    .rise(fromSplash, 80)
                    if AuthFlags.accounts {
                        VStack(spacing: 10) {
                            AuButton(tr("au.signup"), nav.signUp)
                            AuButton(tr("au.login"), kind: .outline, nav.logIn)
                            AuButton(label: tr("au.google"), kind: .outline, fontSize: 15, action: nav.soon, leading: { GoogleLogo() }, trailing: { EmptyView() })
                        }
                        .padding(.top, 4).rise(fromSplash, 160)
                        SkipCard(onClick: nav.local).rise(fromSplash, 160)
                        Terms().padding(.top, 2).rise(fromSplash, 160)
                    } else {
                        StartBlock(onClick: nav.local).padding(.top, 4).rise(fromSplash, 160)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 10)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.white.ignoresSafeArea())
        .overlay { if menu { LanguageMenu(cur: s.lang, onPick: { s.setLanguage($0); menu = false }, onDismiss: { menu = false }) } }
    }
}

private struct LanguageMenu: View {
    let cur: Lang
    let onPick: (Lang) -> Void
    let onDismiss: () -> Void
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001).ignoresSafeArea().onTapGesture(perform: onDismiss)
            VStack(spacing: 2) {
                ForEach(Lang.allCases) { l in
                    let on = l == cur
                    HStack {
                        T(l.longName, au(15, on ? 600 : 400, on ? Au.cobalt2 : Au.ink)).padding(.trailing, 10)
                        Spacer(minLength: 0)
                        if on { MIcon("check", Au.cobalt2, 18, 2) }
                    }
                    .padding(.horizontal, 12).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? Au.wash : Color.white))
                    .pressable(0.98) { onPick(l) }
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(6)
            .frame(width: 230)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Au.hair, lineWidth: 1))
            .boxShadow(Color(argb: 0x2E0B1226), blur: 32, y: 12)
            .padding(.top, 58).padding(.trailing, 20)
        }
    }
}

/// The sample room of the whole prototype: 5,00 × 4,00 m, a window on the left wall, a door, one laser line.
private struct SampleCard: View {
    let height: CGFloat
    var body: some View {
        let l = AppSettings.shared.lang, m = tr("u.m"), m2 = tr("u.m2")
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 6) { Circle().fill(Au.cobalt).frame(width: 6, height: 6); Text(tr("au.sample").uppercased()).st(mono(10.5, 600, Au.ink, ls: 0.08)) }
                    .padding(.horizontal, 9).frame(minHeight: 22).background(Capsule().fill(Au.chip))
                Spacer()
                Text(tr("au.height").uppercased() + " ").st(mono(10.5, 500, Au.cobalt, ls: 0.08))
                Text("\(Num.len(3000, l)) \(m)").st(mono(10.5, 500, Au.cobalt, ls: 0.02))
            }
            .padding(.horizontal, 12).padding(.top, 10)
            PlanDrawing(lx: "\(Num.len(5000, l)) \(m)", ly: "\(Num.len(4000, l)) \(m)")
                .padding(.horizontal, 8).padding(.vertical, 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(Au.hair).frame(height: 1).padding(.horizontal, 12)
            HStack(spacing: 0) {
                Text(tr("au.room").uppercased() + ": ").st(mono(10.5, 600, Au.ink, ls: 0.08))
                Text("\(Num.fixed(20, 2, l)) \(m2)").st(mono(10.5, 600, Au.cobalt, ls: 0.02))
                Spacer()
                Text(tr("au.perim").uppercased() + ": ").st(mono(10.5, 600, Au.ink, ls: 0.08))
                Text("\(Num.len(18000, l)) \(m)").st(mono(10.5, 600, Au.cobalt, ls: 0.02))
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 9)
        }
        .frame(height: height)
        .background(shape.fill(Color.white))
        .overlay(shape.strokeBorder(Au.line, lineWidth: 1.5))
        .boxShadow(Color(argb: 0x123355B4), blur: 18, y: 6)
        .accessibilityElement(children: .combine)
    }
}

private struct PlanDrawing: View {
    let lx: String
    let ly: String
    var body: some View {
        Canvas { ctx, size in
            // viewBox 0 0 300 190, preserveAspectRatio xMidYMid meet
            let k = min(size.width / 300, size.height / 190)
            var c = ctx
            c.translateBy(x: (size.width - 300 * k) / 2, y: (size.height - 190 * k) / 2); c.scaleBy(x: k, y: k)
            let ink = Au.ink, bl = Au.cobalt
            func line(_ a: CGPoint, _ b: CGPoint, _ col: Color, _ w: CGFloat, dash: [CGFloat] = [], cap: CGLineCap = .butt) {
                var p = Path(); p.move(to: a); p.addLine(to: b)
                c.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: w, lineCap: cap, dash: dash))
            }
            c.fill(Path(ellipseIn: CGRect(x: 128, y: 90, width: 44, height: 44)), with: .color(Au.plan))
            line(CGPoint(x: 150, y: 58), CGPoint(x: 150, y: 168), Color(argb: 0xFFDDE5EF), 1, dash: [2, 4])
            c.stroke(SVGPath.path("M70 40V22M230 40V22M70 28H230M66 32l8-8M226 32l8-8"), with: .color(ink), lineWidth: 1.2)
            c.stroke(SVGPath.path("M238 48H258M238 176H258M252 48V176M248 52l8-8M248 180l8-8"), with: .color(ink), lineWidth: 1.2)
            c.stroke(SVGPath.path("M190 176H230V48H70V176H160"), with: .color(ink), style: StrokeStyle(lineWidth: 3.2, lineCap: .square))
            c.fill(Path(CGRect(x: 66.5, y: 84, width: 7, height: 42)), with: .color(Au.wash))
            c.stroke(Path(CGRect(x: 66.5, y: 84, width: 7, height: 42)), with: .color(bl), lineWidth: 1.4)
            line(CGPoint(x: 70, y: 84), CGPoint(x: 70, y: 126), bl, 1.4)
            line(CGPoint(x: 160, y: 176), CGPoint(x: 181.2, y: 154.8), ink, 2.2, cap: .round)
            c.stroke(SVGPath.path("M190 176A30 30 0 0 0 181.2 154.8"), with: .color(Color(argb: 0xFF8A97AD)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            line(CGPoint(x: 42, y: 105), CGPoint(x: 62, y: 105), Color(argb: 0xFFB4C0D3), 1, dash: [1.5, 3])
            line(CGPoint(x: 74, y: 105), CGPoint(x: 228, y: 105), bl, 1.5, dash: [4, 3])
            c.fill(Path(ellipseIn: CGRect(x: 221, y: 98, width: 14, height: 14)), with: .color(bl.opacity(0.2)))
            c.fill(Path(ellipseIn: CGRect(x: 224.5, y: 101.5, width: 7, height: 7)), with: .color(bl))
            func lab(_ text: String, _ p: CGPoint, _ rot: Double) {
                var l = c
                l.translateBy(x: p.x, y: p.y); l.rotate(by: .degrees(rot))
                let r = CGRect(x: -29, y: -10, width: 58, height: 20)
                l.fill(Path(roundedRect: r, cornerRadius: 3), with: .color(.white))
                l.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(Au.line), lineWidth: 1)
                l.draw(l.resolve(Text(text).font(.custom("IBMPlexMono-Medium", size: 11)).foregroundColor(ink)), at: .zero, anchor: .center)
            }
            lab(lx, CGPoint(x: 150, y: 28), 0)
            lab(ly, CGPoint(x: 252, y: 112), 90)
        }
    }
}

/// v1's start: one button to the builder's details, and where everything is kept.
private struct StartBlock: View {
    let onClick: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AuButton(label: tr("fr.start"), action: onClick, leading: { EmptyView() }, trailing: { PathIcon(NEXT_ARROW, .white, 18, 1.8) })
                .accessibilityIdentifier("welcome.skip")
            HStack(alignment: .top, spacing: 8) {
                MIcon("device", Au.ink2, 18, 1.8)
                T(tr("au.skipNote"), au(13, 400, Au.ink2, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct SkipCard: View {
    let onClick: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 12) {
            MIcon("device", Au.cobalt, 22, 1.8).frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Au.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    T(tr("au.skip"), au(15, 600))
                    Text(tr("au.offTag").uppercased()).st(mono(10, 600, .white, ls: 0.08))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Au.cobalt))
                }
                T(tr("au.skipNote"), au(13, 400, Au.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", Au.cobalt, 18, 2)
        }
        .padding(.leading, 12).padding(.trailing, 10).padding(.vertical, 12)
        .background(shape.fill(Au.tint))
        .overlay(shape.strokeBorder(Au.line, lineWidth: 1.5))
        .pressable(0.99, onClick)
        .accessibilityIdentifier("welcome.skip")
    }
}

/* ---------- step pages: header with back, title and n/3, progress, body, footer ---------- */

private struct AuPage<Content: View, Footer: View>: View {
    let title: String
    let step: Int?
    let onBack: () -> Void
    var bottomNote: AnyView? = nil
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer
    @State private var keyboard = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MIcon("back", Au.ink, 24, 2).frame(width: 48, height: 48).pressable(0.95, label: tr("nt.back"), onBack)
                VStack(spacing: 0) {
                    T(title, au(17, 700), align: .center)
                    if let step { Text("\(step)/3").st(mono(12.5, 400, Au.ink2)) }
                }
                .frame(maxWidth: .infinity)
                Color.clear.frame(width: 48, height: 48)
            }
            .padding(.horizontal, 8).frame(minHeight: 56)
            if let step {
                HStack(spacing: 8) { ForEach(1...3, id: \.self) { i in Capsule().fill(i <= step ? Au.cobalt : Au.step).frame(height: 4) } }
                    .padding(.horizontal, 20).padding(.bottom, 12)
            }
            Rectangle().fill(Au.hair).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { content }
                    .padding(.horizontal, 20).padding(.top, 22).padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            if Footer.self != EmptyView.self {
                Rectangle().fill(Au.hair).frame(height: 1)
                footer.padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 12)
            }
            if let bottomNote, !keyboard { bottomNote.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12) }
        }
        .background(Color.white.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboard = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboard = false }
    }
}

private let NEXT_ARROW = "M5 12h14M13 6l6 6-6 6"
private enum F: Hashable { case name, phone, pw }

private func hideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

/// Sign up, step 1: name and phone. Sending the code is not built yet, so the button explains that.
struct SignUpScreen: View {
    let nav: AuthNav
    @State private var name = ""
    @State private var phone = ""
    @State private var tName = false
    @State private var tPhone = false
    @FocusState private var focus: F?
    var body: some View {
        let nErr = name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("bd.req") : nil
        let pErr = Phone.errorKey(phone, required: true).map { tr($0) }
        AuPage(title: tr("au.signup"), step: 1, onBack: nav.back, bottomNote: AnyView(Terms())) {
            AuHeading(title: tr("su.phoneTitle"), lead: tr("su.phoneBody"))
            AuField(label: tr("su.name"), value: $name, placeholder: tr("fr.namePh"), error: nErr, showError: tName, focus: $focus, me: .name,
                    onSubmit: { focus = .phone }, onBlur: { tName = true })
            AuField(label: tr("su.phone"), value: $phone, kind: .phone, placeholder: "90 123 45 67", error: pErr, showError: tPhone, focus: $focus, me: .phone,
                    submit: .done, onSubmit: { focus = nil }, onBlur: { tPhone = true })
            AuButton(label: tr("su.sendCode"), enabled: nErr == nil && pErr == nil, action: { hideKeyboard(); nav.soon() },
                     leading: { EmptyView() }, trailing: { PathIcon(NEXT_ARROW, .white, 18, 1.8) })
            AuRow(lead: tr("su.have"), link: tr("au.login"), onLink: nav.logIn)
        } footer: { EmptyView() }
    }
}

/// Log in: phone and password, Google. Not built yet: the buttons explain that.
struct LogInScreen: View {
    let nav: AuthNav
    @State private var phone = ""
    @State private var pw = ""
    @State private var tPhone = false
    @State private var tPw = false
    @FocusState private var focus: F?
    var body: some View {
        let pErr = Phone.errorKey(phone, required: true).map { tr($0) }
        let wErr = pw.isEmpty ? tr("pw.req") : nil
        AuPage(title: tr("au.login"), step: nil, onBack: nav.back) {
            T(tr("li.title"), au(26, 700, Au.ink, lh: 1.2, ls: -0.012))
            AuField(label: tr("su.phone"), value: $phone, kind: .phone, placeholder: "90 123 45 67", error: pErr, showError: tPhone, focus: $focus, me: .phone,
                    onSubmit: { focus = .pw }, onBlur: { tPhone = true })
            AuField(label: tr("pw.label"), value: $pw, kind: .password, error: wErr, showError: tPw, focus: $focus, me: .pw,
                    submit: .done, onSubmit: { focus = nil }, onBlur: { tPw = true })
            HStack {
                Spacer()
                T(tr("li.forgot"), au(14.5, 600, Au.cobalt)).padding(.horizontal, 4).padding(.vertical, 12).pressable(0.97, nav.soon)
            }
            .offset(y: -10)
            AuButton(tr("au.login"), enabled: pErr == nil && wErr == nil) { hideKeyboard(); nav.soon() }
            HStack(spacing: 12) { Rectangle().fill(Au.hair).frame(height: 1); T(tr("au.or"), au(13, 400, Au.ink3)); Rectangle().fill(Au.hair).frame(height: 1) }
            AuButton(label: tr("au.google"), kind: .outline, fontSize: 15, action: nav.soon, leading: { GoogleLogo() }, trailing: { EmptyView() })
            AuRow(lead: tr("li.noAcc"), link: tr("au.signup"), onLink: nav.signUp)
        } footer: { EmptyView() }
    }
}

/// Continue without an account: the builder's name and phone for reports, kept on this phone only.
struct LocalScreen: View {
    let nav: AuthNav
    var title: String? = nil
    @State private var name = AppSettings.shared.builderName
    @State private var phone = Phone.digits(AppSettings.shared.builderPhone)
    @State private var tName = false
    @State private var tPhone = false
    @FocusState private var focus: F?
    var body: some View {
        let nErr = name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("bd.req") : nil
        let pErr = Phone.errorKey(phone, required: true).map { tr($0) }
        let ok = nErr == nil && pErr == nil
        let start = { hideKeyboard(); AppSettings.shared.saveBuilder(name, phone); nav.done() }
        AuPage(title: title ?? tr(AuthFlags.accounts ? "au.skip" : "fr.builderTitle"), step: nil, onBack: nav.back) {
            AuHeading(title: tr("fr.aboutTitle"), lead: tr("fr.aboutBody"))
            AuField(label: tr("su.name"), value: $name, placeholder: tr("fr.namePh"), error: nErr, showError: tName, focus: $focus, me: .name,
                    onSubmit: { focus = .phone }, onBlur: { tName = true })
            AuField(label: tr("su.phone"), value: $phone, kind: .phone, placeholder: "90 123 45 67", error: pErr, showError: tPhone, focus: $focus, me: .phone,
                    submit: .done, onSubmit: { if ok { start() } else { focus = nil } }, onBlur: { tPhone = true })
            HStack(alignment: .top, spacing: 8) { MIcon("device", Au.ink2, 18, 1.8); T(tr(AuthFlags.accounts ? "fr.noAccount" : "au.skipNote"), au(13, 400, Au.ink2, lh: 1.4)) }
        } footer: {
            AuButton(title != nil ? tr("common.save") : tr("fr.start"), enabled: ok, start)
                .accessibilityIdentifier("local.start")
        }
    }
}

/// The bottom sheet that says accounts are not ready yet (look of the prototype's .au-bs).
struct SoonSheet: View {
    let onLocal: () -> Void
    let onClose: () -> Void
    @State private var shown = false
    var body: some View {
        ZStack(alignment: .bottom) {
            Color(argb: 0x6B0B1226).opacity(shown ? 1 : 0).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 12) {
                Capsule().fill(Color(argb: 0xFFDAE1E9)).frame(width: 48, height: 4).padding(.bottom, 10)
                MIcon("user", Au.cobalt, 40, 1.6).frame(width: 68, height: 68)
                    .background(Circle().fill(Au.wash)).overlay(Circle().strokeBorder(Color(argb: 0xFFD6E2F4), lineWidth: 1.5))
                T(tr("nt.soonT"), au(22, 700, Au.ink, lh: 1.2, ls: -0.01), align: .center).padding(.top, 6)
                T(tr("nt.soonB"), au(15, 400, Au.ink2, lh: 1.5), align: .center).padding(.bottom, 8)
                AuButton(tr("au.skip"), onLocal)
                T(tr("common.close"), au(15, 600, Au.cobalt)).padding(12).pressable(0.97, onClose)
            }
            .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 18)
            .frame(maxWidth: .infinity)
            .background(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous).fill(Color.white).ignoresSafeArea(edges: .bottom))
            .boxShadow(Color(argb: 0x2E0B1226), blur: 30, y: -10)
            .offset(y: shown ? 0 : 700)
        }
        .onAppear { withAnimation(.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.28)) { shown = true } }
    }
}
