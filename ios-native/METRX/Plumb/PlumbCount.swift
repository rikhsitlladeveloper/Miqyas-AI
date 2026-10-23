import Foundation

/*
 * Counting from the real routes (the advanced app; Android plumb/Count.kt): water and heating pipe by diameter with the
 * spare in 4 m sticks (PPR) or coils (metal-plastic, PEX), drains 50 and 110 by the metre with their bends and tees,
 * the underfloor pipe in coils, the elbows, tees, couplings, wall plates, ball valves, main valves, meters, filters and
 * the manifold; the estimate's lines with the labour per outlet, per fixture, per metre, per radiator and per metre of
 * chase. The fixtures themselves are the customer's and are not counted.
 */

/// Pipe of kind (water, heat, ufh) dia mm: m metres, withSpare with the spare, in pieces sticks or coils of per m (unit
/// stick or coil).
struct PipeNeed: Equatable {
    let kind: String
    let dia: Int
    let m: Double
    let withSpare: Double
    let pieces: Int
    let unit: String
    let per: Int
}

/// What an order takes. Lengths in metres.
struct PCount {
    var pipes: [PipeNeed] = []
    var drain50 = 0.0, drain110 = 0.0
    var bends50 = 0, bends110 = 0, tees50 = 0, tees110 = 0
    var elbows = 0, tees = 0, couplings = 0, plates = 0, balls = 0
    var mainValves = 0, meters = 0, filters = 0
    var manifolds = 0, manifOuts = 0, loops = 0
    var points = 0, fixtures = 0, radiators = 0
    var waterM = 0.0, heatM = 0.0, ufhM = 0.0, chaseM = 0.0

    var drainM: Double { drain50 + drain110 }
    /// Every metre of pipe laid (the labour by the metre).
    var pipeM: Double { waterM + heatM + drainM + ufhM }
}

/// A coil's length for metal-plastic and PEX of dia: 100 m thin, 50 m thick.
func coilFor(_ dia: Int) -> Int { dia <= 20 ? 100 : 50 }

private func pPieces(_ ws: Double, _ per: Int) -> Int { ws <= 0 ? 0 : tInt((ws / Double(per) - 1e-9).rounded(.up)) }

/// m metres of kind pipe dia in system water with spare %: whole sticks or coils.
func pipeNeed(_ kind: String, _ dia: Int, _ m: Double, _ water: String, _ spare: Int) -> PipeNeed {
    let ws = m * (1 + Double(spare) / 100.0)
    if kind == "ufh" { return PipeNeed(kind: kind, dia: 16, m: m, withSpare: ws, pieces: pPieces(ws, UFH_COIL), unit: "coil", per: UFH_COIL) }
    if water == "ppr" { return PipeNeed(kind: kind, dia: dia, m: m, withSpare: ws, pieces: pPieces(ws, STICK), unit: "stick", per: STICK) }
    let per = coilFor(dia)
    return PipeNeed(kind: kind, dia: dia, m: m, withSpare: ws, pieces: pPieces(ws, per), unit: "coil", per: per)
}

