import Foundation

/*
 * The design of a piece (modern 3D part 2, founder's decisions of 25 Oct 2026; Android furniture/Look.kt): six design
 * style presets, the fronts' style, handle colours, the kitchen's crown, legs and island end, mirror tints, a bed's
 * headboard and fabric. The boards stay in FMats (fronts, the upper fronts of a two-tone kitchen, the worktop and the
 * backsplash); the handle's type in Furniture.handle; the plinth, cornice and LED of a kitchen in KExtras. Everything
 * else is one small PieceLook on the piece, nil on a piece made before (it looks and costs as it did). The 3D reads it
 * all through lookOf. Plain Swift, unit-tested (PieceLookTests). Named PieceLook here: Look is the 3D's render
 * description (Geo/Look.swift); the saved JSON is Android's ("look" on the piece, the same field names).
 */

/// Furniture.handle for a kitchen's Gola profile: the fronts open by the channel, no handles (Hardware.swift).
let GOLA = "gola"

/// Furniture.handle for long verticals: 1024 on tall doors, 640 on the others, 320 on drawers (longHandleIds).
let LONG_V = "longV"

/// The texture ids the 3D draws boards and fabrics with (DecorPresets.swift; the renderer's own files, part 1).
let TEX_IDS = ["oak_light", "oak_tobacco", "oak_golden", "oak_dark", "walnut", "wenge", "marble_white", "onyx_beige", "stone_dark",
               "skinali_print", "tile_white", "boucle", "velvet", "fabric", "fluted", "fluted_glass"]

/// A piece's design. Written only when set (an older piece has none), and each field only when it is not its default
/// (Android @EncodeDefault NEVER). preset the design style preset it was last set to ("" none, or changed since);
/// style the fronts: "flat", "shaker" (milled frame, neoclassic) or "fluted" (an extra); finish the colour fronts'
/// surface "gloss" or "matte" (the boards follow it; an enamel board shows it); hcol the handles' and frames' colour:
/// black, brass, gold, chrome ("" as drawn before); crown on top: "" none, "cornice", "ceiling" a row of units up to the
/// ceiling (a kitchen's cornice is KExtras.cornice); legs a kitchen on visible metal legs instead of the plinth (an
/// extra); fglass fluted glass in the glass doors (an extra); waterfall the island's worktop runs down its ends (an
/// extra); mirror the mirrors' tint: silver, bronze, graphite ("" silver); led a wardrobe's LED inside with a door
/// sensor; a bed's head ("" a plain board, "vertical", "tufted", "panels"), fabric (LOOK_FABRICS) and soft wall panel;
/// accent the wood accent's board (open shelves, insides, bedside tops; "" none).
struct PieceLook: Codable, Equatable, Hashable {
    var preset = ""
    var style = "flat"
    var finish = ""
    var hcol = ""
    var crown = ""
    var legs = false
    var fglass = false
    var waterfall = false
    var mirror = ""
    var led = false
    var head = ""
    var fabric = ""
    var panel = false
    var accent = ""
    init(preset: String = "", style: String = "flat", finish: String = "", hcol: String = "", crown: String = "", legs: Bool = false,
         fglass: Bool = false, waterfall: Bool = false, mirror: String = "", led: Bool = false, head: String = "", fabric: String = "",
         panel: Bool = false, accent: String = "") {
        self.preset = preset; self.style = style; self.finish = finish; self.hcol = hcol; self.crown = crown; self.legs = legs
        self.fglass = fglass; self.waterfall = waterfall; self.mirror = mirror; self.led = led; self.head = head; self.fabric = fabric
        self.panel = panel; self.accent = accent
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        preset = c.v(.preset, ""); style = c.v(.style, "flat"); finish = c.v(.finish, ""); hcol = c.v(.hcol, ""); crown = c.v(.crown, "")
        legs = c.v(.legs, false); fglass = c.v(.fglass, false); waterfall = c.v(.waterfall, false); mirror = c.v(.mirror, "")
        led = c.v(.led, false); head = c.v(.head, ""); fabric = c.v(.fabric, ""); panel = c.v(.panel, false); accent = c.v(.accent, "")
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case preset, style, finish, hcol, crown, legs, fglass, waterfall, mirror, led, head, fabric, panel, accent }
    /// Every field written only when it is not its default, as Android writes them.
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        if !preset.isEmpty { try c.encode(preset, forKey: .preset) }
        if style != "flat" { try c.encode(style, forKey: .style) }
        if !finish.isEmpty { try c.encode(finish, forKey: .finish) }
        if !hcol.isEmpty { try c.encode(hcol, forKey: .hcol) }
        if !crown.isEmpty { try c.encode(crown, forKey: .crown) }
        if legs { try c.encode(legs, forKey: .legs) }
        if fglass { try c.encode(fglass, forKey: .fglass) }
        if waterfall { try c.encode(waterfall, forKey: .waterfall) }
        if !mirror.isEmpty { try c.encode(mirror, forKey: .mirror) }
        if led { try c.encode(led, forKey: .led) }
        if !head.isEmpty { try c.encode(head, forKey: .head) }
        if !fabric.isEmpty { try c.encode(fabric, forKey: .fabric) }
        if panel { try c.encode(panel, forKey: .panel) }
        if !accent.isEmpty { try c.encode(accent, forKey: .accent) }
    }
}

