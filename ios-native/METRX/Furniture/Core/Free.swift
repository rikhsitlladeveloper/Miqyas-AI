import Foundation

/*
 * Furniture without a room (decided 20 Oct 2026, mockup design/furniture/orders-flow-mockup.html v4; Android
 * furniture/Free.kt; FreeTests). A maker who only has the furniture's sizes picks a ready model, types its sizes and
 * designs it at once; the room can come later ("Xonaga qo‘yish") and the furniture can leave it again
 * ("Xonadan chiqarish").
 *
 * Room-less furniture (Furniture.roomId nil) stands in a made-up room (freeRoom) whose walls are the typed sizes, so
 * the designers, the checks, the price and the documents work on it unchanged. A kitchen's sides are kept in
 * Furniture.free (in the order of its runs); a wardrobe's made-up room follows the wardrobe itself.
 */

/// The sizes a room-less kitchen was given: each run's length in the order of Furniture.walls, the island, the ceiling.
struct FreeSize: Codable, Equatable {
    var sides: [Int] = []
    var island = 0
    var h = 2700
    init(_ sides: [Int] = [], _ island: Int = 0, _ h: Int = 2700) { self.sides = sides; self.island = island; self.h = h }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: CodingKeys.self); sides = c.v(.sides, []); island = c.v(.island, 0); h = c.v(.h, 2700) }
}

/// The made-up room's id starts with this, so screens can tell it from a measured one.
let FREE_ROOM = "free-"

func isFreeRoom(_ r: Room?) -> Bool { r?.id.hasPrefix(FREE_ROOM) == true }

/// A ready model in the gallery: kitchens by layout (sides in run order, island for an island or a peninsula, the
/// ceiling h); wardrobes by their doors (door, slide, open or "type" for a Stage 2 piece) with w × h × d.
struct FModelDef: Equatable {
    var id: String, kind: String
    var layout = "I", sides: [Int] = [], island = 0, h = 2700
    var w = 0, d = W_DEPTH, built = false, doors = "door", n = 0
    /// Stage 2 types (Cabinets.swift): the type, and its gallery group "living" or "bedroom".
    var type = "", group = ""
}

let F_MODELS: [FModelDef] = [
    FModelDef(id: "I", kind: "kitchen", layout: "I", sides: [3000]),
    FModelDef(id: "L", kind: "kitchen", layout: "L", sides: [3000, 2000]),
    FModelDef(id: "U", kind: "kitchen", layout: "U", sides: [2200, 3000, 2200]),
    FModelDef(id: "O", kind: "kitchen", layout: "O", sides: [3000], island: 1800),
    FModelDef(id: "P", kind: "kitchen", layout: "P", sides: [3000], island: 1600),
    FModelDef(id: "h2", kind: "wardrobe", h: 2200, w: 1000, n: 2),
    FModelDef(id: "h3", kind: "wardrobe", h: 2200, w: 1500, n: 3),
    FModelDef(id: "s2", kind: "wardrobe", h: 2500, w: 1800, built: true, doors: "slide", n: 2),
    FModelDef(id: "s3", kind: "wardrobe", h: 2500, w: 2400, built: true, doors: "slide", n: 3),
    FModelDef(id: "op", kind: "wardrobe", h: 2000, w: 1200, d: 400, doors: "open"),
] + CASE_TYPES.map { t in
    let s = typeSize(t)
    return FModelDef(id: t, kind: "wardrobe", h: s.h, w: s.w, d: s.d, doors: "type", type: t, group: LIVING_TYPES.contains(t) ? "living" : "bedroom")
} + NEWER_DEFS

/// The gallery's later pieces of several boxes and items, in a fixed order (Pieces.swift PIECE_TYPES + ITEM_TYPES).
let NEWER_MODELS: [String] = ["stenka", "cornerW", "cornerDesk", "vitrina", "washer", "bed", "bunk", "loft", "dining", "coffee", "bar", "mirrorP"]
/// the gallery's later pieces (Pieces.swift): their sizes come from their steps
private let NEWER_DEFS: [FModelDef] = NEWER_MODELS.map { t in FModelDef(id: t, kind: "wardrobe", doors: "type", type: t, group: "more") }

