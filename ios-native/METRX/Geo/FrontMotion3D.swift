import Foundation

/*
 * Doors and drawers that move without the room being rebuilt (Android geo/Fronts3D.kt, 26 Oct 2026). With
 * furniture3D(split: true) each door, drawer, sliding door, rack and lift-up bed base is built once, shut, as a Front3D
 * of its own: its boards, handle and outlines, its tap boxes, a drawer's box (shown only while it is out) and how it
 * moves (FrontMotion: a turn about its hinge, a pull out or a slide). The 3D (Three/Scene3D.swift) draws it as its own
 * entities and on every step of the animation only sets their transform; the rest of the piece (Furn3D.parts) is built
 * and merged per look once and stays put. The mesh stays the shut one, so a board's picture (its wood grain) moves
 * with the door.
 */

/// A rigid move: rotation m (3 × 3, row-major) then translation t (metres).
struct Rigid3 {
    let m: [Double]
    let t: V3

    static let identity: [Double] = [1, 0, 0, 0, 1, 0, 0, 0, 1]

    func dir(_ v: V3) -> V3 {
        let x: Double = m[0] * v.x + m[1] * v.y + m[2] * v.z
        let y: Double = m[3] * v.x + m[4] * v.y + m[5] * v.z
        let z: Double = m[6] * v.x + m[7] * v.y + m[8] * v.z
        return V3(x, y, z)
    }
    func point(_ p: V3) -> V3 { dir(p) + t }
    /// The box moved with it (its corner moved, its edges turned).
    func obb(_ x: Obb) -> Obb { Obb(o: point(x.o), a: dir(x.a), b: dir(x.b), c: dir(x.c)) }
}

/// How a front moves when fully open: turned angle radians (right-handed) about the line through pivot along the unit
/// axis, then moved by shift (metres). Partly open (at) both go in proportion, as the full rebuild does (a door's angle,
/// a drawer's pull, a sliding door's shift and the lift-up base's tilt are all linear in how far it is open).
struct FrontMotion {
    let pivot: V3, axis: V3, angle: Double, shift: V3

    /// Turned angle about the line through pivot along axis (a hinge, a lift-up bed's base).
    static func turn(_ pivot: V3, _ axis: V3, _ angle: Double) -> FrontMotion {
        FrontMotion(pivot: pivot, axis: axis.unit, angle: angle, shift: V3(0, 0, 0))
    }
    /// Moved along by (a drawer pulled out, a sliding door, a rack).
    static func move(_ by: V3) -> FrontMotion { FrontMotion(pivot: V3(0, 0, 0), axis: V3(0, 1, 0), angle: 0, shift: by) }

    /// The rotation by a about the unit axis k (Rodrigues), row-major.
    private static func rotation(_ k: V3, _ a: Double) -> [Double] {
        let c = cos(a), s = sin(a), t = 1 - c
        let x = k.x, y = k.y, z = k.z
        var m = [Double](repeating: 0, count: 9)
        m[0] = t * x * x + c; m[1] = t * x * y - s * z; m[2] = t * x * z + s * y
        m[3] = t * x * y + s * z; m[4] = t * y * y + c; m[5] = t * y * z - s * x
        m[6] = t * x * z - s * y; m[7] = t * y * z + s * x; m[8] = t * z * z + c
        return m
    }

    /// The rigid move of a front k (0 shut … 1 open) of the way open: p' = R (p − pivot) + pivot + shift k.
    func at(_ k: Double) -> Rigid3 {
        let a = angle * k
        let m = a == 0 ? Rigid3.identity : FrontMotion.rotation(axis, a)
        let r0 = Rigid3(m: m, t: V3(0, 0, 0))
        let rp = r0.dir(pivot)
        let tx: Double = pivot.x - rp.x + shift.x * k
        let ty: Double = pivot.y - rp.y + shift.y * k
        let tz: Double = pivot.z - rp.z + shift.z * k
        return Rigid3(m: m, t: V3(tx, ty, tz))
    }
}

/// One door, drawer, sliding door, rack or lift-up base (key), built shut: its parts (its board in the piece's style, its
/// handle, a mirror, glass…) and edges, its tap boxes picks, and inner, what shows only while it is open at all (a
/// drawer's box, which the full rebuild leaves out when shut). motion moves all of them together.
struct Front3D {
    let key: String
    let motion: FrontMotion
    let parts: [Part3], edges: [Edges3], picks: [Pick]
    let inner: [Part3], innerEdges: [Edges3]
    /// Where it is k of the way open.
    func at(_ k: Double) -> Rigid3 { motion.at(k) }
}

/// What the builder collects into while it draws one front: its own store (parts merged per look) and one for the
/// drawer's box.
final class FrontCap {
    let key: String
    let motion: FrontMotion
    let main = FStore()
    let inner = FStore()
    init(_ key: String, _ motion: FrontMotion) { self.key = key; self.motion = motion }

    private static func parts(_ s: FStore) -> [Part3] {
        var out: [Part3] = []
        for k in s.order { if let p = s.parts[k], !p.faces.isEmpty { out.append(p) } }
        return out
    }
    private static func edges(_ s: FStore) -> [Edges3] {
        var out: [Edges3] = []
        for k in s.edgeOrder { if let e = s.edges[k], !e.segs.isEmpty { out.append(e) } }
        return out
    }

    func done() -> Front3D {
        Front3D(key: key, motion: motion, parts: FrontCap.parts(main), edges: FrontCap.edges(main), picks: main.picks,
                inner: FrontCap.parts(inner), innerEdges: FrontCap.edges(inner))
    }
}

extension Furn3D {
    /// The tap boxes of everything that can be opened, each where it is with the fronts as open as amt says (0…1, as
    /// Scene3D poses them: the same clamp and the same FrontMotion.at, so a tap finds a front where it is drawn).
    func picksAt(_ amt: (String) -> Double) -> [Pick] {
        if fronts.isEmpty { return picks }
        var out = picks
        for fr in fronts {
            let k = min(1, max(0, amt(fr.key)))
            let r = fr.at(k)
            for pk in fr.picks { out.append(Pick(key: pk.key, box: k == 0 ? pk.box : r.obb(pk.box))) }
        }
        return out
    }

    /// The door or drawer a ray meets first, with the fronts as open as amt says (where they are drawn now).
    func pick(_ e: V3, _ d: V3, amt: (String) -> Double) -> String? {
        var best: (String, Double)? = nil
        for pk in picksAt(amt) {
            if let t = pk.box.hit(e, d), best == nil || t < best!.1 { best = (pk.key, t) }
        }
        return best?.0
    }
}
