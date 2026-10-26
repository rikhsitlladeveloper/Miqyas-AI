import Foundation

/*
 * Room geometry and the rules for typed values, ported line for line from the Android app's geo/Geometry.kt (itself
 * from the prototype: core areas/roomWalls/openingIssue/parseDec, sketch skGeo/skSolve). Pure Swift, no UI.
 * All lengths are millimetres (Int), areas mm² (Int64). Plan y points down; corners and walls run clockwise.
 */

enum LenUnit { case m, cm, mm }

/// The strings key of a unit's short name: "u.m", "u.cm" or "u.mm".
func unitKey(_ u: LenUnit) -> String { u == .cm ? "u.cm" : u == .mm ? "u.mm" : "u.m" }

/// Kotlin's roundToInt (Math.round: halves go up), so both apps solve the same shapes to the same millimetre.
func kround(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

enum Parsed: Equatable {
    case ok(Int64)
    case err(String, [String: String])
    var value: Int64? { if case .ok(let v) = self { return v }; return nil }
}

enum Geo {
    /// Limits of a typed dimension, mm (prototype DIM_MAX); a room is at most 6 m high.
    static let DIM_MAX: [String: Int] = ["A": 100_000, "B": 100_000, "H": 6_000, "T": 2_000]
    static func dimMax(_ k: String) -> Int { DIM_MAX[k] ?? 100_000 }

    /// The least a room's measurement may be, mm: a rectangle's side 0,5 m, the height 1,8 m (a drawn room's walls may be short).
    static func dimMin(_ k: String, _ poly: Bool) -> Int {
        if k == "H" { return 1_800 }
        if !poly && (k == "A" || k == "B") { return 500 }
        return 0
    }

    /// What keeps a reading mm off measurement k, as a typed value: ("err.min", the least) or ("err.max", the most); nil when it fits.
    static func readingLimit(_ k: String, _ mm: Int, _ poly: Bool) -> (String, Int)? {
        let lo = dimMin(k, poly), hi = dimMax(k)
        if mm >= 1 && mm < lo { return ("err.min", lo) }
        if mm > hi { return ("err.max", hi) }
        return nil
    }

    /// A height above this is unusual: said under the field (it may be right: a hall, a loft).
    static let H_TALL = 4_500

    /* ---------------- units and number formats ---------------- */

    static func decMark(_ en: Bool) -> String { en ? "." : "," }

    /// Length as the prototype's fmtLen: metres with 2 decimals (3 when the mm need it), or centimetres with 0 or 1.
    static func fmtLen(_ mm: Int?, _ unit: LenUnit = .m, _ en: Bool = false, full: Bool = false) -> String {
        guard let mm else { return "?" }
        // furniture makers' millimetres: whole numbers, no decimals ("3400")
        if unit == .mm { return "\(mm)" }
        let s = unit == .cm ? String(format: "%.\(full || mm % 10 != 0 ? 1 : 0)f", Double(mm) / 10)
                            : String(format: "%.\(full ? 3 : mm % 10 != 0 ? 3 : 2)f", Double(mm) / 1000)
        return s.replacingOccurrences(of: ".", with: decMark(en))
    }

    /// Area mm² as m² with 2 decimals.
    static func fmtArea(_ mm2: Int64?, _ en: Bool = false) -> String {
        guard let mm2 else { return "?" }
        return String(format: "%.2f", Double(mm2) / 1e6).replacingOccurrences(of: ".", with: decMark(en))
    }

    /// A value to put back into a field: as shown, with all decimals when the mm need them (prototype fm()).
    static func fmtField(_ mm: Int, _ unit: LenUnit, _ en: Bool) -> String { fmtLen(mm, unit, en, full: mm % 10 != 0) }

    /* ---------------- typed values (prototype parseDec / lenErr) ---------------- */

    private static let spaces = try! NSRegularExpression(pattern: "[\\s\\u00A0\\u202F]")
    private static let okShape = try! NSRegularExpression(pattern: "^-?\\d*([.,]\\d*)?$")
    private static let emptyShape = try! NSRegularExpression(pattern: "^-?[.,]?$")
    private static func full(_ re: NSRegularExpression, _ s: String) -> Bool { re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil }

    /// Parses "4,255", "4.255", "04.250", "4 255", ".5"; rejects "4.2.1", "1e3", "-1". Returns the value scaled by
    /// 10^maxDec (so with the unit's decimals it is millimetres).
    static func parseDec(_ str: String?, _ maxDec: Int) -> Parsed {
        let raw = str ?? ""
        let s = spaces.stringByReplacingMatches(in: raw, range: NSRange(raw.startIndex..., in: raw), withTemplate: "")
        if s.isEmpty { return .err("err.empty", [:]) }
        if !full(okShape, s) || full(emptyShape, s) { return .err("err.format", [:]) }
        if s.hasPrefix("-") { return .err("err.negative", [:]) }
        let parts = s.replacingOccurrences(of: ",", with: ".").split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let i = parts[0], f = parts.count > 1 ? parts[1] : ""
        if f.count > maxDec { return .err("err.precision", ["n": "\(maxDec)"]) }
        let digits = (i.isEmpty ? "0" : i) + f.padding(toLength: maxDec, withPad: "0", startingAt: 0)
        // at most Int32.max, so a huge number stays huge and sums of lengths never overflow
        return .ok(min(Int64(digits) ?? Int64.max, Int64(Int32.max)))
    }

    static func unitDecimals(_ unit: LenUnit) -> Int { unit == .mm ? 0 : unit == .cm ? 1 : 3 }

    /// A typed length in mm, or the error (key + values) to show. max in mm; zeroOk for an offset or a sill.
    static func lenErr(_ str: String?, _ max: Int, _ unit: LenUnit, _ en: Bool, zeroOk: Bool = false, min: Int = 0) -> Parsed {
        let r = parseDec(str, unitDecimals(unit))
        guard let mm = r.value else { return r }
        if mm == 0 && !zeroOk { return .err("err.zero", [:]) }
        if mm >= 1 && mm < Int64(min) {
            var m = fmtLen(min, unit, en)
            if let rg = m.range(of: "[.,]0+$", options: .regularExpression) { m.removeSubrange(rg) }
            return .err("err.min", ["min": m + " " + "@" + unitKey(unit)])
        }
        if mm > Int64(max) {
            var m = fmtLen(max, unit, en)
            if let rg = m.range(of: "[.,]0+$", options: .regularExpression) { m.removeSubrange(rg) }
            return .err("err.max", ["max": m + " " + "@" + unitKey(unit)])
        }
        return .ok(mm)
    }

    /* ---------------- walls ---------------- */

    /// One wall, clockwise; dimKey holds its length; derived walls (rect C and D, computed polygon walls) follow others.
    struct Wall: Equatable { let id: String; let corner: Int; let len: Int?; let dimKey: String; let derived: Bool; let p0: Pt; let p1: Pt; var status = "" }

    /// The walls of a room (prototype roomWalls). Rect: A, B measured; C = A, D = B. Polygon: from the solved shape.
    static func walls(_ r: Room, _ snap: Bool = true) -> [Wall] {
        if r.isPoly { return polyGeo(r, snap).walls }
        let a = r.dim("A"), b = r.dim("B")
        let L = Double(a.v ?? a.pending?.mm ?? 5000), W = Double(b.v ?? b.pending?.mm ?? 4000)
        return [
            Wall(id: "A", corner: 1, len: a.v, dimKey: "A", derived: false, p0: Pt(x: 0, y: 0), p1: Pt(x: L, y: 0)),
            Wall(id: "B", corner: 2, len: b.v, dimKey: "B", derived: false, p0: Pt(x: L, y: 0), p1: Pt(x: L, y: W)),
            Wall(id: "C", corner: 3, len: a.v, dimKey: "A", derived: true, p0: Pt(x: L, y: W), p1: Pt(x: 0, y: W)),
            Wall(id: "D", corner: 4, len: b.v, dimKey: "B", derived: true, p0: Pt(x: 0, y: W), p1: Pt(x: 0, y: 0)),
        ]
    }

    static func wallLen(_ r: Room, _ id: String, _ snap: Bool = true) -> Int? { walls(r, snap).first { $0.id == id }?.len }
    static func wallCorner(_ r: Room, _ id: String, _ snap: Bool = true) -> Int { walls(r, snap).first { $0.id == id }?.corner ?? 1 }

    /// The measurements the builder takes, in order (prototype hmDimKeys): the non-derived walls, then the height.
    static func stepKeys(_ r: Room, _ snap: Bool = true) -> [String] {
        var seen: [String] = []
        for w in walls(r, snap) where !w.derived && !seen.contains(w.dimKey) { seen.append(w.dimKey) }
        return seen + ["H"]
    }

    /* ---------------- areas ---------------- */

    struct Areas: Equatable { let floor: Int64; let perim: Int64; let gross: Int64?; let open: Int64?; let net: Int64? }

    /// Floor, perimeter, wall areas from confirmed values only (prototype areas()); nil until the floor is known.
    static func areas(_ r: Room, _ snap: Bool = true) -> Areas? {
        let H = r.dim("H").v
        let floor: Int64, perim: Int64
        if r.isPoly {
            let g = polyGeo(r, snap)
            guard g.solved else { return nil }
            floor = Int64(abs(shoelace(g.verts)).rounded())
            perim = g.walls.reduce(Int64(0)) { $0 + Int64($1.len ?? 0) }
        } else {
            guard let L = r.dim("A").v, let W = r.dim("B").v else { return nil }
            floor = Int64(L) * Int64(W); perim = 2 * Int64(L + W)
        }
        // columns take floor and add their two sides to the walls; a niche from the floor adds floor and its sides
        let fx = r.features
        let floorF = floor - fx.filter { $0.type == "column" }.reduce(Int64(0)) { $0 + Int64($1.w) * Int64($1.d) }
            + fx.filter { $0.type == "niche" && $0.sill == 0 }.reduce(Int64(0)) { $0 + Int64($1.w) * Int64($1.d) }
        let ws: [Wall] = fx.contains { $0.type == "column" } ? walls(r, snap) : []
        // a column's side flush with a corner is no wall: it covers that much of the next wall instead (-d, not +d)
        func colSides(_ f: Feature) -> Int64 {
            let len = ws.first { $0.id == f.wall }?.len
            let a: Int64 = f.off <= 0 ? -1 : 1
            let b: Int64 = (len.map { f.off + f.w >= $0 } ?? false) ? -1 : 1
            return (a + b) * Int64(f.d)
        }
        let perimF = perim + fx.reduce(Int64(0)) { a, f in
            if f.type == "column" { return a + colSides(f) }
            return f.sill == 0 ? a + 2 * Int64(f.d) : a
        }
        guard let H else { return Areas(floor: floorF, perim: perimF, gross: nil, open: nil, net: nil) }
        let extra = fx.reduce(Int64(0)) { a, f in
            if f.type == "column" { return a + colSides(f) * Int64(H) }
            // a niche the room's height no longer reaches has nothing inside (and never a negative area)
            let nh = Int64(max(0, min(f.h > 0 ? f.h : H - f.sill, H - f.sill)))
            if nh == 0 { return a }
            return a + 2 * Int64(f.d) * nh + (f.sill > 0 ? Int64(f.w) * Int64(f.d) : 0) + (Int64(f.sill) + nh < Int64(H) ? Int64(f.w) * Int64(f.d) : 0)
        }
        let gross = perim * Int64(H) + extra
        let open = r.openings.reduce(Int64(0)) { $0 + Int64($1.w) * Int64($1.h) }
        return Areas(floor: floorF, perim: perimF, gross: gross, open: open, net: gross - open)
    }

    /// What is wrong with a column or niche f in room r: off the wall's end, too deep or sticking out too far. Nil when it fits.
    static func featureIssue(_ r: Room, _ f: Feature, _ snap: Bool = true) -> String? {
        let ws = walls(r, snap)
        guard let L = ws.first(where: { $0.id == f.wall })?.len else { return "ft.needWall" }
        if f.w <= 0 || f.d <= 0 { return "ft.size" }
        if f.off + f.w > L { return "ft.exceeds" }
        if f.type == "niche" && f.d > 1000 { return "ft.deep" }
        // a column sticks out into the room: at most 2 m, and less than the room's shorter side
        if f.type == "column" && (f.d > 2000 || ws.compactMap(\.len).min().map { f.d >= $0 } == true) { return "ft.colDeep" }
        if f.type == "niche", let H = r.dim("H").v, f.sill + (f.h > 0 ? f.h : 0) > H { return "ft.tall" }
        return nil
    }

    struct WallStats: Equatable { let gross: Int64?; let open: Int64; let net: Int64? }

    /// One wall's areas (prototype wvWallStats).
    static func wallStats(_ len: Int?, _ H: Int?, _ ops: [Opening]) -> WallStats {
        let open = ops.reduce(Int64(0)) { $0 + Int64($1.w) * Int64($1.h) }
        guard let len, let H else { return WallStats(gross: nil, open: open, net: nil) }
        let g = Int64(len) * Int64(H)
        return WallStats(gross: g, open: open, net: g - open)
    }

    /* ---------------- doors and windows (prototype openingIssue) ---------------- */

    struct Issue: Equatable { let field: String; let key: String; let vars: [String: String] }

    /// The first problem with o in room r, or nil. kindName is the localised "Eshik"/"Deraza".
    static func openingIssue(_ r: Room, _ o: Opening, _ kindName: String, _ unit: LenUnit, _ en: Bool, _ snap: Bool = true) -> Issue? {
        let w = walls(r, snap).first { $0.id == o.wall }
        guard let L = w?.len else { return Issue(field: "wall", key: "op.needWall", vars: ["w": w?.derived == true ? w!.dimKey : o.wall]) }
        if o.off + o.w > L { return Issue(field: "w", key: "op.exceeds", vars: ["o": kindName, "x": fmtLen(o.off + o.w - L, .m, en)]) }
        // a door has no sill: only its height can give way
        if let H = r.dim("H").v, o.sill + o.h > H {
            let key = o.type == "door" ? "op.tooTallDoor" : "op.tooTall"
            return Issue(field: "h", key: key, vars: ["o": kindName, "x": fmtLen(o.sill + o.h - H, .m, en)])
        }
        for x in r.openings where x.id != o.id && x.wall == o.wall && o.off < x.off + x.w && x.off < o.off + o.w {
            return Issue(field: "off", key: "op.overlap", vars: ["o": kindName])
        }
        return nil
    }

    /* ---------------- statuses and the next step ---------------- */

    /// How many of the room's measurements are not confirmed (prototype unconfCount).
    static func unconfCount(_ r: Room, _ snap: Bool = true) -> Int {
        if !r.isPoly { return ["A", "B", "H"].filter { r.dim($0).status != "conf" }.count }
        let g = polyGeo(r, snap)
        return g.walls.filter { $0.status != "conf" && $0.status != "calc" }.count + (r.dim("H").status != "conf" ? 1 : 0)
            + g.diagStatus.values.filter { $0 == "recv" || $0 == "unset" || $0 == "warn" }.count
    }

    /// Every measurement confirmed, no reading waiting, and no door or window problem.
    static func allConfirmed(_ r: Room, _ issues: Int, _ snap: Bool = true) -> Bool { stepKeys(r, snap).allSatisfy { r.dim($0).status == "conf" } && issues == 0 }

    /// A, B and H known (pending ignored): enough for 3D (prototype room3DReady).
    static func ready3D(_ r: Room, _ snap: Bool = true) -> Bool {
        r.isPoly ? polyGeo(r, snap).solved && r.dim("H").v != nil : r.dim("A").v != nil && r.dim("B").v != nil && r.dim("H").v != nil
    }

    /* ---------------- polygons: the solver (prototype skGeo / skSolve) ---------------- */

    static let SK_LETTERS = Array("ABCDEFGJKLMNPQRSUVWYZ")
    static let SK_TOL = 20.0
    private static let EPS = 1e-6

    static func polyWallIds(_ n: Int) -> [String] { SK_LETTERS.prefix(n).map(String.init) }

    struct PolyGeo {
        var verts: [Pt]                 // solved corners, or the sketch's when not solved
        var walls: [Wall]
        var solved: Bool
        var err: String? = nil          // closure, negative, cross
        var conflict: [String] = []
        var either: [String] = []
        var measure: [String] = []
        var some = 0
        var computed: [String] = []
        var diagStatus: [String: String] = [:]
        var diagLen: [String: Int] = [:]
        var gap = 0                     // how far the measured walls miss closing, mm (err closure)
    }

    static func snapAngle(_ a: Double) -> Double { let st = Double.pi / 4; return Double(kround(a / st)) * st }

    private struct Solve { var status: String; var len: [Double?]; var err: String? = nil; var errVec: (Double, Double)? = nil
                           var either: [Int] = []; var measure: [Int] = []; var keep: [Int] = []; var some = 0 }

    private static func solve(_ dirs: [Double], _ lens: [Double?]) -> Solve {
        let n = dirs.count
        let ux = dirs.map { cos($0) }, uy = dirs.map { sin($0) }
        var kx = 0.0, ky = 0.0
        var unk: [Int] = []
        for i in 0..<n { if let l = lens[i] { kx += l * ux[i]; ky += l * uy[i] } else { unk.append(i) } }
        var out = lens
        switch unk.count {
        case 0:
            return hypot(kx, ky) > SK_TOL ? Solve(status: "conflict", len: out, err: "closure", errVec: (kx, ky)) : Solve(status: "solved", len: out)
        case 1:
            let k = unk[0]
            let l = -(kx * ux[k] + ky * uy[k])
            let ex = kx + l * ux[k], ey = ky + l * uy[k]
            if hypot(ex, ey) > SK_TOL { return Solve(status: "conflict", len: out, err: "closure", errVec: (ex, ey)) }
            if l <= SK_TOL { return Solve(status: "conflict", len: out, err: "negative", errVec: (kx, ky)) }
            out[k] = Double(kround(l)); return Solve(status: "solved", len: out)
        case 2:
            let a = unk[0], b = unk[1]
            let det = ux[a] * uy[b] - uy[a] * ux[b]
            if abs(det) > EPS {
                let la = (-kx * uy[b] + ky * ux[b]) / det
                let lb = (kx * uy[a] - ky * ux[a]) / det
                if la <= SK_TOL || lb <= SK_TOL { return Solve(status: "conflict", len: out, err: "negative", errVec: (kx, ky)) }
                out[a] = Double(kround(la)); out[b] = Double(kround(lb)); return Solve(status: "solved", len: out)
            }
            let perp = abs(kx * -uy[a] + ky * ux[a])
            return perp > SK_TOL ? Solve(status: "conflict", len: out, err: "closure", errVec: (kx, ky)) : Solve(status: "unresolved", len: out, either: [a, b])
        default:
            for i in stride(from: unk.count - 1, through: 0, by: -1) {
                for j in stride(from: i - 1, through: 0, by: -1) {
                    let a = unk[j], b = unk[i]
                    if abs(ux[a] * uy[b] - uy[a] * ux[b]) > EPS { return Solve(status: "unresolved", len: out, measure: unk.filter { $0 != a && $0 != b }, keep: [a, b]) }
                }
            }
            return Solve(status: "unresolved", len: out, measure: unk, some: unk.count - 1)
        }
    }

    static func buildVerts(_ dirs: [Double], _ len: [Double], _ start: Pt) -> [Pt] {
        var v: [Pt] = []; var x = start.x, y = start.y
        for i in dirs.indices { v.append(Pt(x: x, y: y)); x += len[i] * cos(dirs[i]); y += len[i] * sin(dirs[i]) }
        return v
    }

    static func shoelace(_ v: [Pt]) -> Double {
        var s = 0.0
        for i in v.indices { let a = v[i], b = v[(i + 1) % v.count]; s += a.x * b.y - b.x * a.y }
        return s / 2
    }

    private struct GeoKey: Equatable { let snap: Bool; let poly: Poly?; let dims: [String: Dim] }
    private static var geoCache: [String: (GeoKey, PolyGeo)] = [:]
    /// The tile previews and counts are worked out off the main thread while the screens read the cache too.
    private static let geoLock = NSLock()

    /// Solves a drawn room from its measured walls (prototype skGeo). Cached on the room's shape, dims and snap. The
    /// room's own snap (Poly.snap) wins; snap is only for a room that has none (an old quote's rooms: the quote's snap).
    static func polyGeo(_ r: Room, _ snap: Bool = true) -> PolyGeo {
        let own = r.poly?.snap ?? snap
        let key = GeoKey(snap: own, poly: r.poly, dims: r.dims)
        geoLock.lock()
        let hit = geoCache[r.id]
        geoLock.unlock()
        if let e = hit, e.0 == key { return e.1 }
        let g = computePolyGeo(r, own)
        geoLock.lock()
        if geoCache.count > 200 { geoCache.removeAll() }
        geoCache[r.id] = (key, g)
        geoLock.unlock()
        return g
    }

    private static func computePolyGeo(_ r: Room, _ snap: Bool) -> PolyGeo {
        let V = r.poly!.verts, n = V.count
        let ids = polyWallIds(n)
        let dirs = (0..<n).map { i -> Double in let a = V[i], b = V[(i + 1) % n]; let t = atan2(b.y - a.y, b.x - a.x); return snap ? snapAngle(t) : t }
        let lens = ids.map { r.dim($0).v.map(Double.init) }
        let s = solve(dirs, lens)
        var solved = s.status == "solved"
        var err = s.err
        let computed = solved ? ids.indices.filter { lens[$0] == nil }.map { ids[$0] } : []
        var conflict: [String] = []
        var verts = V
        if s.status == "conflict", let ev = s.errVec {
            let ex = ev.0, ey = ev.1
            let mm = hypot(ex, ey), m = mm > EPS ? mm : 1
            conflict = ids.indices.filter { lens[$0] != nil && abs(cos(dirs[$0]) * ex / m + sin(dirs[$0]) * ey / m) > 0.05 }.map { ids[$0] }
        }
        if solved {
            let built = buildVerts(dirs, s.len.map { $0! }, V[0])
            if selfIntersects(built) != nil {
                solved = false; err = "cross"
                conflict = computed.isEmpty ? ids.indices.filter { lens[$0] != nil }.map { ids[$0] } : computed
            } else { verts = built }
        }
        let either = s.either.map { ids[$0] }
        let walls = ids.enumerated().map { i, id -> Wall in
            let d = r.dim(id)
            let st: String = d.pending != nil ? "recv" : d.v != nil && conflict.contains(id) ? "bad" : d.v != nil ? "conf"
                : solved && computed.contains(id) ? "calc" : either.contains(id) ? "unres" : "unset"
            let len = d.v ?? (solved ? s.len[i].map { kround($0) } : nil)
            return Wall(id: id, corner: i + 1, len: len, dimKey: id, derived: computed.contains(id) && solved, p0: verts[i], p1: verts[(i + 1) % n], status: st)
        }
        var diagStatus: [String: String] = [:], diagLen: [String: Int] = [:]
        for dg in r.poly!.diags {
            let d = r.dim(dg.id)
            let st: String
            if d.pending != nil { st = "recv" }
            else if d.v == nil { st = "unset" }
            else if !solved { st = "conf" }
            else {
                let dist = kround(hypot(verts[dg.a].x - verts[dg.b].x, verts[dg.a].y - verts[dg.b].y))
                diagLen[dg.id] = dist
                st = Double(abs(d.v! - dist)) <= SK_TOL ? "ok" : "warn"
            }
            diagStatus[dg.id] = st
        }
        let gap = s.err == "closure" ? (s.errVec.map { kround(hypot($0.0, $0.1)) } ?? 0) : 0
        return PolyGeo(verts: verts, walls: walls, solved: solved, err: solved ? nil : err, conflict: conflict, either: either,
                       measure: s.measure.map { ids[$0] }, some: s.some, computed: solved ? computed : [], diagStatus: diagStatus, diagLen: diagLen, gap: gap)
    }

    /* ---------------- polygons: shape checks ---------------- */

    private static func cross(_ ax: Double, _ ay: Double, _ bx: Double, _ by: Double) -> Double { ax * by - ay * bx }

    /// Whether segments p1p2 and p3p4 meet (touching included).
    private static func segHit(_ p1: Pt, _ p2: Pt, _ p3: Pt, _ p4: Pt) -> Pt? {
        let d1x = p2.x - p1.x, d1y = p2.y - p1.y, d2x = p4.x - p3.x, d2y = p4.y - p3.y
        let den = cross(d1x, d1y, d2x, d2y)
        if abs(den) < EPS {
            // collinear overlap
            if abs(cross(p3.x - p1.x, p3.y - p1.y, d1x, d1y)) > EPS { return nil }
            let len2 = d1x * d1x + d1y * d1y; if len2 < EPS { return nil }
            let t3 = ((p3.x - p1.x) * d1x + (p3.y - p1.y) * d1y) / len2
            let t4 = ((p4.x - p1.x) * d1x + (p4.y - p1.y) * d1y) / len2
            return max(t3, t4) >= 0 && min(t3, t4) <= 1 ? Pt(x: p3.x, y: p3.y) : nil
        }
        let t = cross(p3.x - p1.x, p3.y - p1.y, d2x, d2y) / den
        let u = cross(p3.x - p1.x, p3.y - p1.y, d1x, d1y) / den
        return t >= -EPS && t <= 1 + EPS && u >= -EPS && u <= 1 + EPS ? Pt(x: p1.x + t * d1x, y: p1.y + t * d1y) : nil
    }

    /// The point where a closed outline crosses itself, or nil (prototype skSelfX).
    static func selfIntersects(_ v: [Pt]) -> Pt? {
        let n = v.count
        for i in 0..<n { let a = v[i], b = v[(i + 1) % n]; if hypot(b.x - a.x, b.y - a.y) < EPS { return a } }
        for i in 0..<n {
            for j in (i + 1)..<max(i + 1, n) {
                let adj = j == i + 1 || (i == 0 && j == n - 1)
                let a1 = v[i], a2 = v[(i + 1) % n], b1 = v[j], b2 = v[(j + 1) % n]
                if adj {
                    // a wall folding back on the next one
                    let shared = j == i + 1 ? a2 : a1
                    let o1 = j == i + 1 ? a1 : a2, o2 = j == i + 1 ? b2 : b1
                    let c = cross(o1.x - shared.x, o1.y - shared.y, o2.x - shared.x, o2.y - shared.y)
                    let dot = (o1.x - shared.x) * (o2.x - shared.x) + (o1.y - shared.y) * (o2.y - shared.y)
                    if abs(c) < EPS && dot > 0 { return shared }
                    continue
                }
                if let h = segHit(a1, a2, b1, b2) { return h }
            }
        }
        return nil
    }

    /// Clockwise on screen (y down), first corner the top-most, then left-most (prototype skOrient).
    static func orient(_ v: [Pt]) -> [Pt] {
        var p = v
        if shoelace(p) < 0 { p.reverse() }
        let minY = p.map(\.y).min()!, maxY = p.map(\.y).max()!
        let tol = 0.01 * (maxY - minY) + EPS
        let start = p.indices.filter { p[$0].y <= minY + tol }.min { p[$0].x < p[$1].x }!
        return Array(p[start...]) + Array(p[..<start])
    }

    /// The L-shaped template: 6 walls A–F (prototype SK_LSHAPE).
    static let L_SHAPE = [Pt(x: 0, y: 0), Pt(x: 3000, y: 0), Pt(x: 3000, y: 1500), Pt(x: 6000, y: 1500), Pt(x: 6000, y: 5000), Pt(x: 0, y: 5000)]

    /// A new drawn room with one empty measurement per wall (prototype skMakeRoom).
    static func polyDims(_ n: Int) -> [String: Dim] {
        var d: [String: Dim] = [:]
        for id in polyWallIds(n) { d[id] = Dim() }
        d["H"] = Dim(); d["T"] = Dim(v: 200, src: "default")
        return d
    }
}
