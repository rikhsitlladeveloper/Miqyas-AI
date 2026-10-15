import Foundation

/*
 * Turning a finger stroke or tapped corners into a room outline (prototype skProcess, skClean, skSnapPoly), ported from
 * the Android app's geo/Sketch.kt. Works in sketch-pad units: the pad is 360 × 440 units and 1 unit = 25 mm (9 × 11 m).
 */
enum Sketch {
    static let PAD_W: Double = 360
    static let PAD_H: Double = 440
    static let PAD_MM: Double = 25

    struct Result { let verts: [Pt]; let closed: Bool; let err: String?; var cross: Pt? = nil }

    private static func d(_ a: Pt, _ b: Pt) -> Double { hypot(a.x - b.x, a.y - b.y) }

    /// Ramer–Douglas–Peucker simplification of an open polyline.
    static func rdp(_ p: [Pt], _ eps: Double) -> [Pt] {
        if p.count < 3 { return p }
        let a = p.first!, b = p.last!
        var idx = -1, best = 0.0
        let len = d(a, b)
        for i in 1..<(p.count - 1) {
            let q = p[i]
            let dist = len < 1e-9 ? d(q, a) : abs((b.x - a.x) * (a.y - q.y) - (a.x - q.x) * (b.y - a.y)) / len
            if dist > best { best = dist; idx = i }
        }
        if best <= eps || idx < 0 { return [a, b] }
        let l = rdp(Array(p[0...idx]), eps), r = rdp(Array(p[idx...]), eps)
        return Array(l.dropLast()) + r
    }

    private static func turn(_ a: Pt, _ b: Pt, _ c: Pt) -> Double {
        let a1 = atan2(b.y - a.y, b.x - a.x), a2 = atan2(c.y - b.y, c.x - b.x)
        var t = a2 - a1
        while t > .pi { t -= 2 * .pi }
        while t < -.pi { t += 2 * .pi }
        return abs(t)
    }

    /// Merges the shortest too-short edge and removes nearly straight corners until nothing changes (prototype skClean).
    static func clean(_ v0: [Pt], _ closed: Bool, _ minLen: Double) -> [Pt] {
        var v = v0
        var changed = true
        while changed && v.count > 2 {
            changed = false
            let n = v.count
            let edges = closed ? n : n - 1
            var si = -1, sl = Double.greatestFiniteMagnitude
            for i in 0..<edges { let l = d(v[i], v[(i + 1) % n]); if l < sl { sl = l; si = i } }
            if si >= 0 && sl < minLen && v.count > (closed ? 3 : 2) {
                let j = (si + 1) % n
                if !closed && si == 0 { v.remove(at: 1) }
                else if !closed && j == n - 1 { v.remove(at: n - 2) }
                else { v[si] = Pt(x: (v[si].x + v[j].x) / 2, y: (v[si].y + v[j].y) / 2); v.remove(at: j) }
                changed = true; continue
            }
            let range = closed ? Array(0..<n) : Array(1..<max(1, n - 1))
            for i in range {
                let a = v[(i - 1 + n) % n], b = v[i], c = v[(i + 1) % n]
                if turn(a, b, c) < 0.21 { v.remove(at: i); changed = true; break }
            }
        }
        return v
    }

