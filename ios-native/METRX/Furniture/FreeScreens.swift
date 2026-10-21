import SwiftUI

/*
 * Furniture without a room (decided 20 Oct 2026, mockup design/furniture/orders-flow-mockup.html v4; Android
 * ui/furniture/FreeScreens.kt): after the three-field new order, "Nima kerak?"; for each piece the room or only its
 * sizes; a gallery of ready models with 3D pictures; the sizes; later "Xonaga qo‘yish" into a measured room, and
 * "Xonadan chiqarish" back out. The rules are in Furniture/Core/Free.swift.
 */

private var en: Bool { AppSettings.shared.lang == .en }

/* ---------------- the order's name and what is still wanted ---------------- */

/// While the order's name follows its furniture: "Oshxona — Akmal", "Shkaf — Akmal", "Oshxona va shkaf — Akmal".
func renameOrder(_ pid: String) {
    Store.shared.update(pid) { p in
        guard p.autoName else { return }
        let ks = Set(p.furniture.map(kindKey) + (p.want ?? []))
        let what: String? = ks.isEmpty ? nil : ks == ["kitchen", "wardrobe"] ? tr("fo.both") : ks == ["wardrobe"] ? tr("kt.wardrobe")
            : ks == ["kitchen"] ? tr("kt.kitchen") : tr("fz.furn")
        p.name = what.map { $0 + " — " + p.customer } ?? p.customer
    }
}

/// A room every wall and the height of which are confirmed.
func measuredRoom(_ r: Room, _ snap: Bool) -> Bool { Geo.stepKeys(r, snap).allSatisfy { r.dim($0).status == "conf" } }

/// Takes the piece out of its room: its sizes from what stands on the walls now.
func takeOut(_ app: AppModel, _ pid: String, _ fid: String) {
    guard let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) else { return }
    let room = roomOf(p, f)
    let snap = AppSettings.shared.angleSnap
    let g = takenOut(f, { id in room.flatMap { wallLen($0, snap, id) } }, room?.dim("H").v)
    Store.shared.update(pid) { pr in pr.furniture = pr.furniture.map { $0.id == fid ? g : $0 } }
    KitOps.shared.sel = nil; KitOps.shared.tick += 1
    app.say("fz.outDone", ["n": dn(f.name)])
}

/// The designer of a piece: the wardrobe's at step, or the kitchen's.
func designer(_ pid: String, _ f: Furniture, step: Int = 1) -> Route {
    f.kind == "wardrobe" ? .wardrobe(pid: pid, fid: f.id, step: step, sec: 0) : .kitchen(pid: pid, fid: f.id, wall: nil)
}

/* ---------------- the page frame ---------------- */

private struct FPage<Content: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let back: () -> Void
    var hasFooter = true
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back"), back).padding(.leading, 6).accessibilityIdentifier("back")
                    BarTitle(title: title, eyebrow: eyebrow)
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) { content }
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, hasFooter ? 120 : 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            if hasFooter { FloatingFooter { footer } }
        }
    }
}

extension FPage where Footer == EmptyView {
    init(eyebrow: String, title: String, back: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow; self.title = title; self.back = back; self.hasFooter = false; self.content = content(); self.footer = EmptyView()
    }
}

private struct ChoiceRow: View {
    let icon: String, title: String, sub: String
    var id = ""
    let action: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            MIcon(icon, G.cobalt, 24, 2).frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 2) { T(title, ui(16.5, 800)); T(sub, ui(13, 400, G.ink2, lh: 1.35)) }
                .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 16).padding(.vertical, 14).frame(minHeight: 78)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.62))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(id)
    }
}

/* ---------------- "Nima kerak?" ---------------- */

struct FNeedScreen: View {
    let app: AppModel
    let pid: String
    var body: some View {
        if let p = Store.shared.get(pid) {
            FPage(eyebrow: dn(p.name), title: tr("fo.what"), back: { app.pop() }) {
                ChoiceRow(icon: "kitchen", title: tr("kt.kitchen"), sub: tr("fz.needKs"), id: "need.kitchen") { pick("kitchen") }
                ChoiceRow(icon: "board", title: tr("kt.wardrobe"), sub: tr("fz.needWs"), id: "need.wardrobe") { pick("wardrobe") }
                ChoiceRow(icon: "layers", title: tr("fz.needB"), sub: tr("fz.needBs"), id: "need.both") { pick("both") }
                ChoiceRow(icon: "box", title: tr("fz.needO"), sub: tr("fz.needOs"), id: "need.other") { pick("other") }
                ChoiceRow(icon: "clock", title: tr("fz.needL"), sub: tr("fz.needLs"), id: "need.later") { pick("later") }
            }
        }
    }
    private func pick(_ k: String) {
        if k == "later" { app.pop(); return }
        let ks = k == "both" ? ["kitchen", "wardrobe"] : [k]
        Store.shared.update(pid) { p in var w = p.want ?? []; for x in ks where !w.contains(x) { w.append(x) }; p.want = w }
        renameOrder(pid)
        app.replaceTop(.fHow(pid: pid, kind: ks[0]))
    }
}

/* ---------------- the room, or only the sizes ---------------- */

struct FHowScreen: View {
    let app: AppModel
    let pid: String
    let kind: String
    var body: some View {
        if let p = Store.shared.get(pid) {
            FPage(eyebrow: dn(p.name), title: tr("fz.howT", ["k": tr(kind == "kitchen" ? "kt.kitchen" : kind == "other" ? "fz.furn" : "kt.wardrobe")]), back: { app.pop() }) {
                ChoiceRow(icon: "room", title: tr("fz.howRoom"), sub: tr("fz.howRoomS"), id: "how.room") { app.pop(); app.sheet = .fNewRoom(pid: pid, kind: kind) }
                ChoiceRow(icon: "ruler", title: tr("fz.howSize"), sub: tr("fz.howSizeS"), id: "how.size") { app.replaceTop(.fModels(pid: pid, kind: kind)) }
            }
        }
    }
}

