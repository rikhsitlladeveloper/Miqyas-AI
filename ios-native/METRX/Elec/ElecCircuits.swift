import Foundation

/*
 * Circuits and cable routes (Android elec/Circuits.kt). The devices go into groups (lighting, the rooms' sockets, the
 * kitchen's, the bathroom's, the stove, oven, air conditioners and water heaters on lines of their own, low-voltage), one
 * breaker a group. Each group's cable runs from the panel: up to the horizontal run ZONE_DOWN under the ceiling, along
 * the walls the shorter way to the room's doorway, through the wall over the door to the next room, along its walls, and
 * straight down to each device (chased, or in a surface channel); or in corrugated pipe over the ceiling and down to
 * each device. Lengths in mm.
 */

/// One circuit: its number on the panel, its group, its devices and the rooms they are in.
struct Circuit {
    let no: Int
    let group: String
    let devs: [ElecDev]
    let rooms: [String]

    var def: GroupDef { groupDef(group) }
    var amps: Int { def.amps }
    var cable: String { def.cable }
    var rcd: Bool { def.rcd }
    var rgb: Int { def.rgb }
    /// Its load, W: every device's power.
    var load: Int { devs.reduce(0) { $0 + watts($1) } }
    /// Its points: the lights of a lighting circuit (its switches are not), else every device.
    var points: Int { group == "light" ? devs.filter { devType($0.t).cat == "light" }.count : devs.count }
}

/// A lighting circuit takes rooms while it stays under this many lights and this load (W).
let LIGHT_PTS = 20
let LIGHT_W = 1800

/// The ids once each, in their order.
private func eDistinct(_ xs: [String]) -> [String] {
    var seen = Set<String>()
    return xs.filter { seen.insert($0).inserted }
}

/// The order's circuits, numbered as on the panel: lighting, sockets room by room, the kitchens, the bathrooms, the lines
/// of their own, then low-voltage.
func circuitsOf(_ p: Project, _ cs: [ECtx]) -> [Circuit] {
    let per: [(ECtx, [ElecDev])] = cs.map { c in (c, devsIn(p, c)) }
    var out: [Circuit] = []
    func add(_ g: String, _ ds: [ElecDev]) {
        if ds.isEmpty { return }
        out.append(Circuit(no: out.count + 1, group: g, devs: ds, rooms: eDistinct(ds.map(\.roomId))))
    }
    func lightPts(_ ds: [ElecDev]) -> Int { ds.filter { devType($0.t).cat == "light" }.count }
    func load(_ ds: [ElecDev]) -> Int { ds.reduce(0) { $0 + watts($1) } }
    // lighting: room after room into one circuit while it stays small enough
    var cur: [ElecDev] = []
    for (c, ds) in per {
        let mine = ds.filter { eGroupOf($0, c.kind) == "light" }
        if mine.isEmpty { continue }
        let pts = lightPts(mine), w = load(mine)
        let cp = lightPts(cur), cw = load(cur)
        if !cur.isEmpty && (cp + pts > LIGHT_PTS || cw + w > LIGHT_W) { add("light", cur); cur = [] }
        cur += mine
    }
    add("light", cur)
    for g in ["sock", "kitch", "bath"] {
        for (c, ds) in per { add(g, ds.filter { eGroupOf($0, c.kind) == g }) }
    }
    for g in ["stove", "oven", "ac", "wh", "own"] {
        for (c, ds) in per {
            for d in ds where eGroupOf(d, c.kind) == g { add(g, [d]) }
        }
    }
    var low: [ElecDev] = []
    for (c, ds) in per { low += ds.filter { eGroupOf($0, c.kind) == "low" } }
    add("low", low)
    return out
}

/* ---------------- the walls as one loop ---------------- */

/// A room's walls end to end: a point on them as one length round the room from wall 1's start corner.
struct Perim {
    let ws: [TWall]
    let st: [Double]
    let P: Double

    init(_ c: ECtx) {
        ws = c.g.walls
        var a: [Double] = []
        var s = 0.0
        for w in ws { a.append(s); s += w.len }
        st = a
        P = s
    }

    func s(_ wall: String, _ a: Double) -> Double {
        let i = max(ws.firstIndex { $0.id == wall } ?? -1, 0)
        return st[i] + eClamp(a, 0, ws[i].len)
    }

