import Foundation

/*
 * Designer C, the founder-approved editing on the picture (27 Oct 2026; design/designer-c/mockup.html; the same rules as
 * the Android app's): the width snaps, who takes the difference when a unit grows or shrinks, a deleted unit's gap and
 * closing it, a copy to the right, moving along the row, the catalogue's tiles going into a gap or between two units,
 * a wall unit's height and alignment, and a wardrobe's sections. Pure functions of the furniture; the screens are
 * Furniture/Dzc*.swift. Unit-tested (DesignerCTests).
 *
 * A kitchen row is the modules of one wall and one row (lower or upper) in the order of Furniture.modules; pack()
 * gives them their x. A row may end short of its wall: that free end takes part like an empty space at the row's end.
 */

/// The widths a drag of a unit's right edge snaps to (no tick on each snap: haptics only on confirm and warning).
let DZC_SNAP = [150, 300, 350, 400, 450, 500, 600, 700, 800, 900, 1000, 1200]
/// A wall unit's heights for its bottom edge's handle.
let DZC_HSNAP = [360, 500, 600, 720, 900]
/// A filler this wide or wider becomes an empty space ("+").
let DZC_GAP_FROM = 150
/// The narrowest cabinet a drag or a fit makes.
let DZC_MIN_W = 150
/// The narrowest wardrobe section.
let DZC_SEC_MIN = 150
/// Zoomed in past this (times the fitted view), the edge moves in 10 mm steps.
let DZC_FINE_ZOOM = 2.5

/* ---------------- what a unit is ---------------- */

/// An empty space of a row (no boards): the lower row's "spaceLow" (app "space") or an upper one.
func dzcSpace(_ m: Module) -> Bool { m.type == "gap" && (m.app == "space" || m.app.isEmpty) }

/// A filler or an empty space: what takes a neighbour's difference first.
func dzcGives(_ m: Module) -> Bool { dzcSpace(m) || m.type == "filler" }

/// A run's blind corner unit (a panel for a door, behind the next run's first unit): it stays at its row's end.
func dzcPinned(_ m: Module) -> Bool { m.app.isEmpty && m.fronts.kind == "panel" && (m.type == "base" || m.type == "wall") }

/// An appliance's unit: only its own widths, no 10 mm steps, and it never takes a neighbour's difference.
func dzcFixedW(_ m: Module) -> Bool { ["dishwasher", "hob", "hood", "oven", "fridgeB", "fridge", "micro"].contains(m.app) }

/// The widths unit m may take.
func dzcWidths(_ m: Module) -> [Int] {
    switch m.app {
    case "dishwasher": return [450, 600]
    case "hob": return [450, 600, 900]
    case "hood": return [600, 900]
    case "sink": return [450, 500, 600, 800, 900]
    case "oven": return [450, 600]
    case "fridgeB": return [600]
    case "micro": return [500, 600]
    case "fridge": return [600, 700, 900]
    default: break
    }
    if m.type == "filler" { return [20, 30, 50, 80, 100] }
    if m.type == "tall" { return [400, 450, 500, 600] }
    return DZC_SNAP
}

/// The narrowest m may become: a filler 10, a cabinet DZC_MIN_W.
func dzcLowW(_ m: Module) -> Int { m.type == "filler" ? 10 : DZC_MIN_W }

/// The biggest snap width that fits in free mm (0: none).
func dzcLargestSnap(_ free: Int) -> Int { DZC_SNAP.filter { $0 <= free }.last ?? 0 }

/// What a drag may snap m to, up to mx (the widest it can get): its widths, mx itself for a free width, its own width.
func dzcCandidates(_ m: Module, _ mx: Int) -> [Int] {
    let lo = dzcLowW(m)
    var list = dzcWidths(m).filter { $0 >= lo && $0 <= mx }
    if !dzcFixedW(m) && m.type != "filler" && mx >= lo && mx <= 1200 && !list.contains(mx) { list.append(mx) }
    if m.w <= mx && m.w >= lo && !list.contains(m.w) { list.append(m.w) }
    return list.sorted()
}

/// The width a drag of the right edge to raw mm gives: the nearest of cands; zoomed in (fine) 10 mm steps between lo and
/// hi, a candidate within 15 mm still winning.
func dzcSnapW(_ raw: Int, _ cands: [Int], fine: Bool, lo: Int, hi: Int) -> Int {
    if fine {
        if let near = cands.first(where: { abs($0 - raw) < 15 }) { return near }
        let v = Int((Double(raw) / 10).rounded()) * 10
        return min(max(v, lo), max(lo, hi))
    }
    guard var best = cands.first else { return min(max(raw, lo), max(lo, hi)) }
    for c in cands where abs(c - raw) < abs(best - raw) { best = c }
    return best
}

/// The nearest of list to raw.
func dzcNearest(_ raw: Int, _ list: [Int]) -> Int {
    guard var best = list.first else { return raw }
    for c in list where abs(c - raw) < abs(best - raw) { best = c }
    return best
}

/* ---------------- a kitchen's rows ---------------- */

struct DzcRow: Equatable, Hashable {
    let wall: String
    let upper: Bool
}

func dzcRowKey(_ m: Module) -> DzcRow { DzcRow(wall: m.wall ?? "", upper: isUpper(m)) }

private func dzcIn(_ m: Module, _ r: DzcRow) -> Bool { (m.wall ?? "") == r.wall && isUpper(m) == r.upper }

/// Row r's modules in their order.
func dzcRowMods(_ f: Furniture, _ r: DzcRow) -> [Module] { f.modules.filter { dzcIn($0, r) } }

/// f with row r's modules replaced by list (in its order); the other modules stay where they are.
func dzcWithRow(_ f: Furniture, _ r: DzcRow, _ list: [Module]) -> Furniture {
    let last = f.modules.lastIndex { dzcIn($0, r) }
    var out: [Module] = []
    var k = 0
    for (i, m) in f.modules.enumerated() {
        if dzcIn(m, r) {
            if k < list.count { out.append(list[k]); k += 1 }
        } else {
            out.append(m)
        }
        if i == last { while k < list.count { out.append(list[k]); k += 1 } }
    }
    if last == nil { out += list }
    var g = f
    g.modules = out
    return g
}

