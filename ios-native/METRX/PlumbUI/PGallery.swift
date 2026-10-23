import SwiftUI
import UIKit
import Observation

/*
 * Choosing a plumber's room kit (22 Oct 2026; Android ui/plumb/PGallery.kt): the gallery of kits grouped by room, each
 * card drawn by the app from the kit put in a sample room seen from inside towards the corner where the riser stands;
 * then a few questions (bath or shower, the extras, the heating, which room), the kit shown in the sample room all along.
 */

private var pgEn: Bool { AppSettings.shared.lang == .en }

/// The sample room a kit is shown in: the door on wall B out of sight, the water marked on wall A, the riser in the A/D
/// corner (none for a heating kit).
private func pgSampleRoom(_ k: PKit) -> (Room, PlRiser?) {
    var L = 4200, W = 3400
    switch k.kind {
    case "bath": L = 2600; W = 2000
    case "wc": L = 1200; W = 1600
    case "util": L = 2200; W = 1800
    default: break
    }
    var ops: [Opening] = []
    if k.id == "ht.ufh" { ops.append(Opening(id: "d", type: "door", wall: "D", w: 800, h: 2100, off: 300)) }
    else if k.kind == "wc" { ops.append(Opening(id: "d", type: "door", wall: "C", w: 700, h: 2100, off: 250)) }
    else { ops.append(Opening(id: "d", type: "door", wall: "B", w: 800, h: 2100, off: W - 1000)) }
    if k.kind == "heat" { ops.append(Opening(id: "w", type: "window", wall: "A", w: 1400, h: 1400, off: L / 2 - 700, sill: 900)) }
    var pts: [SitePoint] = []
    if k.kind == "wc" { pts = [SitePoint(id: "c", t: "cold", wall: "D", off: 800, h: 550)] }
    else if k.kind != "heat" { pts = [SitePoint(id: "c", t: "cold", wall: "A", off: k.kind == "kitchen" ? 1600 : 1300, h: 550)] }
    var r = Room(id: "sample", floorId: "sw", name: "")
    r.dims = ["A": Dim(v: L), "B": Dim(v: W), "H": Dim(v: 2700), "T": Dim(v: 120, src: "default")]
    r.openings = ops
    r.points = pts
    let rs: PlRiser? = k.kind == "heat" ? nil : PlRiser(roomId: "sample", wall: "A", off: 140)
    return (r, rs)
}

/// A kit in its sample room: the room, its fixtures placed, the riser, the routes.
struct PGPreview {
    let c: PCtx
    let fixes: [PlFix]
    let riser: PlRiser?
    let calc: PlumbCalc
}

func pgKitPreview(_ k: PKit, _ o: POpts) -> PGPreview? {
    let (r, rs) = pgSampleRoom(k)
    let kind = k.kind == "heat" ? "room" : k.kind
    let wt = kind == "kitchen" ? "kitchen" : kind == "bath" ? "bath" : "room"
    var p0 = Project(id: "sample", name: "")
    p0.floors = [Workspace(id: "sw", name: "", type: wt)]
    p0.rooms = [r]
    p0.industry = "plumb"
    p0.plumb = PlumbOrder(rooms: [PlRoom(roomId: "sample", kind: kind, ufh: o.ufh, step: o.step)], riser: rs)
    guard let c = pCtxOf(p0, "sample", true) else { return nil }
    var n = 0
    var fs = pPlaceKit(k, c, [], rs, { let s = "s\(n)"; n += 1; return s }, o)
    if o.ufh {
        let id = "s\(n)"; n += 1
        if let m = placeFix("manif", c, fs, rs, id) { fs.append(m) }
    }
    // a boiler for the heating to come from
    if (o.rad || o.ufh) && !fs.contains(where: { $0.t == "gb" }) {
        let id = "s\(n)"; n += 1
        if let b = placeFix("gb", c, fs, rs, id) { fs.append(b) }
    }
    var p = p0
    p.plumb.fixes = fs
    guard let c2 = pCtxOf(p, "sample", true) else { return nil }
    return PGPreview(c: c2, fixes: fs, riser: rs, calc: plumbCalcOf(p, true))
}

