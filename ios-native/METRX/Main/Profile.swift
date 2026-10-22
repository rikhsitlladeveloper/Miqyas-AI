import SwiftUI

/*
 * Profile (prototype profile.js "status first, short groups" with the glass Pro card) and its "More settings" page, the
 * subscription page and the settings sheets. Rows that need later parts (PDF parts, currency, door and window sizes,
 * hints) arrive with them. Dark mode is this app's own addition (founder's decision).
 */

private let GOLD = Color(argb: 0xFFF5C451)
private let MOON = "M20 14.5A8.5 8.5 0 1 1 9.5 4a7 7 0 0 0 10.5 10.5z"

struct ProfileScreen: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        let name = s.builderName
        let initials = name.split(whereSeparator: \.isWhitespace).prefix(2).map { String($0.prefix(1)) }.joined().uppercased()
        VStack(spacing: 0) {
            HStack {
                PageTitle(text: tr("tab.profile")).padding(.leading, 16).padding(.top, 6).frame(maxWidth: .infinity, alignment: .leading)
                LaserButton { app.sheet = .device }
            }
            .padding(.leading, 4).padding(.trailing, 16).padding(.vertical, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // who appears on every quote
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            T(initials.isEmpty ? "?" : initials, ui(20, 600, .white)).frame(width: 56, height: 56).background(Circle().fill(G.avatar))
                            VStack(alignment: .leading, spacing: 2) {
                                T(name.isEmpty ? tr("prof.noName") : name, ui(17, 600, G.ink, lh: 1.25), lines: 1)
                                T(s.builderPhone.isEmpty ? tr("se.notSet") : Phone.format(s.builderPhone), ui(13.5, 400, G.ink2, lh: 1.25))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            MIcon("edit", G.ink, 18, 2).frame(width: 44, height: 44).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
                        }
                        .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)
                        .pressable(0.99) { app.editMe = true }
                        .accessibilityIdentifier("profile.me")
                        HStack(spacing: 7) { MIcon("doc", G.ink2, 16, 2); T(tr((s.furniture || s.tiler || s.elec) && !s.advanced ? "pf.onDesign" : "pf.onQuote"), ui(12.5, 400, G.ink2, lh: 1.4)) }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 10)
                            .overlay(alignment: .top) { Rectangle().fill(G.rim).frame(height: 0.67) }
                    }
                    .glassCard(RoundedRectangle(cornerRadius: 18, style: .continuous), fill: G.glass(0.55))
                    .padding(.horizontal, 16)
                    ProCard { app.push(.subscription) }
                    // furniture makers: how the workshop builds and prices, and its boards and hardware (furniture plan section 6)
                    if s.furniture {
                        Group1(text: tr("wk.group"))
                        Card {
                            // off: the app is just the 3D design; on: prices, order stages, workshop rules, cutting lists
                            SwitchRow(icon: "sliders", title: tr("adv.title"), on: s.advanced) { s.setAdvancedOn(!s.advanced); if !s.advanced { app.dropAdvanced() }; app.say(s.advanced ? "adv.on" : "adv.off") }
                                .accessibilityIdentifier("pf.advanced")
                            if s.advanced {
                                Row1(icon: "board", title: tr("wk.title"), value: nil, sub: tr("wk.titleS")) { app.push(.workshop) }.accessibilityIdentifier("pf.workshop")
                                Row1(icon: "layers", title: tr("wk.mats"), value: nil, sub: tr("wk.matsS", ["m": s.mats.count, "h": s.hws.count])) { app.push(.materials) }.accessibilityIdentifier("pf.mats")
                            }
                        }
                        T(tr("adv.sub"), ui(12.5, 400, G.ink2, lh: 1.4)).padding(.horizontal, 28).padding(.top, 8)
                    }
                    // tilers: the same switch; on, the quantities, prices, estimate and quotes (off: only the tiles in 3D)
                    if s.tiler {
                        Group1(text: tr("tl.gWork"))
                        Card {
                            SwitchRow(icon: "sliders", title: tr("adv.title"), on: s.advanced) { s.setAdvancedOn(!s.advanced); if !s.advanced { app.dropAdvanced() }; app.say(s.advanced ? "adv.on" : "adv.off") }
                                .accessibilityIdentifier("pf.advanced")
                            if s.advanced {
                                Row1(icon: "coin", title: tr("tl.prices"), value: nil, sub: tr("tl.pricesS")) { app.sheet = .tPrices(pid: nil) }.accessibilityIdentifier("pf.tPrices")
                            }
                        }
                        T(tr("tl.advSub"), ui(12.5, 400, G.ink2, lh: 1.4)).padding(.horizontal, 28).padding(.top, 8)
                    }
                    // electricians: the same switch; on, the cable, breakers, prices, estimate and quotes (off: only the devices and
                    // routes in 3D)
                    if s.elec {
                        Group1(text: tr("el.gWork"))
                        Card {
                            SwitchRow(icon: "sliders", title: tr("adv.title"), on: s.advanced) { s.setAdvancedOn(!s.advanced); if !s.advanced { app.dropAdvanced() }; app.say(s.advanced ? "adv.on" : "adv.off") }
                                .accessibilityIdentifier("pf.advanced")
                            if s.advanced {
                                Row1(icon: "coin", title: tr("tl.prices"), value: nil, sub: tr("el.pricesS")) { app.sheet = .ePrices(pid: nil) }.accessibilityIdentifier("pf.ePrices")
                            }
                        }
                        T(tr("el.advSub"), ui(12.5, 400, G.ink2, lh: 1.4)).padding(.horizontal, 28).padding(.top, 8)
                    }
                    Group1(text: tr("pf.gReport"))
                    Card {
                        Row1(icon: "sliders", title: tr("ind.row"), value: tr(s.furniture ? "ind.furn" : isTrade(s.industry) ? "ind.\(s.industry ?? "")" : "ind.build")) { app.sheet = .industry }
                        Row1(icon: "globe", title: tr("se.lang"), value: s.lang.longName) { app.sheet = .language }
                        Row1(icon: "doc", title: tr("se.reportLang"), value: s.reportLang.longName) { app.sheet = .reportLang }
                        // the simple furniture app shares a design: no estimate in it, and no prices to have a currency
                        let design = (s.furniture || s.tiler || s.elec) && !s.advanced
                        Row1(icon: "layers", title: tr("se.pdf"), value: "\(pdfCount(s.pdf, design))/\(pdfKeys(design).count)") { app.sheet = .pdfParts }
                        if !design { Row1(icon: "coin", title: tr("np.currency"), value: s.currency) { app.sheet = .currency } }
                    }
                    // dark mode: this app's own (the prototype has only the light look)
                    Card { SwitchRow(icon: "moon", title: tr("nt.dark"), on: s.dark) { s.setDarkMode(!s.dark) } }.padding(.top, 10)
                    Group1(text: tr("pf.gMeasure"))
                    Card {
                        Row1(icon: "door", title: tr("se.defaults"), value: Geo.fmtLen(s.doorW, s.unit, s.lang == .en) + " × " + Geo.fmtLen(s.doorH, s.unit, s.lang == .en)) { app.sheet = .defaults }
                        SwitchRow(icon: "ruler", title: tr("se.snap"), on: s.angleSnap) { s.setSnap(!s.angleSnap) }
                    }
                    Group1(text: tr("ac.group"))
                    Card { Row1(icon: "user", title: tr("ac.signIn"), value: nil, sub: tr("ac.noneB")) { signIn() } }
                    HStack(spacing: 10) {
                        MIcon("sliders", G.ink, 18, 2); T(tr("pf.more"), ui(15, 600)).frame(maxWidth: .infinity, alignment: .leading); MIcon("chev", G.ink2, 18, 2)
                    }
                    .padding(.horizontal, 14).frame(height: 52)
                    .glassCard(RoundedRectangle(cornerRadius: 14, style: .continuous), fill: G.glass(0.55))
                    .pressable(0.99) { app.push(.settingsMore) }
                    .padding(.horizontal, 16).padding(.top, 14)
                    HStack(alignment: .top, spacing: 8) { MIcon("device", G.ink2, 16, 2); T(tr("prof.local"), ui(12.5, 400, G.ink2, lh: 1.4)) }
                        .padding(.horizontal, 18).padding(.top, 12)
                }
                .padding(.top, 2).padding(.bottom, 20 + NAV_SPACE)
            }
        }
    }

    private func signIn() { app.authFromProfile = true; app.auth = [.welcome] }
}

