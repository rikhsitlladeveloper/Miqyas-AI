import Foundation

/*
 * Room shapes (design/room-shapes/BUILD_SPEC.md §2 and "Geometry"): the 8 picture cards of the "Xona shakli" screen,
 * which sizes each one asks, and the plan they make. A port of the approved mockup's SH, params(), geom(), simple(),
 * tf(), area() and stepErr() (design/room-shapes/mockup.html, "shapes"), tested against shape-cases.json, which the
 * mockup itself generated (gen_cases.js), so both apps draw the same rooms. Names follow the Android app's
 * geo/RoomShapes.kt.
 *
 * Pure Swift, no UI. Lengths are mm. Plan y points down, so the shapes run clockwise on screen.
 * Wall i runs from corner i to corner i + 1. Errors are codes plus values (ShapeError); the UI turns them into text.
 * A finished shape becomes a real Room with shapeToRoom (ShapeRoom.swift).
 */

/* ---------------- the shapes ---------------- */

/// How a shape is built: walls at right angles (walked from wall A), the cut corner, the bay, or a free sketch.
enum ShapeKind: Equatable { case ortho, cut, bay, free }

/// The 8 shapes, in the cards' order (rawValue: the mockup's id). dirs: for right-angle shapes the walk from wall A
/// (R right, D down, L left, U up); every wall but the last two is asked. defaults: each asked size's starting value.
enum RoomShape: String, CaseIterable, Equatable {
    case rect = "rect", L = "L", U = "U", cut = "cut", T = "T", Z = "Z", bay = "bay", free = "free"

    var id: String { rawValue }

    var kind: ShapeKind {
        switch self {
        case .rect, .L, .U, .T, .Z: return .ortho
        case .cut: return .cut
        case .bay: return .bay
        case .free: return .free
        }
    }

    var dirs: String {
        switch self {
        case .rect: return "RDLU"
        case .L: return "RDRDLU"
        case .U: return "RDRURDLU"
        case .T: return "RDLDLULU"
        case .Z: return "RDRDLULU"
        default: return ""
        }
    }

    var defaults: [Int] {
        switch self {
        case .rect: return [3400, 2600]
        case .L: return [1800, 1800, 2400, 1800]
        case .U: return [1400, 1800, 1600, 1800, 1400, 3600]
        case .cut: return [3600, 2200, 2800, 3000]
        case .T: return [4800, 1400, 1600, 2200, 1600, 2200]
        case .Z: return [2600, 1600, 1800, 2400, 2600, 1400]
        case .bay: return [4200, 3600, 1000, 2400, 800]
        case .free: return []
        }
    }

    /// How many sizes the card says it asks (mockup askCount); 0 for the free sketch, which asks every drawn wall.
    var askCount: Int {
        switch kind {
        case .ortho: return dirs.count - 2
        case .cut: return 4
        case .bay: return 5
        case .free: return 0
        }
    }

    /// How many walls the shape has; nil for the free sketch (as many as drawn).
    var wallCount: Int? {
        switch kind {
        case .ortho: return dirs.count
        case .cut: return 5
        case .bay: return 8
        case .free: return nil
        }
    }

    /// The shape with this mockup id ("rect", "L", "U", "cut", "T", "Z", "bay", "free"), or nil.
    static func of(_ id: String) -> RoomShape? { RoomShape(rawValue: id) }
}

/// The mockup's wall letters: wall i is "ABCDEFGHIJ…"[i] (the bay's walls run A–H). See ShapeRoom.wallIds for the editor's.
func shapeWallLetter(_ i: Int) -> String {
    let all = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    return i >= 0 && i < all.count ? String(all[i]) : "?"
}

/// A free sketch for the walls step: each drawn wall's direction (a unit vector, plan y down) and its drawn length (the
/// field's hint), mm.
struct FreeSketch: Equatable {
    var dirs: [Pt]
    var hints: [Int]
}

