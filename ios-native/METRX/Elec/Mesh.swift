import Foundation

/*
 * The devices and routes in 3D (Android elec/Mesh.kt): each device at its true height and size on its wall (a plate
 * with its circuit's colour on it) or on the ceiling (a disc), the panel, and every circuit's cable as a thin coloured
 * strip along the walls and over the ceiling. Faces of one colour on one wall go into one part, so a room is a few dozen
 * meshes, and a wall's devices fade with it when it faces the camera.
 */

/// Device plates and light colours.
let E_PLATE = 0xF8FAFC
let E_SW_PLATE = 0xE8EDF3
let E_LIGHT_RGB = 0xFDE68A
let E_LED_RGB = 0xFACC15
let E_BOX_RGB = 0x94A3B8
let E_PANEL_RGB = 0xCBD5E1

/// Parts keyed by wall, colour and role as they fill.
private final class EParts {
    var keys: [String] = []
    var map: [String: Part3] = [:]
    func of(_ wall: String?, _ rgb: Int, _ role: Role3) -> Part3 {
        let k = "\(wall ?? "-")|\(rgb)|\(role)"
        if let p = map[k] { return p }
        let p = Part3(0, wall, role, rgb, 1, tile: true)
        map[k] = p; keys.append(k)
        return p
    }
    var parts: [Part3] { keys.compactMap { map[$0] } }
}

/// Where plan point q (mm) at z mm up is in the scene, the plan's corner at (dx, dz) metres.
private struct ESc {
    let dx: Double, dz: Double
    func at(_ q: V2, _ z: Double) -> V3 { V3(q.x / 1000 + dx, z / 1000, q.y / 1000 + dz) }
}

/// A box standing out of a wall: a0…a1 along it, b0…b1 up (mm), d0…d1 metres into the room; its back is the wall.
private func eWallBox(_ p: Part3, _ s: ESc, _ w: TWall, _ a0: Double, _ a1: Double, _ b0: Double, _ b1: Double, _ d0: Double, _ d1: Double) {
    let o = w.p0, t = w.t, n = w.nIn
    func pt(_ a: Double, _ b: Double, _ d: Double) -> V3 {
        let x = o.x + t.x * a + n.x * d * 1000
        let y = o.y + t.y * a + n.y * d * 1000
        return s.at(V2(x, y), b)
    }
    let nn = V3(n.x, 0, n.y), tt = V3(t.x, 0, t.y)
    p.faces.append(Face3(n: nn, pts: [pt(a0, b0, d1), pt(a1, b0, d1), pt(a1, b1, d1), pt(a0, b1, d1)]))
    p.faces.append(Face3(n: V3(0, 1, 0), pts: [pt(a0, b1, d0), pt(a0, b1, d1), pt(a1, b1, d1), pt(a1, b1, d0)]))
    p.faces.append(Face3(n: V3(0, -1, 0), pts: [pt(a0, b0, d0), pt(a1, b0, d0), pt(a1, b0, d1), pt(a0, b0, d1)]))
    p.faces.append(Face3(n: tt * -1, pts: [pt(a0, b0, d0), pt(a0, b0, d1), pt(a0, b1, d1), pt(a0, b1, d0)]))
    p.faces.append(Face3(n: tt, pts: [pt(a1, b0, d0), pt(a1, b1, d0), pt(a1, b1, d1), pt(a1, b0, d1)]))
}