/// A design style preset (the mockup's PRESETS, approved 25 Oct 2026): the upper and lower fronts' colour (two-tone or
/// one), finish, style, handle (bar, long, knob, gola), handle colour, the worktop (stone or wood; stone its decor),
/// backsplash (glass, print, tile), crown (none, cornice, ceiling), wood accent, mirror tint, a bed's fabric and
/// headboard. Names and lines are strings lk.p.<id> and lk.p.<id>.d.
struct DesignPreset: Equatable {
    let id: String, up: String, low: String, two: Bool, finish: String, style: String, handle: String, hcol: String
    let top: String, stone: String, splash: String, crown: String, accent: String, mirror: String, fabric: String, head: String
}

private func designP(_ id: String, _ up: String, _ low: String, _ two: Bool, _ finish: String, _ style: String, _ handle: String, _ hcol: String,
                _ top: String, _ stone: String, _ splash: String, _ crown: String, _ accent: String, _ mirror: String, _ fabric: String, _ head: String) -> DesignPreset {
    DesignPreset(id: id, up: up, low: low, two: two, finish: finish, style: style, handle: handle, hcol: hcol,
                 top: top, stone: stone, splash: splash, crown: crown, accent: accent, mirror: mirror, fabric: fabric, head: head)
}

/// Exactly the six approved presets, in the mockup's order.
let DESIGN_PRESETS: [DesignPreset] = [
    designP("twotone", "white", "graphite", true, "gloss", "flat", "bar", "black", "stone", "marble", "glass", "none", "walnut", "graphite", "olive", "vertical"),
    designP("gloss", "white", "white", false, "gloss", "flat", "long", "chrome", "stone", "marble", "print", "none", "halifax", "silver", "grey", "panels"),
    designP("gola", "cashmere", "cashmere", false, "matte", "flat", "gola", "black", "wood", "onyx", "tile", "none", "craft", "bronze", "mocha", "vertical"),
    designP("neo", "ivory", "ivory", false, "matte", "shaker", "knob", "gold", "stone", "onyx", "tile", "cornice", "walnut", "bronze", "cream", "tufted"),
    designP("wood", "white", "halifax", true, "matte", "flat", "bar", "black", "stone", "marble", "tile", "none", "halifax", "silver", "cream", "panels"),
    designP("dark", "graphite", "black", true, "matte", "flat", "long", "brass", "stone", "dark", "glass", "ceiling", "walnut", "bronze", "navy", "vertical")
]

func designPreset(_ id: String?) -> DesignPreset? { DESIGN_PRESETS.first { $0.id == id } }

/* ---------------- boards ---------------- */

private let PL_WOOD_KEYS = Set(LOOK_WOODS.map(\.key))
private let PL_COLOUR_KEYS = Set(LOOK_COLOURS.map(\.key))

/// The front board of a colour or wood colour (DecorPresets.swift keys): a wood decor as it is; a colour as gloss acrylic
/// or soft-touch matte for flat fronts, as MDF enamel for milled (shaker) and fluted ones.
func boardFor(_ colour: String, _ finish: String, _ style: String) -> String {
    if PL_WOOD_KEYS.contains(colour) { return "wd_" + colour }
    if style == "shaker" || style == "fluted" { return "en_" + colour }
    return finish == "gloss" ? "ag_" + colour : "sm_" + colour
}

/// A decor board's colour or wood key (nil: another board, e.g. an older order's LDSP).
func colourOf(_ board: String?) -> String? {
    guard let b = board, b.count >= 4 else { return nil }
    let chars = Array(b)
    guard chars[2] == "_" else { return nil }
    let k = String(chars[3...]), pre = String(chars[0..<3])
    switch pre {
    case "ag_", "sm_", "en_": return PL_COLOUR_KEYS.contains(k) ? k : nil
    case "wd_": return PL_WOOD_KEYS.contains(k) ? k : nil
    default: return nil
    }
}

