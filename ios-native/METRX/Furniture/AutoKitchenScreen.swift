import SwiftUI
import UIKit
import Observation

/*
 * "Oshxona yasash" (Joylan ideas, approved 26 Oct 2026; the mockup's first screen; Android ui/furniture/
 * AutoKitchenScreen.kt): for a measured room, 1. the walls on its plan (their number gives the layout; a wall with a
 * door takes none), 2. the layout chips, 3. the appliances, 4. the six design styles as cards, each a kitchen built for
 * this room (Core/AutoKitchenGen.swift) with its 3D picture, units and metres, price (Advanced), errors and warnings,
 * and why it was built so. "Tanlash" puts it in the room (the room's kitchen before goes; Undo brings it back).
 */

/// The screen's choices and the kitchens built for them, one a style, kept while the choices stay.
@Observable final class AKState {
    var walls: [String] = []
    var layout = "line"
    var app = AKApp()
    var focus = "twotone"
    /// The style placed on this visit, and the kitchens it made.
    var placed: String? = nil
    var placedIds: [String] = []
    var why: Set<String> = []
    var started = false
    @ObservationIgnored private(set) var key = ""
    @ObservationIgnored private(set) var plans: [String: AKPlan] = [:]
    @ObservationIgnored private(set) var kitchens: [String: [Furniture]] = [:]

    /// The plans and kitchens for the room as it is and the choices made; the key of this set (its pictures' too).
    func ensure(_ R: AKRoom, _ room: Room, _ ws: Workshop, snap: Bool) -> String {
        let k = [walls.joined(separator: ","), layout, app.fridge, app.oven, app.dw ? "1" : "0", app.hood, cardSig(room), cardSig(ws), snap ? "s" : ""]
            .joined(separator: "|")
        if k == key { return k }
        key = k
        plans = [:]; kitchens = [:]
        guard !walls.isEmpty else { return k }
        for p in DESIGN_PRESETS {
            guard let pl = akGenerate(R, walls: walls, layout: layout, app: app, preset: p.id) else { continue }
            plans[p.id] = pl
            kitchens[p.id] = akFurniture(pl, room, p.id, ws, snap: snap)
        }
        return k
    }
}

/// A painted card's piece: a kitchen off its room, on the made-up room's walls (the 2D card drawing's).
private func akPaintable(_ f: Furniture) -> Furniture {
    var g = onWalls(f, freeWalls(f.layout, ""))
    g.roomId = nil; g.free = nil; g.pose = nil; g.ws = ""
    return g
}

/// Whether a card's wait is over (its picture came, or the time ran out).
private final class AKOnce { var over = false }

/// The style cards' pictures by key: the lit 3D of the kitchen in its room (Three/CardShots.swift renderRoom), one at a
/// time, the drawn card when the 3D gives none in time. Main thread only.
@Observable final class AKPics {
    static let shared = AKPics()
    private(set) var pics: [String: UIImage] = [:]
    @ObservationIgnored private var queue: [(String, [Furniture], Room)] = []
    @ObservationIgnored private var ctx: (Workshop, [Mat], Bool)? = nil
    @ObservationIgnored private var running = false
    @ObservationIgnored private var fails = 0

    /// The pictures jobs ask for (key, kitchens) in room, the latest asked first; the ones made stay.
    func want(_ jobs: [(String, [Furniture])], _ room: Room, _ ws: Workshop, _ mats: [Mat], snap: Bool) {
        if pics.count > 60 { pics = [:] }
        ctx = (ws, mats, snap)
        queue = jobs.filter { pics[$0.0] == nil && !$0.1.isEmpty }.map { ($0.0, $0.1, room) }
        run()
    }

