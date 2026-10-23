import Foundation

/*
 * The rules (Android win/Warn.kt; like the plumber's sx.w.* list): a sash too narrow, wide, high, big or heavy for the
 * way it opens; a turning sash or a door's leaf sweeping into a radiator, a fixture or the furniture, or into another
 * door's swing; a product bigger than its opening; a sill sticking out of the reveal; a product whose opening was taken
 * away.
 */

/// One warning: strings key (dw.w.*), the room and product it is about, the values in its words (a value "~key" is
/// itself a strings key).
struct WWarn {
    let key: String
    let roomId: String?
    let target: String?
    var vars: [String: String] = [:]
}

/// How big a sash that opens may be: its width, height, area (m²) and weight (kg).
struct WSashLim {
    let minW: Int, maxW: Int, maxH: Int
    let maxArea: Double, maxKg: Double
}

/// The limits of a sash that opens t in profile; a door's sash (door, one at least W_DOOR_SASH_H high) has its own:
/// turning 900 × 1600 (a door's 1000 × 2400), tilt-and-turn the same and at most 1,3 m² (a door's 2,4), a tilting
/// fanlight 1600 × 1000 and 40 kg, a sliding sash 1500 wide in PVC and 2000 in aluminium, 2400 high.
func wLimOf(_ t: String, _ profile: String, _ door: Bool) -> WSashLim? {
    switch t {
    case "turn":
        return door ? WSashLim(minW: 400, maxW: 1000, maxH: 2400, maxArea: 2.4, maxKg: 90) : WSashLim(minW: 350, maxW: 900, maxH: 1600, maxArea: 1.6, maxKg: 60)
    case "tt":
        return door ? WSashLim(minW: 400, maxW: 1000, maxH: 2400, maxArea: 2.4, maxKg: 100) : WSashLim(minW: 350, maxW: 900, maxH: 1600, maxArea: 1.3, maxKg: 70)
    case "tilt":
        return WSashLim(minW: 350, maxW: 1600, maxH: 1000, maxArea: 1.6, maxKg: 40)
    case "slide":
        let alu = profile == "alu"
        return WSashLim(minW: 400, maxW: alu ? 2000 : 1500, maxH: 2400, maxArea: 3.6, maxKg: alu ? 150 : 100)
    default:
        return nil
    }
}

private func wwCm(_ mm: Double) -> String { String(tInt(eMathRoundP(mm / 10))) }
private func wwD2(_ v: Double) -> String { String(format: "%.2f", v) }
private func wwD0(_ v: Double) -> String { String(tInt(eMathRoundP(v))) }

private func wwMerge(_ a: [String: String], _ b: [String: String]) -> [String: String] { a.merging(b) { _, n in n } }

/// The warnings of product it's sashes (in room roomId).
func wSashWarnings(_ it: WinItem, _ roomId: String?) -> [WWarn] {
    if it.isDoor { return [] }
    var out: [WWarn] = []
    for (i, s) in wSashesOf(it).enumerated() {
        guard let lim = wLimOf(s.t, it.profile, s.r.h >= Double(W_DOOR_SASH_H)) else { continue }
        let v: [String: String] = ["n": "\(i + 1)", "k": "~dw.t." + s.t]
        if s.r.w < Double(lim.minW) {
            out.append(WWarn(key: "dw.w.narrow", roomId: roomId, target: it.id, vars: wwMerge(v, ["v": wwCm(s.r.w), "x": wwCm(Double(lim.minW))])))
        } else if s.r.w > Double(lim.maxW) {
            out.append(WWarn(key: "dw.w.wide", roomId: roomId, target: it.id, vars: wwMerge(v, ["v": wwCm(s.r.w), "x": wwCm(Double(lim.maxW))])))
        }
        if s.r.h > Double(lim.maxH) {
            out.append(WWarn(key: "dw.w.high", roomId: roomId, target: it.id, vars: wwMerge(v, ["v": wwCm(s.r.h), "x": wwCm(Double(lim.maxH))])))
        } else if s.r.w <= Double(lim.maxW) && s.r.area > lim.maxArea {
            out.append(WWarn(key: "dw.w.area", roomId: roomId, target: it.id, vars: wwMerge(v, ["v": wwD2(s.r.area), "x": wwD2(lim.maxArea)])))
        }
        let kg = wSashKg(it, s)
        if kg > lim.maxKg {
            out.append(WWarn(key: "dw.w.heavy", roomId: roomId, target: it.id, vars: wwMerge(v, ["v": wwD0(kg), "x": wwD0(lim.maxKg)])))
        }
    }
    return out
}