/// A box of a fixture for the pictures: a0…a1 along its wall, d0…d1 into the room, z0…z1 up, its colour.
private struct PGBox {
    let a0: Double, a1: Double, d0: Double, d1: Double, z0: Double, z1: Double, rgb: Int
    var alpha = 1.0
}

private func pgBoxesOf(_ f: PlFix) -> [PGBox] {
    let x = Double(f.off), h = Double(fixW(f)) / 2, d = Double(fixD(f))
    let z0 = Double(fixZ0(f)), z1 = Double(fixTop(f))
    switch f.t {
    case "wc":
        return [PGBox(a0: x - 170, a1: x + 170, d0: 160, d1: d - 40, z0: 0, z1: 420, rgb: 0xF8FAFC),
                PGBox(a0: x - 190, a1: x + 190, d0: 0, d1: 170, z0: 420, z1: z1, rgb: 0xF8FAFC)]
    case "bs", "bsm":
        var out: [PGBox] = []
        if f.opt == "cab" { out.append(PGBox(a0: x - h + 10, a1: x + h - 10, d0: 20, d1: d - 20, z0: 0, z1: z1 - 160, rgb: 0xE7DCCB)) }
        out.append(PGBox(a0: x - h, a1: x + h, d0: 0, d1: d, z0: z1 - 160, z1: z1, rgb: 0xF8FAFC))
        return out
    case "sink":
        return [PGBox(a0: x - h, a1: x + h, d0: 0, d1: d, z0: 0, z1: z1, rgb: 0xE7DCCB)]
    case "cab":
        return [PGBox(a0: x - h, a1: x + h, d0: 0, d1: d, z0: 0, z1: 150, rgb: 0xF8FAFC),
                PGBox(a0: x - h, a1: x + h, d0: 0, d1: d, z0: 150, z1: z1, rgb: 0xBFDBFE, alpha: 0.35)]
    default:
        return [PGBox(a0: x - h, a1: x + h, d0: 0, d1: d, z0: z0, z1: z1, rgb: 0xF8FAFC)]
    }
}

/// A colour 0xRRGGBB made darker by shade (a box's side faces).
private func pgShade(_ rgb: Int, _ k: Double) -> Int {
    let r = Int(Double((rgb >> 16) & 0xFF) * k)
    let g = Int(Double((rgb >> 8) & 0xFF) * k)
    let b = Int(Double(rgb & 0xFF) * k)
    return (r << 16) | (g << 8) | b
}

private func pgPolyPath(_ pts: [CGPoint]) -> CGPath {
    let p = CGMutablePath()
    guard let f = pts.first else { return p }
    p.move(to: f)
    for q in pts.dropFirst() { p.addLine(to: q) }
    p.closeSubpath()
    return p
}

/// One face of a box in the picture: its corners, the way it faces, how dark.
private struct PGFace {
    let pts: [V3]
    let n: V3
    let shade: Double
}

/// A box against its wall in the picture.
private struct PGWBox {
    let w: TWall
    let b: PGBox
}

