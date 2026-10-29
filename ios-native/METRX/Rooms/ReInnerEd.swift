import SwiftUI

/*
 * Inner walls in the room editor and the openings step (room-editor mockup v3, approved 28 Oct 2026: iwWinHtml, iwPick,
 * iwSet, iwRotate, iwSetLen, iwMoveGap, iwCopy, iwDel, startIw / doIw / endIw, iwPills, iwCard, iwIssues): the
 * "Devor qo‘shish" window of ready pieces drawn from above, a new piece in the middle of the plan, dragged with the
 * smart snap (an end within 300 mm of a wall stretches to it, the wall glows green), turned 90°, its length, gaps,
 * thickness, height and passage typed, copied and deleted, all with Undo. Its faces are walls: tapping a selected
 * piece again selects the face under the finger, for doors, windows and points.
 */

/// A piece kind's name ("To‘g‘ri devor").
func iwName(_ k: String) -> String { reTr("iw.k." + k) }

/// "2 000 × 100 × 2 700", "400 × 400 · dumaloq", "2 400 × 100 × 2 700 · o‘tish 900 × 2 100" (mockup iwSize).
func iwSizeLine(_ p: InnerWall, _ rh: Int) -> String {
    if p.k == "col" { return reLen(p.len) + " × " + reLen(p.len) + " · " + tr(p.round ? "iw.round" : "iw.square") }
    var s = reLen(p.len) + (p.len2 > 0 ? " + " + reLen(p.len2) : "") + " × " + reLen(p.th) + " × " + reLen(p.k == "half" ? (p.h > 0 ? p.h : 1100) : rh)
    if p.k == "arch", let op = p.op { s += " · " + reTr("iw.pass", ["w": reLen(op.w), "h": reLen(op.h)]) }
    return s
}

/// A ready piece's card line (mockup iwCardLine).
func iwCardLine(_ k: String) -> String {
    let D = iwKind(k)
    switch k {
    case "col": return reTr("iw.cl.col")
    case "half": return reLen(D.len) + " × 100 · h " + reLen(D.h) + " · " + reTr("iw.d.half")
    case "arch": return reLen(D.len) + " × 100 · " + reTr("iw.pass", ["w": reLen(D.op?.w ?? 900), "h": reLen(D.op?.h ?? 2100)])
    default: return reLen(D.len) + (D.len2 > 0 ? " + " + reLen(D.len2) : "") + " × 100 · " + reTr("iw.cl.ceil")
    }
}

/// The middle of the room's plan (mockup roomCen): its box's middle when inside, else its centroid, else 600 mm in
/// front of wall A.
func iwRoomCentre(_ g: ReRoomGeo) -> Pt {
    let P = g.poly
    guard P.count >= 3 else { return Pt(x: 0, y: 0) }
    let xs = P.map(\.x), ys = P.map(\.y)
    let c = Pt(x: (xs.min()! + xs.max()!) / 2, y: (ys.min()! + ys.max()!) / 2)
    if iwInside(c, P) { return c }
    var A = 0.0, cx = 0.0, cy = 0.0
    for i in P.indices { let p = P[i], q = P[(i + 1) % P.count], k = p.x * q.y - q.x * p.y; A += k / 2; cx += (p.x + q.x) * k; cy += (p.y + q.y) * k }
    if abs(A) > 1e-6 { let c2 = Pt(x: cx / (6 * A), y: cy / (6 * A)); if iwInside(c2, P) { return c2 } }
    if let f = reWallAFrame(g), let w = g.outer.first { return Pt(x: (w.a.x + w.b.x) / 2 + f.n.x * 600, y: (w.a.y + w.b.y) / 2 + f.n.y * 600) }
    return c
}

/// Every wall and face with its into-the-room side, for the door zones.
func iwZoneWalls(_ g: ReRoomGeo) -> [(id: String, a: Pt, u: Pt, n: Pt, th: Int, inner: Bool)] {
    g.walls.map { w -> (id: String, a: Pt, u: Pt, n: Pt, th: Int, inner: Bool) in
        let L = max(1e-6, hypot(w.b.x - w.a.x, w.b.y - w.a.y))
        let u = Pt(x: (w.b.x - w.a.x) / L, y: (w.b.y - w.a.y) / L)
        var n = Pt(x: -u.y, y: u.x)
        if let lk = w.look { n = lk } else {
            let probe = Pt(x: (w.a.x + w.b.x) / 2 + n.x * 20, y: (w.a.y + w.b.y) / 2 + n.y * 20)
            if !iwInside(probe, g.poly) { n = Pt(x: -n.x, y: -n.y) }
        }
        return (id: w.id, a: w.a, u: u, n: n, th: w.t, inner: w.inner)
    }
}