/// The row's free end, mm (avail: the room the row has, nil an island's: no limit).
func dzcTail(_ row: [Module], _ avail: Int?) -> Int? { avail.map { $0 - row.reduce(0) { $0 + $1.w } } }

/// An empty space in m's place, w wide, with m's id (its row's usual height).
func dzcSpaceLike(_ m: Module, _ w: Int, _ ws: Workshop) -> Module {
    var s = template(isUpper(m) ? "spaceUp" : "spaceLow", ws, m.wall ?? "", w)
    s.id = m.id
    return s
}

/// A filler of the row of m, w wide (a new id).
func dzcFillerLike(_ m: Module, _ w: Int, _ ws: Workshop) -> Module {
    template(isUpper(m) ? "fillerUp" : "fillerLow", ws, m.wall ?? "", w)
}

/// A row tidied: spaces and fillers of no width go, a filler of DZC_GAP_FROM or more becomes an empty space, spaces side
/// by side become one (the first one's id).
func dzcTidy(_ row: [Module], _ ws: Workshop) -> [Module] {
    var out: [Module] = []
    for m in row {
        if dzcGives(m) && m.w <= 0 { continue }
        var n = m
        if m.type == "filler" && m.w >= DZC_GAP_FROM { n = dzcSpaceLike(m, m.w, ws) }
        if dzcSpace(n), let p = out.last, dzcSpace(p) {
            out[out.count - 1].w += n.w
            continue
        }
        out.append(n)
    }
    return out
}

/// What an edit gave: the furniture (unpacked), or why not (a strings key and its numbers); who took the difference
/// (an id, "" the row's free end) and its width before and after; the new unit's id.
struct DzcResult {
    var f: Furniture
    var ok = true
    var why = ""
    var vars: [String: Int] = [:]
    var taker: String? = nil
    var w0 = 0
    var w1 = 0
    var newId: String? = nil
    /// The taker is on the unit's left (nothing on its right could give).
    var left = false
}

private func dzcNo(_ f: Furniture, _ why: String, _ vars: [String: Int] = [:]) -> DzcResult {
    var r = DzcResult(f: f)
    r.ok = false; r.why = why; r.vars = vars
    return r
}

/// The nearest filler or empty space to index i of row (not i itself), or -1.
func dzcNearestGive(_ row: [Module], _ i: Int) -> Int {
    var best = -1, bd = Int.max
    for (j, x) in row.enumerated() where j != i && dzcGives(x) {
        let dist = abs(j - i)
        if dist < bd { bd = dist; best = j }
    }
    return best
}

/// A unit next to index i that may take a difference: not a filler or space, not an appliance.
private func dzcCanNeighbour(_ row: [Module], _ j: Int) -> Bool {
    j >= 0 && j < row.count && !dzcFixedW(row[j]) && !dzcGives(row[j])
}

/// Who takes the difference d (mm; more than 0 growing) when unit i of row is resized by its right edge: j the row
/// index, -1 the row's free end; left: it came from the left of the unit.
struct DzcAbsorb: Equatable {
    let j: Int
    let left: Bool
}

/// Whoever takes the right edge's difference d for unit i of row (tail: the row's free end, nil an island's, no limit):
/// the right side first (the nearest filler or empty space there, growing the row's free end, the unit just right of
/// it, shrinking the free end that grows), and only when nothing on the right can, the left side (the nearest filler
/// or space there, the unit just left of it). nil: nobody can.
func dzcAbsorber(_ row: [Module], _ i: Int, _ d: Int, tail: Int?) -> DzcAbsorb? {
    if d == 0 || i < 0 || i >= row.count { return nil }
    func can(_ j: Int) -> Bool { dzcGives(row[j]) ? row[j].w - d >= 0 : row[j].w - d >= DZC_MIN_W }
    // the right side
    if let g = (i + 1..<row.count).first(where: { dzcGives(row[$0]) }), can(g) { return DzcAbsorb(j: g, left: false) }
    if d > 0, tail == nil || tail! >= d { return DzcAbsorb(j: -1, left: false) }
    if dzcCanNeighbour(row, i + 1), can(i + 1) { return DzcAbsorb(j: i + 1, left: false) }
    if d < 0 { return DzcAbsorb(j: -1, left: false) }
    // nothing there can: the left side
    if let g = (0..<i).reversed().first(where: { dzcGives(row[$0]) }), can(g) { return DzcAbsorb(j: g, left: true) }
    if dzcCanNeighbour(row, i - 1), can(i - 1) { return DzcAbsorb(j: i - 1, left: true) }
    return nil
}

/// The widest unit mid can get: what the one who can give most has (the nearest filler or space on each side given up
/// whole, the row's free end, a neighbour down to DZC_MIN_W; an island's row: no limit, 2400).
func dzcMaxW(_ f: Furniture, _ mid: String, avail: Int?) -> Int {
    guard let m = f.modules.first(where: { $0.id == mid }) else { return 0 }
    let row = dzcRowMods(f, dzcRowKey(m))
    guard let i = row.firstIndex(where: { $0.id == mid }) else { return m.w }
    var best = m.w
    if let g = (i + 1..<row.count).first(where: { dzcGives(row[$0]) }) { best = max(best, m.w + row[g].w) }
    if let g = (0..<i).reversed().first(where: { dzcGives(row[$0]) }) { best = max(best, m.w + row[g].w) }
    if let t = dzcTail(row, avail) { best = max(best, m.w + max(0, t)) } else { best = max(best, 2400) }
    for j in [i + 1, i - 1] where dzcCanNeighbour(row, j) { best = max(best, m.w + row[j].w - DZC_MIN_W) }
    return best
}

