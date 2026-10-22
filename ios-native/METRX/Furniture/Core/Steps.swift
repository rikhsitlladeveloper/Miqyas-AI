import Foundation

/*
 * The furniture gallery and its size steps (decided 21 Oct 2026, mockup design/furniture/gallery-steps-mockup.html v5;
 * Android furniture/Steps.kt; StepsTests): every model once, grouped by room; each main size asked on its own step; the
 * piece built from what was typed (the usual size while a field is empty, so the picture always shows a whole piece).
 */

/// The gallery's groups by room (strings key of the name, models in order).
let GALLERY: [(String, [String])] = [
    ("kitchen", ["I", "L", "U", "O", "P"]),
    ("bedroom", ["h2", "h3", "s2", "s3", "dresser", "nightstand", "vanity"]),
    ("living", ["tv", "shelving", "sideboard"]),
    ("hall", ["hallway", "op"]),
    ("office", ["desk"]),
]

/// One size on its own step: key in the values, its label and help (strings keys), the usual size and the range, mm.
struct SizeStep: Equatable { let key: String, label: String, help: String, usual: Int, min: Int, max: Int }

/// The main sizes of a model, in the order they are asked: a kitchen's sides, its island or peninsula and the ceiling; a cabinet's width, height, depth.
func stepsOf(_ m: FModelDef) -> [SizeStep] {
    if m.kind == "kitchen" {
        let labels: [String], helps: [String]
        switch m.layout {
        case "L": labels = ["fz.w1", "fz.w2"]; helps = ["fx.hW1", "fx.hW2"]
        case "U": labels = ["fz.uL", "fz.uM", "fz.uR"]; helps = ["fx.hUL", "fx.hUM", "fx.hUR"]
        case "O", "P": labels = ["fz.pW"]; helps = ["fx.hRun"]
        default: labels = ["fz.len"]; helps = ["fx.hLen"]
        }
        var out = labels.indices.map { i in SizeStep(key: "s\(i)", label: labels[i], help: helps[i], usual: i < m.sides.count ? m.sides[i] : 3000, min: 600, max: 8000) }
        if m.layout == "O" { out.append(SizeStep(key: "isl", label: "fz.isl", help: "fx.hIsl", usual: m.island, min: 600, max: 6000)) }
        if m.layout == "P" { out.append(SizeStep(key: "isl", label: "fz.pP", help: "fx.hPen", usual: m.island, min: 600, max: 6000)) }
        return out + [SizeStep(key: "h", label: "fz.ceil", help: "fx.hCeil", usual: m.h, min: 2000, max: 4000)]
    }
    // wardrobes stand high; the living room and bedroom pieces can be small
    let ward = m.type.isEmpty
    let legs = !ward && typeSize(m.type).legs
    return [
        SizeStep(key: "w", label: "wd.w", help: "fx.hW", usual: m.w, min: ward ? 400 : 300, max: 6000),
        SizeStep(key: "h", label: "fz.wH", help: legs ? "fx.hHLegs" : "fx.hH", usual: m.h, min: ward ? 1200 : 300, max: 3200),
        SizeStep(key: "d", label: "wd.d", help: "fx.hD", usual: m.d, min: 250, max: 1000),
    ]
}

/// What is wrong with mm for s: "fx.min" or "fx.max" with the limit, or nil.
func stepIssue(_ s: SizeStep, _ mm: Int?) -> (String, Int)? {
    guard let mm else { return nil }
    if mm < s.min { return ("fx.min", s.min) }
    if mm > s.max { return ("fx.max", s.max) }
    return nil
}

/// The piece of model m with the sizes v (a missing one takes its usual size).
func pieceOf(_ m: FModelDef, _ v: [String: Int], _ ws: Workshop, _ name: String, now: Ms = 0) -> Furniture {
    let st = Dictionary(uniqueKeysWithValues: stepsOf(m).map { ($0.key, $0.usual) })
    func g(_ k: String) -> Int { v[k] ?? st[k] ?? 0 }
    if m.kind == "kitchen" {
        return newFreeKitchen(name, m.id, m.layout, (0..<sidesOf(m.layout)).map { g("s\($0)") }, m.layout == "O" || m.layout == "P" ? g("isl") : 0, g("h"), ws, now: now)
    }
    if !m.type.isEmpty { return newFreeCabinet(name, m.type, g("w"), g("h"), g("d"), ws, now: now) }
    return newFreeWardrobe(name, m.id, g("w"), g("h"), g("d"), m.built, m.doors, ws, now: now, n: m.n)
}

