import Foundation

/*
 * The plumber's app (Santexnik, 22 Oct 2026, built like the electrician's; Android plumb/Plumb.kt): fixtures (toilet,
 * basin, bath, shower, kitchen sink, washing and dish washers, water heater, gas boiler, radiators, towel rail, the
 * underfloor heating's manifold) placed against a measured room's walls from room kits, each with its water and drain
 * outlets at their usual heights; the riser (stoyak) with its meters, filters and main valves on a wall; the cold, hot,
 * drain and heating routes worked out from them along the walls and floor through the doorways; underfloor heating
 * loops; rules that warn; and in the advanced app the pipe, fittings, valves and labour. Rooms that are not measured can
 * be typed by size with fixture counts. Lengths are mm. Pure Swift, unit-tested (PlumbTests): placing in
 * PlumbPlace.swift, routes and heating in PlumbRoutes.swift, warnings in PlumbWarn.swift, counting in PlumbCount.swift,
 * 3D in PlumbMesh.swift.
 */

/// One outlet of a fixture: t cold, hot, drain, hs (heating supply) or hr (return); dx along the wall from the fixture's
/// centre; h up; d a drain's diameter.
struct FixPt: Codable, Equatable {
    var t: String
    var dx: Int
    var h: Int
    var d = 0
}

extension FixPt {
    init(from dec: Decoder) throws {
        let c = try dec.container(keyedBy: CodingKeys.self)
        t = c.v(.t, "cold"); dx = c.v(.dx, 0); h = c.v(.h, 0); d = c.v(.d, 0)
    }
}

/// One fixture against wall of room roomId, centred off from the wall's start corner. t one of FIX_TYPES; w its width
/// along the wall when set (a radiator's, by the room's heat; 0: the type's); opt "cab" a basin on a cabinet; pts its
/// outlets (they move with it); kit the kit that placed it.
struct PlFix: Codable, Equatable, Identifiable {
    var id: String
    var t: String
    var roomId: String
    var wall: String
    var off: Int
    var w = 0
    var opt = ""
    var pts: [FixPt] = []
    var kit = ""
}

extension PlFix {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        t = c.v(.t, "wc"); roomId = c.v(.roomId, ""); wall = c.v(.wall, "A"); off = c.v(.off, 0)
        w = c.v(.w, 0); opt = c.v(.opt, ""); pts = c.v(.pts, []); kit = c.v(.kit, "")
    }
}

/// An outlet on its own (not a fixture's): t cold, hot, drain, hs or hr; from the room's site point it was taken from.
struct PlPoint: Codable, Equatable, Identifiable {
    var id: String
    var t: String
    var roomId: String
    var wall: String
    var off: Int
    var h: Int
    var d = 0
    var from: String? = nil
}

extension PlPoint {
    init(from dec: Decoder) throws {
        let c = try dec.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        t = c.v(.t, "cold"); roomId = c.v(.roomId, ""); wall = c.v(.wall, "A"); off = c.v(.off, 0); h = c.v(.h, 0)
        d = c.v(.d, 0); from = c.v(.from, nil)
    }
}

/// The riser (stoyak) with the meters, filters and main valves: on wall of room roomId, off along it. hot: the
/// building's hot water comes up it too.
struct PlRiser: Codable, Equatable {
    var roomId: String
    var wall: String
    var off: Int
    var hot = true
}

extension PlRiser {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        roomId = c.v(.roomId, ""); wall = c.v(.wall, "A"); off = c.v(.off, 0); hot = c.v(.hot, true)
    }
}

/// The choices of a kit (the steps): bath, tray or cabin; basin on a cabinet; washer, towel rail, dishwasher, hand
/// basin; heater; radiators; underfloor heating at step mm.
struct POpts: Codable, Equatable {
    var bath = "bath"
    var cab = false
    var wm = true
    var tr = false
    var dw = true
    var basin = true
    var heater = "gb"
    var rad = false
    var ufh = false
    var step = UFH_STEP
}