/// METRX Pro: active during the pilot, everything open (glass .gl-pro: deep violet, a gold rim and a sheen).
private struct ProCard: View {
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MIcon("card", GOLD, 22, 2).frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(GOLD.opacity(0.18)))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        T("METRX Pro", ui(19, 800, .white))
                        T(tr("pf.subOn"), ui(12, 700, Color(argb: 0xFF7BE3A9))).padding(.horizontal, 9).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(argb: 0x2E3DD68C)))
                    }
                    T(tr("gl.proOn"), ui(13, 400, Color(argb: 0xFFD4D7F7)))
                }
            }
            HStack(spacing: 10) {
                T(tr("sub.pilot"), ui(13, 400, Color(argb: 0xFFD4D7F7), lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
                T(tr("gl.manage"), ui(14, 700, GOLD)); MIcon("chev", GOLD, 14, 2.4)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.14)).frame(height: 0.67) }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                shape.fill(LinearGradient(colors: [Color(argb: 0xFF171B45), Color(argb: 0xFF2B2A78), Color(argb: 0xFF52309A)], startPoint: .topLeading, endPoint: .bottomTrailing))
                // the sheen: a soft light band across the card
                GeometryReader { g in
                    Path { p in
                        let w = g.size.width, h = g.size.height
                        p.move(to: CGPoint(x: w * 0.1, y: 0)); p.addLine(to: CGPoint(x: w * 0.45, y: 0)); p.addLine(to: CGPoint(x: w * 0.25, y: h)); p.addLine(to: CGPoint(x: -w * 0.1, y: h)); p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.1), .white.opacity(0)], startPoint: .leading, endPoint: .trailing))
                }
                .clipShape(shape)
            }
        }
        .overlay(shape.strokeBorder(GOLD.opacity(0.6), lineWidth: 0.67))
        .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(GOLD.opacity(0.12)).padding(-4))
        .boxShadow(Color(argb: 0x613C288C), blur: 40, y: 18)
        .pressable(0.99, action)
        .padding(.horizontal, 20).padding(.top, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct Group1: View {
    let text: String
    var body: some View { T(text, ui(13, 500, G.ink2)).padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8) }
}

private struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            .padding(.horizontal, 20)
    }
}

private struct IconTile: View {
    let icon: String
    var body: some View {
        Group { if icon == "moon" { PathIcon(MOON, G.cobalt, 20, 2) } else { MIcon(icon, G.cobalt, 20, 2) } }
            .frame(width: 36, height: 36)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.12)))
    }
}

/// A settings row (prototype .listrow): icon tile, title, its value, a chevron.
private struct Row1: View {
    let icon: String
    let title: String
    let value: String?
    var sub: String? = nil
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            IconTile(icon: icon)
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15.5, 500, G.ink, lh: 1.4))
                if let sub { T(sub, ui(13, 400, G.ink2, lh: 1.35)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value { T(value, ui(14, 400, G.ink2), lines: 1) }
            MIcon("chev", G.ink2, 18, 2)
        }
        .padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 8).frame(minHeight: 56)
        .pressable(0.99, action)
    }
}

private struct SwitchRow: View {
    let icon: String
    let title: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            IconTile(icon: icon)
            T(title, ui(15.5, 500, G.ink, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
            GSwitch(on: on)
        }
        .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 8).frame(minHeight: 56)
        .pressable(0.99, action)
        .accessibilityValue(on ? "1" : "0")
        .accessibilityAddTraits(.isToggle)
    }
}

/// A page with a back button and a title (the bar of prototype pages that are not tabs).
private struct SubPage<Content: View>: View {
    let app: AppModel
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                GlassIconButton("back", tr("nt.back")) { app.pop() }
                T(title, ui(17, 700)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).frame(height: 64)
            ScrollView { VStack(alignment: .leading, spacing: 12) { content }.padding(.top, 8).padding(.bottom, 24) }
        }
    }
}

