import SwiftUI

/*
 * The room editor v2's simple 3D (room-editor mockup v2 isoSvg): the room seen from a corner above, the back walls full
 * height with their doors, windows and points, the front walls cut low; polygons kept for taps.
 */

/// One polygon of the simple 3D: what it is (key "w:<wall>", "i:<item>", "" the floor, "t:<wall>" a wall's letter at
/// its one point), its corners on the screen, its fill and rim.
struct ReIsoPart {
    let key: String
    let pts: [CGPoint]
    let fill: Color
    let stroke: Color
    let lw: CGFloat
}

/// The polygons back to front, so the last one under a finger is the one on top.
func reIsoParts(_ size: CGSize, _ g: ReRoomGeo, _ items: [ReItem], cam: ReCam, top: CGFloat, sel: ReSel?, issues: Set<String>) -> [ReIsoPart] {
    var out: [ReIsoPart] = []
    guard g.poly.count >= 3 else { return out }
    let rh = Double(g.H)
    func Q(_ x: Double, _ y: Double, _ z: Double) -> CGPoint { CGPoint(x: (x - y) * 0.866, y: (x + y) * 0.5 - z) }
    var x0 = CGFloat.greatestFiniteMagnitude, y0 = CGFloat.greatestFiniteMagnitude
    var x1 = -CGFloat.greatestFiniteMagnitude, y1 = -CGFloat.greatestFiniteMagnitude
    for p in g.poly {
        for z in [0, rh] { let q = Q(p.x, p.y, z); x0 = min(x0, q.x); y0 = min(y0, q.y); x1 = max(x1, q.x); y1 = max(y1, q.y) }
    }
    let pad: CGFloat = 26
    let s = min((size.width - 2 * pad) / max(1, x1 - x0), (size.height - top - 2 * pad) / max(1, y1 - y0))
    let ox = (size.width - (x1 - x0) * s) / 2 - x0 * s
    let oy = top + (size.height - top - (y1 - y0) * s) / 2 - y0 * s
    func S2(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
        let q = Q(x, y, z)
        return CGPoint(x: (ox + q.x * s) * cam.z + cam.dx, y: (oy + q.y * s) * cam.z + cam.dy)
    }
    let edge = Color.black.opacity(0.38)
    out.append(ReIsoPart(key: "", pts: g.poly.map { S2($0.x, $0.y, 0) }, fill: RD.isoFloor, stroke: edge, lw: 0.8))
    struct W3 { let w: ReWall; let ux: Double; let uy: Double; let nx: Double; let ny: Double; let back: Bool; let d: Double }
    let poly2 = g.poly.map { CGPoint(x: $0.x, y: $0.y) }
    let walls: [W3] = g.outer.map { w in
        let dx = w.b.x - w.a.x, dy = w.b.y - w.a.y, L = max(1e-6, hypot(dx, dy))
        let ux = dx / L, uy = dy / L
        var nx = -uy, ny = ux
        let m = CGPoint(x: (w.a.x + w.b.x) / 2 + nx * 5, y: (w.a.y + w.b.y) / 2 + ny * 5)
        if !rePip(m, poly2) { nx = -nx; ny = -ny }
        return W3(w: w, ux: ux, uy: uy, nx: nx, ny: ny, back: nx + ny > 0.05, d: w.a.x + w.b.x + w.a.y + w.b.y)
    }
    func at(_ w: W3, _ t: Double, _ z: Double, _ off: Double) -> CGPoint {
        S2(w.w.a.x + w.ux * t + w.nx * off, w.w.a.y + w.uy * t + w.ny * off, z)
    }
    let glassC = Color(argb: 0x8038BDF8)
    func items3(_ w: W3) {
        for it in items where it.wall == w.w.id {
            let isSel = sel == .item(it.id)
            let bad = issues.contains(it.id) && !isSel
            let ist: Color = isSel ? RD.blue : bad ? RD.issue : edge
            let ilw: CGFloat = isSel ? 2.6 : bad ? 2.2 : 0.8
            let key = "i:" + it.id
            if it.isOpening {
                if it.isBalcony {
                    let d0 = Double(it.dist), dw = Double(it.dw), d1 = Double(it.dist + it.w), h = Double(it.h), z0 = Double(it.h - it.wh)
                    let door = [at(w, d0, 0, 4), at(w, d0 + dw, 0, 4), at(w, d0 + dw, h, 4), at(w, d0, h, 4)]
                    let glass = [at(w, d0 + dw, z0, 4), at(w, d1, z0, 4), at(w, d1, h, 4), at(w, d0 + dw, h, 4)]
                    out.append(ReIsoPart(key: key, pts: door, fill: RD.doorf, stroke: ist, lw: ilw))
                    out.append(ReIsoPart(key: key, pts: glass, fill: glassC, stroke: ist, lw: ilw))
                } else {
                    let z0 = Double(it.z0), z1 = Double(it.top), t0 = Double(it.dist), t1 = Double(it.dist + it.w)
                    let fillI = it.kind == "door" && it.style != "glass" ? RD.doorf : glassC
                    let pts = [at(w, t0, z0, 4), at(w, t1, z0, 4), at(w, t1, z1, 4), at(w, t0, z1, 4)]
                    out.append(ReIsoPart(key: key, pts: pts, fill: fillI, stroke: ist, lw: ilw))
                }
            } else {
                let q = 110.0, d = Double(it.dist), z = Double(it.ph)
                let pts = [at(w, d - q, z - q, 5), at(w, d + q, z - q, 5), at(w, d + q, z + q, 5), at(w, d - q, z + q, 5)]
                out.append(ReIsoPart(key: key, pts: pts, fill: RD.kind(it.kind), stroke: isSel ? RD.blue : bad ? RD.issue : .white, lw: isSel ? 2.6 : 1))
            }
        }
    }
    func wall3(_ w: W3, _ hh: Double, _ full: Bool) {
        let t = Double(w.w.t)
        let selW = sel == .wall(w.w.id)
        let face = [S2(w.w.a.x, w.w.a.y, 0), S2(w.w.b.x, w.w.b.y, 0), S2(w.w.b.x, w.w.b.y, hh), S2(w.w.a.x, w.w.a.y, hh)]
        let cap = [S2(w.w.a.x, w.w.a.y, hh), S2(w.w.b.x, w.w.b.y, hh),
                   S2(w.w.b.x - w.nx * t, w.w.b.y - w.ny * t, hh), S2(w.w.a.x - w.nx * t, w.w.a.y - w.ny * t, hh)]
        let st = selW ? RD.blue : edge
        let lw: CGFloat = selW ? 2.6 : 0.8
        out.append(ReIsoPart(key: "w:" + w.w.id, pts: face, fill: abs(w.ux) > abs(w.uy) ? RD.isoWall : RD.isoWall2, stroke: st, lw: lw))
        out.append(ReIsoPart(key: "w:" + w.w.id, pts: cap, fill: RD.isoCap, stroke: st, lw: lw))
        guard full else { return }
        items3(w)
        let tp = S2((w.w.a.x + w.w.b.x) / 2, (w.w.a.y + w.w.b.y) / 2, hh + 140)
        out.append(ReIsoPart(key: "t:" + w.w.id, pts: [tp], fill: .clear, stroke: .clear, lw: 0))
    }
    let order = walls.sorted { $0.d < $1.d }
    for w in order where w.back { wall3(w, rh, true) }
    // the inner walls (room-editor mockup v3) as boxes, back to front: their sides that face us, the top, and the
    // doors, windows and points on their faces that face us; an arch's passage open below its lintel
    let faces = g.walls.filter { $0.inner }
    for b in g.bodies.sorted(by: { reBodyDepth($0) < reBodyDepth($1) }) {
        let selP = sel == .piece(b.pid)
        let bad = issues.contains(b.pid) && !selP
        let st: Color = selP ? RD.blue : bad ? RD.issue : edge
        let lw: CGFloat = selP ? 2.6 : bad ? 2.2 : 0.8
        let hh = Double(b.h)
        for (j, R) in b.R.enumerated() {
            reIsoBox(R, 0, hh, "p:" + b.pid, st, lw, S2, &out)
            // the lintel over an arch's passage, between its two halves
            if j == 0, let gp = b.gap, gp.count == 2, b.R.count >= 2, b.oph > 0, Double(b.oph) < hh {
                let t = Double(b.th) / 2
                let q = [Pt(x: gp[0].x + b.n.x * t, y: gp[0].y + b.n.y * t), Pt(x: gp[1].x + b.n.x * t, y: gp[1].y + b.n.y * t),
                         Pt(x: gp[1].x - b.n.x * t, y: gp[1].y - b.n.y * t), Pt(x: gp[0].x - b.n.x * t, y: gp[0].y - b.n.y * t)]
                reIsoBox(q, Double(b.oph), hh, "p:" + b.pid, st, lw, S2, &out)
            }
        }
        for f in faces where iwPieceOf(f.id) == b.pid {
            guard let lk = f.look, lk.x + lk.y > 0.05 else { continue }
            let dx = f.b.x - f.a.x, dy = f.b.y - f.a.y, L = max(1e-6, hypot(dx, dy))
            items3(W3(w: f, ux: dx / L, uy: dy / L, nx: lk.x, ny: lk.y, back: true, d: 0))
        }
    }
    for w in order where !w.back { wall3(w, 280, false) }
    return out
}

