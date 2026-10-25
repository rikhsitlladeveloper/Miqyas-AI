import Foundation

/*
 * Kitchen extras (furniture plan section 7, Stage 1b-1; Android furniture/KitchenExtras.kt; KitchenExtrasTests): the
 * worktop's corner joints, its cut-outs for the sink and the hob and its end strips; the backsplash panel; the plinth;
 * the cornice over the wall units; the LED strip under them; end panels at the open ends of the rows. They go into
 * the cut list, the hardware list and the cost. Every rule is a default for the founder's furniture makers to check.
 */

/// A kitchen's extras: joint "butt" or "mitre" (45°) where the worktop turns a corner; cutouts for the sink and the
/// hob; splash the backsplash height in mm (0: none); plinth, cornice, led; ends and endsUp end panels on the lower
/// and the upper row. A kitchen without them (made before Stage 1b) has none.
struct KExtras: Codable, Equatable {
    var joint = "butt"
    var cutouts = true
    var splash = 0
    var plinth = false
    var cornice = false
    var led = false
    var ends = 0
    var endsUp = 0
    init(joint: String = "butt", cutouts: Bool = true, splash: Int = 0, plinth: Bool = false, cornice: Bool = false, led: Bool = false, ends: Int = 0, endsUp: Int = 0) {
        self.joint = joint; self.cutouts = cutouts; self.splash = splash; self.plinth = plinth; self.cornice = cornice; self.led = led; self.ends = ends; self.endsUp = endsUp
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        joint = c.v(.joint, "butt"); cutouts = c.v(.cutouts, true); splash = c.v(.splash, 0); plinth = c.v(.plinth, false)
        cornice = c.v(.cornice, false); led = c.v(.led, false); ends = c.v(.ends, 0); endsUp = c.v(.endsUp, 0)
    }
}

/// What a new kitchen starts with: the plinth and one end panel a row where it ends in the room (an island has two more).
func kExtrasFor(_ layout: String) -> KExtras {
    KExtras(plinth: true, ends: layout == "U" ? 0 : layout == "O" ? 3 : layout == "P" ? 2 : 1, endsUp: layout == "U" ? 0 : 1)
}

/// The worktop's corners: two runs one after the other on walls, both with worktop on them.
func worktopJoints(_ f: Furniture) -> Int {
    let runs = worktopRuns(f)
    return f.walls.indices.filter { i in
        i > 0 && f.walls[i] != ISLAND && f.walls[i - 1] != ISLAND && (runs[f.walls[i]] ?? 0) > 0 && (runs[f.walls[i - 1]] ?? 0) > 0
    }.count
}

/// The plinth's length: the lower row's fronts (base and tall units, the dishwasher, fillers), mm.
func plinthMm(_ f: Furniture) -> Int {
    f.modules.filter { !isUpper($0) && ($0.type == "base" || $0.type == "tall" || $0.type == "filler" || $0.app == "dishwasher") }.reduce(0) { $0 + $1.w }
}

/// The wall units' length (the cornice on top, the LED strip under them), mm.
func wallUnitsMm(_ f: Furniture) -> Int { f.modules.filter { $0.type == "wall" }.reduce(0) { $0 + $1.w } }

/// The LED inside a kitchen's vitrinas (glassDoors) with the kitchen's LED on, mm: each one's width (the 3D lights them so).
func vitrinaLedMm(_ f: Furniture) -> Int {
    if f.kind != "kitchen" || f.kx?.led != true { return 0 }
    var mm = 0
    for m in f.modules where glassDoors(m) { mm += m.w }
    return mm
}

/// The backsplash's length: the worktop along walls (not on the island), mm.
func splashMm(_ f: Furniture) -> Int { worktopRuns(f).filter { $0.key != ISLAND }.values.reduce(0, +) }

/// End panels as parts: the lower ones from the floor to the worktop, the upper ones the wall units' height (of no
/// module: the sticker names the piece only).
func extrasParts(_ f: Furniture, _ ws0: Workshop) -> [FPart] {
    let ws = wsOf(f, ws0)
    guard let x = f.kx else { return [] }
    var out: [FPart] = []
    func part(_ key: String, _ a: Int, _ b: Int, _ n: Int) {
        if n > 0 { out.append(FPart(key: key, mod: "", role: "front", L: max(a, b), W: min(a, b), qty: n, bands: Bands(l1: 2, l2: 2, s1: 2, s2: 2), grain: true)) }
    }
    part("fp.endLow", ws.legH + K_BASE_H, K_BASE_D + 20, x.ends)
    part("fp.endUp", K_WALL_H, K_WALL_D + 20, x.endsUp)
    return out
}

/// The extras in the hardware list: kinds counted like the modules' (metre kinds in mm).
func extrasHardware(_ f: Furniture) -> Counts {
    var n = Counts()
    guard let x = f.kx else { return n }
    let joints = worktopJoints(f)
    n.add(x.joint == "mitre" ? "wtMitre" : "wtJoint", joints)
    if x.cutouts { n.add("wtCut", f.modules.filter { $0.app == "sink" || $0.app == "hob" }.count) }
    // each worktop piece has two ends; a corner joins two of them
    let pieces = worktopRuns(f).values.filter { $0 > 0 }.count
    n.add("wtEnd", 2 * pieces - 2 * joints)
    // on visible metal legs (PieceLook.swift) there is no plinth
    if x.plinth && !metalLegs(f) { n.add("plinthK", plinthMm(f)); n.add("plinthCorner", joints) }
    if x.cornice { n.add("cornice", wallUnitsMm(f)) }
    // the LED under the wall units, and inside each vitrina along its top (founder, 26 Oct 2026: as long as the unit is
    // wide); the drivers, one each 5 m, for both together
    if x.led { let mm = wallUnitsMm(f) + vitrinaLedMm(f); n.add("led", mm); n.add("ledPsu", mm > 0 ? (mm + 4999) / 5000 : 0) }
    return n
}
