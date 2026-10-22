import Foundation

/*
 * A window's sashes and parts as seen from inside (Android win/Geo.kt): x from the left edge, y up from the bottom, mm.
 * The frame runs round the outside; vertical mullions stand on the columns' axes the full height inside the frame,
 * transoms cross their own column; each sash's cell is what is left inside them. From the cells: the profile metres
 * (frame, opening sashes, mullions), the glass, the panels, the hardware, handles and nets.
 */

/// A rectangle on the product, mm: x0…x1 from the left, y0…y1 up from the bottom.
struct WRect: Equatable {
    let x0: Double, y0: Double, x1: Double, y1: Double
    var w: Double { x1 - x0 }
    var h: Double { y1 - y0 }
    var area: Double { w * h / 1e6 }
}

/// Sash row of column col: its cell (inside the frame and mullions) and how it opens.
struct WSash {
    let col: Int
    let row: Int
    let cell: WCell
    let r: WRect
    var t: String { cell.t }
    var opens: Bool { W_OPENS.contains(cell.t) }
}

/// A mullion or transom on its axis; vertical a mullion between columns.
struct WBar {
    let x0: Double, y0: Double, x1: Double, y1: Double
    let vertical: Bool
    let col: Int
    let row: Int
    var len: Double { vertical ? y1 - y0 : x1 - x0 }
}

/// Where the columns' axes are: 0, each mullion, the full width.
func wColEdges(_ it: WinItem) -> [Double] {
    var out: [Double] = [0]
    var a = 0.0
    for c in it.cols { a += Double(c.w); out.append(a) }
    return out
}

/// Where a column's transoms are, down from the top: 0, each transom, the full height.
func wRowEdges(_ c: WCol) -> [Double] {
    var out: [Double] = [0]
    var a = 0.0
    for r in c.rows { a += Double(r.h); out.append(a) }
    return out
}

/// Every sash of window it with its cell.
func wSashesOf(_ it: WinItem) -> [WSash] {
    if it.cols.isEmpty { return [] }
    let F = Double(wFrameF(it.profile))
    let M = Double(wMullF(it.profile)) / 2
    let xs = wColEdges(it)
    let n = it.cols.count
    let W = Double(it.w), H = Double(it.h)
    var out: [WSash] = []
    for (i, c) in it.cols.enumerated() {
        let x0: Double = i == 0 ? F : xs[i] + M
        let x1: Double = i == n - 1 ? W - F : xs[i + 1] - M
        let ys = wRowEdges(c)
        let m = c.rows.count
        for (j, r) in c.rows.enumerated() {
            let top: Double = j == 0 ? H - F : H - ys[j] - M
            let bot: Double = j == m - 1 ? F : H - ys[j + 1] + M
            out.append(WSash(col: i, row: j, cell: r, r: WRect(x0: x0, y0: bot, x1: x1, y1: top)))
        }
    }
    return out
}

/// Every mullion (between columns, the full height inside the frame) and transom (across its column's cell).
func wBarsOf(_ it: WinItem) -> [WBar] {
    if it.cols.isEmpty { return [] }
    let F = Double(wFrameF(it.profile))
    let M = Double(wMullF(it.profile)) / 2
    let xs = wColEdges(it)
    let n = it.cols.count
    let H = Double(it.h), W = Double(it.w)
    var out: [WBar] = []
    if n > 1 {
        for i in 1..<n { out.append(WBar(x0: xs[i], y0: F, x1: xs[i], y1: H - F, vertical: true, col: i - 1, row: 0)) }
    }
    for (i, c) in it.cols.enumerated() {
        let x0: Double = i == 0 ? F : xs[i] + M
        let x1: Double = i == n - 1 ? W - F : xs[i + 1] - M
        let ys = wRowEdges(c)
        if c.rows.count > 1 {
            for j in 1..<c.rows.count {
                let y = H - ys[j]
                out.append(WBar(x0: x0, y0: y, x1: x1, y1: y, vertical: false, col: i, row: j - 1))
            }
        }
    }
    return out
}