/// Tekshiruv for the room: the items' rules, and the inner walls that fall into a door's swing or block a doorway
/// (code "iw.swing" / "iw.block", the piece's id and kind, the door's wall).
func reRoomIssues(_ r: Room, _ g: ReRoomGeo) -> [ReIssue] {
    var out = reIssues(reItems(r), lens: g.lens, roomH: g.H)
    guard !r.inner.isEmpty else { return out }
    let zones = iwDoorZones(r, iwZoneWalls(g))
    for q in iwIssues(r, zones) {
        let k = r.inner.first { $0.id == q.pid }?.k ?? "straight"
        out.append(ReIssue(id: q.pid, code: q.swing ? "iw.swing" : "iw.block", kinds: [k], wall: q.wall))
    }
    return out
}

/* ---------------- the actions ---------------- */

extension ReState {
    func selectPiece(_ id: String, _ h: ReHost) {
        sel = .piece(id); arm = nil
        if let n = newPiece, n != id { newPiece = nil }
        if let s = strip, !reToolIds(self, h).contains(s) { strip = nil }
        Haptic.tick()
    }

    /// The selected piece (or the piece of the selected face).
    func curPiece(_ h: ReHost) -> InnerWall? {
        guard let r = h.room() else { return nil }
        if let id = selPiece { return r.inner.first { $0.id == id } }
        if let w = selWall, let pid = iwPieceOf(w) { return r.inner.first { $0.id == pid } }
        return nil
    }

    /// A ready piece from the window: in the middle of the plan, shrunk so it does not stretch at once, selected.
    func iwPick(_ k: String, _ app: AppModel, _ h: ReHost) {
        guard let r = h.room() else { return }
        let g = reGeo(r)
        let p = iwNew(k, iwRoomCentre(g), r, g.outer)
        iwWin = false
        commit(app, h, reTr("iw.m.added", ["n": iwName(k)])) { $0.inner.append(p); return nil }
        sel = .piece(p.id); newPiece = p.id; arm = nil; strip = nil
    }

    /// A change to piece id, its doors, windows and points kept on their faces (and within them).
    @discardableResult
    func iwChange(_ id: String, _ msg: String, _ app: AppModel, _ h: ReHost, _ fn: (inout InnerWall, Room, ReRoomGeo) -> String?) -> Bool {
        commit(app, h, msg) { r in
            guard let i = r.inner.firstIndex(where: { $0.id == id }) else { return nil }
            let g = reGeo(r)
            var x = r.inner[i]
            if let why = fn(&x, r, g) { return why }
            r.inner[i] = x
            reClampItems(&r)
            return nil
        }
    }

