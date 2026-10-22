import Foundation

/*
 * The other trades on the industry picker (Android trades/Trades.kt; TradesTests): tiler, electrician, plumber,
 * windows and doors. A trade's project is a builder's project (rooms, measurements, estimate, quote); its calculator
 * turns the measured rooms into estimate lines. Rates and prices are samples the maker changes once.
 */

let TRADES = ["tiler", "elec", "plumb", "win"]

func isTrade(_ industry: String?) -> Bool { industry.map { TRADES.contains($0) } ?? false }

/// The calculator's settings, one set for all trades. Lengths in mm; money as typed (whole currency units).
struct TradeSet: Codable, Equatable {
    // tiler
    var tileW = 300, tileH = 600, boxM2 = "1.44", waste = 10, floor = true, wallH = 0
    var pTile = "120000", glueKg = "5", pGlue = "65000", groutKg = "0.4", pGrout = "25000", lTile = "80000"
    // the tiler's layouts (Tiles/Count.swift): corner profile and waterproofing per metre and m², labour for skirting, profiles, waterproofing
    var pProf = "15000", pWp = "45000", lSkirt = "20000", lProf = "15000", lWp = "25000"
    // electrician
    var lights = 1, pSocket = "35000", pSwitch = "30000", pLight = "40000", pCable = "9000", pConduit = "3000", pBreaker = "45000", lPoint = "60000"
    // plumber
    var pPipe = "12000", pSewer = "18000", pFitting = "6000", pTap = "90000", lPlumb = "120000"
    // windows and doors
    var pWinM2 = "900000", pDoorM2 = "1200000", pSillM = "150000", pRevealM = "60000", lWin = "250000"
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let z = TradeSet()
        tileW = c.v(.tileW, z.tileW); tileH = c.v(.tileH, z.tileH); boxM2 = c.v(.boxM2, z.boxM2); waste = c.v(.waste, z.waste)
        floor = c.v(.floor, z.floor); wallH = c.v(.wallH, z.wallH)
        pTile = c.v(.pTile, z.pTile); glueKg = c.v(.glueKg, z.glueKg); pGlue = c.v(.pGlue, z.pGlue); groutKg = c.v(.groutKg, z.groutKg)
        pGrout = c.v(.pGrout, z.pGrout); lTile = c.v(.lTile, z.lTile)
        pProf = c.v(.pProf, z.pProf); pWp = c.v(.pWp, z.pWp); lSkirt = c.v(.lSkirt, z.lSkirt); lProf = c.v(.lProf, z.lProf); lWp = c.v(.lWp, z.lWp)
        lights = c.v(.lights, z.lights); pSocket = c.v(.pSocket, z.pSocket); pSwitch = c.v(.pSwitch, z.pSwitch); pLight = c.v(.pLight, z.pLight)
        pCable = c.v(.pCable, z.pCable); pConduit = c.v(.pConduit, z.pConduit); pBreaker = c.v(.pBreaker, z.pBreaker); lPoint = c.v(.lPoint, z.lPoint)
        pPipe = c.v(.pPipe, z.pPipe); pSewer = c.v(.pSewer, z.pSewer); pFitting = c.v(.pFitting, z.pFitting); pTap = c.v(.pTap, z.pTap); lPlumb = c.v(.lPlumb, z.lPlumb)
        pWinM2 = c.v(.pWinM2, z.pWinM2); pDoorM2 = c.v(.pDoorM2, z.pDoorM2); pSillM = c.v(.pSillM, z.pSillM); pRevealM = c.v(.pRevealM, z.pRevealM); lWin = c.v(.lWin, z.lWin)
    }
}

/// What a calculator worked out: material and labour lines for the estimate (ids start with "t-"), and how much of what.
struct TradeResult { let mats: [Row]; let labor: [Row]; let facts: [String: Double] }

