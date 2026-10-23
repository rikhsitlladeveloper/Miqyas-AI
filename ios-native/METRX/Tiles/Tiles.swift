import Foundation

/*
 * The tiler's app (Kafelchi, 22 Oct 2026; Android tiles/Tiles.kt): tile layouts laid on a measured room's floor and
 * walls, or on a surface typed by its sizes. A layout is one pattern of one tile (and a second tile for a chessboard, a
 * border strip or an accent wall) on the surfaces ticked for it; a room may have several (the floor one, the walls
 * another). Lengths are mm. Pure Swift, unit-tested (TilesTests): the layout in Layout.swift, the counting in
 * Count.swift, the 3D in Mesh.swift.
 */

/// One layout. a × b is the tile, short side first (300 × 600); in the pattern its long side runs along the surface
/// (rot 0), up it (90) or at 45°. pattern: straight, brick2, brick3 (rows shifted by a half or a third), diagonal,
/// herring (herringbone), chess (two looks), border (a strip of the second tile round the floor, or a band on the walls
/// at band). start: center, corner or door, moved by hand by ox, oy on the plan. look and look2 are ids of LOOKS; a2 × b2
/// the border strip's tile (0: as the main one). roomId nil: a surface typed by its sizes (panel). spare, boxM2, boxPcs
/// and price are the advanced app's (empty: the usual ones).
struct TileLayout: Codable, Equatable, Identifiable {
    var id: String
    var model = ""
    var place = "floor"
    var pattern = "straight"
    var a = 600, b = 600
    var joint = 2
    var start = "center"
    var rot = 0
    var ox = 0, oy = 0
    var look = "white"
    var look2 = "graph"
    var a2 = 0, b2 = 0
    var accent = false
    var band = 1200
    var roomId: String? = nil
    var surfs: [TSurf] = []
    var panel: TPanel? = nil
    /// Walls: the joints start where the floor's do, so they line up at the floor.
    var align = true
    /// Floors: tile skirting this high (0: none), cut from the same tile.
    var skirt = 0
    /// Walls: corner profiles on the outside corners (window reveals, niches, columns).
    var profiles = false
    var spare: Int? = nil
    var boxM2 = ""
    var boxPcs = 0
    var price = ""
    var created: Ms = 0

    var tileArea: Double { Double(a) * Double(b) }
    /// The border strip's tile: its own size, or the main tile's.
    var sa: Int { a2 > 0 ? a2 : a }
    var sb: Int { b2 > 0 ? b2 : b }
    var usesSecond: Bool { pattern == "chess" || pattern == "border" || accent }
}

extension TileLayout {
    // layouts saved by an older version load with the newer fields at their defaults
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        model = c.v(.model, ""); place = c.v(.place, "floor"); pattern = c.v(.pattern, "straight")
        a = c.v(.a, 600); b = c.v(.b, 600); joint = c.v(.joint, 2); start = c.v(.start, "center"); rot = c.v(.rot, 0)
        ox = c.v(.ox, 0); oy = c.v(.oy, 0); look = c.v(.look, "white"); look2 = c.v(.look2, "graph")
        a2 = c.v(.a2, 0); b2 = c.v(.b2, 0); accent = c.v(.accent, false); band = c.v(.band, 1200)
        roomId = c.v(.roomId, nil); surfs = c.v(.surfs, []); panel = c.v(.panel, nil)
        align = c.v(.align, true); skirt = c.v(.skirt, 0); profiles = c.v(.profiles, false)
        spare = c.v(.spare, nil); boxM2 = c.v(.boxM2, ""); boxPcs = c.v(.boxPcs, 0); price = c.v(.price, ""); created = c.v(.created, 0)
    }
}

/// A surface the layout covers: "floor", a wall's letter, or "bath:<id>" (a bath's front panel). A wall is tiled in full
/// height (mode full), up to h1 ("to") or as a band from h0 to h1 ("band", a backsplash); alt puts the second tile on it
/// (the accent wall).
struct TSurf: Codable, Equatable {
    var id: String
    var mode = "full"
    var h0 = 0
    var h1 = 0
    var alt = false
}

/// Whether surface s's heights can be laid: "up to" a height above 0, a band whose top is above its bottom (a height typed wrong reads 0).
func surfHeightsOk(_ s: TSurf) -> Bool {
    switch s.mode {
    case "to": return s.h1 > 0
    case "band": return s.h0 > 0 && s.h1 > s.h0
    default: return true
    }
}

