import Foundation

/*
 * Kitchen design rules (furniture plan section 7; Android furniture/Kitchen.kt). Part 3 has what the costing needs;
 * the designer's rules (runs, packing, the library, auto-fill, checks) come with the kitchen screens.
 */

let K_BASE_H = 720
let K_BASE_D = 560
let K_TOP = 38
let K_WALL_H = 720
let K_WALL_D = 300
let K_TALL_H = 2100
/// Worktop to the underside of the wall units.
let K_SPLASH = 600
/// Where the next wall's lower and upper rows start, past the corner unit of the wall before.
let K_CORNER = 600
let K_UP_CORNER = 320
let ISLAND = "island"

func worktopTop(_ ws: Workshop) -> Int { ws.legH + K_BASE_H + K_TOP }
func wallElev(_ ws: Workshop) -> Int { worktopTop(ws) + K_SPLASH }

/// The upper row: wall units, and fillers or gaps hung at wall-unit height.
func isUpper(_ m: Module) -> Bool { m.type == "wall" || ((m.type == "filler" || m.type == "gap") && m.elev >= 1000) }

/// The worktop's length on each wall: over the base units, fillers and the dishwasher of the lower row.
func worktopRuns(_ f: Furniture) -> [String: Int] {
    var out: [String: Int] = [:]
    for m in f.modules where !isUpper(m) && (m.type == "base" || m.type == "filler" || m.app == "dishwasher") { out[m.wall ?? "", default: 0] += m.w }
    return out
}

/// Worktop pieces to buy: each wall's run needs its own pieces of pieceL (corners are joined).
func worktopPieces(_ f: Furniture, _ pieceL: Int) -> Int { worktopRuns(f).values.filter { $0 > 0 }.reduce(0) { $0 + ($1 + pieceL - 1) / pieceL } }
