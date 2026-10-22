import Foundation

/*
 * Counting from the parts (the advanced app; Android win/Count.kt): profile metres of frame, opening sashes and mullions
 * per profile system, glass by the unit's chambers and panels in m², laminate by the metre and side, hardware by sash
 * type, handles, nets, sills, drips and reveals; doors by type and area with their lock and hinges; the labour per m²
 * of window, per door and per metre or m² of the extras. A price list per profile system (PVC, aluminium) and the rest
 * common.
 */

/// One profile system's prices: frame, sash and mullion a metre; hardware per sash that turns, tilts, tilts and turns,
/// slides; fitting a m² of window.
struct WSys: Codable, Equatable {
    var frameM: String
    var sashM: String
    var mullM: String
    var hwTurn: String
    var hwTilt: String
    var hwTT: String
    var hwSlide: String
    var lM2: String

    func hw(_ t: String) -> String {
        switch t {
        case "turn": return hwTurn
        case "tilt": return hwTilt
        case "tt": return hwTT
        default: return hwSlide
        }
    }
}

extension WSys {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let z = WIN_PVC
        frameM = c.v(.frameM, z.frameM); sashM = c.v(.sashM, z.sashM); mullM = c.v(.mullM, z.mullM)
        hwTurn = c.v(.hwTurn, z.hwTurn); hwTilt = c.v(.hwTilt, z.hwTilt); hwTT = c.v(.hwTT, z.hwTT); hwSlide = c.v(.hwSlide, z.hwSlide)
        lM2 = c.v(.lM2, z.lM2)
    }
}

let WIN_PVC = WSys(frameM: "45000", sashM: "55000", mullM: "40000", hwTurn: "120000", hwTilt: "90000", hwTT: "220000", hwSlide: "180000", lM2: "180000")
let WIN_ALU = WSys(frameM: "85000", sashM: "95000", mullM: "75000", hwTurn: "150000", hwTilt: "110000", hwTT: "280000", hwSlide: "160000", lM2: "200000")

/// The windows-and-doors maker's prices, one set for all orders (whole currency units): each profile system's, the
/// glass units and panels a m², laminating a metre of profile a side, the extras, doors a m² by type with their lock and
/// hinges, and the labour.
struct WinPrices: Codable, Equatable {
    var pvc = WIN_PVC
    var alu = WIN_ALU
    var glass1 = "180000", glass2 = "260000", panel = "150000", lam = "25000"
    var sill = "120000", drip = "60000", reveal = "90000", net = "70000", handle = "35000"
    var dInt = "1200000", dEnt = "2800000", dSl = "1600000", dGl = "2200000", hwDoor = "250000"
    var lDoor = "300000", lSill = "30000", lReveal = "80000", lDrip = "20000"
    init() {}

    func sys(_ s: String) -> WSys { s == "alu" ? alu : pvc }
    func door(_ k: String) -> String {
        switch k {
        case "dent": return dEnt
        case "dsl": return dSl
        case "dgl": return dGl
        default: return dInt
        }
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let z = WinPrices()
        pvc = c.v(.pvc, z.pvc); alu = c.v(.alu, z.alu)
        glass1 = c.v(.glass1, z.glass1); glass2 = c.v(.glass2, z.glass2); panel = c.v(.panel, z.panel); lam = c.v(.lam, z.lam)
        sill = c.v(.sill, z.sill); drip = c.v(.drip, z.drip); reveal = c.v(.reveal, z.reveal); net = c.v(.net, z.net); handle = c.v(.handle, z.handle)
        dInt = c.v(.dInt, z.dInt); dEnt = c.v(.dEnt, z.dEnt); dSl = c.v(.dSl, z.dSl); dGl = c.v(.dGl, z.dGl); hwDoor = c.v(.hwDoor, z.hwDoor)
        lDoor = c.v(.lDoor, z.lDoor); lSill = c.v(.lSill, z.lSill); lReveal = c.v(.lReveal, z.lReveal); lDrip = c.v(.lDrip, z.lDrip)
    }
}

/// Whether colour c is a laminate on profile (white PVC and silver aluminium are the profile's own).
func wLaminated(_ profile: String, _ c: String) -> Bool { c != "white" && !(profile == "alu" && c == "silver") }

/// A profile system's share of the order: metres, hardware by sash type, the windows' area.
struct WSysCount {
    var frameM = 0.0, sashM = 0.0, mullM = 0.0
    var hw: [String: Int] = [:]
    var winM2 = 0.0
    var profileM: Double { frameM + sashM + mullM }