/// Draws the kit in its sample room's far corner, seen from inside the room; az turns the view a little.
func pgDrawKitPreview(_ cg: CGContext, _ size: CGSize, _ pv: PGPreview, _ az: Double = 0) {
    cg.saveGState(); defer { cg.restoreGState() }
    cg.setFillColor(eCG(0xF6F8FC)); cg.fill(CGRect(origin: .zero, size: size))
    guard size.width > 1, size.height > 1, pv.c.g.walls.count >= 2 else { return }
    let c = pv.c, g = c.g
    let L = g.walls[0].len / 1000, W = g.walls[1].len / 1000, H = g.H / 1000
    let a = 0.78 + az
    let tgt = V3(L * 0.32, H * 0.32, W * 0.32)
    let dist = hypot(L, W) * 0.82
    let ex = tgt.x + dist * cos(a)
    let ez = tgt.z + dist * sin(a)
    let eye = V3(ex, H * 0.7, ez)
    let cam = TCam(eye, tgt, Double(size.width), Double(size.height), 0.6)
    func sc(_ q: V2, _ z: Double) -> V3 { V3(q.x / 1000, z / 1000, q.y / 1000) }
    func quad(_ pts: [V3], _ col: CGColor, _ stroke: CGColor? = nil) {
        var o: [CGPoint] = []
        for q in pts {
            guard let s = cam.p(q) else { return }
            o.append(s)
        }
        let path = pgPolyPath(o)
        cg.addPath(path); cg.setFillColor(col); cg.fillPath()
        if let stroke { cg.addPath(path); cg.setStrokeColor(stroke); cg.setLineWidth(1); cg.strokePath() }
    }
    func seg(_ p0: CGPoint, _ p1: CGPoint, _ col: CGColor, _ w: CGFloat, _ round: Bool) {
        cg.saveGState()
        cg.setStrokeColor(col); cg.setLineWidth(w); cg.setLineCap(round ? .round : .butt)
        cg.move(to: p0); cg.addLine(to: p1); cg.strokePath()
        cg.restoreGState()
    }
    quad(g.floor.map { sc($0, 0) }, eCG(0xE2E6EC))
    let vis: Set<String> = ["A", "D"]
    for id in ["A", "D"] {
        guard let w = g.wall(id) else { continue }
        quad([sc(w.at(0), 0), sc(w.at(w.len), 0), sc(w.at(w.len), g.H), sc(w.at(0), g.H)], eCG(id == "A" ? 0xEEF1F5 : 0xE6EAF0))
        for o in c.room.openings where o.wall == id {
            let off = Double(o.off), ow = Double(o.w), s = Double(o.sill), oh = Double(o.h)
            let pts = [sc(w.at(off, 2), s), sc(w.at(off + ow, 2), s), sc(w.at(off + ow, 2), s + oh), sc(w.at(off, 2), s + oh)]
            quad(pts, eCG(o.type == "door" ? 0xD9DEE6 : 0xCFE0F7), eCG(0x9AA8BF))
        }
    }
    // the corner's line
    if let w = g.wall("A"), let p0 = cam.p(sc(w.at(0), 0)), let p1 = cam.p(sc(w.at(0), g.H)) { seg(p0, p1, eCG(0x101828, 0x33 / 255.0), 1, false) }
    // the underfloor loops, then the pipes
    if let l = pv.calc.routes.loops.first, l.n > 0 {
        for k in 0..<l.n {
            for ab in pSnake(c, l.step, k, l.n) {
                if let p0 = cam.p(sc(ab.0, 5)), let p1 = cam.p(sc(ab.1, 5)) { seg(p0, p1, eCG(UFH_RGB), 1, false) }
            }
        }
    }
    let runs = eSortedBy(pv.calc.routes.runs) { $0.kind == "drain" ? 0 : 1 }
    for r in runs {
        let col = eCG(kindRgb(r.kind))
        let lw: CGFloat = r.kind == "drain" ? 2.4 : 1.6
        for s in r.segs {
            let onWall = s.wall == nil || vis.contains(s.wall ?? "")
            let low = s.za < 90 && s.zb < 90
            if !(onWall || low) { continue }
            if let p0 = cam.p(sc(s.a, s.za)), let p1 = cam.p(sc(s.b, s.zb)) { seg(p0, p1, col, lw, true) }
        }
    }
    // the riser and the fixtures as boxes, far ones first, each showing the faces turned to the eye
    var boxes: [PGWBox] = []
    if let r = pv.riser, let w = c.wall(r.wall) {
        let half = Double(RISER_W) / 2
        boxes.append(PGWBox(w: w, b: PGBox(a0: Double(r.off) - half, a1: Double(r.off) + half, d0: 0, d1: Double(RISER_D), z0: 0, z1: g.H, rgb: 0xCBD5E1)))
    }
    for f in pv.fixes {
        guard let w = c.wall(f.wall) else { continue }
        for b in pgBoxesOf(f) { boxes.append(PGWBox(w: w, b: b)) }
    }
    let e = V2(eye.x * 1000, eye.z * 1000)
    let far = eSortedBy(boxes) { x in
        let m = x.w.at((x.b.a0 + x.b.a1) / 2, (x.b.d0 + x.b.d1) / 2)
        return -hypot(m.x - e.x, m.y - e.y)
    }
    for bx in far {
        let w = bx.w, b = bx.b
        func pt(_ aa: Double, _ dd: Double, _ zz: Double) -> V3 { sc(w.at(aa, dd), zz) }
        let faces: [PGFace] = [
            PGFace(pts: [pt(b.a0, b.d0, b.z1), pt(b.a1, b.d0, b.z1), pt(b.a1, b.d1, b.z1), pt(b.a0, b.d1, b.z1)], n: V3(0, 1, 0), shade: 1),
            PGFace(pts: [pt(b.a0, b.d1, b.z0), pt(b.a1, b.d1, b.z0), pt(b.a1, b.d1, b.z1), pt(b.a0, b.d1, b.z1)], n: V3(w.nIn.x, 0, w.nIn.y), shade: 0.9),
            PGFace(pts: [pt(b.a0, b.d0, b.z0), pt(b.a0, b.d1, b.z0), pt(b.a0, b.d1, b.z1), pt(b.a0, b.d0, b.z1)], n: V3(-w.t.x, 0, -w.t.y), shade: 0.8),
            PGFace(pts: [pt(b.a1, b.d0, b.z0), pt(b.a1, b.d1, b.z0), pt(b.a1, b.d1, b.z1), pt(b.a1, b.d0, b.z1)], n: V3(w.t.x, 0, w.t.y), shade: 0.8)
        ]
        for f in faces {
            var cx = 0.0, cy = 0.0, cz = 0.0
            for q in f.pts { cx += q.x; cy += q.y; cz += q.z }
            cx /= 4; cy /= 4; cz /= 4
            let facing = (eye.x - cx) * f.n.x + (eye.y - cy) * f.n.y + (eye.z - cz) * f.n.z
            if facing <= 0 { continue }
            quad(f.pts, eCG(pgShade(b.rgb, f.shade), b.alpha), eCG(0x64748B))
        }
    }
    // the outlets
    for f in pv.fixes {
        for q in fixPoints(f) where vis.contains(q.wall) {
            guard let w = c.wall(q.wall), let p = cam.p(sc(w.at(Double(q.off), 6), Double(q.h))) else { continue }
            cg.setFillColor(eCG(kindRgb(q.t)))
            cg.fillEllipse(in: CGRect(x: p.x - 2.4, y: p.y - 2.4, width: 4.8, height: 4.8))
        }
    }
}

