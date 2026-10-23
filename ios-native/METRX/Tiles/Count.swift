import Foundation

/*
 * Counting from the real layout (Android tiles/Count.kt): the whole tiles and the cut pieces of every surface, a cut
 * piece taken from an offcut when one is big enough, then the spare and whole boxes; the adhesive, grout, skirting,
 * corner profiles and waterproofing, and the estimate's lines with the labour.
 */

/// One tile (look and size) a layout or an order needs: tiles laid whole, cut ones, cuts taken from offcuts, then the boxes.
struct TileNeed: Equatable {
    var look: String, a: Int, b: Int, whole: Int, cut: Int, reused: Int, tiles: Int, skirtTiles: Int
    var spare: Int, withSpare: Int, perBox: Int, boxes: Int, m2: Double
    var price = ""
    /// Layouts of one tile merged with different box sizes: what their boxes hold together, m² (-1: from boxes × perBox).
    var boxed = -1.0
    /// What the boxes hold, m².
    var boxedM2: Double { boxed >= 0 ? boxed : Double(boxes) * Double(perBox) * Double(a) * Double(b) / 1e6 }
}

/// Ceiling that a value a hair over a whole number does not push up (Kotlin ceil(x - 1e-9)).
func tCeil(_ v: Double) -> Int { tInt((v - 1e-9).rounded(.up)) }

/// What a layout, a room or an order takes. Areas m², lengths m, weights kg. tooMany: a surface with too many tiles to count.
struct TileCount: Equatable {
    var needs: [TileNeed] = []
    var m2 = 0.0
    var glueKg = 0.0
    var groutKg = 0.0
    var skirtM = 0.0
    var profileM = 0.0
    var wpM2 = 0.0
    var tooMany = false

    var glueBags: Int { tCeil(glueKg / 25.0) }
    var boxes: Int { needs.reduce(0) { $0 + $1.boxes } }

    static func + (x: TileCount, o: TileCount) -> TileCount {
        // the same tile (look and size) once, its counts added up, in the order it first came; a layout priced on its
        // own stays its own line (the same tile at two prices is not one)
        var keys: [String] = []
        var groups: [String: [TileNeed]] = [:]
        for n in x.needs + o.needs {
            let k = "\(n.look)|\(n.a)|\(n.b)|\(n.price)"
            if groups[k] == nil { keys.append(k) }
            groups[k, default: []].append(n)
        }
        var merged: [TileNeed] = []
        for k in keys {
            let ns = groups[k] ?? []
            var f = ns[0]
            let ws = ns.reduce(0) { $0 + $1.withSpare }
            f.whole = ns.reduce(0) { $0 + $1.whole }
            f.cut = ns.reduce(0) { $0 + $1.cut }
            f.reused = ns.reduce(0) { $0 + $1.reused }
            f.tiles = ns.reduce(0) { $0 + $1.tiles }
            f.skirtTiles = ns.reduce(0) { $0 + $1.skirtTiles }
            f.withSpare = ws
            f.m2 = ns.reduce(0.0) { $0 + $1.m2 }
            // one box size: the boxes of the whole; layouts with their own box sizes: each one's boxes, added up.
            // The spare % is said only when it is the same for all (spare -1: they differ)
            let pb0 = ns[0].perBox, sp0 = ns[0].spare
            let onePb = ns.allSatisfy { $0.perBox == pb0 }
            f.spare = ns.allSatisfy { $0.spare == sp0 } ? sp0 : -1
            if onePb {
                f.boxes = tCeil(Double(ws) / Double(pb0))
                f.perBox = pb0
                f.boxed = -1
            } else {
                f.boxes = ns.reduce(0) { $0 + $1.boxes }
                f.perBox = 0
                f.boxed = ns.reduce(0.0) { $0 + $1.boxedM2 }
            }
            merged.append(f)
        }
        return TileCount(needs: merged, m2: x.m2 + o.m2, glueKg: x.glueKg + o.glueKg, groutKg: x.groutKg + o.groutKg, skirtM: x.skirtM + o.skirtM,
                         profileM: x.profileM + o.profileM, wpM2: x.wpM2 + o.wpM2, tooMany: x.tooMany || o.tooMany)
    }
}

/// xs sorted by key, the biggest first, equal ones keeping their order (Kotlin's sortedByDescending is stable).
private func stableDesc<E>(_ xs: [E], _ key: (E) -> Double) -> [E] {
    var ks: [Double] = []
    ks.reserveCapacity(xs.count)
    for x in xs { ks.append(key(x)) }
    let order: [Int] = xs.indices.sorted { (i: Int, j: Int) -> Bool in ks[i] > ks[j] || (ks[i] == ks[j] && i < j) }
    return order.map { xs[$0] }
}