/// How far back a piece stands in the simple 3D (smaller is further).
func reBodyDepth(_ b: ReBody) -> Double {
    let pts = b.R.flatMap { $0 }
    guard !pts.isEmpty else { return 0 }
    return pts.reduce(0) { $0 + $1.x + $1.y } / Double(pts.count)
}

/// A box over plan polygon R from z0 to z1: the sides that face us (outward to +x +y), then its top.
func reIsoBox(_ R: [Pt], _ z0: Double, _ z1: Double, _ key: String, _ st: Color, _ lw: CGFloat, _ S2: (Double, Double, Double) -> CGPoint, _ out: inout [ReIsoPart]) {
    guard R.count >= 3 else { return }
    var cx = 0.0, cy = 0.0
    for q in R { cx += q.x / Double(R.count); cy += q.y / Double(R.count) }
    for i in R.indices {
        let a = R[i], b = R[(i + 1) % R.count]
        let mx = (a.x + b.x) / 2 - cx, my = (a.y + b.y) / 2 - cy
        // the side's outward direction (away from the middle), seen when it points to the viewer
        var nx = -(b.y - a.y), ny = b.x - a.x
        if nx * mx + ny * my < 0 { nx = -nx; ny = -ny }
        guard nx + ny > 0.001 else { continue }
        let side = [S2(a.x, a.y, z0), S2(b.x, b.y, z0), S2(b.x, b.y, z1), S2(a.x, a.y, z1)]
        out.append(ReIsoPart(key: key, pts: side, fill: abs(b.x - a.x) > abs(b.y - a.y) ? RD.isoWall : RD.isoWall2, stroke: st, lw: lw))
    }
    out.append(ReIsoPart(key: key, pts: R.map { S2($0.x, $0.y, z1) }, fill: RD.isoCap, stroke: st, lw: lw))
}

func reDrawIso(_ ctx: GraphicsContext, _ parts: [ReIsoPart]) {
    for p in parts {
        if p.key.hasPrefix("t:"), let c = p.pts.first { ctx.text(String(p.key.dropFirst(2)), c, .ui, 12, 800, RD.ink2); continue }
        ctx.poly(p.pts, fill: p.fill, stroke: p.stroke, p.lw)
    }
}

/// What is tapped in the 3D: the last polygon under p ("w:<wall>" or "i:<item>"), or nil.
func reIsoHit(_ parts: [ReIsoPart], _ p: CGPoint) -> String? {
    for x in parts.reversed() where !x.key.isEmpty && !x.key.hasPrefix("t:") && x.pts.count >= 3 && rePip(p, x.pts) { return x.key }
    return nil
}
