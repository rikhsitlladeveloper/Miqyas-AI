import Foundation

/*
 * The rules (Android plumb/Warn.kt; like the electrician's el.w.* list): a drain laid too flat for its diameter, a 50
 * drain too long to the riser, a toilet too far from it, an outlet at the wrong height for its fixture, a fixture in a
 * door's way or off its wall, no riser placed, no hot water, heating with no boiler.
 */

/// One warning: strings key (sx.w.*), the room and the fixture or outlet it is about, the values in its words (a value
/// "~key" is itself a strings key).
struct PWarn {
    let key: String
    let roomId: String?
    let target: String?
    var vars: [String: String] = [:]
}

private func pCm1(_ mm: Double) -> String { String(format: "%.1f", mm / 10) }
private func pM1(_ mm: Double) -> String { String(format: "%.1f", mm / 1000) }

/// The warnings of room c's fixtures fs and outlets pts.
func fixWarnings(_ c: PCtx, _ fs: [PlFix], _ pts: [APt]) -> [PWarn] {
    var out: [PWarn] = []
    for f in fs {
        let w = c.wall(f.wall)
        let half = Double(fixW(f)) / 2
        if w == nil || Double(f.off) - half < -1 || Double(f.off) + half > w!.len + 1 {
            out.append(PWarn(key: "sx.w.out", roomId: c.id, target: f.id, vars: ["w": f.wall]))
            continue
        }
        if blocksDoor(c, f) { out.append(PWarn(key: "sx.w.door", roomId: c.id, target: f.id)) }
    }
    for q in pts {
        guard let u = q.usual else { continue }
        if abs(q.h - u) > q.tol {
            let vars = ["k": "~sx.o." + q.t, "h": pCm1(Double(q.h)), "u": pCm1(Double(u))]
            out.append(PWarn(key: "sx.w.height", roomId: c.id, target: q.fix ?? q.id, vars: vars))
        }
    }
    return out
}

/// Every warning of the order: its rooms' fixtures, its drains, the riser, the hot water and the heating's boiler.
func pWarningsOf(_ p: Project, _ cs: [PCtx], _ rt: PRoutes) -> [PWarn] {
    var out: [PWarn] = []
    var all: [APt] = []
    var typeOf: [String: String] = [:]
    for c in cs {
        let fs = fixesIn(p, c)
        let pts = pointsIn(p, c, fs)
        all += pts
        out += fixWarnings(c, fs, pts)
        for f in fs { typeOf[f.id] = f.t }
        // a typed room too small for what it was given
        if let fr = c.free {
            for (t, n) in pFreeMissing(fr, fs) { out.append(PWarn(key: "sx.w.noFit", roomId: c.id, target: nil, vars: ["t": "~sx.t." + t, "n": "\(n)"])) }
        }
    }
    for d in rt.drains {
        let who = d.pt.fix ?? d.pt.id
        let ms = Double(minSlope(d.dia))
        if d.horiz > 0 && d.slope + 1e-6 < ms {
            out.append(PWarn(key: "sx.w.slope", roomId: d.pt.roomId, target: who, vars: ["s": pCm1(d.slope), "m": pCm1(ms), "d": "\(d.dia)"]))
        }
        let wc = d.pt.fix.flatMap { typeOf[$0] } == "wc"
        if wc && d.horiz > Double(p.plumb.wcMax) {
            out.append(PWarn(key: "sx.w.wcFar", roomId: d.pt.roomId, target: who, vars: ["m": pM1(d.horiz), "x": pM1(Double(p.plumb.wcMax))]))
        } else if d.dia < 100 && d.horiz > Double(p.plumb.drainMax) {
            out.append(PWarn(key: "sx.w.long", roomId: d.pt.roomId, target: who, vars: ["m": pM1(d.horiz), "x": pM1(Double(p.plumb.drainMax))]))
        }
    }
    // heating alone (radiators, underfloor) needs no riser: only water or a drain does; rooms typed by size have no wall for one
    if rt.riser == nil && cs.contains(where: { $0.free == nil }) && all.contains(where: { $0.t == "cold" || $0.t == "drain" }) { out.append(PWarn(key: "sx.w.noRiser", roomId: nil, target: nil)) }
    if rt.riser != nil && rt.hot == nil && all.contains(where: { $0.t == "hot" }) { out.append(PWarn(key: "sx.w.noHot", roomId: nil, target: nil)) }
    let heating = all.contains { $0.t == "hs" || $0.t == "hr" } || cs.contains { $0.pr.ufh }
    if rt.heat == nil && heating { out.append(PWarn(key: "sx.w.noBoiler", roomId: nil, target: nil)) }
    return out
}

/// The order's riser while its room is there (a riser left on a deleted room counts as none).
func liveRiser(_ p: Project) -> PlRiser? {
    guard let r = p.plumb.riser, p.rooms.contains(where: { $0.id == r.roomId }) else { return nil }
    return r
}

/// The riser the next step asks to place: when the order has none, needs one, and a drawn room can take it. Rooms typed
/// by size only cannot hold a riser, so such an order is not asked for one (nil).
func riserToPlace(_ p: Project, _ snap: Bool) -> PlRiser? {
    liveRiser(p) == nil && needsRiser(p) ? defaultRiser(p, snap) : nil
}

/// Whether order p has water or a drain to bring (a cold or drain outlet): a heating-only order needs no riser.
func needsRiser(_ p: Project) -> Bool {
    let wet: (String) -> Bool = { $0 == "cold" || $0 == "drain" }
    if p.plumb.fixes.contains(where: { f in fixPoints(f).contains { wet($0.t) } }) { return true }
    if p.plumb.points.contains(where: { wet($0.t) }) { return true }
    return p.plumb.free.contains { f in
        let a = f.wc + f.basin + f.bath + f.shower + f.sink
        let b = f.wm + f.dw + f.wh + f.gb
        return a + b > 0
    }
}