/// board again for finish and style (another family of the same colour); a board that is not a decor stays.
func refinish(_ board: String, _ finish: String, _ style: String) -> String { colourOf(board).map { boardFor($0, finish, style) } ?? board }

private func stoneCode(_ decor: String) -> String { decor == "onyx" ? "o" : decor == "dark" ? "d" : "m" }

/// The worktop of a kind ("stone", "wood", "slim") and decor (stone: marble, onyx, dark; wood: craft, halifax).
func worktopFor(_ kind: String, _ decor: String) -> String {
    switch kind {
    case "wood": return decor == "halifax" ? "wt38h" : "wt38c"
    case "slim": return "wt20" + stoneCode(decor)
    default: return "wt38" + stoneCode(decor)
    }
}

/// A worktop's kind: "plain" (the usual wt38, or the workshop's own), "stone", "wood", "slim".
func worktopKind(_ id: String?) -> String {
    switch id ?? "" {
    case "wt38m", "wt38o", "wt38d": return "stone"
    case "wt38c", "wt38h": return "wood"
    case "wt20m", "wt20o", "wt20d": return "slim"
    default: return "plain"
    }
}

/// A worktop's decor key: marble, onyx, dark, craft, halifax ("" none).
func worktopDecor(_ id: String?) -> String {
    switch id ?? "" {
    case "wt38m", "wt20m": return "marble"
    case "wt38o", "wt20o": return "onyx"
    case "wt38d", "wt20d": return "dark"
    case "wt38c": return "craft"
    case "wt38h": return "halifax"
    default: return ""
    }
}

/// The backsplash of a kind: glass (plain skinali), print (printed skinali), tile; "" the workshop's panel (nil).
func splashFor(_ kind: String) -> String? {
    switch kind {
    case "glass": return "skGlass"
    case "print": return "skPrint"
    case "tile": return "spTile"
    default: return nil
    }
}

func splashKind(_ id: String?) -> String {
    switch id ?? "" {
    case "skGlass": return "glass"
    case "skPrint": return "print"
    case "spTile": return "tile"
    default: return ""
    }
}

/// The worktop a piece uses (a kitchen's, a table's or a bar's of worktop board).
func worktopOf(_ f: Furniture) -> String { f.mats.top ?? "wt38" }

/// The backsplash a kitchen uses: its own, or the list's first (as before 25 Oct 2026).
func splashOf(_ f: Furniture, _ mats: [Mat]) -> Mat? {
    if let id = f.mats.splash, let m = mats.first(where: { $0.id == id }) { return m }
    return mats.first { $0.kind == "splash" }
}

/// Whether box m of f takes the upper fronts' board: a kitchen's wall units, another piece's hung boxes.
func isUpperFront(_ f: Furniture, _ m: Module) -> Bool { f.kind == "kitchen" ? isUpper(m) : m.elev >= 1000 }

/// The front board of box m of f: the upper fronts' for isUpperFront, else the fronts'.
func frontOf(_ f: Furniture, _ m: Module?) -> String {
    if let m, isUpperFront(f, m) { return f.mats.frontUp ?? f.mats.front }
    return f.mats.front
}

/// Two colours: the upper fronts differ from the lower ones.
func isTwoTone(_ f: Furniture) -> Bool { f.mats.frontUp != nil && f.mats.frontUp != f.mats.front }

/* ---------------- handles, crown, legs ---------------- */

/// The handle's type as the design shows it: "bar", "long", "knob", "gola" or "push" (no handles).
func handleType(_ f: Furniture) -> String {
    if f.handle == GOLA && f.kind == "kitchen" { return "gola" }
    if f.modules.contains(where: { takesHandles($0) && !handleFronts($0).isEmpty }) && !hasHandles(f) { return "push" }
    if [LONG_V, "handleLong", "handle640", "handle1024"].contains(f.handle) { return "long" }
    if f.handle == "handleKnob" { return "knob" }
    return "bar"
}

/// Furniture.handle for a design's handle type; a Gola profile only on a kitchen (another piece opens by a push).
func handleIdFor(_ type: String, _ f: Furniture) -> String {
    switch type {
    case "long": return LONG_V
    case "knob": return "handleKnob"
    case "gola": return f.kind == "kitchen" ? GOLA : NO_HANDLES
    case "push": return NO_HANDLES
    default: return ""
    }
}

/// f with handles of type (bar, long, knob, gola, push), the fronts chosen without one kept (FurnSwap.swift).
func withHandleType(_ f: Furniture, _ type: String) -> Furniture { swapAll([f], handle: handleIdFor(type, f))[0] }