/// New tiles for the cut pieces cuts of a tile b × a and how many came out of offcuts: a piece about a rectangle takes
/// the smallest offcut it fits in (turn: turned too), the rest of the tile is cut in two and kept when both sides are 40
/// mm or more; other shapes (a diagonal's triangles) share a tile two by two when their areas fit.
func cutTiles(_ cuts: [TPiece], _ b: Double, _ a: Double, _ turn: Bool, _ kerf: Double = 3.0) -> (Int, Int) {
    var fresh = 0, reused = 0
    var off: [(w: Double, h: Double)] = []
    func keep(_ w: Double, _ h: Double) { if w >= 40 && h >= 40 { off.append((w, h)) } }
    func split(_ w: Double, _ h: Double, _ pw: Double, _ ph: Double) {
        // of the two ways to cut the rest, the one that keeps the bigger offcut
        let rw = w - pw - kerf, rh = h - ph - kerf
        if rw * h >= w * rh { keep(rw, h); keep(pw, rh) } else { keep(w, rh); keep(rw, ph) }
    }
    for p in stableDesc(cuts.filter { $0.rectish }, { $0.pw * $0.ph }) {
        var best = -1, bestA = Double.greatestFiniteMagnitude, turned = false
        for i in off.indices {
            let o = off[i], ar = o.w * o.h
            if ar >= bestA { continue }
            if o.w >= p.pw - 0.5 && o.h >= p.ph - 0.5 { best = i; bestA = ar; turned = false }
            else if turn && o.w >= p.ph - 0.5 && o.h >= p.pw - 0.5 { best = i; bestA = ar; turned = true }
        }
        if best >= 0 {
            let o = off.remove(at: best)
            reused += 1
            if turned { split(o.w, o.h, p.ph, p.pw) } else { split(o.w, o.h, p.pw, p.ph) }
        } else {
            fresh += 1
            split(b, a, p.pw, p.ph)
        }
        if off.count > 400 {
            off = stableDesc(off, { $0.w * $0.h })
            while off.count > 300 { off.removeLast() }
        }
    }
    var rest: [Double] = []
    for p in stableDesc(cuts.filter { !$0.rectish }, { $0.area }) {
        let need = p.area * 1.04
        if let i = rest.firstIndex(where: { $0 >= need }) { rest.remove(at: i); reused += 1 }
        else { fresh += 1; if b * a - need > 0 { rest.append(b * a - need) } }
    }
    return (fresh, reused)
}

/// Grout for tiles a × b with joint mm joints, kg a m² (joints' volume: tile thickness by size, grout 1,6 kg/l).
func groutKgM2(_ a: Int, _ b: Int, _ joint: Int) -> Double {
    let t = b <= 300 ? 8.0 : b <= 600 ? 9.0 : 10.0
    return Double(a + b) / (Double(a) * Double(b)) * t * Double(joint) * 1.6
}

/// Adhesive a m²: the usual, a little more for big tiles (a thicker bed).
func glueKgM2(_ b: Int, _ base: Double) -> Double { base * (b >= 1200 ? 1.4 : b >= 600 ? 1.1 : 1.0) }

/// Counts the pieces laid of layout l; skirtMm of skirting cut from its tile, profileMm of corner profiles.
func countLaid(_ l: TileLayout, _ laid: Laid, _ skirtMm: Double = 0, _ profileMm: Double = 0, _ glueBase: Double = 5) -> TileCount {
    let spare = spareOf(l)
    var needs: [TileNeed] = []
    var grout = 0.0, glue = 0.0
    var byProd: [Int: [TPiece]] = [:]
    for pc in laid.pieces { byProd[pc.prod, default: []].append(pc) }
    for prod in byProd.keys.sorted() {
        let ps = byProd[prod] ?? []
        let look = prod == 0 ? l.look : l.look2
        let a = prod == 2 ? l.sa : l.a, b = prod == 2 ? l.sb : l.b
        let whole = ps.filter { !$0.cut }.count
        let cuts = ps.filter { $0.cut }
        let (fresh, reused) = cutTiles(cuts, Double(b), Double(a), lookOf(look).kind != "w")
        var skirtTiles = 0
        if prod == 0 && skirtMm > 0 && l.skirt > 0 {
            let strips = max(1, Int(Double(a) / (Double(l.skirt) + 3.0)))
            skirtTiles = tCeil(skirtMm / Double(b + l.joint) / Double(strips))
        }
        let tiles = whole + fresh
        let ws = tCeil(Double(tiles + skirtTiles) * (1 + Double(spare) / 100.0))
        let pb = perBox(l, a, b)
        var area = 0.0
        for pc in ps { area += pc.area }
        let m2 = area / 1e6
        needs.append(TileNeed(look: look, a: a, b: b, whole: whole, cut: cuts.count, reused: reused, tiles: tiles, skirtTiles: skirtTiles, spare: spare,
                              withSpare: ws, perBox: pb, boxes: tCeil(Double(ws) / Double(pb)), m2: m2, price: l.price))
        let skirtM2 = prod == 0 ? skirtMm / 1000 * Double(l.skirt) / 1000 : 0
        grout += m2 * groutKgM2(a, b, l.joint) + skirtM2 * groutKgM2(a, b, l.joint)
        glue += m2 * glueKgM2(b, glueBase) + skirtM2 * glueBase
    }
    var all = 0.0
    for pc in laid.pieces { all += pc.area }
    return TileCount(needs: needs, m2: all / 1e6, glueKg: glue, groutKg: grout, skirtM: skirtMm / 1000, profileM: profileMm / 1000, wpM2: 0, tooMany: !laid.tooMany.isEmpty)
}