/// The glass a sash holds, m²: a fixed one its cell less the bead's seat, an opening one inside its own profile.
func wGlassOf(_ it: WinItem, _ s: WSash) -> Double {
    if s.t == "panel" { return 0 }
    if s.opens {
        let f = Double(wSashF(it.profile)) * 2 - 16
        let gw = max(s.r.w - f, 0), gh = max(s.r.h - f, 0)
        return gw * gh / 1e6
    }
    let gw = max(s.r.w - 16, 0), gh = max(s.r.h - 16, 0)
    return gw * gh / 1e6
}

/// Glass weight a m²: a one-chamber unit 4-16-4, a two-chamber 4-10-4-10-4; profile a metre, with its steel.
let W_GLASS_KG1 = 20.0
let W_GLASS_KG2 = 30.0
let W_PROF_KG_PVC = 1.8
let W_PROF_KG_ALU = 1.2

/// A sash's weight, kg: its glass and its own profile.
func wSashKg(_ it: WinItem, _ s: WSash) -> Double {
    let glassKg: Double = wGlassOf(it, s) * (it.glass >= 2 ? W_GLASS_KG2 : W_GLASS_KG1)
    if !s.opens { return glassKg }
    let perM: Double = it.profile == "alu" ? W_PROF_KG_ALU : W_PROF_KG_PVC
    let metres: Double = 2 * (s.r.w + s.r.h) / 1000
    return glassKg + metres * perM
}

/// One product's parts (one piece; qty pieces multiply it): profile metres, glass and panels m², hardware by sash type,
/// handles and nets; the extras' lengths and areas for a reveal r deep; a door's area.
struct WParts {
    var frameM = 0.0, sashM = 0.0, mullM = 0.0
    var glassM2 = 0.0, panelM2 = 0.0
    var hw: [String: Int] = [:]
    var handles = 0, nets = 0
    var sillM = 0.0, dripM = 0.0, revealM2 = 0.0
    var areaM2 = 0.0, doorM2 = 0.0
    var profileM: Double { frameM + sashM + mullM }
}

/// The parts of one piece of p with an inside reveal r deep.
func wPartsOf(_ p: WinItem, _ r: Int) -> WParts {
    let area = Double(p.w) * Double(p.h) / 1e6
    let reveal: Double = p.reveals ? (2.0 * Double(p.h) + Double(p.w)) * Double(r) / 1e6 : 0
    var out = WParts()
    if p.isDoor {
        out.handles = p.handles ? 1 : 0
        out.revealM2 = reveal
        out.areaM2 = area
        out.doorM2 = area
        out.hw = ["door": 1]
        return out
    }
    let ss = wSashesOf(p)
    let open = ss.filter(\.opens)
    out.frameM = 2.0 * Double(p.w + p.h) / 1000
    var sashM = 0.0
    for s in open { sashM += 2 * (s.r.w + s.r.h) / 1000 }
    out.sashM = sashM
    var mull = 0.0
    for b in wBarsOf(p) { mull += b.len }
    out.mullM = mull / 1000
    var glass = 0.0, panel = 0.0
    for s in ss {
        glass += wGlassOf(p, s)
        if s.t == "panel" { panel += s.r.area }
    }
    out.glassM2 = glass
    out.panelM2 = panel
    var hw: [String: Int] = [:]
    for s in open { hw[s.t, default: 0] += 1 }
    out.hw = hw
    out.handles = p.handles ? open.count : 0
    out.nets = p.net ? open.count : 0
    out.sillM = p.sill > 0 ? (Double(p.w) + 2.0 * Double(W_SILL_EAR)) / 1000 : 0
    out.dripM = p.drip ? (Double(p.w) + 2.0 * Double(W_DRIP_EAR)) / 1000 : 0
    out.revealM2 = reveal
    out.areaM2 = area
    return out
}
