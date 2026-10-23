import Foundation

/*
 * The furniture gallery and its size steps (decided 21 Oct 2026, mockup design/furniture/gallery-steps-mockup.html v5;
 * Android furniture/Steps.kt; StepsTests): every model once, grouped by room; each main size asked on its own step; the
 * piece built from what was typed (the usual size while a field is empty, so the picture always shows a whole piece).
 */

/// The gallery's groups by room (strings key of the name, models in order).
let GALLERY: [(String, [String])] = [
    ("kitchen", ["I", "L", "U", "O", "P", "dining", "bar", "pantry"]),
    ("bedroom", ["h2", "h3", "s2", "s3", "cornerW", "bed", "dresser", "nightstand", "vanity", "shelfW", "tvBed"]),
    ("living", ["tv", "stenka", "vitrina", "sideboard", "shelving", "coffee", "shelvesW"]),
    ("hall", ["hallway", "shoe", "hallW", "mirrorP", "op"]),
    ("kids", ["bunk", "loft", "kidsW", "toys"]),
    ("office", ["desk", "cornerDesk", "bookcase", "officeC"]),
    ("bath", ["sinkV", "mirrorC", "penal", "washer"]),
]

/// One size on its own step: key in the values, its label and help (strings keys), the usual size and the range, mm.
/// A step with opts asks a choice instead (strings keys; its value is the index, usual the one chosen at first);
/// picks are the usual sizes offered under the field (a mattress's).
struct SizeStep: Equatable {
    let key: String, label: String, help: String, usual: Int, min: Int, max: Int
    var opts: [String] = []
    var picks: [Int] = []
    var choice: Bool { !opts.isEmpty }
}

/// A choice step: opts its strings keys, the first chosen unless usual.
private func choiceStep(_ key: String, _ label: String, _ opts: [String], _ usual: Int = 0) -> SizeStep {
    SizeStep(key: key, label: label, help: label + ".h", usual: usual, min: 0, max: opts.count - 1, opts: opts)
}

private func wStep(_ u: Int, _ lo: Int, _ hi: Int, _ label: String = "wd.w") -> SizeStep { SizeStep(key: "w", label: label, help: "fx.hW", usual: u, min: lo, max: hi) }
private func hStep(_ u: Int, _ lo: Int, _ hi: Int, _ help: String = "fx.hH") -> SizeStep { SizeStep(key: "h", label: "fz.wH", help: help, usual: u, min: lo, max: hi) }
private func dStep(_ u: Int, _ lo: Int, _ hi: Int, _ label: String = "wd.d") -> SizeStep { SizeStep(key: "d", label: label, help: "fx.hD", usual: u, min: lo, max: hi) }

/// The steps of a bed, a bunk or loft bed.
private func bedSteps(_ t: String) -> [SizeStep] {
    let bunkMat = [SizeStep(key: "mw", label: "fb.mw", help: "fb.mw.h", usual: 900, min: 700, max: 1000, picks: [800, 900]),
                   SizeStep(key: "ml", label: "fb.ml", help: "fb.ml.h", usual: 2000, min: 1600, max: 2100, picks: [1900, 2000])]
    let ladder = choiceStep("lad", "fb.lad", ["fb.lad.L", "fb.lad.R"], 1)
    switch t {
    case "bunk": return bunkMat + [hStep(1650, 1400, 2000, "fb.hBunk"), ladder]
    case "loft": return bunkMat + [hStep(1800, 1500, 2200, "fb.hLoft"), ladder, choiceStep("und", "fb.und", ["fb.und.desk", "fb.und.ward", "fb.und.open"])]
    default:
        return [choiceStep("bt", "fb.bt", ["fb.bt.legs", "fb.bt.drawers", "fb.bt.lift"]),
                SizeStep(key: "mw", label: "fb.mw", help: "fb.mw.h", usual: 1600, min: 700, max: 2000, picks: [900, 1200, 1400, 1600, 1800]),
                SizeStep(key: "ml", label: "fb.ml", help: "fb.ml.h", usual: 2000, min: 1800, max: 2200, picks: [1900, 2000]),
                SizeStep(key: "h", label: "fb.h", help: "fb.h.h", usual: 450, min: 250, max: 700),
                SizeStep(key: "hb", label: "fb.hb", help: "fb.hb.h", usual: 1000, min: 600, max: 1600)]
    }
}