/// The sketch the walls step asks about, from the corners the builder's sketch screen made (Sketch.toMm: mm, clockwise):
/// one direction and one hint (rounded to 10 mm) per wall; walls shorter than 1 mm are skipped (mockup skToMm).
func freeSketch(_ corners: [Pt]) -> FreeSketch {
    var dirs: [Pt] = [], hints: [Int] = []
    let n = corners.count
    for i in 0..<n {
        let a = corners[i], b = corners[(i + 1) % n]
        let dx = b.x - a.x, dy = b.y - a.y
        let l = hypot(dx, dy)
        if l < 1 { continue }
        dirs.append(Pt(x: dx / l, y: dy / l))
        hints.append(kround(l / 10) * 10)
    }
    return FreeSketch(dirs: dirs, hints: hints)
}

/// The chosen card with its "Ko‘zgu" (mirror: flips x) and "Burish" (each turn maps (x, y) → (−y, x)), and the free sketch.
struct ShapeSpec: Equatable {
    var shape: RoomShape
    var mirror = false
    var turns = 0
    var sketch: FreeSketch? = nil
    init(_ shape: RoomShape, mirror: Bool = false, turns: Int = 0, sketch: FreeSketch? = nil) {
        self.shape = shape; self.mirror = mirror; self.turns = turns; self.sketch = sketch
    }
    /// Turns as 0–3.
    var turn: Int { ((turns % 4) + 4) % 4 }
    /// "Ko‘zgu" tapped.
    func mirrored() -> ShapeSpec { var s = self; s.mirror.toggle(); return s }
    /// "Burish" tapped: 90° more.
    func turned() -> ShapeSpec { var s = self; s.turns = (turn + 1) % 4; return s }
}

/* ---------------- the asked sizes (mockup params) ---------------- */

/// What a step asks: a wall's length, or the bay's width or depth.
enum AskKind: Equatable { case wall, bayWidth, bayDepth }

/// One step of the walls screen: wall is the wall index for .wall (nil for the bay's width and depth); def prefills the field.
struct ShapeAsk: Equatable {
    let kind: AskKind
    let wall: Int?
    let def: Int
    /// "wall:A" …, "bay.width" or "bay.depth" (as shape-cases.json names them).
    var key: String {
        switch kind {
        case .wall: return "wall:" + shapeWallLetter(wall ?? 0)
        case .bayWidth: return "bay.width"
        case .bayDepth: return "bay.depth"
        }
    }
}

/// The sizes a shape asks, one per step, in order (mockup params). Right angles: walls A… except the last two. Cut
/// corner: A, B, D, E (C is worked out). Bay: G (opposite the bay), H (side), A (corner to the bay), the bay's width and
/// depth. Free: every drawn wall, prefilled with the drawn length.
func asks(_ spec: ShapeSpec) -> [ShapeAsk] {
    let sh = spec.shape
    let d = sh.defaults
    switch sh.kind {
    case .ortho:
        let n = max(0, sh.dirs.count - 2)
        return (0..<n).map { i in ShapeAsk(kind: .wall, wall: i, def: d[i]) }
    case .cut:
        let walls = [0, 1, 3, 4]
        return walls.indices.map { j in ShapeAsk(kind: .wall, wall: walls[j], def: d[j]) }
    case .bay:
        return [ShapeAsk(kind: .wall, wall: 6, def: d[0]), ShapeAsk(kind: .wall, wall: 7, def: d[1]),
                ShapeAsk(kind: .wall, wall: 0, def: d[2]), ShapeAsk(kind: .bayWidth, wall: nil, def: d[3]),
                ShapeAsk(kind: .bayDepth, wall: nil, def: d[4])]
    case .free:
        guard let sk = spec.sketch else { return [] }
        return sk.hints.indices.map { i in ShapeAsk(kind: .wall, wall: i, def: sk.hints[i]) }
    }
}

/* ---------------- errors ---------------- */