/// On top of the piece: "", "cornice" or "ceiling"; a kitchen's cornice is its extras'.
func crownOf(_ f: Furniture) -> String {
    if f.kind == "kitchen" && f.kx?.cornice == true { return "cornice" }
    return f.look?.crown ?? ""
}

/// f with crown on top ("", "cornice", "ceiling"): a kitchen's cornice goes in its extras, the rest in the look.
func withCrown(_ f: Furniture, _ crown: String) -> Furniture {
    var g = f
    var l = f.look ?? PieceLook()
    if f.kind == "kitchen" {
        var k = f.kx ?? KExtras(); k.cornice = crown == "cornice"; g.kx = k
        l.crown = crown == "ceiling" ? "ceiling" : ""
    } else {
        l.crown = crown
    }
    g.look = l
    return g
}

/// A kitchen on visible metal legs: no plinth, the legs priced as metal ones.
func metalLegs(_ f: Furniture) -> Bool { f.kind == "kitchen" && f.look?.legs == true }

/// A kitchen's waterfall ends: an island's two, a peninsula's one (none without an island).
func waterfallEnds(_ f: Furniture) -> Int {
    if f.kind != "kitchen" || f.look?.waterfall != true || islandLen(f) <= 0 { return 0 }
    return f.layout == "P" ? 1 : 2
}

/* ---------------- a wardrobe's crown, a bed's metal legs and wall panel (priced in lookHardware) ---------------- */

/// How far the cornice's top layer stands out at the front and past a free end, mm (CORNICE_LAYERS: 10, 26, 38).
let CORNICE_OUT = 38

/// The boxes of f that take its crown (a cornice, or a row up to the ceiling): a wardrobe's boxes standing on the floor
/// (not hung) whose top is WARD_CROWN_MIN up or more. None on a kitchen (its crown is its own) or a gorka (its
/// neoclassic cornice: Gorka.swift).
func crownBoxes(_ f: Furniture, _ ws0: Workshop) -> [Module] {
    if f.kind != "wardrobe" || f.type == "gorka" { return [] }
    let ws = wsOf(f, ws0)
    return f.modules.filter { $0.type == "wardrobe" && !hung($0) && legsOf($0, ws) + $0.elev + $0.h >= WARD_CROWN_MIN }
}

/// The free ends of f's crowned box m (0, 1 or 2), where the cornice turns back along its side: an end with its own
/// side panel, no other standing box of the piece within 60 mm of it, and off the wall's corner (more than W_GAP_SIDE
/// + 40 from it; the far corner only when wallLen, its wall's length, is known). A piece standing free has both.
func crownFreeEnds(_ f: Furniture, _ m: Module, _ wallLen: Int?) -> Int {
    if f.pose != nil { return 2 }
    func near(_ at: Int) -> Bool {
        f.modules.contains { o in o.id != m.id && o.wall == m.wall && !hung(o) && (abs(o.x + o.w - at) < 60 || abs(o.x - at) < 60) }
    }
    let l = m.sideL && m.x > W_GAP_SIDE + 40 && !near(m.x)
    let r = m.sideR && (wallLen.map { m.x + m.w < $0 - W_GAP_SIDE - 40 } ?? true) && !near(m.x + m.w)
    return (l ? 1 : 0) + (r ? 1 : 0)
}

/// A wardrobe's cornice, mm of profile: along the top of each crowned box, and at each free end back along its side and
/// round the corner (the box's depth + 2 × CORNICE_OUT). wallLen a wall's length (nil: not known); nil: pieceWallLen.
func wardCorniceMm(_ f: Furniture, _ ws: Workshop, _ wallLen: ((String?) -> Int?)? = nil) -> Int {
    let len: (String?) -> Int? = wallLen ?? { pieceWallLen(f, $0) }
    var mm = 0
    for m in crownBoxes(f, ws) { mm += m.w + crownFreeEnds(f, m, len(m.wall)) * (m.d + 2 * CORNICE_OUT) }
    return mm
}

/// A wardrobe's row up to the ceiling (extra fronts and carcass over its boxes), mm: the crowned boxes' width.
func wardCeilMm(_ f: Furniture, _ ws: Workshop) -> Int { crownBoxes(f, ws).reduce(0) { $0 + $1.w } }

/// The length of wall `wall` of f as the price sees it: a room-less piece's made-up room (Free.swift freeRoom, as its 3D
/// draws it); nil in a measured room (the price does not see the room) or without a wall.
func pieceWallLen(_ f: Furniture, _ wall: String?) -> Int? {
    guard f.roomId == nil, let wall, f.kind != "kitchen" else { return nil }
    return Geo.wallLen(freeRoom(f), wall)
}

