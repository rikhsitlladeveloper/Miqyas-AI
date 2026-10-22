import Foundation

/*
 * The fixtures, riser and pipes in 3D (Android plumb/Mesh.kt): each fixture as a few plain boxes at its true size against
 * its wall (a toilet's bowl and cistern, a basin over its cabinet, a bath with its tub, a shower tray with its glass, a
 * sink in its cabinet, the machines with their doors, a heater's cylinder, a radiator's sections), the riser's pipes
 * with the meters, every pipe as a thin strip in its colour along the walls (or on the floor), the underfloor loops on
 * the floor. Faces of one colour go into one part, so a room is a few dozen meshes.
 */

let P_CERAMIC = 0xF8FAFC
let P_SEAT = 0xE8EDF3
let P_CAB = 0xE7DCCB
let P_CHROME = 0x94A3B8
let P_TUB = 0xDCEBFA
let P_GLASS_RGB = 0xBFDBFE
let P_DARK = 0x475569

/// Parts keyed by wall, colour, role and opacity as they fill.
private final class PParts {
    var keys: [String] = []
    var map: [String: Part3] = [:]
    func of(_ wall: String?, _ rgb: Int, _ role: Role3, _ op: Double = 1) -> Part3 {
        let k = "\(wall ?? "-")|\(rgb)|\(role)|\(op)"
        if let p = map[k] { return p }
        let p = Part3(0, wall, role, rgb, op, tile: true)
        map[k] = p; keys.append(k)
        return p
    }
    var parts: [Part3] { keys.compactMap { map[$0] } }
}

/// Where plan point q (mm) at z mm up is in the scene, the plan's corner at (dx, dz) metres.
private struct PSc {
    let dx: Double, dz: Double
    func at(_ q: V2, _ z: Double) -> V3 { V3(q.x / 1000 + dx, z / 1000, q.y / 1000 + dz) }
}

/// A box against wall w: a0…a1 along it, d0…d1 into the room, z0…z1 up (mm). Its back is left out unless back.
private func pBox(_ p: Part3, _ s: PSc, _ w: TWall, _ a0: Double, _ a1: Double, _ d0: Double, _ d1: Double, _ z0: Double, _ z1: Double, _ back: Bool = false) {
    func pt(_ a: Double, _ d: Double, _ z: Double) -> V3 { s.at(w.at(a, d), z) }
    let n = V3(w.nIn.x, 0, w.nIn.y)
    let t = V3(w.t.x, 0, w.t.y)
    p.faces.append(Face3(n: n, pts: [pt(a0, d1, z0), pt(a1, d1, z0), pt(a1, d1, z1), pt(a0, d1, z1)]))
    p.faces.append(Face3(n: V3(0, 1, 0), pts: [pt(a0, d0, z1), pt(a0, d1, z1), pt(a1, d1, z1), pt(a1, d0, z1)]))
    if z0 > 1 { p.faces.append(Face3(n: V3(0, -1, 0), pts: [pt(a0, d0, z0), pt(a1, d0, z0), pt(a1, d1, z0), pt(a0, d1, z0)])) }
    p.faces.append(Face3(n: t * -1, pts: [pt(a0, d0, z0), pt(a0, d1, z0), pt(a0, d1, z1), pt(a0, d0, z1)]))
    p.faces.append(Face3(n: t, pts: [pt(a1, d0, z0), pt(a1, d0, z1), pt(a1, d1, z1), pt(a1, d1, z0)]))
    if back { p.faces.append(Face3(n: n * -1, pts: [pt(a0, d0, z0), pt(a0, d0, z1), pt(a1, d0, z1), pt(a1, d0, z0)])) }
}