    func plus(_ o: WSysCount) -> WSysCount {
        var h = hw
        for (k, v) in o.hw { h[k, default: 0] += v }
        return WSysCount(frameM: frameM + o.frameM, sashM: sashM + o.sashM, mullM: mullM + o.mullM, hw: h, winM2: winM2 + o.winM2)
    }
}

/// What an order takes. doors: by type, pieces and m².
struct WCount {
    var sys: [String: WSysCount] = [:]
    var glass1 = 0.0, glass2 = 0.0, panel = 0.0, lamM = 0.0
    var sillM = 0.0, dripM = 0.0, revealM2 = 0.0
    var nets = 0, handles = 0
    var doors: [String: (Int, Double)] = [:]
    var doorHw = 0
    var windows = 0, doorN = 0

    var pieces: Int { windows + doorN }
    var winM2: Double {
        var a = 0.0
        for s in W_PROFILES { a += sys[s]?.winM2 ?? 0 }
        for (k, v) in sys where !W_PROFILES.contains(k) { a += v.winM2 }
        return a
    }
    var glassM2: Double { glass1 + glass2 }
}

/// The wall's thickness a product stands in: its room's (200 when not typed), its own without a room.
func wWallT(_ p: Project, _ it: WinItem) -> Int {
    if !it.inRoom { return it.freeT }
    return p.rooms.first { $0.id == it.roomId }?.dim("T").v ?? 200
}

/// The parts of products list (each with its reveal's depth), qty pieces each.
func wCountItems(_ list: [(WinItem, Int)]) -> WCount {
    var c = WCount()
    for (it, r) in list {
        let qn = min(max(it.qty, 1), 999)
        let q = Double(qn)
        let pt = wPartsOf(it, r)
        if it.isDoor {
            let d = c.doors[it.kind] ?? (0, 0.0)
            c.doors[it.kind] = (d.0 + qn, d.1 + pt.doorM2 * q)
            c.doorHw += qn
            c.doorN += qn
            c.revealM2 += pt.revealM2 * q
            continue
        }
        var hw: [String: Int] = [:]
        for (k, v) in pt.hw { hw[k] = Int(Double(v) * q) }
        let s = WSysCount(frameM: pt.frameM * q, sashM: pt.sashM * q, mullM: pt.mullM * q, hw: hw, winM2: pt.areaM2 * q)
        let sides = (wLaminated(it.profile, it.colIn) ? 1 : 0) + (wLaminated(it.profile, it.colOut) ? 1 : 0)
        c.sys[it.profile] = (c.sys[it.profile] ?? WSysCount()).plus(s)
        if it.glass < 2 { c.glass1 += pt.glassM2 * q } else { c.glass2 += pt.glassM2 * q }
        c.panel += pt.panelM2 * q
        c.lamM += pt.profileM * Double(sides) * q
        c.sillM += pt.sillM * q
        c.dripM += pt.dripM * q
        c.revealM2 += pt.revealM2 * q
        c.nets += Int(Double(pt.nets) * q)
        c.handles += Int(Double(pt.handles) * q)
        c.windows += qn
    }
    return c
}

/// Each product of order p with its reveal's depth.
func wWithReveals(_ p: Project) -> [(WinItem, Int)] {
    p.win.items.map { it in (it, wRevealOf(wWallT(p, it), wFrameDepth(it))) }
}

func wCountOf(_ p: Project) -> WCount { wCountItems(wWithReveals(p)) }

/// The order's rooms, counts and warnings in one go.
struct WinCalc {
    let ctxs: [WCtx]
    let count: WCount
    let warns: [WWarn]
}

func winCalcOf(_ p: Project, _ snap: Bool) -> WinCalc {
    let cs = wCtxs(p, snap)
    return WinCalc(ctxs: cs, count: wCountOf(p), warns: wWarningsOf(p, cs, snap))
}