    private func run() {
        guard !running, !queue.isEmpty, let c = ctx else { return }
        running = true
        let job = queue.removeFirst()
        let tier = Quality3.current(), spec = cardSpec(tier)
        let once = AKOnce()
        let finish: (UIImage?) -> Void = { [weak self] img in
            DispatchQueue.main.async {
                guard let self, !once.over else { return }
                once.over = true
                self.done(job.0, img, job.1, c.0, c.1, spec)
            }
        }
        if fails >= 2 { finish(nil); return }
        CardRenderer.shared.renderRoom(job.1, job.2, c.0, c.1, spec, tier, snap: c.2, finish)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { finish(nil) }
    }

    private func done(_ key: String, _ img: UIImage?, _ fs: [Furniture], _ ws: Workshop, _ mats: [Mat], _ spec: CardSpec) {
        if let img { fails = 0; pics[key] = cardFit(img, spec) }
        else {
            fails += 1
            if let f = fs.first { pics[key] = cardPainted(akPaintable(f), ws, mats, spec) }
        }
        running = false
        run()
    }
}

/// A check's text in the app's language: metres with one decimal, mm whole, words by their keys.
func akCheckText(_ c: AKCheck) -> String {
    let en = AppSettings.shared.lang == .en
    var v: [String: Any] = [:]
    for (k, x) in c.vars {
        switch x {
        case .m(let d): let s = String(format: "%.1f", d / 1000); v[k] = en ? s : s.replacingOccurrences(of: ".", with: ",")
        case .mm(let n): v[k] = n
        case .word(let w): v[k] = tr(w)
        case .raw(let s): v[k] = s
        }
    }
    return tr(c.key, v)
}

/// The plan's colours for what a run holds (the mockup's legend).
private func akKindColor(_ k: String) -> (Color, Color)? {
    switch k {
    case "sink": return (Color(argb: 0x332E9BD6), Color(argb: 0xFF2E9BD6))
    case "hob", "hobOven": return (Color(argb: 0x2EE0662F), Color(argb: 0xFFE0662F))
    case "fridgeFS", "fridgeBI": return (Color(argb: 0x4D5B6B84), Color(argb: 0xFF5B6B84))
    case "ovenT", "pantry": return (Color(argb: 0x428A96AB), Color(argb: 0xFF8A96AB))
    case "dw": return (Color(argb: 0x2E139C9C), Color(argb: 0xFF139C9C))
    case "filler", "cfill": return nil
    default: return (G.glass(0.9), G.ink3.opacity(0.55))
    }
}

/// Where the plan is drawn: mm to points.
private struct AKFit {
    let k: CGFloat, ox: CGFloat, oy: CGFloat
    func p(_ q: AKPt) -> CGPoint { CGPoint(x: ox + CGFloat(q.x) * k, y: oy + CGFloat(q.y) * k) }
}

/// The room's corners' bounds, mm.
private func akBounds(_ R: AKRoom) -> (Double, Double, Double, Double) {
    var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
    for w in R.walls {
        for q in [w.at(0), w.at(w.L)] { x0 = min(x0, q.x); y0 = min(y0, q.y); x1 = max(x1, q.x); y1 = max(y1, q.y) }
    }
    if x0 > x1 { return (0, 0, 1000, 1000) }
    return (x0, y0, x1, y1)
}

private let AK_PAD = 520.0

private func akFit(_ R: AKRoom, _ size: CGSize) -> AKFit {
    let (x0, y0, x1, y1) = akBounds(R)
    let w = x1 - x0 + 2 * AK_PAD, h = y1 - y0 + 2 * AK_PAD
    let k = min(size.width / CGFloat(w), size.height / CGFloat(h))
    let ox = (size.width - CGFloat(w) * k) / 2 + CGFloat(AK_PAD - x0) * k
    let oy = (size.height - CGFloat(h) * k) / 2 + CGFloat(AK_PAD - y0) * k
    return AKFit(k: k, ox: ox, oy: oy)
}