/// The metal legs bed m of f stands on when its look shows them (PieceLook.legs): 4, or 6 under a bed wider than 1600
/// (its mattress); none on a bed with drawers or a lift-up base, or on its hidden base.
func bedMetalLegs(_ f: Furniture, _ m: Module) -> Int {
    let o = m.opt ?? ItemOpt()
    if f.look?.legs != true || m.type != "bed" || o.bed != "legs" { return 0 }
    return o.mw > 1600 ? 6 : 4
}

/// The soft wall panel's reach past each side of the bed, its bottom off the floor and its usual top, mm.
let PANEL_OUT = 400.0
let PANEL_Y0 = 80.0
let PANEL_Y1 = 1380.0

/// A bed's soft wall panel, mm: a0…a1 along the wall from the bed's left end, y0…y1 up.
struct PanelSpan: Equatable {
    let a0: Double, a1: Double, y0: Double, y1: Double
    /// Its area, mm² (as the price counts it).
    var area: Int { Int(((a1 - a0) * (y1 - y0)).rounded()) }
}

/// A bed's soft wall panel as the 3D draws it and the price counts it (one rule for both, Geo/ItemsScene3D.swift):
/// centred on bed m, PANEL_OUT past each side, from PANEL_Y0 up to PANEL_Y1 or 150 over a taller headboard; cut to the
/// wall's lo…hi (mm along it from the bed's left end). Nil on another box, or with less than 200 mm left.
func bedPanelSpan(_ m: Module, _ lo: Double = -1e9, _ hi: Double = 1e9) -> PanelSpan? {
    guard m.type == "bed" else { return nil }
    let hb = Double(max((m.opt ?? ItemOpt()).hb, m.h + 100))
    let a0 = max(-PANEL_OUT, lo), a1 = min(Double(m.w) + PANEL_OUT, hi)
    guard a1 - a0 >= 200 else { return nil }
    return PanelSpan(a0: a0, a1: a1, y0: PANEL_Y0, y1: max(PANEL_Y1, hb + 150))
}

/// Where a bed's wall panel may reach along its wall (lo to hi, mm from the bed's left end x; its wall wallLen long, nil:
/// not known): to the wall's ends. A bed moved into the room (pose) has one, not cut, only while its back is still at a
/// wall (within 60 mm, square to it); none out in the room (nil).
func bedPanelReach(_ pose: Pose?, _ x: Double, _ wallLen: Double?) -> (lo: Double, hi: Double)? {
    if let p = pose {
        if abs(p.n) < 60 && ((p.deg % 360) + 360) % 360 == 0 { return (lo: -1e9, hi: 1e9) }
        return nil
    }
    let hi: Double = wallLen.map { $0 - x } ?? 1e9
    return (lo: -x, hi: hi)
}

/// Bed m's soft wall panel on f (its look's panel) as the price counts it; wallLen its wall's length (nil: pieceWallLen).
func bedPanelOf(_ f: Furniture, _ m: Module, _ wallLen: Int? = nil) -> PanelSpan? {
    guard f.look?.panel == true else { return nil }
    let len = wallLen ?? pieceWallLen(f, m.wall)
    guard let r = bedPanelReach(f.pose, Double(m.x), len.map { Double($0) }) else { return nil }
    return bedPanelSpan(m, r.lo, r.hi)
}

/* ---------------- a preset ---------------- */

/// f set to preset id: the fronts' boards (the upper ones for a two-tone kitchen or hung boxes), the handles, the look;
/// a kitchen's worktop, backsplash (600 high when it had none) and crown. fresh (a new piece): a sliding wardrobe's
/// middle door gets the mirror too, as the mockup shows it. The extras (fluted glass, waterfall, metal legs, the slim
/// worktop) are never a preset's; LED and a bed's wall panel stay as they were.
func withPreset(_ f: Furniture, _ id: String, fresh: Bool = false) -> Furniture {
    guard let p = designPreset(id) else { return f }
    let low = boardFor(p.two ? p.low : p.up, p.finish, p.style)
    let up: String? = p.two ? boardFor(p.up, p.finish, p.style) : nil
    let kitchen = f.kind == "kitchen"
    var g = f
    g.mats.front = low; g.mats.frontUp = up
    if kitchen {
        g.mats.top = worktopFor(p.top, p.top == "wood" ? p.accent : p.stone)
        g.mats.splash = splashFor(p.splash)
    }
    var l = f.look ?? PieceLook()
    l.preset = p.id; l.style = p.style; l.finish = p.finish; l.hcol = p.hcol
    l.legs = false; l.fglass = false; l.waterfall = false
    l.mirror = p.mirror; l.fabric = p.fabric; l.head = p.head; l.accent = "wd_" + p.accent
    g.look = l
    g = withHandleType(g, p.handle)
    // the crown is a kitchen's (a wardrobe's height is its own size); a gorka takes the neoclassic cornice on its
    // towers and bridge (its height is its own size: no "to the ceiling")
    if kitchen { g = withCrown(g, p.crown == "none" ? "" : p.crown) } else if f.type == "gorka" { g = withCrown(g, p.crown == "cornice" ? "cornice" : "") }
    if kitchen && (g.kx?.splash ?? 0) == 0 { var k = g.kx ?? KExtras(); k.splash = K_SPLASH; g.kx = k }
    if fresh {
        g.modules = g.modules.map { m in
            guard let sl = m.slide else { return m }
            let n = min(4, max(2, sl.n))
            if (0..<n).contains(where: { sl.panel($0) != "ldsp" }) { return m }
            var x = m
            let mid = middleDoors(n)
            x.slide = Slide(sl.n, (0..<n).map { mid.contains($0) ? "mirror" : "ldsp" })
            return x
        }
    }
    return g
}

