import SwiftUI
import UIKit

/*
 * The room editor v2's shared pieces (room-editor mockup v2, approved 28 Oct 2026): the icon row you drag from, the
 * A · B · C · D wall chips, the floating style window with its size steps, the number entry, the hand animation, the
 * "N ta belgi" list and the yellow "Katta devor — to‘g‘rimi?" note. Used by the openings step and the editor.
 */

/// "Katta devor — to‘g‘rimi?" under a wall above 30 m; it never stops "Keyingi".
struct ReBigNote: View {
    let mm: Int
    var body: some View {
        let m = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), Double(mm) / 1000)
        HStack(alignment: .top, spacing: 10) {
            MIcon("alert", G.amberInk, 19, 2)
            (Text(tr("re.big") + " ").font(ui(12.5, 800).font).foregroundColor(G.amberInk)
             + Text(tr("re.bigD", ["v": fmtMm(Double(mm)), "m": AppSettings.shared.lang == .en ? m : m.replacingOccurrences(of: ".", with: ",")]))
                .font(ui(12.5, 400).font).foregroundColor(G.ink))
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.amberWash))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("re.bigNote")
    }
}

/// A kind's icon on its colour (the cards' badge).
struct ReBadge: View {
    let kind: String
    var size: CGFloat = 36
    var body: some View {
        PathIcon(reKind(kind).icon, .white, size * 0.56, 2)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).fill(RD.kind(kind)))
    }
}

/* ---------------- the icon row ---------------- */

/// One icon of the row: tap it (then a wall), or hold and drag it up onto a wall.
struct ReTile: View {
    let kind: String
    let on: Bool
    let tap: () -> Void
    let drag: (CGPoint) -> Void
    let drop: (CGPoint?) -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let g = LongPressGesture(minimumDuration: 0.12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("re")))
            .onChanged { v in if case .second(true, let d?) = v { drag(d.location) } }
            .onEnded { v in
                if case .second(true, let d?) = v, abs(d.translation.height) > 18 || abs(d.translation.width) > 18 { drop(d.location) } else { drop(nil) }
            }
        VStack(spacing: 4) {
            PathIcon(reKind(kind).icon, RD.kind(kind), 24, 2)
            T(reKindName(kind), ui(10.5, 700, G.ink, lh: 1.05), align: .center, lines: 2).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 2)
        .frame(width: 74, height: 66)
        .background(shape.fill(on ? G.cobalt.opacity(0.12) : G.glass(0.78)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .contentShape(shape)
        .onTapGesture { tap() }
        .simultaneousGesture(g)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reKindName(kind))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("re.tile." + kind)
    }
}

/// The row of icons in the trade's order, the groups apart; the first one's frame kept for the hand animation.
struct ReTileRow: View {
    let st: ReState
    let groups: [[String]]
    let tap: (String) -> Void
    let drag: (String, CGPoint) -> Void
    let drop: (String, CGPoint?) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(groups.enumerated()), id: \.offset) { gi, gr in
                    if gi > 0 { Rectangle().fill(G.ink.opacity(0.1)).frame(width: 1, height: 44).padding(.horizontal, 3) }
                    ForEach(Array(gr.enumerated()), id: \.element) { ti, k in
                        ReTile(kind: k, on: st.arm == k, tap: { tap(k) }, drag: { drag(k, $0) }, drop: { drop(k, $0) })
                            .background(GeometryReader { geo in
                                Color.clear
                                    .onAppear { if gi == 0 && ti == 0 { st.tile0 = geo.frame(in: .named("re")) } }
                                    .onChange(of: geo.frame(in: .named("re"))) { _, f in if gi == 0 && ti == 0 { st.tile0 = f } }
                            })
                    }
                }
            }
            .padding(.leading, 8).padding(.trailing, 28).padding(.vertical, 4)
        }
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.88), .init(color: .black.opacity(0.35), location: 1)],
                             startPoint: .leading, endPoint: .trailing))
        .accessibilityIdentifier("re.tiles")
    }
}

/// The icon under the finger while it is dragged, with where it would go.
struct ReDragChip: View {
    let kind: String
    let line: String
    let ok: Bool
    var body: some View {
        HStack(spacing: 8) {
            PathIcon(reKind(kind).icon, RD.kind(kind), 22, 2)
            VStack(alignment: .leading, spacing: 1) {
                T(reKindName(kind), ui(12, 800), lines: 1)
                T(line, ui(10.5, 700, G.ink2), lines: 2)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.sheet(0.97)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ok ? G.green : G.cobalt, lineWidth: ok ? 2.5 : 2))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        .fixedSize()
        .allowsHitTesting(false)
    }
}