/// Profile → More settings (prototype PAGES.settingsMore).
struct SettingsMoreScreen: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        SubPage(app: app, title: tr("pf.more")) {
            Card {
                Row1(icon: "ruler", title: tr("se.units"), value: tr(s.unitCm ? "un.cm" : "un.m")) { app.sheet = .units }
                Row1(icon: "room", title: tr("se.label"), value: tr("se.label." + s.roomLabel)) { app.sheet = .roomLabel }
                Row1(icon: "info", title: tr("se.hintsReset"), value: nil) { s.resetHints(); RoomOps.shared.tipSeen = false; app.say("se.hintsDone") }
            }
            Card {
                Row1(icon: "bt", title: tr("se.device"), value: tr(s.laser == .connected ? "pf.btOn" : "pf.btDisc")) { app.sheet = .device }
                Row1(icon: "card", title: tr("se.sub"), value: tr("se.active")) { app.push(.subscription) }
            }
            Card { Row1(icon: "info", title: tr("se.about"), value: nil) { app.sheet = .about } }
        }
    }
}

/// METRX Pro (prototype PAGES.sub): active in the pilot; what keeps working and what would need a subscription.
struct SubscriptionScreen: View {
    let app: AppModel
    var body: some View {
        SubPage(app: app, title: tr("se.sub")) {
            Card {
                HStack { T(tr("dv.status"), ui(14, 400, G.ink2)).frame(maxWidth: .infinity, alignment: .leading); T(tr("se.active"), ui(15, 700)) }.padding(16)
            }
            T(tr("sub.pilot"), ui(14, 400, G.ink2, lh: 1.45)).padding(.horizontal, 24)
            Group1(text: tr("sub.works"))
            Card { li(["sub.w1", "sub.w2", "sub.w4"], "check", G.green) }
            Group1(text: tr("sub.locked"))
            Card { li(["sub.l1", "sub.l2", "sub.l3"], "lock", G.ink2) }
        }
    }
    @ViewBuilder private func li(_ keys: [String], _ icon: String, _ tint: Color) -> some View {
        ForEach(Array(keys.enumerated()), id: \.offset) { i, k in
            if i > 0 { Hairline() }
            HStack(spacing: 12) { MIcon(icon, tint, 20, 2.2); T(tr(k), ui(15, 500)) }
                .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        }
    }
}

/* ---------------- sheets ---------------- */

struct ProfileSheet: View {
    let app: AppModel
    let sheet: Sheet
    var body: some View {
        let s = AppSettings.shared
        switch sheet {
        case .reportLang:
            GlassSheet(tr("se.reportLang"), onClose: { app.sheet = nil }) {
                ForEach(Lang.allCases) { l in Opt(title: l.longName, on: s.reportLang == l) { s.setReportLangDefault(l); app.sheet = nil } }
            }
        case .units:
            GlassSheet(tr("se.units"), onClose: { app.sheet = nil }) {
                Opt(title: tr("un.m"), on: !s.unitCm, sub: tr("un.mEx")) { s.setUnit(cm: false) }
                Opt(title: tr("un.cm"), on: s.unitCm, sub: tr("un.cmEx")) { s.setUnit(cm: true) }
                T(tr("un.note"), ui(13, 400, G.ink2, lh: 1.45))
            }
        case .roomLabel:
            GlassSheet(tr("se.label"), onClose: { app.sheet = nil }) {
                ForEach(["both", "name", "area", "none"], id: \.self) { k in Opt(title: tr("se.label." + k), on: s.roomLabel == k) { s.setRoomLabel(k); app.sheet = nil } }
            }
        case .about:
            GlassSheet(tr("se.about"), onClose: { app.sheet = nil }) {
                T(tr("se.aboutBody"), ui(15, 400, G.ink, lh: 1.45))
                let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                T("METRX " + v, ui(13, 400, G.ink2))
            } footer: {
                GBtn(tr("common.close"), kind: .secondary) { app.sheet = nil }
            }
        case .pdfParts: PdfPartsSheet(app: app)
        case .defaults: DefaultsSheet(app: app)
        default:
            EmptyView()
        }
    }
}

