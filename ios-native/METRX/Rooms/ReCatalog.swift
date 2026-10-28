import Foundation

/*
 * What goes on a room's walls in the room-editor mockup v2 (approved 28 Oct 2026, design/room-editor/mockup.html IT,
 * GROUPS, STY, pkSteps, stepMeta, pkFieldErr, applyVals, magnet, freeSpot and issues; Android geo/RoomKit.kt): the 14
 * kinds (doors, windows and the points), each kind's styles with their standard sizes, the sizes asked one per step,
 * what is wrong with a typed size, the magnets, and the Tekshiruv rules. Pure Swift, unit-tested (RoomEditorTests).
 *
 * Kinds use the app's own type names: an Opening's "door" / "window", a SitePoint's t (the mockup's gasp is "gas",
 * gasm "meter", sock "socket", sw "switch"). Lengths are mm. A door's or window's position is its near edge from the
 * wall's start corner (Opening.off), a point's its centre (SitePoint.off); a point's height is to its centre.
 */

/// A kind you can put on a wall: its colour (0xRRGGBB), its 24 × 24 icon and the heights its chips offer (points).
struct ReKind: Equatable {
    let id: String
    let color: UInt32
    let icon: String
    var hs: [Int] = []
    var isOpening: Bool { id == "door" || id == "window" }
}

let RE_KINDS: [ReKind] = [
    ReKind(id: "door", color: 0x92400E, icon: "M6 3h12v18H6zM15 12h.01M3 21h18"),
    ReKind(id: "window", color: 0x0284C7, icon: "M4 4h16v13H4zM12 4v13M4 10.5h16M3 20.5h18"),
    ReKind(id: "cold", color: 0x0EA5E9, icon: "M12 3s6 6.5 6 11a6 6 0 0 1 -12 0c0-4.5 6-11 6-11z", hs: [500, 600, 800]),
    ReKind(id: "hot", color: 0xEF4444, icon: "M12 3s6 6.5 6 11a6 6 0 0 1 -12 0c0-4.5 6-11 6-11zM9.5 13c1-1 2-1 3 0s2 1 3 0M9.5 16c1-1 2-1 3 0s2 1 3 0", hs: [500, 600, 800]),
    ReKind(id: "sewer", color: 0x78716C, icon: "M4 12a8 8 0 1 0 16 0a8 8 0 1 0 -16 0M7 9.5h10M6 12h12M7 14.5h10", hs: [400, 100, 500]),
    ReKind(id: "gas", color: 0xF59E0B, icon: "M3 16h18M3 20h18M12 3c2 2.4 3.4 4.2 3.4 6.1a3.4 3.4 0 0 1 -6.8 0c0-1.2 .6-2.1 1.3-2.8 .1 1.1 .7 1.7 1.4 1.7 0-1.8 .3-3.2 .7-5z", hs: [1800, 2000, 2200]),
    ReKind(id: "meter", color: 0xD97706, icon: "M4 4h16v16H4zM8 11a4 4 0 1 0 8 0a4 4 0 1 0 -8 0M12 11l2-2M8 17h8", hs: [1600, 1400, 1800]),
    ReKind(id: "boiler", color: 0xEA580C, icon: "M7 2.5h10v19H7zM12 9c1.4 1.6 2.2 2.8 2.2 4a2.2 2.2 0 0 1 -4.4 0c0-.8 .4-1.4 .9-1.9 .1 .7 .5 1.1 .9 1.1 0-1.2 .2-2.1 .4-3.2zM9.5 18.5h5", hs: [1500, 1400, 1600]),
    ReKind(id: "socket", color: 0x6366F1, icon: "M4 4h16v16H4zM7.5 12a4.5 4.5 0 1 0 9 0a4.5 4.5 0 1 0 -9 0M10.3 12h.01M13.7 12h.01", hs: [300, 1100, 1800]),
    ReKind(id: "switch", color: 0x8B5CF6, icon: "M5 3.5h14v17H5zM9 7h6v10H9zM9 12h6", hs: [900, 1000, 1200]),
    ReKind(id: "rad", color: 0xE11D48, icon: "M5 5v14M9 5v14M13 5v14M17 5v14M3 8h18M3 16h18", hs: [600, 400]),
    ReKind(id: "ac", color: 0x06B6D4, icon: "M3 5h18v8H3zM6 10h12M8 16v3M12 16v4M16 16v3", hs: [2200, 2400, 2500]),
    ReKind(id: "vent", color: 0x64748B, icon: "M4 4h16v16H4zM7 12a5 5 0 1 0 10 0a5 5 0 1 0 -10 0M12 7v10M7 12h10", hs: [2300, 2100, 2500]),
    ReKind(id: "panel", color: 0xCA8A04, icon: "M5 3h14v18H5zM13 6.5l-3 5.5h4l-3 5.5", hs: [1700, 1500, 1800]),
]

