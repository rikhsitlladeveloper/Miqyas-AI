import SwiftUI
import UIKit
import Observation

/*
 * Choosing a room kit (22 Oct 2026; Android ui/elec/EGallery.kt): the gallery of kits grouped by room, each card drawn
 * by the app from the kit put in a sample room; then a few questions (the main light, the extras, which room), the kit
 * shown in the sample room all along.
 */

private var en: Bool { AppSettings.shared.lang == .en }

/// The sample room a kit of kind is shown in: the door on wall D near the eye, the sink's water on wall A for a kitchen
/// or bathroom.
private func sampleRoom(_ kind: String) -> Room {
    let dims: (Int, Int, Int) = kind == "bath" ? (2600, 2200, 2600) : kind == "hall" ? (3800, 1800, 2700) : (4200, 3400, 2700)
    let L = dims.0, W = dims.1, H = dims.2
    var ops: [Opening] = [Opening(id: "d", type: "door", wall: "D", w: 800, h: 2100, off: 250)]
    if kind == "hall" { ops.append(Opening(id: "d2", type: "door", wall: "B", w: 800, h: 2100, off: 500)) }
    if kind == "office" { ops.append(Opening(id: "w", type: "window", wall: "A", w: 1400, h: 1400, off: L - 1900, sill: 900)) }
    else if kind != "bath" && kind != "hall" { ops.append(Opening(id: "w", type: "window", wall: "C", w: 1400, h: 1400, off: 1400, sill: 900)) }
    var pts: [SitePoint] = []
    if kind == "kitchen" { pts = [SitePoint(id: "c", t: "cold", wall: "A", off: tInt(Double(L) * 0.38), h: 550)] }
    if kind == "bath" { pts = [SitePoint(id: "c", t: "cold", wall: "A", off: 700, h: 600)] }
    var r = Room(id: "sample", floorId: "sw", name: "")
    r.dims = ["A": Dim(v: L), "B": Dim(v: W), "H": Dim(v: H), "T": Dim(v: 120, src: "default")]
    r.openings = ops
    r.points = pts
    return r
}

/// A kit in its sample room: the room, its devices placed, their circuits and routes from the door.
struct KPreview {
    let c: ECtx
    let devs: [ElecDev]
    let calc: ElecCalc
}

func kitPreview(_ k: ElecKit, _ o: KitOpts) -> KPreview? {
    let r = sampleRoom(k.kind)
    var p0 = Project(id: "sample", name: "")
    let wt = k.kind == "kitchen" ? "kitchen" : k.kind == "bath" ? "bath" : "room"
    p0.floors = [Workspace(id: "sw", name: "", type: wt)]
    p0.rooms = [r]
    p0.industry = "elec"
    p0.elec = ElecOrder(rooms: [ElecRoom(roomId: "sample", kind: k.kind)])
    guard let c = ctxOf(p0, "sample", true) else { return nil }
    var n = 0
    let ds = placeKit(k, c, [], { let s = "s\(n)"; n += 1; return s }, o)
    var p = p0
    p.elec.devs = ds
    guard let c2 = ctxOf(p, "sample", true) else { return nil }
    return KPreview(c: c2, devs: ds, calc: calcOf(p, true))
}

private let P_WALL = 0xEEF1F5
private let P_FLOOR = 0xE2E6EC

private func ePolyPath(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    guard let f = pts.first else { return p }
    p.move(to: f)
    for q in pts.dropFirst() { p.addLine(to: q) }
    p.closeSubpath()
    return p
}