/// What is wrong, as a code (rawValue: the Android app's ShapeErrorCode name); the UI maps it to a string. The values
/// each code carries are listed with it.
enum ShapeErrorCode: String, Equatable {
    /// A typed value outside its range: value (nil when empty), min, limit (the most).
    case outOfRange = "OUT_OF_RANGE"
    /// Cut corner: wall D must be shorter than wall A; limit = A.
    case cutDNotShorter = "CUT_D_NOT_SHORTER"
    /// Cut corner: wall B must be shorter than wall E; limit = E.
    case cutBNotShorter = "CUT_B_NOT_SHORTER"
    /// Cut corner: no cut comes out (D < A and B < E both needed).
    case cutNoCut = "CUT_NO_CUT"
    /// Bay: A + the bay's width (value) must be shorter than wall G (limit).
    case bayNotFit = "BAY_NOT_FIT"
    /// Bay: too deep for its width, the 45° sides meet (the width must be more than twice the depth).
    case bayTooDeep = "BAY_TOO_DEEP"
    /// Free sketch: the walls miss closing by value mm, more than max(30 mm, 1 % of the perimeter).
    case notClosed = "NOT_CLOSED"
    /// A worked-out wall comes out zero or negative: wall, value its length.
    case wallNegative = "WALL_NEGATIVE"
    /// The walls cross each other.
    case wallsCross = "WALLS_CROSS"
    /// The diagonal (value) does not match the walls: they give limit (± 20 mm, the editor's tolerance).
    case diagMismatch = "DIAG_MISMATCH"
    /// A field is empty (or a free shape has no sketch).
    case empty = "EMPTY"
    /// An opening's distance is past its wall: wall, limit the wall's length.
    case opPastWall = "OP_PAST_WALL"
    /// A door or window does not fit its wall: distance + width = value, the wall limit.
    case opNotFit = "OP_NOT_FIT"
    /// A window's sill + height (value) is above the room's height (limit).
    case opAboveCeiling = "OP_ABOVE_CEILING"
}

/// An error code with its values (see each ShapeErrorCode); wall is a wall index, lengths are mm.
struct ShapeError: Equatable {
    let code: ShapeErrorCode
    var wall: Int? = nil
    var value: Double? = nil
    var limit: Double? = nil
    var min: Double? = nil
    init(_ code: ShapeErrorCode, wall: Int? = nil, value: Double? = nil, limit: Double? = nil, min: Double? = nil) {
        self.code = code; self.wall = wall; self.value = value; self.limit = limit; self.min = min
    }
}

/// Walls (and the bay's sizes, the diagonal, door and window widths) are 300–20 000 mm.
let SHAPE_WALL_MIN = 300
let SHAPE_WALL_MAX = 20_000
/// The room's height is 2 000–6 000 mm, 2 700 the first time.
let SHAPE_HEIGHT_MIN = 2_000
let SHAPE_HEIGHT_MAX = 6_000
let SHAPE_HEIGHT_DEFAULT = 2_700
/// How far a typed diagonal may be off the walls' one, mm: the editor's (Geo.SK_TOL), so the room it makes says "ok".
let SHAPE_DIAG_TOL = 20.0

/* ---------------- the geometry (mockup geom) ---------------- */

/// One wall: index (letter shapeWallLetter), from corner `from` to `to` (before mirror and turn). len is the asked or
/// worked-out length (the free sketch's typed one). ask is the step that asks it, nil when it is worked out ("avtomat",
/// drawn dashed). angle: the cut wall's angle in whole degrees. bad: zero or negative.
struct ShapeWall: Equatable {
    let index: Int
    let len: Double
    let ask: Int?
    let from: Pt
    let to: Pt
    var angle: Int? = nil
    var bad = false
    var derived: Bool { ask == nil }
    var letter: String { shapeWallLetter(index) }
}

/// A size drawn as a guide line, not a wall (the bay's width and depth): from a to b, asked by step ask.
struct ShapeGuide: Equatable { let a: Pt; let b: Pt; let ask: Int }