/// The kind with this id (an unknown one reads as a socket's look).
func reKind(_ id: String) -> ReKind { RE_KINDS.first { $0.id == id } ?? RE_KINDS[8] }

/// The point kinds (not doors or windows).
let RE_POINTS = ["cold", "hot", "sewer", "gas", "meter", "boiler", "socket", "switch", "rad", "ac", "vent", "panel"]
let RE_ELEC = ["socket", "switch", "panel"]
let RE_WATER = ["cold", "hot", "sewer"]

/// The icon row's groups for a trade, in order: doors and windows, water and gas, electrics; an electrician sees the
/// electrics before the water and gas (mockup kindsOrder; the founder's default).
func reGroups(_ industry: String) -> [[String]] {
    let open = ["door", "window"], water = ["cold", "hot", "sewer", "gas", "meter", "boiler"], elec = ["socket", "switch", "rad", "ac", "vent", "panel"]
    return industry == "elec" ? [open, elec, water] : [open, water, elec]
}

/* ---------------- styles ---------------- */

/// A style's standard sizes by field: w, h, sill (a door or window), dw, ww, wh (a balcony block), ph, pw (a point).
/// h == RE_CEIL: up to the ceiling (the panoramic window).
typealias ReVals = [String: Int]
let RE_CEIL = -1

/// A style: its id (Opening.style / SitePoint.style), its sizes, its width chips (cw) when they differ from the kind's.
/// Its name is strings key "st.<kind>.<id>", a line under it "st.<kind>.<id>.d" when hasD.
struct ReStyle: Equatable {
    let id: String
    let v: ReVals
    var cw: [Int] = []
    var hasD = false
}

private func S(_ id: String, _ v: ReVals, cw: [Int] = [], d: Bool = false) -> ReStyle { ReStyle(id: id, v: v, cw: cw, hasD: d) }