extension POpts {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        bath = c.v(.bath, "bath"); cab = c.v(.cab, false); wm = c.v(.wm, true); tr = c.v(.tr, false); dw = c.v(.dw, true)
        basin = c.v(.basin, true); heater = c.v(.heater, "gb"); rad = c.v(.rad, false); ufh = c.v(.ufh, false); step = c.v(.step, UFH_STEP)
    }
}

/// A kit chosen for a room not measured yet: put in once the room is measured.
struct PKitPick: Codable, Equatable {
    var kit: String
    var o = POpts()
}

extension PKitPick {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kit = c.v(.kit, ""); o = c.v(.o, POpts())
    }
}

/// A room as the plumber sees it: its kind (bath, wc, kitchen, util, hall, room; "" until known), the door the pipes come
/// in by (door, nil: its first), the riser room's door they leave by (pdoor), the pipe between the two doors (link); ufh
/// underfloor heating at step mm; seen the room's water and drain site points already taken in; kits put in; pend the
/// kits chosen before it was measured.
struct PlRoom: Codable, Equatable {
    var roomId: String
    var kind = ""
    var door: String? = nil
    var pdoor: String? = nil
    var link = P_LINK_MM
    var ufh = false
    var step = UFH_STEP
    var seen: [String] = []
    var kits: [String] = []
    var pend: [PKitPick] = []
}

extension PlRoom {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        roomId = c.v(.roomId, ""); kind = c.v(.kind, ""); door = c.v(.door, nil); pdoor = c.v(.pdoor, nil); link = c.v(.link, P_LINK_MM)
        ufh = c.v(.ufh, false); step = c.v(.step, UFH_STEP); seen = c.v(.seen, []); kits = c.v(.kits, []); pend = c.v(.pend, [])
    }
}

/// A room typed by size without measuring (L × W × H): how many of each fixture it has, its radiators, underfloor
/// heating, and the typical pipe from its door to the riser (link).
struct PlFree: Codable, Equatable, Identifiable {
    var id: String
    var name = ""
    var kind = "bath"
    var L = 2500
    var W = 2000
    var H = 2700
    var wc = 1
    var basin = 1
    var bath = 1
    var shower = 0
    var sink = 0
    var wm = 0
    var dw = 0
    var wh = 0
    var gb = 0
    var rad = 0
    var ufh = false
    var link = 3000
    var kit = ""
}

extension PlFree {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = c.v(.name, ""); kind = c.v(.kind, "bath"); L = c.v(.L, 2500); W = c.v(.W, 2000); H = c.v(.H, 2700)
        wc = c.v(.wc, 1); basin = c.v(.basin, 1); bath = c.v(.bath, 1); shower = c.v(.shower, 0); sink = c.v(.sink, 0)
        wm = c.v(.wm, 0); dw = c.v(.dw, 0); wh = c.v(.wh, 0); gb = c.v(.gb, 0); rad = c.v(.rad, 0); ufh = c.v(.ufh, false)
        link = c.v(.link, 3000); kit = c.v(.kit, "")
    }
}

/// A plumber's order: the fixtures, the loose outlets, the rooms' settings, the riser, the water pipe (water ppr, mp
/// metal-plastic, pex), how the water and the heating run (run, hrun: along the walls or in the floor), the rooms
/// without a plan, the spare, and the rules' limits: the toilet's pipe to the riser (wcMax) and a 50 drain's (drainMax).
struct PlumbOrder: Codable, Equatable {
    var fixes: [PlFix] = []
    var points: [PlPoint] = []
    var rooms: [PlRoom] = []
    var riser: PlRiser? = nil
    var water = "ppr"
    var run = "wall"
    var hrun = "floor"
    var free: [PlFree] = []
    var spare: Int? = nil
    var wcMax = WC_MAX
    var drainMax = DRAIN_MAX

    func room(_ id: String) -> PlRoom { rooms.first { $0.roomId == id } ?? PlRoom(roomId: id) }
    var empty: Bool { fixes.isEmpty && points.isEmpty && free.isEmpty && riser == nil && !rooms.contains(where: { $0.ufh }) }
}

