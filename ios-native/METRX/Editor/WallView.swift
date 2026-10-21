import SwiftUI

/* One wall seen from inside the room (prototype PAGES.wallView, wvElevSVG, openings.js drag in the wall view). */

private var DOOR_FILL: Color { pc(0xFFE2E6EC, 0xFF283044) }

/// Length and height used to draw a wall: confirmed or computed, else a received reading, else a placeholder.
struct WallFrame { let L: Int; let H: Int; let lenKnown: Bool; let hKnown: Bool; let lenSt: String; let hSt: String; let provisional: Bool }

func wallFrame(_ r: Room, _ w: Geo.Wall, _ ops: [Opening]) -> WallFrame {
    let d = r.dim(w.dimKey), h = r.dim("H")
    let ext = ops.map { $0.off + $0.w }.max() ?? 0
    let hTop = ops.map { $0.sill + $0.h }.max() ?? 0
    let geoLen = kround(hypot(w.p1.x - w.p0.x, w.p1.y - w.p0.y))
    let L = w.len ?? d.pending?.mm ?? max(geoLen > 0 ? geoLen : 4000, ext + 600)
    let H = h.v ?? h.pending?.mm ?? max(2700, hTop + 300)
    let lenSt = w.len != nil && d.pending == nil ? "conf" : d.pending != nil ? "recv" : "unset"
    return WallFrame(L: L, H: H, lenKnown: w.len != nil, hKnown: h.v != nil, lenSt: lenSt, hSt: h.status,
                     provisional: (w.len == nil && d.pending != nil) || (h.v == nil && h.pending != nil))
}

/// Where the elevation sits in its 360-wide viewBox (prototype: margins L52 R24 T30, height budget 170).
struct ElevLayout {
    let VW: CGFloat = 360
    let chainH: CGFloat, s: CGFloat, x0: CGFloat, yFloor: CGFloat, yT: CGFloat, VH: CGFloat
    init(_ fr: WallFrame, _ ops: [Opening]) {
        chainH = ops.isEmpty ? 0 : 30
        let ext = ops.map { $0.off + $0.w }.max() ?? 0, hTop = ops.map { $0.sill + $0.h }.max() ?? 0
        let Lx = CGFloat(max(fr.L, ext)), Hx = CGFloat(max(fr.H, hTop))
        let s = min(284 / Lx, 170 / Hx)
        self.s = s
        x0 = 52 + (284 - CGFloat(fr.L) * s) / 2
        yFloor = 30 + Hx * s
        yT = yFloor - CGFloat(fr.H) * s
        VH = yFloor + chainH + 50
    }
    func x(_ mm: Int) -> CGFloat { x0 + CGFloat(mm) * s }
    func y(_ mm: Int) -> CGFloat { yFloor - CGFloat(mm) * s }
}

struct WallViewScreen: View {
    let app: AppModel
    let pid: String
    let rid: String
    let wall: String
    @State private var slide: CGFloat = 0
    private var ops: RoomOps { RoomOps.shared }