    func iwRotate(_ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), let r = h.room() else { return }
        newPiece = nil
        var t = p
        t.ang = (t.ang + 90) % 360
        let g = reGeo(r)
        let m = iwSnap(r, g.outer, g.poly, t)
        iwChange(p.id, reTr("iw.m.rot", ["n": iwName(p.k)]) + (m.stretched ? " · " + reTr("iw.m.stretched") : ""), app, h) { x, _, _ in x = m.p; return nil }
    }

    /// The length (a column's side): the piece keeps its start (P0) where it is.
    func iwSetLen(_ v: Int, _ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), v != p.len else { return }
        guard v >= (p.k == "col" ? 100 : 300), v <= SHAPE_WALL_MAX else { warn(app, reTr("iw.m.range")); return }
        let msg = tr(p.k == "col" ? "iw.m.size" : "iw.m.len", ["n": iwName(p.k), "a": reLen(p.len), "b": reLen(v)])
        iwChange(p.id, msg, app, h) { x, r, _ in
            if x.k != "col" {
                let G = iwGeo(x, reHeight(r))
                x.x = Int((G.P0.x + G.d.x * Double(v) / 2).rounded()); x.y = Int((G.P0.y + G.d.y * Double(v) / 2).rounded())
            }
            x.len = v
            return nil
        }
    }

    /// A gap to the nearest wall typed (field S0 / S1 / E0 / E1): the piece moves so the gap is v.
    func iwMoveGap(_ field: String, _ v: Int, _ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), let r = h.room() else { return }
        let g = reGeo(r)
        guard let res = iwSides(r, g.outer, p)[field], res.gap != v else { return }
        let sh = Double(res.gap - v)
        iwChange(p.id, reTr("iw.m.gap", ["n": iwName(p.k), "v": reLen(v)]), app, h) { x, _, _ in
            x.x = Int((Double(x.x) + res.dir.x * sh).rounded()); x.y = Int((Double(x.y) + res.dir.y * sh).rounded())
            return nil
        }
    }

    func iwSetTh(_ v: Int, _ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), v != p.th else { return }
        guard v >= 50, v <= 1000 else { warn(app, reTr("iw.m.range")); return }
        iwChange(p.id, reTr("iw.m.th", ["n": iwName(p.k), "v": reLen(v)]), app, h) { x, _, _ in x.th = v; return nil }
    }

    func iwSetH(_ v: Int, _ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), let r = h.room() else { return }
        guard v >= 300, v < reHeight(r) else { warn(app, reTr("iw.m.hRange", ["v": reLen(reHeight(r))])); return }
        iwChange(p.id, reTr("iw.m.h", ["n": iwName(p.k), "v": reLen(v)]), app, h) { x, _, _ in x.h = v; return nil }
    }

    func iwSetOp(w: Int? = nil, hh: Int? = nil, _ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), let r = h.room(), let op = p.op else { return }
        let nw = w ?? op.w, nh = hh ?? op.h
        guard nw >= 400, nw <= p.len - 200, nh >= 1000, nh <= reHeight(r) - 50 else { warn(app, reTr("iw.m.opRange")); return }
        iwChange(p.id, reTr("iw.m.op", ["n": iwName(p.k), "w": reLen(nw), "h": reLen(nh)]), app, h) { x, _, _ in x.op = InnerOp(w: nw, h: nh); return nil }
    }

    func iwRound(_ on: Bool, _ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), p.round != on else { return }
        iwChange(p.id, tr(on ? "iw.m.round" : "iw.m.square", ["n": iwName(p.k)]), app, h) { x, _, _ in x.round = on; return nil }
    }

    /// "Nusxa": the same piece 600 mm to a side that is inside the room (a column its size + 400).
    func iwCopy(_ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), let r = h.room() else { return }
        let g = reGeo(r), G = iwGeo(p, g.H)
        let off = p.k == "col" ? Double(p.len + 400) : 600
        var ok: Pt? = nil
        for dv in [G.n, Pt(x: -G.n.x, y: -G.n.y), G.d, Pt(x: -G.d.x, y: -G.d.y)] {
            let c = Pt(x: G.c.x + dv.x * off, y: G.c.y + dv.y * off)
            if iwInside(c, g.poly) { ok = c; break }
        }
        guard let c = ok else { warn(app, reTr("iw.m.noCopy")); return }
        var cp = p
        cp.id = uid(); cp.x = Int(c.x.rounded()); cp.y = Int(c.y.rounded())
        if commit(app, h, reTr("iw.m.copy", ["n": iwName(p.k)]), { $0.inner.append(cp); return nil }) { sel = .piece(cp.id) }
    }

    /// "O‘chirish": the piece and the doors, windows and points on its faces.
    func iwDel(_ app: AppModel, _ h: ReHost) {
        guard let p = curPiece(h), let r = h.room() else { return }
        let lost = r.openings.filter { iwPieceOf($0.wall) == p.id }.count + r.points.filter { iwPieceOf($0.wall) == p.id }.count
        let msg = reTr("iw.m.del", ["n": iwName(p.k)]) + (lost > 0 ? " · " + reTr("iw.m.delN", ["n": lost]) : "")
        commit(app, h, msg) { r in
            r.inner.removeAll { $0.id == p.id }
            r.openings.removeAll { iwPieceOf($0.wall) == p.id }
            r.points.removeAll { iwPieceOf($0.wall) == p.id }
            return nil
        }
        sel = nil; strip = nil; newPiece = nil
    }

    /* the drag: the piece follows the finger inside the room's box, its ends stretch to the walls near them */

    /// A drag of piece id began at plan millimetre q.
    func iwDragBegin(_ id: String, _ q: Pt, _ h: ReHost) {
        guard let r = h.room(), r.inner.contains(where: { $0.id == id }) else { return }
        sel = .piece(id); arm = nil
        if let s = strip, !reToolIds(self, h).contains(s) { strip = nil }
        live = ReLive(mode: "iw", id: id, snap: r, grab: CGFloat(q.x), hgrab: CGFloat(q.y))
        Haptic.tick()
    }

    func iwDragMove(_ q: Pt) {
        guard let lv = live, lv.mode == "iw", let base = lv.snap, let i = base.inner.firstIndex(where: { $0.id == lv.id }) else { return }
        let g = reGeo(base)
        let b = base.inner[i]
        let xs = g.poly.map(\.x), ys = g.poly.map(\.y)
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return }
        var p = b
        p.x = Int(min(x1, max(x0, Double(b.x) + q.x - Double(lv.grab))).rounded())
        p.y = Int(min(y1, max(y0, Double(b.y) + q.y - Double(lv.hgrab))).rounded())
        var probe = base
        probe.inner[i] = p
        let res = iwSnap(probe, g.outer, g.poly, p)
        probe.inner[i] = res.p
        reClampItems(&probe)
        preview = probe
        iwGlow = Set(res.hits)
        live?.changed = true
        live?.edge = res.stretched ? "s" : ""
    }

    /// The drag ended: kept with its message and Undo (a cancelled one goes back).
    func iwDragEnd(_ cancel: Bool, _ app: AppModel, _ h: ReHost) {
        guard let lv = live, lv.mode == "iw" else { return }
        live = nil
        let pv = preview
        preview = nil
        iwGlow = []
        guard !cancel, lv.changed, let r = pv, let p = r.inner.first(where: { $0.id == lv.id }) else { return }
        newPiece = nil
        let msg = reTr("iw.m.moved", ["n": iwName(p.k), "l": reLen(p.len) + (p.len2 > 0 ? " + " + reLen(p.len2) : "")]) + (lv.edge == "s" ? " · " + reTr("iw.m.stretched") : "")
        commit(app, h, msg) { $0 = r; return nil }
    }

    /// A tap on a piece: the first selects it, the next (on the selected piece) its face under the finger.
    func iwTap(_ id: String, _ q: Pt, _ h: ReHost) {
        guard let r = h.room() else { return }
        if selPiece == id {
            let g = reGeo(r)
            var best: (d: Double, id: String)? = nil
            for w in g.walls where w.inner && iwPieceOf(w.id) == id {
                let d = iwSegDist(q, w.a, w.b)
                if best == nil || d < best!.d { best = (d, w.id) }
            }
            if let b = best { selectWall(b.id, h); return }
        }
        selectPiece(id, h)
    }
}