func fModel(_ id: String) -> FModelDef? { F_MODELS.first { $0.id == id } }

/// The gallery of a kind: kitchens, wardrobes, or ("other") the living room and bedroom types.
func modelsOf(_ kind: String) -> [FModelDef] { kind == "other" ? F_MODELS.filter { !$0.type.isEmpty } : F_MODELS.filter { $0.kind == kind && $0.type.isEmpty } }

/// What a piece counts as for the order's name and what is still wanted: kitchen, wardrobe or other.
func kindKey(_ f: Furniture) -> String { f.kind == "wardrobe" && !f.type.isEmpty ? "other" : f.kind }

/// How many runs along walls a layout has (an island or a peninsula is not one).
func sidesOf(_ layout: String) -> Int { layout == "L" ? 2 : layout == "U" ? 3 : 1 }

/// The made-up room's walls for a layout: the first run on A; a U goes left wall D, back wall A, right wall B.
func freeWalls(_ layout: String) -> [String] {
    switch layout {
    case "L": return ["A", "B"]
    case "U": return ["D", "A", "B"]
    case "O", "P": return ["A", ISLAND]
    default: return ["A"]
    }
}

/// The running metres the price counts for typed sizes: every side, less 600 at each corner, plus the island.
func freeRunMm(_ layout: String, _ sides: [Int], _ island: Int) -> Int {
    let n = sidesOf(layout)
    return sides.prefix(n).reduce(0, +) - (n - 1) * K_CORNER + (layout == "O" || layout == "P" ? island : 0)
}

/// Where the rows of a run end, mm from its start (the corner zone of a later run included).
func runEnd(_ f: Furniture, _ r: Run) -> Int { max(fillOf(f, r, false).used + r.lowStart, fillOf(f, r, true).used + r.upStart) }

/// A room-less kitchen's run lengths, by wall.
func freeLens(_ f: Furniture) -> [String: Int] {
    let ws = f.walls.filter { $0 != ISLAND }
    let sides = f.free?.sides ?? []
    let runs = runsOf(f) { _ in nil }
    var out: [String: Int] = [:]
    for (i, w) in ws.enumerated() {
        out[w] = i < sides.count ? sides[i] : max(600, runs.first { $0.wall == w }.map { runEnd(f, $0) } ?? 600)
    }
    return out
}

/// A run's length for a room-less piece (nil when it stands in a room, or for the island).
func freeLen(_ f: Furniture, _ wall: String) -> Int? { f.roomId == nil && f.kind == "kitchen" ? freeLens(f)[wall] : nil }

/// A cabinet-like piece's main box: its (first) cabinet, or its bed, table, bar counter or mirror panel.
func wardOfF(_ f: Furniture) -> Module? { f.modules.first { $0.type == "wardrobe" || (ITEM_MODS.contains($0.type) && $0.type != "mirror") } }