/// Every kind's styles (mockup STY), the first one the standard.
let RE_STYLES: [String: [ReStyle]] = [
    "door": [S("single", ["w": 800, "h": 2100]), S("double", ["w": 1200, "h": 2100], cw: [1000, 1200, 1400]),
             S("slide", ["w": 900, "h": 2100], cw: [800, 900, 1000]), S("arch", ["w": 900, "h": 2100], cw: [800, 900, 1200]),
             S("glass", ["w": 800, "h": 2100]), S("balcony", ["dw": 700, "h": 2100, "ww": 1200, "wh": 1400]),
             S("fold", ["w": 900, "h": 2100], cw: [800, 900, 1200])],
    "window": [S("single", ["w": 700, "h": 1400, "sill": 900], cw: [600, 700, 800]), S("double", ["w": 1500, "h": 1500, "sill": 900]),
               S("triple", ["w": 2100, "h": 1500, "sill": 900], cw: [1800, 2100, 2400]), S("fort", ["w": 1200, "h": 1400, "sill": 900]),
               S("pano", ["w": 1800, "h": RE_CEIL], cw: [1500, 1800, 2400]), S("balcony", ["ww": 1200, "wh": 1400, "dw": 700, "h": 2100])],
    "socket": [S("one", ["ph": 300]), S("two", ["ph": 300]), S("three", ["ph": 1100], d: true), S("usb", ["ph": 1100]), S("power", ["ph": 600])],
    "switch": [S("k1", ["ph": 900]), S("k2", ["ph": 900]), S("k3", ["ph": 900]), S("pass", ["ph": 900], d: true)],
    "rad": [S("alu", ["pw": 640, "ph": 600], d: true), S("steel", ["pw": 1000, "ph": 600]), S("cast", ["pw": 650, "ph": 600], d: true),
            S("towel", ["pw": 500, "ph": 1200], d: true)],
    "cold": [S("tap", ["ph": 500], d: true), S("mix", ["ph": 800], d: true), S("wm", ["ph": 600])],
    "hot": [S("tap", ["ph": 500], d: true), S("mix", ["ph": 800], d: true), S("wm", ["ph": 600], d: true)],
    "sewer": [S("d50", ["ph": 400], d: true), S("d110", ["ph": 100])],
    "gas": [S("g15", ["ph": 1800], d: true), S("g20", ["ph": 1800], d: true), S("g25", ["ph": 2200], d: true)],
    "meter": [S("g16", ["ph": 1600], d: true), S("g4", ["ph": 1600], d: true), S("smart", ["ph": 1600])],
    "boiler": [S("open", ["ph": 1500]), S("turbo", ["ph": 1500]), S("dual", ["ph": 1400], d: true)],
    "ac": [S("b7", ["pw": 700, "ph": 2200], d: true), S("b9", ["pw": 800, "ph": 2200], d: true), S("b12", ["pw": 850, "ph": 2200], d: true),
           S("b18", ["pw": 1000, "ph": 2200], d: true)],
    "vent": [S("r100", ["ph": 2300]), S("r125", ["ph": 2300], d: true), S("sq", ["ph": 2300]), S("fan", ["ph": 2300], d: true)],
    "panel": [S("m6", ["ph": 1700], d: true), S("m12", ["ph": 1700]), S("m24", ["ph": 1700]), S("m36", ["ph": 1700], d: true)],
]

func reStyles(_ kind: String) -> [ReStyle] { RE_STYLES[kind] ?? [S("one", ["ph": 500])] }

/// The style id, or the kind's first (an older opening's "" is a door's single, a window's double).
func reStyle(_ kind: String, _ id: String) -> ReStyle {
    let l = reStyles(kind)
    if id.isEmpty && kind == "window" { return l[1] }
    return l.first { $0.id == id } ?? l[0]
}

/// The style's standard sizes; up to the ceiling becomes the room's height.
func reStd(_ kind: String, _ style: String, _ roomH: Int) -> ReVals {
    var v = reStyle(kind, style).v
    if v["h"] == RE_CEIL { v["h"] = roomH }
    return v
}

/// The sizes asked one per step (mockup pkSteps): a door's width then height; a window's width, height and sill (a
/// panoramic one no sill); a balcony block the door's then the window's (a window's balcony asks the window first); a
/// point its height, a radiator and an air conditioner their width first.
func reSteps(_ kind: String, _ style: String) -> [String] {
    let st = reStyle(kind, style).id
    if kind == "door" { return st == "balcony" ? ["dw", "h", "ww", "wh"] : ["w", "h"] }
    if kind == "window" { return st == "balcony" ? ["ww", "wh", "dw", "h"] : st == "pano" ? ["w", "h"] : ["w", "h", "sill"] }
    return kind == "rad" || kind == "ac" ? ["pw", "ph"] : ["ph"]
}