private func num(_ s: String) -> Double { Double(s.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) ?? 0 }
/// A double as a whole number, never trapping: absurd settings (saved before the calculator checked them) stay finite.
private func i64(_ v: Double) -> Int64 { v.isFinite ? Int64(min(max(v, -9e15), 9e15)) : 0 }
private func qty(_ v: Double) -> String {
    if v == v.rounded(.down) { return String(i64(v)) }
    var s = String(format: "%.2f", v)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
private func money(_ v: Double) -> String { String(i64(v.rounded())) }
private func up(_ v: Double) -> Double { (v - 1e-9).rounded(.up) }

/// A room's tiled area in m²: its floor, and its walls up to wallH less the doors and windows below that line.
func tileArea(_ r: Room, _ t: TradeSet, _ snap: Bool = true) -> Double {
    guard let a = Geo.areas(r, snap) else { return 0 }
    var mm2 = t.floor ? Double(a.floor) : 0
    if t.wallH > 0 {
        let H = r.dim("H").v ?? t.wallH
        let hh = min(t.wallH, H)
        let open = r.openings.reduce(0.0) { $0 + Double($1.w) * Double(max(0, min($1.sill + $1.h, hh) - $1.sill)) }
        mm2 += Double(a.perim) * Double(hh) - open
    }
    return mm2 / 1e6
}

/// The trade's lines for the measured rooms; name gives a line's words (strings key, values), and a number in them
/// has the decimal mark of the language (en: a point, else a comma).
func tradeRows(_ trade: String, _ rooms: [Room], _ t: TradeSet, _ name: (String, [String: String]) -> String, _ snap: Bool = true, _ en: Bool = true) -> TradeResult {
    var mats: [Row] = [], labor: [Row] = [], facts: [String: Double] = [:]
    // prices are whole currency units: one saved with decimals before the calculator checked them is rounded
    func mat(_ key: String, _ unit: String, _ q: Double, _ price: String, _ vars: [String: String] = [:]) {
        let pr = price.replacingOccurrences(of: " ", with: "")
        if q > 0 { mats.append(Row(id: "t-\(key)", name: name("tr.\(key)", vars), unit: name("tu.\(unit)", [:]), qty: qty(q), price: pr.isEmpty ? pr : money(num(pr)))) }
    }
    // counts saved before the calculator checked them can be absurd: kept in range so the sums never overflow
    let lightsEach = min(max(t.lights, 0), 100), waste = min(max(t.waste, 0), 100)
    func lab(_ key: String, _ amount: Double, _ vars: [String: String] = [:]) {
        if amount > 0 { labor.append(Row(id: "t-\(key)", name: name("tr.\(key)", vars), amount: money(amount))) }
    }
    let measured = rooms.filter { Geo.ready3D($0, snap) }
    func perimM(_ r: Room) -> Double { Double(Geo.areas(r, snap)?.perim ?? 0) / 1000 }
    switch trade {
    case "tiler":
        let area = measured.reduce(0.0) { $0 + tileArea($1, t, snap) }
        facts["area"] = area
        let box = num(t.boxM2) > 0 ? num(t.boxM2) : 1
        let boxes = up(area * (1 + Double(waste) / 100) / box)
        facts["boxes"] = boxes
        mat("tile", "m2", boxes * box, t.pTile, ["w": "\(t.tileW)", "h": "\(t.tileH)", "n": "\(i64(boxes))"])
        mat("glue", "bag", up(area * num(t.glueKg) / 25), t.pGlue)
        mat("grout", "kg", up(area * num(t.groutKg)), t.pGrout)
        lab("tileLab", area * num(t.lTile), ["a": Money.num(qty((area * 10).rounded() / 10), en)])
    case "elec":
        let sockets = measured.reduce(0) { $0 + $1.points.filter { $0.t == "socket" }.count }
        let switches = measured.reduce(0) { $0 + $1.points.filter { $0.t == "switch" }.count }
        let lights = measured.count * lightsEach
        let points = sockets + switches + lights
        // cable: round each room's walls once, and 2,5 m down to each point and up to each light
        let cable = measured.reduce(0.0) { a, r in a + perimM(r) + 2.5 * Double(r.points.filter { $0.t == "socket" || $0.t == "switch" }.count + lightsEach) }
        facts["points"] = Double(points); facts["cable"] = cable
        mat("socket", "pcs", Double(sockets), t.pSocket); mat("switch", "pcs", Double(switches), t.pSwitch); mat("light", "pcs", Double(lights), t.pLight)
        mat("cable", "m", up(cable * 1.1), t.pCable); mat("conduit", "m", up(cable), t.pConduit)
        mat("breaker", "pcs", measured.isEmpty ? 0 : Double(measured.count + 1), t.pBreaker)
        lab("elecLab", Double(points) * num(t.lPoint), ["n": "\(points)"])
    case "plumb":
        let water = measured.reduce(0) { $0 + $1.points.filter { $0.t == "cold" || $0.t == "hot" }.count }
        let sewer = measured.reduce(0) { $0 + $1.points.filter { $0.t == "sewer" }.count }
        // supply: 3 m to each water point and once round the walls of a room that has water; drain: 2,5 m a point
        let pipe = measured.reduce(0.0) { a, r in
            let w = r.points.filter { $0.t == "cold" || $0.t == "hot" }.count
            return a + (w == 0 ? 0 : 3.0 * Double(w) + perimM(r))
        }
        facts["points"] = Double(water + sewer); facts["pipe"] = pipe
        mat("pipe", "m", up(pipe), t.pPipe); mat("sewer", "m", up(2.5 * Double(sewer)), t.pSewer)
        mat("fitting", "pcs", 4.0 * Double(water + sewer), t.pFitting); mat("tap", "pcs", Double(water), t.pTap)
        lab("plumbLab", Double(water + sewer) * num(t.lPlumb), ["n": "\(water + sewer)"])
    default:   // windows and doors
        let ops = measured.flatMap(\.openings)
        // one line a size: windows priced by their m², doors too; sills and reveals by the metre
        var groups: [String: (type: String, w: Int, h: Int, n: Int)] = [:]
        for o in ops { let k = "\(o.type)|\(o.w)|\(o.h)"; groups[k] = (o.type, o.w, o.h, (groups[k]?.n ?? 0) + 1) }
        let sorted = groups.values.sorted { ($0.type, -$0.w, -$0.h) < ($1.type, -$1.w, -$1.h) }
        for g in sorted {
            let m2 = Double(g.w * g.h) / 1e6
            mat(g.type == "door" ? "door" : "window", "pcs", Double(g.n), money(m2 * num(g.type == "door" ? t.pDoorM2 : t.pWinM2)), ["w": "\(g.w)", "h": "\(g.h)"])
        }
        let wins = ops.filter { $0.type == "window" }
        mat("sill", "m", up(wins.reduce(0.0) { $0 + Double($1.w + 100) / 1000 } * 10) / 10, t.pSillM)
        mat("reveal", "m", up(ops.reduce(0.0) { $0 + Double($1.w + 2 * $1.h) / 1000 } * 10) / 10, t.pRevealM)
        facts["count"] = Double(ops.count)
        lab("winLab", Double(ops.count) * num(t.lWin), ["n": "\(ops.count)"])
    }
    return TradeResult(mats: mats, labor: labor, facts: facts)
}