    private func idx(_ s: Double) -> Int {
        var i = ws.count - 1
        while i > 0 && st[i] > s { i -= 1 }
        return i
    }

    /// The pieces (wall, from, to along it) of the way d mm on from s0, clockwise.
    func pieces(_ s0: Double, _ d: Double) -> [(TWall, Double, Double)] {
        var out: [(TWall, Double, Double)] = []
        if P <= 0 { return out }
        var s = eMod(eMod(s0, P) + P, P)
        var left = d
        var guardN = 0
        while left > 1e-6 && guardN < 4 * ws.count + 4 {
            guardN += 1
            let i = idx(s)
            let w = ws[i]
            let a = s - st[i]
            let step = min(left, w.len - a)
            if step > 1e-6 { out.append((w, a, a + step)) }
            left -= step
            s = eMod(st[i] + w.len, P)
            if step <= 1e-6 && w.len - a <= 1e-6 { s = st[(i + 1) % ws.count] }
        }
        return out
    }
}

/// The shortest way round the walls from e that reaches every point ts (lengths round the room): clockwise as far as
/// the first and back the other way as far as the second. It never goes round twice.
func eCover(_ P: Double, _ e: Double, _ ts: [Double]) -> (Double, Double) {
    if ts.isEmpty || P <= 0 { return (0, 0) }
    let r = ts.map { eMod(eMod($0 - e, P) + P, P) }.sorted()
    var best = (r[r.count - 1], 0.0)
    if P - r[0] < best.0 + best.1 { best = (0, P - r[0]) }
    if r.count >= 2 {
        for j in 0..<(r.count - 1) {
            let c = r[j] + (P - r[j + 1])
            if c < best.0 + best.1 { best = (r[j], P - r[j + 1]) }
        }
    }
    return best
}

/// A piece of a cable's route: from a at za to b at zb (plan mm, mm up), on wall or over the ceiling (nil).
struct ERunSeg {
    let a: V2, za: Double, b: V2, zb: Double, wall: String?
    init(_ a: V2, _ za: Double, _ b: V2, _ zb: Double, _ wall: String?) { self.a = a; self.za = za; self.b = b; self.zb = zb; self.wall = wall }
    var len: Double { hypot(hypot(b.x - a.x, b.y - a.y), zb - za) }
}

/// A circuit's route in one room: its pieces to draw, its cable length len there (with the ends and, for a room away
/// from the panel, the cable between the doors), and for counting the stretches of wall it runs along (runs, lengths
/// round the room), the drops down to each device (drops, by device, in order), its run over the ceiling (ceil).
struct CRun {
    let circuit: Circuit
    let roomId: String
    let segs: [ERunSeg]
    let len: Double
    let runs: [(Double, Double)]
    let drops: [(String, Double)]
    let ceil: Double
    let rise: Double
}

/// All the order's routes: by circuit, the cable each takes (cableOf), and whether they reach the panel.
struct Routes {
    let circuits: [Circuit]
    let runs: [CRun]
    let panel: ElecPanel?
    let method: String
    func cableOf(_ c: Circuit) -> Double { runs.filter { $0.circuit.no == c.no }.reduce(0.0) { $0 + $1.len } + Double(TAIL) }
    func inRoom(_ rid: String) -> [CRun] { runs.filter { $0.roomId == rid } }
}

private func eDist(_ a: V2, _ b: V2) -> Double { hypot(a.x - b.x, a.y - b.y) }

/// The door of the panel's room a room's cable leaves by: the one set, else that room's last door other than the entrance.
func exitDoor(_ pc: ECtx, _ pn: ElecPanel, _ er: ElecRoom) -> Opening? {
    let ds = pc.doors
    if let d = ds.first(where: { $0.id == er.pdoor }) { return d }
    return ds.filter { $0.id != pn.entry }.last ?? ds.last
}

