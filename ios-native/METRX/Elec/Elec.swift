import Foundation

/*
 * The electrician's app (Elektrik, 22 Oct 2026, built like the tiler's and the furniture maker's; Android elec/Elec.kt):
 * devices (sockets, switches, lights, low-voltage points, junction boxes) placed on a measured room's walls and ceiling
 * from room kits, the panel (shchit) on a wall, the circuits worked out from them, the cable routes from the panel along
 * the walls through the doorways, safety warnings, and in the advanced app the cable, breakers, boxes and labour. Rooms
 * that are not measured can be typed by size with point counts. Lengths are mm. Pure Swift, unit-tested (ElecTests):
 * placing in Place.swift, circuits and routes in Circuits.swift, warnings in Warn.swift, counting in Count.swift, 3D in
 * Mesh.swift.
 */

/// One device. On a wall: wall, off from the wall's start corner to its centre and h from the floor to its centre; on
/// the ceiling (wall nil): at plan point cx, cy. t one of DEV_TYPES; len an LED strip's length; w its power in watts when
/// set by hand (0: the usual); own on its own line (a breaker of its own); kit the room kit that placed it; from the
/// room's site point it was taken from.
struct ElecDev: Codable, Equatable, Identifiable {
    var id: String
    var t: String
    var roomId: String
    var wall: String? = nil
    var off = 0
    var h = 0
    var cx = 0
    var cy = 0
    var len = 0
    var w = 0
    var own = false
    var kit = ""
    var from: String? = nil

    var onCeiling: Bool { wall == nil }
}

extension ElecDev {
    // devices saved by an older version load with the newer fields at their defaults
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        t = c.v(.t, "s1"); roomId = c.v(.roomId, ""); wall = c.v(.wall, nil)
        off = c.v(.off, 0); h = c.v(.h, 0); cx = c.v(.cx, 0); cy = c.v(.cy, 0); len = c.v(.len, 0); w = c.v(.w, 0)
        own = c.v(.own, false); kit = c.v(.kit, ""); from = c.v(.from, nil)
    }
}

/// The panel: on wall of room roomId, centred off along it and h up. entry: the flat's entrance door, if it is in this room.
struct ElecPanel: Codable, Equatable {
    var roomId: String
    var wall: String
    var off: Int
    var h = PANEL_H
    var entry: String? = nil
}

extension ElecPanel {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        roomId = c.v(.roomId, ""); wall = c.v(.wall, "A"); off = c.v(.off, 0); h = c.v(.h, PANEL_H); entry = c.v(.entry, nil)
    }
}

/// A room as the electrician sees it: its kind (kitchen, bath, bed, living, hall, office, other; "" until known), the
/// door the cables come in through (door, nil: its first door), the panel room's door they leave by (pdoor, nil: that
/// room's last door) and the cable between the two doors (link, mm). seen: the room's sockets and switches already taken
/// in as devices; kits the kits put in it; pend the kits chosen before it was measured.
struct ElecRoom: Codable, Equatable {
    var roomId: String
    var kind = ""
    var door: String? = nil
    var pdoor: String? = nil
    var link = LINK_MM
    var seen: [String] = []
    var kits: [String] = []
    var pend: [KitPick] = []
}

extension ElecRoom {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        roomId = c.v(.roomId, ""); kind = c.v(.kind, ""); door = c.v(.door, nil); pdoor = c.v(.pdoor, nil); link = c.v(.link, LINK_MM)
        seen = c.v(.seen, []); kits = c.v(.kits, []); pend = c.v(.pend, [])
    }
}

/// A kit chosen for a room not measured yet: put in once the room is measured.
struct KitPick: Codable, Equatable {
    var kit: String
    var light = ""
    var led = true
    var ac = true
    var low = true
}

extension KitPick {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kit = c.v(.kit, ""); light = c.v(.light, ""); led = c.v(.led, true); ac = c.v(.ac, true); low = c.v(.low, true)
    }
}

/// A room typed by its size without measuring (L × W × H): how many sockets, switches, lights, low-voltage points and
/// power lines (stove, AC…) it has, and the cable between its door and the panel (link).
struct ElecFree: Codable, Equatable, Identifiable {
    var id: String
    var name = ""
    var kind = "other"
    var L = 4000
    var W = 3000
    var H = 2700
    var sock = 4
    var sw = 1
    var light = 1
    var low = 0
    var power = 0
    var link = 4000
    var kit = ""
    /// The power points' types in order (pst stove, pov oven, pac AC, pwh water heater); past the list, or in an older order, AC.
    var powers: [String] = []
}

extension ElecFree {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = c.v(.name, ""); kind = c.v(.kind, "other"); L = c.v(.L, 4000); W = c.v(.W, 3000); H = c.v(.H, 2700)
        sock = c.v(.sock, 4); sw = c.v(.sw, 1); light = c.v(.light, 1); low = c.v(.low, 0); power = c.v(.power, 0)
        link = c.v(.link, 4000); kit = c.v(.kit, ""); powers = c.v(.powers, [])
    }
}

