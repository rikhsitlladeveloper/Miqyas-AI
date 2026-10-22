import Foundation

/*
 * The windows-and-doors app (Deraza-eshik, 22 Oct 2026, built like the plumber's; Android win/Win.kt): products picked
 * from a gallery by group (windows, balcony, doors) fill the measured openings of a room (their size the opening's less
 * the fitting gap each side) or stand without a room at a typed size. A window is split into sashes (tabaqa) by vertical
 * and horizontal mullions (impost); each sash is fixed, turns, tilts, tilts and turns, slides or is an opaque panel; the
 * profile is PVC or aluminium with its chambers, the glass unit one- or two-chamber, the colour inside and out; the
 * extras are the sill (podokonnik), the drip (otliv), the reveals (otkos), the mosquito net and the handles. A door is
 * its type, its size, its hinge side and which way it opens. Rules warn; the advanced app prices it from its parts.
 * Lengths are mm. Pure Swift, unit-tested (WinTests): sashes and parts in WinGeo.swift, rooms and placing in
 * WinPlace.swift, warnings in WinWarn.swift, counting and the estimate in WinCount.swift, 3D in WinMesh.swift.
 */

/// One sash of a window column: h its height between the transoms' axes (rows from the top), how it opens t (one of
/// W_SASH_TYPES) and its hinge side hinge as seen from inside ("L" or "R"; a sliding sash: the way it slides open).
struct WCell: Codable, Hashable {
    var h: Int
    var t = "fix"
    var hinge = "L"
}

extension WCell {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        h = c.v(.h, 1000); t = c.v(.t, "fix"); hinge = c.v(.hinge, "L")
    }
}

/// A column of a window between the mullions' axes: w wide, its sashes from the top.
struct WCol: Codable, Hashable {
    var w: Int
    var rows: [WCell]
}

extension WCol {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        w = c.v(.w, 1000); rows = c.v(.rows, [])
    }
}

/// A window or door: kind its gallery type (W_KINDS); in room roomId filling opening opening (both nil: without a room,
/// qty alike, named name, in a wall freeT thick); w × h its size; gap the fitting gap each side (a door opening has
/// none at the floor); cols a window's sashes. The profile (pvc, alu) with chambers, the glass unit's chambers glass
/// (1, 2), the colour or laminate inside colIn and outside colOut. Extras: the sill mm deep (0: none), the drip, the
/// reveals, mosquito nets, handles. A door: hinge side seen from inside, opens swing "in" (into this room) or "out"; a
/// sliding one slides towards hinge. fit: its size follows its opening.
struct WinItem: Codable, Hashable, Identifiable {
    var id: String
    var kind: String
    var roomId: String? = nil
    var opening: String? = nil
    var w: Int
    var h: Int
    var gap = W_GAP
    var cols: [WCol] = []
    var profile = "pvc"
    var chambers = 5
    var glass = 2
    var colIn = "white"
    var colOut = "white"
    var sill = 0
    var drip = false
    var reveals = false
    var net = false
    var handles = true
    var hinge = "L"
    var swing = "in"
    var name = ""
    var qty = 1
    var freeT = W_FREE_T
    /// In a room: the size follows the opening (less the gap); false once a size is typed by hand.
    var fit = true

    var isDoor: Bool { W_DOOR_KINDS.contains(kind) }
    var inRoom: Bool { roomId != nil && opening != nil }
}

extension WinItem {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = c.v(.kind, "w1"); roomId = c.v(.roomId, nil); opening = c.v(.opening, nil)
        w = c.v(.w, 1000); h = c.v(.h, 1000); gap = c.v(.gap, W_GAP); cols = c.v(.cols, [])
        profile = c.v(.profile, "pvc"); chambers = c.v(.chambers, 5); glass = c.v(.glass, 2)
        colIn = c.v(.colIn, "white"); colOut = c.v(.colOut, "white")
        sill = c.v(.sill, 0); drip = c.v(.drip, false); reveals = c.v(.reveals, false); net = c.v(.net, false); handles = c.v(.handles, true)
        hinge = c.v(.hinge, "L"); swing = c.v(.swing, "in"); name = c.v(.name, ""); qty = c.v(.qty, 1)
        freeT = c.v(.freeT, W_FREE_T); fit = c.v(.fit, true)
    }
}

