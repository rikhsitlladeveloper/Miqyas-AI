import Foundation

/*
 * A product as boxes at its true size (Android win/Mesh.kt), seen in its own frame: a along the wall from its left edge
 * (as seen from inside), d into the room from the wall's inside face (negative: in the wall), z up from its bottom. A
 * window's frame and mullions (each split in an inside and an outside half for the two colours), its sashes' own
 * profile, the glass (see-through), the panels, the handles, the nets outside; the sill inside, the drip outside, the
 * reveals; a door's frame, its leaf (glass for a glass door, in front of the wall for a sliding one) and its handle.
 * The room's 3D and the gallery's pictures are both drawn from these boxes.
 */

/// A box of a product, mm in its own frame (see above); its colour and opacity; glass a pane.
struct WBox {
    let a0: Double, a1: Double, d0: Double, d1: Double, z0: Double, z1: Double
    let rgb: Int
    var op = 1.0
    var glass = false
}

let W_GLASS_RGB = 0xA9C8EE
let W_HANDLE_RGB = 0xE9EAE6
let W_HANDLE_DARK = 0x5B6470
let W_NET_RGB = 0x4B5563
let W_SILL_RGB = 0xF7F7F4
let W_DRIP_RGB = 0xD9DDE3

/// Collects a product's boxes: a profile bar in its two colours, a ring of four bars.
private final class WBoxes {
    var out: [WBox] = []
    let cin: Int, cout: Int, dOut: Double, dIn: Double
    init(_ cin: Int, _ cout: Int, _ dOut: Double, _ dIn: Double) { self.cin = cin; self.cout = cout; self.dOut = dOut; self.dIn = dIn }

    func add(_ a0: Double, _ a1: Double, _ d0: Double, _ d1: Double, _ z0: Double, _ z1: Double, _ rgb: Int, _ op: Double = 1, glass: Bool = false) {
        out.append(WBox(a0: a0, a1: a1, d0: d0, d1: d1, z0: z0, z1: z1, rgb: rgb, op: op, glass: glass))
    }

    /// A profile bar: the inside half in the inside colour, the outside half in the outside one.
    func bar(_ a0: Double, _ a1: Double, _ z0: Double, _ z1: Double, _ d0: Double? = nil, _ d1: Double? = nil) {
        let b0 = d0 ?? dOut, b1 = d1 ?? dIn
        let m = (b0 + b1) / 2
        add(a0, a1, m, b1, z0, z1, cin)
        add(a0, a1, b0, m, z0, z1, cout)
    }

    func ring(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ f: Double, _ d0: Double, _ d1: Double) {
        bar(x0, x0 + f, y0, y1, d0, d1)
        bar(x1 - f, x1, y0, y1, d0, d1)
        bar(x0 + f, x1 - f, y0, y0 + f, d0, d1)
        bar(x0 + f, x1 - f, y1 - f, y1, d0, d1)
    }
}

/// A door's frame, leaf and handle.
private func wDoorBoxes(_ it: WinItem, _ bx: WBoxes, _ r: Double, _ D: Double) {
    let W = Double(it.w), H = Double(it.h)
    let F = Double(W_DOOR_FRAME)
    let dd0 = -r - D, dd1 = -r
    let cin = bx.cin
    let dIn = bx.dIn, dOut = bx.dOut
    bx.add(0, F, dd0, dd1, 0, H, cin)
    bx.add(W - F, W, dd0, dd1, 0, H, cin)
    bx.add(F, W - F, dd0, dd1, H - F, H, cin)
    let left = it.hinge != "R"
    let silver = wColourRgb("silver")
    switch it.kind {
    case "dsl":
        // the leaf hangs in front of the wall on its rail, closed over the opening
        bx.add(-30, W + 30, 8, 48, 10, H + 10, cin)
        bx.add(-40, 2 * W, 0, 60, H + 30, H + 80, W_DRIP_RGB)
        let hx: Double = left ? W - 20 : 20
        bx.add(hx - 12, hx + 12, 48, 70, 900, 1100, W_HANDLE_DARK)
    case "dgl":
        bx.add(F + 2, W - F - 2, dIn - 34, dIn - 24, 10, H - F - 2, W_GLASS_RGB, 0.4, glass: true)
        bx.add(F + 2, W - F - 2, dIn - 40, dIn - 18, 10, 90, silver)
        bx.add(F + 2, W - F - 2, dIn - 40, dIn - 18, H - F - 60, H - F - 2, silver)
        let hx: Double = left ? W - F - 70 : F + 70
        bx.add(hx - 12, hx + 12, dIn - 18, dIn + 40, 700, 1300, silver)
    default:
        let inSwing = it.swing == "in"
        let l0: Double = inSwing ? dIn - 44 : dOut + 4
        let l1 = l0 + 40
        bx.add(F + 2, W - F - 2, l0, l1, 10, H - F - 2, cin)
        let hx: Double = left ? W - F - 70 : F + 70
        let hc: Int = it.kind == "dent" ? W_HANDLE_DARK : silver
        bx.add(hx - 60, hx + 12, l1, l1 + 45, 990, 1015, hc)
        bx.add(hx - 14, hx + 14, l1, l1 + 10, 940, 1060, hc)
    }
}