/// The order's routes with its panel and cable method.
func routesOf(_ p: Project, _ cs: [ECtx], _ circuits0: [Circuit]? = nil) -> Routes {
    let circuits = circuits0 ?? circuitsOf(p, cs)
    let pn: ElecPanel? = p.elec.panel.flatMap { x in cs.contains { $0.id == x.roomId } ? x : nil }
    let method = p.elec.method
    var byId: [String: ECtx] = [:]
    for c in cs { byId[c.id] = c }
    var runs: [CRun] = []
    for cc in circuits {
        let inPanel = pn?.roomId
        let away = cc.rooms.filter { $0 != inPanel }
        // the panel's room: its own devices, and the doors the other rooms' cables leave by
        var rooms = cc.rooms
        if let pn, !away.isEmpty, !cc.rooms.contains(pn.roomId) { rooms.append(pn.roomId) }
        for rid in rooms {
            guard let c = byId[rid] else { continue }
            let k = runs.filter { $0.roomId == rid }.count
            var exits: [Opening] = []
            if let pn, rid == pn.roomId {
                var seen = Set<String>()
                for a in away {
                    guard let ac = byId[a], let o = exitDoor(c, pn, ac.er) else { continue }
                    if seen.insert(o.id).inserted { exits.append(o) }
                }
            }
            // a room typed by size is away from the panel even when no panel is placed yet
            var link = 0.0
            if let pn, rid != pn.roomId { link = Double(c.free?.link ?? c.er.link) }
            else if pn == nil, let f = c.free { link = Double(f.link) }
            let mine = cc.devs.filter { $0.roomId == rid }
            let here: ElecPanel? = (pn != nil && rid == pn!.roomId) ? pn : nil
            runs.append(roomRun(c, cc, mine, here, exits, method, k, link))
        }
    }
    return Routes(circuits: circuits, runs: runs, panel: pn, method: method)
}