/* ---------------- the wall chips ---------------- */

/// "Devor  A B C D", each with its length: the selected one blue, the drop's green, all glowing while an icon is armed.
struct ReWallChips: View {
    let g: ReRoomGeo
    let sel: String?
    let hl: String?
    let armed: Bool
    let tap: (String) -> Void
    var body: some View {
        HStack(spacing: 5) {
            T(tr("re.wallW"), ui(11.5, 700, G.ink2), lines: 1).padding(.horizontal, 2)
            ForEach(g.walls, id: \.id) { w in
                let on = w.id == sel, h = w.id == hl
                let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)
                VStack(spacing: 1) {
                    T(w.id, ui(13, 800, on || h ? .white : armed ? G.cobalt2 : G.ink), lines: 1)
                    T(reLen(w.len), num(9.5, 700, on || h ? .white.opacity(0.85) : G.ink3), lines: 1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(shape.fill(h ? G.green : on ? G.cobalt : G.glass(0.85)))
                .overlay(shape.strokeBorder(armed && !on && !h ? G.cobalt : G.rim, lineWidth: armed && !on && !h ? 2 : 1))
                .pressable(0.96) { tap(w.id) }
                .accessibilityIdentifier("re.wchip." + w.id)
            }
        }
    }
}

/* ---------------- the style window and its size steps ---------------- */

/// The floating window over the dimmed plan (mockup renderPk): the style cards drawn as front views, the last style first
/// with "Yana shu"; then one size per step with its big drawing, chips, the field, Lazer and Ovoz, and Orqaga /
/// Standart / Keyingi (Qo‘yish on the last). A tap outside cancels only while the style is chosen.
struct RePickWindow: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    /// The keyboard is up: the big drawing gets smaller and the buttons stay in sight.
    @State private var kb = false
    var body: some View {
        Group {
            if let p = st.pk, let r = h.room() { window(p, reGeo(r)) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in kb = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in kb = false }
    }

    @ViewBuilder private func window(_ p: RePk, _ g: ReRoomGeo) -> some View {
        GeometryReader { geo in
                ZStack {
                    G.scrim.ignoresSafeArea()
                        .onTapGesture { if p.phase == "style" { st.pkCancel() } else { Haptic.tick() } }
                    ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if p.phase == "style" { styleBody(p, g) } else { sizeBody(p, g) }
                        }
                        .padding(14)
                    }
                    .onChange(of: kb) { _, up in if up { withAnimation { proxy.scrollTo("pkButtons", anchor: .bottom) } } }
                    .onChange(of: p.step) { _, _ in if kb { proxy.scrollTo("pkButtons", anchor: .bottom) } }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(maxHeight: max(200, geo.size.height - 40))
                    .fixedSize(horizontal: false, vertical: true)
                    .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(G.solid))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 14)
                    .padding(.horizontal, 12)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .transition(.opacity)
    }

    private func head(_ p: RePk, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 10) {
            ReBadge(kind: p.kind)
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(16, 800, lh: 1.2), lines: 2)
                T(sub, ui(12, 500, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("x", G.ink2, 17, 2).frame(width: 38, height: 38)
                .background(Circle().fill(G.ink.opacity(0.06)))
                .pressable(0.95, label: tr("common.cancel")) { st.pkCancel() }
                .accessibilityIdentifier("re.pkX")
        }
    }

    @ViewBuilder private func styleBody(_ p: RePk, _ g: ReRoomGeo) -> some View {
        let last = p.mode == "new" ? st.last[p.kind] : nil
        let list = reStylesLastFirst(p.kind, last?.style)
        head(p, tr("re.styT", ["n": reKindName(p.kind), "w": p.wall]), tr(p.mode == "new" ? "re.styS" : "re.styR"))
        if let l = last {
            VStack(spacing: 1) {
                HStack(spacing: 8) {
                    MIcon("copy", .white, 18, 2.2)
                    T(tr("re.again", ["v": reAgainLine(p.kind, l.style, l.v)]), ui(15.5, 800, .white), lines: 1).minimumScaleFactor(0.8)
                }
                T(tr("re.againS", ["n": reStyleName(p.kind, l.style)]), ui(11.5, 600, .white.opacity(0.85)), lines: 1)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(G.cobalt))
            .pressable(0.98) { st.pkAgain(app, h) }
            .accessibilityIdentifier("re.again")
            T(tr("re.orOther"), ui(11.5, 700, G.ink3), align: .center).frame(maxWidth: .infinity)
        }
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(list, id: \.id) { s in
                let isLast = last?.style == s.id, now = p.mode != "new" && p.orig?.style == s.id
                let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
                VStack(alignment: .leading, spacing: 2) {
                    ReStyleThumb(kind: p.kind, style: s.id, roomH: g.H)
                        .frame(height: 78)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(RD.elev))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    T(reStyleName(p.kind, s.id), ui(13, 800, lh: 1.2), lines: 2).padding(.horizontal, 4).padding(.top, 4)
                    T(reCardLine(p.kind, s, g.H), num(11, 500, G.ink2), lines: 2).padding(.horizontal, 4).padding(.bottom, 2)
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(shape.fill(G.glass(0.85)))
                .overlay(shape.strokeBorder(isLast || now ? G.cobalt : G.rim, lineWidth: isLast || now ? 2.5 : 1))
                .overlay(alignment: .topLeading) {
                    if isLast || now {
                        T(tr(isLast ? "re.tagLast" : "re.tagNow"), ui(10.5, 800, .white)).padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Capsule().fill(G.cobalt)).padding(10)
                    }
                }
                .pressable(0.98) { st.pkStyle(s.id, h) }
                .accessibilityIdentifier("re.sty." + s.id)
            }
        }
        GBtn(tr("common.cancel"), kind: .secondary, height: 50, fontSize: 14) { st.pkCancel() }.accessibilityIdentifier("re.pkCancel")
    }

    @ViewBuilder private func sizeBody(_ p: RePk, _ g: ReRoomGeo) -> some View {
        let steps = reSteps(p.kind, p.style)
        let i = min(p.step, steps.count - 1)
        let f = steps[i]
        let it = st.pkItem(h) ?? p.it
        let err = st.pkErr(h)
        let lastStep = i == steps.count - 1
        let ch = reChips(p.kind, p.style, f, g.H)
        let cur = p.v[f]
        head(p, reKindName(p.kind) + " · " + reStyleName(p.kind, p.style), tr("re.stepOf", ["w": p.wall, "i": i + 1, "n": steps.count]))
        ReSizeArt(it: it, field: f, roomH: g.H, bad: err != nil, fmt: reLen)
            .frame(height: kb ? 100 : 176)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(RD.elev))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        HStack(spacing: 5) {
            ForEach(Array(steps.enumerated()), id: \.offset) { j, x in
                if j > 0 { T("→", ui(12, 700, G.ink3)) }
                T(tr("re.f." + reFieldKey(p.kind, p.style, x)), ui(12, j == i ? 800 : 700, j == i ? G.cobalt2 : j < i ? G.ink2 : G.ink3), lines: 1)
            }
        }
        .frame(maxWidth: .infinity)
        let chips = AnyView(ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ch.chips, id: \.self) { x in
                    let on = cur == x
                    HStack(spacing: 3) {
                        T(reLen(x), num(13, 800, on ? .white : G.ink))
                        if x == ch.std { T(tr("re.std"), ui(10, 700, on ? .white.opacity(0.8) : G.ink3)) }
                    }
                    .padding(.horizontal, 12).frame(minHeight: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? G.cobalt : G.glass(0.85)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                    .pressable(0.96) { st.pkSet(x); Haptic.tick() }
                    .accessibilityIdentifier("re.chip.\(x)")
                }
            }
            .padding(2)
        })
        RshSizeField(app: app, d: st, key: "pk\(p.kind)\(p.style)\(f)\(i)", label: tr("re.f." + reFieldKey(p.kind, p.style, f)),
                     help: tr("re.fd." + reFieldKey(p.kind, p.style, f), ["c": reLen(g.H)]) + (p.style == "balcony" ? " · " + tr("re.sill", ["v": reLen(it.h - it.wh)]) : ""),
                     text: p.input, fresh: p.fresh, hint: cur ?? ch.std ?? 0, issue: err,
                     live: { (st.pk?.input ?? "", st.pk?.fresh ?? false) },
                     onText: { st.pkText($0) },
                     onNext: { st.pkNext(app, h) },
                     onValue: { mm, words in
                         let before = st.pk?.input ?? ""
                         st.pkSet(mm)
                         if let w = words { st.heard = (before: before, words: w) } else { st.heard = nil }
                         st.flash += 1; Haptic.confirm()
                     },
                     onUnVoice: { if let hd = st.heard { st.pkText(hd.before); st.heard = nil } },
                     chips: chips)
        HStack(spacing: 6) {
            GBtn(tr("re.back"), kind: .secondary, icon: "back", height: 50, fontSize: 13.5, fill: false) { st.pkBack(h) }.accessibilityIdentifier("re.pkBack")
            GBtn(tr("re.stdB"), kind: .secondary, height: 50, fontSize: 13.5, fill: false) { st.pkStd(app, h) }.accessibilityIdentifier("re.pkStd")
            GBtn(tr(lastStep ? (p.mode == "new" ? "re.place" : "common.save") : "common.next"), height: 50, fontSize: 15) { st.pkNext(app, h) }
                .accessibilityIdentifier("rsh.next")
        }
        .id("pkButtons")
    }
}