/// An opening sash's own profile, glass, handle and net.
private func wOpenSashBoxes(_ it: WinItem, _ s: WSash, _ bx: WBoxes, _ D: Double, _ S: Double, _ handleRgb: Int) {
    let c = s.r
    let dIn = bx.dIn, dOut = bx.dOut
    // the sash's own profile inside its cell, standing a little into the room, and its glass
    let s0 = dIn - D * 0.55
    let s1 = dIn + 8
    bx.ring(c.x0, c.y0, c.x1, c.y1, S, s0, s1)
    let gm = (s0 + s1) / 2
    bx.add(c.x0 + S, c.x1 - S, gm - 4, gm + 4, c.y0 + S, c.y1 - S, W_GLASS_RGB, 0.35, glass: true)
    if it.handles {
        let mid = (c.y0 + c.y1) / 2
        switch s.t {
        case "tilt":
            let x = (c.x0 + c.x1) / 2
            bx.add(x - 70, x + 10, s1, s1 + 40, c.y1 - S / 2 - 12, c.y1 - S / 2 + 12, handleRgb)
        case "slide":
            let x: Double = s.cell.hinge == "R" ? c.x0 + S / 2 : c.x1 - S / 2
            bx.add(x - 10, x + 10, s1, s1 + 30, mid - 90, mid + 90, handleRgb)
        default:
            let x: Double = s.cell.hinge == "R" ? c.x0 + S / 2 : c.x1 - S / 2
            bx.add(x - 12, x + 12, s1, s1 + 14, mid - 40, mid + 40, handleRgb)
            bx.add(x - 11, x + 11, s1 + 14, s1 + 50, mid - 130, mid - 20, handleRgb)
        }
    }
    if it.net { bx.add(c.x0 + 10, c.x1 - 10, dOut - 10, dOut - 4, c.y0 + 10, c.y1 - 10, W_NET_RGB, 0.45) }
}

/// The boxes of it standing in a wall t thick (its frame r in from the inside face); floor in a door opening (no sill
/// under it).
func wProductBoxes(_ it: WinItem, _ t: Int, _ floor: Bool) -> [WBox] {
    let D = Double(wFrameDepth(it))
    let r = Double(wRevealOf(t, wFrameDepth(it)))
    let dIn = -r, dOut = -r - D, dMid = -r - D / 2
    let W = Double(it.w), H = Double(it.h)
    let bx = WBoxes(wColourRgb(it.colIn), wColourRgb(it.colOut), dOut, dIn)
    if it.isDoor {
        wDoorBoxes(it, bx, r, D)
        return bx.out + wExtraBoxes(it, t, r, floor)
    }
    let handleRgb = it.colIn == "white" ? W_HANDLE_RGB : W_HANDLE_DARK
    let F = Double(wFrameF(it.profile))
    let M = Double(wMullF(it.profile)) / 2
    let S = Double(wSashF(it.profile))
    bx.ring(0, 0, W, H, F, dOut, dIn)
    for b in wBarsOf(it) {
        if b.vertical { bx.bar(b.x0 - M, b.x0 + M, b.y0, b.y1) } else { bx.bar(b.x0, b.x1, b.y0 - M, b.y0 + M) }
    }
    for s in wSashesOf(it) {
        let c = s.r
        if s.t == "panel" {
            bx.add(c.x0, c.x1, dMid - 12, dMid + 12, c.y0, c.y1, bx.cin)
        } else if s.opens {
            wOpenSashBoxes(it, s, bx, D, S, handleRgb)
        } else {
            bx.add(c.x0, c.x1, dMid - 4, dMid + 4, c.y0, c.y1, W_GLASS_RGB, 0.35, glass: true)
        }
    }
    return bx.out + wExtraBoxes(it, t, r, floor)
}