extension TSurf {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); mode = c.v(.mode, "full"); h0 = c.v(.h0, 0); h1 = c.v(.h1, 0); alt = c.v(.alt, false)
    }
}

/// A surface without a room: a floor a × b, or a wall or backsplash a long and b high.
struct TPanel: Codable, Equatable {
    var kind = "floor"
    var a = 3000
    var b = 2000
}

extension TPanel {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kind = c.v(.kind, "floor"); a = c.v(.a, 3000); b = c.v(.b, 2000)
    }
}

/// A shower tray or a bath marked in a room: against wall, off from its start corner, w along it, d into the room, h
/// high. Tiles stop round it; a bath's front can be tiled.
struct TFix: Codable, Equatable, Identifiable {
    var id: String
    var type = "tray"
    var wall = "A"
    var off = 0
    var w = 900
    var d = 900
    var h = 150
}

extension TFix {
    init(from dec: Decoder) throws {
        let c = try dec.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); type = c.v(.type, "tray"); wall = c.v(.wall, "A")
        off = c.v(.off, 0); w = c.v(.w, 900); d = c.v(.d, 900); h = c.v(.h, 150)
    }
}

/// A room's tiling extras: its tray and bath, and the waterproofing (floor and wpUp up the walls, the shower zone to showerH).
struct TileRoom: Codable, Equatable {
    var roomId: String
    var fixes: [TFix] = []
    var wp = false
    var wpUp = 200
    var showerH = 1800
}

extension TileRoom {
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        roomId = c.v(.roomId, ""); fixes = c.v(.fixes, []); wp = c.v(.wp, false); wpUp = c.v(.wpUp, 200); showerH = c.v(.showerH, 1800)
    }
}

/// A tile's look: a plain colour ("c"), or a drawn marble ("m"), wood ("w") or concrete ("k") of base colour rgb.
struct TileLook: Equatable {
    let id: String
    let kind: String
    let rgb: Int
    var vein = 0
}

let LOOKS: [TileLook] = [
    TileLook(id: "white", kind: "c", rgb: 0xF3F3F0), TileLook(id: "cream", kind: "c", rgb: 0xEADFCB), TileLook(id: "lgrey", kind: "c", rgb: 0xCFCECA),
    TileLook(id: "grey", kind: "c", rgb: 0x8D9096), TileLook(id: "graph", kind: "c", rgb: 0x3A3D43), TileLook(id: "black", kind: "c", rgb: 0x1F2023),
    TileLook(id: "sage", kind: "c", rgb: 0x93A792), TileLook(id: "blue", kind: "c", rgb: 0x5D7FA8), TileLook(id: "terra", kind: "c", rgb: 0xB8673F),
    TileLook(id: "carrara", kind: "m", rgb: 0xF1F0EC, vein: 0x9EA2A8), TileLook(id: "calacatta", kind: "m", rgb: 0xF3EEE4, vein: 0xB89A63),
    TileLook(id: "nero", kind: "m", rgb: 0x2C2C2F, vein: 0xD8D8D8),
    TileLook(id: "oak", kind: "w", rgb: 0xC09869), TileLook(id: "walnut", kind: "w", rgb: 0x7B5337), TileLook(id: "ash", kind: "w", rgb: 0xDCCAA8),
    TileLook(id: "cement", kind: "k", rgb: 0xAAA9A5), TileLook(id: "dcement", kind: "k", rgb: 0x6E6F71)
]

func lookOf(_ id: String) -> TileLook { LOOKS.first { $0.id == id } ?? LOOKS[0] }

/// The sizes offered first, short side first (mm).
let TILE_SIZES: [(Int, Int)] = [(200, 200), (300, 300), (300, 600), (600, 600), (600, 1200), (200, 600)]

/// The patterns, and the places of the gallery (Pol, Devor, Hammom, Oshxona fartuk).
let PATTERNS = ["straight", "brick2", "brick3", "diagonal", "herring", "chess", "border"]
let PLACES = ["floor", "wall", "bath", "apron"]

/// A gallery card: the layout it starts from; surf what it covers in a room ("floor", "walls" or "apron").
struct TModel {
    let id: String, place: String, pattern: String, a: Int, b: Int, look: String
    var look2 = "graph"
    var surf: String
    var a2 = 0, b2 = 0
    var accent = false
    init(_ id: String, _ place: String, _ pattern: String, _ a: Int, _ b: Int, _ look: String, _ look2: String = "graph", surf: String? = nil,
         a2: Int = 0, b2: Int = 0, accent: Bool = false) {
        self.id = id; self.place = place; self.pattern = pattern; self.a = a; self.b = b; self.look = look; self.look2 = look2
        self.surf = surf ?? (place == "floor" ? "floor" : place == "apron" ? "apron" : "walls")
        self.a2 = a2; self.b2 = b2; self.accent = accent
    }
}