/// The made-up room of room-less furniture: a rectangle whose walls carry the kitchen's sides (the U's first side sets
/// its depth) or that fits the wardrobe with its usual gaps; no doors, windows or site points.
func freeRoom(_ f: Furniture) -> Room {
    let a: Int, b: Int, h: Int
    if f.kind == "wardrobe" {
        // the first wall carries the piece (a corner piece's first arm), the second a corner piece's other arm
        let bs = boxes(f)
        let w0 = f.walls.first ?? "A"
        let w1: String? = f.walls.count > 1 ? f.walls[1] : nil
        let onA = bs.filter { $0.wall == w0 }
        let onB = bs.filter { $0.wall == w1 }
        a = onA.map { $0.x + $0.w + W_GAP_SIDE }.max() ?? 2000
        if let bEnd = onB.map({ $0.x + $0.w }).max() { b = max(2000, bEnd + 600) }
        else { b = max(2000, (bs.map(\.d).max() ?? W_DEPTH) + 1400) }
        let ws0 = Workshop()
        h = (bs.map { topOf($0, ws0) }.max() ?? 2200) + 300
    } else {
        let lens = freeLens(f), ws = f.walls.filter { $0 != ISLAND }
        func len(_ i: Int) -> Int { i < ws.count ? (lens[ws[i]] ?? 3000) : 3000 }
        switch f.layout {
        case "U": a = len(1); b = max(len(0), len(2))
        case "L": a = len(0); b = len(1)
        case "O", "P": a = len(0); b = 3000
        default: a = len(0); b = 1800
        }
        h = (f.free?.h ?? 0) > 0 ? f.free!.h : 2700
    }
    var r = Room(id: FREE_ROOM + f.id, floorId: "", name: f.name)
    r.dims = ["A": Dim(v: a, src: "manual"), "B": Dim(v: b, src: "manual"), "H": Dim(v: h, src: "manual"), "T": Dim(v: 200, src: "default")]
    r.floorColor = "#E3E8F0"
    return r
}

/// 600 mm units, the last one narrower (from 300) or a filler: the widths along len.
private func slots(_ len: Int) -> [Int] {
    if len <= 0 { return [] }
    let n = len / 600, rem = len - n * 600
    return Array(repeating: 600, count: n) + (rem > 0 ? [rem] : [])
}

/// A new room-less kitchen of layout with its sides (run order), island and ceiling, filled with plain units.
func newFreeKitchen(_ name: String, _ model: String, _ layout: String, _ sides: [Int], _ island: Int, _ h: Int, _ ws: Workshop, now: Ms = 0) -> Furniture {
    let walls = freeWalls(layout)
    var f = Furniture(id: uid(), kind: "kitchen", name: name, roomId: nil, walls: walls, created: now, layout: layout,
                      free: FreeSize(Array(sides.prefix(sidesOf(layout))), walls.contains(ISLAND) ? island : 0, h), model: model, kx: kExtrasFor(layout))
    let ff = f
    let runs = runsOf(f) { freeLen(ff, $0) }
    f = autoFill(f, runs, ws, [], usualPoints(runs))
    if walls.contains(ISLAND) && island > 0 {
        // a peninsula starts with a filler where it joins the side, so its doors clear the side's units
        let pad = layout == "P" ? CORNER_FILLER : 0
        if pad > 0 { f.modules.append(template("fillerLow", ws, ISLAND, pad)) }
        f.modules += slots(island - pad).map { template($0 < 300 ? "fillerLow" : "base", ws, ISLAND, $0) }
    }
    return pack(f, runs)
}

/// Where the water and the gas usually are in a kitchen without a room, so it gets a sink and a hob like a real one: one
/// side, the sink at its second unit and the hob two units from its end; a corner kitchen, the sink in the middle of the
/// first side (a U's back wall) and the hob in the middle of the next.
private func usualPoints(_ runs: [Run]) -> [SitePoint] {
    let rs = runs.filter { $0.wall != ISLAND && $0.len != nil }
    guard let r0 = rs.first else { return [] }
    func mid(_ r: Run) -> Int { r.lowStart + ((r.len ?? 0) - r.lowStart) / 2 }
    func pt(_ t: String, _ r: Run, _ off: Int) -> SitePoint { SitePoint(id: t + "-" + r.wall, t: t, wall: r.wall, off: off, h: 500) }
    if rs.count == 1 {
        let l = (r0.len ?? 0) - r0.lowStart
        return [pt("cold", r0, r0.lowStart + 900)] + (l >= 2400 ? [pt("gas", r0, r0.lowStart + l - 900)] : [])
    }
    let sink = rs.count >= 3 ? rs[1] : rs[0], hob = rs.count >= 3 ? rs[2] : rs[1]
    return [pt("cold", sink, mid(sink)), pt("gas", hob, mid(hob))]
}

