import Foundation

/*
 * Counting from the real routes (the advanced app; Android elec/Count.kt): cable by type with the spare in whole 100 m
 * coils, breakers by amps, RCDs, the main switch and the panel's size in modules, socket and junction boxes, pipe,
 * channel and chase metres, and the estimate's lines with the labour per point, per metre and for the panel.
 */

/// Cable m metres of type ("1.5", "2.5", "6", "utp"), with the spare: withSpare m in coils coils.
struct CableNeed: Equatable {
    let type: String
    let m: Double
    let withSpare: Double
    let coils: Int
}

/// What an order takes. Lengths in metres. breakers: how many of each breaker (amps → count).
struct ECount: Equatable {
    var circuits = 0
    var cables: [CableNeed] = []
    var breakers: [Int: Int] = [:]
    var rcds = 0
    var modules = 0
    var panelModules = 0
    var sockets = 0, switches = 0, lights = 0, low = 0
    var boxes = 0, jboxes = 0
    var chaseM = 0.0, gofraM = 0.0, channelM = 0.0
    var cableM = 0.0

    var points: Int { sockets + switches + lights + low }
}

/// Less cable than this (m, with the spare) is bought by the metre; more in whole coils.
let COIL_FROM = 50

/// Whole coils of COIL m for m metres.
func coilsFor(_ m: Double) -> Int { m <= 0 ? 0 : tInt((m / Double(COIL) - 1e-9).rounded(.up)) }

/// The usual panel sizes, modules.
let PANEL_SIZES = [12, 18, 24, 36, 48, 54, 72]

/// The panel for modules used: the next size with a fifth spare.
func ePanelFor(_ modules: Int) -> Int {
    if modules <= 0 { return 0 }
    let need = (Double(modules) * 1.2 - 1e-9).rounded(.up)
    return PANEL_SIZES.first { Double($0) >= need } ?? PANEL_SIZES[PANEL_SIZES.count - 1]
}

/// The length of the union of stretches iv round a loop P long.
func unionLen(_ iv: [(Double, Double)], _ P: Double) -> Double {
    if iv.isEmpty || P <= 0 { return 0 }
    var flat: [(Double, Double)] = []
    for (a0, b0) in iv {
        if b0 - a0 >= P { flat.append((0, P)); continue }
        let a = eMod(eMod(a0, P) + P, P)
        let b = a + (b0 - a0)
        if b <= P { flat.append((a, b)) } else { flat.append((a, P)); flat.append((0, b - P)) }
    }
    var sum = 0.0, cur0 = -1.0, cur1 = -1.0
    for (a, b) in eSortedBy(flat, { $0.0 }) {
        if a > cur1 {
            if cur1 > cur0 { sum += cur1 - cur0 }
            cur0 = a; cur1 = b
        } else { cur1 = max(cur1, b) }
    }
    if cur1 > cur0 { sum += cur1 - cur0 }
    return min(sum, P)
}