/// The wall nearest the tap, within 36 points.
private func akWallAt(_ R: AKRoom, _ fit: AKFit, _ pt: CGPoint) -> String? {
    var best: (String, CGFloat)? = nil
    for w in R.walls {
        let a = fit.p(w.at(0)), b = fit.p(w.at(w.L))
        let dx = b.x - a.x, dy = b.y - a.y, l2 = max(1, dx * dx + dy * dy)
        let t = max(0, min(1, ((pt.x - a.x) * dx + (pt.y - a.y) * dy) / l2))
        let d = hypot(pt.x - (a.x + dx * t), pt.y - (a.y + dy * t))
        if d < 36 && (best == nil || d < best!.1) { best = (w.id, d) }
    }
    return best?.0
}

/// Four corners of a strip along wall w from a to b, d0 to d1 into the room.
private func akStrip(_ R: AKRoom, _ fit: AKFit, _ w: String, _ a: Double, _ b: Double, _ d0: Double, _ d1: Double) -> Path {
    var p = Path()
    p.addLines([fit.p(R.at(w, a, d0)), fit.p(R.at(w, b, d0)), fit.p(R.at(w, b, d1)), fit.p(R.at(w, a, d1))])
    p.closeSubpath()
    return p
}

/// The room's plan: the floor, the focused kitchen's lower units, the walls (picked ones blue, a door's grey), the
/// windows, doors, water and gas.
private func akDrawPlan(_ ctx: GraphicsContext, _ R: AKRoom, _ sel: [String], _ plan: AKPlan?, _ fit: AKFit) {
    var floor = Path()
    floor.addLines(R.walls.map { fit.p($0.at(0)) })
    floor.closeSubpath()
    ctx.fill(floor, with: .color(G.solid))
    if let plan {
        for r in plan.runs {
            for e in r.base {
                guard let c = akKindColor(e.k) else { continue }
                let path = akStrip(R, fit, r.w, e.a, e.b, 0, 600)
                ctx.fill(path, with: .color(c.0))
                ctx.stroke(path, with: .color(c.1), lineWidth: 1)
            }
        }
    }
    let wallW = max(5, 160 * fit.k)
    for w in R.walls {
        let on = sel.contains(w.id)
        let col: Color = on ? G.cobalt : R.blocked(w.id) ? G.ink3.opacity(0.45) : G.ink.opacity(0.7)
        var p = Path()
        p.move(to: fit.p(w.at(0, -80))); p.addLine(to: fit.p(w.at(w.L, -80)))
        ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: wallW, lineCap: .square))
    }
    for o in R.windows {
        var p = Path()
        p.move(to: fit.p(R.at(o.wall, o.a, -80))); p.addLine(to: fit.p(R.at(o.wall, o.b, -80)))
        ctx.stroke(p, with: .color(Color(argb: 0xFF7CC4F0)), lineWidth: wallW * 0.7)
    }
    for o in R.doors {
        var p = Path()
        p.move(to: fit.p(R.at(o.wall, o.a, -80))); p.addLine(to: fit.p(R.at(o.wall, o.b, -80)))
        ctx.stroke(p, with: .color(G.solid), lineWidth: wallW + 1)
        var leaf = Path()
        leaf.move(to: fit.p(R.at(o.wall, o.b, 0))); leaf.addLine(to: fit.p(R.at(o.wall, o.b, o.b - o.a)))
        ctx.stroke(leaf, with: .color(G.ink3), lineWidth: 1.5)
    }
    for (s, rgb) in [(R.water, 0xFF1E88E5 as UInt32), (R.gas, 0xFFE0A100 as UInt32)] {
        guard let s else { continue }
        let c = fit.p(R.at(s.wall, s.t, 120))
        let r = max(5, 110 * fit.k)
        let dot = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        ctx.fill(dot, with: .color(Color(argb: rgb)))
        ctx.stroke(dot, with: .color(.white), lineWidth: 2)
    }
}

/* ---------------- the screen ---------------- */

struct AutoKitchenScreen: View {
    let app: AppModel
    let pid: String
    let rid: String
    @State private var st = AKState()