/// An electrician's order: the devices, the rooms' settings, the panel, how the cables run (chase, gofra, channel), the
/// rooms without a plan; spare the cable's spare, % (nil: CABLE_SPARE).
struct ElecOrder: Codable, Equatable {
    var devs: [ElecDev] = []
    var rooms: [ElecRoom] = []
    var panel: ElecPanel? = nil
    var method = "chase"
    var free: [ElecFree] = []
    var spare: Int? = nil

    func room(_ id: String) -> ElecRoom { rooms.first { $0.roomId == id } ?? ElecRoom(roomId: id) }
    var empty: Bool { devs.isEmpty && free.isEmpty && panel == nil }
}

extension ElecOrder {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        devs = c.v(.devs, []); rooms = c.v(.rooms, []); panel = c.v(.panel, nil); method = c.v(.method, "chase")
        free = c.v(.free, []); spare = c.v(.spare, nil)
    }
}

let PANEL_H = 1600
let LINK_MM = 1000
let CABLE_SPARE = 10
/// The horizontal run of chased or channel cable: this far under the ceiling.
let ZONE_DOWN = 150
/// Cable left at each end to connect, mm.
let TAIL = 200
let COIL = 100

let METHODS = ["chase", "gofra", "channel"]
let KINDS = ["kitchen", "bath", "bed", "living", "hall", "office", "other"]

/// A device type: cat sock, sw, light, low or box; ceil on the ceiling; h its usual height (negative: that far under the
/// ceiling); dw × dh its size on the wall (ceiling: dw across); watts its usual power; group the circuit it goes on
/// ("sock": the room's sockets, which a kitchen or bathroom makes its own group).
struct DevType {
    let id: String, cat: String, ceil: Bool, h: Int, dw: Int, dh: Int, watts: Int, group: String
}

private func dt(_ id: String, _ cat: String, _ ceil: Bool, _ h: Int, _ dw: Int, _ dh: Int, _ watts: Int, _ group: String) -> DevType {
    DevType(id: id, cat: cat, ceil: ceil, h: h, dw: dw, dh: dh, watts: watts, group: group)
}

let DEV_TYPES: [DevType] = [
    dt("s1", "sock", false, 300, 86, 86, 300, "sock"),
    dt("s2", "sock", false, 300, 156, 86, 500, "sock"),
    dt("sw", "sock", false, 1100, 90, 90, 300, "sock"),
    dt("su", "sock", false, 300, 86, 86, 100, "sock"),
    dt("pst", "sock", false, 600, 100, 100, 7000, "stove"),
    dt("pov", "sock", false, 600, 86, 86, 3500, "oven"),
    dt("pac", "sock", false, -300, 86, 86, 2500, "ac"),
    dt("pwh", "sock", false, 1800, 86, 86, 2000, "wh"),
    dt("k1", "sw", false, 900, 86, 86, 0, "light"),
    dt("k2", "sw", false, 900, 86, 86, 0, "light"),
    dt("kp", "sw", false, 900, 86, 86, 0, "light"),
    dt("kd", "sw", false, 900, 86, 86, 0, "light"),
    dt("lc", "light", true, 0, 380, 0, 100, "light"),
    dt("ls", "light", true, 0, 90, 0, 10, "light"),
    dt("lw", "light", false, 1800, 220, 150, 40, "light"),
    dt("led", "light", false, -60, 0, 14, 0, "light"),
    dt("lch", "light", true, 0, 560, 0, 200, "light"),
    dt("tv", "low", false, 1100, 86, 86, 0, "low"),
    dt("lan", "low", false, 300, 86, 86, 0, "low"),
    dt("int", "low", false, 1500, 120, 200, 0, "low"),
    dt("cam", "low", false, -300, 100, 100, 0, "low"),
    dt("bell", "low", false, 1500, 86, 86, 0, "low"),
    dt("jb", "box", false, -ZONE_DOWN, 100, 100, 0, "")
]

/// The types by group on the "add" sheet.
let CATS = ["sock", "sw", "light", "low", "box"]

func devType(_ t: String) -> DevType { DEV_TYPES.first { $0.id == t } ?? DEV_TYPES[0] }

/// A height that may count from the ceiling (negative) in mm from the floor, for a room H high.
func absH(_ h: Int, _ H: Int) -> Int { h < 0 ? H + h : h }

/// The usual height of a new device of type t in a room H high; a kitchen's ordinary sockets go over the worktop.
func usualH(_ t: String, _ H: Int, _ kind: String = "") -> Int {
    if kind == "kitchen" && (t == "s1" || t == "s2") { return 1100 }
    if kind == "bath" && t == "sw" { return 1100 }
    return absH(devType(t).h, H)
}

/// A device's power, W: as typed, or the usual (an LED strip by its length, 12 W a metre).
func watts(_ d: ElecDev) -> Int {
    if d.w > 0 { return d.w }
    if d.t == "led" { return (d.len * 12 + 999) / 1000 }
    return devType(d.t).watts
}

/// A device's size on the wall, mm (an LED strip: its length × 14).
func devSize(_ d: ElecDev) -> (Int, Int) {
    let ty = devType(d.t)
    if d.t == "led" { return (max(d.len, 100), ty.dh) }
    return (ty.dw, ty.dh)
}