/// Everything order p takes, from its rooms cs, circuits and routes.
func countOf(_ p: Project, _ cs: [ECtx], _ rt: Routes) -> ECount {
    let spare = eClampI(p.elec.spare ?? CABLE_SPARE, 0, 100)
    var cab: [String: Double] = [:]
    for c in rt.circuits {
        cab[c.cable] = (cab[c.cable] ?? 0) + rt.cableOf(c) / 1000
    }
    var cables: [CableNeed] = []
    for t in ["1.5", "2.5", "6", "utp"] {
        guard let m = cab[t], m > 0 else { continue }
        let ws = m * (1 + Double(spare) / 100)
        cables.append(CableNeed(type: t, m: m, withSpare: ws, coils: coilsFor(ws)))
    }
    var brk: [Int: Int] = [:]
    for c in rt.circuits where c.amps > 0 { brk[c.amps, default: 0] += 1 }
    let rcds = rt.circuits.filter { $0.rcd }.count
    let modules = brk.values.reduce(0, +) + 2 * rcds + (brk.isEmpty ? 0 : 2)
    var all: [ElecDev] = []
    for c in cs { all += devsIn(p, c) }
    func cat(_ k: String) -> Int { all.filter { devType($0.t).cat == k }.count }
    let boxes = all.filter { !$0.onCeiling && devType($0.t).cat != "box" && $0.t != "led" }.count
    // a junction box in every room with devices, where none was placed
    var jb = 0
    for c in cs {
        let ds = devsIn(p, c)
        let placed = ds.filter { $0.t == "jb" }.count
        if placed > 0 { jb += placed } else if ds.contains(where: { devType($0.t).cat != "box" }) { jb += 1 }
    }
    // chases and channels: each stretch of wall once (cables share them), each drop once; pipe: every cable its own
    // the rise from the panel: one shared chase or channel (the longest), but in gofra every circuit has its own pipe
    var wallM = 0.0, drops = 0.0, ceilM = 0.0, rises = 0.0, risesAll = 0.0
    for c in cs {
        let runs = rt.inRoom(c.id)
        if runs.isEmpty { continue }
        wallM += unionLen(runs.flatMap { $0.runs }, Perim(c).P)
        var dk: [String] = []
        var dv: [String: Double] = [:]
        for r in runs {
            for (id, v) in r.drops {
                if dv[id] == nil { dk.append(id) }
                dv[id] = v
            }
        }
        drops += dk.reduce(0.0) { $0 + (dv[$1] ?? 0) }
        ceilM += runs.reduce(0.0) { $0 + $1.ceil }
        rises = max(rises, runs.map(\.rise).max() ?? 0)
        risesAll += runs.reduce(0.0) { $0 + $1.rise }
    }
    let cableM = rt.circuits.reduce(0.0) { $0 + rt.cableOf($1) } / 1000
    var chase = 0.0, gofra = 0.0, channel = 0.0
    switch rt.method {
    case "gofra": chase = drops / 1000; gofra = (ceilM + risesAll) / 1000
    case "channel": channel = (wallM + drops + rises + ceilM) / 1000
    default: chase = (wallM + drops + rises) / 1000; gofra = ceilM / 1000
    }
    return ECount(circuits: rt.circuits.count, cables: cables, breakers: brk, rcds: rcds, modules: modules, panelModules: ePanelFor(modules),
                  sockets: cat("sock"), switches: cat("sw"), lights: cat("light"), low: cat("low"), boxes: boxes, jboxes: jb,
                  chaseM: chase, gofraM: gofra, channelM: channel, cableM: cableM)
}

/// The order's circuits, routes and counts in one go.
struct ElecCalc {
    let ctxs: [ECtx]
    let circuits: [Circuit]
    let routes: Routes
    let count: ECount
    let warns: [EWarn]
}

func calcOf(_ p: Project, _ snap: Bool) -> ElecCalc {
    let cs = ctxs(p, snap)
    let cc = circuitsOf(p, cs)
    let rt = routesOf(p, cs, cc)
    return ElecCalc(ctxs: cs, circuits: cc, routes: rt, count: countOf(p, cs, rt), warns: warningsOf(p, cs, cc))
}