/// Draws the kit in its sample room's far corner, seen from inside the room; az turns the view a little.
func drawKitPreview(_ cg: CGContext, _ size: CGSize, _ pv: KPreview, _ az: Double = 0) {
    cg.saveGState(); defer { cg.restoreGState() }
    cg.setFillColor(eCG(0xF6F8FC)); cg.fill(CGRect(origin: .zero, size: size))
    guard size.width > 1, size.height > 1, pv.c.g.walls.count >= 2 else { return }
    let c = pv.c, g = c.g
    let L = g.walls[0].len / 1000, W = g.walls[1].len / 1000, H = g.H / 1000
    let a = 0.78 + az
    let tgt = V3(L * 0.3, H * 0.45, W * 0.3)
    let dist = hypot(L, W) * 0.78
    let eye = V3(tgt.x + dist * cos(a), H * 0.62, tgt.z + dist * sin(a))
    let cam = TCam(eye, tgt, Double(size.width), Double(size.height), 0.58)
    func sc(_ q: V2, _ z: Double) -> V3 { V3(q.x / 1000, z / 1000, q.y / 1000) }
    func quad(_ pts: [V3], _ col: CGColor, _ stroke: CGColor? = nil) {
        var o: [CGPoint] = []
        for q in pts {
            guard let s = cam.p(q) else { return }
            o.append(s)
        }
        let path = ePolyPath(o)
        cg.addPath(path); cg.setFillColor(col); cg.fillPath()
        if let stroke { cg.addPath(path); cg.setStrokeColor(stroke); cg.setLineWidth(1); cg.strokePath() }
    }
    func dot(_ p: CGPoint, _ r: CGFloat, _ col: CGColor) {
        cg.setFillColor(col); cg.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
    }
    func seg(_ p0: CGPoint, _ p1: CGPoint, _ col: CGColor, _ w: CGFloat, _ round: Bool) {
        cg.saveGState()
        cg.setStrokeColor(col); cg.setLineWidth(w); cg.setLineCap(round ? .round : .butt)
        cg.move(to: p0); cg.addLine(to: p1); cg.strokePath()
        cg.restoreGState()
    }
    quad(g.floor.map { sc($0, g.H) }, eCG(0xF8FAFC))
    quad(g.floor.map { sc($0, 0) }, eCG(P_FLOOR))
    for id in ["A", "D"] {
        guard let w = g.wall(id) else { continue }
        quad([sc(w.at(0), 0), sc(w.at(w.len), 0), sc(w.at(w.len), g.H), sc(w.at(0), g.H)], eCG(id == "A" ? P_WALL : 0xE6EAF0))
        for o in c.room.openings where o.wall == id {
            let off = Double(o.off), ow = Double(o.w), s = Double(o.sill), oh = Double(o.h)
            let pts = [sc(w.at(off, 2), s), sc(w.at(off + ow, 2), s), sc(w.at(off + ow, 2), s + oh), sc(w.at(off, 2), s + oh)]
            quad(pts, eCG(o.type == "door" ? 0xD9DEE6 : 0xCFE0F7), eCG(0x9AA8BF))
        }
        for x in c.room.points where x.wall == id {
            if let p = cam.p(sc(w.at(Double(x.off), 3), Double(x.h))) { dot(p, 3.5, eCG(0x2563EB)) }
        }
    }
    // the corner's line
    if let w = g.wall("A"), let p0 = cam.p(sc(w.at(0), 0)), let p1 = cam.p(sc(w.at(0), g.H)) { seg(p0, p1, eCG(0x101828, 0x33 / 255.0), 1, false) }
    let vis: Set<String> = ["A", "D"]
    // the routes in their circuits' colours
    for r in pv.calc.routes.runs {
        let col = eCG(r.circuit.rgb)
        for s in r.segs where s.wall == nil || vis.contains(s.wall ?? "") {
            if let p0 = cam.p(sc(s.a, s.za)), let p1 = cam.p(sc(s.b, s.zb)) { seg(p0, p1, col, 1.6, true) }
        }
    }
    let circ = circuitByDev(pv.calc)
    for d in pv.devs {
        let col = circ[d.id].map { eCG($0.rgb) } ?? eCG(0x94A3B8)
        if d.onCeiling {
            let q = V2(Double(d.cx), Double(d.cy))
            let r = Double(devType(d.t).dw) / 2
            var ring: [V3] = []
            for i in 0..<12 {
                let t = 2 * Double.pi * Double(i) / 12
                ring.append(sc(V2(q.x + r * cos(t), q.y + r * sin(t)), g.H - 5))
            }
            quad(ring, eCG(0xFDE68A), eCG(0x6B7280))
            continue
        }
        guard let wid = d.wall, vis.contains(wid), let w = c.wall(wid) else { continue }
        let (dw, dh) = devSize(d)
        let m = Double(d.off), hm = Double(d.h)
        let a0 = m - Double(dw) / 2, a1 = m + Double(dw) / 2, b0 = hm - Double(dh) / 2, b1 = hm + Double(dh) / 2
        if d.t == "led" {
            if let p0 = cam.p(sc(w.at(a0, 4), hm)), let p1 = cam.p(sc(w.at(a1, 4), hm)) { seg(p0, p1, eCG(0xFACC15), 3, false) }
            continue
        }
        // drawn a little bigger than true so the plates read on a card
        let k = 1.5
        let l0 = m - (m - a0) * k, l1 = m + (a1 - m) * k
        let v0 = hm - (hm - b0) * k, v1 = hm + (b1 - hm) * k
        let pts = [sc(w.at(l0, 5), v0), sc(w.at(l1, 5), v0), sc(w.at(l1, 5), v1), sc(w.at(l0, 5), v1)]
        quad(pts, devType(d.t).cat == "box" ? eCG(0x94A3B8) : eCG(0xFFFFFF), eCG(0x475569))
        if let p = cam.p(sc(w.at(m, 6), hm)) { dot(p, 2.2, col) }
    }
}