/// A windows-and-doors order: its products, and the fitting gap new ones get.
struct WinOrder: Codable, Equatable {
    var items: [WinItem] = []
    var gap = W_GAP

    var empty: Bool { items.isEmpty }
    func item(_ id: String) -> WinItem? { items.first { $0.id == id } }
}

extension WinOrder {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        items = c.v(.items, []); gap = c.v(.gap, W_GAP)
    }
}

/// The fitting gap round a product in its opening, each side, mm (15–20 is usual); the range a maker can type.
let W_GAP = 20
let W_GAP_MIN = 0
let W_GAP_MAX = 60
/// A wall's thickness for a product without a room, mm.
let W_FREE_T = 300
/// The sill's ears into the side reveals and the drip's, each side; the sill's usual overhang past the wall's face; the
/// most it may stick out.
let W_SILL_EAR = 50
let W_DRIP_EAR = 25
let W_SILL_OVER = 50
let W_SILL_OVER_MAX = 100
/// A door's frame (korobka) seen from the front, mm; its depth.
let W_DOOR_FRAME = 40
let W_DOOR_DEPTH = 100
/// A sash at least this high counts as a door's (a balcony door, a panoramic one): its own limits.
let W_DOOR_SASH_H = 1800

let W_SASH_TYPES = ["fix", "turn", "tilt", "tt", "slide", "panel"]
/// Sash types that open (a handle, hardware, a net).
let W_OPENS: Set<String> = ["turn", "tilt", "tt", "slide"]
/// Sash types that swing into the room as they turn.
let W_SWINGS: Set<String> = ["turn", "tt"]
let W_PROFILES = ["pvc", "alu"]
/// Chamber counts a profile comes in: PVC 3, 5, 6, 7; aluminium 1 (cold) or 3 (warm, with a thermal break).
func wChambersOf(_ profile: String) -> [Int] { profile == "alu" ? [1, 3] : [3, 5, 6, 7] }
let W_GLASSES = [1, 2]
/// Colours and laminates: white, cream, golden oak, walnut, mahogany, anthracite, silver.
let W_COLOURS = ["white", "cream", "goak", "walnut", "mahog", "anthr", "silver"]
func wColourRgb(_ c: String) -> Int {
    switch c {
    case "cream": return 0xEFE6D2
    case "goak": return 0xB7813F
    case "walnut": return 0x6E4B30
    case "mahog": return 0x7B3A2B
    case "anthr": return 0x3D434B
    case "silver": return 0xB9C0C8
    default: return 0xF4F5F2
    }
}
let W_DOOR_KINDS: Set<String> = ["dint", "dent", "dsl", "dgl"]

/// A frame's face seen from inside, mm: PVC 60, aluminium 50.
func wFrameF(_ profile: String) -> Int { profile == "alu" ? 50 : 60 }
/// A mullion's face, mm: PVC 80, aluminium 70.
func wMullF(_ profile: String) -> Int { profile == "alu" ? 70 : 80 }
/// An opening sash's own profile inside its cell, mm: PVC 75, aluminium 60.
func wSashF(_ profile: String) -> Int { profile == "alu" ? 60 : 75 }
/// How deep the frame is (into the wall), mm: PVC by its chambers, aluminium cold or warm.
func wFrameDepth(_ it: WinItem) -> Int {
    if it.isDoor { return W_DOOR_DEPTH }
    if it.profile == "alu" { return it.chambers >= 3 ? 65 : 50 }
    switch it.chambers {
    case 3: return 58
    case 6: return 76
    case 7: return 82
    default: return 70
    }
}

/// The inside reveal's depth, mm: the frame stands in the middle of a wall t thick.
func wRevealOf(_ t: Int, _ depth: Int) -> Int { max(0, (t - depth) / 2) }

/// The usual sill depth for a reveal r deep: past the wall's face by W_SILL_OVER, in whole 50 mm.
func wSillFor(_ r: Int) -> Int { max(150, ((r + W_SILL_OVER + 49) / 50) * 50) }