/// A new room-less wardrobe w × h × d: doors as the model has them (hinged, sliding or none).
func newFreeWardrobe(_ name: String, _ model: String, _ w: Int, _ h: Int, _ d: Int, _ built: Bool, _ doors: String, _ ws: Workshop, now: Ms = 0, n: Int = 0) -> Furniture {
    var m = wardrobeTemplate(ws, "A", W_GAP_SIDE, w, h, builtIn: built, d: d)
    if doors == "slide" { m.slide = Slide((2...4).contains(n) ? n : slideDoorsFor(slideOpening(m, ws.t).0)) }
    if doors == "open" {
        let ih = wardInnerH(m, ws.t)
        m.sections = m.sections.map { s in var x = s; x.fronts = Fronts("open", 0); x.inserts = Array(repeating: Insert("shelf"), count: 4); return spreadShelves(x, ih, ws.t) }
    }
    return Furniture(id: uid(), kind: "wardrobe", name: name, roomId: nil, walls: ["A"], modules: [m], created: now, model: model)
}

/// A new room-less cabinet of a Stage 2 type, w × h × d.
func newFreeCabinet(_ name: String, _ type: String, _ w: Int, _ h: Int, _ d: Int, _ ws: Workshop, now: Ms = 0) -> Furniture {
    Furniture(id: uid(), kind: "wardrobe", name: name, roomId: nil, walls: ["A"], modules: [cabinetTemplate(type, ws, "A", W_GAP_SIDE, w, h, d)],
              created: now, model: type, type: type)
}

/* ---------------- into a room and out again ---------------- */

/// The walls the piece takes in a room whose walls go ids (clockwise), its first side on first.
func placeWalls(_ f: Furniture, _ ids: [String], _ first: String) -> [String] {
    let i0 = max(0, ids.firstIndex(of: first) ?? 0)
    // a corner piece takes the wall it starts on and the next one round the corner
    if CORNER_TYPES.contains(f.type) && ids.count > 1 { return [ids[i0], ids[(i0 + 1) % ids.count]] }
    if f.kind != "kitchen" { return [i0 < ids.count ? ids[i0] : first] }
    let n = f.walls.filter { $0 != ISLAND }.count
    // a room with no walls yet: the piece keeps the one it was given (no % 0)
    if ids.isEmpty { return f.walls.contains(ISLAND) ? [first, ISLAND] : [first] }
    let out = (0..<n).map { ids[(i0 + $0) % ids.count] }
    return f.walls.contains(ISLAND) ? out + [ISLAND] : out
}

/// The piece with its walls renamed index by index (the island stays the island).
func onWalls(_ f: Furniture, _ walls: [String]) -> Furniture {
    var map: [String: String] = [:]
    for (i, w) in f.walls.enumerated() { map[w] = i < walls.count ? walls[i] : w }
    var g = f; g.walls = walls
    g.modules = f.modules.map { m in var x = m; if let w = m.wall { x.wall = map[w] ?? w }; return x }
    return g
}

/// Something that does not fit: key its text, its numbers.
struct FitIssue: Equatable { let key: String; let vars: [String: String] }