/// A flat disc under the ceiling at plan point q, r mm across radius, z0…z1 mm up: seen from below and from above.
private func eDisc(_ p: Part3, _ s: ESc, _ q: V2, _ r: Double, _ z0: Double, _ z1: Double, _ n: Int = 10) {
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

/// The 3D of room c's devices ds, the panel pn when in it, and the routes runs; the plan's corner at (dx, dz) metres in
/// the scene.
func elecParts(_ c: ECtx, _ ds: [ElecDev], _ pn: ElecPanel?, _ runs: [CRun], _ dx: Double, _ dz: Double, _ circuitOf: (String) -> Circuit?) -> [Part3] {
    let ps = EParts()
    let s = ESc(dx: dx, dz: dz)
    let H = c.g.H
    for d in ds {
        let ty = devType(d.t)
        let col = circuitOf(d.id)?.rgb ?? E_BOX_RGB
        if d.onCeiling {
            let q = V2(Double(d.cx), Double(d.cy))
            switch d.t {
            case "ls":
                eDisc(ps.of(nil, E_PLATE, .furn), s, q, 48, H - 8, H - 2, 8)
                eDisc(ps.of(nil, E_LIGHT_RGB, .furn), s, q, 30, H - 10, H - 7, 8)
            case "lch":
                eDisc(ps.of(nil, E_PLATE, .furn), s, q, 60, H - 25, H - 2, 8)
                eDisc(ps.of(nil, 0x94A3B8, .furn), s, q, 10, H - 420, H - 25, 6)
                eDisc(ps.of(nil, E_LIGHT_RGB, .furn), s, q, Double(ty.dw) / 2, H - 560, H - 420, 12)
            default:
                eDisc(ps.of(nil, E_PLATE, .furn), s, q, Double(ty.dw) / 2, H - 40, H - 2, 12)
                eDisc(ps.of(nil, E_LIGHT_RGB, .furn), s, q, Double(ty.dw) / 2 - 30, H - 44, H - 40, 12)
            }
            continue
        }
        guard let w = c.wall(d.wall) else { continue }
        let (dw, dh) = devSize(d)
        let off = Double(d.off), hh = Double(d.h)
        let a0 = off - Double(dw) / 2, a1 = off + Double(dw) / 2, b0 = hh - Double(dh) / 2, b1 = hh + Double(dh) / 2
        if d.t == "led" {
            eWallBox(ps.of(w.id, E_LED_RGB, .opening), s, w, a0, a1, b0, b1, 0, 0.012)
        } else if d.t == "lw" {
            eWallBox(ps.of(w.id, E_PLATE, .opening), s, w, a0, a1, b0, b1, 0, 0.05)
            eWallBox(ps.of(w.id, E_LIGHT_RGB, .opening), s, w, a0 + 20, a1 - 20, b0 - 4, b0, 0.005, 0.045)
        } else if ty.cat == "box" {
            eWallBox(ps.of(w.id, E_BOX_RGB, .opening), s, w, a0, a1, b0, b1, 0, 0.01)
        } else {
            let plate = ty.cat == "sw" ? E_SW_PLATE : E_PLATE
            let dep = ty.cat == "sock" && ty.group != "sock" ? 0.025 : 0.014
            eWallBox(ps.of(w.id, plate, .opening), s, w, a0, a1, b0, b1, 0, dep)
            // the circuit's colour on the plate
            let m = Double(min(dw, dh)) * 0.22
            eWallBox(ps.of(w.id, col, .opening), s, w, off - m, off + m, hh - m, hh + m, dep, dep + 0.003)
        }
    }
    if let pn, pn.roomId == c.id, let w = c.wall(pn.wall) {
        let (pw, ph) = panelSize(0)
        let off = Double(pn.off), hh = Double(pn.h)
        let a0 = off - Double(pw) / 2, a1 = off + Double(pw) / 2, b0 = hh - Double(ph) / 2, b1 = hh + Double(ph) / 2
        eWallBox(ps.of(w.id, E_PANEL_RGB, .opening), s, w, a0, a1, b0, b1, 0, 0.1)
        eWallBox(ps.of(w.id, 0x64748B, .opening), s, w, a0 + 20, a1 - 20, hh - 4, hh + 4, 0.1, 0.104)
    }
    // the routes: 16 mm strips just off the walls and under the ceiling
    for r in runs {
        let rgb = r.circuit.rgb
        for g in r.segs {
            if g.len < 1 { continue }
            guard let wid = g.wall else {
                let dxp = g.b.x - g.a.x, dyp = g.b.y - g.a.y
                let l = max(hypot(dxp, dyp), 1e-9)
                let nx = -dyp / l * 8, ny = dxp / l * 8
                let q = [V2(g.a.x + nx, g.a.y + ny), V2(g.b.x + nx, g.b.y + ny), V2(g.b.x - nx, g.b.y - ny), V2(g.a.x - nx, g.a.y - ny)]
                let p = ps.of(nil, rgb, .furn)
                let pts = q.map { s.at($0, g.za) }
                p.faces.append(Face3(n: V3(0, -1, 0), pts: pts))
                p.faces.append(Face3(n: V3(0, 1, 0), pts: Array(pts.reversed())))
                continue
            }
            guard let w = c.wall(wid) else { continue }
            let n = V3(w.nIn.x, 0, w.nIn.y)
            let vertical = abs(g.za - g.zb) > 1
            let p = ps.of(w.id, rgb, .opening)
            var pts: [V3] = []
            if vertical {
                let tx = w.t.x * 8, ty = w.t.y * 8
                pts = [s.at(V2(g.a.x - tx, g.a.y - ty), g.za), s.at(V2(g.a.x + tx, g.a.y + ty), g.za),
                       s.at(V2(g.b.x + tx, g.b.y + ty), g.zb), s.at(V2(g.b.x - tx, g.b.y - ty), g.zb)]
            } else {
                pts = [s.at(g.a, g.za - 8), s.at(g.b, g.zb - 8), s.at(g.b, g.zb + 8), s.at(g.a, g.za + 8)]
            }
            p.faces.append(Face3(n: n, pts: pts))
        }
    }
    return ps.parts
}