/// How far q is from the segment a–b, mm.
func iwSegDist(_ q: Pt, _ a: Pt, _ b: Pt) -> Double {
    let dx = b.x - a.x, dy = b.y - a.y, L2 = dx * dx + dy * dy
    let t = L2 < 1e-9 ? 0 : max(0, min(1, ((q.x - a.x) * dx + (q.y - a.y) * dy) / L2))
    return hypot(q.x - (a.x + dx * t), q.y - (a.y + dy * t))
}

/* ---------------- the "Devor qo‘shish" window ---------------- */

let IW_IC = "M3 20h18M5 20V8l4-3 4 3v12M13 12h6v8"

/// A ready piece drawn from above for its card (mockup iwThumb).
struct IwThumb: View {
    let k: String
    var body: some View {
        Canvas { ctx, sz in
            let frame = CGRect(x: 6, y: 5, width: sz.width - 12, height: sz.height - 10)
            ctx.box(frame, stroke: G.ink.opacity(0.18), 1, rx: 4)
            if k == "col" {
                ctx.box(CGRect(x: sz.width * 0.28, y: sz.height / 2 - 14, width: 28, height: 28), fill: RD.wallc)
                ctx.fill(Path(ellipseIn: CGRect(x: sz.width * 0.7 - 14, y: sz.height / 2 - 14, width: 28, height: 28)), with: .color(RD.wallc))
                return
            }
            var p = iwNew(k, Pt(x: 0, y: 0), Room(id: "t", floorId: "", name: ""), [], id: "t")
            p.th = 150
            p.len = iwKind(k).len; p.len2 = iwKind(k).len2
            let G = iwGeo(p, 2700)
            let pts = G.R.flatMap { $0 }
            guard let mnx = pts.map(\.x).min(), let mxx = pts.map(\.x).max(), let mny = pts.map(\.y).min(), let mxy = pts.map(\.y).max() else { return }
            let s = min((sz.width - 44) / CGFloat(max(1, mxx - mnx)), (sz.height - 30) / CGFloat(max(1, mxy - mny)))
            let ox = (sz.width - CGFloat(mxx - mnx) * s) / 2 - CGFloat(mnx) * s, oy = (sz.height - CGFloat(mxy - mny) * s) / 2 - CGFloat(mny) * s
            func M(_ q: Pt) -> CGPoint { CGPoint(x: ox + CGFloat(q.x) * s, y: oy + CGFloat(q.y) * s) }
            for R in G.R { ctx.poly(R.map(M), fill: k == "half" ? RD.wallc.opacity(0.45) : RD.wallc) }
            if let gp = G.gap {
                let t = Double(p.th) / 2
                for k2 in [t, -t] {
                    ctx.line(RD.wallc, M(Pt(x: gp.0.x + G.n.x * k2, y: gp.0.y + G.n.y * k2)), M(Pt(x: gp.1.x + G.n.x * k2, y: gp.1.y + G.n.y * k2)), 1.4, dash: [3, 3])
                }
            }
        }
        .frame(height: 78)
        .accessibilityHidden(true)
    }
}