    /// Rounds every wall to 45°, joins walls that point the same way and closes the outline by least squares (prototype skSnapPoly).
    static func snapPoly(_ v: [Pt], _ closed: Bool) -> [Pt]? {
        let n = v.count
        let edges = closed ? n : n - 1
        if edges < 1 { return nil }
        var dirs: [Double] = [], lens: [Double] = []
        for i in 0..<edges {
            let a = v[i], b = v[(i + 1) % n]
            dirs.append(Geo.snapAngle(atan2(b.y - a.y, b.x - a.x))); lens.append(d(a, b))
        }
        // merge consecutive edges with the same direction; opposite ones cancel
        var md: [Double] = [], ml: [Double] = []
        for i in dirs.indices {
            if let last = md.last {
                let r = (dirs[i] - last).truncatingRemainder(dividingBy: 2 * .pi)
                let diff = abs(((r + 3 * .pi).truncatingRemainder(dividingBy: 2 * .pi)) - .pi)
                if diff < 1e-6 || abs(diff - .pi) < 1e-6 {
                    let same = abs(cos(dirs[i] - last) - 1) < 1e-6
                    let l = same ? ml.last! + lens[i] : ml.last! - lens[i]
                    if l < 0 { md[md.count - 1] = dirs[i]; ml[ml.count - 1] = -l } else { ml[ml.count - 1] = l }
                    continue
                }
            }
            md.append(dirs[i]); ml.append(lens[i])
        }
        if closed && md.count >= 2 && abs(cos(md.first! - md.last!) - 1) < 1e-6 { ml[0] += ml.last!; md.removeLast(); ml.removeLast() }
        if closed && md.count < 3 { return nil }
        let orig = ml
        if closed {
            var ex = 0.0, ey = 0.0, a = 0.0, b = 0.0, c = 0.0
            for i in md.indices { let ux = cos(md[i]), uy = sin(md[i]); ex += ml[i] * ux; ey += ml[i] * uy; a += ux * ux; b += ux * uy; c += uy * uy }
            let det = a * c - b * b
            if abs(det) < 1e-9 { return nil }
            let lx = (c * ex - b * ey) / det, ly = (a * ey - b * ex) / det
            for i in md.indices { ml[i] = ml[i] - (cos(md[i]) * lx + sin(md[i]) * ly) }
        }
        for i in md.indices where ml[i] < max(0.3 * orig[i], 1) { return nil }
        // rebuild: closed outlines keep their centroid, open paths their start
        var x = v[0].x, y = v[0].y
        var out = [Pt(x: x, y: y)]
        for i in md.indices { x += ml[i] * cos(md[i]); y += ml[i] * sin(md[i]); out.append(Pt(x: x, y: y)) }
        let pts = closed ? Array(out.dropLast()) : out
        if closed {
            let cx0 = v.map(\.x).reduce(0, +) / Double(v.count), cy0 = v.map(\.y).reduce(0, +) / Double(v.count)
            let cx1 = pts.map(\.x).reduce(0, +) / Double(pts.count), cy1 = pts.map(\.y).reduce(0, +) / Double(pts.count)
            return clean(pts.map { Pt(x: $0.x + cx0 - cx1, y: $0.y + cy0 - cy1) }, true, 1)
        }
        return clean(pts, false, 1)
    }

    /// The whole pipeline (prototype skProcess). tap = corners were tapped; tapClosed = the last tap closed the shape.
    static func process(_ raw0: [Pt], tap: Bool, tapClosed: Bool, snap: Bool) -> Result {
        var raw: [Pt] = []
        for p in raw0 where raw.isEmpty || d(raw.last!, p) >= 0.5 { raw.append(p) }
        if raw.count < (tap ? 2 : 5) { return Result(verts: raw, closed: false, err: "short") }
        let bw = raw.map(\.x).max()! - raw.map(\.x).min()!, bh = raw.map(\.y).max()! - raw.map(\.y).min()!
        let Dg = hypot(bw, bh)
        var closed: Bool
        var v: [Pt]
        if !tap {
            if Dg < 40 { return Result(verts: raw, closed: false, err: "short") }
            let ct = max(26, 0.15 * Dg)
            closed = d(raw.last!, raw.first!) < ct
            v = rdp(raw, max(6, 0.035 * Dg))
            if closed && v.count > 2 && d(v.last!, v.first!) < ct { v.removeLast() }
        } else { closed = tapClosed; v = raw }
        v = clean(v, closed, max(tap ? 4 : 10, 0.05 * Dg))
        if closed && v.count < 3 { return Result(verts: v, closed: true, err: "few") }
        if snap && (closed || tap), let s = snapPoly(v, closed) { v = s }
        if v.count > 20 { return Result(verts: v, closed: closed, err: "many") }
        if closed {
            if let x = Geo.selfIntersects(v) { return Result(verts: v, closed: true, err: "cross", cross: x) }
            return Result(verts: Geo.orient(v), closed: true, err: nil)
        }
        return Result(verts: v, closed: false, err: "open")
    }

    /// Pad units to millimetres on a 10 mm grid, duplicates dropped, clockwise from the top-left corner.
    static func toMm(_ v: [Pt]) -> [Pt] {
        var mm: [Pt] = []
        for p in v {
            let q = Pt(x: Double(kround(p.x * PAD_MM / 10) * 10), y: Double(kround(p.y * PAD_MM / 10) * 10))
            if mm.isEmpty || mm.last! != q { mm.append(q) }
        }
        if mm.count > 1 && mm.first! == mm.last! { mm.removeLast() }
        return mm.count >= 3 ? Geo.orient(mm) : mm
    }
}