/// What does not fit when f goes on walls of a room (len each wall's length, roomH its height); a wardrobe stands off
/// mm from the wall's start corner (nil: in the corner).
func fitIssues(_ f: Furniture, _ walls: [String], _ len: (String) -> Int?, _ roomH: Int?, _ ws: Workshop, off: Int? = nil, start: Int? = nil,
               deep: (String) -> Int? = { _ in nil }) -> [FitIssue] {
    var out: [FitIssue] = []
    if f.kind == "wardrobe" {
        let bs = boxes(f)
        if bs.isEmpty { return out }
        let x = off ?? cornerGap(f)
        if CORNER_TYPES.contains(f.type) {
            // each arm along its own wall: the first ends in the corner, the second starts past the first's depth
            for (i, fw) in f.walls.prefix(2).enumerated() {
                guard i < walls.count, let l = len(walls[i]) else { continue }
                let on = bs.filter { $0.wall == fw }
                let need: Int
                if i == 0 { need = on.reduce(0, { $0 + $1.w }) + 2 * W_GAP_SIDE }
                else { need = (on.map { $0.x + $0.w }.max() ?? 0) + W_GAP_SIDE }
                if need > l { out.append(FitIssue(key: "fz.wide", vars: ["n": f.name, "v": "\(need)", "w": walls[i], "d": "\(need - l)", "l": "\(l)"])) }
            }
        } else if let L = len(walls[0]), f.pose == nil, x + runLen(f) > L {
            // standing free (a desk in the room) it is not held to a wall's length
            let v = x + runLen(f)
            out.append(FitIssue(key: "fz.wide", vars: ["n": f.name, "v": "\(v)", "w": walls[0], "d": "\(v - L)", "l": "\(L)"]))
        }
        let H = bs.map { topOf($0, ws) }.max() ?? 0
        if let roomH, H > roomH { out.append(FitIssue(key: "fz.high", vars: ["n": f.name, "v": "\(H)", "d": "\(H - roomH)", "l": "\(roomH)"])) }
        // deeper than the room in front of its wall: it would go through the wall opposite (deep: the room's depth there)
        if !CORNER_TYPES.contains(f.type) && f.pose == nil, let room = deep(walls[0]) {
            let d = bs.map { $0.d }.max() ?? 0
            if d > room { out.append(FitIssue(key: "fz.deep", vars: ["n": f.name, "v": "\(d)", "d": "\(d - room)", "l": "\(room)"])) }
        }
        return out
    }
    let runs = runsOf(f) { _ in nil }
    for (i, w) in walls.enumerated() where w != ISLAND && i < runs.count {
        let r = runs[i]
        var need = runEnd(f, r)
        if f.roomId == nil, let s = f.free?.sides, i < s.count { need = max(s[i], need) }
        // a one-wall kitchen slid along its wall needs its distance from the corner too
        if i == 0 { need += start ?? 0 }
        guard let L = len(w) else { continue }
        if need > L { out.append(FitIssue(key: "fz.long", vars: ["i": "\(i + 1)", "v": "\(need)", "w": w, "d": "\(need - L)", "l": "\(L)"])) }
    }
    return out
}

/// A row of a run cut to avail: units kept from its start while they fit, the rest of the room a narrower unit or a filler.
private func fitRow(_ f: Furniture, _ wall: String, _ upper: Bool, _ start: Int, _ avail: Int, _ ws: Workshop) -> Furniture {
    let row = f.modules.filter { $0.wall == wall && isUpper($0) == upper }
    if row.reduce(0, { $0 + $1.w }) + start <= avail { return f }
    var x = start
    var keep: [Module] = []
    for m in row where x + m.w <= avail { keep.append(m); x += m.w }
    let rem = avail - x
    if rem > 0 { keep.append(template(upper ? (rem < 300 ? "fillerUp" : "wall") : (rem < 300 ? "fillerLow" : "base"), ws, wall, rem)) }
    var g = f; g.modules = f.modules.filter { !($0.wall == wall && isUpper($0) == upper) } + keep
    return g
}

/// Items whose width "fit to the wall" may take in: a table, the bar counter.
let NARROW_ITEMS: Set<String> = ["table", "bar"]

/// How deep a room is in front of a wall from p0 to p1: the farthest of the room's corners from the wall's line, mm.
func depthFrom(_ p0: Pt, _ p1: Pt, _ corners: [Pt]) -> Int {
    let dx = p1.x - p0.x, dy = p1.y - p0.y
    let l = (dx * dx + dy * dy).squareRoot()
    if l <= 0 { return 0 }
    var best = 0.0
    for c in corners {
        let cross = (c.x - p0.x) * dy - (c.y - p0.y) * dx
        best = max(best, abs(cross) / l)
    }
    return Int(best)
}