/// The snapping heights (mm from the floor) for a room H high.
func snapHeights(_ H: Int) -> [Int] {
    let all = [300, 600, 900, 1100, 1500, 1800, H - 300, H - ZONE_DOWN, H - 60]
    var out: [Int] = []
    for v in all where v >= 100 && v < H && !out.contains(v) { out.append(v) }
    return out
}

/* ---------------- circuits' groups ---------------- */

/// A circuit group: amps its breaker, cable its cable ("1.5", "2.5", "6" mm² VVG, "utp" low-voltage), rcd behind an
/// RCD (UZO), maxPts most points before it is too many, rgb its colour in the drawings.
struct GroupDef {
    let id: String, amps: Int, cable: String, rcd: Bool, maxPts: Int, rgb: Int
}

private func gd(_ id: String, _ amps: Int, _ cable: String, _ rcd: Bool, _ maxPts: Int, _ rgb: Int) -> GroupDef {
    GroupDef(id: id, amps: amps, cable: cable, rcd: rcd, maxPts: maxPts, rgb: rgb)
}

let GROUPS: [GroupDef] = [
    gd("light", 10, "1.5", false, 20, 0xF59E0B),
    gd("sock", 16, "2.5", false, 10, 0x2563EB),
    gd("kitch", 16, "2.5", true, 8, 0x16A34A),
    gd("bath", 16, "2.5", true, 6, 0x7C3AED),
    gd("stove", 32, "6", false, 1, 0xDC2626),
    gd("oven", 16, "2.5", false, 1, 0xEA580C),
    gd("ac", 16, "2.5", false, 1, 0x0891B2),
    gd("wh", 16, "2.5", true, 1, 0xDB2777),
    gd("own", 16, "2.5", false, 1, 0x475569),
    gd("low", 0, "utp", false, 1000, 0x0F766E)
]

func groupDef(_ id: String) -> GroupDef { GROUPS.first { $0.id == id } ?? GROUPS[1] }

/// The group device d in a room of kind goes on; nil for a junction box.
func eGroupOf(_ d: ElecDev, _ kind: String) -> String? {
    let ty = devType(d.t)
    if ty.cat == "box" { return nil }
    if ty.cat == "low" { return "low" }
    if d.own && ty.cat == "sock" { return "own" }
    if ty.group != "sock" { return ty.group }
    switch kind {
    case "kitchen": return "kitch"
    case "bath": return "bath"
    default: return "sock"
    }
}

/// The kind a room of workspace type wsType named name is, when the electrician has not said.
func guessKind(_ wsType: String?, _ name: String) -> String {
    let n = name.lowercased()
    func has(_ xs: [String]) -> Bool { xs.contains { n.contains($0) } }
    if wsType == "kitchen" || has(["oshxona", "кух", "ошхона", "kitchen"]) { return "kitchen" }
    if wsType == "bath" || has(["hammom", "ванн", "ҳаммом", "bath", "hojat", "туал"]) { return "bath" }
    if has(["koridor", "корид", "dahliz", "прихож", "hall", "kirish"]) { return "hall" }
    if has(["yotoq", "спал", "ётоқ", "bed", "bolalar", "дет"]) { return "bed" }
    if has(["mehmon", "гост", "меҳмон", "living", "zal", "зал"]) { return "living" }
    if has(["ishxona", "кабин", "office", "ишхона"]) { return "office" }
    return "other"
}

/* ---------------- Kotlin's helpers, kept exact ---------------- */

/// Kotlin's roundToInt: the nearest whole number, halves up.
func eRound(_ v: Double) -> Int { tInt((v + 0.5).rounded(.down)) }

/// Kotlin's coerceIn.
func eClamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { v < lo ? lo : (v > hi ? hi : v) }
func eClampI(_ v: Int, _ lo: Int, _ hi: Int) -> Int { v < lo ? lo : (v > hi ? hi : v) }

/// Kotlin's % on doubles (the sign of the dividend).
func eMod(_ a: Double, _ n: Double) -> Double { a.truncatingRemainder(dividingBy: n) }

/// The first element with the smallest key (Kotlin's minBy), nil when empty.
func eMinBy<T>(_ xs: [T], _ key: (T) -> Double) -> T? {
    var best: T? = nil
    var bk = 0.0
    for x in xs {
        let k = key(x)
        if best == nil || k < bk { best = x; bk = k }
    }
    return best
}

/// The first element with the largest key (Kotlin's maxBy), nil when empty.
func eMaxBy<T>(_ xs: [T], _ key: (T) -> Double) -> T? {
    var best: T? = nil
    var bk = 0.0
    for x in xs {
        let k = key(x)
        if best == nil || k > bk { best = x; bk = k }
    }
    return best
}

/// A stable sort by a key (Kotlin's sortedBy).
func eSortedBy<T>(_ xs: [T], _ key: (T) -> Double) -> [T] {
    let keyed: [(Int, Double)] = xs.indices.map { ($0, key(xs[$0])) }
    let order = keyed.sorted { a, b in a.1 != b.1 ? a.1 < b.1 : a.0 < b.0 }
    return order.map { xs[$0.0] }
}