/// A kind's styles with the last one used first (mockup renderPk).
func reStylesLastFirst(_ kind: String, _ lastStyle: String?) -> [ReStyle] {
    let l = reStyles(kind)
    guard let s = lastStyle else { return l }
    return l.filter { $0.id == s } + l.filter { $0.id != s }
}

/// "Yana shu · 800 × 2 100": the last sizes in a line.
func reAgainLine(_ k: String, _ style: String, _ v: ReVals) -> String {
    if (k == "door" || k == "window") && style == "balcony" { return tr("re.balLine", ["d": reLen(v["dw"] ?? 0), "w": reLen(v["ww"] ?? 0)]) }
    if k == "door" || k == "window" { return reLen(v["w"] ?? 0) + " × " + reLen(v["h"] ?? 0) }
    return (v["pw"].map { tr("re.pwV", ["v": reLen($0)]) + " · " } ?? "") + tr("re.phV", ["v": reLen(v["ph"] ?? 0)])
}

/// A size step's name in the strings (re.f.<key>, re.fd.<key>): a door's height differs from a window's, a balcony's
/// parts are their own, a radiator's width from an AC's.
func reFieldKey(_ kind: String, _ style: String, _ f: String) -> String {
    switch f {
    case "w": return kind == "door" ? "dW" : "wW"
    case "h": return style == "balcony" ? "bH" : kind == "door" ? "dH" : style == "pano" ? "pH" : "wH"
    case "pw": return kind == "rad" ? "radW" : "acW"
    case "ph": return "ph"
    default: return f
    }
}