/// The piece made to fit walls: kitchen rows cut to each wall, a wardrobe narrowed to the wall and lowered under the ceiling.
func fitTo(_ f: Furniture, _ walls: [String], _ len: (String) -> Int?, _ roomH: Int?, _ ws0: Workshop, off: Int? = nil) -> Furniture {
    let ws = wsOf(f, ws0)
    if f.kind == "wardrobe" { return fitPiece(f, walls, len, roomH, ws, off: off) }
    var g = f
    for r in runsOf(f, len) where r.wall != ISLAND && r.len != nil {
        g = fitRow(g, r.wall, false, r.lowStart, r.len!, ws)
        g = fitRow(g, r.wall, true, r.upStart, r.len!, ws)
    }
    return pack(g, runsOf(g, len))
}

/// A cabinet-like piece made to fit walls: lowered under the ceiling, its widest box narrowed to the wall; a corner
/// piece into its corner, a piece of several boxes packed again.
private func fitPiece(_ f: Furniture, _ walls: [String], _ len: (String) -> Int?, _ roomH: Int?, _ ws: Workshop, off: Int?) -> Furniture {
    guard let m = wardOfF(f) else { return f }
    // lower under the ceiling: a cabinet's carcass, not a bed or a table
    func lower(_ b: Module) -> Module {
        guard let roomH, b.type == "wardrobe", topOf(b, ws) > roomH - W_GAP_TOP else { return b }
        var n = b; n.h = max(300, roomH - W_GAP_TOP - legsOf(b, ws) - b.elev)
        return n
    }
    // narrower to the wall: a cabinet's widest box gives way (a door hinged at an end next to the wall needs 50 mm there)
    // a table or the bar counter gives way too, down to its least width (a bed keeps its mattress's; a loft bed its frame)
    func narrow(_ g: Furniture, _ wall: String, _ room: Int?) -> Furniture {
        if g.type == "loft" { return g }
        let on = boxes(g).filter { $0.wall == wall && !hung($0) && ($0.type == "wardrobe" || NARROW_ITEMS.contains($0.type)) }
        guard let room, !on.isEmpty else { return g }
        let ext = CORNER_TYPES.contains(g.type) ? on.reduce(0, { $0 + $1.w }) : runLen(g)
        let over = ext - room
        if over <= 0 { return g }
        let open = on.filter { b in !b.sections.contains { $0.blind > 0 } }
        guard let big = open.max(by: { $0.w < $1.w }) else { return g }
        if big.type != "wardrobe" {
            let least = itemRange(big, "w").lowerBound
            let iw = max(min(big.w, least), big.w - over)
            var o2 = g
            o2.modules = g.modules.map { x in
                guard x.id == big.id else { return x }
                var n = x; n.w = iw
                return n
            }
            return o2
        }
        let w = max(min(big.w, 300), big.w - over)
        var out = g
        out.modules = g.modules.map { x in
            guard x.id == big.id else { return x }
            var n = x; n.w = w; n.sections = splitSections(w, x.sections.map { var s = $0; s.lock = false; return s })
            return n
        }
        return out
    }
    var g = f
    g.modules = f.modules.map { isBox($0) ? lower($0) : $0 }
    let L0 = len(walls[0])
    if boxes(f).count == 1 && m.type == "wardrobe" {
        let x = off ?? cornerGap(f)
        let gapR = cornerGap(f, right: true)
        let w = L0.map { max(min(m.w, 300), min(m.w, $0 - x - gapR)) } ?? m.w
        g.modules = g.modules.map { b in
            guard b.id == m.id else { return b }
            var n = b; n.w = w
            if w != m.w { n.sections = splitSections(w, b.sections.map { var s = $0; s.lock = false; return s }) }
            return n
        }
        return g
    }
    if CORNER_TYPES.contains(f.type) {
        let wa = f.walls[0]
        let wb = f.walls.count > 1 ? f.walls[1] : f.walls[0]
        g = narrow(g, wa, L0.map { $0 - 2 * W_GAP_SIDE })
        let lastD = boxes(g).last(where: { $0.wall == wa })?.d ?? 0
        let roomB: Int? = walls.count > 1 ? len(walls[1]).map { $0 - W_GAP_SIDE - lastD } : nil
        g = narrow(g, wb, roomB)
        return cornerFit(g, L0)
    }
    let x0 = off ?? cornerGap(f)
    let gapR = cornerGap(f, right: true)
    g = narrow(g, f.walls.first ?? "A", L0.map { $0 - x0 - gapR })
    return packPiece(g, L0, ws: ws)
}