/// The chips of size step field (mockup stepMeta), the style's own standard among them, sorted; std the standard.
func reChips(_ kind: String, _ style: String, _ field: String, _ roomH: Int) -> (chips: [Int], std: Int?) {
    let st = reStyle(kind, style)
    var ch: [Int]
    switch field {
    case "w": ch = !st.cw.isEmpty ? st.cw : kind == "door" ? [700, 800, 900] : [1200, 1500, 1800]
    case "h":
        if st.id == "balcony" || kind == "door" { ch = [2000, 2100, 2200] }
        else if st.id == "pano" { ch = [2400, 2500, roomH] }
        else { ch = [1200, 1400, 1500] }
    case "sill": ch = [800, 900]
    case "dw": ch = [600, 700, 800]
    case "ww": ch = [900, 1200, 1500]
    case "wh": ch = [1200, 1400, 1500]
    case "pw": ch = kind == "rad" ? [500, 640, 800, 1000, 1200] : [700, 800, 850, 1000]
    default: ch = reKind(kind).hs
    }
    let sv = reStd(kind, st.id, roomH)[field]
    if let sv { ch.append(sv) }
    var seen = Set<Int>(), out: [Int] = []
    for x in ch where !seen.contains(x) { seen.insert(x); out.append(x) }
    return (out.sorted(), sv)
}

/* ---------------- a typed size ---------------- */

/// What is wrong with a size (mockup pkFieldErr), as a strings key under "re.e." and its values.
struct ReErr: Equatable {
    let code: String
    var vars: [String: Int] = [:]
}

/// The first problem of size field of an item of kind/style with sizes v on a wall L long in a room roomH high.
func reFieldErr(_ kind: String, _ style: String, _ v: ReVals, _ field: String, wallL: Int, roomH: Int) -> ReErr? {
    let steps = reSteps(kind, style)
    func later(_ a: String, _ b: String) -> Bool { (steps.firstIndex(of: a) ?? -1) > (steps.firstIndex(of: b) ?? -1) }
    guard let x = v[field] else { return ReErr(code: "empty") }
    switch field {
    case "w", "pw":
        let mn = field == "pw" ? 200 : 300
        if x < mn { return ReErr(code: "min", vars: ["m": mn]) }
        if x > wallL { return ReErr(code: "wide", vars: ["v": x, "l": wallL]) }
    case "dw", "ww":
        if x < 300 { return ReErr(code: "min", vars: ["m": 300]) }
        let tw = (v["dw"] ?? 0) + (v["ww"] ?? 0)
        if tw > wallL { return ReErr(code: "balWide", vars: ["v": tw, "l": wallL]) }
    case "h":
        if x < 300 { return ReErr(code: "min", vars: ["m": 300]) }
        if x > roomH { return ReErr(code: "ceil", vars: ["v": x, "c": roomH]) }
        if reStyle(kind, style).id == "balcony" && later("h", "wh") && x < (v["wh"] ?? 0) + 100 {
            return ReErr(code: "balDoor", vars: ["m": (v["wh"] ?? 0) + 100])
        }
    case "sill":
        let h = v["h"] ?? 0
        if x + h > roomH { return ReErr(code: "sillCeil", vars: ["s": x, "h": h, "t": x + h, "c": roomH]) }
    case "wh":
        if x < 300 { return ReErr(code: "min", vars: ["m": 300]) }
        if later("wh", "h") && x > (v["h"] ?? 0) - 100 { return ReErr(code: "balWin", vars: ["m": (v["h"] ?? 0) - 100]) }
    case "ph":
        if x > roomH { return ReErr(code: "ceil", vars: ["v": x, "c": roomH]) }
    default: break
    }
    return nil
}

/// The first step with a problem and the problem (mockup pkCheckAll), or nil.
func reCheckAll(_ kind: String, _ style: String, _ v: ReVals, wallL: Int, roomH: Int) -> (step: Int, err: ReErr)? {
    for (i, f) in reSteps(kind, style).enumerated() {
        if let e = reFieldErr(kind, style, v, f, wallL: wallL, roomH: roomH) { return (i, e) }
    }
    return nil
}