/// The preset a piece shows as chosen: the one it was set to, unless something was changed since.
func presetOf(_ f: Furniture) -> String { f.look?.preset ?? "" }

/// f with its look changed by fn; it is no longer its preset.
func withLook(_ f: Furniture, _ fn: (PieceLook) -> PieceLook) -> Furniture {
    var g = f
    var l = fn(f.look ?? PieceLook()); l.preset = ""
    g.look = l
    return g
}

/// The middle door(s) of n sliding doors (the mockup's mirror door): the second of two or three, the two inner ones of four.
func middleDoors(_ n: Int) -> Set<Int> { n >= 4 ? [1, 2] : [1] }

/// What a sliding wardrobe's middle door is filled with: "mirror", "glass" (lacobel) or "ldsp"; nil without sliding doors.
func middleFill(_ f: Furniture) -> String? {
    guard let sl = f.modules.first(where: { $0.slide != nil })?.slide else { return nil }
    let first = middleDoors(min(4, max(2, sl.n))).min() ?? 1
    return sl.panel(first)
}

/// f with its sliding doors' middle door(s) filled with fill ("mirror", "glass" lacobel, "ldsp").
func withMiddleFill(_ f: Furniture, _ fill: String) -> Furniture {
    var g = f
    g.modules = f.modules.map { m in
        guard let sl = m.slide else { return m }
        let n = min(4, max(2, sl.n))
        let mid = middleDoors(n)
        var x = m
        x.slide = Slide(sl.n, (0..<n).map { mid.contains($0) ? fill : sl.panel($0) })
        return x
    }
    return g
}

/* ---------------- what the 3D draws ---------------- */

/// A surface as the 3D draws it: rgb, finish ("gloss", "matte", "wood", "stone", "glass", "mirror", "metal", "fabric",
/// "velvet", "led"), the texture tex (TEX_IDS; nil: plain colour), grain along the part's length, the board mat it is
/// cut from (nil: not a board), and for fronts their style (flat, shaker, fluted).
struct Surface: Equatable {
    var rgb: String
    var finish: String
    var tex: String? = nil
    var grain = false
    var mat: String? = nil
    var style = "flat"
    init(_ rgb: String, _ finish: String, _ tex: String? = nil, _ grain: Bool = false, _ mat: String? = nil, _ style: String = "flat") {
        self.rgb = rgb; self.finish = finish; self.tex = tex; self.grain = grain; self.mat = mat; self.style = style
    }
}

/// A board's surface: an enamel board shows the look's finish; a plain board (no finish set) is matte.
private func boardSurface(_ id: String, _ mats: [Mat], _ look: PieceLook?, _ style: String = "flat") -> Surface {
    let m = mats.first { $0.id == id } ?? MAT_PRESETS.first { $0.id == id }
    let fin: String
    if let m {
        if id.hasPrefix("en_") {
            let lf = look?.finish ?? ""
            fin = lf == "gloss" || lf == "matte" ? lf : "matte"
        } else {
            fin = m.finish.isEmpty ? "matte" : m.finish
        }
    } else {
        fin = "matte"
    }
    return Surface(m?.rgb ?? "#CDBFAE", fin, m?.tex, m?.grain ?? false, id, style)
}

/// The handles' and frames' surface in the look's colour (grey metal as drawn before).
private func metalSurface(_ l: PieceLook?) -> Surface {
    let c = l?.hcol ?? ""
    if c.isEmpty { return Surface("#4B5563", "metal") }
    if c == "black" { return Surface(HANDLE_RGB["black"] ?? "#1E1F22", "matte") }
    return Surface(HANDLE_RGB[c] ?? "#4B5563", "metal")
}