/* ---------------- skirting, corner profiles, waterproofing ---------------- */

/// A stretch of skirting: on the vertical surface frame, from a0 to a1 mm along it.
struct TRun {
    let frame: TFrame, a0: Double, a1: Double
    var wall: String? = nil
    var len: Double { a1 - a0 }
}

/// [0, len] less the stretches cuts.
func tGaps(_ len: Double, _ cuts: [(Double, Double)]) -> [(Double, Double)] {
    var out: [(Double, Double)] = []
    var cur = 0.0
    var clipped: [(Double, Double)] = []
    for c in cuts {
        let a = max(0.0, c.0), b = min(len, c.1)
        if b > a { clipped.append((a, b)) }
    }
    // by where they start, equal ones in their order (Kotlin's sortedBy is stable)
    let order: [Int] = clipped.indices.sorted { (i: Int, j: Int) -> Bool in clipped[i].0 < clipped[j].0 || (clipped[i].0 == clipped[j].0 && i < j) }
    for k in order {
        let (a, b) = clipped[k]
        if a > cur + 1 { out.append((cur, a)) }
        cur = max(cur, b)
    }
    if len > cur + 1 { out.append((cur, len)) }
    return out
}

/// Whether a wall of the room is tiled from the floor up by one of the room's layouts (then it needs no skirting).
private func tiledToFloor(_ all: [TileLayout], _ roomId: String, _ wall: String) -> Bool {
    all.contains { l in l.roomId == roomId && l.surfs.contains { $0.id == wall && $0.mode != "band" } }
}

/// The skirting of floor layout l: along every wall less its doors, the tray and bath, and walls tiled to the floor;
/// round the columns.
func skirtRuns(_ l: TileLayout, _ g: TRoomGeo, _ all: [TileLayout]) -> [TRun] {
    if l.skirt <= 0 || !l.surfs.contains(where: { $0.id == "floor" }) { return [] }
    var out: [TRun] = []
    for w in g.walls {
        if tiledToFloor(all, g.room.id, w.id) { continue }
        var cuts: [(Double, Double)] = []
        for o in g.room.openings where o.wall == w.id && o.type == "door" { cuts.append((Double(o.off), Double(o.off + o.w))) }
        for f in g.fixes { if let c = coverOn(g, w, f) { cuts.append(c) } }
        let cols = g.rect ? g.room.features.filter { $0.wall == w.id && $0.type == "column" } : []
        for c in cols { cuts.append((Double(c.off), Double(c.off + c.w))) }
        for (a, b) in tGaps(w.len, cuts) { out.append(TRun(frame: g.wallFrame(w), a0: a, a1: b, wall: w.id)) }
        for c in cols {
            let a0 = Double(c.off), a1 = Double(c.off + c.w), d = Double(c.d)
            out.append(TRun(frame: g.wallFrame(w, d), a0: a0, a1: a1, wall: w.id))
            let fl = TFrame(g.scene(w.at(a0)), V3(w.nIn.x, 0, w.nIn.y), V3(0, 1, 0), V3(-w.t.x, 0, -w.t.y))
            let fr = TFrame(g.scene(w.at(a1)), V3(w.nIn.x, 0, w.nIn.y), V3(0, 1, 0), V3(w.t.x, 0, w.t.y))
            out.append(TRun(frame: fl, a0: 0, a1: d, wall: w.id))
            out.append(TRun(frame: fr, a0: 0, a1: d, wall: w.id))
        }
    }
    return out
}