/* ---------------- a number outside the style window ---------------- */

/// A size typed for a distance pill, a wall's length, a thickness or the height: the app's size field with Lazer and
/// Ovoz, the range, and Tayyor.
struct ReKpOverlay: View {
    let app: AppModel
    let st: ReState
    var body: some View {
        if let k = st.kp {
            let v = rshParse(st.kpText, AppSettings.shared.unit, zeroOk: k.lo == 0)
            let bad: String? = {
                guard !st.kpText.isEmpty else { return nil }
                guard let v, v >= k.lo, v <= k.hi else { return tr("re.kpRange", ["a": reLen(k.lo), "b": reLen(k.hi), "u": unitWord(AppSettings.shared.unit)]) }
                return nil
            }()
            ZStack(alignment: .bottom) {
                G.scrim.ignoresSafeArea().onTapGesture { st.kp = nil }
                VStack(alignment: .leading, spacing: 10) {
                    RshSizeField(app: app, d: st, key: "kp" + k.title, label: k.title,
                                 help: tr("re.kpRange", ["a": reLen(k.lo), "b": reLen(k.hi), "u": unitWord(AppSettings.shared.unit)]),
                                 text: st.kpText, fresh: false, hint: k.cur, issue: bad,
                                 live: { (st.kpText, false) },
                                 onText: { st.kpText = $0; st.heard = nil },
                                 onNext: { done(k, v, bad) },
                                 onValue: { mm, words in
                                     let before = st.kpText
                                     st.kpText = rshFieldText(mm, AppSettings.shared.unit)
                                     if let w = words { st.heard = (before: before, words: w) } else { st.heard = nil }
                                     st.flash += 1; Haptic.confirm()
                                 },
                                 onUnVoice: { if let hd = st.heard { st.kpText = hd.before; st.heard = nil } })
                    if k.big, let v, reWallBig(v), bad == nil { ReBigNote(mm: v) }
                    HStack(spacing: 8) {
                        GBtn(tr("common.cancel"), kind: .secondary, height: 50, fontSize: 15) { st.kp = nil }
                        GBtn(tr("re.done"), enabled: bad == nil, height: 50, fontSize: 15) { done(k, v, bad) }.accessibilityIdentifier("re.kpOk")
                    }
                }
                .padding(16)
                .background(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous).fill(G.solid).ignoresSafeArea(edges: .bottom))
            }
        }
    }
    private func done(_ k: ReKp, _ v: Int?, _ bad: String?) {
        if st.kpText.isEmpty { st.kp = nil; return }
        guard bad == nil, let v else { Haptic.warn(); return }
        st.kp = nil
        k.apply(v)
    }
}