/// An upright cylinder (a water heater) at plan point q, radius r mm, z0…z1 up.
private func pCyl(_ p: Part3, _ s: PSc, _ q: V2, _ r: Double, _ z0: Double, _ z1: Double, _ n: Int = 12) {
    var ring: [V2] = []
    for i in 0..<n {
        let a = 2 * Double.pi * Double(i) / Double(n)
        ring.append(V2(q.x + r * cos(a), q.y + r * sin(a)))
    }
    p.faces.append(Face3(n: V3(0, 1, 0), pts: Array(ring.map { s.at($0, z1) }.reversed())))
    p.faces.append(Face3(n: V3(0, -1, 0), pts: ring.map { s.at($0, z0) }))
    for i in 0..<n {
        let a = ring[i], b = ring[(i + 1) % n]
        let mx = (a.x + b.x) / 2 - q.x, my = (a.y + b.y) / 2 - q.y
        let l = max(hypot(mx, my), 1e-9)
        p.faces.append(Face3(n: V3(mx / l, 0, my / l), pts: [s.at(a, z0), s.at(b, z0), s.at(b, z1), s.at(a, z1)]))
    }
}

/// A flat round face standing d into the room from wall w at a along it and z up (a machine's door).
private func pRing(_ p: Part3, _ s: PSc, _ w: TWall, _ a: Double, _ z: Double, _ d: Double, _ r: Double, _ n: Int = 12) {
    var pts: [V3] = []
    for i in 0..<n {
        let t = 2 * Double.pi * Double(i) / Double(n)
        pts.append(s.at(w.at(a + r * cos(t), d), z + r * sin(t)))
    }
    p.faces.append(Face3(n: V3(w.nIn.x, 0, w.nIn.y), pts: Array(pts.reversed())))
}