extension PlumbOrder {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        fixes = c.v(.fixes, []); points = c.v(.points, []); rooms = c.v(.rooms, []); riser = c.v(.riser, nil)
        water = c.v(.water, "ppr"); run = c.v(.run, "wall"); hrun = c.v(.hrun, "floor"); free = c.v(.free, [])
        spare = c.v(.spare, nil); wcMax = c.v(.wcMax, WC_MAX); drainMax = c.v(.drainMax, DRAIN_MAX)
    }
}

let P_LINK_MM = 1000
let PIPE_SPARE = 10
let WC_MAX = 1000
let DRAIN_MAX = 3000
/// Water along the walls: cold this high, hot KIND_DZ above it; in the floor: this high.
let WATER_Z = 250
let FLOOR_Z = 30
let KIND_DZ = 60
/// Heating along the walls: just over the floor, behind the skirting.
let HEAT_Z = 120
/// A drain's height where it meets the riser (its centre), mm.
let DRAIN_IN = 60
/// The drains are laid at this slope (mm a metre) when the outlet is high enough; the rules' least slope.
let SLOPE_50 = 30
let SLOPE_110 = 20
let MIN_50 = 20
let MIN_110 = 10
/// The riser's box (meters, filters, valves) on the wall, mm.
let RISER_W = 260
let RISER_D = 260
/// Pipe at the riser for its meter, filter and valve, a kind.
let RISER_TAIL = 600
/// PPR sticks, metal-plastic and PEX coils, the underfloor pipe's coil, m.
let STICK = 4
let UFH_COIL = 200
/// Underfloor heating: pipe spacing, the longest loop, mm.
let UFH_STEP = 150
let LOOP_MAX = 80_000
/// Radiators: watts a m² of floor, a section's watts and width.
let W_M2 = 100
let SEC_W = 180
let SEC_MM = 80

let WATERS = ["ppr", "mp", "pex"]
let RUNS = ["wall", "floor"]
let P_KINDS = ["bath", "wc", "kitchen", "util", "hall", "room"]
/// Outlet kinds: water, drain, heating supply and return.
let PT_KINDS = ["cold", "hot", "drain", "hs", "hr"]

/// A kind's colour in the drawings: cold blue, hot red, drain grey, heating supply orange and return purple; the
/// underfloor loops amber.
func kindRgb(_ t: String) -> Int {
    switch t {
    case "cold": return 0x2563EB
    case "hot": return 0xDC2626
    case "drain": return 0x6B7280
    case "hs": return 0xEA580C
    case "hr": return 0x7C3AED
    default: return 0xF59E0B
    }
}
let UFH_RGB = 0xF59E0B

/// A fixture type: cat wet, kitchen, heater or heat; w × d its footprint (along the wall × into the room), z0…h its
/// height from the floor; pts its usual outlets; tol how far an outlet's height may be off before it warns; hot it makes
/// hot water; heat it heats.
struct FixType {
    let id: String, cat: String, w: Int, d: Int, h: Int, z0: Int, pts: [FixPt]
    var tol = 150
    var hot = false
    var heat = false
}

private func fp(_ t: String, _ dx: Int, _ h: Int, _ d: Int = 0) -> FixPt { FixPt(t: t, dx: dx, h: h, d: d) }

private func ft(_ id: String, _ cat: String, _ w: Int, _ d: Int, _ h: Int, _ z0: Int, _ pts: [FixPt], tol: Int = 150, hot: Bool = false, heat: Bool = false) -> FixType {
    FixType(id: id, cat: cat, w: w, d: d, h: h, z0: z0, pts: pts, tol: tol, hot: hot, heat: heat)
}