/// A kit's picture as a still image (the gallery's cards).
func kitPicture(_ k: ElecKit, _ size: CGSize) -> UIImage? {
    guard let pv = kitPreview(k, defaultOpts(k)) else { return nil }
    let fmt = UIGraphicsImageRendererFormat.preferred()
    fmt.opaque = true
    return UIGraphicsImageRenderer(size: size, format: fmt).image { c in drawKitPreview(c.cgContext, size, pv) }
}

/// The gallery's pictures, made once from the app's own drawing of each kit, away from the main thread.
@Observable final class ElecPics {
    static let shared = ElecPics()
    private(set) var pics: [String: UIImage] = [:]
    @ObservationIgnored private var job: Task<Void, Never>? = nil

    @MainActor
    func make() {
        if job != nil { return }
        let ids = KITS.map(\.id).filter { pics[$0] == nil }
        if ids.isEmpty { return }
        job = Task { @MainActor [weak self] in
            for id in ids {
                if Task.isCancelled { return }
                let img = await Task.detached(priority: .utility) { () -> UIImage? in
                    guard let k = kitOf(id) else { return nil }
                    return kitPicture(k, CGSize(width: 200, height: 170))
                }.value
                guard let self, !Task.isCancelled else { return }
                if let img { self.pics[id] = img }
            }
            self?.job = nil
        }
    }
}

/// A kit's contents, from the kit put in its sample room (worked out once a kit).
final class EKitDevs {
    static let shared = EKitDevs()
    private var memo: [String: [ElecDev]] = [:]
    func of(_ k: ElecKit) -> [ElecDev] {
        if let m = memo[k.id] { return m }
        let ds = kitPreview(k, defaultOpts(k))?.devs ?? []
        memo[k.id] = ds
        return ds
    }
}

/// A kit's sample-room picture with the choices made, worked out again only when they change.
final class EPreviewCache {
    private var key: String? = nil
    private var opts: KitOpts? = nil
    private var pv: KPreview? = nil
    func get(_ k: ElecKit, _ o: KitOpts) -> KPreview? {
        if key == k.id, opts == o { return pv }
        key = k.id; opts = o; pv = kitPreview(k, o)
        return pv
    }
}

/// The kit live in the sample room: a sideways drag turns it a little.
struct EKitPreviewView: View {
    let pv: KPreview?
    @Environment(\.displayScale) private var scale
    @State private var az = 0.0
    /// The turn when this drag began; 0 the drag is not decided yet, 1 it turns the room, 2 it is a scroll.
    @State private var from = 0.0
    @State private var mode = 0

    var body: some View {
        Canvas { ctx, size in
            let pv = self.pv, az = self.az
            ctx.withCGContext { cg in
                if let pv { drawKitPreview(cg, size, pv, az) }
                else { cg.setFillColor(eCG(0xF6F8FC)); cg.fill(CGRect(origin: .zero, size: size)) }
            }
        }
        .contentShape(Rectangle())
        // only a mostly sideways drag turns it, so the page still scrolls over the picture
        .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { v in
            if mode == 0 { mode = abs(v.translation.width) > abs(v.translation.height) ? 1 : 2; from = az }
            if mode == 1 { az = min(0.45, max(-0.45, from - Double(v.translation.width * scale) / 400)) }
        }.onEnded { _ in mode = 0 })
    }
}