    var body: some View {
        if let p = Store.shared.get(pid), let room = p.rooms.first(where: { $0.id == rid }) {
            let s = AppSettings.shared, snap = s.angleSnap
            let R = akRoomOf(room, snap)
            let key = st.ensure(R, room, s.workshop, snap: snap)
            let en = s.lang == .en
            let sub = tr("ak.sub", ["r": roomTitle(p, room), "a": Geo.fmtLen(room.dim("A").v, .m, en), "b": Geo.fmtLen(room.dim("B").v, .m, en)])
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
                    BarTitle(title: tr("ak.title"), eyebrow: dn(p.name), sub: sub)
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let pl = st.placed, p.furniture.contains(where: { st.placedIds.contains($0.id) }) {
                            AKPlacedCard(app: app, p: p, rid: rid, preset: pl, ids: st.placedIds, plan: st.plans[pl])
                        }
                        AKPlanCard(R: R, st: st, plan: st.plans[st.placed ?? st.focus], onTap: { tapWall(R, $0) })
                        AKLayoutCard(st: st) { setLayout(R, $0) }
                        AKAppCard(st: st)
                        AKStep(n: 4, title: tr("ak.s4"), meta: s.advanced ? tr("ak.priceAdv") : nil)
                        T(tr("ak.s4hint"), ui(12.5, 400, G.ink2, lh: 1.4)).padding(.horizontal, 2)
                        if p.furniture.contains(where: { $0.kind == "kitchen" && $0.roomId == room.id && !st.placedIds.contains($0.id) }) {
                            T(tr("ak.replace"), ui(12.5, 500, G.amberInk, lh: 1.4))
                                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.amberWash))
                        }
                        ForEach(DESIGN_PRESETS.map(\.id), id: \.self) { id in
                            AKStyleCard(p: p, preset: id, plan: st.plans[id], fs: st.kitchens[id] ?? [], pic: AKPics.shared.pics[key + "|" + id],
                                        placed: st.placed == id, open: st.why.contains(id),
                                        onPic: { st.focus = id }, onWhy: { toggleWhy(id) }, onPick: { pick(p, room, id) })
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 28)
                }
            }
            .onAppear { start(R); pictures(key, room) }
            .onChange(of: key) { _, k in pictures(k, room) }
        }
    }

    private func roomTitle(_ p: Project, _ r: Room) -> String { p.floors.first { $0.id == r.floorId }.map { floorName($0) } ?? dn(r.name) }

    /// The first visit: the walls the kitchen usually takes.
    private func start(_ R: AKRoom) {
        if st.started { return }
        st.started = true
        st.walls = akStartWalls(R)
        st.layout = akDeriveLayout(R, st.walls)
    }

    private func pictures(_ key: String, _ room: Room) {
        let s = AppSettings.shared
        let order = [st.focus] + DESIGN_PRESETS.map(\.id).filter { $0 != st.focus }
        let jobs: [(String, [Furniture])] = order.map { (key + "|" + $0, st.kitchens[$0] ?? []) }
        AKPics.shared.want(jobs, room, s.workshop, s.mats, snap: s.angleSnap)
    }

    private func tapWall(_ R: AKRoom, _ w: String) {
        if R.blocked(w) { app.say("ak.doorWall", kind: .info); return }
        if !akFree(R, w) { app.say("ak.shortWall", kind: .info); return }
        let ws = akTapWall(st.walls, w)
        if ws.isEmpty { app.say("ak.oneWall", kind: .info); return }
        st.walls = ws
        st.layout = akDeriveLayout(R, ws)
    }

    private func setLayout(_ R: AKRoom, _ lay: String) {
        if lay == st.layout { return }
        guard let ws = akWallsFor(R, lay, st.walls) else { app.say("ak.noLayout", kind: .info); return }
        st.layout = lay
        st.walls = ws
    }

    private func toggleWhy(_ id: String) {
        if st.why.contains(id) { st.why.remove(id) } else { st.why.insert(id); st.focus = id }
    }

    /// "Tanlash": the style's kitchens go into the room instead of the kitchens there; Undo puts the order back.
    private func pick(_ p: Project, _ room: Room, _ id: String) {
        if st.placed == id, let f = p.furniture.first(where: { st.placedIds.contains($0.id) }) {
            KitOps.shared.sel = nil
            app.push(.kitchen(pid: p.id, fid: f.id, wall: nil, d3: true))
            return
        }
        guard let plan = st.plans[id], app.once() else { return }
        let s = AppSettings.shared
        let before = p
        let others = p.furniture.filter { $0.kind == "kitchen" && $0.roomId != room.id }.count
        let fs = akFurniture(plan, room, id, s.workshop, snap: s.angleSnap, now: nowMs()) { i in tr("kt.nameN", ["n": others + i + 1]) }
        Store.shared.update(p.id) { pr in pr.furniture.removeAll { $0.kind == "kitchen" && $0.roomId == room.id } }
        for f in fs { addPiece(p.id, f) }
        st.placed = id
        st.placedIds = fs.map(\.id)
        st.focus = id
        let state = st
        app.say("ak.placedT", ["n": tr("lk.p." + id)], action: "common.undo") {
            Store.shared.update(before.id) { $0 = before }
            state.placed = nil
            state.placedIds = []
            AppModel.shared.say("ak.undone", kind: .info)
        }
    }
}