let T_MODELS: [TModel] = [
    TModel("fl.straight", "floor", "straight", 600, 600, "cement"),
    TModel("fl.brick2", "floor", "brick2", 300, 600, "lgrey"),
    TModel("fl.brick3", "floor", "brick3", 200, 600, "oak"),
    TModel("fl.diagonal", "floor", "diagonal", 300, 300, "cream"),
    TModel("fl.herring", "floor", "herring", 200, 600, "walnut"),
    TModel("fl.chess", "floor", "chess", 300, 300, "white", "black"),
    TModel("fl.border", "floor", "border", 600, 600, "calacatta", "nero", a2: 200, b2: 600),
    TModel("wl.straight", "wall", "straight", 300, 600, "white"),
    TModel("wl.brick2", "wall", "brick2", 200, 600, "cream"),
    TModel("wl.big", "wall", "straight", 600, 1200, "carrara"),
    TModel("wl.border", "wall", "border", 300, 600, "lgrey", "graph", a2: 200, b2: 600),
    TModel("wl.herring", "wall", "herring", 200, 600, "sage"),
    TModel("bt.straight", "bath", "straight", 300, 600, "white"),
    TModel("bt.accent", "bath", "straight", 300, 600, "white", "blue", accent: true),
    TModel("bt.marble", "bath", "straight", 600, 1200, "carrara"),
    TModel("bt.floor", "bath", "chess", 300, 300, "white", "graph", surf: "floor"),
    TModel("bt.diag", "bath", "diagonal", 300, 300, "lgrey", surf: "floor"),
    TModel("ap.brick2", "apron", "brick2", 200, 600, "white"),
    TModel("ap.herring", "apron", "herring", 200, 600, "terra"),
    TModel("ap.marble", "apron", "straight", 600, 1200, "calacatta"),
    TModel("ap.chess", "apron", "chess", 200, 200, "white", "blue")
]

func tModel(_ id: String) -> TModel? { T_MODELS.first { $0.id == id } }

/// A new layout from a gallery card.
func layoutOf(_ m: TModel, _ id: String, _ now: Ms = 0) -> TileLayout {
    let joint = m.b >= 1200 ? 2 : m.place == "floor" ? 3 : 2
    return TileLayout(id: id, model: m.id, place: m.place, pattern: m.pattern, a: m.a, b: m.b, joint: joint, start: "center", look: m.look, look2: m.look2,
                      a2: m.a2, b2: m.b2, accent: m.accent, created: now)
}

/// The backsplash band the app starts with: from the worktop (900) 600 up.
let APRON_H0 = 900
let APRON_H1 = 1500

/// The usual spare: 10 % for diagonal and herringbone (and anything laid at 45°), else 5 %.
func spareOf(_ l: TileLayout) -> Int { l.spare ?? (l.pattern == "diagonal" || l.pattern == "herring" || l.rot == 45 ? 10 : 5) }

/// Tiles in a usual box of tiles a × b.
func piecesPerBox(_ a: Int, _ b: Int) -> Int {
    let m2 = Double(a) * Double(b) / 1e6
    if m2 >= 0.7 { return 2 }           // 600 × 1200
    if m2 >= 0.35 { return 4 }          // 600 × 600
    if m2 >= 0.17 { return 8 }          // 300 × 600
    // smaller tiles: about 1,2 m² a box (300 × 300: 13, 200 × 600: 10)
    let n = 1.2 / m2 + 1e-6
    return max(1, n.isFinite ? Int(n) : 1)
}

/// Tiles in a box of layout l: as set, or the usual.
func perBox(_ l: TileLayout, _ a0: Int? = nil, _ b0: Int? = nil) -> Int {
    let a = a0 ?? l.a, b = b0 ?? l.b
    if l.boxPcs > 0 && a == l.a && b == l.b { return l.boxPcs }
    if let m2 = Double(l.boxM2.replacingOccurrences(of: ",", with: ".")), m2 > 0, a == l.a, b == l.b {
        let n = m2 * 1e6 / (Double(a) * Double(b)) + 1e-6
        return max(1, n.isFinite ? Int(min(n, 1e6)) : 1)
    }
    return piecesPerBox(a, b)
}