extension ReState {
    func openKp(_ title: String, cur: Int, lo: Int, hi: Int, big: Bool = false, _ apply: @escaping (Int) -> Void) {
        kpText = ""
        heard = nil
        kp = ReKp(title: title, cur: cur, lo: lo, hi: hi, big: big, apply: apply)
    }
}

/* ---------------- the hand animation ---------------- */

/// Until the first item is placed (and twice more after "?"): a ghost icon goes from the row's first icon up onto wall
/// A, the wall glows, the icon drops in (3,6 s a turn, mockup coach). With "Reduce motion": a still arrow and the wall
/// lit. from, to: the row's icon and wall A's middle; a, b: wall A's ends, in the page's "re" space.
struct ReCoach: View {
    let kind: String
    let from: CGPoint
    let to: CGPoint
    let a: CGPoint
    let b: CGPoint
    let caption: CGPoint
    @Environment(\.accessibilityReduceMotion) private var still
    var body: some View {
        ZStack {
            if still {
                Canvas { ctx, _ in
                    ctx.line(G.green.opacity(0.35), a, b, 12, round: true)
                    let p0 = CGPoint(x: from.x, y: from.y - 34), p1 = CGPoint(x: to.x, y: to.y + 26)
                    let c = CGPoint(x: (p0.x + p1.x) / 2 + 46, y: (p0.y + p1.y) / 2)
                    var p = Path(); p.move(to: p0); p.addQuadCurve(to: p1, control: c)
                    ctx.stroke(p, with: .color(G.cobalt), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [7, 6]))
                    let u = unitV(c, p1), pr = CGPoint(x: -u.y, y: u.x)
                    ctx.poly([p1, p1 - u * 11 + pr * 6, p1 - u * 11 - pr * 6], fill: G.cobalt)
                }
            } else {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.6) / 3.6
                    let fr = ReCoach.frame(t, from, to)
                    Canvas { ctx, _ in if fr.glow > 0 { ctx.line(G.green.opacity(0.6 * fr.glow), a, b, 14, round: true) } }
                    PathIcon(reKind(kind).icon, RD.kind(kind), 28, 2)
                        .frame(width: 54, height: 54)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.solid))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(G.cobalt, lineWidth: 2))
                        .scaleEffect(fr.gs)
                        .opacity(fr.go)
                        .position(fr.gp)
                    PathIcon(SD_HAND_IC, G.ink, 42, 1.5)
                        .opacity(fr.ho)
                        .position(CGPoint(x: fr.hp.x + 9, y: fr.hp.y + 15))
                }
            }
            HStack(spacing: 6) {
                PathIcon(SD_HAND_IC, G.cobalt, 16, 2)
                T(tr("re.coach"), ui(12, 700, G.ink2), lines: 1)
            }
            .padding(.horizontal, 12).frame(height: 30)
            .background(Capsule().fill(G.sheet(0.94)))
            .position(caption)
        }
        .allowsHitTesting(false)
        .accessibilityIdentifier("re.coach")
    }

    /// Where the ghost and the hand are at t (0–1 of a turn): the ghost's centre and scale, its opacity, the hand's
    /// tip, its opacity, how much the wall glows (mockup cGhost, cHand, cGlow).
    static func frame(_ t: Double, _ p0: CGPoint, _ p1: CGPoint) -> ReCoachFrame {
        func lerp(_ a: CGPoint, _ b: CGPoint, _ k: Double) -> CGPoint {
            let kk = CGFloat(k)
            return CGPoint(x: a.x + (b.x - a.x) * kk, y: a.y + (b.y - a.y) * kk)
        }
        func seg(_ t: Double, _ a: Double, _ b: Double) -> Double { max(0, min(1, (t - a) / (b - a))) }
        var f = ReCoachFrame()
        f.gp = lerp(p0, p1, seg(t, 0.20, 0.56))
        var gs = 1.0
        if t < 0.14 { gs = 0.8 }
        else if t < 0.20 { gs = 0.8 + 0.2 * seg(t, 0.14, 0.20) }
        else if t < 0.56 { gs = 1 }
        else if t < 0.64 { gs = 1 - 0.4 * seg(t, 0.56, 0.64) }
        else { gs = 0.6 - 0.2 * seg(t, 0.64, 0.74) }
        f.gs = CGFloat(gs)
        if t < 0.14 { f.go = 0 }
        else if t < 0.20 { f.go = seg(t, 0.14, 0.20) }
        else if t < 0.64 { f.go = 1 }
        else if t < 0.74 { f.go = 0.9 * (1 - seg(t, 0.64, 0.74)) }
        else { f.go = 0 }
        f.hp = f.gp
        if t < 0.14 { f.hp = CGPoint(x: p0.x, y: p0.y + CGFloat(34 - 34 * seg(t, 0, 0.14))) }
        else if t > 0.56 { f.hp = CGPoint(x: p1.x, y: p1.y + CGFloat(34 * seg(t, 0.56, 0.76))) }
        if t < 0.08 { f.ho = seg(t, 0, 0.08) } else if t < 0.64 { f.ho = 1 } else { f.ho = 1 - seg(t, 0.64, 0.76) }
        if t < 0.42 { f.glow = 0 } else if t < 0.5 { f.glow = seg(t, 0.42, 0.5) } else if t < 0.63 { f.glow = 1 } else { f.glow = 1 - seg(t, 0.63, 0.76) }
        return f
    }
}