/* ---------------- the steps ---------------- */

/// A step's heading: its number, title and a note on the right.
private struct AKStep: View {
    let n: Int
    let title: String
    var meta: String? = nil
    var body: some View {
        HStack(spacing: 8) {
            T("\(n)", ui(12.5, 800, .white), align: .center).frame(width: 24, height: 24).background(Circle().fill(G.cobalt))
            T(title, ui(16, 800)).frame(maxWidth: .infinity, alignment: .leading)
            if let meta { T(meta, ui(12, 600, G.ink3), lines: 1) }
        }
    }
}

/// 1. The plan: tap a wall (or its chip) to take it or leave it.
private struct AKPlanCard: View {
    let R: AKRoom
    let st: AKState
    let plan: AKPlan?
    let onTap: (String) -> Void
    var body: some View {
        let bd = akBounds(R)
        let aspect = CGFloat((bd.2 - bd.0 + 2 * AK_PAD) / max(1, bd.3 - bd.1 + 2 * AK_PAD))
        VStack(alignment: .leading, spacing: 10) {
            AKStep(n: 1, title: tr("ak.s1"), meta: tr("ak.wallsMeta", ["l": tr("ak.l." + st.layout), "n": st.walls.count]))
            GeometryReader { geo in
                let fit = akFit(R, geo.size)
                Canvas { ctx, _ in akDrawPlan(ctx, R, st.walls, plan, fit) }
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { pt in if let w = akWallAt(R, fit, pt) { onTap(w) } }
            }
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: 300)
            .accessibilityHidden(true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(R.walls.map(\.id), id: \.self) { w in
                        FChip(label: tr("kt.wallN", ["w": w]), on: st.walls.contains(w)) { onTap(w) }
                            .opacity(akFree(R, w) ? 1 : 0.45)
                            .accessibilityIdentifier("ak.wall." + w)
                    }
                }
            }
            AKLegend()
            T(tr("ak.s1hint"), ui(12, 400, G.ink2, lh: 1.4))
        }
        .padding(14)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// The plan's legend.
private struct AKLegend: View {
    var body: some View {
        let items: [(String, UInt32)] = [("ak.leg.sink", 0xFF2E9BD6), ("ak.leg.hob", 0xFFE0662F), ("ak.leg.fridge", 0xFF5B6B84),
                                         ("ak.leg.tall", 0xFF8A96AB), ("ak.leg.dw", 0xFF139C9C), ("ak.water", 0xFF1E88E5), ("ak.gas", 0xFFE0A100)]
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items, id: \.0) { k, c in
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(argb: c)).frame(width: 10, height: 10)
                        T(tr(k), ui(11.5, 500, G.ink2), lines: 1)
                    }
                }
            }
        }
    }
}