    var body: some View {
        if let p = Store.shared.get(pid), let r = p.rooms.first(where: { $0.id == rid }) {
            let snap = AppSettings.shared.angleSnap, unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en
            let ws = Geo.walls(r, snap)
            let i = max(0, ws.firstIndex { $0.id == wall } ?? 0)
            let w = ws[i]
            let wallOps = r.openings.filter { $0.wall == w.id }.sorted { $0.off < $1.off }
            let fr = wallFrame(r, w, wallOps)
            let _ = ops.histTick
            ZStack {
                RoomGrid().ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                        VStack(alignment: .leading, spacing: 0) {
                            T(tr("wv.title", ["w": w.id]), ui(20, 800, G.ink, lh: 1.2), lines: 1)
                            T(dn(r.name), ui(12, 400, G.ink2), lines: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        GlassIconButton("undo", tr("common.undo"), tint: ops.canUndo(r.id) ? G.ink : PC.offIcon) { ops.undo(p.id, r.id) }
                        GlassIconButton("redo", "redo", tint: ops.canRedo(r.id) ? G.ink : PC.offIcon) { ops.redo(p.id, r.id) }
                    }
                    .padding(.horizontal, 16).frame(height: 64)
                    VStack(alignment: .leading, spacing: 12) {
                        // pager: previous, the dots, next, and the small room map that leads back to the plan
                        HStack(spacing: 8) {
                            GlassIconButton("back", tr("wv.prev"), tint: ws.count > 1 ? G.ink : PC.offIcon) { go(-1, ws, i) }
                            HStack(spacing: 6) {
                                ForEach(ws.indices, id: \.self) { k in
                                    Circle().fill(k == i ? G.cobalt : G.ink.opacity(0.2)).frame(width: k == i ? 12 : 7, height: k == i ? 12 : 7)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            GlassIconButton("chev", tr("wv.next"), tint: ws.count > 1 ? G.ink : PC.offIcon) { go(1, ws, i) }.accessibilityIdentifier("wv.next")
                            Locator(ws: ws, i: i).pressable(0.96, label: tr("ed2.plan")) { app.pop() }
                        }
                        T(tr("wv.inside"), ui(12.5, 400, G.ink2))
                        Elevation(r: r, w: w, ops: wallOps, fr: fr, wallCount: ws.count,
                                  pts: (p.isFurniture || p.industry == "elec" || p.industry == "plumb") ? r.points.filter { $0.wall == w.id } : [],
                                  onPoint: { id in app.sheet = .pointForm(pid: p.id, rid: r.id, wall: w.id, id: id) },
                                  onSwipe: { go($0, ws, i) },
                                  onOpening: { id in app.sheet = .openingForm(pid: p.id, rid: r.id, oid: id, type: "door", wall: nil) },
                                  onLength: {
                                      if w.derived && !r.isPoly { app.say("wv.derived", ["w": w.id, "s": w.dimKey], kind: .info) }
                                      ops.focus(r.id, w.dimKey); app.pop()
                                  },
                                  onHeight: { ops.focus(r.id, "H"); app.pop() },
                                  onDragEnd: { o, off, sill in ops.moveOpening(p.id, r.id, o, off, sill) })
                            .offset(x: slide).opacity(1 - Double(abs(slide)) / 28 * 0.65)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)
                    // the details scroll under the drawing, which stays in place for dragging
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(wallOps.filter { ops.issue(r, $0) != nil }) { o in
                                if let iss = ops.issue(r, o) {
                                    HStack(spacing: 8) {
                                        MIcon("alert", G.err, 18, 2)
                                        T(tr(iss.key, iss.vars), ui(13.5, 500, G.err, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                                        T(tr("ed.fix"), ui(14, 700, G.err)).padding(6).pressable(0.96) { app.sheet = .openingForm(pid: p.id, rid: r.id, oid: o.id, type: o.type, wall: nil) }
                                    }
                                    .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.errWash))
                                }
                            }
                            if !wallOps.isEmpty {
                                HStack(alignment: .top, spacing: 8) {
                                    MIcon("info", G.ink2, 16, 2)
                                    T(tr(wallOps.contains { $0.type == "window" } ? "op.dragHintW" : "op.dragHint"), ui(13, 400, G.ink2, lh: 1.4))
                                }
                            }
                            Stats(r: r, w: w, ops: wallOps, fr: fr, en: en)
                            HStack(spacing: 8) { T(tr("wv.openings"), ui(15.5, 600)); CountPill(n: wallOps.count) }
                            if wallOps.isEmpty { T(tr("wv.none"), ui(13.5, 400, G.ink2)) }
                            else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(wallOps) { o in
                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 6) { MIcon(o.type, G.cobalt, 18, 2); T(ops.opName(o), ui(14.5, 700)) }
                                                T(Geo.fmtLen(o.w, unit, en) + " × " + Geo.fmtLen(o.h, unit, en) + " " + unitName(), num(14, 600))
                                                T(tr("wv.off", ["c": w.corner, "v": (o.offDrag ? "≈ " : "") + Geo.fmtLen(o.off, unit, en) + " " + unitName()]), ui(12.5, 400, o.offDrag ? PC.amber : G.ink2))
                                                if o.type == "window" { T(tr("wv.sill", ["v": (o.sillDrag ? "≈ " : "") + Geo.fmtLen(o.sill, unit, en) + " " + unitName()]), ui(12.5, 400, o.sillDrag ? PC.amber : G.ink2)) }
                                                if ops.issue(r, o) != nil { T(tr("room.bad"), ui(12.5, 600, G.err)) }
                                            }
                                            .padding(12).frame(width: 152, alignment: .leading)
                                            .glassCard(RoundedRectangle(cornerRadius: 18, style: .continuous), fill: G.glass(0.55))
                                            .pressable(0.98) { app.sheet = .openingForm(pid: p.id, rid: r.id, oid: o.id, type: o.type, wall: nil) }
                                        }
                                    }
                                    .padding(.vertical, 14).padding(.horizontal, 2)
                                }
                                .padding(.vertical, -14)
                            }
                            // furniture orders: sockets, switches and pipes on this wall (furniture plan section 5)
                            if p.isFurniture || p.industry == "elec" || p.industry == "plumb" { PointsSection(app: app, p: p, r: r, wall: w.id) }
                            HStack(spacing: 6) { MIcon("plus", .white, 18, 2.4); T(tr("wv.add"), ui(15, 700, .white)) }
                                .padding(.horizontal, 18).frame(minHeight: 48)
                                .background(Capsule().fill(G.cobalt))
                                .pressable(0.97) { app.sheet = .wallAdd(pid: p.id, rid: r.id, wall: w.id) }
                                .accessibilityIdentifier("wv.add")
                        }
                        .padding(.horizontal, 16).padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private func go(_ step: Int, _ ws: [Geo.Wall], _ i: Int) {
        guard ws.count > 1 else { return }
        let n = ws[(i + step + ws.count) % ws.count]
        app.setTop(.wallView(pid: pid, rid: rid, wall: n.id))
        app.sheet = nil
        slide = 28 * CGFloat(step)
        withAnimation(.easeOut(duration: 0.22)) { slide = 0 }
    }
}