/// A kit's picture as a still image (the gallery's cards).
func pgKitPicture(_ k: PKit, _ size: CGSize) -> UIImage? {
    guard let pv = pgKitPreview(k, k.opts) else { return nil }
    let fmt = UIGraphicsImageRendererFormat.preferred()
    fmt.opaque = true
    return UIGraphicsImageRenderer(size: size, format: fmt).image { c in pgDrawKitPreview(c.cgContext, size, pv) }
}

/// The gallery's pictures, made once from the app's own drawing of each kit, away from the main thread.
@Observable final class PGPics {
    static let shared = PGPics()
    private(set) var pics: [String: UIImage] = [:]
    @ObservationIgnored private var job: Task<Void, Never>? = nil

    @MainActor
    func make() {
        if job != nil { return }
        let ids = PKITS.map(\.id).filter { pics[$0] == nil }
        if ids.isEmpty { return }
        job = Task { @MainActor [weak self] in
            for id in ids {
                if Task.isCancelled { return }
                let img = await Task.detached(priority: .utility) { () -> UIImage? in
                    guard let k = pkitOf(id) else { return nil }
                    return pgKitPicture(k, CGSize(width: 200, height: 170))
                }.value
                guard let self, !Task.isCancelled else { return }
                if let img { self.pics[id] = img }
            }
            self?.job = nil
        }
    }
}

/// A kit's sample-room picture with the choices made, worked out again only when they change.
final class PGPreviewCache {
    private var key: String? = nil
    private var opts: POpts? = nil
    private var pv: PGPreview? = nil
    func get(_ k: PKit, _ o: POpts) -> PGPreview? {
        if key == k.id, opts == o { return pv }
        key = k.id; opts = o; pv = pgKitPreview(k, o)
        return pv
    }
}