/* ---------------- the item on the wall ---------------- */

/// A door, window or point as the editor works with it: kind, style, the wall it is on, where (dist: an opening's near
/// edge, a point's centre, from the wall's start corner) and its sizes.
struct ReItem: Equatable {
    var id: String
    var kind: String
    var style: String
    var wall: String
    var dist: Int
    var w = 0, h = 0, sill = 0, dw = 0, wh = 0
    var ph = 0, pw = 0
    var sw = "", thr = 0
    var isOpening: Bool { kind == "door" || kind == "window" }
    var isBalcony: Bool { style == "balcony" }
    /// Its width along the wall (a point counts as 0: its distances are to its centre).
    var along: Int { isOpening ? w : 0 }
    /// The bottom of the glass: a window's sill (a balcony and a door start on the floor).
    var z0: Int { kind == "window" && style != "balcony" ? sill : 0 }
    /// The top: a balcony block's door top, else bottom plus height.
    var top: Int { isBalcony ? h : z0 + h }
}

/// The opening as an item (its style "" read as the kind's standard one).
func reItem(_ o: Opening) -> ReItem {
    let st = reStyle(o.type, o.style).id
    var it = ReItem(id: o.id, kind: o.type == "door" ? "door" : "window", style: st, wall: o.wall, dist: o.off, w: o.w, h: o.h, sill: o.sill)
    it.dw = o.dw; it.wh = o.wh; it.sw = o.sw; it.thr = o.thr
    if st == "balcony" && it.dw <= 0 { it.dw = min(700, max(300, o.w / 3)); it.wh = it.wh > 0 ? it.wh : max(300, o.h - 700) }
    return it
}

/// The point as an item.
func reItem(_ x: SitePoint) -> ReItem {
    var it = ReItem(id: x.id, kind: x.t, style: reStyle(x.t, x.style).id, wall: x.wall, dist: x.off)
    it.ph = x.h; it.pw = x.pw
    return it
}

/// The item back into the room's opening (kept fields of the old one, e.g. offDrag, stay).
func reOpening(_ it: ReItem, _ old: Opening? = nil) -> Opening {
    var o = old ?? Opening(id: it.id, type: it.kind, wall: it.wall, w: it.w, h: it.h, off: it.dist, sill: 0)
    o.type = it.kind; o.wall = it.wall; o.w = it.w; o.h = it.h; o.off = it.dist
    o.style = it.style; o.sw = it.sw; o.thr = it.kind == "door" ? it.thr : 0
    if it.isBalcony { o.sill = 0; o.dw = it.dw; o.wh = it.wh } else { o.sill = it.kind == "window" ? it.sill : 0; o.dw = 0; o.wh = 0 }
    o.offDrag = false; o.sillDrag = false
    return o
}

/// The item back into the room's point: its default diameter and meter box for the kind (Data/SitePoints.swift).
func rePoint(_ it: ReItem, _ old: SitePoint? = nil) -> SitePoint {
    let d = pointDefaults(it.kind)
    var x = old ?? SitePoint(id: it.id, t: it.kind, wall: it.wall, off: it.dist, h: it.ph, d: d.d, mh: d.mh)
    x.t = it.kind; x.wall = it.wall; x.off = it.dist; x.h = it.ph; x.style = it.style
    x.pw = it.kind == "rad" || it.kind == "ac" ? it.pw : 0
    if it.kind == "sewer" { x.d = it.style == "d110" ? 110 : 50 }
    return x
}

/// The sizes of an item by field (mockup itVals).
func reVals(_ it: ReItem) -> ReVals {
    if !it.isOpening { return it.pw > 0 || it.kind == "rad" || it.kind == "ac" ? ["ph": it.ph, "pw": it.pw] : ["ph": it.ph] }
    if it.isBalcony { return ["dw": it.dw, "ww": it.w - it.dw, "h": it.h, "wh": it.wh] }
    var v: ReVals = ["w": it.w, "h": it.h]
    if it.kind == "window" && it.style != "pano" { v["sill"] = it.sill }
    return v
}