/// Where a corner kitchen's first side starts on its wall: its units end in the corner, an empty stretch before them.
func firstStart(_ f: Furniture, _ wallLen: Int?) -> Int {
    guard f.kind == "kitchen", f.walls.filter({ $0 != ISLAND }).count >= 2, let L = wallLen, let r = runsOf(f, { _ in nil }).first else { return 0 }
    return max(0, L - runEnd(f, r))
}

/// The piece standing in room roomId (workspace wsId) on walls (len each wall's length); a wardrobe off from the
/// corner; keep its size kept. A corner kitchen's first side shorter than its wall gets an empty stretch at the wall's
/// start, so its last unit stands in the corner where the next side turns.
/// Pieces that may stand away from the walls, turned any way (a kitchen's island always may): a desk, shelving as a divider.
let FREE_TYPES: Set<String> = ["desk", "shelving", "bed", "bunk", "loft", "dining", "coffee", "bar"]

func canStandFree(_ f: Furniture) -> Bool { f.kind == "wardrobe" && FREE_TYPES.contains(f.type) }

/// The empty stretch a kitchen's first side starts with (its leading space gaps) taken off: what is left to place again.
func withoutLead(_ f: Furniture, _ len: (String) -> Int? = { _ in nil }) -> Furniture {
    guard f.kind == "kitchen" else { return f }
    let w0 = f.walls.first
    let lead = Set(f.modules.filter { $0.wall == w0 && $0.type == "gap" && $0.x == 0 && ($0.app == "space" || isUpper($0)) }.map(\.id))
    if lead.isEmpty { return f }
    var g = f; g.modules = f.modules.filter { !lead.contains($0.id) }
    return pack(g, runsOf(g, len))
}

/// How far a one-wall kitchen starts from its wall's corner: the width of its leading empty stretch.
func leadOf(_ f: Furniture) -> Int {
    let w0 = f.walls.first
    return f.modules.first { $0.wall == w0 && $0.type == "gap" && $0.x == 0 && $0.app == "space" && !isUpper($0) }?.w ?? 0
}

/// The island's (or peninsula's) length along its row.
func islandLen(_ f: Furniture) -> Int { runsOf(f) { _ in nil }.first { $0.wall == ISLAND }.map { fillOf(f, $0, false).used } ?? 0 }

/// Where an island stands unless dragged: centred on the first side, 900 mm out from its units, its fronts facing them.
/// A peninsula joins the side's end at a right angle, going out into the room, its fronts towards the kitchen.
func islandPose(_ f: Furniture, _ wallLen: Int) -> Pose {
    let len = islandLen(f)
    let first = f.walls.first { $0 != ISLAND } ?? "A"
    if f.layout == "P" {
        let end = runsOf(f) { _ in nil }.first { $0.wall != ISLAND }.map { runEnd(f, $0) } ?? wallLen
        // its seating overhang and finished back (336 mm past its back) stay inside the room
        return Pose(first, min(end, wallLen - 336), 600, 90)
    }
    return Pose(first, (wallLen - len) / 2 + len, K_BASE_D + 900 + K_BASE_D, 180)
}

