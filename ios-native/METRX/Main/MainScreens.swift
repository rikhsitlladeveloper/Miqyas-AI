import SwiftUI

/// The floating three-tab bar (prototype .gl-nav): a glass pill, the current tab a white bubble.
struct GlassNav: View {
    let cur: Tab
    let onTab: (Tab) -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.self) { t in
                let on = t == cur
                VStack(spacing: 3) {
                    MIcon(t.icon, on ? G.cobalt2 : G.slate, 22, 2)
                    // a furniture maker's, a tiler's and an electrician's projects are orders
                    T(tr(t == .projects && AppSettings.shared.orderApp ? "fo.tab" : t.label), ui(11, on ? 700 : 600, on ? G.cobalt2 : G.slate), lines: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(on ? G.glass(0.85) : .clear)
                    .boxShadow(on ? G.shade.opacity(0.12) : .clear, blur: 12, y: 4))
                .pressable(0.96) { onTab(t) }
                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier("tab." + "\(t)")
            }
        }
        .padding(6)
        .frame(maxWidth: 300).frame(height: 68)
        .glassBlur(shape, tint: G.sheet(0.45))
        .topHighlight(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.18), blur: 34, y: 14))
        .padding(.horizontal, 20)
        .padding(.top, 4).padding(.bottom, 14)
    }
}

private let PLAN = "M10 10h120v60h50v70H10z M10 80h70 M80 80v60 M130 10v60"
private let PLAN_DIM = "M40 10v-6 M100 10v-6 M40 7h60"
private let ARROW = "M7 17L17 7M9 7h8v8"
private let RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private let CALC = "M8 2.5h8a3 3 0 0 1 3 3v13a3 3 0 0 1-3 3H8a3 3 0 0 1-3-3v-13a3 3 0 0 1 3-3z M8.5 6.5h7M8.5 11h.01M12 11h.01M15.5 11h.01M8.5 14.5h.01M12 14.5h.01M15.5 14.5h.01M8.5 18h.01M12 18h.01M15.5 18h.01"

/// Home: a greeting with a different line on every visit, one big "New project" card and two small cards.
struct HomeScreen: View {
    let app: AppModel
    var body: some View {
        if AppSettings.shared.furniture { FurnitureHome(app: app) } else if AppSettings.shared.tiler { TilerHome(app: app) }
        else if AppSettings.shared.elec { ElecHome(app: app) }
        else if AppSettings.shared.plumb { PlumbHome(app: app) }
        else if AppSettings.shared.win { WinHome(app: app) } else { builder }
    }
    @ViewBuilder private var builder: some View {
        let s = AppSettings.shared
        let first = s.builderName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let lines = tr("gl.lines").split(separator: "|").map(String.init)
        let line = lines.isEmpty ? "" : lines[s.visit % lines.count]
        VStack(spacing: 0) {
            GlassHeader { app.openLaser() }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        T(first.isEmpty ? tr("hm.hi0") : tr("hm.hi", ["n": first]), ui(38, 800, G.ink, lh: 1.1, ls: -0.02)).accessibilityAddTraits(.isHeader)
                        T(line, ui(19, 500, G.slate, lh: 1.35)).frame(maxWidth: 320, alignment: .leading)
                    }
                    .padding(.top, 22).padding(.bottom, 16)
                    BigCard { app.push(.newProject(editId: nil)) }
                    HStack(spacing: 14) {
                        SmallCard(icon: RULER, title: tr("gl.meas"), sub: tr("gl.measS")) { app.push(.measure(calc: false)) }.accessibilityIdentifier("home.measure")
                        SmallCard(icon: CALC, title: tr("gl.calc"), sub: tr("gl.calcS")) { app.push(.measure(calc: true)) }.accessibilityIdentifier("home.calc")
                    }
                }
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24 + NAV_SPACE)
            }
        }
    }
}

private struct BigCard: View {
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        ZStack(alignment: .topTrailing) {
            Canvas { ctx, size in
                var c = ctx; let k = size.width / 190; c.scaleBy(x: k, y: k)
                c.stroke(SVGPath.path(PLAN), with: .color(G.cobalt), lineWidth: 2)
                c.stroke(SVGPath.path(PLAN_DIM), with: .color(G.cobalt), lineWidth: 1.2)
            }
            .frame(width: 190, height: 150).opacity(0.35).offset(x: 14, y: 18)
            VStack(alignment: .leading, spacing: 0) {
                MIcon("plus", .white, 30, 2.4).frame(width: 64, height: 64)
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(G.cobalt))
                    .topHighlight(RoundedRectangle(cornerRadius: 22, style: .continuous), 0.45)
                    .boxShadow(G.cobalt.opacity(0.4), blur: 24, y: 10)
                Spacer(minLength: 28)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        // a furniture maker or a tradesman makes orders, a builder projects
                        T(tr(orderWords() ? "fo.new" : "hm.t.new"), ui(30, 800, G.ink, lh: 1.1, ls: -0.02))
                        T(tr("gl.newS"), ui(15, 400, G.ink2))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PathIcon(ARROW, G.ink, 20, 2.2).frame(width: 44, height: 44).background(Circle().fill(G.glass(0.7)))
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        }
        .clipShape(shape)
        .glassCard(shape, shadowBlur: 40, shadowY: 18, shadowAlpha: 0.16)
        .overlay(alignment: .bottom) { Rectangle().fill(G.hi(0.35)).frame(height: 1).padding(.horizontal, 20) }
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.new")
    }
}

private struct SmallCard: View {
    let icon: String
    let title: String
    let sub: String
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PathIcon(icon, G.cobalt, 22, 2).frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt.opacity(0.12)))
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) { T(title, ui(18, 700)); T(sub, ui(13, 400, G.ink2)) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .glassCard(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
    }
}

/// Big page title of the tab pages (prototype .h1).
struct PageTitle: View {
    let text: String
    var body: some View { T(text, ui(36, 800, G.ink, lh: 1.15, ls: -0.02)).accessibilityAddTraits(.isHeader) }
}

/// App language (prototype SHEETS.lang).
struct LanguageSheet: View {
    let app: AppModel
    var body: some View {
        GlassSheet(tr("se.lang"), onClose: { app.sheet = nil }) {
            ForEach(Lang.allCases) { l in
                Opt(title: l.longName, on: AppSettings.shared.lang == l) { AppSettings.shared.setLanguage(l); app.sheet = nil }
            }
        }
    }
}

/// A choice in a list (prototype .optlist .opt): white, blue when chosen, with a check.
struct Opt: View {
    let title: String
    let on: Bool
    var sub: String? = nil
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                T(title, ui(16, on ? 700 : 500, on ? G.cobalt2 : G.ink))
                if let sub { T(sub, ui(13, 400, G.ink2)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if on { MIcon("check", G.cobalt2, 20, 2.4) }
        }
        .padding(.horizontal, 16).padding(.vertical, 8).frame(minHeight: 56)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.6)))
        .overlay(shape.strokeBorder(on ? G.cobalt.opacity(0.5) : G.rim, lineWidth: 1))
        .pressable(0.99, action)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
