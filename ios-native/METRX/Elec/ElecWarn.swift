import Foundation

/*
 * Safety warnings (Android elec/Warn.kt; like the furniture's fz.* list): a socket too near water or gas, a switch behind
 * a door when it opens, a socket in a bathroom's splash zone, a device on a door or window, a circuit with too many
 * points or too much load for its breaker, and no panel placed.
 */

/// One warning: strings key (el.w.*), the room and device it is about, the values in its words.
struct EWarn {
    let key: String
    let roomId: String?
    let devId: String?
    var vars: [String: String] = [:]
}

/// The distance between a device and a site point in room c, mm (along the floor and up).
func distTo(_ c: ECtx, _ d: ElecDev, _ x: SitePoint) -> Double? {
    guard let q = c.planOf(x) else { return nil }
    let a = c.planOf(d)
    let z = d.onCeiling ? c.g.H : Double(d.h)
    return hypot(hypot(a.x - q.x, a.y - q.y), z - Double(x.h))
}

/// The nearest of the points xs to device d, mm (nil: none of them on a wall of the room).
private func nearestOf(_ c: ECtx, _ d: ElecDev, _ xs: [SitePoint]) -> Double? {
    var best: Double? = nil
    for x in xs {
        guard let v = distTo(c, d, x) else { continue }
        if best == nil || v < best! { best = v }
    }
    return best
}

/// The warnings of room c's devices ds.
func devWarnings(_ c: ECtx, _ ds: [ElecDev]) -> [EWarn] {
    var out: [EWarn] = []
    let water = c.wet.filter { WATER_T.contains($0.t) }
    let gasPts = c.wet.filter { GAS_T.contains($0.t) }
    for d in ds {
        let ty = devType(d.t)
        let w = c.wall(d.wall)
        if !d.onCeiling && w == nil { continue }
        if let w, Double(d.off) > w.len || Double(d.h) > c.g.H {
            out.append(EWarn(key: "el.w.out", roomId: c.id, devId: d.id, vars: ["w": w.id]))
            continue
        }
        let sockish = ty.cat == "sock"
        // the water heater's own socket goes high beside the heater, made for it: not a splash-zone socket
        if c.kind == "bath" && sockish && d.t == "pwh" {
            // nothing to warn about
        } else if c.kind == "bath" && sockish {
            let wet = nearestOf(c, d, water)
            if d.t != "sw" || (wet != nil && wet! < Double(WATER_MM)) { out.append(EWarn(key: "el.w.splash", roomId: c.id, devId: d.id)) }
        } else if sockish {
            if let wet = nearestOf(c, d, water), wet < Double(WATER_MM) {
                out.append(EWarn(key: "el.w.water", roomId: c.id, devId: d.id, vars: ["cm": "\(tInt(wet / 10))"]))
            }
        }
        if sockish || ty.cat == "sw" {
            if let gas = nearestOf(c, d, gasPts), gas < Double(GAS_MM) {
                out.append(EWarn(key: "el.w.gas", roomId: c.id, devId: d.id, vars: ["cm": "\(tInt(gas / 10))"]))
            }
        }
        guard let w else { continue }
        let (dw, dh) = devSize(d)
        let hw = Double(dw) / 2, hh = Double(dh) / 2
        let doors = c.room.openings.filter { $0.wall == w.id && $0.type == "door" }
        if ty.cat == "sw" && doors.contains(where: { o in d.off > o.off - o.w && d.off < o.off && d.h < o.h }) {
            out.append(EWarn(key: "el.w.door", roomId: c.id, devId: d.id))
        }
        let onOpening = c.room.openings.contains { o in
            let x0 = Double(d.off) - hw, x1 = Double(d.off) + hw, y0 = Double(d.h) - hh, y1 = Double(d.h) + hh
            return o.wall == w.id && x1 > Double(o.off) && x0 < Double(o.off + o.w) && y1 > Double(o.sill) && y0 < Double(o.sill + o.h)
        }
        if onOpening { out.append(EWarn(key: "el.w.open", roomId: c.id, devId: d.id)) }
    }
    return out
}

/// Every warning of the order: its rooms' devices, its circuits, the panel.
func warningsOf(_ p: Project, _ cs: [ECtx], _ circuits: [Circuit]) -> [EWarn] {
    var out: [EWarn] = []
    for c in cs { out += devWarnings(c, devsIn(p, c)) }
    for cc in circuits {
        let d = cc.def
        let only: String? = cc.rooms.count == 1 ? cc.rooms[0] : nil
        if cc.group != "low" && cc.points > d.maxPts {
            out.append(EWarn(key: "el.w.points", roomId: only, devId: nil, vars: ["g": "\(cc.no)", "n": "\(cc.points)", "m": "\(d.maxPts)"]))
        }
        if d.amps > 0 && cc.load > d.amps * 230 {
            out.append(EWarn(key: "el.w.load", roomId: only, devId: nil, vars: ["g": "\(cc.no)", "kw": String(format: "%.1f", Double(cc.load) / 1000), "a": "\(d.amps)"]))
        }
    }
    if livePanel(p) == nil && !p.elec.devs.isEmpty { out.append(EWarn(key: "el.w.noPanel", roomId: nil, devId: nil)) }
    return out
}

/// The order's panel while its room is there (a panel left on a deleted room counts as none).
func livePanel(_ p: Project) -> ElecPanel? {
    guard let pn = p.elec.panel, p.rooms.contains(where: { $0.id == pn.roomId }) else { return nil }
    return pn
}