/* ---------------- the gallery ---------------- */

struct FModelsScreen: View {
    let app: AppModel
    let pid: String
    let kind: String
    var body: some View {
        if let p = Store.shared.get(pid) {
            let list = modelsOf(kind)
            // groups in the gallery's order ("" for kitchens and wardrobes)
            let groups = list.map(\.group).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            FPage(eyebrow: dn(p.name), title: tr(kind == "kitchen" ? "fz.modelsK" : kind == "other" ? "fz.modelsO" : "fz.modelsW"), back: { app.pop() }) {
                T(tr("fz.modelsNote"), ui(14, 400, G.ink2, lh: 1.4))
                ForEach(groups, id: \.self) { g in
                    if !g.isEmpty { T(tr("kt." + g), ui(16, 800)).padding(.top, 6) }
                    let ms = list.filter { $0.group == g }
                    ForEach(Array(stride(from: 0, to: ms.count, by: 2)), id: \.self) { i in
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(ms[i..<min(i + 2, ms.count)], id: \.id) { m in
                                ModelCard(m: m, wide: i + 1 >= ms.count) { app.push(.fSizes(pid: pid, kind: m.kind, model: m.id, fid: nil)) }
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct ModelCard: View {
    let m: FModelDef
    let wide: Bool
    let action: () -> Void
    var body: some View {
        let name = tr("fz.m." + m.id)
        let pic = ModelPic(m: m, sides: m.sides, island: m.island, w: m.w, h: m.h, d: m.d)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        let words = VStack(alignment: .leading, spacing: 2) {
            T(name, ui(14.5, 800), lines: 2)
            T(tr("fz.s." + m.id), ui(12, 500, G.ink2, lh: 1.3), lines: 2)
        }
        .padding(.horizontal, 4)
        Group {
            // the last card of an odd row takes the whole width, its picture beside the words
            if wide { HStack(spacing: 10) { pic.frame(maxWidth: .infinity); words.frame(maxWidth: .infinity, alignment: .leading) } }
            else { VStack(alignment: .leading, spacing: 6) { pic; words; Spacer(minLength: 0) } }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.62))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("model." + m.id)
    }
}

/* ---------------- the 3D picture of a model (the mockup's iso sketch) ---------------- */

private let PIC_BG = Color(argb: 0xFFF6F8FC)
private let FLOOR = Color(argb: 0xFFE8ECF3), FLOOR_LN = Color(argb: 0xFFC9D1DE)
private let WALL_F = Color(argb: 0x0D3550E0), WALL_F2 = Color(argb: 0x0A3550E0), WALL_LN = Color(argb: 0x2E3550E0)
private let LO = Color(argb: 0xFFD9E2EF), SI = Color(argb: 0xFFC9D5E6), TOP = Color(argb: 0xFF4B4F58), UP = Color(argb: 0xFFE4EAF3), LN = Color(argb: 0xFF7A8BA6)
private let DARK = Color(argb: 0xFF333333)
private let WD = Color(argb: 0xFFE8E0D3), WD_OPEN = Color(argb: 0xFFF3EEE6), WD_LN = Color(argb: 0xFF8C7A62)

/// The iso sketch's drawing in its 260 × 230 frame.
private struct Iso {
    let c: GraphicsContext
    func p(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CGPoint { CGPoint(x: 130 + (x - y) * 0.62, y: 150 + (x + y) * 0.33 - z) }
    func poly(_ pts: [CGPoint], _ fill: Color, _ line: Color, dashed: Bool = false) {
        var path = Path(); path.move(to: pts[0]); pts.dropFirst().forEach { path.addLine(to: $0) }; path.closeSubpath()
        c.fill(path, with: .color(fill))
        c.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : []))
    }
    /// A box seen from the front-right: its front, right side and top, as the mockup draws them.
    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ d: CGFloat, _ h: CGFloat, _ fill: Color, _ line: Color, _ z0: CGFloat = 0) {
        let q = [p(x, y, z0), p(x + w, y, z0), p(x + w, y + d, z0), p(x, y + d, z0),
                 p(x, y, z0 + h), p(x + w, y, z0 + h), p(x + w, y + d, z0 + h), p(x, y + d, z0 + h)]
        poly([q[3], q[2], q[6], q[7]], fill, line); poly([q[1], q[2], q[6], q[5]], fill, line); poly([q[4], q[5], q[6], q[7]], fill, line)
    }
    func line(_ a: CGPoint, _ b: CGPoint, _ col: Color, _ w: CGFloat = 1, round: Bool = false) {
        var path = Path(); path.move(to: a); path.addLine(to: b)
        c.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: w, lineCap: round ? .round : .butt))
    }
    func vline(_ x: CGFloat, _ y: CGFloat, _ z0: CGFloat, _ z1: CGFloat, _ col: Color, _ w: CGFloat = 1) { line(p(x, y, z0), p(x, y, z1), col, w) }
}

/// The model drawn as a small 3D sketch on a floor with faint walls, sized to fill a 260 × 230 picture.
struct ModelPic: View {
    let m: FModelDef
    let sides: [Int]
    let island: Int
    let w: Int, h: Int, d: Int
    var body: some View {
        Canvas { ctx, size in
            var c = ctx
            let k0 = size.width / 260
            c.scaleBy(x: k0, y: k0)
            drawModel(Iso(c: c))
        }
        .aspectRatio(260 / 230, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(PIC_BG)
        .accessibilityHidden(true)
    }

    private func drawModel(_ g: Iso) {
        if !m.type.isEmpty { drawCabinet(g, m.type, max(w, 300), max(h, 300), max(d, 250)); return }
        let kit = m.kind == "kitchen", L = m.layout
        func side(_ i: Int) -> CGFloat { CGFloat(max(i < sides.count ? sides[i] : 600, 600)) }
        let main: CGFloat = kit ? (L == "U" ? side(1) : side(0)) : CGFloat(max(w, 300))
        let turns = kit && L != "I"
        let k = min(0.05, (kit ? 140 : 105) / (turns ? main + 900 : main))
        let isl = CGFloat(max(island, 600))
        let deep: CGFloat = kit ? (L == "L" ? side(1) : L == "U" ? max(side(0), side(2)) : L == "P" ? isl : L == "O" ? 2400 : 600) : CGFloat(max(d, 300))
        let W = main * k + 30, D = max(deep * k + 30, 90), H = CGFloat(kit ? max(h, 2000) : max(h + 150, 2500)) * k
        g.poly([g.p(0, 0, 0), g.p(W, 0, 0), g.p(W, D, 0), g.p(0, D, 0)], FLOOR, FLOOR_LN)
        g.poly([g.p(0, 0, 0), g.p(W, 0, 0), g.p(W, 0, H), g.p(0, 0, H)], WALL_F, WALL_LN, dashed: true)
        if kit && (L == "L" || L == "U") { g.poly([g.p(0, 0, 0), g.p(0, D, 0), g.p(0, D, H), g.p(0, 0, H)], WALL_F2, WALL_LN, dashed: true) }
        if kit {
            let dd = 600 * k, lo = 870 * k, up0 = 1450 * k, up = 720 * k, ud = 350 * k, t = 40 * k
            func run(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ uppers: Bool) {
                g.box(x, y, w, dd, lo, LO, LN); g.box(x, y, w, dd, t, TOP, DARK, lo); if uppers { g.box(x, y, w, ud, up, UP, LN, up0) }
            }
            func leg(_ x: CGFloat, _ y: CGFloat, _ len: CGFloat, _ uppers: Bool) {
                g.box(x, y, dd, len, lo, SI, LN); g.box(x, y, dd, len, t, TOP, DARK, lo); if uppers { g.box(x, y, ud, len, up, UP, LN, up0) }
            }
            let a = main * k
            if L == "L" { leg(0, dd, side(1) * k - dd, true) }
            if L == "U" { leg(0, dd, side(0) * k - dd, true) }
            run(0, 0, a, true)
            let n = max(1, Int((main / 600).rounded()))
            for i in 1..<max(n, 1) { g.vline(a * CGFloat(i) / CGFloat(n), dd, 0, lo, LN) }
            if L == "U" { leg(a - dd, dd, side(2) * k - dd, false) }
            if L == "P" { leg(a - dd, dd, isl * k - dd, false) }
            if L == "O" {
                let il = isl * k
                g.box((a - il) / 2, dd + 900 * k, il, 900 * k, lo, LO, LN); g.box((a - il) / 2, dd + 900 * k, il, 900 * k, t, TOP, DARK, lo)
            }
        } else {
            let ww = CGFloat(w) * k, dp = CGFloat(d) * k, hh = CGFloat(h) * k
            g.box(0, 0, ww, dp, hh, m.doors == "open" ? WD_OPEN : WD, WD_LN)
            switch m.doors {
            case "open":
                for i in 1..<5 { let z = hh * CGFloat(i) / 5; g.line(g.p(0, dp, z), g.p(ww, dp, z), WD_LN, 1.6) }
            case "slide":
                let n = max(2, m.n), pw = ww / CGFloat(n)
                for i in 0..<n {
                    g.box(CGFloat(i) * pw, dp + (i % 2 == 1 ? 2 : 0) * k * 30, pw, k * 20, hh * 0.98, i % 2 == 1 ? Color(argb: 0xFFDCD2C2) : Color(argb: 0xFFEDE6DA), WD_LN)
                }
            default:
                let n = m.n > 0 ? m.n : max(2, Int((Double(w) / 600).rounded()))
                for i in 1..<n { g.vline(ww * CGFloat(i) / CGFloat(n), dp, 0, hh, WD_LN) }
                for i in 0..<n {
                    let x = ww * (CGFloat(i) + (i % 2 == 1 ? 0.12 : 0.88)) / CGFloat(n)
                    g.line(g.p(x, dp, hh * 0.45), g.p(x, dp, hh * 0.55), DARK, 2, round: true)
                }
            }
        }
    }

    /// A Stage 2 type's picture: its template's carcass, sections, drawers, shelves and doors, as an iso sketch.
    private func drawCabinet(_ g: Iso, _ type: String, _ ww: Int, _ hh: Int, _ dd: Int) {
        let cab = cabinetTemplate(type, Workshop(), "A", 0, ww, hh, dd)
        let k = min(0.06, 110 / CGFloat(max(ww, hh)))
        let w = CGFloat(ww) * k, dp = CGFloat(dd) * k, h = CGFloat(hh) * k
        let z0: CGFloat = cab.legs ? 100 * k : 0
        g.poly([g.p(-10, -10, 0), g.p(w + 30, -10, 0), g.p(w + 30, dp + 60, 0), g.p(-10, dp + 60, 0)], FLOOR, FLOOR_LN)
        let wh = max(h + 40, 120)
        g.poly([g.p(-10, -10, 0), g.p(w + 30, -10, 0), g.p(w + 30, -10, wh), g.p(-10, -10, wh)], WALL_F, WALL_LN, dashed: true)
        if cab.legs { for x in [4, w - 6] { g.box(x, dp - 6, 2, 2, z0, DARK, DARK) } }
        let t = 16 * k
        var a: CGFloat = 0
        for (i, s) in cab.sections.enumerated() {
            let sw = CGFloat(s.w) * k
            if s.knee {
                // the knee space: the top over it, a side down to the floor at its far end
                g.box(a, 0, sw, dp, t, WD, WD_LN, z0 + h - t)
            } else {
                g.box(a, 0, sw, dp, h, s.fronts.kind == "open" ? WD_OPEN : WD, WD_LN, z0)
                let ih = h - 2 * t
                for x in s.inserts {
                    let y = z0 + t + CGFloat(x.pos) * k
                    switch x.kind {
                    case "shelf": g.line(g.p(a + 1, dp, y), g.p(a + sw - 1, dp, y), WD_LN, 1.2)
                    case "drawer":
                        let top = y + CGFloat(x.h) * k
                        g.line(g.p(a + 1, dp, top), g.p(a + sw - 1, dp, top), WD_LN, 1.2)
                        g.line(g.p(a + sw * 0.42, dp, y + CGFloat(x.h) * k * 0.6), g.p(a + sw * 0.58, dp, y + CGFloat(x.h) * k * 0.6), DARK, 1.8, round: true)
                    case "rail": g.line(g.p(a + 2, dp * 0.5, y), g.p(a + sw - 2, dp * 0.5, y), DARK, 1.4)
                    default: break
                    }
                }
                if s.fronts.kind == "door" {
                    let n = max(1, s.fronts.n)
                    for j in 1..<max(n, 1) { g.vline(a + sw * CGFloat(j) / CGFloat(n), dp, z0, z0 + h, WD_LN) }
                    for j in 0..<n {
                        let x = a + sw * (CGFloat(j) + (j % 2 == 1 ? 0.12 : 0.88)) / CGFloat(n)
                        g.line(g.p(x, dp, z0 + ih * 0.45), g.p(x, dp, z0 + ih * 0.6), DARK, 2, round: true)
                    }
                }
            }
            if i > 0 { g.vline(a, dp, s.knee || cab.sections[i - 1].knee ? 0 : z0, z0 + h, WD_LN) }
            a += sw
        }
        // a desk's far side stands on the floor
        if cab.sections.last?.knee == true { g.box(w - t, 0, t, dp, z0 + h - t, WD, WD_LN, 0) }
    }
}

/* ---------------- the sizes ---------------- */

/// The labels of a layout's sides, in run order.
private func sideKeys(_ layout: String) -> [String] {
    switch layout {
    case "L": return ["fz.w1", "fz.w2"]
    case "U": return ["fz.uL", "fz.uM", "fz.uR"]
    case "O", "P": return ["fz.pW"]
    default: return ["fz.len"]
    }
}

private enum SF: Hashable { case side(Int), island, ceil, w, h, d }

private func mm(_ s: String) -> Int { Int(String(s.filter { $0.isASCII && $0.isNumber }.prefix(5))) ?? 0 }

struct FSizesScreen: View {
    let app: AppModel
    let pid: String
    let kind: String
    let model: String
    let fid: String?
    @State private var sides: [String]
    @State private var island: String
    @State private var ceil: String
    @State private var w: String
    @State private var h: String
    @State private var d: String
    @State private var built: Bool
    @State private var tried = false
    @FocusState private var focus: SF?

    init(app: AppModel, pid: String, kind: String, model: String, fid: String?) {
        self.app = app; self.pid = pid; self.kind = kind; self.model = model; self.fid = fid
        let m = FSizesScreen.modelOf(model, kind)
        let edit = fid.flatMap { id in Store.shared.get(pid)?.furniture.first { $0.id == id } }
        let n = sidesOf(edit?.layout ?? m.layout)
        // what the fields start from: the piece being changed, or the model's usual sizes
        let start = edit?.free
        let s0 = Array((start?.sides ?? m.sides).prefix(n)).map(String.init)
        _sides = State(initialValue: s0 + Array(repeating: "", count: max(0, n - s0.count)))
        let isl = start?.island ?? m.island
        _island = State(initialValue: isl > 0 ? "\(isl)" : "")
        _ceil = State(initialValue: "\(start?.h ?? m.h)")
        _w = State(initialValue: "\(m.w)"); _h = State(initialValue: "\(m.h)"); _d = State(initialValue: "\(m.d)")
        _built = State(initialValue: m.built)
    }

    static func modelOf(_ id: String, _ kind: String) -> FModelDef { fModel(id) ?? fModel(kind == "kitchen" ? "L" : "h2")! }

    private func digits(_ b: Binding<String>, _ n: Int = 5) -> Binding<String> {
        Binding(get: { b.wrappedValue }, set: { b.wrappedValue = String($0.filter { $0.isASCII && $0.isNumber }.prefix(n)) })
    }
    private func sideBinding(_ i: Int) -> Binding<String> {
        Binding(get: { i < sides.count ? sides[i] : "" }, set: { v in if i < sides.count { sides[i] = String(v.filter { $0.isASCII && $0.isNumber }.prefix(5)) } })
    }

    var body: some View {
        if let p = Store.shared.get(pid) {
            let m = FSizesScreen.modelOf(model, kind)
            let cabinet = !m.type.isEmpty
            let edit = fid.flatMap { id in p.furniture.first { $0.id == id } }
            let kit = kind == "kitchen"
            let L = edit?.layout ?? m.layout
            let n = sidesOf(L)
            let hasIsland = L == "O" || L == "P"
            let sideErr = kit && sides.contains { mm($0) < 600 } ? tr("fz.min600") : nil
            let islErr = kit && hasIsland && mm(island) < 600 ? tr("fz.min600") : nil
            let wErr = !kit && !cabinet && (mm(w) < 400 || mm(h) < 1200) ? tr("fz.minW")
                : cabinet && (mm(w) < 300 || mm(h) < 300 || mm(d) < 250) ? tr("fz.minC") : nil
            let ok = sideErr == nil && islErr == nil && wErr == nil
            FPage(eyebrow: dn(p.name), title: tr(kit ? "fz.sizesK" : cabinet ? "fz.sizesO" : "fz.sizesW"), back: { app.pop() }) {
                // the chosen model, with a way back to the gallery
                HStack(spacing: 10) {
                    ModelPic(m: m, sides: sides.map(mm), island: mm(island), w: mm(w), h: mm(h), d: mm(d))
                        .frame(width: 96).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        T(tr("fz.m." + m.id), ui(15.5, 800), lines: 2)
                        T(tr("fz.s." + m.id), ui(12.5, 400, G.ink2), lines: 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if edit == nil { GBtn(tr("fz.change"), kind: .secondary, height: 40, corner: 12, fontSize: 13.5, fill: false) { app.pop() } }
                }
                .padding(8)
                .glassCard(RoundedRectangle(cornerRadius: 18, style: .continuous), fill: G.glass(0.62))
                if kit {
                    ForEach(Array(sideKeys(L).enumerated()), id: \.offset) { i, key in
                        GField(label: tr(key), value: sideBinding(i), placeholder: "2000", error: mm(i < sides.count ? sides[i] : "") < 600 ? sideErr : nil, showError: tried,
                               focus: $focus, me: .side(i), onSubmit: { focus = i + 1 < n ? .side(i + 1) : hasIsland ? .island : .ceil }, labelRight: "mm", number: true, id: "fz.side\(i)")
                    }
                    if hasIsland {
                        GField(label: tr(L == "P" ? "fz.pP" : "fz.isl"), value: digits($island), placeholder: "1800", error: islErr, showError: tried, focus: $focus, me: .island,
                               onSubmit: { focus = .ceil }, labelRight: "mm", number: true)
                    }
                    GField(label: tr("fz.ceil"), value: digits($ceil), placeholder: "2700", focus: $focus, me: .ceil, submit: .done, onSubmit: { focus = nil }, labelRight: "mm", number: true)
                    // the running metres, as the price counts them
                    let vs = sides.map(mm), corners = n - 1
                    let t = (max(0, freeRunMm(L, vs, mm(island))) + 50) / 100
                    let islPart = hasIsland ? " + " + tr(L == "P" ? "kt.peninsula" : "kt.island").lowercased() + " \(mm(island))" : ""
                    let cut = corners > 0 ? " − \(corners * K_CORNER) " + tr("kt.cornerCut") : ""
                    T(vs.map(String.init).joined(separator: " + ") + islPart + cut + " → \(t / 10)\(en ? "." : ",")\(t % 10) " + tr("kt.pm"), num(15, 700))
                } else {
                    GField(label: tr("wd.w"), value: digits($w), placeholder: "2400", error: wErr, showError: tried, focus: $focus, me: .w, onSubmit: { focus = .h },
                           labelRight: "mm", number: true, id: "fz.w")
                    GField(label: tr("fz.wH"), value: digits($h), placeholder: "2600", focus: $focus, me: .h, onSubmit: { focus = .d }, labelRight: "mm", number: true)
                    GField(label: tr("wd.d"), value: digits($d, 4), placeholder: "600", focus: $focus, me: .d, submit: .done, onSubmit: { focus = nil }, labelRight: "mm", number: true)
                    if !cabinet {
                        T(tr("fz.type"), ui(15, 700))
                        Seg(items: [("built", tr("wd.built")), ("free", tr("wd.free"))], cur: built ? "built" : "free") { built = $0 == "built" }
                    }
                    // as the wardrobe is made: about 600 a section, two doors on a section 600 or wider
                    let secs = sectionsFor(max(mm(w), 400))
                    if m.doors == "door" { T(tr("fz.doorsH", ["n": secs * (mm(w) / secs >= 600 ? 2 : 1)]), ui(13, 400, G.ink2, lh: 1.4)) }
                    if m.doors == "slide" { T(tr("fz.doorsS", ["n": m.n]), ui(13, 400, G.ink2, lh: 1.4)) }
                }
                if edit == nil { T(tr("fz.noRoomNote"), ui(13, 400, G.ink2, lh: 1.4)) }
            } footer: {
                GBtn(tr(edit != nil ? "common.save" : "kt.start"), enabled: !tried || ok) { create(p, m, edit, ok) }.accessibilityIdentifier("fz.create")
            }
        }
    }

    private func create(_ p: Project, _ m: FModelDef, _ edit: Furniture?, _ ok: Bool) {
        tried = true
        guard ok else { return }
        focus = nil
        let ws = AppSettings.shared.workshop
        let kit = kind == "kitchen", cabinet = !m.type.isEmpty
        let L = edit?.layout ?? m.layout
        let hasIsland = L == "O" || L == "P"
        let ceilMm = mm(ceil) > 0 ? mm(ceil) : 2700
        if let edit {
            // new sizes for a room-less kitchen: the units that no longer fit are cut, the rest stays
            var nf = edit; nf.free = FreeSize(sides.map(mm), hasIsland ? mm(island) : 0, ceilMm)
            let nn = nf
            let g = fitTo(nf, nf.walls, { freeLen(nn, $0) }, nil, ws)
            Store.shared.update(pid) { pr in pr.furniture = pr.furniture.map { $0.id == edit.id ? g : $0 } }
            KitOps.shared.tick += 1; app.pop(); app.say("fz.saved"); return
        }
        let now = nowMs()
        let count = p.furniture.filter { cabinet ? $0.type == m.type : $0.kind == kind && $0.type.isEmpty }.count + 1
        let f: Furniture
        if cabinet { f = newFreeCabinet(tr("ft." + m.type) + " \(count)", m.type, mm(w), mm(h), mm(d), ws, now: now) }
        else if kit { f = newFreeKitchen(tr("kt.nameN", ["n": count]), m.id, L, sides.map(mm), hasIsland ? mm(island) : 0, ceilMm, ws, now: now) }
        else { f = newFreeWardrobe(tr("wd.nameN", ["n": count]), m.id, mm(w), mm(h), mm(d) >= 200 ? mm(d) : W_DEPTH, built, m.doors, ws, now: now, n: m.n) }
        let moved = p.stage == "measure"
        let wantKey = cabinet ? "other" : kind
        Store.shared.update(pid) { pr in
            pr.furniture.append(f)
            if pr.stage == "measure" { pr.stage = "design" }
            var wn = pr.want ?? []; if !wn.contains(wantKey) { wn.append(wantKey) }; pr.want = wn
        }
        renameOrder(pid)
        KitOps.shared.sel = nil
        app.popTo { if case .project(let id, _, _, _) = $0 { return id == pid }; return false }
        app.push(designer(pid, f, step: 2))
        app.say(moved ? "fz.createdS" : "fz.created", ["n": dn(f.name), "s": tr("fs.design")])
    }
}

/* ---------------- on the designers and the order: room-less pieces ---------------- */

/// On a room-less piece's designer: it has no room yet, and the way into one.
struct FreeBanner: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            T(tr("fz.banner"), ui(13.5, 500, G.ink, lh: 1.4))
            HStack(spacing: 8) {
                GBtn(tr("fz.toRoom"), icon: "room", height: 44, corner: 14, fontSize: 14) { app.sheet = .fPickRoom(pid: p.id, fid: f.id) }.accessibilityIdentifier("fz.toRoom")
                if f.kind == "kitchen" {
                    GBtn(tr("fz.sizesBtn"), kind: .secondary, icon: "ruler", height: 44, corner: 14, fontSize: 14) {
                        app.push(.fSizes(pid: p.id, kind: f.kind, model: f.model.isEmpty ? f.layout : f.model, fid: f.id))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(G.cobalt.opacity(0.08)))
        .overlay(shape.strokeBorder(G.cobalt.opacity(0.25), lineWidth: 1))
    }
}

/// A room-less piece's line: its model, sizes and running metres.
func freeSub(_ f: Furniture, _ en: Bool) -> String {
    func m(_ v: Int) -> String { Geo.fmtLen(v, .m, en) }
    if f.kind == "wardrobe" {
        guard let w = wardOfF(f) else { return "" }
        let name: String? = f.model.isEmpty ? nil : tr(!f.type.isEmpty ? "ft." + f.model : "fz.m." + f.model)
        return [name, m(w.w) + " × " + m(w.h) + " × " + m(w.d) + " m"].compactMap { $0 }.joined(separator: " · ")
    }
    let fs = f.free
    let run = fs.map { freeRunMm(f.layout, $0.sides, $0.island) } ?? runMm(f)
    let t = (max(0, run) + 50) / 100
    let sizes = fs.map { $0.sides.map(String.init).joined(separator: " + ") + ($0.island > 0 ? " + \($0.island)" : "") }
    return [tr(f.model.isEmpty ? "kt.l" + f.layout : "fz.m." + f.model), sizes, "\(t / 10)\(en ? "." : ",")\(t % 10) " + tr("kt.pm")].compactMap { $0 }.joined(separator: " · ")
}

/// "Xonasiz mebel": the order's pieces without a room, each with its price and "Xonaga qo‘yish".
struct FreeCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let free = p.furniture.filter { $0.roomId == nil }
        if !free.isEmpty {
            let amounts = pieceAmounts(p)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    MIcon("ruler", G.cobalt, 24, 2).frame(width: 64, height: 52)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 1) { T(tr("fz.free"), ui(16, 700), lines: 1); T(tr("fz.freeS"), ui(12.5, 400, G.ink2), lines: 1) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(free) { f in
                    HStack(spacing: 10) {
                        MIcon(f.kind == "wardrobe" ? "board" : "kitchen", G.ink3, 18, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            T(dn(f.name), ui(14.5, 700), lines: 1)
                            T(freeSub(f, en), num(12.5, 500, G.ink2), lines: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let a = amounts[f.id], a > 0 { T(shortStr(p, a), num(14, 700)) }
                        MIcon("chev", G.ink3, 16, 2)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.75)))
                    .pressable(0.985) { KitOps.shared.sel = nil; app.push(designer(p.id, f)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    TodoRow(label: tr("fz.toRoom")) { app.sheet = .fPickRoom(pid: p.id, fid: f.id) }
                }
            }
            .padding(12)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        }
    }
}

/* ---------------- which room ---------------- */

struct PickRoomSheet: View {
    let app: AppModel
    let pid: String
    let fid: String
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) {
            let snap = AppSettings.shared.angleSnap
            let rooms = p.rooms.filter { measuredRoom($0, snap) }
            let m = { (v: Int?) -> String in v.map { Geo.fmtLen($0, .m, en) } ?? "?" }
            GlassSheet(tr("fz.pickT", ["n": dn(f.name)]), onClose: { app.sheet = nil }) {
                if rooms.isEmpty { T(tr("fz.noMeasured"), ui(14, 400, G.ink2, lh: 1.45)) }
                ForEach(rooms) { r in
                    let w = p.floors.first { $0.id == r.floorId }
                    HStack(spacing: 12) {
                        MIcon(w?.type == "kitchen" ? "kitchen" : "room", G.cobalt, 22, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            T(w.map { floorName($0) } ?? dn(r.name), ui(15.5, 700), lines: 1)
                            T(m(r.dim("A").v) + " × " + m(r.dim("B").v) + " m · h " + m(r.dim("H").v), num(12.5, 500, G.ink2), lines: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        MIcon("chev", G.ink3, 16, 2)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.ink.opacity(0.05)))
                    .pressable(0.98) { app.sheet = nil; app.push(.fPlace(pid: p.id, fid: f.id, rid: r.id)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }
                HStack(spacing: 8) { MIcon("plus", G.cobalt2, 18, 2.2); T(tr("fz.newRoom"), ui(15, 700, G.cobalt2)).frame(maxWidth: .infinity, alignment: .leading) }
                    .padding(.horizontal, 12).frame(minHeight: 52)
                    .dashedGlass(14)
                    .pressable(0.98) { app.sheet = .fNewRoom(pid: p.id, kind: f.kind, fid: f.id) }
                    .accessibilityIdentifier("fz.newRoom")
            }
        }
    }
}

/* ---------------- into the room ---------------- */

private enum PF: Hashable { case off }

struct FPlaceScreen: View {
    let app: AppModel
    let pid: String
    let fid: String
    let rid: String
    @State private var first: String
    @State private var off = ""          // a wardrobe's distance from the corner; "" = in the corner
    @State private var keep = false
    @State private var fitted: Furniture? = nil
    @FocusState private var focus: PF?

    init(app: AppModel, pid: String, fid: String, rid: String) {
        self.app = app; self.pid = pid; self.fid = fid; self.rid = rid
        let p = Store.shared.get(pid)
        let room = p?.rooms.first { $0.id == rid }
        let ids = room.map { Geo.walls($0, AppSettings.shared.angleSnap).map(\.id) } ?? []
        let taken = p?.furniture.filter { $0.roomId == rid && $0.id != fid }.flatMap(\.walls) ?? []
        _first = State(initialValue: ids.first { !taken.contains($0) } ?? ids.first ?? "A")
    }

    var body: some View {
        if let p = Store.shared.get(pid), let f0 = p.furniture.first(where: { $0.id == fid }), let room = p.rooms.first(where: { $0.id == rid }) {
            let s = AppSettings.shared, snap = s.angleSnap, ws = s.workshop
            let wl = Geo.walls(room, snap)
            let ids = wl.map(\.id)
            let others = p.furniture.filter { $0.roomId == room.id && $0.id != f0.id }
            let taken = others.flatMap(\.walls)
            let ward = f0.kind == "wardrobe"
            let offMm: Int? = { let v = mm(off); return v > 0 ? v : nil }()
            let f = fitted ?? f0
            let on = placeWalls(f, ids, first)
            let len = { (id: String) in wallLen(room, snap, id) }
            let roomH = room.dim("H").v
            let issues = fitIssues(f, on, len, roomH, ws, off: offMm)
            let roomName = p.floors.first { $0.id == room.floorId }.map { floorName($0) } ?? dn(room.name)
            let clash = on.first { taken.contains($0) }
            FPage(eyebrow: dn(f0.name) + " → " + roomName, title: tr("fz.toRoom"), back: { app.pop() }) {
                PlacePlan(room: room, f: f, on: on, off: offMm, snap: snap)
                T(tr(ward ? "fz.wallQ" : "fz.first"), ui(15, 700))
                FlowLayout(spacing: 8) {
                    ForEach(wl, id: \.id) { w in
                        FChip(label: tr("kt.wallN", ["w": w.id]) + (len(w.id).map { " · \($0)" } ?? ""), on: w.id == first) { if w.id != first { first = w.id; reset() } }
                    }
                }
                let next = on.dropFirst().filter { $0 != ISLAND }
                if !ward && !next.isEmpty { T(tr("fz.nextWalls", ["w": next.joined(separator: ", ")]), ui(13, 400, G.ink2, lh: 1.4)) }
                if let clash, let who = others.first(where: { $0.walls.contains(clash) }) {
                    T(tr("kt.wallTaken", ["w": clash, "n": dn(who.name)]), ui(12.5, 500, G.amberInk, lh: 1.4))
                }
                if ward {
                    T(tr("fz.offset"), ui(15, 700))
                    HStack(spacing: 8) {
                        FChip(label: tr("fz.corner"), on: offMm == nil) { off = ""; reset() }
                        GField(label: nil, value: Binding(get: { off }, set: { off = String($0.filter { $0.isASCII && $0.isNumber }.prefix(5)); reset() }), placeholder: "0",
                               focus: $focus, me: .off, submit: .done, onSubmit: { focus = nil }, labelRight: nil, number: true)
                    }
                }
                if !issues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 8) {
                            MIcon("alert", keep ? G.amberInk : G.err, 18, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(issues.enumerated()), id: \.offset) { _, i in
                                    let vars: [String: Any] = Dictionary(uniqueKeysWithValues: i.vars.map { k, v in (k, k == "n" ? dn(v) : v) })
                                    T(tr(i.key, vars), ui(13.5, 600, keep ? G.amberInk : G.err, lh: 1.35))
                                }
                            }
                        }
                        if keep { T(tr("fz.kept"), ui(12.5, 500, G.amberInk, lh: 1.35)) }
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(keep ? G.amberWash : G.errWash))
                    let heightOnly = issues.allSatisfy { $0.key == "fz.high" }
                    HStack(spacing: 8) {
                        GBtn(tr(heightOnly ? "fz.fitH" : "fz.fit"), kind: .secondary, height: 46, corner: 14, fontSize: 14) {
                            fitted = fitTo(placed(f, on, room.id, room.floorId, off: offMm), on, len, roomH, ws, off: offMm); keep = false; app.say("fz.fitted")
                        }
                        .accessibilityIdentifier("fz.fit")
                        GBtn(tr("fz.keep"), kind: keep ? .primary : .secondary, height: 46, corner: 14, fontSize: 14) { keep = true }.accessibilityIdentifier("fz.keep")
                    }
                }
            } footer: {
                GBtn(tr("fz.placeHere"), enabled: issues.isEmpty || keep) {
                    if !issues.isEmpty && !keep { app.say("fz.pickFirst", kind: .error); return }
                    let g = placed(f, on, room.id, room.floorId, off: offMm, keep: !issues.isEmpty, len: len)
                    Store.shared.update(pid) { pr in
                        pr.furniture = pr.furniture.map { $0.id == f0.id ? g : $0 }
                        if pr.stage == "measure" { pr.stage = "design" }
                    }
                    KitOps.shared.sel = nil; KitOps.shared.tick += 1
                    app.replaceTop(designer(pid, g))
                    app.say("fz.placed", ["n": dn(f0.name), "r": roomName])
                }
                .accessibilityIdentifier("fz.place")
            }
        }
    }