/// Style and sizes v put on item it on a wall L long, keeping its centre where it was (mockup applyVals).
func reApply(_ it: ReItem, _ style: String, _ v: ReVals, wallL: Int, centre: Int) -> ReItem {
    var x = it
    x.style = style
    if x.isOpening {
        if style == "balcony" {
            x.dw = v["dw"] ?? 700; x.w = x.dw + (v["ww"] ?? 1200); x.h = v["h"] ?? 2100; x.wh = v["wh"] ?? 1400; x.sill = 0
        } else {
            x.w = v["w"] ?? x.w; x.h = v["h"] ?? x.h; x.dw = 0; x.wh = 0
            if x.kind == "window" { x.sill = style == "pano" ? 0 : (v["sill"] ?? x.sill) }
        }
        x.dist = reClamp(reR10(centre - x.w / 2), 0, max(0, wallL - x.w))
    } else {
        x.ph = v["ph"] ?? x.ph
        x.pw = v["pw"] ?? 0
    }
    return x
}

/// A new item of kind on wall at centre mm from its start, at the first style's sizes, shrunk to the wall and the room.
func reNewItem(_ kind: String, wall: String, centre: Int, wallL: Int, roomH: Int, id: String = uid()) -> ReItem {
    let st = reStyles(kind)[kind == "window" ? 1 : 0]
    var it = ReItem(id: id, kind: kind, style: st.id, wall: wall, dist: 0)
    it = reApply(it, st.id, reStd(kind, st.id, roomH), wallL: wallL, centre: centre)
    if it.isOpening {
        it.w = min(it.w, wallL / 10 * 10)
        if kind == "window" && it.sill + it.h > roomH { it.h = max(300, roomH - it.sill - 100) }
        if kind == "door" && it.h > roomH { it.h = roomH - 100 }
        it.dist = reClamp(reR10(centre - it.w / 2), 0, max(0, wallL - it.w))
        if kind == "door" { it.sw = "inL" } else { it.sw = "L" }
    } else {
        it.dist = reClamp(centre, 0, wallL)
    }
    return it
}

func reClamp(_ v: Int, _ a: Int, _ b: Int) -> Int { max(a, min(b, v)) }
func reR10(_ v: Int) -> Int { Int((Double(v) / 10).rounded()) * 10 }

/* ---------------- magnets, distances, free places ---------------- */

/// Where a dragged item lands (mockup magnet): within 12 screen points (at most 250 mm) of a corner or the wall's middle
/// it sticks there ("corner" / "mid"); else to 10 mm. pxPerMm: screen points a millimetre.
func reMagnet(_ along: Int, _ wallL: Int, _ raw: Double, _ pxPerMm: Double) -> (v: Int, mag: String?) {
    let hi = max(0, wallL - along)
    let th = min(250, 12 / max(pxPerMm, 1e-6))
    var best: (d: Double, v: Double, l: String)? = nil
    for (x, l) in [(0.0, "corner"), (Double(hi), "corner"), (Double(hi) / 2, "mid")] {
        let d = abs(raw - x)
        if d < th && (best == nil || d < best!.d) { best = (d, x, l) }
    }
    if let b = best { return (Int(b.v.rounded()), b.l) }
    return (reClamp(reR10(Int(raw.rounded())), 0, hi), nil)
}

/// The distances to both corners: from the start corner to the near edge (a point's centre), and from the far edge to
/// the end corner.
func reDists(_ it: ReItem, _ wallL: Int) -> (l: Int, r: Int) { (it.dist, wallL - it.along - it.dist) }

/// Two doors or windows on the same wall that overlap.
func reOverlap(_ a: ReItem, _ b: ReItem) -> Bool {
    a.id != b.id && a.wall == b.wall && a.isOpening && b.isOpening && a.dist < b.dist + b.w && b.dist < a.dist + a.w
}