/// Unit mid nw wide (Designer C "Kenglik", its right edge dragged or the width typed): the difference is taken as
/// dzcAbsorber says, the right side first. A filler left 150 mm or wider becomes an empty space; one left at 0 goes.
func dzcResize(_ f: Furniture, _ mid: String, _ nw: Int, avail: Int?, ws: Workshop) -> DzcResult {
    guard let m = f.modules.first(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    let key = dzcRowKey(m)
    var row = dzcRowMods(f, key)
    guard let i = row.firstIndex(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    let d = nw - m.w
    if d == 0 { return DzcResult(f: f) }
    if nw < dzcLowW(m) { return dzcNo(f, "dzc.minW", ["v": dzcLowW(m)]) }
    var r = DzcResult(f: f)
    let tail = dzcTail(row, avail)
    guard let ab = dzcAbsorber(row, i, d, tail: tail) else {
        let mx = dzcMaxW(f, mid, avail: avail)
        return mx > m.w ? dzcNo(f, "dzc.maxW", ["v": mx]) : dzcNo(f, "dzc.noTaker")
    }
    r.left = ab.left
    if ab.j < 0 {
        r.taker = tail == nil ? nil : ""; r.w0 = tail ?? 0; r.w1 = (tail ?? 0) - d
    } else {
        r.taker = row[ab.j].id; r.w0 = row[ab.j].w; r.w1 = row[ab.j].w - d
        row[ab.j].w -= d
    }
    row[i].w = nw
    r.f = dzcWithRow(f, key, dzcTidy(row, ws))
    return r
}

/// Unit mid deleted (Designer C "O‘chirish"): a dashed "+" space of its width stays in its place (an empty space
/// itself goes). newId: the space now there.
func dzcDelete(_ f: Furniture, _ mid: String, ws: Workshop) -> DzcResult {
    guard let m = f.modules.first(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    let key = dzcRowKey(m)
    var row = dzcRowMods(f, key)
    guard let i = row.firstIndex(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    let at = row[0..<i].reduce(0) { $0 + $1.w }
    if dzcSpace(m) { row.remove(at: i) } else { row[i] = dzcSpaceLike(m, m.w, ws) }
    let tidy = dzcTidy(row, ws)
    var r = DzcResult(f: dzcWithRow(f, key, tidy))
    var x = 0
    for n in tidy {
        if dzcSpace(n) && at >= x && at < x + n.w { r.newId = n.id; break }
        x += n.w
    }
    return r
}

/// The "+" space unit m leaves when deleted from f, mm: its own width, or more when it joins a space beside it (the
/// delete toast's number).
func dzcGapLeft(_ f: Furniture, _ m: Module, _ ws: Workshop) -> Int {
    let r = dzcDelete(f, m.id, ws: ws)
    guard let id = r.newId, let g = r.f.modules.first(where: { $0.id == id }) else { return m.w }
    return g.w
}

/// Empty space gid closed (Designer C "Yopish ↔"): the units after it move up; the row's last filler or space (before a
/// blind corner unit) grows by its width, else a new one goes there (an island's row just gets shorter).
func dzcCloseGap(_ f: Furniture, _ gid: String, avail: Int?, ws: Workshop) -> DzcResult {
    guard let g = f.modules.first(where: { $0.id == gid }), dzcSpace(g) else { return dzcNo(f, "dzc.gone") }
    let key = dzcRowKey(g)
    var row = dzcRowMods(f, key)
    guard let i = row.firstIndex(where: { $0.id == gid }) else { return dzcNo(f, "dzc.gone") }
    var end = row.count - 1
    while end >= 0 && dzcPinned(row[end]) { end -= 1 }
    if i == end { return dzcNo(f, "dzc.atEnd") }
    let w = g.w
    row.remove(at: i)
    var e = row.count - 1
    while e >= 0 && dzcPinned(row[e]) { e -= 1 }
    var r = DzcResult(f: f)
    if e >= 0 && dzcGives(row[e]) {
        r.taker = row[e].id; r.w0 = row[e].w; r.w1 = row[e].w + w
        row[e].w += w
    } else if avail != nil {
        let n = w < DZC_GAP_FROM ? dzcFillerLike(g, w, ws) : dzcSpaceLike(g, w, ws)
        row.insert(n, at: e + 1)
        r.newId = n.id; r.w0 = 0; r.w1 = w
    }
    r.f = dzcWithRow(f, key, dzcTidy(row, ws))
    return r
}

/// Takes need mm for a unit going in at index at of row (at already holds it): the row's free end first, then the
/// empty spaces nearest it, then the fillers. Returns the row, or nil when there is not enough room.
private func dzcTakeRoom(_ row0: [Module], at: Int, need: Int, avail: Int?) -> [Module]? {
    var row = row0
    let others = row.reduce(0) { $0 + $1.w } - row[at].w
    var rem = need
    if let a = avail {
        let tail = max(0, a - others)
        rem -= min(tail, rem)
    } else {
        return row
    }
    if rem <= 0 { return row }
    let idx = row.indices.filter { $0 != at && dzcGives(row[$0]) }
    let order = idx.sorted { a, b in
        let sa = dzcSpace(row[a]) ? 0 : 1, sb = dzcSpace(row[b]) ? 0 : 1
        return sa != sb ? sa < sb : abs(a - at) < abs(b - at)
    }
    for j in order where rem > 0 {
        let tk = min(row[j].w, rem)
        row[j].w -= tk; rem -= tk
    }
    return rem > 0 ? nil : row
}

/// The room a row has for a new unit: its free end, spaces and fillers.
func dzcFree(_ row: [Module], avail: Int?) -> Int? {
    guard let a = avail else { return nil }
    return max(0, a - row.reduce(0) { $0 + $1.w }) + row.filter(dzcGives).reduce(0) { $0 + $1.w }
}

/// A copy of unit mid to its right (Designer C "Nusxa"): the room comes from the row's free end, then the nearest
/// empty spaces and fillers; not enough room: why, with the free and the needed mm.
func dzcCopy(_ f: Furniture, _ mid: String, avail: Int?, ws: Workshop, id: String? = nil) -> DzcResult {
    guard let m = f.modules.first(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    let key = dzcRowKey(m)
    var row = dzcRowMods(f, key)
    guard let i = row.firstIndex(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    var c = m
    c.id = id ?? uid()
    let free = dzcFree(row, avail: avail)
    if let free, free < m.w { return dzcNo(f, "dzc.noCopy", ["f": free, "n": m.w]) }
    row.insert(c, at: i + 1)
    guard let took = dzcTakeRoom(row, at: i + 1, need: m.w, avail: avail) else { return dzcNo(f, "dzc.noCopy", ["f": free ?? 0, "n": m.w]) }
    var r = DzcResult(f: dzcWithRow(f, key, dzcTidy(took, ws)))
    r.newId = c.id
    return r
}

/// The last place a unit may take in a row without it (rest): before the blind corner units at its end.
func dzcMoveHi(_ rest: [Module]) -> Int {
    var hi = rest.count
    while hi > 0 && dzcPinned(rest[hi - 1]) { hi -= 1 }
    return hi
}

/// Unit mid moved to place `to` among the others of its row (Designer C: lifted and dropped, or "Surish").
func dzcMove(_ f: Furniture, _ mid: String, to: Int, ws: Workshop) -> DzcResult {
    guard let m = f.modules.first(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    let key = dzcRowKey(m)
    var rest = dzcRowMods(f, key)
    guard let i = rest.firstIndex(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    rest.remove(at: i)
    let t = min(max(to, 0), dzcMoveHi(rest))
    rest.insert(m, at: t)
    return DzcResult(f: dzcWithRow(f, key, dzcTidy(rest, ws)))
}

/// Unit mid one place left (step -1) or right (+1) along its row; nil when it cannot go that way.
func dzcStep(_ f: Furniture, _ mid: String, _ step: Int, ws: Workshop) -> DzcResult? {
    guard let m = f.modules.first(where: { $0.id == mid }) else { return nil }
    let row = dzcRowMods(f, dzcRowKey(m))
    guard let i = row.firstIndex(where: { $0.id == mid }) else { return nil }
    var rest = row
    rest.remove(at: i)
    let t = i + step
    if t < 0 || t > dzcMoveHi(rest) || dzcPinned(m) { return nil }
    return dzcMove(f, mid, to: t, ws: ws)
}

/// Where a unit lifted with its left edge at gx (mm from the run's start; the row starts at start) drops: the place
/// among the others whose centre is nearest its centre.
func dzcDropSlot(_ row: [Module], _ mid: String, start: Int, gx: Int) -> Int {
    guard let i = row.firstIndex(where: { $0.id == mid }) else { return 0 }
    var rest = row
    let m = rest.remove(at: i)
    let hi = dzcMoveHi(rest)
    let c = gx + m.w / 2
    var best = 0, bd = Int.max, acc = start
    for j in 0...hi {
        let cen = acc + m.w / 2
        if abs(cen - c) < bd { bd = abs(cen - c); best = j }
        if j < rest.count { acc += rest[j].w }
    }
    return best
}

/// Wall unit mid h high, its top where it was (Designer C: the bottom edge's handle, "Balandlik").
func dzcHeight(_ f: Furniture, _ mid: String, _ h: Int) -> Furniture {
    var g = f
    g.modules = f.modules.map { m in
        guard m.id == mid else { return m }
        var n = m
        n.elev = m.elev + m.h - h; n.h = h
        return n
    }
    return g
}

/// Wall unit mid lined up with the lower unit under its middle (Designer C "Tekislash"): its width and place, its
/// neighbours giving way; nil with why when it cannot.
func dzcAlign(_ f: Furniture, _ mid: String, ws: Workshop) -> DzcResult {
    guard let m = f.modules.first(where: { $0.id == mid }), isUpper(m) else { return dzcNo(f, "dzc.gone") }
    let key = dzcRowKey(m)
    var row = dzcRowMods(f, key)
    guard let i = row.firstIndex(where: { $0.id == mid }) else { return dzcNo(f, "dzc.gone") }
    let cx = m.x + m.w / 2
    let low = f.modules.filter { ($0.wall ?? "") == key.wall && !isUpper($0) && !dzcSpace($0) }
    guard let b = low.first(where: { cx >= $0.x && cx < $0.x + $0.w }) else { return dzcNo(f, "dzc.noUnder") }
    let dl = b.x - m.x, dr = (b.x + b.w) - (m.x + m.w)
    if dl == 0 && dr == 0 { return dzcNo(f, "dzc.alreadyAligned") }
    if dl != 0 {
        guard i > 0, row[i - 1].w + dl >= dzcLowW(row[i - 1]) || dzcGives(row[i - 1]) && row[i - 1].w + dl >= 0 else { return dzcNo(f, "dzc.noAlign") }
        row[i - 1].w += dl
    }
    if dr != 0 {
        if i + 1 < row.count {
            guard row[i + 1].w - dr >= dzcLowW(row[i + 1]) || dzcGives(row[i + 1]) && row[i + 1].w - dr >= 0 else { return dzcNo(f, "dzc.noAlign") }
            row[i + 1].w -= dr
        }
    }
    row[i].w = b.w
    var r = DzcResult(f: dzcWithRow(f, key, dzcTidy(row, ws)))
    r.w0 = m.w; r.w1 = b.w
    return r
}

/* ---------------- the catalogue ---------------- */

/// A catalogue tile: its category, the library kind (Kitchen.swift template; "corner" a blind corner unit, "openLow" an
/// open lower unit), its width, its row, and an appliance's fixed width.
struct DzcTile: Hashable {
    let cat: String
    let kind: String
    let w: Int
    let upper: Bool
    let fixed: Bool
}

let DZC_CATS = ["door", "drawer", "tech", "corner", "tall", "open", "wall", "filler"]

let DZC_TILES: [DzcTile] = {
    var out: [DzcTile] = []
    func t(_ cat: String, _ kind: String, _ ws: [Int], up: Bool = false, fixed: Bool = false) {
        for w in ws { out.append(DzcTile(cat: cat, kind: kind, w: w, upper: up, fixed: fixed)) }
    }
    t("door", "base", [300, 400, 450, 500, 600, 800, 900])
    t("drawer", "drawers", [400, 450, 600, 800])
    t("tech", "sink", [600, 800])
    t("tech", "hob", [600], fixed: true)
    t("tech", "dishwasher", [450, 600], fixed: true)
    t("tech", "fridge", [600], fixed: true)
    t("tech", "oven", [600], fixed: true)
    t("tech", "fridgeB", [600], fixed: true)
    t("tech", "hood", [600, 900], up: true, fixed: true)
    t("tech", "micro", [600], up: true)
    t("corner", "corner", [600, 900])
    t("tall", "pantry", [400, 450, 600])
    t("open", "openLow", [300, 600])
    t("open", "open", [300, 600], up: true)
    t("open", "vitrina", [600, 800], up: true)
    t("wall", "wall", [300, 400, 450, 500, 600, 800, 900], up: true)
    t("filler", "fillerLow", [50, 100])
    t("filler", "fillerUp", [50, 100], up: true)
    return out
}()

/// The unit a tile makes, w wide, on wall.
func dzcTileModule(_ t: DzcTile, _ w: Int, _ ws: Workshop, _ wall: String) -> Module {
    switch t.kind {
    case "corner":
        var b = template("base", ws, wall, w)
        b.fronts = Fronts("panel", 1); b.inserts = [Insert("shelf", qty: 1)]
        return b
    case "openLow":
        var b = template("base", ws, wall, w)
        b.fronts = Fronts("open", 0); b.inserts = [Insert("shelf", qty: 2)]
        return b
    default:
        return template(t.kind, ws, wall, w)
    }
}

/// Where a tile would go and how: the new row, the new unit's id, into a space (its id) or between two units.
struct DzcPlan {
    var ok = true
    var row: [Module] = []
    var id = ""
    var why = ""
    var vars: [String: Int] = [:]
    var space: String? = nil
    var w = 0
    var adapted = false
}

private func dzcPlanNo(_ why: String, _ vars: [String: Int]) -> DzcPlan {
    var p = DzcPlan()
    p.ok = false; p.why = why; p.vars = vars
    return p
}

/// Tile t into empty space gi of row (at its right half when right): the space gets narrower (under 100 mm left: a
/// filler); a tile wider than the space takes the biggest snap that fits, unless it is an appliance.
func dzcPlanInto(_ row: [Module], _ gi: Int, _ t: DzcTile, ws: Workshop, right: Bool) -> DzcPlan {
    var L = row
    let g = L[gi]
    var nw = t.w, adapted = false
    if g.w < nw {
        let fit = dzcLargestSnap(g.w)
        if t.fixed || fit < DZC_MIN_W { return dzcPlanNo("dzc.spaceSmall", ["g": g.w, "n": t.w]) }
        nw = fit; adapted = true
    }
    let nm = dzcTileModule(t, nw, ws, g.wall ?? "")
    let rem = g.w - nw
    if rem == 0 {
        L[gi] = nm
    } else {
        if rem < 100 {
            var fl = dzcFillerLike(g, rem, ws)
            fl.id = g.id
            L[gi] = fl
        } else {
            L[gi].w = rem
        }
        L.insert(nm, at: right ? gi + 1 : gi)
    }
    var p = DzcPlan()
    p.row = dzcTidy(L, ws); p.id = nm.id; p.space = g.id; p.w = nw; p.adapted = adapted
    return p
}

/// Tile t dropped at u mm along the run (the row starting at start): into the empty space there, else between the two
/// units nearest u, the room taken from the free end, the spaces, the fillers.
func dzcPlanAt(_ row: [Module], _ t: DzcTile, u: Int, start: Int, avail: Int?, ws: Workshop, wall: String) -> DzcPlan {
    var x = start
    for (i, m) in row.enumerated() {
        if dzcSpace(m) && u >= x && u <= x + m.w { return dzcPlanInto(row, i, t, ws: ws, right: u - x > m.w / 2) }
        x += m.w
    }
    let hi = dzcMoveHi(row)
    var best = 0, bd = Int.max, acc = start
    for j in 0...hi {
        if abs(acc - u) < bd { bd = abs(acc - u); best = j }
        if j < row.count { acc += row[j].w }
    }
    return dzcPlanBetween(row, t, at: best, avail: avail, ws: ws, wall: wall)
}

/// Tile t in at place `at` of row: the room from the free end, the spaces, the fillers; a tile that does not fit takes
/// the biggest snap that does, unless it is an appliance.
func dzcPlanBetween(_ row: [Module], _ t: DzcTile, at: Int, avail: Int?, ws: Workshop, wall: String) -> DzcPlan {
    var need = t.w, adapted = false
    if let free = dzcFree(row, avail: avail), free < need {
        let fit = dzcLargestSnap(free)
        if t.fixed || fit < DZC_MIN_W { return dzcPlanNo("dzc.noRoom", ["f": free, "n": t.w]) }
        need = fit; adapted = true
    }
    var L = row
    let nm = dzcTileModule(t, need, ws, wall)
    L.insert(nm, at: min(max(at, 0), L.count))
    guard let took = dzcTakeRoom(L, at: min(max(at, 0), L.count - 1), need: need, avail: avail) else {
        return dzcPlanNo("dzc.noRoom", ["f": dzcFree(row, avail: avail) ?? 0, "n": t.w])
    }
    var p = DzcPlan()
    p.row = dzcTidy(took, ws); p.id = nm.id; p.w = need; p.adapted = adapted
    return p
}

/// A tapped tile: the selected empty space when it is of the tile's row, else the first space it fits of the current
/// wall, then of the others, then the current wall's free end. nil (with why) when it fits nowhere.
func dzcTapPlan(_ f: Furniture, _ runs: [Run], cur: String, sel: String?, _ t: DzcTile, ws: Workshop) -> (wall: String, plan: DzcPlan) {
    let order = [cur] + runs.map(\.wall).filter { $0 != cur }
    func avail(_ w: String) -> Int? { runs.first { $0.wall == w }.flatMap { r in fillOf(f, r, t.upper).avail } }
    if t.upper && cur == ISLAND && runs.count == 1 { return (cur, dzcPlanNo("dzc.noUp", [:])) }
    if let sel, let s = f.modules.first(where: { $0.id == sel }), dzcSpace(s), isUpper(s) == t.upper {
        let row = dzcRowMods(f, DzcRow(wall: s.wall ?? "", upper: t.upper))
        if let i = row.firstIndex(where: { $0.id == sel }) {
            let p = dzcPlanInto(row, i, t, ws: ws, right: false)
            return (s.wall ?? cur, p)
        }
    }
    for w in order where !(t.upper && w == ISLAND) {
        let row = dzcRowMods(f, DzcRow(wall: w, upper: t.upper))
        for (i, m) in row.enumerated() where dzcSpace(m) && m.w >= min(t.fixed ? t.w : DZC_MIN_W, t.w) {
            let p = dzcPlanInto(row, i, t, ws: ws, right: false)
            if p.ok { return (w, p) }
        }
    }
    let row = dzcRowMods(f, DzcRow(wall: cur, upper: t.upper))
    let a = avail(cur)
    if let tail = dzcTail(row, a), tail >= DZC_MIN_W || tail >= t.w {
        let p = dzcPlanBetween(row, t, at: dzcMoveHi(row), avail: a, ws: ws, wall: cur)
        if p.ok { return (cur, p) }
    } else if a == nil {
        return (cur, dzcPlanBetween(row, t, at: dzcMoveHi(row), avail: nil, ws: ws, wall: cur))
    }
    return (cur, dzcPlanNo("dzc.noSpace", ["n": t.w]))
}

/* ---------------- a kitchen unit's type, fronts, depth, base ---------------- */

/// The types Designer C's "Turi" offers: a lower unit's, an upper one's.
let DZC_TYPES_LOW = ["door1", "door2", "drawer2", "drawer3", "drawer4", "openLow", "sink", "hob", "dishwasher"]
let DZC_TYPES_UP = ["wdoor1", "wdoor2", "vitrina", "open", "micro", "hood"]

/// Unit m's type key for "Turi".
func dzcTypeOf(_ m: Module) -> String {
    if isUpper(m) {
        if m.app == "hood" { return "hood" }
        if m.app == "micro" { return "micro" }
        if glassDoors(m) { return "vitrina" }
        if m.fronts.kind == "open" { return "open" }
        return m.fronts.n >= 2 ? "wdoor2" : "wdoor1"
    }
    if m.app == "sink" { return "sink" }
    if m.app == "hob" { return "hob" }
    if m.app == "dishwasher" { return "dishwasher" }
    if m.fronts.kind == "drawer" { return "drawer\(m.fronts.n)" }
    if m.fronts.kind == "open" { return "openLow" }
    return m.fronts.n >= 2 ? "door2" : "door1"
}

/// Unit m as type key: its id, width, row, depth and choices (own board, soft close, hinge) kept; nil when its width
/// does not suit the type (an appliance's widths).
func dzcRetype(_ m: Module, _ key: String, ws: Workshop) -> Module? {
    let wall = m.wall ?? ""
    var n: Module
    switch key {
    case "door1", "door2": n = template("base", ws, wall, m.w); n.fronts = Fronts("door", key == "door2" ? 2 : 1)
    case "drawer2", "drawer3", "drawer4": n = template("drawers", ws, wall, m.w); n.fronts = Fronts("drawer", Int(key.dropFirst(6)) ?? 3)
    case "openLow": n = template("base", ws, wall, m.w); n.fronts = Fronts("open", 0); n.inserts = [Insert("shelf", qty: 2)]
    case "sink", "hob": n = template(key, ws, wall, m.w)
    case "dishwasher":
        if ![450, 600].contains(m.w) { return nil }
        n = template("dishwasher", ws, wall, m.w)
    case "wdoor1", "wdoor2": n = template("wall", ws, wall, m.w); n.fronts = Fronts("door", key == "wdoor2" ? 2 : 1)
    case "vitrina", "open": n = template(key, ws, wall, m.w)
    case "micro":
        if ![500, 600].contains(m.w) { return nil }
        n = template("micro", ws, wall, m.w)
    case "hood":
        if ![600, 900].contains(m.w) { return nil }
        n = template("hood", ws, wall, m.w)
    default: return nil
    }
    n.id = m.id
    // the row's height and legs stay (a kitchen's own legs; a wall unit's height and place)
    if n.type == m.type && n.app != "hood" && m.app != "hood" { n.elev = m.elev; n.h = m.h; n.d = m.d }
    else if !isUpper(n) && !isUpper(m) && n.type != "gap" && m.type != "gap" { n.elev = m.elev; n.d = m.d }
    n.soft = m.soft; n.handles = m.handles; n.front = m.front
    n.hinges = n.fronts == m.fronts ? m.hinges : []
    n.noHandle = m.noHandle
    return frontsChanged(m, n)
}

/// m with q shelves (glass ones behind glass doors), its other inserts kept.
func dzcShelves(_ m: Module, _ q: Int) -> Module {
    var n = m
    let kind = glassDoors(m) ? "glass" : "shelf"
    n.inserts = m.inserts.filter { $0.kind != "shelf" && $0.kind != "glass" } + (q > 0 ? [Insert(kind, qty: q)] : [])
    return n
}

func dzcShelfCount(_ m: Module) -> Int { m.inserts.filter { $0.kind == "shelf" || $0.kind == "glass" }.reduce(0) { $0 + $1.qty } }

/// m with n drawers (2–5).
func dzcDrawers(_ m: Module, _ n: Int) -> Module {
    var x = m
    x.fronts = Fronts("drawer", min(5, max(2, n)))
    return frontsChanged(m, x)
}

/// The depths "Chuqurlik" offers: a lower unit's, an upper one's.
let DZC_DEPTH_LOW = [300, 450, 560, 600]
let DZC_DEPTH_UP = [280, 300, 320, 350]

/// The fronts' board of units ids (Designer C "Fasad · Faqat shu"); the piece's own board clears the unit's.
func dzcFrontOne(_ f: Furniture, _ ids: Set<String>, _ board: String) -> Furniture {
    var g = f
    g.modules = f.modules.map { m in
        guard ids.contains(m.id) else { return m }
        var n = m
        n.front = nil
        n.front = frontOf(f, n) == board ? nil : board
        return n
    }
    return g
}

/// The fronts' board of a whole row (Designer C "Shu qatorga"): a kitchen's upper fronts (frontUp) or its lower ones,
/// the other row keeping its board; the units of that row lose their own.
func dzcFrontRow(_ f: Furniture, upper: Bool, _ board: String) -> Furniture {
    var g = f
    if upper {
        g.mats.frontUp = board == f.mats.front ? nil : board
    } else {
        if f.mats.frontUp == nil { g.mats.frontUp = f.mats.front }
        g.mats.front = board
        if g.mats.frontUp == board { g.mats.frontUp = nil }
    }
    g.modules = f.modules.map { m in
        guard f.kind != "kitchen" || isUpper(m) == upper else { return m }
        var n = m; n.front = nil; return n
    }
    return g
}

/// The fronts' board of the whole piece (Designer C "Butun oshxonaga" / "Hammasiga"): one board, no unit its own.
func dzcFrontAll(_ f: Furniture, _ board: String) -> Furniture {
    var g = f
    g.mats.front = board
    g.mats.frontUp = nil
    g.modules = f.modules.map { m in var n = m; n.front = nil; return n }
    return g
}

/// A kitchen's base (Designer C "Tsokol/oyoq", one for the whole kitchen): "plinth" a plinth over the legs, "legs"
/// adjustable legs without one, "metal" visible metal legs; h the legs' height, every unit on them moving with it.
func dzcKitchenBase(_ f: Furniture, _ kind: String, _ h: Int, ws: Workshop) -> Furniture {
    let now = wsOf(f, ws).legH
    let dy = h - now
    var g = withLook(f) { l in var n = l; n.legs = kind == "metal"; return n }
    var kx = g.kx ?? KExtras()
    kx.plinth = kind == "plinth"
    g.kx = kx
    g.baseH = h
    if dy != 0 {
        g.modules = g.modules.map { m in
            if m.app == "fridge" || m.elev == 0 { return m }
            var n = m; n.elev += dy; return n
        }
    }
    return g
}

/// The kitchen's base kind: "plinth", "legs" or "metal".
func dzcKitchenBaseKind(_ f: Furniture) -> String {
    if metalLegs(f) { return "metal" }
    return f.kx?.plinth == true ? "plinth" : "legs"
}

/// The legs' heights "Tsokol/oyoq" steps through.
let DZC_BASE_H = [80, 100, 120, 150]

/* ---------------- checks with a fix ---------------- */

/// What "Tuzatish" does for check c of kitchen f: a unit over a window or a door narrower up to it (or a space when
/// that leaves less than 150), one over a tall unit a space, a hood raised to its height, a row too long shortened by
/// its fillers and spaces, a row's free end closed with a filler or a space. nil: no fix.
func dzcFix(_ f: Furniture, _ c: FCheck, _ runs: [Run], _ openings: [Opening], ws: Workshop) -> DzcResult? {
    let kws = wsOf(f, ws)
    func avail(_ m: Module) -> Int? { runs.first { $0.wall == m.wall }.flatMap { fillOf(f, $0, isUpper(m)).avail } }
    switch c.key {
    case "kc.window", "kc.door":
        guard let id = c.mid, let m = f.modules.first(where: { $0.id == id }) else { return nil }
        let o = openings.first { $0.wall == m.wall && $0.off < m.x + m.w && $0.off + $0.w > m.x && $0.sill < m.elev + m.h && $0.sill + $0.h > m.elev }
        if let o, o.off > m.x {
            let fit = (o.off - m.x) / 10 * 10
            if fit >= DZC_MIN_W {
                let r = dzcResize(f, id, fit, avail: avail(m), ws: kws)
                if r.ok { return r }
            }
        }
        return dzcDelete(f, id, ws: kws)
    case "kc.tallUp":
        guard let id = c.mid else { return nil }
        return dzcDelete(f, id, ws: kws)
    case "kc.hood":
        guard let id = c.mid, let m = f.modules.first(where: { $0.id == id }), let need = c.vars["n"]?.base as? Int else { return nil }
        let top = m.elev + m.h
        let e = worktopTop(kws) + need
        if top - e < 200 { return nil }
        var g = f
        g.modules = f.modules.map { x in
            guard x.id == id else { return x }
            var n = x; n.elev = e; n.h = top - e; return n
        }
        return DzcResult(f: g)
    case "kc.over", "kc.overUp":
        guard let w = c.vars["w"]?.base as? String, let over = c.vars["v"]?.base as? Int else { return nil }
        let key = DzcRow(wall: w, upper: c.key == "kc.overUp")
        var row = dzcRowMods(f, key)
        var rem = over
        for j in row.indices.reversed() where rem > 0 && dzcGives(row[j]) {
            let tk = min(row[j].w, rem)
            row[j].w -= tk; rem -= tk
        }
        if rem > 0 { return nil }
        return DzcResult(f: dzcWithRow(f, key, dzcTidy(row, kws)))
    case "kc.gap":
        guard let w = c.vars["w"]?.base as? String, let left = c.vars["v"]?.base as? Int, left > 0 else { return nil }
        let key = DzcRow(wall: w, upper: false)
        var row = dzcRowMods(f, key)
        guard let any = row.first else { return nil }
        let hi = dzcMoveHi(row)
        let n = left < DZC_GAP_FROM ? dzcFillerLike(any, left, kws) : dzcSpaceLike(Module(id: uid(), type: "base", w: left, h: K_BASE_H, d: K_BASE_D, wall: w, elev: kws.legH), left, kws)
        row.insert(n, at: hi)
        var r = DzcResult(f: dzcWithRow(f, key, dzcTidy(row, kws)))
        r.newId = n.id
        return r
    default:
        return nil
    }
}

/* ---------------- a wardrobe's sections ---------------- */

/// The widest section i of m can get: its neighbour (the right one, the last section's left one) down to DZC_SEC_MIN.
func dzcSecMax(_ m: Module, _ i: Int) -> Int {
    let n = m.sections.count
    guard n > 1, i >= 0, i < n else { return m.w }
    let side = [i + 1, i - 1].filter { $0 >= 0 && $0 < n }.map { m.sections[$0].w }.max() ?? DZC_SEC_MIN
    return m.sections[i].w + side - DZC_SEC_MIN
}

/// Which section takes the difference d when section i's right edge moves: the one on its right, and only when it
/// cannot (it would get narrower than DZC_SEC_MIN, or there is none) the one on its left; nil: neither can.
func dzcSecTaker(_ m: Module, _ i: Int, _ d: Int) -> Int? {
    let n = m.sections.count
    for j in [i + 1, i - 1] where j >= 0 && j < n && m.sections[j].w - d >= DZC_SEC_MIN { return j }
    return nil
}

/// Section i of m nw wide (Designer C: its right edge dragged, or "Kenglik"): the neighbour dzcSecTaker says takes the
/// difference (the right one first); both keep their widths from then on (locked).
func dzcSecResize(_ m: Module, _ i: Int, _ nw: Int) -> (m: Module, ok: Bool, taker: Int, w1: Int) {
    let n = m.sections.count
    guard n > 1, i >= 0, i < n else { return (m, false, -1, 0) }
    let j0 = i + 1 < n ? i + 1 : i - 1
    let d = nw - m.sections[i].w
    if d == 0 { return (m, true, j0, m.sections[j0].w) }
    guard nw >= DZC_SEC_MIN, let j = dzcSecTaker(m, i, d) else { return (m, false, j0, m.sections[j0].w) }
    var out = m
    out.sections[i].w = nw; out.sections[i].lock = true
    out.sections[j].w -= d; out.sections[j].lock = true
    return (out, true, j, out.sections[j].w)
}

/// A copy of section i to its right (Designer C "Nusxa"): the sections then share the width equally (at most 8).
func dzcSecCopy(_ m: Module, _ i: Int) -> Module? {
    guard i >= 0, i < m.sections.count, m.sections.count < 8 else { return nil }
    var secs = m.sections
    secs.insert(secs[i], at: i + 1)
    secs = secs.map { var s = $0; s.lock = false; return s }
    let out = splitSections(m.w, secs)
    if out.contains(where: { $0.w < DZC_SEC_MIN }) { return nil }
    var n = m
    n.sections = out
    return n
}

/// Section i deleted: its neighbour (the left one, the first section's right one) takes its width; the last section stays.
func dzcSecDelete(_ m: Module, _ i: Int) -> Module? {
    let n = m.sections.count
    guard n > 1, i >= 0, i < n else { return nil }
    let j = i > 0 ? i - 1 : 1
    var out = m
    out.sections[j].w += m.sections[i].w
    out.sections.remove(at: i)
    return out
}

/// Section i moved to place `to` (its width and inside with it).
func dzcSecMove(_ m: Module, _ i: Int, to: Int) -> Module {
    guard i >= 0, i < m.sections.count else { return m }
    var secs = m.sections
    let s = secs.remove(at: i)
    secs.insert(s, at: min(max(to, 0), secs.count))
    var out = m
    out.sections = secs
    return out
}

/// Where a section lifted with its left edge at gx (mm from the box's left) drops.
func dzcSecSlot(_ m: Module, _ i: Int, gx: Int) -> Int {
    guard i >= 0, i < m.sections.count else { return 0 }
    var rest = m.sections
    let s = rest.remove(at: i)
    let c = gx + s.w / 2
    var best = 0, bd = Int.max, acc = 0
    for j in 0...rest.count {
        let cen = acc + s.w / 2
        if abs(cen - c) < bd { bd = abs(cen - c); best = j }
        if j < rest.count { acc += rest[j].w }
    }
    return best
}

/// m with n sections, as the sizes step's stepper does: new ones with five shelves and doors, the old ones as they were.
func dzcSecCount(_ m: Module, _ n: Int, _ ws: Workshop) -> Module {
    let cnt = min(8, max(1, n))
    if cnt == m.sections.count { return m }
    let ih = wardInnerH(m, ws.t)
    var secs = cnt > m.sections.count
        ? m.sections + (0..<(cnt - m.sections.count)).map { _ in spreadShelves(Section(0, inserts: Array(repeating: Insert("shelf"), count: 5)), ih, ws.t) }
        : Array(m.sections.prefix(cnt))
    secs = secs.map { var s = $0; s.lock = false; return s }
    var out = m
    out.sections = splitSections(m.w, secs).enumerated().map { i, s in
        if i < m.sections.count { return s }
        var x = s; x.fronts = Fronts("door", s.w >= 600 ? 2 : 1); return x
    }
    return out
}

/// A section's type key for "Turi": "d2", "d1", "open", "mirror", "glass".
func dzcSecType(_ s: Section) -> String {
    if s.fronts.kind == "open" { return "open" }
    if s.face == "mirror" { return "mirror" }
    if s.face == "glass" { return "glass" }
    return s.fronts.n >= 2 ? "d2" : "d1"
}

/// Section s as type key: two doors, one door, open, a mirror on its doors, glass doors.
func dzcSecRetype(_ s: Section, _ key: String) -> Section {
    var n = s
    switch key {
    case "d2": n.fronts = Fronts("door", 2); n.face = ""
    case "d1": n.fronts = Fronts("door", 1); n.face = ""
    case "open": n.fronts = Fronts("open", 0); n.face = ""
    case "mirror", "glass":
        if n.fronts.kind != "door" { n.fronts = Fronts("door", s.w >= 600 ? 2 : 1) }
        n.face = key
    default: break
    }
    return frontsChanged(s, n)
}

/// A wardrobe's base (Designer C "Tsokol/oyoq"): "plinth" or "legs", h its height; the whole height stays.
func dzcWardBase(_ m: Module, _ kind: String, _ h: Int, _ ws: Workshop) -> Module {
    let whole = outerH(m, ws)
    var n = m
    n.legs = kind == "legs"
    n.base = h
    n.h = max(300, whole - (n.legs ? h : 0))
    return n
}