/// A shape worked out from its values. corners before mirror and turn (an unclosed free sketch keeps its open end: one
/// corner more than walls); walls in order; error the first problem, nil when the room closes; values the asked values
/// with defaults filled in; gapFixed the free sketch's closing gap spread over its walls, mm; gap its gap when too big
/// to spread (drawn from the open end back to corner 0); guides the bay's width and depth lines.
struct ShapeGeo: Equatable {
    let spec: ShapeSpec
    let corners: [Pt]
    let walls: [ShapeWall]
    let error: ShapeError?
    let values: [Int]
    var gapFixed = 0.0
    var gap: Double? = nil
    var guides: [ShapeGuide] = []

    var ok: Bool { error == nil }
    /// The floor area, mm² (mockup Math.abs(area(pts))).
    var areaMm2: Double { abs(polygonArea(corners)) }
    /// The corners as drawn, after mirror and turn (mockup tf).
    var cornersShown: [Pt] { corners.map { shownPoint($0, spec) } }
    /// The bounding box's width and height, mm (the summary's "4 200 × 3 600 mm").
    var size: (w: Double, h: Double) {
        let xs = corners.map(\.x), ys = corners.map(\.y)
        let w = (xs.max() ?? 0) - (xs.min() ?? 0)
        let h = (ys.max() ?? 0) - (ys.min() ?? 0)
        return (w, h)
    }
}

/// A wall while the geometry is worked out.
private struct WallDraft {
    let ask: Int?
    let len: Double
    var bad = false
    var angle: Int? = nil
}

private func shapeDir(_ c: Character) -> Pt {
    switch c {
    case "R": return Pt(x: 1, y: 0)
    case "D": return Pt(x: 0, y: 1)
    case "L": return Pt(x: -1, y: 0)
    default: return Pt(x: 0, y: -1)
    }
}