private struct EGroupTops: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue()) { $1 } }
}

/* ---------------- the gallery ---------------- */

struct EGalleryScreen: View {
    let app: AppModel
    let pid: String
    let rid: String?
    let fromNew: Bool
    @State private var cur: String? = nil
    @State private var jumping = false
    @State private var viewH: CGFloat = 0

    var body: some View {
        if let p = Store.shared.get(pid) {
            let room = rid.flatMap { id in p.rooms.first { $0.id == id } }
            let kinds = kindsFor(p, room)
            let on = cur ?? kinds.first ?? "kitchen"
            let pics = ElecPics.shared.pics
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
                    BarTitle(title: tr("el.galT"), eyebrow: dn(p.name))
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollViewReader { proxy in
                    chips(kinds, on, proxy)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            T(intro(p, room), ui(13.5, 400, G.ink2, lh: 1.4))
                            ForEach(kinds, id: \.self) { g in group(p, g, pics) }
                            if fromNew {
                                T(tr("fz.needL"), ui(14.5, 700, G.cobalt2)).padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity)
                                    .pressable(0.97) { app.pop() }
                                    .accessibilityAddTraits(.isButton).accessibilityIdentifier("eg.later")
                            }
                            Color.clear.frame(height: 1)
                                .background(GeometryReader { geo in Color.clear.preference(key: EGroupTops.self, value: ["_end": geo.frame(in: .named("egal")).maxY]) })
                        }
                        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 28)
                    }
                    .coordinateSpace(name: "egal")
                    .background(GeometryReader { geo in Color.clear.onAppear { viewH = geo.size.height }.onChange(of: geo.size.height) { _, h in viewH = h } })
                    // the chip of the group at the top of the list
                    .onPreferenceChange(EGroupTops.self) { tops in
                        guard !jumping, !kinds.isEmpty else { return }
                        let atEnd = viewH > 0 && (tops["_end"] ?? .infinity) <= viewH + 4
                        let top = atEnd ? kinds[kinds.count - 1] : kinds.last { (tops[$0] ?? .infinity) <= 60 } ?? kinds[0]
                        if top != cur { cur = top }
                    }
                }
            }
            .onAppear { ElecPics.shared.make() }
        }
    }

    /// The room kinds with kits, the room's own kind first.
    private func kindsFor(_ p: Project, _ room: Room?) -> [String] {
        let ks = KINDS.filter { k in KITS.contains { $0.kind == k } }
        guard let r = room else { return ks }
        let snap = AppSettings.shared.angleSnap
        let set = p.elec.room(r.id).kind
        let first = ctxOf(p, r.id, snap)?.kind ?? (set.isEmpty ? guessKind(p.floors.first { $0.id == r.floorId }?.type, r.name) : set)
        return ks.filter { $0 == first } + ks.filter { $0 != first }
    }

    private func intro(_ p: Project, _ room: Room?) -> String {
        guard let room else { return tr("el.galB") }
        let f = { (mm: Int?) in Geo.fmtLen(mm, .m, en) }
        return tr("tl.forRoom", ["r": eRoomName(p, room), "a": f(room.dim("A").v), "b": f(room.dim("B").v), "h": f(room.dim("H").v)])
    }

    private func chips(_ kinds: [String], _ on: String, _ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(kinds, id: \.self) { g in
                    let sel = g == on
                    T(tr(eKindKey(g)), ui(14, 700, sel ? G.solid : G.ink), lines: 1)
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .background(Capsule().fill(sel ? G.ink : G.glass(0.55)))
                        .pressable(0.97) {
                            cur = g; jumping = true
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("eg-" + g, anchor: .top) }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { jumping = false }
                        }
                        .accessibilityAddTraits(sel ? [.isSelected, .isButton] : .isButton)
                        .accessibilityIdentifier("eg.chip." + g)
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
        }
    }

    @ViewBuilder private func group(_ p: Project, _ g: String, _ pics: [String: UIImage]) -> some View {
        let ks = KITS.filter { $0.kind == g }
        HStack(alignment: .lastTextBaseline, spacing: 8) { T(tr(eKindKey(g)), ui(17, 800)); T("\(ks.count)", ui(12.5, 500, G.ink3)) }
            .padding(.top, 8).padding(.leading, 2)
            .background(GeometryReader { geo in Color.clear.preference(key: EGroupTops.self, value: [g: geo.frame(in: .named("egal")).minY]) })
            .id("eg-" + g)
        ForEach(Array(stride(from: 0, to: ks.count, by: 2)), id: \.self) { i in
            HStack(alignment: .top, spacing: 10) {
                ForEach(ks[i..<min(i + 2, ks.count)], id: \.id) { k in
                    EKitCard(k: k, pic: pics[k.id], wide: i + 1 >= ks.count) { app.push(.eSteps(pid: p.id, kit: k.id, rid: rid)) }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EKitCard: View {
    let k: ElecKit
    let pic: UIImage?
    let wide: Bool
    let action: () -> Void
    var body: some View {
        let name = tr("el.kit." + k.id)
        let sub = devSummary(EKitDevs.shared.of(k))
        let img = ZStack {
            Color(argb: 0xFFF6F8FC)
            if let pic { Image(uiImage: pic).resizable().scaledToFill() } else { T("3D…", ui(11, 600, G.ink3)) }
        }
        .aspectRatio(200 / 170, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        let words = VStack(alignment: .leading, spacing: 2) {
            T(name, ui(14.5, 800), lines: 2)
            T(sub, ui(12, 500, G.ink2, lh: 1.3), lines: 3)
        }
        .padding(.horizontal, 4)
        Group {
            // the last card of an odd row takes the whole width, its picture beside the words
            if wide { HStack(spacing: 10) { img.frame(maxWidth: .infinity); words.frame(maxWidth: .infinity, alignment: .leading) } }
            else { VStack(alignment: .leading, spacing: 6) { img; words; Spacer(minLength: 0) } }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.62))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("ekit." + k.id)
    }
}

/* ---------------- the steps ---------------- */

/// Which steps page set app.backOverride last: a page going away clears it only while it is still its own.
private enum EBackOwner { static var last = 0; static var seq = 0 }

private enum ESF: Hashable { case l, w, h }

struct EStepsScreen: View {
    let app: AppModel
    let pid: String
    let kit: String
    let rid: String?
    @State private var light: String
    @State private var led: Bool
    @State private var ac: Bool
    @State private var low: Bool
    /// where: a room's id, "new" (a new room) or "free" (typed by size)
    @State private var wher: String
    @State private var tl: String
    @State private var tw: String
    @State private var th: String
    @State private var at = 0
    @State private var backToken = 0
    @State private var pvc = EPreviewCache()
    @FocusState private var focus: ESF?

    init(app: AppModel, pid: String, kit: String, rid: String?) {
        self.app = app; self.pid = pid; self.kit = kit; self.rid = rid
        let d0 = kitOf(kit).map { defaultOpts($0) } ?? KitOpts()
        _light = State(initialValue: d0.light)
        _led = State(initialValue: d0.led)
        _ac = State(initialValue: d0.ac)
        _low = State(initialValue: d0.low)
        _wher = State(initialValue: rid ?? "")
        let s = AppSettings.shared
        let e = s.lang == .en
        _tl = State(initialValue: Geo.fmtField(4000, s.unit, e))
        _tw = State(initialValue: Geo.fmtField(3000, s.unit, e))
        _th = State(initialValue: Geo.fmtField(2700, s.unit, e))
    }

    private var steps: [String] { rid == nil ? ["light", "extras", "where"] : ["light", "extras"] }
    private var opts: KitOpts { KitOpts(light: light, led: led, ac: ac, low: low) }

    private func sizes() -> (Int, Int, Int)? {
        let unit = AppSettings.shared.unit
        guard let L = parseLen(tl, unit), let W = parseLen(tw, unit), let H = parseLen(th, unit) else { return nil }
        if !(1000...30000).contains(L) || !(1000...30000).contains(W) || !(2000...6000).contains(H) { return nil }
        return (L, W, H)
    }

    private func ok(_ s: String) -> Bool { s != "where" || (!wher.isEmpty && (wher != "free" || sizes() != nil)) }

    var body: some View {
        if let p = Store.shared.get(pid), let k = kitOf(kit) {
            let st = steps, n = st.count
            let step = st[min(max(at, 0), n - 1)]
            let pv = pvc.get(k, opts)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        GlassIconButton("back", tr("nt.back")) { prev() }.padding(.leading, 6).accessibilityIdentifier("back")
                        BarTitle(title: tr("el.kit." + k.id), eyebrow: tr("tl.stepN", ["i": min(at, n - 1) + 1, "n": n]))
                    }
                    .padding(.trailing, 12).frame(minHeight: 64)
                    .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                    .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            dots(n, at)
                            if pv != nil && step != "where" {
                                picture(pv)
                                T(devSummary(pv?.devs ?? []), ui(13, 600, G.ink2, lh: 1.35))
                            }
                            stepBody(p, k, step)
                        }
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 168)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                FloatingFooter {
                    if at < n - 1 {
                        GBtn(tr("common.next"), enabled: ok(step)) { if ok(step) { at += 1 } }.accessibilityIdentifier("es.next")
                    } else {
                        GBtn(tr(putNow(p) ? "el.s.put" : "el.s.putLater"), enabled: st.allSatisfy { ok($0) }) { save(p, k) }.accessibilityIdentifier("es.save")
                    }
                }
            }
            .onAppear {
                EBackOwner.seq += 1; backToken = EBackOwner.seq; EBackOwner.last = backToken
                app.backOverride = { prev() }
            }
            .onDisappear { if EBackOwner.last == backToken { app.backOverride = nil; EBackOwner.last = 0 } }
        }
    }

    /// The kit goes in now (a measured room, a new typed room, or the order's rooms left for later), or once measured.
    private func putNow(_ p: Project) -> Bool {
        if wher.isEmpty || wher == "free" { return true }
        guard let r = p.rooms.first(where: { $0.id == wher }) else { return false }
        return Geo.ready3D(r, AppSettings.shared.angleSnap)
    }

    private func dots(_ n: Int, _ at: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<n, id: \.self) { i in
                Capsule().fill(i == at ? G.cobalt : i < at ? G.cobalt.opacity(0.45) : G.ink.opacity(0.15)).frame(width: i == at ? 22 : 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func picture(_ pv: KPreview?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            EKitPreviewView(pv: pv)
            T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(10).allowsHitTesting(false)
        }
        .aspectRatio(1.25, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
    }

    @ViewBuilder private func stepBody(_ p: Project, _ k: ElecKit, _ step: String) -> some View {
        switch step {
        case "light":
            EAsk(title: tr("el.s.light"), help: tr("el.s.lightH")) {
                ForEach([("", "el.s.asKit"), ("lc", "el.t.lc"), ("lch", "el.t.lch"), ("ls", "el.s.spots")], id: \.0) { v, key in
                    EOption(title: tr(key), sub: v.isEmpty ? tr("el.s.asKitS") : tr("el.s." + v + "S"), on: light == v) { light = v }
                }
            }
        case "extras":
            EAsk(title: tr("el.s.extras"), help: tr("el.s.extrasH")) {
                EToggle(title: tr("el.s.led"), sub: tr("el.s.ledS"), on: led) { led.toggle() }
                if k.kind != "bath" && k.kind != "hall" { EToggle(title: tr("el.s.ac"), sub: tr("el.s.acS"), on: ac) { ac.toggle() } }
                EToggle(title: tr("el.s.low"), sub: tr("el.s.lowS"), on: low) { low.toggle() }
            }
        default:
            whereStep(p, k)
        }
    }

    private func whereStep(_ p: Project, _ k: ElecKit) -> some View {
        let snap = AppSettings.shared.angleSnap
        let uw = unitWord(AppSettings.shared.unit)
        return EAsk(title: tr("fq.title"), help: tr("el.s.whereH")) {
            ForEach(p.rooms) { r in
                EOption(title: eRoomName(p, r), sub: roomSub(r, snap), on: wher == r.id) { wher = r.id }
            }
            EOption(title: tr("fz.newRoom"), sub: tr("el.s.newS", ["k": tr(eKindKey(k.kind))]), on: wher == "new") { wher = "new" }
            EOption(title: tr("tl.s.noRoom"), sub: tr("el.s.freeS"), on: wher == "free") { wher = "free" }
            if wher == "free" {
                HStack(alignment: .top, spacing: 8) {
                    sizeField(tr("tl.pa"), $tl, "4", .l, uw)
                    sizeField(tr("tl.pbW"), $tw, "3", .w, uw)
                    sizeField(tr("tl.pbH"), $th, "2,7", .h, uw)
                }
            }
        }
    }

    /// A room's line on the "which room" step: its sizes, measured, or to be measured later.
    private func roomSub(_ r: Room, _ snap: Bool) -> String {
        let ready = measuredRoom(r, snap)
        if ready && !r.isPoly {
            let a = Geo.fmtLen(r.dim("A").v, .m, en), b = Geo.fmtLen(r.dim("B").v, .m, en)
            return a + " × " + b + U_M
        }
        return tr(ready ? "tl.measured" : "el.s.later")
    }

    private func sizeField(_ label: String, _ text: Binding<String>, _ ph: String, _ me: ESF, _ uw: String) -> some View {
        let b = Binding(get: { text.wrappedValue }, set: { v in text.wrappedValue = String(v.filter { $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }.prefix(7)) })
        return GField(label: label, value: b, placeholder: ph, focus: $focus, me: me, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
    }

    private func prev() {
        focus = nil
        if at > 0 { at -= 1 } else { app.pop() }
    }

    private func save(_ p: Project, _ k: ElecKit) {
        guard steps.allSatisfy({ ok($0) }), app.once() else { return }
        let o = opts
        let kitName = tr("el.kit." + k.id)
        let pid = p.id
        let toProject: (Route) -> Bool = { r in if case .project(let id, _, _, _) = r { return id == pid }; return false }
        switch wher {
        case "free":
            guard let sz = sizes() else { return }
            let f = freeOf(k, o, uid(), tr(eKindKey(k.kind)), sz.0, sz.1, sz.2)
            updateElec(pid) { $0.free.append(f) }
            app.popTo(toProject)
            app.push(.eView(pid: pid, rid: "free:" + f.id))
            app.say("el.kitAdded", ["n": kitName])
        case "new":
            // the suggested name kept as its key, so it follows the language
            let key = eKindKey(k.kind)
            let nrid = addElecRoom(pid, k.kind, suggestedName(nextName(p, key), key))
            let pick = pickOf(k, o)
            updateERoom(pid, nrid) { $0.pend.append(pick) }
            app.popTo(toProject)
            openRoom(app, pid, nrid)
            app.say("el.kitPend")
        default:
            guard let r = p.rooms.first(where: { $0.id == wher }) else { return }
            app.popTo(toProject)
            if Geo.ready3D(r, AppSettings.shared.angleSnap) {
                let want = ctxOf(p, r.id, AppSettings.shared.angleSnap).map { kitWanted(k, $0, o) } ?? 0
                let got = applyKit(pid, r.id, k, o)
                app.push(.eView(pid: pid, rid: r.id))
                // fewer than the kit has: the room had no clear place for the rest (doors, windows, water)
                if got < want { app.say("el.kitFewer", ["n": got, "m": want], kind: .info) } else { app.say("el.kitPlaced", ["n": got]) }
            } else {
                let pick = pickOf(k, o)
                updateERoom(pid, r.id) { $0.pend.append(pick) }
                app.say("el.kitPend")
            }
        }
    }
}

/// A step's question, its help line and its choices.
struct EAsk<Content: View>: View {
    let title: String
    let help: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            T(title, ui(21, 800, G.ink, lh: 1.2)).padding(.top, 4)
            T(help, ui(13, 400, G.ink2, lh: 1.4))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One choice as a card with a line under it.
struct EOption: View {
    let title: String
    let sub: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 10) {
            ZStack {
                Circle().strokeBorder(on ? G.cobalt : G.ink3, lineWidth: 2).frame(width: 20, height: 20)
                if on { Circle().fill(G.cobalt).frame(width: 10, height: 10) }
            }
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15, 700, on ? G.cobalt2 : G.ink))
                T(sub, ui(12.5, 400, G.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.75)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

/// A choice that is on or off, with its switch.
struct EToggle: View {
    let title: String
    let sub: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15, 700))
                T(sub, ui(12.5, 400, G.ink2, lh: 1.3))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GSwitch(on: on)
        }
        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 60)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.75)))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}
