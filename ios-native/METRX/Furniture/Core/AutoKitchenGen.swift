import Foundation

/*
 * "Oshxona yasash" (Joylan ideas, approved 26 Oct 2026; the mockup's gen / tryPlan / place / fitW and checks; Android
 * furniture/AutoKitchen.kt): a kitchen built for a measured room from the walls picked, the layout and the appliances,
 * once for each of the six design presets. Plain Swift, unit-tested (AutoKitchenGenTests).
 *
 * The rules, as the mockup has them:
 *  - the fridge (with a tall oven or a pantry) stands at a wall end, never under a window;
 *  - the sink goes nearest the water point, the hob nearest the gas pipe, 300 mm clear of wall ends, tall units and
 *    windows, and 0.9–2.2 m from the sink; the dishwasher beside the sink;
 *  - the gaps are filled with 600 units and one odd size (or a filler under 150);
 *  - wall units stay off the windows and the tall units, the hood goes over the hob;
 *  - several arrangements are tried (each free end for the fridge, with and without a pantry) and the one with the
 *    fewest errors and warnings is kept. The checks only warn, they never stop the choice.
 * The corners follow the app's kitchens (Kitchen.swift autoFill, door collisions of 22 Oct 2026): the run that turns
 * ends with a 50 mm filler and a blind corner unit 600 wide; the next run starts at 600 with a 50 mm filler (wall units
 * at 320). The plan is in millimetres, x right, y down; a wall runs from its start corner (clockwise) and its normal
 * points into the room.
 */

/// A point on the plan, mm.
struct AKPt: Equatable {
    let x: Double, y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

func akDist(_ a: AKPt, _ b: AKPt) -> Double { hypot(a.x - b.x, a.y - b.y) }

/// A wall as the generator sees it: its id, length, start point and direction on the plan; the normal into the room
/// is the direction turned a quarter clockwise on the plan (y down).
struct AKWall: Equatable {
    let id: String
    let L: Double
    let px: Double, py: Double
    let ux: Double, uy: Double
    var nx: Double { -uy }
    var ny: Double { ux }
    /// The point t along the wall and d into the room.
    func at(_ t: Double, _ d: Double = 0) -> AKPt { AKPt(px + ux * t + nx * d, py + uy * t + ny * d) }
}

/// A window or a door: a…b along its wall, sill…top from the floor.
struct AKOpen: Equatable { let wall: String; let a: Double; let b: Double; let sill: Double; let top: Double }

/// A water or gas point: t along its wall.
struct AKSpot: Equatable { let wall: String; let t: Double }

/// The room: its walls clockwise, windows, doors, the water and the gas.
struct AKRoom: Equatable {
    var walls: [AKWall]
    var windows: [AKOpen] = []
    var doors: [AKOpen] = []
    var water: AKSpot? = nil
    var gas: AKSpot? = nil