/// The plan from the asked values (one per asks step; a missing or nil one takes its default), as the mockup's geom():
/// the corners, every wall, which are worked out, the cut's angle, the area and the first error.
func shapeGeometry(_ spec: ShapeSpec, _ values: [Int?]) -> ShapeGeo {
    let sh = spec.shape
    let P = asks(spec)
    let v: [Int] = P.indices.map { i -> Int in
        if i < values.count, let x = values[i] { return x }
        return P[i].def
    }
    let d: [Double] = v.map { Double($0) }
    var pts: [Pt] = []
    var E: [WallDraft] = []
    var err: ShapeError? = nil
    var guides: [ShapeGuide] = []
    var gapFixed = 0.0
    var gap: Double? = nil
    switch sh.kind {
    case .ortho:
        let dr: [Pt] = sh.dirs.map { shapeDir($0) }
        let n = dr.count
        var x = 0.0, y = 0.0
        pts.append(Pt(x: 0, y: 0))
        for i in 0..<(n - 2) {
            x += dr[i].x * d[i]
            y += dr[i].y * d[i]
            pts.append(Pt(x: x, y: y))
        }
        let a = dr[n - 2], b = dr[n - 1]
        let l1: Double, l2: Double
        if a.x != 0 { l1 = -x / a.x; l2 = -y / b.y } else { l1 = -y / a.y; l2 = -x / b.x }
        pts.append(Pt(x: x + a.x * l1, y: y + a.y * l1))
        for i in 0..<n {
            let asked = i < n - 2
            let len: Double = asked ? d[i] : (i == n - 2 ? l1 : l2)
            E.append(WallDraft(ask: asked ? i : nil, len: len))
        }
    case .cut:
        let W = d[0], r1 = d[1], bb = d[2], H = d[3]
        let cx = W - bb, cy = H - r1
        pts = [Pt(x: 0, y: 0), Pt(x: W, y: 0), Pt(x: W, y: r1), Pt(x: bb, y: H), Pt(x: 0, y: H)]
        let bad = cx <= 0 || cy <= 0
        let deg: Double = atan2(cy, cx) * 180 / Double.pi
        E = [WallDraft(ask: 0, len: W), WallDraft(ask: 1, len: r1),
             WallDraft(ask: nil, len: hypot(cx, cy), bad: bad, angle: kround(deg)),
             WallDraft(ask: 2, len: bb), WallDraft(ask: 3, len: H)]
        if bad { err = ShapeError(.cutNoCut) }
    case .bay:
        let W2 = d[0], D = d[1], p = d[2], w = d[3], dp = d[4]
        let fr = w - 2 * dp
        let rs = W2 - p - w
        let pw = p + w
        pts = [Pt(x: 0, y: 0), Pt(x: p, y: 0), Pt(x: p + dp, y: -dp), Pt(x: pw - dp, y: -dp),
               Pt(x: pw, y: 0), Pt(x: W2, y: 0), Pt(x: W2, y: D), Pt(x: 0, y: D)]
        let side: Double = dp * 2.0.squareRoot()
        E = [WallDraft(ask: 2, len: p), WallDraft(ask: nil, len: side), WallDraft(ask: nil, len: fr, bad: fr <= 0),
             WallDraft(ask: nil, len: side), WallDraft(ask: nil, len: rs, bad: rs <= 0), WallDraft(ask: nil, len: D),
             WallDraft(ask: 0, len: W2), WallDraft(ask: 1, len: D)]
        let mid = p + w / 2
        guides = [ShapeGuide(a: Pt(x: p, y: 0), b: Pt(x: pw, y: 0), ask: 3), ShapeGuide(a: Pt(x: mid, y: 0), b: Pt(x: mid, y: -dp), ask: 4)]
        if rs <= 0 { err = ShapeError(.bayNotFit, value: pw, limit: W2) }
        else if fr <= 0 { err = ShapeError(.bayTooDeep) }
    case .free:
        // a free card with no sketch (or under 3 walls) yet: nothing to draw, nothing to make
        guard let sk = spec.sketch, sk.dirs.count >= 3, sk.dirs.count == d.count else {
            return ShapeGeo(spec: spec, corners: [Pt(x: 0, y: 0)], walls: [], error: ShapeError(.empty), values: v)
        }
        let dr = sk.dirs
        let n2 = dr.count
        var x2 = 0.0, y2 = 0.0, per = 0.0
        pts.append(Pt(x: 0, y: 0))
        for j in 0..<n2 {
            x2 += dr[j].x * d[j]
            y2 += dr[j].y * d[j]
            per += d[j]
            pts.append(Pt(x: x2, y: y2))
        }
        let g = hypot(x2, y2)
        let tol = max(30, per * 0.01)
        if g <= tol {
            var cum = 0.0
            for j in 1...n2 {
                cum += d[j - 1]
                let px: Double = pts[j].x - x2 * cum / per
                let py: Double = pts[j].y - y2 * cum / per
                pts[j] = Pt(x: px, y: py)
            }
            pts.removeLast()
            gapFixed = g
        } else {
            gap = g
            err = ShapeError(.notClosed, value: g)
        }
        for j in 0..<n2 { E.append(WallDraft(ask: j, len: d[j])) }
    }
    let isOpen = gap != nil
    for k in E.indices where E[k].len <= 0.5 { E[k].bad = true }
    if err == nil {
        if let bi = E.firstIndex(where: { $0.bad }) { err = ShapeError(.wallNegative, wall: bi, value: E[bi].len) }
        else if !isSimplePolygon(pts) { err = ShapeError(.wallsCross) }
    }
    var walls: [ShapeWall] = []
    for (i, e) in E.enumerated() {
        let to = isOpen ? pts[i + 1] : pts[(i + 1) % pts.count]
        walls.append(ShapeWall(index: i, len: e.len, ask: e.ask, from: pts[i], to: to, angle: e.angle, bad: e.bad))
    }
    return ShapeGeo(spec: spec, corners: pts, walls: walls, error: err, values: v, gapFixed: gapFixed, gap: gap, guides: guides)
}

/// A plan point as drawn after mirror and turn (mockup tf): mirror flips x, then each turn maps (x, y) → (−y, x).
func shownPoint(_ p: Pt, _ spec: ShapeSpec) -> Pt {
    var x = p.x, y = p.y
    if spec.mirror { x = -x }
    for _ in 0..<spec.turn { let t = x; x = -y; y = t }
    return Pt(x: x, y: y)
}