/// A piece's sizes as step values: a kitchen's typed sides, island and ceiling; a cabinet's outer width, height (legs in) and depth.
func valsOf(_ f: Furniture, _ ws: Workshop) -> [String: Int] {
    if f.kind == "kitchen" {
        guard let fs = f.free else { return [:] }
        var out: [String: Int] = [:]
        for (i, s) in fs.sides.enumerated() { out["s\(i)"] = s }
        if fs.island > 0 { out["isl"] = fs.island }
        out["h"] = fs.h
        return out
    }
    guard let m = wardOfF(f) else { return [:] }
    return ["w": m.w, "h": f.type.isEmpty ? m.h : outerH(m, ws), "d": m.d]
}

/// The model a piece was made from (a kitchen made before the gallery: its layout's model; a wardrobe: two doors).
func modelOf(_ f: Furniture) -> FModelDef {
    fModel(f.model) ?? fModel(!f.type.isEmpty ? f.type : f.kind == "kitchen" ? f.layout : "h2") ?? F_MODELS[0]
}

/// The piece with new sizes v: a room-less kitchen's runs follow its sides (units that no longer fit are cut, the rest
/// stays); a cabinet keeps its sections, spread again over a new width.
func resized(_ f: Furniture, _ v: [String: Int], _ ws: Workshop) -> Furniture {
    if f.kind == "kitchen" {
        let n = sidesOf(f.layout)
        let old = f.free ?? FreeSize()
        var nf = f
        nf.free = FreeSize((0..<n).map { v["s\($0)"] ?? ($0 < old.sides.count ? old.sides[$0] : 3000) }, f.walls.contains(ISLAND) ? v["isl"] ?? old.island : 0, v["h"] ?? old.h)
        let nn = nf
        return fitTo(nf, nf.walls, { freeLen(nn, $0) }, nil, ws)
    }
    guard let m = wardOfF(f) else { return f }
    let w = v["w"] ?? m.w, d = v["d"] ?? m.d
    var h = v["h"] ?? outerH(m, ws)
    if !f.type.isEmpty && m.legs { h -= legsOf(m, ws) }
    var nm = m; nm.w = w; nm.h = h; nm.d = d
    if w != m.w { nm.sections = splitSections(w, m.sections.map { var s = $0; s.lock = false; return s }) }
    var g = f; g.modules = f.modules.map { $0.id == m.id ? nm : $0 }
    return g
}

/// Where a piece fits best in a room whose walls go ids: the first wall with nothing wrong, else the one with the fewest issues.
func bestFirst(_ f: Furniture, _ ids: [String], _ len: (String) -> Int?, _ roomH: Int?, _ ws: Workshop) -> (String, [FitIssue]) {
    let all = ids.map { w in (w, fitIssues(f, placeWalls(f, ids, w), len, roomH, ws)) }
    return all.min { $0.1.count < $1.1.count } ?? (ids.first ?? "A", [])
}

/// A kitchen for a measured room: it takes the walls it goes on whole (from first, clockwise), their lengths its sides;
/// an island or peninsula keeps its usual length where it fits; the ceiling is the room's.
func roomKitchen(_ m: FModelDef, _ ids: [String], _ first: String, _ len: (String) -> Int?, _ roomH: Int?, _ ws: Workshop, _ name: String, now: Ms = 0) -> Furniture {
    let probe = pieceOf(m, [:], ws, name, now: now)
    let on = placeWalls(probe, ids, first).filter { $0 != ISLAND }
    var v: [String: Int] = [:]
    for (i, w) in on.enumerated() { v["s\(i)"] = len(w) ?? (i < m.sides.count ? m.sides[i] : 3000) }
    // an island runs along its side; a peninsula out from it, so it is held to the room's other way less the side's
    // units and a 900 way round its end
    var cap: Int? = v["s0"].map { $0 - 600 }
    if m.layout == "P" {
        cap = nil
        let i0 = ids.firstIndex(of: on.first ?? first) ?? -1
        let j = ids.isEmpty ? -1 : (i0 + 1) % ids.count
        if j >= 0, let l = len(ids[j]) { cap = l - 600 - 900 }
    }
    if let usual = stepsOf(m).first(where: { $0.key == "isl" })?.usual { v["isl"] = max(600, min(usual, cap ?? usual)) }
    if let roomH { v["h"] = roomH }
    return pieceOf(m, v, ws, name, now: now)
}

/// A cabinet for a measured room: its usual size, no wider than the wall first and no higher than the ceiling allows.
func roomCabinet(_ m: FModelDef, _ wallLen: Int?, _ roomH: Int?, _ ws: Workshop, _ name: String, now: Ms = 0) -> Furniture {
    let st = Dictionary(uniqueKeysWithValues: stepsOf(m).map { ($0.key, $0.usual) })
    let w = wallLen.map { min(st["w"]!, $0 - 2 * W_GAP_SIDE) } ?? st["w"]!
    let h = m.type.isEmpty && roomH != nil ? min(st["h"]!, roomH! - W_GAP_TOP) : st["h"]!
    return pieceOf(m, ["w": max(300, w), "h": h, "d": st["d"]!], ws, name, now: now)
}