/// Everything order p takes, from its rooms cs and routes rt.
func pCountOf(_ p: Project, _ cs: [PCtx], _ rt: PRoutes) -> PCount {
    let pl = p.plumb
    let spare = eClampI(pl.spare ?? PIPE_SPARE, 0, 100)
    func m(_ v: Double) -> Double { v / 1000 }
    // water and heating: the trunk at its diameter, the branches 20
    func byDia(_ kinds: Set<String>) -> [(Int, Double)] {
        var out: [Int: Double] = [:]
        for r in rt.runs where kinds.contains(r.kind) {
            out[r.dia] = (out[r.dia] ?? 0) + m(r.trunk)
            out[20] = (out[20] ?? 0) + m(r.drops)
        }
        var res: [(Int, Double)] = []
        for k in out.keys.sorted() {
            let v = out[k] ?? 0
            if v > 0 { res.append((k, v)) }
        }
        return res
    }
    let water = byDia(["cold", "hot"])
    let heat = byDia(["hs", "hr"])
    let ufhM = rt.loops.reduce(0.0) { $0 + $1.total } / 1000
    var pipes: [PipeNeed] = []
    for (d, v) in water { pipes.append(pipeNeed("water", d, v, pl.water, spare)) }
    for (d, v) in heat { pipes.append(pipeNeed("heat", d, v, pl.water, spare)) }
    if ufhM > 0 { pipes.append(pipeNeed("ufh", 16, ufhM, pl.water, spare)) }
    // drains: each stretch of wall once a diameter (the pipes join), a 50 where a 110 runs beside it is the 110's
    var d50 = 0.0, d110 = 0.0
    var drainRuns: [PRun] = []
    for d in rt.drains { drainRuns += d.runs }
    for c in cs {
        let rs = drainRuns.filter { $0.roomId == c.id }
        if rs.isEmpty { continue }
        let P = Perim(c.g.walls).P
        var s110: [(Double, Double)] = [], s50: [(Double, Double)] = []
        var drop110 = 0.0, drop50 = 0.0
        for r in rs {
            if r.dia >= 100 { s110 += r.stretches; drop110 += r.drops } else { s50 += r.stretches; drop50 += r.drops }
        }
        let u110 = unionLen(s110, P)
        d110 += u110 + drop110
        d50 += (unionLen(s50 + s110, P) - u110) + drop50
    }
    // the pipe between the doors, once a room and diameter
    var groupKeys: [String] = []
    var groupMax: [String: Double] = [:]
    var groupBig: [String: Bool] = [:]
    for d in rt.drains where d.between > 0 {
        let big = d.dia >= 100
        let k = d.pt.roomId + "|" + (big ? "1" : "0")
        if groupMax[k] == nil { groupKeys.append(k); groupMax[k] = d.between; groupBig[k] = big }
        else { groupMax[k] = max(groupMax[k] ?? 0, d.between) }
    }
    for k in groupKeys {
        let l = groupMax[k] ?? 0
        if groupBig[k] == true { d110 += l } else { d50 += l }
    }
    let dr50 = rt.drains.filter { $0.dia < 100 }
    let dr110 = rt.drains.filter { $0.dia >= 100 }
    let sup = rt.runs.filter { $0.kind != "drain" }
    let ws = rt.runs.filter { $0.kind == "cold" || $0.kind == "hot" }
    let pieces = pipes.filter { $0.kind != "ufh" }
    var allPts = 0
    var fixes: [PlFix] = []
    for c in cs {
        allPts += pointsIn(p, c).count
        fixes += fixesIn(p, c)
    }
    // the riser's meter, filter and main valve: one set for its cold when cold water runs from it, another for its hot only
    // when the hot water comes up it (not from a gas boiler or a water heater); a heating-only order needs none
    let coldOut = rt.runs.contains { $0.kind == "cold" }
    let hotFromRiser = rt.riser?.hot == true && rt.hot != nil && rt.hot?.fix == nil
    let hotOut = hotFromRiser && rt.runs.contains { $0.kind == "hot" }
    let riserKinds = rt.riser == nil ? 0 : (coldOut ? 1 : 0) + (hotOut ? 1 : 0)
    func bends(_ ds: [PDrain]) -> Int { ds.reduce(0) { acc, d in acc + 1 + d.runs.reduce(0) { $0 + $1.corners } } }
    var res = PCount()
    res.pipes = pipes
    res.drain50 = m(d50); res.drain110 = m(d110)
    res.bends50 = bends(dr50); res.bends110 = bends(dr110)
    res.tees50 = dr50.count; res.tees110 = dr110.count
    res.elbows = sup.reduce(0) { $0 + $1.corners + 2 * $1.dips + $1.branches }
    res.tees = sup.reduce(0) { $0 + $1.branches }
    let sticks = pieces.reduce(0) { $0 + $1.pieces }
    res.couplings = pl.water == "ppr" ? sticks : 0
    res.plates = ws.reduce(0) { $0 + $1.branches }
    res.balls = sup.reduce(0) { $0 + $1.branches }
    res.mainValves = riserKinds; res.meters = riserKinds; res.filters = riserKinds
    // each manifold placed (a typed room with underfloor heating has its own)
    res.manifolds = rt.loops.isEmpty ? 0 : max(1, fixes.filter { $0.t == "manif" }.count)
    res.manifOuts = rt.loops.reduce(0) { $0 + $1.n }
    res.loops = rt.loops.reduce(0) { $0 + $1.n }
    res.points = allPts
    res.fixtures = fixes.count
    res.radiators = fixes.filter { $0.t == "rad" }.count
    res.waterM = m(ws.reduce(0.0) { $0 + $1.len })
    res.heatM = m(sup.filter { $0.kind == "hs" || $0.kind == "hr" }.reduce(0.0) { $0 + $1.len })
    res.ufhM = ufhM
    res.chaseM = m(sup.reduce(0.0) { $0 + $1.chase })
    return res
}

/// The order's routes, counts and warnings in one go.
struct PlumbCalc {
    let ctxs: [PCtx]
    let routes: PRoutes
    let count: PCount
    let warns: [PWarn]
}