/// The signed area, mm² (mockup area: positive when the corners run clockwise on screen, y down).
func polygonArea(_ pts: [Pt]) -> Double {
    var a = 0.0
    for i in pts.indices {
        let p = pts[i], q = pts[(i + 1) % pts.count]
        a += p.x * q.y - q.x * p.y
    }
    return a / 2
}

/// Whether a closed outline never crosses or touches itself (mockup simple).
func isSimplePolygon(_ p: [Pt]) -> Bool {
    let n = p.count
    for i in 0..<n {
        for j in (i + 1)..<max(i + 1, n) {
            if j == i + 1 || (i == 0 && j == n - 1) { continue }
            if shapeSegsMeet(p[i], p[(i + 1) % n], p[j], p[(j + 1) % n]) { return false }
        }
    }
    return true
}

private func shapeTurnSign(_ a: Pt, _ b: Pt, _ c: Pt) -> Int {
    let p: Double = (b.x - a.x) * (c.y - a.y)
    let q: Double = (b.y - a.y) * (c.x - a.x)
    let v = p - q
    if abs(v) < 1e-3 { return 0 }
    return v > 0 ? 1 : -1
}

private func shapeOnSeg(_ a: Pt, _ b: Pt, _ c: Pt) -> Bool {
    let e = 1e-6
    let inX = Swift.min(a.x, b.x) - e <= c.x && c.x <= Swift.max(a.x, b.x) + e
    let inY = Swift.min(a.y, b.y) - e <= c.y && c.y <= Swift.max(a.y, b.y) + e
    return inX && inY
}

private func shapeSegsMeet(_ a: Pt, _ b: Pt, _ c: Pt, _ d: Pt) -> Bool {
    let o1 = shapeTurnSign(a, b, c), o2 = shapeTurnSign(a, b, d), o3 = shapeTurnSign(c, d, a), o4 = shapeTurnSign(c, d, b)
    let apart = o1 != o2 && o3 != o4
    if apart && o1 != 0 && o2 != 0 && o3 != 0 && o4 != 0 { return true }
    if o1 == 0 && shapeOnSeg(a, b, c) { return true }
    if o2 == 0 && shapeOnSeg(a, b, d) { return true }
    if o3 == 0 && shapeOnSeg(c, d, a) { return true }
    if o4 == 0 && shapeOnSeg(c, d, b) { return true }
    return apart
}

/* ---------------- step errors (mockup wNext / stepErr) ---------------- */

/// A wall (or bay size) typed on the walls step: nil when 300–20 000 mm, else .outOfRange.
func wallValueError(_ v: Int?) -> ShapeError? {
    if let v, v >= SHAPE_WALL_MIN, v <= SHAPE_WALL_MAX { return nil }
    return ShapeError(.outOfRange, value: v.map { Double($0) }, limit: Double(SHAPE_WALL_MAX), min: Double(SHAPE_WALL_MIN))
}

/// The height step: nil when 2 000–6 000 mm, else .outOfRange.
func heightError(_ v: Int?) -> ShapeError? {
    if let v, v >= SHAPE_HEIGHT_MIN, v <= SHAPE_HEIGHT_MAX { return nil }
    return ShapeError(.outOfRange, value: v.map { Double($0) }, limit: Double(SHAPE_HEIGHT_MAX), min: Double(SHAPE_HEIGHT_MIN))
}

