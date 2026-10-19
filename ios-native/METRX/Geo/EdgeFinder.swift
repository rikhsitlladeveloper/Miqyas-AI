import Foundation

/*
 * Photo edge measuring (part 2; Android geo/EdgeFinder.kt, the same steps and numbers): the straight edges and corners of
 * a photo, found on the phone and offline, so a measuring line's ends can snap onto a table's, door's or cabinet's edges.
 * blur → gradients → thin edges → keep strong ones → group pixels of one direction into straight segments → join the
 * pieces of one edge → corners where two edges end together → the best rectangle of four edges.
 * It works on a small grey copy of the photo (about 420 px on the long side); results are in the item's units.
 */

/// A straight edge from (x1, y1) to (x2, y2).
struct ESeg: Equatable {
    var x1: Float, y1: Float, x2: Float, y2: Float
    var len: Float { hypotf(x2 - x1, y2 - y1) }
    var ang: Float { atan2f(y2 - y1, x2 - x1) }
}

/// A corner where edges a and b end together.
struct ECorner: Equatable { let x: Float, y: Float, a: Int, b: Int }

/// Four corners in order, and the edges along its sides: side i runs from pts[i] to pts[i+1] along segs[i].
struct ERect: Equatable { let pts: [(Float, Float)]; let segs: [Int]
    static func == (l: ERect, r: ERect) -> Bool { l.segs == r.segs && zip(l.pts, r.pts).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 } }
}

struct PhotoEdges: Equatable {
    let segs: [ESeg], corners: [ECorner], rect: ERect?
    static let none = PhotoEdges(segs: [], corners: [], rect: nil)
}

enum EdgeFinder {
    /// The long side of the grey copy the finder works on.
    static let work = 420