/// The PDF's parts the Profile offers; a simple furniture app's design has no estimate.
func pdfKeys(_ design: Bool) -> [String] { design ? ["plan", "dims", "views", "sign"] : ["plan", "dims", "views", "estimate", "sign"] }
func pdfCount(_ p: PdfParts, _ design: Bool = false) -> Int {
    [("plan", p.plan), ("dims", p.dims), ("views", p.views), ("estimate", p.estimate), ("sign", p.sign)].filter { pdfKeys(design).contains($0.0) && $0.1 }.count
}

/// What the PDF shows (prototype SHEETS.pdf).
private struct PdfPartsSheet: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared, p = s.pdf
        let design = (s.furniture || s.tiler || s.elec) && !s.advanced
        GlassSheet(tr("se.pdf"), onClose: { app.sheet = nil }) {
            ForEach([("plan", p.plan), ("dims", p.dims), ("views", p.views), ("estimate", p.estimate), ("sign", p.sign)].filter { pdfKeys(design).contains($0.0) }, id: \.0) { k, on in
                HStack(spacing: 12) { MIcon(on ? "boxok" : "box", on ? G.cobalt : G.ink2, 24, 2); T(tr("pdf." + k), ui(16, 500)).frame(maxWidth: .infinity, alignment: .leading) }
                    .padding(.horizontal, 4).frame(minHeight: 52)
                    .pressable(0.98) {
                        var n = p
                        switch k { case "plan": n.plan = !on; case "dims": n.dims = !on; case "views": n.views = !on; case "estimate": n.estimate = !on; default: n.sign = !on }
                        s.setPdfParts(n)
                    }
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("pdf." + k)
            }
            T(tr(design ? "se.pdfBodyD" : "se.pdfBody"), ui(13, 400, G.ink2, lh: 1.45))
        }
    }
}

private enum DF: Hashable { case f(Int) }

/// Default door and window sizes (prototype SHEETS.defaults): typed with the length rules of the room editor.
private struct DefaultsSheet: View {
    let app: AppModel
    @State private var f: [String] = []
    @State private var tried = false
    @FocusState private var focus: DF?
    private func bind(_ i: Int) -> Binding<String> { Binding(get: { i < f.count ? f[i] : "" }, set: { if i < f.count { f[i] = $0 } }) }
    var body: some View {
        let s = AppSettings.shared, u = s.unit, en = s.lang == .en, m = unitName()
        let maxes = [100_000, 20_000, 100_000, 20_000, 20_000]
        // a window can sit on the floor: its sill (the last) may be 0
        let r = (0..<5).map { Geo.lenErr($0 < f.count ? f[$0] : "", maxes[$0], u, en, zeroOk: $0 == 4) }
        GlassSheet(tr("se.defaults"), onClose: { app.sheet = nil }) {
            T(tr("se.defaultsBody"), ui(14, 400, G.ink2, lh: 1.45))
            T(tr("op.door"), ui(13, 700, G.ink2))
            HStack(alignment: .top, spacing: 10) {
                NumField(label: tr("op.width"), value: bind(0), suffix: m, error: errText(r[0]), showError: tried, focus: $focus, me: .f(0), id: "df.dw")
                NumField(label: tr("op.height"), value: bind(1), suffix: m, error: errText(r[1]), showError: tried, focus: $focus, me: .f(1))
            }
            T(tr("op.window"), ui(13, 700, G.ink2))
            HStack(alignment: .top, spacing: 10) {
                NumField(label: tr("op.width"), value: bind(2), suffix: m, error: errText(r[2]), showError: tried, focus: $focus, me: .f(2))
                NumField(label: tr("op.height"), value: bind(3), suffix: m, error: errText(r[3]), showError: tried, focus: $focus, me: .f(3))
            }
            NumField(label: tr("op.sill"), value: bind(4), suffix: m, error: errText(r[4]), showError: tried, focus: $focus, me: .f(4))
        } footer: {
            GBtn(tr("common.save")) {
                let v = r.compactMap(\.value)
                guard v.count == 5 else { tried = true; return }
                s.setDefaults(Int(v[0]), Int(v[1]), Int(v[2]), Int(v[3]), Int(v[4])); app.sheet = nil; app.say("se.saved")
            }
            .accessibilityIdentifier("df.save")
        }
        .onAppear {
            if f.isEmpty { f = [s.doorW, s.doorH, s.winW, s.winH, s.winSill].map { Geo.fmtField($0, u, en) } }
        }
    }
}