private func eNum(_ s: String) -> Double { Double(s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0 }
private func eQty(_ v: Double) -> String {
    if v == v.rounded(.down) { return String(tInt(v)) }
    var s = String(format: "%.2f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
/// Kotlin's Math.round: halves go up.
private func eMathRound(_ v: Double) -> Double { (v + 0.5).rounded(.down) }
private func eMoney(_ v: Double) -> String { String(tInt(eMathRound(v))) }

/// The cable's name in the lines: "3×1.5" or "UTP" (the comma is put in by the language).
func cableName(_ t: String) -> String { t == "utp" ? "UTP" : "3×" + t }

/// The order's lines for the estimate (ids "t-…"): cable by type in whole coils, devices, boxes, breakers, RCDs, the
/// main switch, the panel, pipe and channel; the labour for the points, the chases, the cable and the panel. name gives a
/// line's stored words (strings key, values).
func elecRows(_ p: Project, _ t: TradeSet, _ snap: Bool, _ name: (String, [String: String]) -> String) -> TradeResult {
    let c = calcOf(p, snap).count
    var mats: [Row] = [], labor: [Row] = []
    func mat(_ key: String, _ unit: String, _ q: Double, _ price: String, _ vars: [String: String] = [:], _ id: String? = nil) {
        if q <= 0 { return }
        let pr = price.replacingOccurrences(of: " ", with: "")
        mats.append(Row(id: "t-" + (id ?? key), name: name("el.e." + key, vars), unit: name("tu." + unit, [:]), qty: eQty(q), price: pr.isEmpty ? pr : eMoney(eNum(pr))))
    }
    func lab(_ key: String, _ amount: Double, _ vars: [String: String] = [:]) {
        if amount > 0 { labor.append(Row(id: "t-" + key, name: name("el.e." + key, vars), amount: eMoney(amount))) }
    }
    for n in c.cables {
        let price: String
        switch n.type {
        case "1.5": price = t.pCab15
        case "6": price = t.pCab6
        case "utp": price = t.pUtp
        default: price = t.pCable
        }
        // (a non-breaking space after VVG: a stored line's values lose plain spaces)
        let label = n.type == "utp" ? "UTP" : "VVG\u{00A0}" + cableName(n.type)
        // a short run is bought by the metre, from COIL_FROM m in whole coils
        if n.coils == 0 || n.withSpare < Double(COIL_FROM) {
            mat("cabM", "m", (n.withSpare - 1e-9).rounded(.up), price, ["c": label], "cab" + n.type)
        } else {
            mat("cab", "m", Double(n.coils * COIL), price, ["c": label, "n": "\(n.coils)"], "cab" + n.type)
        }
    }
    mat("sock", "pcs", Double(c.sockets), t.pSocket)
    mat("sw", "pcs", Double(c.switches), t.pSwitch)
    mat("light", "pcs", Double(c.lights), t.pLight)
    mat("low", "pcs", Double(c.low), t.pLow)
    mat("box", "pcs", Double(c.boxes), t.pBox)
    mat("jbox", "pcs", Double(c.jboxes), t.pJBox)
    for a in c.breakers.keys.sorted() { mat("brk", "pcs", Double(c.breakers[a] ?? 0), t.pBreaker, ["a": "\(a)"], "brk\(a)") }
    mat("rcd", "pcs", Double(c.rcds), t.pRcd)
    if !c.breakers.isEmpty {
        mat("main", "pcs", 1, t.pMain)
        mat("panel", "pcs", 1, eMoney(eNum(t.pPanelM) * Double(c.panelModules)), ["n": "\(c.panelModules)"])
    }
    mat("gofra", "m", (c.gofraM - 1e-9).rounded(.up), t.pConduit)
    mat("chan", "m", (c.channelM - 1e-9).rounded(.up), t.pChan)
    lab("lPts", Double(c.points) * eNum(t.lPoint), ["n": "\(c.points)"])
    // the metres a labour line shows are the ones it is priced by, so quantity × rate is its amount
    let chaseM = eMathRound(c.chaseM * 10) / 10
    let cableM = eMathRound(c.cableM * 10) / 10
    lab("lChase", chaseM * eNum(t.lChase), ["a": eQty(chaseM)])
    lab("lCable", cableM * eNum(t.lMetre), ["a": eQty(cableM)])
    if !c.breakers.isEmpty { lab("lPanel", eNum(t.lPanel), ["n": "\(c.circuits)"]) }
    return TradeResult(mats: mats, labor: labor, facts: ["points": Double(c.points), "cable": c.cableM])
}
