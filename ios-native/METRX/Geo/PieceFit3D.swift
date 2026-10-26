import Foundation

/*
 * The designer's 3D of a room-less piece (Furniture/Furniture3DView.swift, Furniture3DPane): the camera starts on the
 * piece itself, not on the middle of its made-up room, near enough that the piece fills about 78 % of the picture's
 * free band (between the "See inside" pill along its top and the hint along its bottom), across or up, whichever is
 * tighter. Pure maths, tested in METRXTests/PieceFit3DTests.swift. The gallery's cards keep their own framing
 * (Furniture/CardCache.swift cardAim), a measured room its room framing (Cam3D's fit).
 */

/// How much of the free band the piece fills, across or up (whichever is tighter).
let PIECE_FILL = 0.78

/// A room-less piece for the camera: its box (lo, hi), the points the fit keeps inside the picture (the piece's own
/// corners, so an L kitchen's empty corner does not count), and the bands of the picture covered along its top and
/// bottom, in points.
struct PieceFrame {
    var lo: V3
    var hi: V3
    var pts: [V3]
    var top: Double = 60
    var bottom: Double = 48
    var fill: Double = PIECE_FILL

    /// The box's middle: where the camera looks.
    var mid: V3 { (lo + hi) * 0.5 }
}

/// Grid cells (2 cm) a point falls in, so one corner shared by many boards counts once.
private struct Cell3: Hashable { let x: Int32; let y: Int32; let z: Int32 }

/// The frame of the points pts (nil when there are none). Many points are thinned to about cap, the furthest ones out
/// along each axis always kept.
func pieceFrame(_ pts: [V3], cap: Int = 3000) -> PieceFrame? {
    guard let p0 = pts.first else { return nil }
    var lo = p0, hi = p0
    var ext: [V3] = [p0, p0, p0, p0, p0, p0]
    var seen = Set<Cell3>()
    var out: [V3] = []
    for p in pts {
        if p.x < lo.x { lo.x = p.x; ext[0] = p }
        if p.x > hi.x { hi.x = p.x; ext[1] = p }
        if p.y < lo.y { lo.y = p.y; ext[2] = p }
        if p.y > hi.y { hi.y = p.y; ext[3] = p }
        if p.z < lo.z { lo.z = p.z; ext[4] = p }
        if p.z > hi.z { hi.z = p.z; ext[5] = p }
        let c = Cell3(x: Int32((p.x * 50).rounded()), y: Int32((p.y * 50).rounded()), z: Int32((p.z * 50).rounded()))
        if seen.insert(c).inserted { out.append(p) }
    }
    if out.count > cap {
        let step = Int((Double(out.count) / Double(max(1, cap))).rounded(.up))
        var thin: [V3] = []
        var i = 0
        while i < out.count { thin.append(out[i]); i += step }
        out = thin
    }
    out += ext
    return PieceFrame(lo: lo, hi: hi, pts: out)
}

/// The frame of a piece's 3D: everything it draws (boards, glass, handles) and, shut, its doors and drawers (split
/// fronts); nil with nothing drawn.
func pieceFrame(_ fur: Furn3D) -> PieceFrame? {
    var pts: [V3] = []
    for p in fur.parts {
        for f in p.faces { pts += f.pts }
    }
    for fr in fur.fronts {
        for p in fr.parts {
            for f in p.faces { pts += f.pts }
        }
    }
    return pieceFrame(pts)
}

/// Where the camera of a w × h picture (points), turned to theta and phi (Cam3D's angles), looks and how far it stands
/// to show pf: it looks at the box's middle, moved along the picture's up so that middle sits in the middle of the free
/// band, and stands where the furthest point out from it reaches pf.fill of the band's half width or half height
/// (whichever comes first). half: half the camera's vertical field of view.
func pieceAim(_ pf: PieceFrame, theta: Double, phi: Double, w: Double, h: Double, half: Double = FOV_HALF) -> (tgt: V3, r: Double) {
    let c = pf.mid
    let ww = max(1, w), hh = max(1, h)
    let aspect = ww / hh
    // the free band; a very short picture keeps at least 40 % of its height, the covered bands shrunk alike
    var top = max(0, pf.top), bottom = max(0, pf.bottom)
    let minBand = hh * 0.4
    if hh - top - bottom < minBand {
        let k = (hh - minBand) / max(1e-9, top + bottom)
        top *= k; bottom *= k
    }
    let band = hh - top - bottom
    // the band's middle in the picture's units (-1 bottom … 1 top), and how far from it the piece may reach
    let ny0 = 1 - 2 * (top + band / 2) / hh
    let limX = pf.fill
    let limY = pf.fill * band / hh
    // the camera's own directions (Cam3D.eye, ray): o from the target to the eye, f forward, s right, u up
    let o = V3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
    let f = o * -1
    let s = V3(sin(theta), 0, -cos(theta))
    let u = s.cross(f)
    let tn = tan(half)
    let fy = 1 / tn, fx = fy / aspect
    let pts = pf.pts.isEmpty ? [pf.lo, pf.hi] : pf.pts
    // the target moved along up by k: the box's middle then shows at ny0 whatever the distance
    func target(_ r: Double) -> V3 { c + u * (-ny0 * r * tn) }
    func fits(_ r: Double) -> Bool {
        let e = target(r) + o * r
        for p in pts {
            let d = p - e
            let zc = d.dot(f)
            if zc <= 0.05 { return false }
            let nx = fx * d.dot(s) / zc
            let ny = fy * d.dot(u) / zc
            if abs(nx) > limX || abs(ny - ny0) > limY { return false }
        }
        return true
    }
    // the nearest distance that still fits: out until it fits, then halved in between
    let size = max(0.05, (pf.hi - pf.lo).len)
    var near = 0.01
    var far = size + 0.5
    var n = 0
    while !fits(far) && n < 40 { near = far; far *= 2; n += 1 }
    for _ in 0..<50 {
        let m = (near + far) / 2
        if fits(m) { far = m } else { near = m }
    }
    return (target(far), far)
}