/// Fixture f's boxes in room c.
private func fixParts(_ ps: PParts, _ s: PSc, _ c: PCtx, _ f: PlFix) {
    guard let w = c.wall(f.wall) else { return }
    let x = Double(f.off), fw = Double(fixW(f)), fd = Double(fixD(f))
    let ty = fixType(f.t)
    let th = Double(ty.h), tz0 = Double(ty.z0)
    let a0 = x - fw / 2, a1 = x + fw / 2
    let white = ps.of(nil, P_CERAMIC, .furn)
    let chrome = ps.of(nil, P_CHROME, .furn)
    switch f.t {
    case "wc":
        pBox(white, s, w, x - 170, x + 170, 160, fd - 40, 0, 400)
        pBox(ps.of(nil, P_SEAT, .furn), s, w, x - 180, x + 180, 180, fd, 400, 430)
        pBox(white, s, w, x - 190, x + 190, 0, 170, 400, th)
        pBox(chrome, s, w, x - 30, x + 30, 60, 110, th, th + 6)
    case "bs", "bsm":
        let top = th
        pBox(white, s, w, a0, a1, 0, fd, top - 160, top)
        pBox(ps.of(nil, P_TUB, .furn), s, w, a0 + 60, a1 - 60, 60, fd - 60, top - 4, top + 1)
        pBox(chrome, s, w, x - 15, x + 15, 60, 120, top + 1, top + 140)
        if f.opt == "cab" { pBox(ps.of(nil, P_CAB, .furn), s, w, a0 + 10, a1 - 10, 20, fd - 20, 0, top - 160) }
        else { pBox(chrome, s, w, x - 25, x + 25, 40, 100, 480, top - 160) }
    case "bath":
        pBox(white, s, w, a0, a1, 0, fd, 0, th)
        pBox(ps.of(nil, P_TUB, .furn), s, w, a0 + 70, a1 - 70, 70, fd - 70, th - 4, th + 1)
    case "sh", "cab":
        pBox(white, s, w, a0, a1, 0, fd, 0, 150)
        pBox(ps.of(nil, P_TUB, .furn), s, w, a0 + 50, a1 - 50, 50, fd - 50, 146, 151)
        if f.t == "cab" {
            let g = ps.of(nil, P_GLASS_RGB, .furn, 0.35)
            pBox(g, s, w, a0, a1, fd - 8, fd, 150, th)
            pBox(g, s, w, a1 - 8, a1, 0, fd, 150, th)
            pBox(chrome, s, w, a0, a1, fd - 12, fd, th - 30, th)
        }
        pBox(chrome, s, w, x - 50, x + 50, 0, 140, 1900, 1920)
    case "sink":
        pBox(ps.of(nil, P_CAB, .furn), s, w, a0, a1, 0, fd - 30, 0, 820)
        pBox(ps.of(nil, 0xCBD5E1, .furn), s, w, a0, a1, 0, fd, 820, 850)
        pBox(ps.of(nil, 0x9CA3AF, .furn), s, w, x - 250, x + 250, 100, fd - 100, 846, 851)
        pBox(chrome, s, w, x - 15, x + 15, 40, 90, 851, 1100)
    case "wm", "dw":
        pBox(white, s, w, a0, a1, 0, fd, 0, th)
        if f.t == "wm" {
            pRing(chrome, s, w, x, 430, fd + 1, 210)
            pRing(ps.of(nil, P_DARK, .furn), s, w, x, 430, fd + 2, 150)
        } else {
            pBox(chrome, s, w, a0 + 60, a1 - 60, fd, fd + 15, th - 70, th - 50)
        }
    case "wh":
        pCyl(white, s, w.at(x, fd / 2), fd / 2, tz0, th)
    case "gb":
        pBox(white, s, w, a0, a1, 0, fd, tz0, th)
        pBox(ps.of(nil, P_DARK, .furn), s, w, x - 80, x + 80, fd, fd + 3, th - 200, th - 150)
    case "rad":
        let n = max(1, tInt(fw / Double(SEC_MM)))
        let sw = fw / Double(n)
        for i in 0..<n {
            let s0 = a0 + Double(i) * sw + 4, s1 = a0 + Double(i + 1) * sw - 4
            pBox(white, s, w, s0, s1, 10, fd, tz0, th)
        }
    case "tr":
        pBox(chrome, s, w, a0, a0 + 25, 50, 80, tz0, th)
        pBox(chrome, s, w, a1 - 25, a1, 50, 80, tz0, th)
        for i in 0..<6 {
            let z = tz0 + 60 + Double(i) * (th - tz0 - 120) / 5
            pBox(chrome, s, w, a0, a1, 55, 75, z, z + 18)
        }
    case "manif":
        pBox(ps.of(nil, 0xE2E8F0, .furn), s, w, a0, a1, 0, fd, tz0, th)
        pBox(ps.of(nil, kindRgb("hs"), .furn), s, w, a0 + 40, a1 - 40, fd, fd + 25, 650, 680)
        pBox(ps.of(nil, kindRgb("hr"), .furn), s, w, a0 + 40, a1 - 40, fd, fd + 25, 450, 480)
    default:
        pBox(white, s, w, a0, a1, 0, fd, tz0, th)
    }
}

/// The riser's pipes up the wall, its meters, filters and main valves.
private func riserParts(_ ps: PParts, _ s: PSc, _ c: PCtx, _ r: PlRiser) {
    guard let w = c.wall(r.wall) else { return }
    let x = Double(r.off), H = c.g.H
    pBox(ps.of(nil, kindRgb("drain"), .furn), s, w, x - 110, x, 30, 140, 0, H)
    var ks: [(String, Double)] = [("cold", x + 40)]
    if r.hot { ks.append(("hot", x + 100)) }
    for (k, a) in ks {
        pBox(ps.of(nil, kindRgb(k), .furn), s, w, a - 16, a + 16, 40, 72, 0, H)
        pBox(ps.of(nil, 0xE5E7EB, .furn), s, w, a - 30, a + 30, 30, 110, 760, 860)      // the meter
        pBox(ps.of(nil, P_DARK, .furn), s, w, a - 22, a + 22, 30, 100, 620, 690)        // the filter
        pBox(ps.of(nil, 0xDC2626, .furn), s, w, a - 8, a + 60, 72, 90, 960, 975)        // the valve's lever
    }
}