/// A gallery type: group win, balc or door; w × h its usual size; cols its sashes at that size; profile its usual
/// profile; col a door's usual colour.
struct WinKind {
    let id: String
    let group: String
    let w: Int
    let h: Int
    var cols: [WCol] = []
    var profile = "pvc"
    var col = "white"
    var isDoor: Bool { W_DOOR_KINDS.contains(id) }
}

private func wOne(_ w: Int, _ h: Int, _ t: String, _ hinge: String = "L") -> WCol { WCol(w: w, rows: [WCell(h: h, t: t, hinge: hinge)]) }

private func wMakeKinds() -> [WinKind] {
    var out: [WinKind] = []
    out.append(WinKind(id: "w1", group: "win", w: 700, h: 1400, cols: [wOne(700, 1400, "tt", "L")]))
    out.append(WinKind(id: "w2", group: "win", w: 1300, h: 1400, cols: [wOne(650, 1400, "fix"), wOne(650, 1400, "tt", "R")]))
    out.append(WinKind(id: "w3", group: "win", w: 2000, h: 1400, cols: [wOne(650, 1400, "turn", "L"), wOne(700, 1400, "fix"), wOne(650, 1400, "tt", "R")]))
    let fixA = WCol(w: 700, rows: [WCell(h: 450), WCell(h: 1350, t: "tt", hinge: "L")])
    let fixB = WCol(w: 700, rows: [WCell(h: 450), WCell(h: 1350)])
    out.append(WinKind(id: "wfix", group: "win", w: 1400, h: 1800, cols: [fixA, fixB]))
    out.append(WinKind(id: "wtt", group: "win", w: 1400, h: 1400, cols: [wOne(700, 1400, "tt", "L"), wOne(700, 1400, "tt", "R")]))
    out.append(WinKind(id: "wsl", group: "win", w: 1800, h: 1400, cols: [wOne(900, 1400, "slide", "R"), wOne(900, 1400, "slide", "L")], profile: "alu", col: "silver"))
    out.append(WinKind(id: "pano", group: "win", w: 2400, h: 2400, cols: [wOne(800, 2400, "fix"), wOne(800, 2400, "tt", "L"), wOne(800, 2400, "fix")]))
    let balcB = WCol(w: 1200, rows: [WCell(h: 1250), WCell(h: 850, t: "panel")])
    out.append(WinKind(id: "balc", group: "balc", w: 1950, h: 2100, cols: [wOne(750, 2100, "tt", "L"), balcB]))
    let glz: [WCol] = [wOne(750, 1400, "slide", "R"), wOne(750, 1400, "slide", "R"), wOne(750, 1400, "slide", "L"), wOne(750, 1400, "slide", "L")]
    out.append(WinKind(id: "bglz", group: "balc", w: 3000, h: 1400, cols: glz, profile: "alu", col: "silver"))
    out.append(WinKind(id: "dint", group: "door", w: 800, h: 2000, col: "walnut"))
    out.append(WinKind(id: "dent", group: "door", w: 900, h: 2050, col: "anthr"))
    out.append(WinKind(id: "dsl", group: "door", w: 800, h: 2000, col: "white"))
    out.append(WinKind(id: "dgl", group: "door", w: 800, h: 2000, col: "silver"))
    return out
}

let W_KINDS: [WinKind] = wMakeKinds()

/// The gallery's groups, in order.
let W_GROUPS = ["win", "balc", "door"]

func wkind(_ id: String) -> WinKind { W_KINDS.first { $0.id == id } ?? W_KINDS[0] }

/// Which openings a type fills: doors the doors, windows the windows, a balcony block either.
func wFillsType(_ kind: String, _ openingType: String) -> Bool {
    if W_DOOR_KINDS.contains(kind) { return openingType == "door" }
    if kind == "balc" { return true }
    return openingType == "window"
}