/// What stops "Keyingi" on walls step `step`, with values holding everything typed so far including this step's value
/// (mockup wNext + stepErr). Each error shows on the step where it becomes knowable: the range at once; the cut from its
/// D step (D < A) and E step (B < E); the bay's "doesn't fit" from its width step and "too deep" at the depth step;
/// anything else (a wall worked out negative, crossing walls, the free sketch not closing) on the last step, or on any
/// step when editingOne (changing one value from the summary).
func stepError(_ spec: ShapeSpec, _ values: [Int?], _ step: Int, editingOne: Bool = false) -> ShapeError? {
    let typed: Int? = step >= 0 && step < values.count ? values[step] : nil
    if let e = wallValueError(typed) { return e }
    let n = asks(spec).count
    let last = step >= n - 1 || editingOne
    let g = shapeGeometry(spec, values)
    let v = g.values
    switch spec.shape.kind {
    case .cut:
        if step >= 2 && v[0] - v[2] <= 0 { return ShapeError(.cutDNotShorter, wall: 3, limit: Double(v[0])) }
        if step >= 3 && v[3] - v[1] <= 0 { return ShapeError(.cutBNotShorter, wall: 1, limit: Double(v[3])) }
        return last ? g.error : nil
    case .bay:
        if step >= 3 && g.error?.code == .bayNotFit { return g.error }
        if step >= 4 { return g.error }
        return last ? g.error : nil
    default:
        return last ? g.error : nil
    }
}

/* ---------------- the diagonal (free sketch, optional) ---------------- */

/// The diagonal runs from corner 0 to this corner (mockup diagK: half the asked walls).
func diagonalCorner(_ spec: ShapeSpec) -> Int { asks(spec).count / 2 }

/// The diagonal the walls give, mm (the field's hint is this rounded to 10 mm); 0 when the shape has no such corner.
func expectedDiagonal(_ g: ShapeGeo) -> Double {
    let k = diagonalCorner(g.spec)
    guard k > 0, k < g.corners.count else { return 0 }
    let a = g.corners[0], b = g.corners[k]
    return hypot(a.x - b.x, a.y - b.y)
}

/// A typed diagonal: out of range, or off the walls' by more than 20 mm (.diagMismatch, the editor's own tolerance, so
/// the room shows it "ok"); nil when it matches.
func diagonalError(_ spec: ShapeSpec, _ values: [Int?], _ diag: Int?) -> ShapeError? {
    if let e = wallValueError(diag) { return e }
    guard let dg = diag else { return ShapeError(.empty) }
    let d = expectedDiagonal(shapeGeometry(spec, values))
    if abs(Double(dg) - d) > SHAPE_DIAG_TOL { return ShapeError(.diagMismatch, value: Double(dg), limit: d) }
    return nil
}

/* ---------------- doors, windows and pipes on the plan (mockup OP, opNext, opHint) ---------------- */

/// What the "Eshik, deraza, suv, gaz bormi?" step adds: a door, a window, cold water, the sewer or a gas pipe.
enum OpKind: String, CaseIterable, Equatable {
    case door = "door", window = "window", water = "water", sewer = "sewer", gas = "gas"
    var id: String { rawValue }
    /// A door or window (an opening in the wall), not a pipe (a site point).
    var isOpening: Bool { self == .door || self == .window }
    /// The site point type a pipe becomes ("cold", "sewer", "gas"); the opening type for a door or window.
    var roomType: String {
        switch self {
        case .water: return "cold"
        default: return rawValue
        }
    }
}

/// One field of an added item: the distance from the wall's start corner (the dot), the width, the height, a window's sill.
enum OpField: Equatable { case dist, width, height, sill }

/// A field asked for an item, in order, with the value it starts from.
struct OpAsk: Equatable { let field: OpField; let def: Int }

/// The fields each kind asks (a window's sill is prefilled with 900, BUILD_SPEC §2.6).
func opAsks(_ kind: OpKind) -> [OpAsk] {
    switch kind {
    case .door: return [OpAsk(field: .dist, def: 600), OpAsk(field: .width, def: 900), OpAsk(field: .height, def: 2100)]
    case .window: return [OpAsk(field: .dist, def: 900), OpAsk(field: .width, def: 1500), OpAsk(field: .height, def: 1500), OpAsk(field: .sill, def: 900)]
    case .water: return [OpAsk(field: .dist, def: 400)]
    case .sewer: return [OpAsk(field: .dist, def: 700)]
    case .gas: return [OpAsk(field: .dist, def: 1200)]
    }
}