/// 2. The layout.
private struct AKLayoutCard: View {
    let st: AKState
    let onPick: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AKStep(n: 2, title: tr("ak.s2"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AK_LAYOUTS, id: \.self) { l in
                        FChip(label: tr("ak.l." + l), on: st.layout == l) { onPick(l) }.accessibilityIdentifier("ak.lay." + l)
                    }
                }
            }
        }
        .padding(14)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// 3. The appliances.
private struct AKAppCard: View {
    let st: AKState
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AKStep(n: 3, title: tr("ak.s3"))
            AKAppRow(label: tr("ak.a.fridge"), opts: [("bi", "ak.a.fridge.bi"), ("fs", "ak.a.fridge.fs")], cur: st.app.fridge) { st.app.fridge = $0 }
            AKAppRow(label: tr("ak.a.oven"), opts: [("hob", "ak.a.oven.hob"), ("tall", "ak.a.oven.tall")], cur: st.app.oven) { st.app.oven = $0 }
            AKAppRow(label: tr("ak.a.dw"), opts: [("1", "ak.a.dw.on"), ("0", "ak.a.dw.off")], cur: st.app.dw ? "1" : "0") { st.app.dw = $0 == "1" }
            AKAppRow(label: tr("ak.a.hood"), opts: [("built", "ak.a.hood.built"), ("angled", "ak.a.hood.angled")], cur: st.app.hood) { st.app.hood = $0 }
        }
        .padding(14)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

private struct AKAppRow: View {
    let label: String
    let opts: [(String, String)]
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            T(label, ui(13, 600, G.ink2))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(opts, id: \.0) { v, k in FChip(label: tr(k), on: cur == v) { if cur != v { onPick(v) } } }
                }
            }
        }
    }
}

/* ---------------- 4. the style cards ---------------- */

/// A style's card: the picture, name and line, units and metres, price (Advanced), the checks' count, why it was built
/// so, and "Tanlash".
private struct AKStyleCard: View {
    let p: Project
    let preset: String
    let plan: AKPlan?
    let fs: [Furniture]
    let pic: UIImage?
    let placed: Bool
    let open: Bool
    let onPic: () -> Void
    let onWhy: () -> Void
    let onPick: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let pic { Image(uiImage: pic).resizable().scaledToFill() } else { CardShimmer() }
            }
            .frame(maxWidth: .infinity).frame(height: 190).clipped()
            .contentShape(Rectangle())
            .onTapGesture(perform: onPic)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    T(tr("lk.p." + preset), ui(16, 800), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                    if placed { T(tr("ak.on"), ui(11.5, 700, G.green), lines: 1) }
                }
                T(tr("lk.p." + preset + ".d"), ui(12.5, 400, G.ink2), lines: 2)
                if let plan { AKCardFacts(p: p, plan: plan, fs: fs) } else { T(tr("ak.noFit"), ui(13, 600, G.amberInk)) }
                if let plan { AKWhy(plan: plan, open: open, onToggle: onWhy) }
                GBtn(placed ? tr("ak.placed") : tr("ak.pick"), kind: placed ? .secondary : .primary, enabled: plan != nil, height: 46, corner: 15, fontSize: 15) { onPick() }
                    .padding(.top, 4)
                    .accessibilityIdentifier("ak.pick." + preset)
            }
            .padding(12)
        }
        .clipShape(shape)
        .glassCard(shape, fill: G.glass(0.6))
        .overlay(shape.strokeBorder(placed ? G.green : Color.clear, lineWidth: 2))
    }
}