/// The nearest place to it.dist on its wall where it overlaps no other door or window (mockup freeSpot), or nil.
func reFreeSpot(_ it: ReItem, _ others: [ReItem], _ wallL: Int) -> Int? {
    var s = 0
    while s <= wallL {
        for d in [it.dist + s, it.dist - s] where d >= 0 && d + it.w <= wallL {
            var t = it
            t.dist = d
            if !others.contains(where: { reOverlap(t, $0) }) { return d }
        }
        s += 50
    }
    return nil
}

/* ---------------- Tekshiruv ---------------- */

/// A problem of the room's items (mockup issues): the item, a strings key under "re.i." and its words and numbers.
struct ReIssue: Equatable {
    let id: String
    let code: String
    var kinds: [String] = []
    var wall = ""
    var vars: [String: Int] = [:]
}

/// The rules: an item past its wall, a door or window above the ceiling, a point above it, two openings over each
/// other, a point on a door or window, electrics nearer than 600 mm to water, a gas meter or boiler nearer than 500 mm
/// to electrics (along the same wall). lens: each wall's length by id; roomH the height.
func reIssues(_ items: [ReItem], lens: [String: Int], roomH: Int) -> [ReIssue] {
    var out: [ReIssue] = []
    for it in items {
        guard let L = lens[it.wall] else { continue }
        if it.isOpening {
            if it.dist < 0 || it.dist + it.w > L { out.append(ReIssue(id: it.id, code: "out", kinds: [it.kind], wall: it.wall)) }
            if it.top > roomH { out.append(ReIssue(id: it.id, code: "ceil", kinds: [it.kind], vars: ["t": it.top, "c": roomH])) }
        } else if it.ph > roomH { out.append(ReIssue(id: it.id, code: "pCeil", kinds: [it.kind])) }
    }
    for i in items.indices {
        for j in items.indices where j > i {
            let a = items[i], b = items[j]
            if a.wall != b.wall { continue }
            if a.isOpening && b.isOpening && a.dist < b.dist + b.w && b.dist < a.dist + a.w {
                out.append(ReIssue(id: b.id, code: "over", kinds: [a.kind, b.kind], wall: a.wall))
            }
            let o: ReItem? = a.isOpening && !b.isOpening ? a : b.isOpening && !a.isOpening ? b : nil
            if let o {
                let p = o.id == a.id ? b : a
                if p.dist > o.dist && p.dist < o.dist + o.w && p.ph > o.z0 && p.ph < o.top {
                    out.append(ReIssue(id: p.id, code: "onOp", kinds: [p.kind, o.kind]))
                }
            }
        }
    }
    for e in items where RE_ELEC.contains(e.kind) {
        var bw: (d: Int, q: ReItem)? = nil, bg: (d: Int, q: ReItem)? = nil
        for q in items where q.wall == e.wall {
            let d = abs(e.dist - q.dist)
            if RE_WATER.contains(q.kind) && (bw == nil || d < bw!.d) { bw = (d, q) }
            if (q.kind == "meter" || q.kind == "boiler") && (bg == nil || d < bg!.d) { bg = (d, q) }
        }
        if let bw, bw.d < 600 { out.append(ReIssue(id: e.id, code: "water", kinds: [e.kind], vars: ["d": bw.d])) }
        if let bg, bg.d < 500 { out.append(ReIssue(id: bg.q.id, code: "gas", kinds: [bg.q.kind], vars: ["d": bg.d])) }
    }
    return out
}

/* ---------------- the room's walls (Uzunlik, the openings step) ---------------- */

/// A wall typed in the editor (mockup setWallLen): 300 – 999 999 mm; above 30 000 it is said, never stopped.
func reWallLenOk(_ v: Int) -> Bool { v >= SHAPE_WALL_MIN && v <= SHAPE_WALL_MAX }
func reWallBig(_ v: Int) -> Bool { v > Geo.WALL_BIG }