/// One moment of the hand animation: the ghost's centre, scale and opacity, the hand's tip and opacity, the glow.
struct ReCoachFrame {
    var gp = CGPoint.zero
    var gs: CGFloat = 1
    var go = 0.0
    var hp = CGPoint.zero
    var ho = 0.0
    var glow = 0.0
}

let SD_HAND_IC = "M8 13V5.5a1.5 1.5 0 0 1 3 0V11m0-1.5V4a1.5 1.5 0 0 1 3 0v6m0-4.5a1.5 1.5 0 0 1 3 0V12m0-4a1.5 1.5 0 0 1 3 0v6.5A7.5 7.5 0 0 1 12.5 22h-.7a6 6 0 0 1 -5-2.7L4.2 15a1.6 1.6 0 0 1 2.5-2z"

/* ---------------- the list of items ---------------- */

/// "Belgilar · N ta": every item with its wall, sizes and distances (and its problem in red); a tap selects it.
struct ReListSheet: View {
    let st: ReState
    let h: ReHost
    var body: some View {
        if st.list, let r = h.room() {
            let g = reGeo(r)
            let items = reItems(r)
            let iss = Dictionary(reIssues(items, lens: g.lens, roomH: g.H).map { ($0.id, reIssueText($0)) }, uniquingKeysWith: { a, _ in a })
            ZStack(alignment: .bottom) {
                G.scrim.ignoresSafeArea().onTapGesture { st.list = false }
                VStack(alignment: .leading, spacing: 4) {
                    Capsule().fill(G.rim).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.bottom, 8)
                    T(tr("re.listT", ["n": items.count]), ui(19, 800))
                    T(tr("re.listS"), ui(12.5, 400, G.ink2)).padding(.bottom, 6)
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(items, id: \.id) { it in
                                let d = reDists(it, g.len(it.wall))
                                HStack(spacing: 10) {
                                    ReBadge(kind: it.kind, size: 30)
                                    VStack(alignment: .leading, spacing: 1) {
                                        T(reItemName(it), ui(13.5, 800), lines: 1)
                                        T(tr("re.wallX", ["w": it.wall]) + " · " + reSizeLine(it) + " · " + reLen(d.l) + " | " + reLen(d.r), num(12, 500, G.ink2), lines: 2)
                                        if let e = iss[it.id] { T(e, ui(12, 700, RD.issue), lines: 2) }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(st.selItem == it.id ? G.cobalt.opacity(0.1) : .clear))
                                .contentShape(Rectangle())
                                .pressable(0.99) { st.list = false; st.select(it.id, h) }
                                .accessibilityIdentifier("re.row." + it.kind)
                            }
                        }
                    }
                    .frame(maxHeight: 380)
                    T(tr("common.close"), ui(14, 700, G.ink2), align: .center).underline().frame(maxWidth: .infinity, minHeight: 44)
                        .pressable(0.97) { st.list = false }
                }
                .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 24)
                .background(UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous).fill(G.solid).ignoresSafeArea(edges: .bottom))
            }
        }
    }
}