/// total mm shared out in proportion to weights, in whole 5 mm, the last taking what is left.
func wShare(_ total: Int, _ weights: [Int]) -> [Int] {
    if weights.isEmpty { return [] }
    let sum = max(weights.reduce(0, +), 1)
    var out: [Int] = []
    for x in weights.dropLast() {
        let part: Double = Double(x) * Double(total) / Double(sum)
        out.append(tInt(eMathRoundP(part / 5)) * 5)
    }
    out.append(total - out.reduce(0, +))
    return out
}

/// The sashes cols stretched to w × h, in proportion.
func wScaled(_ cols: [WCol], _ w: Int, _ h: Int) -> [WCol] {
    let ws = wShare(w, cols.map(\.w))
    var out: [WCol] = []
    for (i, c) in cols.enumerated() {
        let hs = wShare(h, c.rows.map(\.h))
        var rows: [WCell] = []
        for (j, r) in c.rows.enumerated() {
            var x = r
            x.h = hs[j]
            rows.append(x)
        }
        out.append(WCol(w: ws[i], rows: rows))
    }
    return out
}

/// A product's size for an opening ow × oh of type: less the gap each side; a door opening has none at the floor.
func wSizeFor(_ ow: Int, _ oh: Int, _ type: String, _ gap: Int) -> (Int, Int) {
    let hg = type == "door" ? gap : 2 * gap
    return (max(100, ow - 2 * gap), max(100, oh - hg))
}

/// A new product of type k sized w × h, with that type's usual sashes, profile and colours.
func wNewItem(_ id: String, _ k: WinKind, _ w0: Int? = nil, _ h0: Int? = nil, gap: Int = W_GAP, roomId: String? = nil, opening: String? = nil) -> WinItem {
    let w = w0 ?? k.w, h = h0 ?? k.h
    let col: String = k.isDoor ? k.col : (k.profile == "alu" ? "silver" : "white")
    let cols: [WCol] = k.isDoor ? [] : wScaled(k.cols, w, h)
    return WinItem(id: id, kind: k.id, roomId: roomId, opening: opening, w: w, h: h, gap: gap, cols: cols, profile: k.profile,
                   chambers: k.profile == "alu" ? 3 : 5, glass: 2, colIn: col, colOut: col, sill: 0, drip: !k.isDoor && roomId != nil, handles: true)
}

/// it refitted to an opening ow × oh of type with its own gap: the size, the sashes in proportion.
func wRefit(_ it: WinItem, _ ow: Int, _ oh: Int, _ type: String) -> WinItem {
    let s = wSizeFor(ow, oh, type, it.gap)
    return wResized(it, s.0, s.1)
}

/// it at a new size, its sashes in proportion.
func wResized(_ it: WinItem, _ w: Int, _ h: Int) -> WinItem {
    var x = it
    x.w = w; x.h = h
    if !it.cols.isEmpty { x.cols = wScaled(it.cols, w, h) }
    return x
}

/* ---------------- changing the sashes ---------------- */

/// Splits column ci in two halves (a new vertical mullion); the new half copies the sash.
func wSplitCol(_ it: WinItem, _ ci: Int) -> WinItem {
    guard ci >= 0, ci < it.cols.count else { return it }
    let c = it.cols[ci]
    let a = (c.w / 2 / 5) * 5
    var cs = it.cols
    var left = c
    left.w = a
    var right = c
    right.w = c.w - a
    right.rows = c.rows.map { r in
        var x = r
        x.hinge = r.hinge == "L" ? "R" : "L"
        return x
    }
    cs[ci] = left
    cs.insert(right, at: ci + 1)
    var out = it
    out.cols = cs
    return out
}

/// Splits sash ri of column ci in two (a new transom), the upper half fixed.
func wSplitRow(_ it: WinItem, _ ci: Int, _ ri: Int) -> WinItem {
    guard ci >= 0, ci < it.cols.count else { return it }
    let c = it.cols[ci]
    guard ri >= 0, ri < c.rows.count else { return it }
    let r = c.rows[ri]
    let top = (r.h / 2 / 5) * 5
    var rows = c.rows
    var low = r
    low.h = r.h - top
    rows[ri] = low
    rows.insert(WCell(h: top, t: "fix"), at: ri)
    var out = it
    out.cols[ci].rows = rows
    return out
}