private func wcNum(_ s: String) -> Double { Double(s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0 }
private func wcQty(_ v: Double) -> String {
    if v == v.rounded(.down) { return String(tInt(v)) }
    var s = String(format: "%.2f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
private func wcMoney(_ v: Double) -> String { String(tInt(eMathRoundP(v))) }

/// Metres up to the next 10 cm, m² up to the next 0,01.
func wUpM(_ v: Double) -> Double { (v * 10 - 1e-9).rounded(.up) / 10 }
func wUpM2(_ v: Double) -> Double { (v * 100 - 1e-9).rounded(.up) / 100 }

/// The lines for the estimate (ids "t-…") of products list: per profile system its frame, sash and mullion metres and
/// hardware by sash type; glass, panels, laminate, the extras, doors by type and their hardware; the labour. name gives
/// a line's stored words (strings key, values).
func wRowsFor(_ list: [(WinItem, Int)], _ t: WinPrices, _ name: (String, [String: String]) -> String) -> TradeResult {
    let c = wCountItems(list)
    var mats: [Row] = [], labor: [Row] = []
    func mat(_ key: String, _ unit: String, _ q: Double, _ price: String, _ vars: [String: String] = [:], _ id: String? = nil) {
        if q <= 0 { return }
        let pr = price.replacingOccurrences(of: " ", with: "")
        let shown = pr.isEmpty ? pr : wcMoney(wcNum(pr))
        mats.append(Row(id: "t-" + (id ?? key), name: name("dw.e." + key, vars), unit: name("tu." + unit, [:]), qty: wcQty(q), price: shown))
    }
    func lab(_ key: String, _ amount: Double, _ vars: [String: String] = [:], _ id: String? = nil) {
        if amount > 0 { labor.append(Row(id: "t-" + (id ?? key), name: name("dw.e." + key, vars), amount: wcMoney(amount))) }
    }
    for s in W_PROFILES {
        guard let sc = c.sys[s] else { continue }
        let ps = t.sys(s)
        let sv: [String: String] = ["s": "~dw.p." + s]
        mat("frame", "m", wUpM(sc.frameM), ps.frameM, sv, "frame-" + s)
        mat("sash", "m", wUpM(sc.sashM), ps.sashM, sv, "sash-" + s)
        mat("mull", "m", wUpM(sc.mullM), ps.mullM, sv, "mull-" + s)
        for k in ["turn", "tilt", "tt", "slide"] {
            var hv = sv
            hv["k"] = "~dw.t." + k
            mat("hw", "pcs", Double(sc.hw[k] ?? 0), ps.hw(k), hv, "hw-" + s + "-" + k)
        }
    }
    mat("glass", "m2", wUpM2(c.glass1), t.glass1, ["n": "1"], "glass1")
    mat("glass", "m2", wUpM2(c.glass2), t.glass2, ["n": "2"], "glass2")
    mat("panel", "m2", wUpM2(c.panel), t.panel)
    mat("lam", "m", wUpM(c.lamM), t.lam)
    for k in W_DOOR_KINDS.sorted() {
        guard let d = c.doors[k] else { continue }
        mat("door", "m2", wUpM2(d.1), t.door(k), ["k": "~dw.k." + k, "n": "\(d.0)"], "door-" + k)
    }
    mat("doorHw", "pcs", Double(c.doorHw), t.hwDoor)
    mat("sill", "m", wUpM(c.sillM), t.sill)
    mat("drip", "m", wUpM(c.dripM), t.drip)
    mat("reveal", "m2", wUpM2(c.revealM2), t.reveal)
    mat("net", "pcs", Double(c.nets), t.net)
    mat("handle", "pcs", Double(c.handles), t.handle)
    for s in W_PROFILES {
        guard let sc = c.sys[s] else { continue }
        let a = wUpM2(sc.winM2)
        lab("lWin", a * wcNum(t.sys(s).lM2), ["s": "~dw.p." + s, "a": wcQty(a)], "lWin-" + s)
    }
    lab("lDoor", Double(c.doorN) * wcNum(t.lDoor), ["n": "\(c.doorN)"])
    let sm = wUpM(c.sillM), rv = wUpM2(c.revealM2), dm = wUpM(c.dripM)
    lab("lSill", sm * wcNum(t.lSill), ["a": wcQty(sm)])
    lab("lReveal", rv * wcNum(t.lReveal), ["a": wcQty(rv)])
    lab("lDrip", dm * wcNum(t.lDrip), ["a": wcQty(dm)])
    return TradeResult(mats: mats, labor: labor, facts: ["pieces": Double(c.pieces), "area": c.winM2])
}

/// The order's lines for the estimate.
func winRows(_ p: Project, _ t: WinPrices, _ name: (String, [String: String]) -> String) -> TradeResult { wRowsFor(wWithReveals(p), t, name) }

/// What lines r come to, whole currency units.
func wTotal(_ r: TradeResult) -> Double {
    var s = 0.0
    for m in r.mats { s += wcNum(m.qty) * wcNum(m.price) }
    for l in r.labor { s += wcNum(l.amount) }
    return s
}

/// What one product (all its pieces) comes to with its reveal r.
func wItemCost(_ it: WinItem, _ r: Int, _ t: WinPrices) -> Double { wTotal(wRowsFor([(it, r)], t) { k, _ in k }) }