/// Circuit cc's route in room c to its devices ds: from the panel pn when it is in this room (and on to the doors exits
/// other rooms' cables leave by), else from the room's door, plus link for the cable between the doors. k stacks it
/// beside the circuits already drawn in the room.
func roomRun(_ c: ECtx, _ cc: Circuit, _ ds: [ElecDev], _ pn: ElecPanel?, _ exits: [Opening], _ method: String, _ k: Int, _ link: Double) -> CRun {
    let H = c.g.H
    let per = Perim(c)
    var segs: [ERunSeg] = []
    var dropKeys: [String] = []
    var dropVal: [String: Double] = [:]
    func setDrop(_ id: String, _ v: Double) {
        if dropVal[id] == nil { dropKeys.append(id) }
        dropVal[id] = v
    }
    let walls = ds.filter { !$0.onCeiling }
    let lights = ds.filter { $0.onCeiling }
    let kd = Double(k)
    // where it starts: the panel's top, or the door it came in by (over the door)
    let (_, ph) = panelSize(0)
    var startWall: TWall?
    var startA = 0.0
    var rise = 0.0
    if let pn {
        startWall = c.wall(pn.wall); startA = Double(pn.off)
    } else {
        let e = c.entry
        startWall = e.flatMap { c.wall($0.wall) } ?? c.g.walls[0]
        if let e { startA = Double(e.off) + Double(e.w) / 2 }
    }
    let sw = startWall ?? c.g.walls[0]
    let panelTop: Double = pn.map { Double($0.h) + Double(ph) / 2 } ?? 0
    var tails = Double(TAIL) * Double(ds.count)
    func inw(_ w: TWall, _ a: Double) -> V2 { w.at(a, 12) }
    func dropsSum() -> Double { dropKeys.reduce(0.0) { $0 + (dropVal[$1] ?? 0) } }
    func drops() -> [(String, Double)] { dropKeys.map { ($0, dropVal[$0] ?? 0) } }

    if method == "gofra" {
        let z = H - 15 - 15 * kd
        let start = inw(sw, startA)
        if pn != nil {
            rise = H - panelTop
            segs.append(ERunSeg(start, panelTop, start, z, sw.id))
        }
        // over the ceiling from point to point, nearest first; each wall device straight down from above it
        var left: [(V2, ElecDev?)] = []
        for d in walls { if let w = c.wall(d.wall) { left.append((inw(w, Double(d.off)), d)) } }
        for d in lights { left.append((V2(Double(d.cx), Double(d.cy)), d)) }
        for o in exits { if let w = c.wall(o.wall) { left.append((inw(w, Double(o.off) + Double(o.w) / 2), nil)) } }
        var cur = start
        var ceilM = 0.0
        while !left.isEmpty {
            var bi = 0
            var bd = eDist(cur, left[0].0)
            for i in 0..<left.count {
                let dd = eDist(cur, left[i].0)
                if dd < bd { bd = dd; bi = i }
            }
            let n = left.remove(at: bi)
            ceilM += eDist(cur, n.0)
            segs.append(ERunSeg(cur, z, n.0, z, nil))
            cur = n.0
            if let d = n.1, !d.onCeiling {
                let (_, dh) = devSize(d)
                let edge = Double(d.h) + Double(dh) / 2
                setDrop(d.id, max(0, H - edge))
                segs.append(ERunSeg(n.0, z, n.0, edge, d.wall))
            }
        }
        let len = rise + ceilM + dropsSum() + tails + link
        return CRun(circuit: cc, roomId: c.id, segs: segs, len: len, runs: [], drops: drops(), ceil: ceilM, rise: rise)
    }
    // chased or in a channel: up to the run under the ceiling, round the walls, down to each device
    let zone = H - Double(ZONE_DOWN)
    let z = zone - 25 * kd
    if pn != nil {
        rise = abs(zone - panelTop)
        segs.append(ERunSeg(inw(sw, startA), panelTop, inw(sw, startA), z, sw.id))
    }
    let e = per.s(sw.id, startA)
    var ts: [Double] = []
    for d in walls { ts.append(per.s(d.wall ?? "", Double(d.off))) }
    for o in exits { ts.append(per.s(o.wall, Double(o.off) + Double(o.w) / 2)) }
    // the lights: the cable goes up from the wall nearest to them and on over the ceiling from light to light
    var ceilM = 0.0
    if !lights.isEmpty {
        let first = eMinBy(lights) { nearestWall(c, V2(Double($0.cx), Double($0.cy))).2 } ?? lights[0]
        let nw = nearestWall(c, V2(Double(first.cx), Double(first.cy)))
        let lw = nw.0, la = nw.1, ld = nw.2
        ts.append(per.s(lw.id, la))
        let cz = H - 12 - 12 * kd
        let att = inw(lw, la)
        segs.append(ERunSeg(att, z, att, cz, lw.id))
        ceilM += (H - zone) + ld
        var cur = V2(Double(first.cx), Double(first.cy))
        segs.append(ERunSeg(att, cz, cur, cz, nil))
        var left = lights.filter { $0.id != first.id }
        while !left.isEmpty {
            var bi = 0
            var bd = eDist(cur, V2(Double(left[0].cx), Double(left[0].cy)))
            for i in 0..<left.count {
                let dd = eDist(cur, V2(Double(left[i].cx), Double(left[i].cy)))
                if dd < bd { bd = dd; bi = i }
            }
            let n = left.remove(at: bi)
            let q = V2(Double(n.cx), Double(n.cy))
            ceilM += eDist(cur, q)
            segs.append(ERunSeg(cur, cz, q, cz, nil))
            cur = q
        }
    }
    let cv = eCover(per.P, e, ts)
    let cw = cv.0, ccw = cv.1
    var runs: [(Double, Double)] = []
    if cw > 0 {
        runs.append((e, e + cw))
        for pc in per.pieces(e, cw) { segs.append(ERunSeg(inw(pc.0, pc.1), z, inw(pc.0, pc.2), z, pc.0.id)) }
    }
    if ccw > 0 {
        runs.append((e - ccw, e))
        for pc in per.pieces(e - ccw, ccw) { segs.append(ERunSeg(inw(pc.0, pc.1), z, inw(pc.0, pc.2), z, pc.0.id)) }
    }
    for d in walls {
        guard let w = c.wall(d.wall) else { continue }
        let (_, dh) = devSize(d)
        // a device under the run is reached from above, one over it (an LED strip at the ceiling) from below
        let top = Double(d.h) + Double(dh) / 2
        let edge = top <= zone ? top : Double(d.h) - Double(dh) / 2
        setDrop(d.id, abs(zone - edge))
        let at = inw(w, Double(d.off))
        segs.append(ERunSeg(at, z, at, edge, w.id))
    }
    if ds.isEmpty && exits.isEmpty { tails = 0 }
    let len = rise + cw + ccw + dropsSum() + ceilM + tails + link
    return CRun(circuit: cc, roomId: c.id, segs: segs, len: len, runs: runs, drops: drops(), ceil: ceilM, rise: rise)
}