/// A bed's fabric as the 3D draws it.
private func fabricSurface(_ l: PieceLook?) -> Surface {
    guard let fb = LOOK_FABRICS.first(where: { $0.key == l?.fabric }) else { return Surface("#E2D9CB", "fabric", "boucle") }
    return Surface(fb.rgb, fb.velvet ? "velvet" : "fabric", fb.velvet ? "velvet" : fb.key == "cream" ? "boucle" : "fabric")
}

/// What the 3D draws part of box m of f with (m nil: the piece as a whole). Parts:
///  - "front" the box's doors and drawers (the upper fronts' board for a kitchen's wall units); "frontUp", "frontLow" a
///    two-tone piece's upper and lower fronts by name (a sliding door's panel above and below its split);
///  - "carcass", "back", "worktop", "splash", "plinth" (the lower fronts' board), "accent" (wood; the carcass without one);
///  - "handle", "gola", "legs", "frame" (sliding doors' and glass doors' profiles) in the handle colour;
///  - "mirror" in its tint; "glass" (fluted when PieceLook.fglass); "fabric" a bed's; "led".
/// A piece without a look (made before 25 Oct 2026) gets the colours it had, flat and matte, the handles grey. mats the
/// workshop's list (a board missing there is looked up in the presets).
func lookOf(_ f: Furniture, _ m: Module?, _ part: String, _ mats: [Mat] = MAT_PRESETS) -> Surface {
    let l = f.look
    let style = l?.style ?? "flat"
    switch part {
    case "front": return boardSurface(frontOf(f, m), mats, l, style)
    case "frontUp": return boardSurface(f.mats.frontUp ?? f.mats.front, mats, l, style)
    case "frontLow": return boardSurface(f.mats.front, mats, l, style)
    case "plinth": return boardSurface(f.mats.front, mats, l, "flat")
    case "back": return boardSurface(f.mats.back, mats, l)
    case "worktop": return boardSurface(worktopOf(f), mats, l)
    case "splash": return splashOf(f, mats).map { boardSurface($0.id, mats, l) } ?? Surface("#E8E2D8", "matte")
    case "accent":
        if let a = l?.accent, !a.isEmpty { return boardSurface(a, mats, l) }
        return boardSurface(f.mats.carcass, mats, l)
    case "handle", "legs", "frame": return metalSurface(l)
    case "gola":
        let c = l?.hcol ?? ""
        return c == "black" || c.isEmpty ? Surface("#232427", "metal") : Surface("#BFC3C8", "metal")
    case "mirror":
        let t = l?.mirror ?? ""
        return Surface(MIRROR_RGB[MIRROR_RGB[t] != nil ? t : "silver"] ?? "#BCC0C4", "mirror")
    case "glass": return Surface("#F2F7F6", "glass", l?.fglass == true ? "fluted_glass" : nil)
    case "fabric": return fabricSurface(l)
    case "led": return Surface("#FFD39A", "led")
    default: return boardSurface(f.mats.carcass, mats, l)
    }
}

/* ---------------- hardware and prices ---------------- */

/// The fronts a front style is priced on: doors, drawer faces and appliance panels.
private let PL_STYLED: Set<String> = ["fp.door", "fp.dFace", "fp.panel"]