/// The window of ready pieces (mockup iwWinHtml): six top-view cards, the note, Bekor.
struct ReIwWindow: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    var body: some View {
        if st.iwWin, let r = h.room() {
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.32).ignoresSafeArea()
                    .onTapGesture { st.iwWin = false }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        PathIcon(IW_IC, .white, 18, 2).frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RD.wallc))
                        VStack(alignment: .leading, spacing: 1) {
                            T(reTr("iw.winT"), ui(15, 800), lines: 1)
                            T(reTr("iw.winS"), ui(12, 500, G.ink2, lh: 1.2), lines: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        MIcon("x", G.ink2, 17, 2).frame(width: 38, height: 38).background(Circle().fill(G.ink.opacity(0.06)))
                            .pressable(0.95, label: tr("common.cancel")) { st.iwWin = false }
                            .accessibilityIdentifier("iw.close")
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(IW_KINDS.map(\.id), id: \.self) { k in
                            VStack(alignment: .leading, spacing: 3) {
                                IwThumb(k: k).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.glass(0.7)))
                                // two lines: "Стена с проёмом (арка)" was cut off
                                T(iwName(k), ui(13, 800, lh: 1.15), lines: 2).minimumScaleFactor(0.85)
                                T(iwCardLine(k), num(11, 500, G.ink2), lines: 2)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.solid))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                            .pressable(0.97, label: iwName(k)) { Haptic.tick(); st.iwPick(k, app, h) }
                            .accessibilityIdentifier("iw.card." + k)
                        }
                    }
                    T(reTr("iw.note", ["h": reLen(reHeight(r))]), ui(11.5, 500, G.ink2, lh: 1.25), lines: 4)
                    GBtn(reTr("iw.cancel"), kind: .secondary, height: 48) { st.iwWin = false }
                        .accessibilityIdentifier("iw.cancel")
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(G.sheet(0.98)).ignoresSafeArea(edges: .bottom))
                .padding(.horizontal, 6)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// The leading tile of an icon row: "Devor qo‘shish" opens the window.
struct ReIwTile: View {
    let tap: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 4) {
            PathIcon(IW_IC, RD.wallc, 24, 2)
            T(reTr("iw.tile"), ui(10.5, 700, G.ink, lh: 1.05), align: .center, lines: 2).minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 2)
        .frame(width: 74, height: 66)
        .background(shape.fill(G.glass(0.78)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.96, label: reTr("iw.tile")) { Haptic.tick(); tap() }
        .accessibilityIdentifier("iw.open")
    }
}

/* ---------------- on the plan: the pills ---------------- */