func plumbCalcOf(_ p: Project, _ snap: Bool) -> PlumbCalc {
    let cs = pCtxs(p, snap)
    let rt = pRoutesOf(p, cs)
    return PlumbCalc(ctxs: cs, routes: rt, count: pCountOf(p, cs, rt), warns: pWarningsOf(p, cs, rt))
}

private func pNum(_ s: String) -> Double { Double(s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0 }
private func pQty(_ v: Double) -> String {
    if v == v.rounded(.down) { return String(tInt(v)) }
    var s = String(format: "%.2f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
private func pMoney(_ v: Double) -> String { String(tInt(eMathRoundP(v))) }

/// The order's lines for the estimate (ids "t-…"): pipe by diameter in whole sticks or coils, drains, the underfloor
/// pipe, fittings, valves, meters, filters and the manifold; the labour per outlet, fixture, metre, radiator and chase.
/// name gives a line's stored words (strings key, values).
func plumbRows(_ p: Project, _ t: TradeSet, _ snap: Bool, _ name: (String, [String: String]) -> String) -> TradeResult {
    let c = plumbCalcOf(p, snap).count
    var mats: [Row] = [], labor: [Row] = []
    func mat(_ key: String, _ unit: String, _ q: Double, _ price: String, _ vars: [String: String] = [:], _ id: String? = nil) {
        if q <= 0 { return }
        let pr = price.replacingOccurrences(of: " ", with: "")
        mats.append(Row(id: "t-" + (id ?? key), name: name("sx.e." + key, vars), unit: name("tu." + unit, [:]), qty: pQty(q), price: pr.isEmpty ? pr : pMoney(pNum(pr))))
    }
    func lab(_ key: String, _ amount: Double, _ vars: [String: String] = [:]) {
        if amount > 0 { labor.append(Row(id: "t-" + key, name: name("sx.e." + key, vars), amount: pMoney(amount))) }
    }
    let sys = "~sx.sys." + p.plumb.water
    for n in c.pipes {
        var price = t.pX20
        var key = n.unit == "stick" ? "pipeS" : "pipeC"
        switch n.kind {
        case "ufh": price = t.pUfh; key = "ufh"
        case "heat": price = t.pHeat; key = n.unit == "stick" ? "heatS" : "heatC"
        default: price = n.dia == 32 ? t.pX32 : n.dia == 25 ? t.pX25 : t.pX20
        }
        mat(key, "m", Double(n.pieces * n.per), price, ["s": sys, "d": "\(n.dia)", "n": "\(n.pieces)"], key + "\(n.dia)")
    }
    mat("d50", "m", (c.drain50 - 1e-9).rounded(.up), t.pD50)
    mat("d110", "m", (c.drain110 - 1e-9).rounded(.up), t.pD110)
    mat("bend", "pcs", Double(c.bends50), t.pDBend, ["d": "50"], "bend50")
    mat("bend", "pcs", Double(c.bends110), t.pDBend, ["d": "110"], "bend110")
    mat("dtee", "pcs", Double(c.tees50), t.pDTee, ["d": "50"], "dtee50")
    mat("dtee", "pcs", Double(c.tees110), t.pDTee, ["d": "110"], "dtee110")
    mat("elbow", "pcs", Double(c.elbows), t.pElbow)
    mat("tee", "pcs", Double(c.tees), t.pTee)
    mat("coup", "pcs", Double(c.couplings), t.pCoup)
    mat("plate", "pcs", Double(c.plates), t.pPlate)
    mat("ball", "pcs", Double(c.balls), t.pBall)
    mat("mainv", "pcs", Double(c.mainValves), t.pMainV)
    mat("meter", "pcs", Double(c.meters), t.pMeter)
    mat("filter", "pcs", Double(c.filters), t.pFilter)
    mat("manif", "pcs", Double(c.manifolds), t.pManif, ["n": "\(c.manifOuts)"])
    lab("lPts", Double(c.points) * pNum(t.lPPt), ["n": "\(c.points)"])
    lab("lFix", Double(c.fixtures) * pNum(t.lPFix), ["n": "\(c.fixtures)"])
    // the metres the line shows are the ones it is priced by, so quantity × rate is its amount
    let pipeM = eMathRoundP(c.pipeM * 10) / 10
    let chaseM = eMathRoundP(c.chaseM * 10) / 10
    lab("lMetre", pipeM * pNum(t.lPM), ["a": pQty(pipeM)])
    lab("lRad", Double(c.radiators) * pNum(t.lPRad), ["n": "\(c.radiators)"])
    lab("lChase", chaseM * pNum(t.lPChase), ["a": pQty(chaseM)])
    return TradeResult(mats: mats, labor: labor, facts: ["points": Double(c.points), "pipe": c.pipeM])
}
