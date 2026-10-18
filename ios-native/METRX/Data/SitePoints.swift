import Foundation

/*
 * Site points of a furniture order's room (furniture plan section 5; Android data/SitePoints.kt): what the furniture
 * must keep clear of. Unit-tested (FurnitureTests).
 */

/// The kinds, in the sheet's order.
let PT_TYPES = ["socket", "switch", "cold", "hot", "sewer", "gas", "meter"]

/// A new point's height from the floor, its diameter (sewer) or width (meter) and the meter's height, mm.
func pointDefaults(_ t: String) -> (h: Int, d: Int, mh: Int) {
    switch t {
    case "socket": return (300, 0, 0)
    case "switch": return (900, 0, 0)
    case "cold", "hot": return (550, 0, 0)
    case "sewer": return (450, 50, 0)
    case "gas": return (1000, 0, 0)
    case "meter": return (1500, 300, 400)
    default: return (500, 0, 0)
    }
}

/// Width and height a point takes on the wall, mm: a socket plate, a pipe, the meter's box.
func pointSize(_ x: SitePoint) -> (w: Int, h: Int) {
    switch x.t {
    case "socket", "switch": return (86, 86)
    case "cold", "hot", "gas": return (32, 32)
    case "sewer": let v = max(x.d, 40); return (v, v)
    case "meter": return (max(x.d, 100), max(x.mh, 100))
    default: return (40, 40)
    }
}

/// "pt.offBig" past the wall's length L, "pt.hBig" above the room's height H; nil when fine or not measured yet.
func pointProblem(_ x: SitePoint, _ L: Int?, _ H: Int?) -> String? {
    if let L, x.off > L { return "pt.offBig" }
    if let H, x.h > H { return "pt.hBig" }
    return nil
}