/// The kit live in the sample room: a sideways drag turns it a little.
struct PGKitPreviewView: View {
    let pv: PGPreview?
    @Environment(\.displayScale) private var scale
    @State private var az = 0.0
    /// The turn when this drag began; 0 the drag is not decided yet, 1 it turns the room, 2 it is a scroll.
    @State private var from = 0.0
    @State private var mode = 0

    var body: some View {
        Canvas { ctx, size in
            let pv = self.pv, az = self.az
            ctx.withCGContext { cg in
                if let pv { pgDrawKitPreview(cg, size, pv, az) }
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

/// The gallery's groups, in order.
let PG_KINDS = ["bath", "wc", "kitchen", "util", "heat"]

private struct PGGroupTops: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue()) { $1 } }
}

/* ---------------- the gallery ---------------- */

struct PGalleryScreen: View {
    let app: AppModel
    let pid: String
    var rid: String? = nil
    var fromNew = false
    @State private var cur: String? = nil
    @State private var jumping = false
    @State private var viewH: CGFloat = 0

    var body: some View {
        if let p = Store.shared.get(pid) {
            let room = rid.flatMap { id in p.rooms.first { $0.id == id } }
            let kinds = kindsFor(p, room)
            let on = cur ?? kinds.first ?? "bath"
            let pics = PGPics.shared.pics
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
                                    .accessibilityAddTraits(.isButton).accessibilityIdentifier("pg.later")
                            }
                            Color.clear.frame(height: 1)
                                .background(GeometryReader { geo in Color.clear.preference(key: PGGroupTops.self, value: ["_end": geo.frame(in: .named("pgal")).maxY]) })
                        }
                        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 28)
                    }
                    .coordinateSpace(name: "pgal")
                    .background(GeometryReader { geo in Color.clear.onAppear { viewH = geo.size.height }.onChange(of: geo.size.height) { _, h in viewH = h } })
                    // the chip of the group at the top of the list
                    .onPreferenceChange(PGGroupTops.self) { tops in
                        guard !jumping, !kinds.isEmpty else { return }
                        let atEnd = viewH > 0 && (tops["_end"] ?? .infinity) <= viewH + 4
                        let top = atEnd ? kinds[kinds.count - 1] : kinds.last { (tops[$0] ?? .infinity) <= 60 } ?? kinds[0]
                        if top != cur { cur = top }
                    }
                }
            }
            .onAppear { PGPics.shared.make() }
        }
    }

    /// The room kinds with kits, the room's own kind first.
    private func kindsFor(_ p: Project, _ room: Room?) -> [String] {
        let ks = PG_KINDS
        guard let r = room else { return ks }
        let set = p.plumb.room(r.id).kind
        let first = set.isEmpty ? pGuessKind(p.floors.first { $0.id == r.floorId }?.type, r.name) : set
        return ks.filter { $0 == first } + ks.filter { $0 != first }
    }

    private func intro(_ p: Project, _ room: Room?) -> String {
        guard let room else { return tr("sx.galB") }
        let f = { (mm: Int?) in Geo.fmtLen(mm, .m, pgEn) }
        return tr("tl.forRoom", ["r": pRoomName(p, room), "a": f(room.dim("A").v), "b": f(room.dim("B").v), "h": f(room.dim("H").v)])
    }

    private func chips(_ kinds: [String], _ on: String, _ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(kinds, id: \.self) { g in
                    let sel = g == on
                    T(tr(pKindKey(g)), ui(14, 700, sel ? G.solid : G.ink), lines: 1)
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .background(Capsule().fill(sel ? G.ink : G.glass(0.55)))
                        .pressable(0.97) {
                            cur = g; jumping = true
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("pg-" + g, anchor: .top) }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { jumping = false }
                        }
                        .accessibilityAddTraits(sel ? [.isSelected, .isButton] : .isButton)
                        .accessibilityIdentifier("pg.chip." + g)
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
        }
    }

    @ViewBuilder private func group(_ p: Project, _ g: String, _ pics: [String: UIImage]) -> some View {
        let ks = PKITS.filter { $0.kind == g }
        HStack(alignment: .lastTextBaseline, spacing: 8) { T(tr(pKindKey(g)), ui(17, 800)); T("\(ks.count)", ui(12.5, 500, G.ink3)) }
            .padding(.top, 8).padding(.leading, 2)
            .background(GeometryReader { geo in Color.clear.preference(key: PGGroupTops.self, value: [g: geo.frame(in: .named("pgal")).minY]) })
            .id("pg-" + g)
        ForEach(Array(stride(from: 0, to: ks.count, by: 2)), id: \.self) { i in
            HStack(alignment: .top, spacing: 10) {
                ForEach(ks[i..<min(i + 2, ks.count)], id: \.id) { k in
                    PGKitCard(k: k, pic: pics[k.id], wide: i + 1 >= ks.count) { app.push(.pSteps(pid: p.id, kit: k.id, rid: rid)) }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PGKitCard: View {
    let k: PKit
    let pic: UIImage?
    let wide: Bool
    let action: () -> Void
    var body: some View {
        let name = tr("sx.kit." + k.id)
        let sub = tr("sx.kitS." + k.id)
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
        .accessibilityIdentifier("pkit." + k.id)
    }
}

/* ---------------- the steps ---------------- */

/// Which steps page set app.backOverride last: a page going away clears it only while it is still its own.
private enum PGBackOwner { static var last = 0; static var seq = 0 }

private enum PGSF: Hashable { case l, w, h }

struct PStepsScreen: View {
    let app: AppModel
    let pid: String
    let kit: String
    let rid: String?
    @State private var bath: String
    @State private var cab: Bool
    @State private var wm: Bool
    @State private var trl: Bool
    @State private var dw: Bool
    @State private var basin: Bool
    @State private var heater: String
    @State private var rad: Bool
    @State private var ufh: Bool
    @State private var step: Int
    /// where: a room's id, "new" (a new room) or "free" (typed by size)
    @State private var wher: String
    @State private var tl: String
    @State private var tw: String
    @State private var th: String
    @State private var at = 0
    @State private var backToken = 0
    @State private var pvc = PGPreviewCache()
    @FocusState private var focus: PGSF?

    init(app: AppModel, pid: String, kit: String, rid: String? = nil) {
        self.app = app; self.pid = pid; self.kit = kit; self.rid = rid
        let k = pkitOf(kit)
        let d0 = k?.opts ?? POpts()
        _bath = State(initialValue: d0.bath)
        _cab = State(initialValue: d0.cab)
        _wm = State(initialValue: d0.wm)
        _trl = State(initialValue: d0.tr)
        _dw = State(initialValue: d0.dw)
        _basin = State(initialValue: d0.basin)
        _heater = State(initialValue: d0.heater)
        _rad = State(initialValue: d0.rad)
        _ufh = State(initialValue: d0.ufh)
        _step = State(initialValue: d0.step)
        _wher = State(initialValue: rid ?? "")
        let s = AppSettings.shared
        let e = s.lang == .en
        let kitchen = k?.kind == "kitchen"
        _tl = State(initialValue: Geo.fmtField(kitchen ? 3500 : 2500, s.unit, e))
        _tw = State(initialValue: Geo.fmtField(kitchen ? 3000 : 2000, s.unit, e))
        _th = State(initialValue: Geo.fmtField(2700, s.unit, e))
    }

    private func steps(_ k: PKit) -> [String] {
        var out: [String] = []
        if !k.main.isEmpty { out.append("main") }
        if k.kind != "heat" || k.main.isEmpty { out.append("heat") }
        if rid == nil { out.append("where") }
        return out
    }

    private var opts: POpts {
        POpts(bath: bath, cab: cab, wm: wm, tr: trl, dw: dw, basin: basin, heater: heater, rad: rad, ufh: ufh, step: step)
    }

    private func sizes() -> (Int, Int, Int)? {
        let unit = AppSettings.shared.unit
        guard let L = parseLen(tl, unit), let W = parseLen(tw, unit), let H = parseLen(th, unit) else { return nil }
        if !(800...30000).contains(L) || !(800...30000).contains(W) || !(2000...6000).contains(H) { return nil }
        return (L, W, H)
    }

    private func ok(_ s: String) -> Bool { s != "where" || (!wher.isEmpty && (wher != "free" || sizes() != nil)) }

    var body: some View {
        if let p = Store.shared.get(pid), let k = pkitOf(kit) {
            let st = steps(k), n = st.count
            let cur = st[min(max(at, 0), n - 1)]
            let pv = pvc.get(k, opts)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        GlassIconButton("back", tr("nt.back")) { prev() }.padding(.leading, 6).accessibilityIdentifier("back")
                        BarTitle(title: tr("sx.kit." + k.id), eyebrow: tr("tl.stepN", ["i": min(at, n - 1) + 1, "n": n]))
                    }
                    .padding(.trailing, 12).frame(minHeight: 64)
                    .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                    .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            dots(n, at)
                            if pv != nil && cur != "where" {
                                picture(pv)
                                T(fixSummary(pv?.fixes ?? []), ui(13, 600, G.ink2, lh: 1.35))
                            }
                            stepBody(p, k, cur)
                        }
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 168)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                FloatingFooter {
                    if at < n - 1 {
                        GBtn(tr("common.next"), enabled: ok(cur)) { if ok(cur) { at += 1 } }.accessibilityIdentifier("ps.next")
                    } else {
                        GBtn(tr(putNow(p) ? "el.s.put" : "el.s.putLater"), enabled: st.allSatisfy { ok($0) }) { save(p, k) }.accessibilityIdentifier("ps.save")
                    }
                }
            }
            .onAppear {
                PGBackOwner.seq += 1; backToken = PGBackOwner.seq; PGBackOwner.last = backToken
                app.backOverride = { prev() }
            }
            .onDisappear { if PGBackOwner.last == backToken { app.backOverride = nil; PGBackOwner.last = 0 } }
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

    private func picture(_ pv: PGPreview?) -> some View {
        ZStack(alignment: .bottomTrailing) {
            PGKitPreviewView(pv: pv)
            T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(10).allowsHitTesting(false)
        }
        .aspectRatio(1.25, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
    }

    @ViewBuilder private func stepBody(_ p: Project, _ k: PKit, _ cur: String) -> some View {
        switch cur {
        case "main": mainStep(k)
        case "heat":
            EAsk(title: tr("sx.s.heat"), help: tr("sx.s.heatH")) {
                EToggle(title: tr("sx.s.rad"), sub: tr("sx.s.radS"), on: rad) { rad.toggle() }
                EToggle(title: tr("sx.s.ufh"), sub: tr("sx.s.ufhS"), on: ufh) { ufh.toggle() }
            }
        default:
            whereStep(p, k)
        }
    }

    private func mainStep(_ k: PKit) -> some View {
        EAsk(title: tr("sx.s.main"), help: tr("sx.s.mainH")) {
            if k.main.contains("bath") {
                ForEach(["bath", "sh", "cab"], id: \.self) { v in
                    EOption(title: tr("sx.t." + v), sub: tr("sx.s." + v + "S"), on: bath == v) { bath = v }
                }
            }
            if k.main.contains("heater") {
                ForEach(["gb", "wh"], id: \.self) { v in
                    EOption(title: tr("sx.t." + v), sub: tr("sx.s." + v + "S"), on: heater == v) { heater = v }
                }
            }
            if k.main.contains("step") {
                ForEach([100, 150, 200], id: \.self) { v in
                    EOption(title: tr("sx.s.stepV", ["n": v / 10]), sub: tr("sx.s.step\(v)S"), on: step == v) { step = v }
                }
            }
            extras(k)
        }
    }

    @ViewBuilder private func extras(_ k: PKit) -> some View {
        if k.main.contains("cab") { EToggle(title: tr("sx.s.vanity"), sub: tr("sx.s.vanityS"), on: cab) { cab.toggle() } }
        if k.main.contains("wm") { EToggle(title: tr("sx.t.wm"), sub: tr("sx.s.wmS"), on: wm) { wm.toggle() } }
        if k.main.contains("tr") { EToggle(title: tr("sx.t.tr"), sub: tr("sx.s.trS"), on: trl) { trl.toggle() } }
        if k.main.contains("basin") { EToggle(title: tr("sx.t.bsm"), sub: tr("sx.s.bsmS"), on: basin) { basin.toggle() } }
        if k.main.contains("dw") { EToggle(title: tr("sx.t.dw"), sub: tr("sx.s.dwS"), on: dw) { dw.toggle() } }
    }

    private func whereStep(_ p: Project, _ k: PKit) -> some View {
        let snap = AppSettings.shared.angleSnap
        let uw = unitWord(AppSettings.shared.unit)
        let kind = k.kind == "heat" ? "room" : k.kind
        return EAsk(title: tr("fq.title"), help: tr("el.s.whereH")) {
            ForEach(p.rooms) { r in
                EOption(title: pRoomName(p, r), sub: roomSub(r, snap), on: wher == r.id) { wher = r.id }
            }
            EOption(title: tr("fz.newRoom"), sub: tr("el.s.newS", ["k": tr(pKindKey(kind))]), on: wher == "new") { wher = "new" }
            EOption(title: tr("tl.s.noRoom"), sub: tr("sx.s.freeS"), on: wher == "free") { wher = "free" }
            if wher == "free" {
                HStack(alignment: .top, spacing: 8) {
                    sizeField(tr("tl.pa"), $tl, "2,5", .l, uw)
                    sizeField(tr("tl.pbW"), $tw, "2", .w, uw)
                    sizeField(tr("tl.pbH"), $th, "2,7", .h, uw)
                }
            }
        }
    }

    /// A room's line on the "which room" step: its sizes, measured, or to be measured later.
    private func roomSub(_ r: Room, _ snap: Bool) -> String {
        let ready = measuredRoom(r, snap)
        if ready && !r.isPoly {
            let a = Geo.fmtLen(r.dim("A").v, .m, pgEn), b = Geo.fmtLen(r.dim("B").v, .m, pgEn)
            return a + " × " + b + U_M
        }
        return tr(ready ? "tl.measured" : "el.s.later")
    }

    private func sizeField(_ label: String, _ text: Binding<String>, _ ph: String, _ me: PGSF, _ uw: String) -> some View {
        let b = Binding(get: { text.wrappedValue }, set: { v in text.wrappedValue = String(v.filter { $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }.prefix(7)) })
        return GField(label: label, value: b, placeholder: ph, focus: $focus, me: me, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
    }

    private func prev() {
        focus = nil
        if at > 0 { at -= 1 } else { app.pop() }
    }

    private func save(_ p: Project, _ k: PKit) {
        guard steps(k).allSatisfy({ ok($0) }), app.once() else { return }
        let o = opts
        let kitName = tr("sx.kit." + k.id)
        let kind = k.kind == "heat" ? "room" : k.kind
        let pid = p.id
        let toProject: (Route) -> Bool = { r in if case .project(let id, _, _, _) = r { return id == pid }; return false }
        switch wher {
        case "free":
            guard let sz = sizes() else { return }
            let f = pFreeOf(k, o, uid(), tr(pKindKey(kind)), sz.0, sz.1, sz.2)
            updatePlumb(pid) { $0.free.append(f) }
            app.popTo(toProject)
            app.push(.pView(pid: pid, rid: "free:" + f.id))
            app.say("el.kitAdded", ["n": kitName])
        case "new":
            // the suggested name kept as its key, so it follows the language
            let key = pKindKey(kind)
            let nrid = addPlumbRoom(pid, kind, suggestedName(nextName(p, key), key))
            let pick = PKitPick(kit: k.id, o: o)
            updatePRoom(pid, nrid) { $0.pend.append(pick) }
            app.popTo(toProject)
            openRoom(app, pid, nrid)
            app.say("el.kitPend")
        default:
            guard let r = p.rooms.first(where: { $0.id == wher }) else { return }
            app.popTo(toProject)
            if Geo.ready3D(r, AppSettings.shared.angleSnap) {
                let got = applyPKit(pid, r.id, k, o)
                app.push(.pView(pid: pid, rid: r.id))
                app.say("sx.kitPlaced", ["n": got])
            } else {
                let pick = PKitPick(kit: k.id, o: o)
                updatePRoom(pid, r.id) { $0.pend.append(pick) }
                app.say("el.kitPend")
            }
        }
    }
}