/// The sill (inside), the drip (outside) and the reveals of it in a wall t thick with its reveal r.
private func wExtraBoxes(_ it: WinItem, _ t: Int, _ r: Double, _ floor: Bool) -> [WBox] {
    var out: [WBox] = []
    let W = Double(it.w), H = Double(it.h), g = Double(it.gap)
    if !it.isDoor && it.sill > 0 && !floor {
        let ear = Double(W_SILL_EAR)
        out.append(WBox(a0: -ear, a1: W + ear, d0: -r, d1: Double(it.sill) - r, z0: -22, z1: -2, rgb: W_SILL_RGB))
    }
    if !it.isDoor && it.drip && !floor {
        let ear = Double(W_DRIP_EAR)
        let d1 = -r - Double(wFrameDepth(it))
        out.append(WBox(a0: -ear, a1: W + ear, d0: -Double(t) - 50, d1: d1, z0: -32, z1: -18, rgb: W_DRIP_RGB))
    }
    if it.reveals {
        let top = H + g
        let bot: Double = floor ? 0 : -g
        out.append(WBox(a0: -g, a1: -g + 8, d0: -r, d1: 0, z0: bot, z1: top, rgb: W_SILL_RGB))
        out.append(WBox(a0: W + g - 8, a1: W + g, d0: -r, d1: 0, z0: bot, z1: top, rgb: W_SILL_RGB))
        out.append(WBox(a0: -g, a1: W + g, d0: -r, d1: 0, z0: top - 8, z1: top, rgb: W_SILL_RGB))
    }
    return out
}

/* ---------------- in the room's 3D ---------------- */

/// Parts keyed by wall, colour and opacity as they fill.
private final class WParts3 {
    var keys: [String] = []
    var map: [String: Part3] = [:]
    func of(_ wall: String, _ rgb: Int, _ op: Double) -> Part3 {
        let k = "\(wall)|\(rgb)|\(op)"
        if let p = map[k] { return p }
        let p = Part3(0, wall, .opening, rgb, op)
        map[k] = p; keys.append(k)
        return p
    }
    var parts: [Part3] { keys.compactMap { map[$0] } }
}

/// One box of a placed product as six faces in part f.
private func wBoxFaces(_ f: Part3, _ pl: WPlaced, _ b: WBox, _ dx: Double, _ dz: Double) {
    let w = pl.w
    func at(_ a: Double, _ d: Double, _ z: Double) -> V3 {
        let q = w.at(pl.a0 + a, d)
        return V3(q.x / 1000 + dx, (pl.z0 + z) / 1000, q.y / 1000 + dz)
    }
    let n = V3(w.nIn.x, 0, w.nIn.y)
    let tt = V3(w.t.x, 0, w.t.y)
    let up = V3(0, 1, 0)
    f.faces.append(Face3(n: n, pts: [at(b.a0, b.d1, b.z0), at(b.a1, b.d1, b.z0), at(b.a1, b.d1, b.z1), at(b.a0, b.d1, b.z1)]))
    f.faces.append(Face3(n: n * -1, pts: [at(b.a0, b.d0, b.z0), at(b.a0, b.d0, b.z1), at(b.a1, b.d0, b.z1), at(b.a1, b.d0, b.z0)]))
    f.faces.append(Face3(n: up, pts: [at(b.a0, b.d0, b.z1), at(b.a0, b.d1, b.z1), at(b.a1, b.d1, b.z1), at(b.a1, b.d0, b.z1)]))
    f.faces.append(Face3(n: up * -1, pts: [at(b.a0, b.d0, b.z0), at(b.a1, b.d0, b.z0), at(b.a1, b.d1, b.z0), at(b.a0, b.d1, b.z0)]))
    f.faces.append(Face3(n: tt * -1, pts: [at(b.a0, b.d0, b.z0), at(b.a0, b.d1, b.z0), at(b.a0, b.d1, b.z1), at(b.a0, b.d0, b.z1)]))
    f.faces.append(Face3(n: tt, pts: [at(b.a1, b.d0, b.z0), at(b.a1, b.d0, b.z1), at(b.a1, b.d1, b.z1), at(b.a1, b.d1, b.z0)]))
}

/// The 3D of the products pls in room c; the plan's corner at (dx, dz) metres in the scene.
func winParts(_ c: WCtx, _ pls: [WPlaced], _ dx: Double, _ dz: Double) -> [Part3] {
    let ps = WParts3()
    for pl in pls {
        for b in wProductBoxes(pl.it, c.T, pl.doorOpening) {
            if b.a1 - b.a0 < 0.5 || b.d1 - b.d0 < 0.5 || b.z1 - b.z0 < 0.5 { continue }
            wBoxFaces(ps.of(pl.w.id, b.rgb, b.op), pl, b, dx, dz)
        }
    }
    return ps.parts
}