    func wall(_ id: String) -> AKWall? { walls.first { $0.id == id } }
    func next(_ id: String) -> String {
        guard let i = walls.firstIndex(where: { $0.id == id }), !walls.isEmpty else { return id }
        return walls[(i + 1) % walls.count].id
    }
    func prev(_ id: String) -> String {
        guard let i = walls.firstIndex(where: { $0.id == id }), !walls.isEmpty else { return id }
        return walls[(i + walls.count - 1) % walls.count].id
    }
    /// A wall with a door takes no kitchen.
    func blocked(_ id: String) -> Bool { doors.contains { $0.wall == id } }
    func at(_ w: String, _ t: Double, _ d: Double = 0) -> AKPt { wall(w)?.at(t, d) ?? AKPt(0, 0) }
    func spot(_ s: AKSpot?) -> AKPt? { s.map { at($0.wall, $0.t) } }
    func windowsOn(_ w: String) -> [AKOpen] { windows.filter { $0.wall == w } }
}

/// The appliances: fridge "fs" free-standing or "bi" built in; oven "hob" under the hob or "tall" in a tall unit;
/// a dishwasher; the hood "built" in a wall unit or "angled" on the wall.
struct AKApp: Equatable, Hashable {
    var fridge = "fs"
    var oven = "hob"
    var dw = true
    var hood = "built"
}

/// The layouts, in the chips' order: one wall, a corner (L), three walls (U), two rows on facing walls.
let AK_LAYOUTS = ["line", "L", "U", "two"]

/// A preset's own choices (the mockup's PRESETS plan): a pantry this wide by the fridge, drawers in every unit from
/// 400, the wall units' mix ("mix" a vitrina and an open shelf, "flap", "glass2" two vitrinas, "shelf" two open
/// shelves), units up to the ceiling.
struct AKOpts: Equatable {
    var pantry = 0
    var drawers = false
    var up = ""
    var ceiling = false
}

func akOpts(_ preset: String) -> AKOpts {
    switch preset {
    case "twotone": return AKOpts(up: "mix")
    case "gloss": return AKOpts(up: "flap")
    case "gola": return AKOpts(pantry: 450, drawers: true)
    case "neo": return AKOpts(up: "glass2")
    case "wood": return AKOpts(up: "shelf")
    case "dark": return AKOpts(pantry: 600, ceiling: true)
    default: return AKOpts()
    }
}

/// One thing on a run, a…b along its wall: k sink, hob, hobOven (the oven under it), dw, fridgeFS, fridgeBI, ovenT,
/// pantry, doors, drawers, bottle, filler; cfill and blind the corner's filler and blind unit; upper: doors, glass,
/// shelf, flap, hood, blindUp, cfillUp.
struct AKItem: Equatable {
    var k: String
    var a: Double
    var b: Double
    var tall = false
}

/// A run along one wall: cs it starts past a corner, ce it turns a corner at its end; lo…hi where its units may go.
struct AKRun: Equatable {
    let w: String
    let L: Double
    let cs: Bool, ce: Bool
    let lo: Double, hi: Double
    var items: [AKItem] = []
    var base: [AKItem] = []
    var ups: [AKItem] = []
    var angled = false
}

/// A finding: st ok, warn or err; key its text (ak.ck.*); its numbers.
struct AKCheck: Equatable {
    let st: String
    let key: String
    var vars: [String: AKVal] = [:]
}

/// A check's value: metres (shown with one decimal), whole mm, a word (a strings key) or text as it is.
enum AKVal: Equatable {
    case m(Double)
    case mm(Int)
    case word(String)
    case raw(String)
}

/// Where something went: run ri, a…b.
struct AKPick: Equatable { let ri: Int; let a: Double; let b: Double; let cost: Double }

/// A built kitchen: its runs (path order), checks and counts, the score it won with, where the sink and the hob went.
struct AKPlan: Equatable {
    let layout: String
    let app: AKApp
    var runs: [AKRun]
    var checks: [AKCheck]
    var err: Int
    var warn: Int
    var score: Double
    var relax: Int
    var withP: Bool
    /// The preset wanted a pantry that did not fit.
    var noP: Bool
    var tried = 0
    var sink: AKPick
    var hob: AKPick
    var dSH: Double
}

/* ---------------- small helpers (the mockup's) ---------------- */

/// JavaScript's Math.round.
private func akRound(_ x: Double) -> Double { (x + 0.5).rounded(.down) }

private let AK_STD: Set<Int> = [150, 200, 300, 400, 450, 500, 600, 800, 900]
private let AK_TALL: Set<String> = ["fridgeBI", "fridgeFS", "ovenT", "pantry"]

/// A gap on a run: a…b; hl, hr its ends are hard (a wall end or a tall unit), where the hob keeps 300 mm.
struct AKGap: Equatable { let a: Double; let b: Double; let hl: Bool; let hr: Bool }

func akRun(_ R: AKRoom, _ w: String, _ cs: Bool, _ ce: Bool) -> AKRun {
    let L = R.wall(w)?.L ?? 0
    let lo = cs ? Double(K_CORNER + CORNER_FILLER) : 0
    let hi = ce ? L - Double(K_CORNER + CORNER_FILLER) : L
    return AKRun(w: w, L: L, cs: cs, ce: ce, lo: lo, hi: hi)
}

/// The runs of walls for layout: two rows stand alone; the others follow the room round from the wall whose previous
/// one is not picked.
func akPathRuns(_ R: AKRoom, _ walls: [String], _ layout: String) -> [AKRun] {
    if layout == "two" { return walls.map { akRun(R, $0, false, false) } }
    guard var s = walls.first else { return [] }
    let set = Set(walls)
    for w in walls where !set.contains(R.prev(w)) { s = w; break }
    var path = [s]
    while path.count < walls.count {
        let n = R.next(path[path.count - 1])
        if !set.contains(n) || path.contains(n) { break }
        path.append(n)
    }
    var out: [AKRun] = []
    for (i, w) in path.enumerated() { out.append(akRun(R, w, i > 0, i < path.count - 1)) }
    return out
}

func akFreeGaps(_ r: AKRun) -> [AKGap] {
    let it = r.items.sorted { $0.a < $1.a }
    var g: [AKGap] = []
    var cur = r.lo, hl = !r.cs
    for x in it {
        if x.a > cur + 0.5 { g.append(AKGap(a: cur, b: x.a, hl: hl, hr: x.tall)) }
        if x.b > cur { cur = x.b; hl = x.tall }
    }
    if r.hi > cur + 0.5 { g.append(AKGap(a: cur, b: r.hi, hl: hl, hr: !r.ce)) }
    return g
}

/// a…b less the zones.
func akSubtract(_ a: Double, _ b: Double, _ zs: [(Double, Double)]) -> [(Double, Double)] {
    var out: [(Double, Double)] = [(a, b)]
    for (za, zb) in zs {
        var n: [(Double, Double)] = []
        for (x, y) in out {
            if zb <= x || za >= y { n.append((x, y)); continue }
            if za > x { n.append((x, za)) }
            if zb < y { n.append((zb, y)) }
        }
        out = n
    }
    return out
}

/// A leftover no unit fits (101–149 or 201–299 mm): 1, else 0.
func akBadGap(_ x: Double) -> Double { (x > 100 && x < 150) || (x > 200 && x < 300) ? 1 : 0 }

/// What place may and may not do: keep margin from a hard end, stay out of the zones, add the extra cost.
struct AKPlaceOpt {
    var margin: Double = 0
    var zones: ((AKRun, Int) -> [(Double, Double)])? = nil
    var extra: ((AKRun, Int, Double) -> Double)? = nil
}

/// An item w wide as near target as it can go, inside the free gaps, leaving usable leftovers.
func akPlace(_ R: AKRoom, _ runs: [AKRun], _ w: Double, _ target: AKPt, _ opt: AKPlaceOpt = AKPlaceOpt()) -> AKPick? {
    var best: AKPick? = nil
    for (ri, r) in runs.enumerated() {
        guard let W = R.wall(r.w) else { continue }
        let proj = (target.x - W.px) * W.ux + (target.y - W.py) * W.uy
        let zs = opt.zones?(r, ri) ?? []
        for g in akFreeGaps(r) {
            let a0 = g.a + (g.hl ? opt.margin : 0), b0 = g.b - (g.hr ? opt.margin : 0)
            for (sa, sb) in akSubtract(a0, b0, zs) {
                if sb - sa < w - 0.5 { continue }
                let c0 = min(max(proj, sa + w / 2), sb - w / 2)
                let l = c0 - w / 2 - g.a, rr = g.b - c0 - w / 2
                var cands = [c0, sa + w / 2, sb - w / 2]
                if l > 0 { cands += [c0 - l, c0 + 300 - l, c0 + 150 - l, c0 + 200 - l] }
                if rr > 0 { cands += [c0 + rr, c0 - (300 - rr), c0 - (150 - rr), c0 - (200 - rr)] }
                for c1 in cands {
                    let c = akRound((c1 - w / 2) / 10) * 10 + w / 2
                    if c - w / 2 < sa - 0.5 || c + w / 2 > sb + 0.5 { continue }
                    let left = c - w / 2 - g.a, right = g.b - c - w / 2
                    var cost = akDist(W.at(c), target) + (akBadGap(left) + akBadGap(right)) * 5000
                    if let ex = opt.extra { cost += ex(r, ri, c) }
                    if best == nil || cost < best!.cost { best = AKPick(ri: ri, a: c - w / 2, b: c + w / 2, cost: cost) }
                }
            }
        }
    }
    return best
}

/// A length as units: 600s while more than 900 is left, then the rest; under 150 a filler (negative).
func akFitW(_ len0: Double) -> [Int] {
    let len = Int(akRound(len0))
    if len <= 0 { return [] }
    if len < 150 { return [-len] }
    var out: [Int] = []
    var rem = len
    while rem > 900 { out.append(600); rem -= 600 }
    out.append(rem)
    return out
}

/* ---------------- the generator ---------------- */

/// The kitchen for walls (picked, any order), layout and app, with preset's choices: the best of the arrangements
/// tried; nil when even the fridge does not fit.
func akGenerate(_ R: AKRoom, walls: [String], layout: String, app: AKApp, preset: String) -> AKPlan? {
    let pp = akOpts(preset)
    let r0 = akPathRuns(R, walls, layout)
    var ends: [(Int, Int)] = []
    for (i, r) in r0.enumerated() {
        if !r.cs { ends.append((i, 0)) }
        if !r.ce { ends.append((i, 1)) }
    }
    var best: AKPlan? = nil
    var tried = 0
    let withs: [Bool] = pp.pantry > 0 ? [true, false] : [false]
    for e in ends {
        for wp in withs {
            tried += 1
            guard let p = akTry(R, walls, layout, app, pp, e, wp, false) else { continue }
            if best == nil || p.score < best!.score { best = p }
        }
    }
    if best == nil, let e = ends.first { best = akTry(R, walls, layout, app, pp, e, false, true) }
    best?.tried = tried
    return best
}

/// One arrangement: the fridge's block at end e (run, 0 its start or 1 its end), with the pantry or not; noWin lets
/// the tall units stand under a window (the last resort).
func akTry(_ R: AKRoom, _ walls: [String], _ layout: String, _ app: AKApp, _ pp: AKOpts, _ e: (Int, Int), _ withP: Bool, _ noWin: Bool) -> AKPlan? {
    var runs = akPathRuns(R, walls, layout)
    guard e.0 < runs.count else { return nil }
    var relax = 0
    // 1. the fridge (and a tall oven, a pantry) at a wall end, never under a window
    var tl: [(String, Double)] = [(app.fridge == "bi" ? "fridgeBI" : "fridgeFS", 600)]
    if app.oven == "tall" { tl.append(("ovenT", 600)) }
    if withP { tl.append(("pantry", Double(pp.pantry))) }
    let fi = e.0, side = e.1
    let tw = tl.reduce(0) { $0 + $1.1 }
    if tw > runs[fi].hi - runs[fi].lo - 300 { return nil }
    var t = side == 0 ? runs[fi].lo : runs[fi].hi
    for it in tl {
        let a = side == 0 ? t : t - it.1, b = a + it.1
        if !noWin && R.windowsOn(runs[fi].w).contains(where: { a < $0.b && b > $0.a }) { return nil }
        runs[fi].items.append(AKItem(k: it.0, a: a, b: b, tall: true))
        t = side == 0 ? b : a
    }
    let blkA = runs[fi].items.map(\.a).min() ?? 0, blkB = runs[fi].items.map(\.b).max() ?? 0
    let land: (AKRun, Int) -> [(Double, Double)] = { _, ri in ri == fi ? [(blkA - 400, blkB + 400)] : [] }
    // 2. the sink at the water point; without one, by a window of the kitchen, else in the middle of the first run
    var water = R.spot(R.water)
    if water == nil {
        if let o = R.windows.first(where: { o in runs.contains { $0.w == o.wall } }) { water = R.at(o.wall, (o.a + o.b) / 2) }
        else { water = R.at(runs[0].w, (runs[0].lo + runs[0].hi) / 2) }
    }
    let wt = water ?? AKPt(0, 0)
    var sPick = akPlace(R, runs, 800, wt, AKPlaceOpt(zones: land))
    if sPick == nil { relax += 1; sPick = akPlace(R, runs, 800, wt) }
    if sPick == nil { relax += 1; sPick = akPlace(R, runs, 600, wt) }
    guard let s = sPick else { return nil }
    runs[s.ri].items.append(AKItem(k: "sink", a: s.a, b: s.b))
    let sw = runs[s.ri].w
    let sc = (s.a + s.b) / 2, sP = R.at(sw, sc, 300)
    // 3. the hob at the gas pipe (none: by the sink): 300 mm from wall ends, tall units and windows, 0.9–2.2 m from the sink
    let gasP = R.spot(R.gas)
    let gas = gasP ?? R.at(sw, sc)
    let winZ: (AKRun) -> [(Double, Double)] = { rr in R.windowsOn(rr.w).map { ($0.a - 300, $0.b + 300) } }
    let extra: (AKRun, Int, Double) -> Double = { rr, _, c in
        let d = akDist(R.at(rr.w, c, 300), sP)
        return d < 900 ? 4000 : d > 2200 ? (d - 2200) * 3 : 0
    }
    let sri = s.ri
    let zones1: (AKRun, Int) -> [(Double, Double)] = { rr, ri in
        var z = winZ(rr)
        if ri == sri { z.append((sc - 600, sc + 600)) }
        return z + land(rr, ri)
    }
    var hPick = akPlace(R, runs, 600, gas, AKPlaceOpt(margin: 300, zones: zones1, extra: extra))
    if hPick == nil { relax += 1; hPick = akPlace(R, runs, 600, gas, AKPlaceOpt(margin: 300, zones: { rr, _ in winZ(rr) }, extra: extra)) }
    if hPick == nil { relax += 2; hPick = akPlace(R, runs, 600, gas, AKPlaceOpt(extra: extra)) }
    guard let h = hPick else { return nil }
    let hobK = app.oven == "hob" ? "hobOven" : "hob"
    runs[h.ri].items.append(AKItem(k: hobK, a: h.a, b: h.b))
    let hw = runs[h.ri].w
    let hc = (h.a + h.b) / 2, hP = R.at(hw, hc, 300)
    // 4. the dishwasher beside the sink
    var dwPlaced = false, dwNext = false
    if app.dw {
        var bd: (Double, Double, Double)? = nil
        for w in [600.0, 450.0] {
            for sd in [1.0, -1.0] {
                let a = sd > 0 ? s.b : s.a - w, b = a + w
                guard let g = akFreeGaps(runs[s.ri]).first(where: { a >= $0.a - 0.5 && b <= $0.b + 0.5 }) else { continue }
                var cost = (akBadGap(a - g.a) + akBadGap(g.b - b)) * 5000 + (w == 600 ? 0 : 30)
                let toHob: Double = hc > sc ? 1 : hc < sc ? -1 : 0
                if h.ri == s.ri && toHob == sd { cost += 40 }
                if bd == nil || cost < bd!.2 { bd = (a, b, cost) }
            }
        }
        if let bd, bd.2 < 5000 {
            runs[s.ri].items.append(AKItem(k: "dw", a: bd.0, b: bd.1)); dwPlaced = true; dwNext = true
        } else {
            let near = R.at(sw, sc)
            let d6 = akPlace(R, runs, 600, near), d4 = akPlace(R, runs, 450, near)
            var d: AKPick? = d4
            if let d6, d4 == nil || d6.cost <= d4!.cost + 30 { d = d6 }
            if let d { runs[d.ri].items.append(AKItem(k: "dw", a: d.a, b: d.b)); dwPlaced = true }
        }
    }
    // 5. the corners, and the gaps filled with units fitted to the wall
    for i in runs.indices { runs[i].base = akBaseRow(runs[i], hobK, pp) }
    // 6. wall units: not over a window or a tall unit; the hood over the hob
    for i in runs.indices { akUpperRow(R, &runs[i], i == h.ri ? h : nil, app) }
    akMixUppers(R, &runs, R.at(hw, hc), pp)
    // 7. the checks (warnings only)
    var checks: [AKCheck] = []
    var err = 0, warn = 0
    func add(_ st: String, _ key: String, _ vars: [String: AKVal] = [:]) {
        checks.append(AKCheck(st: st, key: key, vars: vars))
        if st == "warn" { warn += 1 }
        if st == "err" { err += 1 }
    }
    let dSH = akDist(sP, hP)
    add(dSH >= 900 && dSH <= 2200 ? "ok" : "warn", dSH < 900 ? "ak.ck.shNear" : dSH > 2200 ? "ak.ck.shFar" : "ak.ck.sh", ["v": .m(dSH)])
    akHobCheck(R, runs[h.ri], h, add)
    akFridgeCheck(runs[fi], side, hobK, add)
    var dW = 0.0
    if let wp = R.spot(R.water) {
        dW = akDist(R.at(sw, sc), wp)
        add(dW <= 1000 ? "ok" : "warn", dW < 150 ? "ak.ck.wOn" : dW <= 1000 ? "ak.ck.wNear" : "ak.ck.wFar", ["v": .m(dW)])
    } else {
        add("warn", "ak.ck.noWater")
    }
    var dG = 0.0
    if let gp = gasP {
        dG = akDist(R.at(hw, hc), gp)
        if dG <= 1500 { add("ok", "ak.ck.gOk", ["v": .m(dG)]) }
        else if dG <= 2000 { add("warn", "ak.ck.gHose", ["v": .m(dG)]) }
        else { add("err", "ak.ck.gFar", ["v": .m(dG)]) }
    } else {
        add("warn", "ak.ck.noGas")
    }
    akFitCheck(runs, add)
    // the tall units under a window: only the last resort, when no wall end was clear of it
    let frWin = runs.contains { r in r.items.contains { x in x.tall && R.windowsOn(r.w).contains { x.a < $0.b && x.b > $0.a } } }
    add(frWin ? "warn" : "ok", frWin ? "ak.ck.frWin" : "ak.ck.frEnd")
    if app.dw {
        if !dwPlaced { add("warn", "ak.ck.dwNone") } else if !dwNext { add("warn", "ak.ck.dwFar") } else { add("ok", "ak.ck.dwOk") }
    }
    // 8. the score: errors, warnings, what had to give, the pipes' lengths, the fridge near the door
    var fD = 0.0
    if let door = R.doors.first, let f = runs[fi].items.first(where: { $0.k.hasPrefix("fridge") }) {
        fD = akDist(R.at(runs[fi].w, (f.a + f.b) / 2), R.at(door.wall, (door.a + door.b) / 2))
    }
    let noP = pp.pantry > 0 && !withP
    var score = Double(err * 1000 + warn * 100 + relax * 40) + (noP ? 150 : 0)
    score += dG / 50 + dW / 50 + fD / 400
    return AKPlan(layout: layout, app: app, runs: runs, checks: checks, err: err, warn: warn, score: score, relax: relax, withP: withP, noP: noP,
                  sink: s, hob: h, dSH: dSH)
}

/// A run's lower row: its items, the corner pieces, and every gap filled (600s and one odd size, a filler under 150;
/// the odd size towards a hard end; drawers by the hob and the tall units, and everywhere from 400 when the preset wants).
func akBaseRow(_ r: AKRun, _ hobK: String, _ pp: AKOpts) -> [AKItem] {
    var base = r.items
    let L = r.L, c = Double(K_CORNER), cf = Double(CORNER_FILLER)
    if r.ce { base.append(AKItem(k: "cfill", a: L - c - cf, b: L - c)); base.append(AKItem(k: "blind", a: L - c, b: L)) }
    if r.cs { base.append(AKItem(k: "cfill", a: c, b: c + cf)) }
    let hb = r.items.first { $0.k == hobK }
    for g in akFreeGaps(r) {
        var ws = akFitW(g.b - g.a)
        let hobL = hb.map { abs($0.b - g.a) < 1 } ?? false
        let hobR = hb.map { abs($0.a - g.b) < 1 } ?? false
        let tallAtLeft = r.items.contains { $0.tall && abs($0.b - g.a) < 1 }
        if hobR || (!hobL && g.hl && !g.hr && !tallAtLeft) { ws.reverse() }
        var x = g.a
        for w in ws {
            if w < 0 { base.append(AKItem(k: "filler", a: x, b: x - Double(w))); x -= Double(w); continue }
            let a = x, b = x + Double(w)
            let tH = hb.map { abs($0.b - a) < 1 || abs($0.a - b) < 1 } ?? false
            let tT = r.items.contains { $0.tall && (abs($0.b - a) < 1 || abs($0.a - b) < 1) }
            let k: String
            if w <= 200 { k = "bottle" }
            else if tH || (pp.drawers && w >= 400) || (tT && w >= 400 && w <= 600) { k = "drawers" }
            else { k = "doors" }
            base.append(AKItem(k: k, a: a, b: b))
            x = b
        }
    }
    return base.sorted { $0.a < $1.a }
}

/// A run's wall units: none over the tall units or within 50 mm of a window; the hood over the hob (unless the hob is
/// under a window, or the hood is an angled one on the wall); the corner pieces; the rest in units of 250 or more.
func akUpperRow(_ R: AKRoom, _ r: inout AKRun, _ hob: AKPick?, _ app: AKApp) {
    var ups: [AKItem] = []
    var bl: [(Double, Double)] = []
    for x in r.items where x.tall { bl.append((x.a, x.b)) }
    for o in R.windowsOn(r.w) { bl.append((o.a - 50, o.b + 50)) }
    r.angled = false
    if let h = hob {
        let uw = R.windowsOn(r.w).contains { h.a < $0.b + 50 && h.b > $0.a - 50 }
        if !uw {
            if app.hood == "built" { ups.append(AKItem(k: "hood", a: h.a, b: h.b)) } else { r.angled = true }
            bl.append((h.a, h.b))
        }
    }
    let L = r.L, c = Double(K_CORNER), uc = Double(K_UP_CORNER), cf = Double(CORNER_FILLER)
    if r.ce { ups.append(AKItem(k: "blindUp", a: L - c, b: L)); bl.append((L - c, L)) }
    if r.cs { ups.append(AKItem(k: "cfillUp", a: uc, b: uc + cf)); bl.append((0, uc + cf)) }
    for (a, b) in akSubtract(0, L, bl) {
        if b - a < 250 { continue }
        var x = a
        for w in akFitW(b - a) where w > 0 { ups.append(AKItem(k: "doors", a: x, b: x + Double(w))); x += Double(w) }
    }
    r.ups = ups.sorted { $0.a < $1.a }
}

/// The preset's wall units: furthest from the hob first, a vitrina and an open shelf ("mix"), all lift-up ("flap"),
/// two vitrinas ("glass2"), two open shelves ("shelf").
func akMixUppers(_ R: AKRoom, _ runs: inout [AKRun], _ hobW: AKPt, _ pp: AKOpts) {
    var pool: [(Int, Int, Double, Double)] = []   // run, unit, distance, width
    for (ri, r) in runs.enumerated() {
        for (ui, u) in r.ups.enumerated() where u.k == "doors" { pool.append((ri, ui, akDist(R.at(r.w, (u.a + u.b) / 2), hobW), u.b - u.a)) }
    }
    // the stable sort of the mockup: furthest first, ties in order
    pool = pool.enumerated().sorted { x, y in x.element.2 != y.element.2 ? x.element.2 > y.element.2 : x.offset < y.offset }.map(\.element)
    func set(_ e: (Int, Int, Double, Double), _ k: String) { runs[e.0].ups[e.1].k = k }
    switch pp.up {
    case "flap":
        for e in pool { set(e, "flap") }
    case "mix":
        if let g = pool.first(where: { $0.3 >= 500 }) { set(g, "glass") }
        if let s = pool.first(where: { runs[$0.0].ups[$0.1].k == "doors" && $0.3 <= 450 }) { set(s, "shelf") }
    case "glass2":
        for e in pool.filter({ $0.3 >= 400 }).prefix(2) { set(e, "glass") }
    case "shelf":
        for e in pool.filter({ $0.3 <= 800 }).prefix(2) { set(e, "shelf") }
    default: break
    }
}

/// The hob's room: 300 mm from the nearest wall end, tall unit or window; under a window is an error.
private func akHobCheck(_ R: AKRoom, _ hr: AKRun, _ h: AKPick, _ add: (String, String, [String: AKVal]) -> Void) {
    var obs: [(Double, String)] = []
    if !hr.cs { obs.append((0, "ak.o.wall")) }
    if !hr.ce { obs.append((hr.L, "ak.o.wall")) }
    for x in hr.items where x.tall {
        let n = x.k.hasPrefix("fridge") ? "ak.o.fridge" : "ak.o.tall"
        obs.append((x.a, n)); obs.append((x.b, n))
    }
    var underWin = false
    for o in R.windowsOn(hr.w) {
        if h.a < o.b && h.b > o.a { underWin = true }
        obs.append((o.a, "ak.o.win")); obs.append((o.b, "ak.o.win"))
    }
    var cl: (Double, String) = (1e9, "")
    for (x, n) in obs {
        let d = x <= h.a + 0.5 ? h.a - x : x >= h.b - 0.5 ? x - h.b : -1
        if d >= 0 && d < cl.0 { cl = (akRound(d), n) }
    }
    if underWin { add("err", "ak.ck.hobWin", [:]) }
    else if cl.0 >= 300 {
        if cl.0 < 1e8 { add("ok", "ak.ck.hobClear", ["v": .mm(Int(cl.0)), "o": .word(cl.1)]) } else { add("ok", "ak.ck.hobFree", [:]) }
    } else {
        add("warn", "ak.ck.hobTight", ["v": .mm(Int(cl.0)), "o": .word(cl.1)])
    }
}

/// Worktop beside the fridge: 400 mm or more, not a tall unit, the sink or the hob.
private func akFridgeCheck(_ fr: AKRun, _ side: Int, _ hobK: String, _ add: (String, String, [String: AKVal]) -> Void) {
    guard let f = fr.items.first(where: { $0.k.hasPrefix("fridge") }) else { return }
    let inner = side == 0 ? f.b : f.a
    let seq = side == 0 ? fr.base : Array(fr.base.reversed())
    var nb: AKItem? = nil
    for e in seq {
        let touch = side == 0 ? e.a >= inner - 1 : e.b <= inner + 1
        if !touch || (e.a == f.a && e.b == f.b) { continue }
        if e.k == "filler" || e.k == "cfill" { continue }
        nb = e; break
    }
    guard let n = nb else { add("warn", "ak.ck.frNone", [:]); return }
    if AK_TALL.contains(n.k) { add("warn", "ak.ck.frTall", ["o": .word(n.k == "ovenT" ? "ak.o.oven" : "ak.o.tall")]); return }
    if n.k == "sink" || n.k == hobK { add("warn", "ak.ck.frNext", ["o": .word(n.k == "sink" ? "ak.o.sink" : "ak.o.hob")]); return }
    let w = n.k == "blind" ? 600 : Int(akRound(n.b - n.a))
    if w >= 400 { add("ok", "ak.ck.frOk", ["v": .mm(w)]) } else { add("warn", "ak.ck.frShort", ["v": .mm(w)]) }
}

/// The units fitted to the walls: the sizes that are not the usual ones, and the fillers.
private func akFitCheck(_ runs: [AKRun], _ add: (String, String, [String: AKVal]) -> Void) {
    let skip: Set<String> = ["cfill", "blind", "blindUp", "cfillUp"]
    var ns: [Int] = [], fl: [Int] = []
    for r in runs {
        for e in r.base where !skip.contains(e.k) {
            let w = Int(akRound(e.b - e.a))
            if e.k == "filler" { fl.append(w) } else if !AK_STD.contains(w) && !ns.contains(w) { ns.append(w) }
        }
        for u in r.ups where !skip.contains(u.k) {
            let w = Int(akRound(u.b - u.a))
            if !AK_STD.contains(w) && !ns.contains(w) { ns.append(w) }
        }
    }
    let n = ns.sorted(by: >).map(String.init).joined(separator: ", "), f = fl.map(String.init).joined(separator: ", ")
    let key = ns.isEmpty ? (fl.isEmpty ? "ak.ck.fitStd" : "ak.ck.fitStdF") : (fl.isEmpty ? "ak.ck.fit" : "ak.ck.fitF")
    add("ok", key, ["n": .raw(n), "f": .raw(f)])
}

/* ---------------- picking walls and layouts (the mockup's tapWall, deriveLayout, wallsFor) ---------------- */

func akAdjacent(_ R: AKRoom, _ a: String, _ b: String) -> Bool { R.next(a) == b || R.next(b) == a }

/// The layout the picked walls make: one a line, three a U, two an L when they meet, else two rows.
func akDeriveLayout(_ R: AKRoom, _ ws: [String]) -> String {
    if ws.count <= 1 { return "line" }
    if ws.count >= 3 { return "U" }
    return akAdjacent(R, ws[0], ws[1]) ? "L" : "two"
}

/// Whether walls ws follow one another round the room (one chain, as a U kitchen needs).
func akChained(_ R: AKRoom, _ ws: [String]) -> Bool {
    let set = Set(ws)
    guard let s = ws.first(where: { !set.contains(R.prev($0)) }) else { return false }
    var path = [s]
    while path.count < ws.count {
        let n = R.next(path[path.count - 1])
        if !set.contains(n) || path.contains(n) { return false }
        path.append(n)
    }
    return true
}

/// Whether wall w can take a kitchen: measured, no door on it.
func akFree(_ R: AKRoom, _ w: String) -> Bool { !R.blocked(w) && (R.wall(w)?.L ?? 0) >= 1200 }

/// The walls for layout, starting from the ones picked (ws); nil when the room has no such walls free.
func akWallsFor(_ R: AKRoom, _ layout: String, _ ws: [String]) -> [String]? {
    let ids = R.walls.map(\.id)
    let order = ws.filter { ids.contains($0) } + ids.filter { !ws.contains($0) }
    for w in order where akFree(R, w) {
        switch layout {
        case "line": return [w]
        case "L":
            if ws.count == 2 && akAdjacent(R, ws[0], ws[1]) && ws.allSatisfy({ akFree(R, $0) }) { return ws }
            if akFree(R, R.next(w)) && R.next(w) != w { return [w, R.next(w)] }
            if akFree(R, R.prev(w)) && R.prev(w) != w { return [R.prev(w), w] }
        case "U":
            let a = R.prev(w), b = R.next(w)
            if Set([a, w, b]).count == 3 && akFree(R, a) && akFree(R, b) { return [a, w, b] }
            let b2 = R.next(b)
            if Set([w, b, b2]).count == 3 && akFree(R, b) && akFree(R, b2) { return [w, b, b2] }
        default:
            // two rows: the wall facing it (halfway round the room)
            guard let i = ids.firstIndex(of: w), ids.count >= 4 else { continue }
            let o = ids[(i + ids.count / 2) % ids.count]
            if akFree(R, o) && !akAdjacent(R, w, o) { return [w, o] }
        }
    }
    return nil
}

/// The walls after tapping w: on or off, three at most (the last three).
func akTapWall(_ ws: [String], _ w: String) -> [String] {
    var out = ws.contains(w) ? ws.filter { $0 != w } : ws + [w]
    if out.count > 3 { out = Array(out.suffix(3)) }
    return out
}

/// The walls a kitchen first starts on: the longest free wall with the water, else the longest free one, and its
/// free neighbour when there is one (an L, as the mockup starts).
func akStartWalls(_ R: AKRoom) -> [String] {
    let free = R.walls.filter { akFree(R, $0.id) }
    guard !free.isEmpty else { return [] }
    let wet = free.filter { $0.id == R.water?.wall }
    let longest = free.max(by: { $0.L < $1.L })
    guard let mainWall = wet.first ?? longest else { return [] }
    let main = mainWall.id
    if akFree(R, R.prev(main)) && R.prev(main) != main { return [R.prev(main), main] }
    if akFree(R, R.next(main)) && R.next(main) != main { return [main, R.next(main)] }
    return [main]
}

/* ---------------- the room and the furniture ---------------- */

/// The generator's room from a measured room: its walls (the drawing's estimate where one is not measured), windows,
/// doors, and the cold water (else the drain or the hot water) and the gas pipe of its site points.
func akRoomOf(_ r: Room, _ snap: Bool) -> AKRoom {
    var walls: [AKWall] = []
    for w in Geo.walls(r, snap) {
        let dx = w.p1.x - w.p0.x, dy = w.p1.y - w.p0.y
        let l = max(1e-6, hypot(dx, dy))
        let len = Double(wallLen(r, snap, w.id) ?? Int(l.rounded()))
        // the walls' points follow the measured lengths along the drawing's directions
        walls.append(AKWall(id: w.id, L: len, px: w.p0.x, py: w.p0.y, ux: dx / l, uy: dy / l))
    }
    // a drawing's corners are not at the measured lengths: each wall starts where the one before ends
    if r.isPoly, walls.count >= 3 {
        var x = walls[0].px, y = walls[0].py
        var fixed: [AKWall] = []
        for w in walls {
            fixed.append(AKWall(id: w.id, L: w.L, px: x, py: y, ux: w.ux, uy: w.uy))
            x += w.ux * w.L; y += w.uy * w.L
        }
        walls = fixed
    }
    var R = AKRoom(walls: walls)
    for o in r.openings {
        let op = AKOpen(wall: o.wall, a: Double(o.off), b: Double(o.off + o.w), sill: Double(o.sill), top: Double(o.sill + o.h))
        if o.type == "window" { R.windows.append(op) } else { R.doors.append(op) }
    }
    let water = r.points.first { $0.t == "cold" } ?? r.points.first { $0.t == "sewer" } ?? r.points.first { $0.t == "hot" }
    R.water = water.map { AKSpot(wall: $0.wall, t: Double($0.off)) }
    R.gas = r.points.first { $0.t == "gas" }.map { AKSpot(wall: $0.wall, t: Double($0.off)) }
    return R
}

/// The app's layout of a plan's runs (two rows are two one-wall kitchens).
func akFLayout(_ layout: String) -> String { layout == "U" ? "U" : layout == "L" ? "L" : "I" }

/// The modules of a lower or upper row from x0 on wall w: each item as a kitchen unit, a gap of space between them.
private func akRow(_ items: [AKItem], _ x0: Int, _ w: String, _ ws: Workshop, upper: Bool) -> [Module] {
    var out: [Module] = []
    var x = x0
    for it in items {
        let a = Int(akRound(it.a)), b = Int(akRound(it.b))
        if a > x { out.append(template(upper ? "spaceUp" : "spaceLow", ws, w, a - x)) }
        if b - a > 0 { out.append(akModule(it.k, b - a, w, ws, upper: upper)) }
        x = max(x, b)
    }
    return out
}

/// One item as a kitchen unit of the library (Kitchen.swift template).
func akModule(_ k: String, _ w: Int, _ wall: String, _ ws: Workshop, upper: Bool = true) -> Module {
    switch k {
    case "sink": return template("sink", ws, wall, w)
    case "hob": return template("hob", ws, wall, w)
    // the oven under the hob: its front an appliance's panel
    case "hobOven": var m = template("hob", ws, wall, w); m.fronts = Fronts("panel", 1); return m
    case "dw": return template("dishwasher", ws, wall, w)
    case "fridgeFS": return template("fridge", ws, wall, w)
    case "fridgeBI": return template("fridgeB", ws, wall, w)
    case "ovenT": return template("oven", ws, wall, w)
    case "pantry": return template("pantry", ws, wall, w)
    case "drawers": return template("drawers", ws, wall, w)
    // a bottle unit: one pull-out
    case "bottle": var m = template("drawers", ws, wall, w); m.fronts = Fronts("drawer", 1); return m
    case "filler", "cfill": return template("fillerLow", ws, wall, w)
    case "blind": var m = template("base", ws, wall, w); m.fronts = Fronts("panel", 1); return m
    case "blindUp": var m = template("wall", ws, wall, w); m.fronts = Fronts("panel", 1); return m
    case "cfillUp": return template("fillerUp", ws, wall, w)
    case "hood": return template("hood", ws, wall, w)
    case "glass": var m = template("vitrina", ws, wall, w); m.accentIn = true; return m
    case "shelf": return template("open", ws, wall, w)
    // "doors" in the lower row is a base unit with doors (it was made a wall unit, which left the lower rows short)
    case "doors": return template(upper ? "wall" : "base", ws, wall, w)
    case "flap": return template("wall", ws, wall, w)
    default: return template("base", ws, wall, w)
    }
}

/// The plan as kitchens for room r (workspace wsId): one kitchen on the runs (two rows: one a row), in preset's look,
/// packed on the room's walls. names gives each new kitchen's name (its number among them, from 0).
func akFurniture(_ plan: AKPlan, _ r: Room, _ preset: String, _ ws: Workshop, snap: Bool, now: Ms = 0, names: (Int) -> String = { _ in "" }) -> [Furniture] {
    let groups: [[AKRun]] = plan.layout == "two" ? plan.runs.map { [$0] } : [plan.runs]
    var out: [Furniture] = []
    for (gi, rs) in groups.enumerated() {
        var mods: [Module] = []
        for (i, run) in rs.enumerated() {
            let past = i > 0
            mods += akRow(run.base, past ? K_CORNER : 0, run.w, ws, upper: false)
            mods += akRow(run.ups, past ? K_UP_CORNER : 0, run.w, ws, upper: true)
        }
        let layout = akFLayout(rs.count == 1 ? "line" : plan.layout)
        var f = Furniture(id: uid(), kind: "kitchen", name: names(gi), roomId: r.id, walls: rs.map(\.w), modules: mods, created: now,
                          layout: layout, ws: r.floorId, kx: kExtrasFor(layout))
        let ff = f
        f = pack(f, runsOf(ff) { id in wallLen(r, snap, id) })
        f = withPreset(f, preset, fresh: true, ws: ws)
        out.append(f)
    }
    return out
}

/// The units a card counts (the mockup's N): base, tall and wall units and the dishwasher; no fillers or spaces.
func akUnits(_ fs: [Furniture]) -> Int {
    fs.reduce(0) { n, f in n + f.modules.filter { ["base", "tall", "wall"].contains($0.type) || $0.app == "dishwasher" }.count }
}

/// The running metres of the kitchens, mm.
func akRunMm(_ fs: [Furniture]) -> Int { fs.reduce(0) { $0 + runMm($1) } }