    /// The grey value of 8-bit red, green and blue.
    static func grey(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Float { 0.299 * Float(r) + 0.587 * Float(g) + 0.114 * Float(b) }

    /// Edges of a grey image g (w × h, 0–255), given back in units where the whole image is outW × outH.
    static func find(_ g: [Float], _ w: Int, _ h: Int, _ outW: Float, _ outH: Float) -> PhotoEdges {
        let n = w * h
        guard w >= 8, h >= 8, g.count >= n else { return .none }
        // 5-tap blur, both directions
        let k: [Float] = [1, 4, 6, 4, 1]
        var tmp = [Float](repeating: 0, count: n), bl = [Float](repeating: 0, count: n)
        for y in 0..<h { for x in 0..<w {
            var s: Float = 0; for j in -2...2 { s += k[j + 2] * g[y * w + min(max(x + j, 0), w - 1)] }; tmp[y * w + x] = s / 16
        } }
        for y in 0..<h { for x in 0..<w {
            var s: Float = 0; for j in -2...2 { s += k[j + 2] * tmp[min(max(y + j, 0), h - 1) * w + x] }; bl[y * w + x] = s / 16
        } }
        // gradients
        var gx = [Float](repeating: 0, count: n), gy = [Float](repeating: 0, count: n), mg = [Float](repeating: 0, count: n)
        for y in 1..<(h - 1) { for x in 1..<(w - 1) {
            let i = y * w + x
            let a = bl[i - w - 1], b = bl[i - w], c = bl[i - w + 1], d = bl[i - 1], f = bl[i + 1]
            let gg = bl[i + w - 1], hh = bl[i + w], ii = bl[i + w + 1]
            let X = (c + 2 * f + ii) - (a + 2 * d + gg), Y = (gg + 2 * hh + ii) - (a + 2 * b + c)
            gx[i] = X; gy[i] = Y; mg[i] = hypotf(X, Y)
        } }
        // thin to one pixel
        var nm = [Float](repeating: 0, count: n), vals: [Float] = []
        for y in 1..<(h - 1) { for x in 1..<(w - 1) {
            let i = y * w + x, m = mg[i]; if m < 8 { continue }
            let dx = Int((gx[i] / m + 0.5).rounded(.down)), dy = Int((gy[i] / m + 0.5).rounded(.down))   // as Kotlin's roundToInt
            if m >= mg[i + dy * w + dx] && m >= mg[i - dy * w - dx] { nm[i] = m; vals.append(m) }
        } }
        if vals.isEmpty { return .none }
        vals.sort()
        // the bar follows the photo's strongest edges, so a white frame on a light wall still counts next to a dark door
        let hi = max(40, vals[Int(Float(vals.count - 1) * 0.98)] * 0.18), lo = hi * 0.45
        var edge = [Bool](repeating: false, count: n), st: [Int] = []
        let nb = [-w - 1, -w, -w + 1, -1, 1, w - 1, w, w + 1]
        for i in 0..<n where nm[i] >= hi { edge[i] = true; st.append(i) }
        while let i = st.popLast() { for o in nb { let j = i + o; if j >= 0 && j < n && !edge[j] && nm[j] >= lo { edge[j] = true; st.append(j) } } }

        // group edge pixels of one direction and fit straight segments
        let idx = (0..<n).filter { edge[$0] }.sorted { mg[$0] != mg[$1] ? mg[$0] > mg[$1] : $0 < $1 }   // stable, as Kotlin's
        var used = [Bool](repeating: false, count: n)
        func ang(_ i: Int) -> Float { atan2f(gy[i], gx[i]) }
        let pi = Float.pi, tol = pi / 8, minLen = Float(max(w, h)) * 0.05
        var raw: [ESeg] = []
        var reg: [Int] = []; reg.reserveCapacity(4096)
        for s0 in idx {
            if used[s0] { continue }
            used[s0] = true; reg.removeAll(keepingCapacity: true); reg.append(s0)
            var cs = cosf(2 * ang(s0)), sn = sinf(2 * ang(s0))
            var q = 0
            while q < reg.count {
                let i = reg[q]; q += 1
                for o in nb {
                    let j = i + o; if j < 0 || j >= n || used[j] || !edge[j] { continue }
                    let m = atan2f(sn, cs) / 2
                    var df = fmodf(abs(ang(j) - m), pi); df = min(df, pi - df)
                    if df < tol { used[j] = true; reg.append(j); cs += cosf(2 * ang(j)); sn += sinf(2 * ang(j)) }
                }
            }
            let rn = reg.count; if rn < 10 { continue }
            var mx: Float = 0, my: Float = 0
            for t in reg { mx += Float(t % w); my += Float(t / w) }
            mx /= Float(rn); my /= Float(rn)
            var sxx: Float = 0, syy: Float = 0, sxy: Float = 0
            for t in reg { let x = Float(t % w) - mx, y = Float(t / w) - my; sxx += x * x; syy += y * y; sxy += x * y }
            sxx /= Float(rn); syy /= Float(rn); sxy /= Float(rn)
            let tr = sxx + syy, dt = sxx * syy - sxy * sxy, disc = sqrtf(max(0, tr * tr / 4 - dt))
            let l1 = tr / 2 + disc, l2 = tr / 2 - disc
            if sqrtf(max(0, l2)) > 1.6 { continue }          // too thick to be one straight edge
            var ux = sxy, uy = l1 - sxx
            if abs(ux) + abs(uy) < 1e-6 { if sxx >= syy { ux = 1; uy = 0 } else { ux = 0; uy = 1 } }
            let ul = hypotf(ux, uy); ux /= ul; uy /= ul
            var t0: Float = 1e9, t1: Float = -1e9
            for t in reg { let p = (Float(t % w) - mx) * ux + (Float(t / w) - my) * uy; if p < t0 { t0 = p }; if p > t1 { t1 = p } }
            let len = t1 - t0
            if len < minLen || Float(rn) / len < 0.6 { continue }
            raw.append(ESeg(x1: mx + ux * t0, y1: my + uy * t0, x2: mx + ux * t1, y2: my + uy * t1))
        }

        // join pieces of one edge (broken by a cup, a leg or a shadow)
        let gapT = Float(max(w, h)) * 0.1
        var merged = true
        while merged {
            merged = false
            outer: for i in raw.indices { for j in (i + 1)..<max(i + 1, raw.count) {
                let a = raw[i], b = raw[j]
                var da = fmodf(abs(a.ang - b.ang), pi); da = min(da, pi - da); if da > 0.07 { continue }
                let la = a.len, ux = (a.x2 - a.x1) / la, uy = (a.y2 - a.y1) / la
                func dist(_ x: Float, _ y: Float) -> Float { abs((x - a.x1) * uy - (y - a.y1) * ux) }
                if dist(b.x1, b.y1) > 3 || dist(b.x2, b.y2) > 3 { continue }
                func p(_ x: Float, _ y: Float) -> Float { (x - a.x1) * ux + (y - a.y1) * uy }
                let tb0 = min(p(b.x1, b.y1), p(b.x2, b.y2)), tb1 = max(p(b.x1, b.y1), p(b.x2, b.y2))
                if tb0 > la + gapT || tb1 < -gapT { continue }
                let t0 = min(0, tb0), t1 = max(la, tb1)
                raw[i] = ESeg(x1: a.x1 + ux * t0, y1: a.y1 + uy * t0, x2: a.x1 + ux * t1, y2: a.y1 + uy * t1); raw.remove(at: j)
                merged = true; break outer
            } }
        }
        let sx = outW / Float(w), sy = outH / Float(h)
        // a stable sort, as Kotlin's sortedByDescending
        let all = raw.enumerated().sorted { $0.element.len != $1.element.len ? $0.element.len > $1.element.len : $0.offset < $1.offset }
            .prefix(60).map { ESeg(x1: $0.element.x1 * sx, y1: $0.element.y1 * sy, x2: $0.element.x2 * sx, y2: $0.element.y2 * sy) }
        let W = outW, H = outH, tolC = max(W, H) * 0.03

        // corners: two edges meeting at their ends
        func joins(_ segs: [ESeg]) -> ([ECorner], [[Int: ECorner]]) {
            var corners: [ECorner] = []
            var adj = [[Int: ECorner]](repeating: [:], count: segs.count)
            for i in segs.indices { for j in (i + 1)..<max(i + 1, segs.count) {
                let a = segs[i], b = segs[j]
                var da = fmodf(abs(a.ang - b.ang), pi); da = min(da, pi - da); if da < 0.44 { continue }
                let d1x = a.x2 - a.x1, d1y = a.y2 - a.y1, d2x = b.x2 - b.x1, d2y = b.y2 - b.y1
                let den = d1x * d2y - d1y * d2x; if abs(den) < 1e-6 { continue }
                let t = ((b.x1 - a.x1) * d2y - (b.y1 - a.y1) * d2x) / den
                let px = a.x1 + t * d1x, py = a.y1 + t * d1y
                if px < -tolC || py < -tolC || px > W + tolC || py > H + tolC { continue }
                func near(_ s: ESeg) -> Float { min(hypotf(px - s.x1, py - s.y1), hypotf(px - s.x2, py - s.y2)) }
                let c = ECorner(x: px, y: py, a: i, b: j), na = near(a), nbb = near(b)
                // for the rectangle a side may stop short of its corner (hidden by a leg or a shadow)
                if na <= max(tolC, a.len) && nbb <= max(tolC, b.len) { adj[i][j] = c; adj[j][i] = c }
                if na > tolC || nbb > tolC { continue }
                if !corners.contains(where: { hypotf($0.x - px, $0.y - py) < tolC / 2 }) { corners.append(c) }
            } }
            return (corners, adj)
        }
        // short strokes that meet no other edge are mostly texture (a rug's pattern, wood grain): left out
        let c0 = joins(Array(all)).0
        let segs = Array(all.enumerated().filter { i, s in s.len >= max(W, H) * 0.09 || c0.contains { $0.a == i || $0.b == i } }.map(\.element).prefix(50))
        let (corners, adj) = joins(segs)

        // the best rectangle: four edges joined end to end, every side mostly seen
        var rect: ERect? = nil, best: Float = 0
        for i in segs.indices {
            for j in adj[i].keys.sorted() where j > i {
                let c1 = adj[i][j]!
                for kk in adj[j].keys.sorted() where kk > i {
                    let c2 = adj[j][kk]!
                    for l in adj[kk].keys.sorted() where l > i && l != j {
                        let c3 = adj[kk][l]!
                        guard let c0 = adj[l][i] else { continue }
                        let q = [c0, c1, c2, c3]
                        var sg: Float = 0, ok = true
                        for m in 0..<4 {
                            let p = q[m], r = q[(m + 1) % 4], s = q[(m + 2) % 4]
                            let v = (r.x - p.x) * (s.y - r.y) - (r.y - p.y) * (s.x - r.x)
                            let cr: Float = v > 0 ? 1 : (v < 0 ? -1 : 0)
                            if cr == 0 || (sg != 0 && cr != sg) { ok = false; break }; sg = cr
                        }
                        if !ok { continue }
                        var ar: Float = 0; for m in 0..<4 { let p = q[m], r = q[(m + 1) % 4]; ar += p.x * r.y - r.x * p.y }
                        ar = abs(ar / 2); if ar < W * H * 0.03 { continue }
                        let sides = [i, j, kk, l]
                        let cov = sides.enumerated().map { m, sgi in min(1, segs[sgi].len / max(1, hypotf(q[(m + 1) % 4].x - q[m].x, q[(m + 1) % 4].y - q[m].y))) }.min()!
                        if cov < 0.45 { continue }
                        let score = ar * cov
                        if score > best { best = score; rect = ERect(pts: q.map { ($0.x, $0.y) }, segs: sides) }
                    }
                }
            }
        }
        return PhotoEdges(segs: segs, corners: corners, rect: rect)
    }
}

/// The two sides of a found rectangle to measure (part 3): the ones meeting at its corner nearest the photo's bottom
/// left, the more level one first (a table's length, a door's width), then the other (depth or height).
func rectSides(_ r: ERect) -> [((Float, Float), (Float, Float))] {
    let p = r.pts, n = p.count
    guard let i = p.indices.max(by: { (p[$0].1 - p[$0].0) < (p[$1].1 - p[$1].0) }) else { return [] }
    let c = p[i], s1 = (c, p[(i + 1) % n]), s2 = (c, p[(i + n - 1) % n])
    func level(_ s: ((Float, Float), (Float, Float))) -> Float { abs(s.1.0 - s.0.0) / max(1e-3, hypotf(s.1.0 - s.0.0, s.1.1 - s.0.1)) }
    return level(s1) >= level(s2) ? [s1, s2] : [s2, s1]
}

/* ---------------- snapping a line's end onto the edges ---------------- */

/// What a line's end is stuck to: a corner (edges a and b) or an edge (a, b = -1).
struct ESnap: Equatable {
    let corner: Bool, a: Int, b: Int
    init(corner: Bool, a: Int, b: Int = -1) { self.corner = corner; self.a = a; self.b = b }
    var segs: [Int] { b >= 0 ? [a, b] : [a] }
}

/// A point after snapping, and what it is stuck to (nil: free).
struct ESnapped: Equatable { var x: Float, y: Float; let snap: ESnap? }

/// The point at (x, y) moved onto a corner within rCorner (corners win), else onto the nearest edge within rEdge; all in
/// the same units as the edges. Free when nothing is near.
func edgeSnap(_ e: PhotoEdges, _ x: Float, _ y: Float, _ rCorner: Float, _ rEdge: Float) -> ESnapped {
    var bc: ECorner? = nil, bd = rCorner
    for c in e.corners { let d = hypotf(c.x - x, c.y - y); if d <= bd { bd = d; bc = c } }
    if let c = bc { return ESnapped(x: c.x, y: c.y, snap: ESnap(corner: true, a: c.a, b: c.b)) }
    var bs = -1, be = rEdge, qx: Float = 0, qy: Float = 0
    for (i, s) in e.segs.enumerated() {
        let dx = s.x2 - s.x1, dy = s.y2 - s.y1, l2 = dx * dx + dy * dy; if l2 <= 0 { continue }
        let t = min(max(((x - s.x1) * dx + (y - s.y1) * dy) / l2, 0), 1)
        let px = s.x1 + t * dx, py = s.y1 + t * dy, d = hypotf(px - x, py - y)
        if d <= be { be = d; bs = i; qx = px; qy = py }
    }
    return bs >= 0 ? ESnapped(x: qx, y: qy, snap: ESnap(corner: false, a: bs)) : ESnapped(x: x, y: y, snap: nil)
}

/// The edge both ends are stuck to, or nil.
func sharedEdge(_ a: ESnap?, _ b: ESnap?) -> Int? {
    guard let a, let b else { return nil }
    return a.segs.first { b.segs.contains($0) }
}

/// Both ends on one edge: the line lies exactly along it (each end moved straight onto the edge's line).
func lockAlong(_ e: PhotoEdges, _ a: ESnapped, _ b: ESnapped) -> (ESnapped, ESnapped) {
    guard let si = sharedEdge(a.snap, b.snap), si < e.segs.count else { return (a, b) }
    let s = e.segs[si], dx = s.x2 - s.x1, dy = s.y2 - s.y1, l2 = dx * dx + dy * dy
    guard l2 > 0 else { return (a, b) }
    func on(_ p: ESnapped) -> ESnapped { let t = ((p.x - s.x1) * dx + (p.y - s.y1) * dy) / l2; var q = p; q.x = s.x1 + t * dx; q.y = s.y1 + t * dy; return q }
    return (on(a), on(b))
}