private func tOverlap(_ a0: Double, _ a1: Double, _ b0: Double, _ b1: Double) -> Double { max(0.0, min(a1, b1) - max(a0, b0)) }

/// Corner profiles of a wall layout l, mm: round its windows and niches, up the columns and the room's outside corners.
func profileMm(_ l: TileLayout, _ g: TRoomGeo) -> Double {
    if !l.profiles { return 0 }
    var sum = 0.0
    var zones: [String: (Double, Double)] = [:]
    for s in l.surfs where g.wall(s.id) != nil { zones[s.id] = zoneOf(s, g.H) }
    // the walls in the layout's order, so the sum adds up the same way every time
    var seen = Set<String>()
    let wallIds = l.surfs.map(\.id).filter { zones[$0] != nil && seen.insert($0).inserted }
    for wid in wallIds {
        guard let z = zones[wid] else { continue }
        let lo = z.0, hi = z.1
        func edges(_ x0: Double, _ x1: Double, _ y0: Double, _ y1: Double) {
            let ov = tOverlap(y0, y1, lo, hi)
            if ov <= 0 { return }
            sum += 2 * ov
            if y1 > lo && y1 < hi { sum += x1 - x0 }
            if y0 > lo + 1 && y0 < hi { sum += x1 - x0 }
        }
        for o in g.room.openings where o.wall == wid && o.type == "window" {
            edges(Double(o.off), Double(o.off + o.w), Double(o.sill), Double(o.sill + o.h))
        }
        if g.rect {
            for f in g.room.features where f.wall == wid {
                if f.type == "column" { sum += 2 * (hi - lo) }
                else {
                    let sill = Double(f.sill)
                    let nh = min(f.h > 0 ? Double(f.h) : g.H - sill, g.H - sill)
                    edges(Double(f.off), Double(f.off + f.w), sill, sill + nh)
                }
            }
        }
    }
    // the outside corners of a drawn room (an L-shape's inner corner seen from the room is one), where both walls are tiled
    let sg = polyArea(g.floor) >= 0 ? 1.0 : -1.0
    let n = g.walls.count
    for i in 0..<n {
        let w = g.walls[i], prev = g.walls[(i - 1 + n) % n]
        if prev.t.cross(w.t) * sg >= -1e-6 { continue }
        guard let z0 = zones[prev.id], let z1 = zones[w.id] else { continue }
        sum += tOverlap(z0.0, z0.1, z1.0, z1.1)
    }
    return sum
}

/// A room's waterproofing, m²: the floor, wpUp up every wall (less its doors), and the walls by the tray and bath up
/// to the shower height.
func wpM2(_ tr: TileRoom, _ g: TRoomGeo) -> Double {
    if !tr.wp { return 0 }
    var mm2 = abs(polyArea(g.floor))
    for w in g.walls {
        let doors = g.room.openings.filter { $0.wall == w.id && $0.type == "door" }.reduce(0.0) { $0 + Double($1.w) }
        mm2 += max(0.0, w.len - doors) * Double(tr.wpUp)
        for f in g.fixes {
            if let c = coverOn(g, w, f) { mm2 += (c.1 - c.0) * max(0.0, min(Double(tr.showerH), g.H) - Double(tr.wpUp)) }
        }
    }
    return mm2 / 1e6
}

/* ---------------- whole orders ---------------- */

/// A typed surface's frame: a floor lies flat, a wall or backsplash stands up. Only its shape matters for counting.
func panelFrame(_ kind: String) -> TFrame {
    kind == "floor" ? TFrame(V3(0, 0, 0), V3(1, 0, 0), V3(0, 0, 1), V3(0, 1, 0)) : TFrame(V3(0, 0, 0), V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1))
}

/// The room of a layout as the tiles see it (nil: not measured yet).
func geoFor(_ p: Project, _ roomId: String?, _ snap: Bool, _ dx: Double = 0, _ dz: Double = 0) -> TRoomGeo? {
    guard let r = p.rooms.first(where: { $0.id == roomId }) else { return nil }
    return roomGeo(r, snap, p.troom.first { $0.roomId == r.id }?.fixes ?? [], dx, dz)
}