/// The small room outline: the current wall in blue and an arrow showing which way we look (prototype wv mini locator).
private struct Locator: View {
    let ws: [Geo.Wall]
    let i: Int
    var body: some View {
        Canvas { ctx, size in
            let pad: CGFloat = 8
            let pts = ws.map { CGPoint($0.p0) }
            guard pts.count >= 3 else { return }
            let minX = pts.map(\.x).min()!, maxX = pts.map(\.x).max()!, minY = pts.map(\.y).min()!, maxY = pts.map(\.y).max()!
            let s = min((size.width - 2 * pad) / max(1, maxX - minX), (size.height - 2 * pad) / max(1, maxY - minY))
            let ox = (size.width - (maxX - minX) * s) / 2 - minX * s, oy = (size.height - (maxY - minY) * s) / 2 - minY * s
            let m = { (p: CGPoint) in CGPoint(x: ox + p.x * s, y: oy + p.y * s) }
            ctx.stroke(polyPath(pts.map(m)), with: .color(PC.greyLine), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            let w = ws[i]
            let a = m(CGPoint(w.p0)), b = m(CGPoint(w.p1))
            ctx.line(PC.cob, a, b, 3.2, round: true)
            // inside is to the right of a clockwise wall (y down)
            let d = b - a, len = max(1, d.len)
            let sgn: CGFloat = Geo.shoelace(ws.map(\.p0)) >= 0 ? 1 : -1
            let nIn = CGPoint(x: -d.y / len, y: d.x / len) * sgn
            let md = mid(a, b)
            let tip = md + nIn * 3.5, base = md + nIn * 10, u = d / len * 4
            ctx.fill(polyPath([tip, base + u, base - u]), with: .color(PC.cob))
        }
        .frame(width: 72, height: 54)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.glass(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
    }
}

private struct Stats: View {
    let r: Room
    let w: Geo.Wall
    let ops: [Opening]
    let fr: WallFrame
    let en: Bool
    var body: some View {
        let st = Geo.wallStats(fr.lenKnown ? fr.L : r.dim(w.dimKey).pending?.mm, r.dim("H").v ?? r.dim("H").pending?.mm, ops)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 0) {
                StatCell(label: tr("wv.gross"), v: st.gross.map { Geo.fmtArea($0, en) + " m²" } ?? "—")
                StatCell(label: tr("rp.openings"), v: ops.isEmpty ? "—" : Geo.fmtArea(st.open, en) + " m²")
                StatCell(label: tr("wv.net"), v: st.net.map { Geo.fmtArea($0, en) + " m²" } ?? "—", bold: true)
            }
            if st.gross == nil { T(tr("wv.missing"), ui(12.5, 400, G.ink2)) }
            else if fr.provisional { T(tr("wv.prov"), ui(12.5, 500, PC.amber)) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }
}

private struct StatCell: View {
    let label: String
    let v: String
    var bold = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { T(label, ui(11.5, 400, G.ink2), lines: 1); T(v, num(16, bold ? 800 : 600), lines: 1) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/* ---------------- the elevation: drawing, taps and dragging ---------------- */

private struct Drag { let id: String; let off: Int; let sill: Int; let tag: String? }

private struct Elevation: View {
    let r: Room
    let w: Geo.Wall
    let ops: [Opening]
    let fr: WallFrame
    let wallCount: Int
    let pts: [SitePoint]
    let onPoint: (String) -> Void
    let onSwipe: (Int) -> Void
    let onOpening: (String) -> Void
    let onLength: () -> Void
    let onHeight: () -> Void
    let onDragEnd: (Opening, Int, Int) -> Void

    @State private var live: Drag? = nil
    @State private var finger = CGPoint.zero
    @State private var g: Gest? = nil
    private struct Gest { let hit: Opening?; var hitPt: SitePoint? = nil; var dragging = false; var axis: Character? = nil; var cur: Drag? = nil; var swiped = false }

    var body: some View {
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en, st = AppSettings.shared
        let shown = withLive(ops, live)
        let lay = ElevLayout(fr, shown)
        let issueOf = { (o: Opening) in RoomOps.shared.issue(r, o) != nil }
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        GeometryReader { geo in
            Canvas { ctx, size in
                let k = size.width / lay.VW
                var c = ctx; c.scaleBy(x: k, y: k)
                drawElevation(c, lay, r, w, shown, fr, wallCount, unit, en, live, issueOf)
                for x in pts { drawSitePoint(c, x, CGPoint(x: lay.x(x.off), y: lay.y(x.h)), lay.s, 7) }
                if let live, let o = shown.first(where: { $0.id == live.id }) {
                    let t = tr("wv.off", ["c": w.corner, "v": Geo.fmtLen(o.off, unit, en) + " " + unitName()])
                        + (o.type == "window" ? "\n" + tr("wv.sill", ["v": Geo.fmtLen(o.sill, unit, en) + " " + unitName()]) : "")
                    dragTip(ctx, size, t, finger, issueOf(o))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let k = geo.size.width / lay.VW
                let laySnap = ElevLayout(fr, ops)
                if g == nil {
                    let sp = v.startLocation / k
                    // a site point is small: a tap near it opens it, before any door or window under it
                    let hitPt = pts.last { x in abs(sp.x - laySnap.x(x.off)) < 14 && abs(sp.y - laySnap.y(x.h)) < 14 }
                    let hit = hitPt != nil ? nil : ops.last { o in
                        sp.x >= laySnap.x(o.off) - 4 && sp.x <= laySnap.x(o.off + o.w) + 4 && sp.y >= laySnap.y(o.sill + o.h) - 4 && sp.y <= laySnap.y(o.sill) + 4
                    }
                    g = Gest(hit: hit, hitPt: hitPt)
                }
                guard var s = g else { return }
                let d = v.location - v.startLocation
                let mmPer = 1 / k / laySnap.s
                if let o = s.hit {
                    if !s.dragging && d.len > 7 {
                        s.dragging = true
                        if o.type == "window" { s.axis = abs(d.y) > 1.4 * abs(d.x) ? "v" : abs(d.x) > 1.4 * abs(d.y) ? "h" : nil }
                    }
                    if s.dragging {
                        let slack: CGFloat = 14
                        func sl(_ v: CGFloat, _ on: Bool) -> CGFloat { on ? (v < 0 ? -1 : 1) * max(0, abs(v) - slack) : v }
                        let dx = o.type == "door" ? d.x : sl(d.x, s.axis == "v")
                        let off = snapOff(o.off + kround(Double(dx * mmPer)), o.w, fr.lenKnown ? fr.L : nil)
                        var sill = o.sill
                        var tag: String? = nil
                        if o.type == "window" {
                            let dy = sl(d.y, s.axis == "h")
                            let snapped = snapSill(o.sill - kround(Double(dy * mmPer)), o, ops, st.winSill, fr.hKnown ? fr.H : nil)
                            sill = snapped.0; tag = snapped.1
                        }
                        s.cur = Drag(id: o.id, off: off, sill: sill, tag: tag); live = s.cur; finger = v.location
                    }
                } else if !s.swiped && abs(d.x) >= 48 && abs(d.x) >= 1.5 * abs(d.y) {
                    s.swiped = true; onSwipe(d.x < 0 ? 1 : -1)
                }
                g = s
            }.onEnded { v in
                defer { g = nil; live = nil }
                guard let s = g else { return }
                if s.dragging, let o = s.hit, let c = s.cur { onDragEnd(o, c.off, c.sill); return }
                if s.swiped { return }
                if let x = s.hitPt { onPoint(x.id); return }
                if let o = s.hit { onOpening(o.id); return }
                let ly = ElevLayout(fr, ops), sp = v.startLocation / (geo.size.width / lay.VW)
                if abs(sp.y - (ly.yFloor + ly.chainH + 30)) < 20 { onLength() }
                else if abs(sp.x - (ly.x0 - 26)) < 20 && sp.y >= ly.yT && sp.y <= ly.yFloor { onHeight() }
            })
        }
        .aspectRatio(lay.VW / lay.VH, contentMode: .fit)
        .background(RoomGrid())
        .background(shape.fill(G.glass(0.55)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tr("wv.title", ["w": w.id])))
        .accessibilityIdentifier("elevation")
    }
}

/// The openings with the dragged one at its live place.
private func withLive(_ ops: [Opening], _ live: Drag?) -> [Opening] {
    guard let live else { return ops }
    return ops.map { o in
        guard o.id == live.id else { return o }
        var x = o; x.off = live.off; x.sill = live.sill
        return x
    }
}

/// Sill snapping (prototype snapSill): 10 mm steps; the default sill, other windows' sills and other openings' heads within 50 mm.
func snapSill(_ raw: Int, _ o: Opening, _ all: [Opening], _ defSill: Int, _ H: Int?) -> (Int, String?) {
    var v = kround(Double(raw) / 10) * 10
    var cands: [(Int, String)] = [(defSill, "def")]
    for x in all where x.id != o.id && x.wall == o.wall {
        if x.type == "window" { cands.append((x.sill, "sill")) }
        cands.append((x.sill + x.h - o.h, "top"))
    }
    var tag: String? = nil
    if let best = cands.filter({ $0.0 >= 0 && abs($0.0 - v) <= 50 }).min(by: { abs($0.0 - v) < abs($1.0 - v) }) { v = best.0; tag = best.1 }
    v = H.map { min(max(v, 0), max(0, $0 - o.h)) } ?? max(0, v)
    return (v, tag)
}

private func drawElevation(_ ctx: GraphicsContext, _ lay: ElevLayout, _ r: Room, _ w: Geo.Wall, _ ops: [Opening], _ fr: WallFrame, _ n: Int,
                           _ unit: LenUnit, _ en: Bool, _ live: Drag?, _ issueOf: (Opening) -> Bool) {
    let x0 = lay.x0, x1 = lay.x(fr.L), yT = lay.yT, yF = lay.yFloor
    // floor: a hatched band 7 high reaching 14 past each side, and the floor line
    var fc = ctx; fc.clip(to: Path(CGRect(x: x0 - 14, y: yF, width: x1 - x0 + 28, height: 7)))
    var hx = x0 - 21
    while hx < x1 + 14 { fc.line(PC.ink, CGPoint(x: hx, y: yF + 7), CGPoint(x: hx + 7, y: yF), 1); hx += 4 }
    ctx.line(PC.ink, CGPoint(x: x0 - 14, y: yF), CGPoint(x: x1 + 14, y: yF), 2.4)
    // the wall face; its sides dashed while the length is not confirmed, the top while the height is not
    ctx.fill(Path(CGRect(x: x0, y: yT, width: x1 - x0, height: yF - yT)), with: .color(PC.white))
    let dash: [CGFloat] = [5, 4]
    ctx.line(PC.ink, CGPoint(x: x0, y: yT), CGPoint(x: x0, y: yF), 1.4, dash: fr.lenKnown ? nil : dash)
    ctx.line(PC.ink, CGPoint(x: x1, y: yT), CGPoint(x: x1, y: yF), 1.4, dash: fr.lenKnown ? nil : dash)
    ctx.line(PC.ink, CGPoint(x: x0, y: yT), CGPoint(x: x1, y: yT), 1.4, dash: fr.hKnown ? nil : dash)
    // corner numbers above the wall: start on the left, end on the right
    for (x, c) in [(x0, w.corner), (x1, w.corner % max(1, n) + 1)] {
        let p = CGPoint(x: x, y: yT - 14)
        ctx.disc(PC.white, 9, p); ctx.ring(PC.ink3, 9, p, 1)
        ctx.text("\(c)", p, .ui, 10, 600, PC.ink)
    }
    // guide lines while a window is dragged
    if let live, fr.H > 0, let o = ops.first(where: { $0.id == live.id }), o.type == "window" {
        func guide(_ yMm: Int, _ on: Bool) { ctx.line(PC.cob.opacity(on ? 1 : 0.6), CGPoint(x: x0, y: lay.y(yMm)), CGPoint(x: x1, y: lay.y(yMm)), on ? 1.6 : 0.9, dash: on ? nil : [4, 3]) }
        guide(o.sill, live.tag == "sill" || live.tag == "def")
        guide(o.sill + o.h, live.tag == "top")
        let rightRoom = x1 - lay.x(o.off + o.w) >= 46
        let gx = rightRoom ? lay.x(o.off + o.w) + 12 : lay.x(o.off) - 12
        let tx = gx + (rightRoom ? 14 : -14)
        if lay.y(0) - lay.y(o.sill) >= 2 {
            ctx.line(PC.cob, CGPoint(x: gx, y: lay.y(0)), CGPoint(x: gx, y: lay.y(o.sill)), 1)
            ctx.text(Geo.fmtLen(o.sill, unit, en), CGPoint(x: tx, y: (lay.y(0) + lay.y(o.sill)) / 2), .num, 10.5, 600, PC.cob)
        }
        let top = fr.H - o.sill - o.h
        if top > 0 && lay.y(o.sill + o.h) - lay.y(fr.H) >= 2 {
            ctx.line(PC.cob, CGPoint(x: gx, y: lay.y(o.sill + o.h)), CGPoint(x: gx, y: lay.y(fr.H)), 1)
            ctx.text(Geo.fmtLen(top, unit, en), CGPoint(x: tx, y: (lay.y(o.sill + o.h) + lay.y(fr.H)) / 2), .num, 10.5, 600, PC.cob)
        }
    }
    // doors and windows to scale (one universal look, one colour)
    for o in ops {
        let bad = issueOf(o)
        let c = bad ? PC.red : live?.id == o.id ? PC.cob : PC.ink
        let rect = CGRect(x: lay.x(o.off), y: lay.y(o.sill + o.h), width: max(2, CGFloat(o.w) * lay.s), height: max(2, CGFloat(o.h) * lay.s))
        ctx.fill(Path(rect), with: .color(DOOR_FILL)); ctx.stroke(Path(rect), with: .color(c), lineWidth: 1.4)
        if o.type == "door" {
            ctx.stroke(Path(CGRect(x: rect.minX + 3, y: rect.minY + 3, width: rect.width - 6, height: rect.height - 3)), with: .color(c), lineWidth: 0.9)
            ctx.disc(c, 1.8, CGPoint(x: rect.maxX - 7, y: rect.minY + rect.height * 0.55))
        } else {
            ctx.line(c, CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.midX, y: rect.maxY), 1)
            ctx.line(c, CGPoint(x: rect.minX - 3, y: rect.maxY), CGPoint(x: rect.maxX + 3, y: rect.maxY), 2)
        }
        if rect.width > 30 && rect.height > 26 { ctx.text(Geo.fmtLen(o.h, unit, en), CGPoint(x: rect.midX, y: rect.midY), .num, 10, 400, PC.ink3) }
        if o.approx && live?.id != o.id { ctx.stroke(Path(rect.insetBy(dx: -3, dy: -3)), with: .color(PC.amber), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])) }
        if bad { ctx.stroke(Path(rect.insetBy(dx: -3, dy: -3)), with: .color(PC.red), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3])) }
    }
    // the chain of distances along the floor
    if !ops.isEmpty {
        let y = yF + 18
        let cuts = Array(Set(([0] + ops.flatMap { [$0.off, $0.off + $0.w] } + [fr.L]).map { min(max($0, 0), fr.L) })).sorted()
        ctx.line(PC.ink3, CGPoint(x: lay.x(0), y: y), CGPoint(x: lay.x(fr.L), y: y), 0.9, dash: fr.lenKnown ? nil : dash)
        for cx in cuts { let x = lay.x(cx); ctx.line(PC.ink3, CGPoint(x: x - 3, y: y + 3), CGPoint(x: x + 3, y: y - 3), 1.2) }
        for k in 0..<max(0, cuts.count - 1) {
            let a = lay.x(cuts[k]), b = lay.x(cuts[k + 1])
            let last = k == cuts.count - 2
            let t = last && !fr.lenKnown ? "?" : Geo.fmtLen(cuts[k + 1] - cuts[k], unit, en)
            let narrow = (b - a) < 8 * CGFloat(t.count)
            ctx.text(t, CGPoint(x: (a + b) / 2, y: narrow && k % 2 == 1 ? y + 22 : y + 10), .num, 10.5, 400, PC.ink3)
        }
    }
    // overall length, and the height on the left
    let ly = yF + lay.chainH + 30
    let lc = fr.lenSt == "conf" ? PC.ink : fr.lenSt == "recv" ? PC.amber : PC.greyLine
    ctx.line(lc, CGPoint(x: x0, y: ly), CGPoint(x: x1, y: ly), 1.1, dash: fr.lenSt == "conf" ? nil : dash)
    for x in [x0, x1] { ctx.line(lc, CGPoint(x: x - 4, y: ly + 4), CGPoint(x: x + 4, y: ly - 4), 1.6) }
    let lenTxt = w.derived && !r.isPoly ? "= " + w.dimKey : fr.lenSt == "recv" ? Geo.fmtLen(r.dim(w.dimKey).pending?.mm, unit, en, full: true) : fr.lenSt == "conf" ? Geo.fmtLen(w.len, unit, en) : "?"
    tag(ctx, lenTxt, CGPoint(x: (x0 + x1) / 2, y: ly), fr.lenSt, 0)
    let hxx = x0 - 26
    let hc = fr.hSt == "conf" ? PC.ink : fr.hSt == "recv" ? PC.amber : PC.greyLine
    ctx.line(hc, CGPoint(x: hxx, y: yT), CGPoint(x: hxx, y: yF), 1.1, dash: fr.hSt == "conf" ? nil : dash)
    for y in [yT, yF] { ctx.line(hc, CGPoint(x: hxx - 4, y: y + 4), CGPoint(x: hxx + 4, y: y - 4), 1.6) }
    let hTxt = fr.hSt == "recv" ? Geo.fmtLen(r.dim("H").pending?.mm, unit, en, full: true) : fr.hSt == "conf" ? Geo.fmtLen(r.dim("H").v, unit, en) : "?"
    tag(ctx, hTxt, CGPoint(x: hxx, y: (yT + yF) / 2), fr.hSt, -90)
}

private func tag(_ ctx0: GraphicsContext, _ t: String, _ c0: CGPoint, _ st: String, _ rot: Double) {
    let pw = pillW(t, st != "unset")
    var ctx = ctx0
    ctx.translateBy(x: c0.x, y: c0.y); ctx.rotate(by: .degrees(rot))
    let c = CGPoint.zero
    let rect = CGRect(x: -pw / 2, y: -13, width: pw, height: 26)
    let pill = Path(roundedRect: rect, cornerRadius: 13)
    ctx.fill(pill, with: .color(PC.pillFill(0.9)))
    ctx.stroke(pill, with: .color(st == "recv" ? PC.amber : st == "unset" ? PC.greyLine : PC.pillEdge(1)), style: StrokeStyle(lineWidth: 1.2, dash: st == "unset" ? [3, 2] : []))
    ctx.text(t, CGPoint(x: st == "conf" ? -7 : st == "recv" ? 7 : 0, y: c.y), .ui, 14, 800, PC.pillInk)
    if st == "conf" { ctx.tick(rect.maxX - 14, c.y, PC.okGreen, 2.2) }
    else if st == "recv" { ctx.clock(CGPoint(x: rect.minX + 12, y: c.y), PC.amber) }
}