/// The look's own hardware of f (kinds counted like the modules', metre kinds in mm, area kinds in mm²): a milled or
/// fluted front style by the m² of its fronts, a kitchen's row of units to the ceiling by the metre of its wall units,
/// the waterfall ends, a wardrobe's LED with door sensors, a bed's upholstered headboard and soft wall panel. The swaps
/// (a Gola profile for the handles, metal legs, tinted mirror, fluted glass) are in lookSwap.
func lookHardware(_ f: Furniture, _ ws0: Workshop) -> Counts {
    var n = Counts()
    guard let l = f.look else { return n }
    let ws = wsOf(f, ws0)
    if l.style == "shaker" || l.style == "fluted" {
        var mm2 = 0
        for m in f.modules {
            for p in partsOf(m, ws) where p.role == "front" && PL_STYLED.contains(p.key) { mm2 += p.L * p.W * p.qty }
        }
        // a Kotlin Int on Android
        n.add(l.style == "shaker" ? "frontShaker" : "frontFluted", min(mm2, Int(Int32.max)))
    }
    if f.kind == "kitchen" && l.crown == "ceiling" { n.add("ceilUnit", wallUnitsMm(f)) }
    n.add("waterfall", waterfallEnds(f))
    // (a gorka's LED is its strips round the towers, the base and the bridge: Gorka.swift gorkaHardware)
    if f.kind == "wardrobe" && l.led && f.type != "gorka" {
        for m in f.modules where m.type == "wardrobe" && !m.led {
            n.add("led", m.w - 2 * ws.t); n.add("ledPsu", 1)
            let doors = m.sections.filter { $0.fronts.kind == "door" }.count
            n.add("ledSensor", m.slide.map { min(4, max(2, $0.n)) } ?? max(1, doors))
        }
    }
    // a wardrobe's crown: the cornice by the metre along its top and round its free ends (the kitchen's cornice item),
    // or the row up to the ceiling, its extra fronts and carcass, by the metre of its width
    switch l.crown {
    case "cornice": n.add("cornice", wardCorniceMm(f, ws))
    case "ceiling": n.add("wdCeil", wardCeilMm(f, ws))
    default: break
    }
    for m in f.modules where m.type == "bed" {
        let hb = max((m.opt ?? ItemOpt()).hb, m.h + 100)
        if !l.head.isEmpty { n.add(l.head == "tufted" ? "headTufted" : "headSoft", m.w * (hb - m.h)) }
        // the soft wall panel by its area as the 3D draws it (bedPanelSpan), and the LED strip along its top
        if let p = bedPanelOf(f, m) {
            n.add("softPanel", p.area)
            if l.led { n.add("led", Int((p.a1 - p.a0).rounded())); n.add("ledPsu", 1) }
        }
    }
    return n
}

/// Box m's hardware h as f's look changes it: a kitchen's Gola profile instead of handles (a channel along each base
/// unit, one a drawer, two on a tall unit; the wall units open by a push latch), metal legs instead of the hidden ones,
/// the mirror in its tint, the fluted glass over the glass doors.
func lookSwap(_ f: Furniture, _ m: Module, _ h: inout Counts, _ edge: Bool) {
    if f.kind == "kitchen" && f.handle == GOLA {
        let k = h.remove("handle") ?? 0
        if k > 0 {
            if m.type == "wall" || isUpper(m) {
                if !edge { h.add("push", k) }
            } else {
                h.add("gola", m.w * (m.fronts.kind == "drawer" ? k : m.type == "tall" ? 2 : 1))
            }
        }
    }
    guard let l = f.look else { return }
    if metalLegs(f), let v = h.remove("leg") { h.add("legMetal", v) }
    // a bed on its metal legs: those instead of the plain ones (4, 6 under a wide bed)
    let bl = bedMetalLegs(f, m)
    if bl > 0 { h.remove("leg"); h.add("legMetal", bl) }
    if l.mirror == "bronze" || l.mirror == "graphite", let v = h.remove("mirror") { h.add(l.mirror == "bronze" ? "mirrorBronze" : "mirrorGraphite", v) }
    if l.fglass { h.add("fglass", h["glassDoor"] ?? 0) }
}

/// The handle a door of height h takes with long verticals.
private func longFor(_ h: Int) -> String { h >= 1400 ? "handle1024" : h >= 700 ? "handle640" : "handleLong" }

/// The handle each front with one takes on f with long verticals (LONG_V): a door 1400 mm high or more takes the 1024,
/// a door from 700 the 640, a drawer, a shorter door or a dishwasher's front the 320. In the order the hardware counts
/// them, one id a handle.
func longHandleIds(_ f: Furniture, _ ws0: Workshop) -> [String] {
    let ws = wsOf(f, ws0)
    var out: [String] = []
    for m in f.modules where takesHandles(m) {
        for fr in handleFronts(m) where hasHandle(m, fr.key) {
            if fr.drawer || m.type == "gap" { out.append("handleLong"); continue }
            if fr.sec >= 0 {
                let j: Int = fr.key.range(of: ":f").flatMap { Int(fr.key[$0.upperBound...]) } ?? 0
                guard fr.sec < m.sections.count else { out.append("handleLong"); continue }
                let s = m.sections[fr.sec]
                let sizes = frontSizes(s.fronts, frontW(s), m.h - wardBase(m), ws)
                out.append(j >= 0 && j < sizes.count ? longFor(sizes[j].0) : "handleLong")
            } else {
                let j = Int(fr.key.hasPrefix("f") ? String(fr.key.dropFirst()) : fr.key) ?? 0
                let sizes = frontSizes(m.fronts, m.w, m.h, ws)
                out.append(j >= 0 && j < sizes.count ? longFor(sizes[j].0) : "handleLong")
            }
        }
    }
    return out
}