/// Takes away the mullion beside sash ri of column ci: the transom over it (else under it), else the column's mullion
/// to its right (else left).
func wMergeAt(_ it: WinItem, _ ci: Int, _ ri: Int) -> WinItem {
    guard ci >= 0, ci < it.cols.count else { return it }
    let c = it.cols[ci]
    if c.rows.count > 1 {
        guard ri >= 0, ri < c.rows.count else { return it }
        let other = ri > 0 ? ri - 1 : ri + 1
        var keep = c.rows[ri]
        keep.h = c.rows[ri].h + c.rows[other].h
        var rows = c.rows
        let lo = min(ri, other)
        rows[lo] = keep
        rows.remove(at: lo + 1)
        var out = it
        out.cols[ci].rows = rows
        return out
    }
    if it.cols.count < 2 { return it }
    let other = ci < it.cols.count - 1 ? ci + 1 : ci - 1
    let lo = min(ci, other)
    var cs = it.cols
    var merged = c
    merged.w = c.w + it.cols[other].w
    cs[lo] = merged
    cs.remove(at: lo + 1)
    var out = it
    out.cols = cs
    return out
}

/// Moves the vertical mullion after column ci to x mm from the left (each column kept at least mn wide).
func wMoveMullion(_ it: WinItem, _ ci: Int, _ x: Int, _ mn: Int = 150) -> WinItem {
    if ci < 0 || ci >= it.cols.count - 1 { return it }
    let start = it.cols.prefix(ci).reduce(0) { $0 + $1.w }
    let pair = it.cols[ci].w + it.cols[ci + 1].w
    let a = min(max(x - start, mn), pair - mn)
    var out = it
    out.cols[ci].w = a
    out.cols[ci + 1].w = pair - a
    return out
}

/// Moves the transom under sash ri of column ci to y mm down from the top.
func wMoveTransom(_ it: WinItem, _ ci: Int, _ ri: Int, _ y: Int, _ mn: Int = 150) -> WinItem {
    guard ci >= 0, ci < it.cols.count else { return it }
    let c = it.cols[ci]
    if ri < 0 || ri >= c.rows.count - 1 { return it }
    let start = c.rows.prefix(ri).reduce(0) { $0 + $1.h }
    let pair = c.rows[ri].h + c.rows[ri + 1].h
    let a = min(max(y - start, mn), pair - mn)
    var out = it
    out.cols[ci].rows[ri].h = a
    out.cols[ci].rows[ri + 1].h = pair - a
    return out
}

/// Sets column ci's width to w, the next column (else the one before) taking the difference.
func wSetColW(_ it: WinItem, _ ci: Int, _ w: Int) -> WinItem {
    if it.cols.count < 2 || ci < 0 || ci >= it.cols.count { return it }
    if ci < it.cols.count - 1 {
        let start = it.cols.prefix(ci).reduce(0) { $0 + $1.w }
        return wMoveMullion(it, ci, start + w)
    }
    return wMoveMullion(it, ci - 1, it.w - w)
}

/// Sets sash ri's height in column ci to h, the sash under it (else over it) taking the difference.
func wSetRowH(_ it: WinItem, _ ci: Int, _ ri: Int, _ h: Int) -> WinItem {
    guard ci >= 0, ci < it.cols.count else { return it }
    let c = it.cols[ci]
    if c.rows.count < 2 || ri < 0 || ri >= c.rows.count { return it }
    if ri < c.rows.count - 1 {
        let start = c.rows.prefix(ri).reduce(0) { $0 + $1.h }
        return wMoveTransom(it, ci, ri, start + h)
    }
    let all = c.rows.reduce(0) { $0 + $1.h }
    return wMoveTransom(it, ci, ri - 1, all - h)
}

/// Changes sash ri of column ci.
func wSetCell(_ it: WinItem, _ ci: Int, _ ri: Int, _ f: (WCell) -> WCell) -> WinItem {
    guard ci >= 0, ci < it.cols.count, ri >= 0, ri < it.cols[ci].rows.count else { return it }
    var out = it
    out.cols[ci].rows[ri] = f(it.cols[ci].rows[ri])
    return out
}