let FIX_TYPES: [FixType] = [
    ft("wc", "wet", 380, 650, 780, 0, [fp("drain", 0, 100, 110), fp("cold", 250, 200)], tol: 100),
    ft("bs", "wet", 600, 480, 850, 650, [fp("hot", -80, 550), fp("cold", 80, 550), fp("drain", 0, 500, 50)]),
    ft("bsm", "wet", 450, 320, 850, 650, [fp("cold", 60, 550), fp("drain", 0, 500, 50)]),
    ft("bath", "wet", 1700, 750, 580, 0, [fp("hot", -625, 800), fp("cold", -475, 800), fp("drain", -700, 150, 50)]),
    ft("sh", "wet", 900, 900, 150, 0, [fp("hot", -75, 1100), fp("cold", 75, 1100), fp("drain", 0, 100, 50)]),
    ft("cab", "wet", 900, 900, 2150, 0, [fp("hot", -75, 1100), fp("cold", 75, 1100), fp("drain", 0, 100, 50)]),
    ft("sink", "kitchen", 800, 600, 850, 0, [fp("hot", -80, 550), fp("cold", 80, 550), fp("drain", 0, 500, 50)]),
    ft("wm", "wet", 600, 600, 850, 0, [fp("cold", 150, 600), fp("drain", -150, 600, 50)]),
    ft("dw", "kitchen", 600, 600, 820, 0, [fp("cold", 150, 400), fp("drain", -150, 400, 50)]),
    ft("wh", "heater", 450, 450, 2000, 1150, [fp("cold", 100, 1050), fp("hot", -100, 1050)], hot: true),
    ft("gb", "heater", 400, 320, 1850, 1150, [fp("hs", -140, 1050), fp("hot", -50, 1050), fp("cold", 50, 1050), fp("hr", 140, 1050)], hot: true, heat: true),
    ft("rad", "heat", 560, 90, 680, 100, [fp("hs", -240, 600), fp("hr", 240, 150)], tol: 100),
    ft("tr", "heat", 500, 110, 1700, 900, [fp("hot", -200, 1600), fp("hot", -200, 1000)], tol: 200),
    ft("manif", "heat", 500, 120, 900, 300, [fp("hs", -150, 400), fp("hr", 150, 400)], tol: 200)
]

func fixType(_ t: String) -> FixType { FIX_TYPES.first { $0.id == t } ?? FIX_TYPES[0] }

/// The fixture types by group on the "add" sheet.
let FIX_CATS = ["wet", "kitchen", "heater", "heat"]

/// A fixture's width along the wall, mm.
func fixW(_ f: PlFix) -> Int { f.w > 0 ? f.w : fixType(f.t).w }
func fixD(_ f: PlFix) -> Int { fixType(f.t).d }
/// The bottom of a fixture: a basin on a cabinet stands on the floor.
func fixZ0(_ f: PlFix) -> Int { f.opt == "cab" ? 0 : fixType(f.t).z0 }
func fixTop(_ f: PlFix) -> Int { fixType(f.t).h }

/// A radiator's outlets for its width w: the supply at the top of one end, the return at the bottom of the other.
func radPts(_ w: Int) -> [FixPt] { [FixPt(t: "hs", dx: -w / 2 + 40, h: 600), FixPt(t: "hr", dx: w / 2 - 40, h: 150)] }

/// The usual outlets of a new fixture of type t, w wide.
func defaultPts(_ t: String, _ w: Int = 0) -> [FixPt] { t == "rad" ? radPts(w > 0 ? w : fixType(t).w) : fixType(t).pts }

/// The usual heights a loose outlet snaps to, mm from the floor.
let SNAP_H = [60, 100, 150, 200, 250, 400, 500, 550, 600, 800, 1000, 1050, 1100, 1200]

/// The usual height of a new loose outlet of kind t.
func usualPtH(_ t: String) -> Int {
    switch t {
    case "drain": return 500
    case "hs": return 600
    case "hr": return 150
    default: return 550
    }
}

/// The diameter of a drain outlet d (0: 50).
func drainD(_ d: Int) -> Int { d >= 100 ? 110 : 50 }

/// The kind a room of workspace type wsType named name is, when the plumber has not said.
func pGuessKind(_ wsType: String?, _ name: String) -> String {
    let n = name.lowercased()
    func has(_ xs: [String]) -> Bool { xs.contains { n.contains($0) } }
    if has(["hojat", "туал", "ҳожат", "санузел", "toilet", "uborn"]) || n == "wc" { return "wc" }
    if has(["qozon", "котел", "котёл", "котель", "boiler", "kotyol", "utility", "кир", "kir "]) { return "util" }
    switch guessKind(wsType, name) {
    case "kitchen": return "kitchen"
    case "bath": return "bath"
    case "hall": return "hall"
    default: return "room"
    }
}