/// An item added on the plan: on shape wall `wall`, dist mm from that wall's start corner (ShapeWall.from, the dot) to
/// the door's or window's near edge, or to the pipe. w, h and sill for doors and windows only.
struct ShapeOpening: Equatable {
    var kind: OpKind
    var wall: Int
    var dist: Int
    var w = 0
    var h = 0
    var sill = 0
    init(_ kind: OpKind, _ wall: Int, _ dist: Int, _ w: Int = 0, _ h: Int = 0, _ sill: Int = 0) {
        self.kind = kind; self.wall = wall; self.dist = dist; self.w = w; self.h = h; self.sill = sill
    }
}

/// The value a field starts from on wall `wall` (mockup opHint): the default, shrunk so it fits the wall; dist, w and
/// h are the fields typed before it.
func opHint(_ g: ShapeGeo, _ roomHeight: Int, _ kind: OpKind, _ wall: Int, _ field: OpField, dist: Int = 0, w: Int = 0, h: Int = 0) -> Int {
    let f = opAsks(kind)
    let def = f.first { $0.field == field }?.def ?? 0
    let L = wall >= 0 && wall < g.walls.count ? g.walls[wall].len : 0
    switch field {
    case .dist:
        let ww = f.count > 1 ? f[1].def : 0
        let room = Int(((L - Double(ww) - 100) / 10).rounded(.down)) * 10
        return Swift.max(0, Swift.min(def, room))
    case .width:
        let room = Int(((L - Double(dist)) / 10).rounded(.down)) * 10
        return Swift.max(SHAPE_WALL_MIN, Swift.min(def, room))
    case .height:
        return Swift.min(def, roomHeight)
    case .sill:
        return Swift.max(0, Swift.min(def, roomHeight - h))
    }
}

/// What stops "Keyingi" on an item's field (mockup opNext): value typed for field; dist, w, h typed before. Distance:
/// at most the wall. Width: 300–20 000 and distance + width within the wall. Height: 300 up to the room's height.
/// Sill: sill + height up to the room's height.
func opFieldError(_ g: ShapeGeo, _ roomHeight: Int, _ kind: OpKind, _ wall: Int, _ field: OpField, _ value: Int?,
                  dist: Int = 0, w: Int = 0, h: Int = 0) -> ShapeError? {
    guard let value else { return ShapeError(.empty) }
    guard wall >= 0, wall < g.walls.count else { return ShapeError(.empty) }
    let L = g.walls[wall].len
    let x = Double(value)
    switch field {
    case .dist:
        if value < 0 { return ShapeError(.outOfRange, value: x, limit: L, min: 0) }
        if x > L { return ShapeError(.opPastWall, wall: wall, value: x, limit: L) }
        return nil
    case .width:
        if let e = wallValueError(value) { return e }
        let total = dist + value
        if Double(total) > L { return ShapeError(.opNotFit, wall: wall, value: Double(total), limit: L) }
        return nil
    case .height:
        if value < SHAPE_WALL_MIN || value > roomHeight {
            return ShapeError(.outOfRange, value: x, limit: Double(roomHeight), min: Double(SHAPE_WALL_MIN))
        }
        return nil
    case .sill:
        if value < 0 { return ShapeError(.outOfRange, value: x, limit: Double(roomHeight - h), min: 0) }
        if value + h > roomHeight { return ShapeError(.opAboveCeiling, value: Double(value + h), limit: Double(roomHeight)) }
        return nil
    }
}

/// The first problem with a whole item, field by field, or nil.
func openingError(_ g: ShapeGeo, _ roomHeight: Int, _ op: ShapeOpening) -> ShapeError? {
    guard op.wall >= 0, op.wall < g.walls.count else { return ShapeError(.empty) }
    for a in opAsks(op.kind) {
        let v: Int
        switch a.field {
        case .dist: v = op.dist
        case .width: v = op.w
        case .height: v = op.h
        case .sill: v = op.sill
        }
        if let e = opFieldError(g, roomHeight, op.kind, op.wall, a.field, v, dist: op.dist, w: op.w, h: op.h) { return e }
    }
    return nil
}