/// Units and metres, the price (Advanced), the errors and warnings.
private struct AKCardFacts: View {
    let p: Project
    let plan: AKPlan
    let fs: [Furniture]
    var body: some View {
        let s = AppSettings.shared, en = s.lang == .en
        let meta = tr("ak.meta", ["n": akUnits(fs), "m": metres1(akRunMm(fs), en)])
        let dot: Color = plan.err > 0 ? G.err : plan.warn > 0 ? G.amberInk : G.green
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                T(meta, ui(12.5, 600, G.ink2), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                if s.advanced, !fs.isEmpty {
                    let pr = priceOf(fs, p.fprice, s.workshop, s.mats, s.hws)
                    T(tr("ak.price", ["v": Money.str(pr.price, p.precision, en) + " " + Money.cur(p.currency)]), num(14, 800), lines: 1)
                }
            }
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 8, height: 8)
                T(tr("ak.errWarn", ["e": plan.err, "w": plan.warn]), ui(12.5, 600, G.ink2), lines: 1)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// "Nega shunday qurildi": the lead and every check.
private struct AKWhy: View {
    let plan: AKPlan
    let open: Bool
    let onToggle: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                T((open ? "▾ " : "▸ ") + tr("ak.why"), ui(13.5, 700, G.cobalt2)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 36).contentShape(Rectangle())
            .pressable(0.99, onToggle)
            .accessibilityAddTraits(.isButton)
            if open {
                T(tr("ak.lead") + (plan.noP ? " " + tr("ak.leadNoP") : ""), ui(12.5, 400, G.ink2, lh: 1.4))
                ForEach(Array(plan.checks.enumerated()), id: \.offset) { _, c in AKCheckRow(c: c) }
            }
        }
    }
}

private struct AKCheckRow: View {
    let c: AKCheck
    var body: some View {
        let col: Color = c.st == "err" ? G.err : c.st == "warn" ? G.amberInk : G.green
        let mark = c.st == "ok" ? "✓" : c.st == "warn" ? "!" : "✕"
        HStack(alignment: .top, spacing: 8) {
            T(mark, ui(11, 800, col), align: .center).frame(width: 18, height: 18).background(Circle().fill(col.opacity(0.14)))
            T(akCheckText(c), ui(12.5, 400, G.ink2, lh: 1.38)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The style placed: its 3D, the three prices (Advanced) and the client's 3D file.
private struct AKPlacedCard: View {
    let app: AppModel
    let p: Project
    let rid: String
    let preset: String
    let ids: [String]
    let plan: AKPlan?
    var body: some View {
        let s = AppSettings.shared
        let fs = p.furniture.filter { ids.contains($0.id) }
        VStack(alignment: .leading, spacing: 8) {
            T(tr("lk.p." + preset), ui(17, 800))
            if let plan { AKCardFacts(p: p, plan: plan, fs: fs) }
            GBtn(tr("ak.open3d"), icon: "cube", height: 48, corner: 16, fontSize: 15) {
                if let f = fs.first { KitOps.shared.sel = nil; app.push(.kitchen(pid: p.id, fid: f.id, wall: nil, d3: true)) }
            }
            .accessibilityIdentifier("ak.open3d")
            HStack(spacing: 8) {
                if s.advanced {
                    GBtn(tr("ak.tiers"), kind: .secondary, height: 46, corner: 15, fontSize: 14.5) {
                        let pid = p.id
                        app.popTo { r in if case .project(let id, _, _, _) = r { return id == pid }; return false }
                        app.setProjectTab("price")
                    }
                    .accessibilityIdentifier("ak.tiers")
                }
                GBtn(tr("ak.share"), kind: .secondary, icon: "send", height: 46, corner: 15, fontSize: 14.5) { app.sheet = .share3d(pid: p.id, rid: rid) }
                    .accessibilityIdentifier("ak.share")
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// The way in from a measured kitchen room: the dashed row of the order's rooms and the gallery.
struct AutoKitchenEntry: View {
    let app: AppModel
    let pid: String
    let rid: String
    var body: some View {
        HStack(spacing: 12) {
            MIcon("kitchen", G.cobalt, 24, 2)
            VStack(alignment: .leading, spacing: 1) {
                T(tr("ak.entry"), ui(14.5, 700, G.cobalt2))
                T(tr("ak.entryS"), ui(12.5, 400, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .dashedGlass(16)
        .pressable(0.98) { app.push(.autoKitchen(pid: pid, rid: rid)) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("ak.entry")
    }
}