/// The adhesive's kg a m² as typed in the trade's prices; 0 is kept (no adhesive bought), blank or wrong is the usual 5.
func glueBaseOf(_ s: String) -> Double {
    guard let v = Double(s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")), v >= 0 else { return 5 }
    return v
}

/// What layout l of order p takes; zero until its room is measured.
func countLayout(_ p: Project, _ l: TileLayout, _ snap: Bool, _ glueBase: Double = 5) -> TileCount {
    guard let rid = l.roomId else {
        guard let s = panelSurf(l, panelFrame(l.panel?.kind ?? "floor")) else { return TileCount() }
        return countLaid(l, layAll(l, [s], nil, nil), 0, 0, glueBase)
    }
    guard let g = geoFor(p, rid, snap) else { return TileCount() }
    let fl = floorLayout(p.tiles, rid)
    let laid = layRoom(l, g, fl?.id != l.id ? fl : nil)
    let skirt = skirtRuns(l, g, p.tiles).reduce(0.0) { $0 + $1.len }
    return countLaid(l, laid, skirt, profileMm(l, g), glueBase)
}

/// What a room's layouts (or, roomId nil, the whole order) take, with the rooms' waterproofing.
func countOrder(_ p: Project, _ snap: Bool, _ glueBase: Double = 5, _ roomId: String? = nil, all: Bool? = nil) -> TileCount {
    let every = all ?? (roomId == nil)
    var c = TileCount()
    for l in p.tiles where every || l.roomId == roomId { c = c + countLayout(p, l, snap, glueBase) }
    for tr in p.troom where every || tr.roomId == roomId {
        if let g = geoFor(p, tr.roomId, snap) { c = c + TileCount(wpM2: wpM2(tr, g)) }
    }
    return c
}

private func tNum(_ s: String) -> Double { Double(s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0 }
private func tQty(_ v: Double) -> String {
    if v == v.rounded(.down) { return String(tInt(v)) }
    var s = String(format: "%.2f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
/// Kotlin's Math.round: halves go up.
private func tRound(_ v: Double) -> Double { (v + 0.5).rounded(.down) }
private func tMoney(_ v: Double) -> String { String(tInt(tRound(v))) }

/// The order's lines for the estimate (ids "t-…"): each tile in m² of whole boxes, adhesive bags, grout, corner
/// profiles, waterproofing, and the labour for the tiling, skirting, profiles and waterproofing. name gives a line's
/// stored words (strings key, values).
func tileRows(_ p: Project, _ t: TradeSet, _ snap: Bool, _ name: (String, [String: String]) -> String) -> TradeResult {
    let c = countOrder(p, snap, glueBaseOf(t.glueKg))
    var mats: [Row] = [], labor: [Row] = []
    func mat(_ key: String, _ unit: String, _ q: Double, _ price: String, _ vars: [String: String] = [:], _ id: String? = nil) {
        if q <= 0 { return }
        let pr = price.replacingOccurrences(of: " ", with: "")
        mats.append(Row(id: "t-" + (id ?? key), name: name("tl.e." + key, vars), unit: name("tu." + unit, [:]), qty: tQty(q), price: pr.isEmpty ? pr : tMoney(tNum(pr))))
    }
    func lab(_ key: String, _ amount: Double, _ vars: [String: String] = [:]) {
        if amount > 0 { labor.append(Row(id: "t-" + key, name: name("tl.e." + key, vars), amount: tMoney(amount))) }
    }
    for (i, n) in c.needs.enumerated() {
        let pr = n.price.trimmingCharacters(in: .whitespaces).isEmpty ? t.pTile : n.price
        let vars = ["a": "\(n.a)", "b": "\(n.b)", "n": "\(n.boxes)", "l": "~tl.lk." + n.look]
        mat("tile", "m2", tRound(n.boxedM2 * 100) / 100, pr, vars, "tile\(i)")
    }
    mat("glue", "bag", Double(c.glueBags), t.pGlue)
    mat("grout", "kg", Double(tCeil(c.groutKg)), t.pGrout)
    mat("prof", "m", Double(tCeil(c.profileM * 1.05 * 10)) / 10, t.pProf)
    mat("wp", "m2", Double(tCeil(c.wpM2 * 10)) / 10, t.pWp)
    // each labour line is priced by the quantity it shows, so quantity × rate is its amount
    func r1(_ v: Double) -> Double { tRound(v * 10) / 10 }
    let m2r = r1(c.m2), skR = r1(c.skirtM), prR = r1(c.profileM), wpR = r1(c.wpM2)
    lab("lab", m2r * tNum(t.lTile), ["a": tQty(m2r)])
    lab("labSkirt", skR * tNum(t.lSkirt), ["a": tQty(skR)])
    lab("labProf", prR * tNum(t.lProf), ["a": tQty(prR)])
    lab("labWp", wpR * tNum(t.lWp), ["a": tQty(wpR)])
    return TradeResult(mats: mats, labor: labor, facts: ["area": c.m2, "boxes": Double(c.boxes)])
}