/// The piece standing in room roomId (workspace wsId) on walls; a wardrobe off from the corner; a one-wall kitchen start
/// from it; pose: an island or a free-standing piece where it was dragged.
func placed(_ f: Furniture, _ walls: [String], _ roomId: String, _ wsId: String, off: Int? = nil, keep: Bool = false, len: (String) -> Int? = { _ in nil }, ws: Workshop = Workshop(),
            start: Int? = nil, pose: Pose? = nil) -> Furniture {
    var g = onWalls(withoutLead(f, len), walls); g.roomId = roomId; g.ws = wsId; g.keep = keep; g.pose = pose
    if g.kind == "wardrobe" {
        // a corner piece fills its corner; the others stand off from the wall's start
        let wallLen = len(walls[0]), free = pose != nil
        if CORNER_TYPES.contains(g.type) { return cornerFit(g, wallLen) }
        g = packPiece(shiftRun(g, off ?? cornerGap(g)), wallLen, ws: ws)
        // the side panels follow where it stands: an end in the room has one, a sliding wardrobe uses the wall it meets
        if boxes(g).count > 1 { return g }
        g.modules = g.modules.map { $0.type == "wardrobe" ? withSides($0, wallLen, free: free) : $0 }
        return g
    }
    let gap = walls.filter { $0 != ISLAND }.count == 1 ? start ?? 0 : firstStart(g, len(walls[0]))
    if gap > 0 {
        let w0 = walls[0]
        var low = template("spaceLow", ws, w0, gap); low.elev = g.modules.first { $0.wall == w0 && !isUpper($0) }?.elev ?? ws.legH
        var up = template("spaceUp", ws, w0, gap); up.elev = g.modules.first { $0.wall == w0 && isUpper($0) }?.elev ?? wallElev(ws)
        // the empty stretch goes first in the module list, so it packs at the wall's start
        g.modules = [low, up] + g.modules
        g = pack(g, runsOf(g, len))
    }
    return g
}

/// The piece taken out of its room: sizes from what is on each wall now, back on the made-up room's walls.
func takenOut(_ f0: Furniture, _ len: (String) -> Int?, _ roomH: Int?) -> Furniture {
    if f0.kind == "wardrobe" {
        let corner = CORNER_TYPES.contains(f0.type)
        var g = onWalls(f0, corner ? ["A", "B"] : ["A"]); g.roomId = nil; g.ws = ""; g.keep = false; g.pose = nil
        if corner {
            g.modules = g.modules.map { m in
                var x = m
                if m.wall == "A" { x.x = W_GAP_SIDE }
                return x
            }
            return cornerFit(g, nil)
        }
        if boxes(g).count > 1 { return packPiece(shiftRun(g, W_GAP_SIDE)) }
        g.modules = g.modules.map { m in
            var x = m
            // out of the room it stands free: a sliding wardrobe gets both its side panels back
            if m.type == "wardrobe" { x.x = W_GAP_SIDE; return withSides(x, nil) }
            if isBox(m) { x.x = W_GAP_SIDE }
            return x
        }
        return g
    }
    // the empty stretch before a corner kitchen's first side stays with the room, and so does where its island stood
    var f = withoutLead(f0, len); f.pose = nil
    let runs = runsOf(f, len)
    let sides = runs.filter { $0.wall != ISLAND }.map { max(runEnd(f, $0), 600) }
    let island = runs.first { $0.wall == ISLAND }.map { fillOf(f, $0, false).used } ?? 0
    var g = onWalls(f, freeWalls(f.layout)); g.roomId = nil; g.ws = ""; g.keep = false
    g.free = FreeSize(sides, island, roomH ?? f.free?.h ?? 2700)
    let gg = g
    return pack(g, runsOf(g) { freeLen(gg, $0) })
}