/// The selected piece's live pills (mockup iwPills): its length on it, the gaps across it and past its ends — a tap
/// opens the keypad (with Lazer); "magnit · devorgacha" while an end sticks to a wall.
struct ReIwBubbles: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    let lay: ReLayout
    var body: some View {
        if let id = st.selPiece, let r = st.shown(h), let p = r.inner.first(where: { $0.id == id }), st.pk == nil {
            let res = iwSides(r, lay.g.outer, p)
            let G = iwGeo(p, lay.g.H)
            let W = lay.size.width, H = lay.size.height
            ZStack(alignment: .topLeading) {
                ForEach(res.keys.sorted(), id: \.self) { k in
                    if let x = res[k], x.gap > 1 {
                        let a = lay.map.p(x.a), b = lay.map.p(x.b)
                        if (b - a).len >= 6 {
                            pill(reLen(x.gap), mid(a, b), W, H, id: "iw.gap." + k) {
                                st.openKp(tr(k.hasPrefix("S") ? "iw.kp.gapS" : "iw.kp.gapE"), cur: x.gap, lo: 0, hi: SHAPE_WALL_MAX) { v in st.iwMoveGap(k, v, app, h) }
                            }
                        }
                    }
                }
                let lp = lay.map.p(p.k == "col" ? G.c : Pt(x: G.c.x + G.d.x * Double(p.len) / 4, y: G.c.y + G.d.y * Double(p.len) / 4))
                pill((p.k == "col" ? "" : reTr("iw.p.len") + " ") + reLen(p.len), lp, W, H, strong: true, id: "iw.len") {
                    st.openKp(tr(p.k == "col" ? "iw.kp.size" : "iw.kp.len"), cur: p.len, lo: p.k == "col" ? 100 : 300, hi: SHAPE_WALL_MAX, big: p.k != "col") { v in st.iwSetLen(v, app, h) }
                }
                if !st.iwGlow.isEmpty {
                    let mp = lay.map.p(Pt(x: G.c.x - G.n.x * (Double(p.th) / 2 + 260), y: G.c.y - G.n.y * (Double(p.th) / 2 + 260)))
                    T(reTr("iw.mag"), ui(11.5, 800, .white), lines: 1).padding(.horizontal, 10).frame(height: 26)
                        .background(Capsule().fill(RD.green))
                        .position(x: min(W - 60, max(60, mp.x)), y: min(H - 14, max(14, mp.y)))
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func pill(_ t: String, _ c: CGPoint, _ W: CGFloat, _ H: CGFloat, strong: Bool = false, id: String, _ a: @escaping () -> Void) -> some View {
        T(t, num(12, 800, strong ? .white : G.cobalt2), lines: 1).padding(.horizontal, 9).frame(minWidth: 44, minHeight: 28)
            .background(Capsule().fill(strong ? G.cobalt : G.solid))
            .overlay(Capsule().strokeBorder(G.cobalt.opacity(0.5), lineWidth: 1))
            .contentShape(Capsule())
            .pressable(0.95, label: t) { Haptic.tick(); a() }
            .accessibilityIdentifier(id)
            .position(x: min(W - 26, max(26, c.x)), y: min(H - 14, max(14, c.y)))
    }
}

/* ---------------- the openings step's floating card ---------------- */

/// The selected piece's card (mockup iwCard): its name and size, thickness chips (a column's shape), its faces, a
/// problem, and Uzunlik / Balandlik / O‘tish / Burish / Nusxa / O‘chirish.
struct ReIwCard: View {
    let app: AppModel
    let st: ReState
    let h: ReHost
    let g: ReRoomGeo
    let p: InnerWall
    let issue: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PathIcon(IW_IC, .white, 18, 2).frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RD.wallc))
                VStack(alignment: .leading, spacing: 1) {
                    T(iwName(p.k) + (st.newPiece == p.id ? " · " + reTr("iw.c.new") : ""), ui(14, 800), lines: 1)
                    T(iwSizeLine(p, g.H) + " " + unitWord(AppSettings.shared.unit), num(12, 500, G.ink2), lines: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                xb(st.cardMin ? "M6 15l6-6 6 6" : "M6 9l6 6 6-6", st.cardMin ? reTr("re.cardOpen") : reTr("re.cardMin"), "re.cardMin") { st.cardMin.toggle(); Haptic.tick() }
                xb("M6 6l12 12M18 6L6 18", reTr("re.desel"), "re.desel") { st.deselect() }
            }
            if !st.cardMin {
                HStack(spacing: 6) {
                    T(tr(p.k == "col" ? "iw.c.shape" : "iw.c.th"), ui(12, 700, G.ink2), lines: 1)
                    if p.k == "col" {
                        chip(reTr("iw.o.square"), !p.round, "iw.c.sq") { st.iwRound(false, app, h) }
                        chip(reTr("iw.o.round"), p.round, "iw.c.rd") { st.iwRound(true, app, h) }
                    } else {
                        ForEach(IW_TH, id: \.self) { v in chip(reLen(v), p.th == v, "iw.c.th\(v)") { st.iwSetTh(v, app, h) } }
                    }
                }
                let fc = g.walls.filter { $0.inner && iwPieceOf($0.id) == p.id }
                if !fc.isEmpty {
                    HStack(spacing: 6) {
                        T(reTr("iw.c.faces"), ui(12, 700, G.ink2), lines: 1)
                        ForEach(fc, id: \.id) { w in chip(w.label, false, "iw.face." + w.label) { st.selectWall(w.id, h) } }
                        T(reTr("iw.c.facesN"), ui(11, 500, G.ink3), lines: 1).minimumScaleFactor(0.8)
                    }
                }
                if let issue {
                    HStack(spacing: 6) { PathIcon(RE_IC["checks"] ?? "", RD.issue, 15, 2); T(issue, ui(12, 700, RD.issue), lines: 2) }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        act(RE_IC["len"] ?? "", tr(p.k == "col" ? "iw.t.iwSize" : "iw.t.iwLen"), "iw.b.len") {
                            st.openKp(tr(p.k == "col" ? "iw.kp.size" : "iw.kp.len"), cur: p.len, lo: p.k == "col" ? 100 : 300, hi: SHAPE_WALL_MAX, big: p.k != "col") { v in st.iwSetLen(v, app, h) }
                        }
                        if p.k == "half" {
                            act(RE_IC["h"] ?? "", reTr("iw.t.iwH"), "iw.b.h") {
                                st.openKp(reTr("iw.t.iwH"), cur: p.h > 0 ? p.h : 1100, lo: 300, hi: g.H - 1) { v in st.iwSetH(v, app, h) }
                            }
                        }
                        if p.k == "arch", let op = p.op {
                            act(RE_IC["w"] ?? "", reTr("iw.t.iwOp"), "iw.b.op") {
                                st.openKp(reTr("iw.o.opW"), cur: op.w, lo: 400, hi: p.len - 200) { v in st.iwSetOp(w: v, app, h) }
                            }
                        }
                        if p.k != "col" { act(RE_IC["rot"] ?? "", reTr("iw.t.iwRot"), "iw.b.rot") { st.iwRotate(app, h) } }
                        act(RE_IC["copy"] ?? "", reTr("iw.t.iwCopy"), "iw.b.copy") { st.iwCopy(app, h) }
                        act(RE_IC["del"] ?? "", reTr("iw.t.iwDel"), "iw.b.del", red: true) { st.iwDel(app, h) }
                    }
                }
            }
        }
        .padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 8)
    }

    private func xb(_ d: String, _ label: String, _ id: String, _ a: @escaping () -> Void) -> some View {
        PathIcon(d, G.ink2, 17, 2).frame(width: 38, height: 38)
            .background(Circle().fill(G.ink.opacity(0.06)))
            .pressable(0.95, label: label, a)
            .accessibilityIdentifier(id)
    }
    private func chip(_ t: String, _ on: Bool, _ id: String, _ a: @escaping () -> Void) -> some View {
        T(t, num(12.5, 800, on ? .white : G.ink), lines: 1).padding(.horizontal, 10).frame(minWidth: 40, minHeight: 32)
            .background(Capsule().fill(on ? G.cobalt : G.ink.opacity(0.06)))
            .pressable(0.95, label: t) { Haptic.tick(); a() }
            .accessibilityIdentifier(id)
    }
    private func act(_ icon: String, _ t: String, _ id: String, red: Bool = false, _ a: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            PathIcon(icon, red ? RD.issue : G.ink, 17, 2)
            T(t, ui(12.5, 700, red ? RD.issue : G.ink), lines: 1)
        }
        .padding(.horizontal, 11).frame(minHeight: 40)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(G.ink.opacity(0.06)))
        .pressable(0.96, label: t) { Haptic.tick(); a() }
        .accessibilityIdentifier(id)
    }
}