/// The warnings of placed product pl in room c with what stands there obs and the other doors' swings doors.
func wPlacedWarnings(_ c: WCtx, _ pl: WPlaced, _ obs: [WObst], _ doors: [WSweep]) -> [WWarn] {
    let it = pl.it, o = pl.o
    var out: [WWarn] = []
    // the opening was made a door (or a window) after the product went in: it is the wrong kind for it now
    if !wFillsType(it.kind, o.type) {
        out.append(WWarn(key: "dw.w.type", roomId: c.id, target: it.id, vars: ["k": "~dw.k." + it.kind, "o": "~" + (o.type == "door" ? "op.door" : "op.window")]))
    }
    if it.w > o.w || it.h > o.h {
        let vars = ["w": wwCm(Double(it.w)), "h": wwCm(Double(it.h)), "a": wwCm(Double(o.w)), "b": wwCm(Double(o.h))]
        out.append(WWarn(key: "dw.w.big", roomId: c.id, target: it.id, vars: vars))
    }
    if !it.isDoor && it.sill > 0 && it.sill > pl.r + W_SILL_OVER_MAX {
        let vars = ["s": wwCm(Double(it.sill)), "r": wwCm(Double(pl.r)), "m": wwCm(Double(it.sill - pl.r))]
        out.append(WWarn(key: "dw.w.sill", roomId: c.id, target: it.id, vars: vars))
    }
    out += wSashWarnings(it, c.id)
    for sw in wSashSweeps(pl) {
        let door = it.isDoor
        if let ob = obs.first(where: { ob in ob.z1 > sw.z0 + 1 && ob.z0 < sw.z1 - 1 && convexHit(sw.poly, ob.poly) }) {
            out.append(WWarn(key: door ? "dw.w.swing" : "dw.w.blocked", roomId: c.id, target: it.id, vars: ["o": "~" + ob.what, "n": "\(sw.sash + 1)"]))
        }
        if door && doors.contains(where: { d in d.item != it.id && convexHit(sw.poly, d.poly) }) {
            out.append(WWarn(key: "dw.w.doors", roomId: c.id, target: it.id))
        }
    }
    return out
}

/// Every warning of the order: each room's products, and the products without a room.
func wWarningsOf(_ p: Project, _ cs: [WCtx], _ snap: Bool) -> [WWarn] {
    var out: [WWarn] = []
    for c in cs {
        let items = wItemsIn(p, c)
        let pls = items.compactMap { wPlaced(c, $0) }
        for i in items where !pls.contains(where: { $0.it.id == i.id }) {
            out.append(WWarn(key: "dw.w.gone", roomId: c.id, target: i.id))
        }
        let obs = wObstaclesIn(p, c, snap)
        // the doors' swings: the products', and the doors not filled yet as they usually open
        let filled = Set(pls.map(\.o.id))
        var doors: [WSweep] = pls.compactMap { wDoorSweep($0) }
        for o in c.room.openings where o.type == "door" && !filled.contains(o.id) {
            if let s = wOpenSwing(c, o) { doors.append(s) }
        }
        for pl in pls { out += wPlacedWarnings(c, pl, obs, doors) }
    }
    // products whose room is gone or not measured: the sashes still have their rules
    let seen = Set(cs.map(\.id))
    for it in p.win.items where it.inRoom && !seen.contains(it.roomId ?? "") {
        out += wSashWarnings(it, it.roomId)
    }
    return out
}