/// A pipe's strip: along the wall's face (on the floor when it lies there), half its half width.
private func pStrip(_ p: Part3, _ s: PSc, _ g: PSeg, _ w: TWall?, _ half: Double) {
    if g.len < 1 { return }
    let floor = g.za <= 80 && g.zb <= 80 && abs(g.za - g.zb) < 30
    if w == nil || floor {
        let dx = g.b.x - g.a.x, dy = g.b.y - g.a.y
        let l = hypot(dx, dy)
        if l < 1 { return }
        let nx = -dy / l * half, ny = dx / l * half
        let q0 = V2(g.a.x + nx, g.a.y + ny), q1 = V2(g.b.x + nx, g.b.y + ny)
        let q2 = V2(g.b.x - nx, g.b.y - ny), q3 = V2(g.a.x - nx, g.a.y - ny)
        let za = g.za + 2, zb = g.zb + 2
        p.faces.append(Face3(n: V3(0, 1, 0), pts: [s.at(q0, za), s.at(q3, za), s.at(q2, zb), s.at(q1, zb)]))
        p.faces.append(Face3(n: V3(0, -1, 0), pts: [s.at(q0, za), s.at(q1, zb), s.at(q2, zb), s.at(q3, za)]))
        return
    }
    guard let w else { return }
    let n = V3(w.nIn.x, 0, w.nIn.y)
    let vertical = abs(g.za - g.zb) > 1 && hypot(g.b.x - g.a.x, g.b.y - g.a.y) < 1
    var pts: [V3] = []
    if vertical {
        let tx = w.t.x * half, ty = w.t.y * half
        pts = [s.at(V2(g.a.x - tx, g.a.y - ty), g.za), s.at(V2(g.a.x + tx, g.a.y + ty), g.za),
               s.at(V2(g.b.x + tx, g.b.y + ty), g.zb), s.at(V2(g.b.x - tx, g.b.y - ty), g.zb)]
    } else {
        pts = [s.at(g.a, g.za - half), s.at(g.b, g.zb - half), s.at(g.b, g.zb + half), s.at(g.a, g.za + half)]
    }
    p.faces.append(Face3(n: n, pts: pts))
}

/// A pipe's strip half width, mm: its diameter, a little thicker so it reads.
func pipeHalf(_ kind: String, _ dia: Int) -> Double { kind == "drain" ? Double(dia) / 2 : 12 }

/// The 3D of room c's fixtures fs, outlets pts, the riser rs when in it, the routes runs and the underfloor loops loop
/// (with its spacing); the plan's corner at (dx, dz) metres in the scene.
func plumbParts(_ c: PCtx, _ fs: [PlFix], _ pts: [APt], _ rs: PlRiser?, _ runs: [PRun], _ loop: PLoop?, _ dx: Double, _ dz: Double) -> [Part3] {
    let ps = PParts()
    let s = PSc(dx: dx, dz: dz)
    for f in fs { fixParts(ps, s, c, f) }
    if let rs, rs.roomId == c.id { riserParts(ps, s, c, rs) }
    // the outlets: a small coloured plate on the wall
    for q in pts {
        guard let w = c.wall(q.wall) else { continue }
        let o = Double(q.off), h = Double(q.h)
        pBox(ps.of(w.id, kindRgb(q.t), .opening), s, w, o - 22, o + 22, 0, 26, h - 22, h + 22)
    }
    for r in runs {
        let half = pipeHalf(r.kind, r.dia)
        for g in r.segs { pStrip(ps.of(g.wall, kindRgb(r.kind), .opening), s, g, c.wall(g.wall), half) }
    }
    if let loop, loop.n > 0 {
        let p = ps.of(nil, UFH_RGB, .furn)
        for k in 0..<loop.n {
            for ab in pSnake(c, loop.step, k, loop.n) { pStrip(p, s, PSeg(ab.0, 6, ab.1, 6, nil), nil, 8) }
        }
    }
    return ps.parts
}