    private func reset() { fitted = nil; keep = false }
}

/// The room from above with the piece's place: each side along its wall (red past the wall's end), the wardrobe at its distance.
private struct PlacePlan: View {
    let room: Room
    let f: Furniture
    let on: [String]
    let off: Int?
    let snap: Bool
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Canvas { ctx, size in
            let wl = Geo.walls(room, snap)
            guard !wl.isEmpty else { return }
            let runs = runsOf(f) { _ in nil }
            let xs = wl.flatMap { [$0.p0.x, $0.p1.x] }, ys = wl.flatMap { [$0.p0.y, $0.p1.y] }
            let x0 = xs.min()!, y0 = ys.min()!
            let spanX = max(xs.max()! - x0, 1), spanY = max(ys.max()! - y0, 1)
            let pad: CGFloat = 34
            let k = min((size.width - 2 * pad) / spanX, (size.height - 2 * pad) / spanY)
            let ox = (size.width - spanX * k) / 2, oy = (size.height - spanY * k) / 2
            func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + (x - x0) * k, y: oy + (y - y0) * k) }
            var outline = Path()
            for (i, w) in wl.enumerated() { let a = P(w.p0.x, w.p0.y); if i == 0 { outline.move(to: a) } else { outline.addLine(to: a) } }
            outline.closeSubpath()
            ctx.fill(outline, with: .color(Color(argb: 0xFFF3F6FB)))
            ctx.stroke(outline, with: .color(Color(argb: 0xFF0F172A)), lineWidth: 5)
            func quad(_ q: [CGPoint], _ c: Color) {
                var pp = Path(); pp.move(to: q[0]); q.dropFirst().forEach { pp.addLine(to: $0) }; pp.closeSubpath()
                ctx.fill(pp, with: .color(c.opacity(0.22))); ctx.stroke(pp, with: .color(c), lineWidth: 2)
            }
            let blue = Color(argb: 0xFF3550E0), red = Color(argb: 0xFFDC2626)
            let sidesOn = on.filter { $0 != ISLAND }.count
            for w in wl {
                let dx = w.p1.x - w.p0.x, dy = w.p1.y - w.p0.y, l = max(hypot(dx, dy), 1)
                let ux = dx / l, uy = dy / l, nx = -uy, ny = ux              // into the room
                let mid = P(w.p0.x + dx / 2, w.p0.y + dy / 2)
                ctx.draw(Text(w.id).font(.system(size: 12)).foregroundColor(Color(argb: 0xFF475569)), at: CGPoint(x: mid.x - nx * 20, y: mid.y - ny * 20))
                // the piece along this wall
                func bar(_ a: Double, _ b: Double, _ depth: Double, _ over: Bool) {
                    quad([P(w.p0.x + ux * a, w.p0.y + uy * a), P(w.p0.x + ux * b, w.p0.y + uy * b),
                          P(w.p0.x + ux * b + nx * depth, w.p0.y + uy * b + ny * depth), P(w.p0.x + ux * a + nx * depth, w.p0.y + uy * a + ny * depth)], over ? red : blue)
                }
                guard let i = on.firstIndex(of: w.id) else { continue }
                if f.kind == "wardrobe" {
                    guard let m = wardOfF(f) else { continue }
                    let a = Double(off ?? W_GAP_SIDE)
                    bar(a, a + Double(m.w), Double(m.d), a + Double(m.w) > l + 1)
                } else {
                    guard i < runs.count else { continue }
                    let r = runs[i]
                    var need = runEnd(f, r)
                    if f.roomId == nil, let s = f.free?.sides, i < s.count { need = max(s[i], need) }
                    // a corner kitchen's first side ends in the corner
                    let a = i == 0 && sidesOn > 1 ? max(0, l - Double(need)) : 0
                    bar(a, a + Double(need), 600, Double(need) > l + 1)
                }
            }
            // the island or peninsula, 900 out in front of the first side
            if on.contains(ISLAND) && f.kind == "kitchen", let w = wl.first(where: { $0.id == on[0] }) {
                let isl = Double(f.modules.filter { $0.wall == ISLAND && !isUpper($0) }.reduce(0) { $0 + $1.w })
                if isl > 0 {
                    let dx = w.p1.x - w.p0.x, dy = w.p1.y - w.p0.y, l = max(hypot(dx, dy), 1)
                    let ux = dx / l, uy = dy / l, nx = -uy, ny = ux
                    let a = (l - isl) / 2, b = a + isl, d0 = 1500.0, d1 = 2100.0
                    quad([P(w.p0.x + ux * a + nx * d0, w.p0.y + uy * a + ny * d0), P(w.p0.x + ux * b + nx * d0, w.p0.y + uy * b + ny * d0),
                          P(w.p0.x + ux * b + nx * d1, w.p0.y + uy * b + ny * d1), P(w.p0.x + ux * a + nx * d1, w.p0.y + uy * a + ny * d1)], blue)
                }
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(shape.fill(G.glass(0.6)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
