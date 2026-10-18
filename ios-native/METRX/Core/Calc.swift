import Foundation

/*
 * The Measure page's small calculator (prototype measure.js; Android core/Calc.kt): area, net wall, volume, a sum of
 * lengths, and the brick tool (founder's choice B): one brick layer over the wall face less an optional opening, with
 * spare and mortar. Geometry only: nothing here is written to an estimate.
 */

/// Brick length, width, height and joint in mm, spare in % (prototype QB_DEF).
struct BrickSpec: Codable, Equatable {
    var l = 250, w = 120, h = 65, j = 10, s = 5
    init(l: Int = 250, w: Int = 120, h: Int = 65, j: Int = 10, s: Int = 5) { self.l = l; self.w = w; self.h = h; self.j = j; self.s = s }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        l = c.v(.l, 250); w = c.v(.w, 120); h = c.v(.h, 65); j = c.v(.j, 10); s = c.v(.s, 5)
    }
}

/// The two usual Uzbek bricks (prototype QB_PRESETS).
let BRICK_PRESETS = [(250, 120, 65), (250, 120, 88)]
/// What each brick value may be (prototype QB_LIM).
let BRICK_LIMITS: [String: ClosedRange<Int>] = ["l": 100...600, "w": 50...400, "h": 30...300, "j": 0...30, "s": 0...30]

/// Bricks (whole, spare included) and mortar in m³ for a wall face of faceMm2 (prototype qbCount, one layer).
func brickCount(_ faceMm2: Double, _ b: BrickSpec) -> (Int, Double) {
    let n = faceMm2 / (Double(b.l + b.j) * Double(b.h + b.j))
    let bricks = Int((n * Double(100 + b.s) / 100 - 1e-9).rounded(.up))
    let thick = Double(b.w)                     // one layer: half a brick thick
    let mortar = max(0, faceMm2 * thick - n * Double(b.l) * Double(b.w) * Double(b.h)) / 1e9
    return (bricks, mortar)
}

/// The slots each tool fills, in order (prototype QC_SLOTS); "sum" takes any number.
let CALC_SLOTS: [String: [String]] = ["area": ["L", "W"], "wall": ["L", "H", "ow", "oh"], "vol": ["L", "W", "H"], "sum": [], "brick": ["L", "H", "ow", "oh"],
    "sheet": ["L", "W"]]

/// Furniture makers' tool instead of bricks: whole sheets for a surface of areaMm2 with waste % added. The sheet is
/// 2800 × 2070 mm until the workshop settings arrive (furniture plan section 6.2).
func sheetsFor(_ areaMm2: Double, sheetL: Int = 2800, sheetW: Int = 2070, waste: Int = 15) -> Int {
    Int((areaMm2 * Double(100 + waste) / 100 / (Double(sheetL) * Double(sheetW)) - 1e-9).rounded(.up))
}