/// The steps of the newer models (22 Oct 2026); nil for the older ones.
private func newSteps(_ m: FModelDef) -> [SizeStep]? {
    let t = m.type
    let legs = choiceStep("lg", "fb.lg", ["fb.lg.board", "fb.lg.metal4", "fb.lg.frame"])
    let round = choiceStep("rc", "fb.rc", ["fb.rc.no", "fb.rc.yes"])
    switch t {
    case "bed", "bunk", "loft": return bedSteps(t)
    case "dining": return [wStep(1400, 600, 3000), dStep(800, 500, 1200), hStep(750, 600, 900), legs, choiceStep("tp", "fb.tp", ["fb.tp.ldsp", "fb.tp.wt"]), round]
    case "coffee": return [wStep(1000, 400, 1600), dStep(600, 300, 1000), hStep(450, 300, 600), legs, round]
    case "bar": return [wStep(1500, 600, 3000), hStep(1100, 900, 1250), dStep(600, 400, 900, "fb.barD")]
    case "mirrorP": return [wStep(1000, 400, 2000), SizeStep(key: "h", label: "fz.wH", help: "fb.hPanel", usual: 1600, min: 600, max: 2200)]
    case "stenka": return [wStep(3000, 1500, 6000, "fz.wAll"), hStep(2200, 1500, 3000), dStep(400, 300, 650)]
    case "cornerW":
        return [SizeStep(key: "w", label: "fz.wA", help: "fz.wA.h", usual: 1800, min: 1000, max: 4000),
                SizeStep(key: "w2", label: "fz.wB", help: "fz.wB.h", usual: 1600, min: 1000, max: 4000),
                hStep(2200, 1500, 3000), dStep(600, 400, 700)]
    case "cornerDesk":
        return [SizeStep(key: "w", label: "fz.wA", help: "fz.wA.h", usual: 1400, min: 900, max: 3000),
                SizeStep(key: "w2", label: "fz.wB", help: "fz.wB.h", usual: 1200, min: 1100, max: 3000),
                hStep(750, 650, 850, "fx.hHLegs"), dStep(600, 450, 800)]
    case "vitrina": return [wStep(800, 400, 1600), hStep(2000, 1400, 2500), dStep(400, 300, 600)]
    case "washer": return [wStep(650, 600, 900), hStep(2000, 1500, 2600), dStep(600, 550, 700)]
    case "vanity":
        return [wStep(1000, 600, 1800), hStep(750, 650, 850, "fx.hHLegs"), dStep(450, 350, 600),
                SizeStep(key: "rw", label: "fz.mirW", help: "fz.mirW.h", usual: 600, min: 300, max: 1600),
                SizeStep(key: "rh", label: "fz.mirH", help: "fz.mirH.h", usual: 800, min: 300, max: 1400)]
    default:
        let s = typeSize(t)
        if HUNG_TYPES.contains(t) {
            return [wStep(s.w, 300, 3000), SizeStep(key: "h", label: "fz.wH", help: "fx.hH", usual: s.h, min: 150, max: 1200), dStep(s.d, 100, 500),
                    SizeStep(key: "e", label: "fz.elev", help: "fz.elev.h", usual: s.elev, min: 300, max: 2200)]
        }
        if MOUNT_TYPES.contains(t) {
            return [wStep(s.w, 300, 1600), hStep(s.h, 400, 2400, "fx.hHLegs"), dStep(s.d, 250, 650), choiceStep("mt", "fb.mt", ["fb.mt.legs", "fb.mt.wall"])]
        }
        return nil
    }
}

/// Models built by Pieces.swift (newPiece / pieceVals / pieceResized) rather than the older rules.
func isNewModel(_ type: String) -> Bool {
    !type.isEmpty && (ITEM_TYPES.contains(type) || PIECE_TYPES.contains(type) || MORE_TYPES.contains(type) || type == "vanity")
}

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
    if let ns = newSteps(m) { return ns }
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
    if isNewModel(m.type) { return newPiece(m.type, g, ws, name, now: now) }
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
    if isNewModel(f.type) { return pieceVals(f, ws) }
    guard let m = wardOfF(f) else { return [:] }
    return ["w": m.w, "h": f.type.isEmpty ? m.h : outerH(m, ws), "d": m.d]
}

/// A piece's sizes in a line: a bed's mattress, a corner piece's two arms, else width × height × depth; mm the unit's word.
func sizeLine(_ f: Furniture, _ ws: Workshop, _ mm: String) -> String {
    let v = valsOf(f, ws)
    func g(_ k: String, _ d: Int) -> String { "\(v[k] ?? d)" }
    if v["mw"] != nil { return g("mw", 0) + " × " + g("ml", 0) + " · h " + g("h", 0) + " " + mm }
    if v["w2"] != nil { return g("w", 0) + " + " + g("w2", 0) + " × " + g("h", 0) + " × " + g("d", 0) + " " + mm }
    guard let m = wardOfF(f) else { return "" }
    return g("w", m.w) + " × " + g("h", m.h) + " × " + g("d", m.d) + " " + mm
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
    if isNewModel(f.type) { return pieceResized(f, v, ws) }
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
    // a bed or a table keeps its usual size; a corner piece's first arm is held to the wall
    guard let sw = st["w"], !ITEM_TYPES.contains(m.type) else { return pieceOf(m, [:], ws, name, now: now) }
    if CORNER_TYPES.contains(m.type) {
        let aw: Int = wallLen.map { min(sw, $0 - 2 * W_GAP_SIDE) } ?? sw
        return pieceOf(m, ["w": max(900, aw)], ws, name, now: now)
    }
    let w = wallLen.map { min(sw, $0 - 2 * W_GAP_SIDE) } ?? sw
    let h = m.type.isEmpty && roomH != nil ? min(st["h"]!, roomH! - W_GAP_TOP) : st["h"]!
    var v = st
    v["w"] = max(300, w); v["h"] = h; v["d"] = st["d"] ?? m.d
    return pieceOf(m, v, ws, name, now: now)
}
