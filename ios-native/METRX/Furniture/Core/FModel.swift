import Foundation

/*
 * The shared furniture core's data (design/furniture/FURNITURE_PLAN.md, section 6; Android furniture/FModel.kt). Every
 * designer (kitchen, wardrobe, later living room and bedroom) produces Furniture with Modules; the core turns them into
 * parts, a cut list, a sheet layout, hardware and a cost. Lengths are millimetres. Every field has a default so older
 * orders still load, and the JSON is the Android app's.
 */

/// A piece of furniture in an order: kind kitchen or wardrobe; its modules; which material plays which role.
struct Furniture: Codable, Equatable, Identifiable {
    var id: String
    var kind: String
    var name = ""
    var roomId: String? = nil
    var walls: [String] = []
    var modules: [Module] = []
    var mats = FMats()
    var created: Ms = 0
    /// Kitchens: I (one wall), L, U, O (a wall and an island), P (a wall and a peninsula).
    var layout = "I"
    /// The workspace it belongs to ("" for furniture without a room).
    var ws = ""
    /// Without a room (roomId nil): the typed sizes (Free.swift).
    var free: FreeSize? = nil
    /// The gallery model it started from (Free.swift F_MODELS), "" when made in a room.
    var model = ""
    /// Put in a room although bigger than its wall or ceiling ("O‘lchamni saqlash").
    var keep = false
    /// Kitchens: the worktop joints and cut-outs, backsplash, plinth, cornice, LED and end panels (KitchenExtras.swift).
    var kx: KExtras? = nil
    /// A cabinet on the wardrobe's engine (kind "wardrobe"): "" a wardrobe, or a Stage 2 type (Cabinets.swift CASE_TYPES).
    var type = ""
    /// Standing away from the walls, dragged on the room's plan: a kitchen's island, or the whole piece (a desk…); nil: the usual place.
    var pose: Pose? = nil
    /// Kitchens: the legs' height under the units, mm (the carcass stays 720, the worktop follows); nil: the workshop's.
    var baseH: Int? = nil
    init(id: String, kind: String, name: String = "", roomId: String? = nil, walls: [String] = [], modules: [Module] = [], mats: FMats = FMats(),
         created: Ms = 0, layout: String = "I", ws: String = "", free: FreeSize? = nil, model: String = "", keep: Bool = false, kx: KExtras? = nil, type: String = "",
         pose: Pose? = nil, baseH: Int? = nil) {
        self.id = id; self.kind = kind; self.name = name; self.roomId = roomId; self.walls = walls; self.modules = modules; self.mats = mats
        self.created = created; self.layout = layout; self.ws = ws; self.free = free; self.model = model; self.keep = keep; self.kx = kx; self.type = type
        self.pose = pose; self.baseH = baseH
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); kind = c.v(.kind, "kitchen"); name = c.v(.name, ""); roomId = c.v(.roomId, nil)
        walls = c.v(.walls, []); modules = c.v(.modules, []); mats = c.v(.mats, FMats()); created = c.v(.created, 0)
        layout = c.v(.layout, "I"); ws = c.v(.ws, "")
        free = c.v(.free, nil); model = c.v(.model, ""); keep = c.v(.keep, false); kx = c.v(.kx, nil); type = c.v(.type, "")
        pose = c.v(.pose, nil); baseH = c.v(.baseH, nil)
    }
}

/// The workshop's rules as f is built: a kitchen with its own legs' height.
func wsOf(_ f: Furniture, _ ws: Workshop) -> Workshop {
    guard f.kind == "kitchen", let h = f.baseH else { return ws }
    var w = ws; w.legH = h
    return w
}

/// A place in the room: a mm along wall ref from its start and n mm into the room is the back's left end; the piece is
/// turned deg from standing with its back to that wall. A piece on a wall is Pose(wall, x, 0, 0).
struct Pose: Codable, Equatable, Hashable {
    var ref: String
    var a: Int
    var n: Int
    var deg = 0
    init(_ ref: String, _ a: Int, _ n: Int, _ deg: Int = 0) { self.ref = ref; self.a = a; self.n = n; self.deg = deg }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        ref = c.v(.ref, "A"); a = c.v(.a, 0); n = c.v(.n, 0); deg = c.v(.deg, 0)
    }
}

/// Material ids (from the workshop's list) for the carcass, the fronts and the back panel.
struct FMats: Codable, Equatable {
    var carcass = "ldsp16w", front = "ldsp16k", back = "hdf3"
    init(carcass: String = "ldsp16w", front: String = "ldsp16k", back: String = "hdf3") { self.carcass = carcass; self.front = front; self.back = back }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        carcass = c.v(.carcass, "ldsp16w"); front = c.v(.front, "ldsp16k"); back = c.v(.back, "hdf3")
    }
}

/// One box. type: base (on legs, two rails on top), wall (hung), tall (on legs, full height), wardrobe (one carcass
/// split into sections by dividers), gap (no carcass: a dishwasher's panel or a free-standing fridge's space) or filler
/// (a strip of front board closing a gap). w × h × d is the carcass (legs not included); x along its run on wall,
/// elev its bottom above the floor (wall units).
struct Module: Codable, Equatable, Identifiable {
    var id: String
    var type: String
    var w: Int, h: Int, d: Int
    var x = 0
    var wall: String? = nil
    var elev = 0
    var fronts = Fronts()
    var inserts: [Insert] = []
    var sections: [Section] = []
    var legs = true
    var soft = true
    var handles = true
    var label = ""
    /// What it is for: sink, hob, oven, dishwasher, fridge (free-standing), fridgeB (built-in), hood, micro; "" for storage.
    var app = ""
    /// Wardrobes: a side panel at the left and right end; a built-in wardrobe has none where it meets a wall.
    var sideL = true
    var sideR = true
    /// Wardrobes: sliding (купе) doors over the whole front instead of each section's doors (plan 1b-2); nil: hinged.
    var slide: Slide? = nil
    /// Wardrobes: the plinth's or the legs' height, mm; nil: a plinth of 80, or the workshop's legs.
    var base: Int? = nil
    init(id: String, type: String, w: Int, h: Int, d: Int, x: Int = 0, wall: String? = nil, elev: Int = 0, fronts: Fronts = Fronts(), inserts: [Insert] = [],
         sections: [Section] = [], legs: Bool = true, soft: Bool = true, handles: Bool = true, label: String = "", app: String = "", sideL: Bool = true, sideR: Bool = true,
         slide: Slide? = nil, base: Int? = nil) {
        self.id = id; self.type = type; self.w = w; self.h = h; self.d = d; self.x = x; self.wall = wall; self.elev = elev; self.fronts = fronts
        self.inserts = inserts; self.sections = sections; self.legs = legs; self.soft = soft; self.handles = handles; self.label = label; self.app = app
        self.sideL = sideL; self.sideR = sideR; self.slide = slide; self.base = base
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); type = c.v(.type, "base"); w = c.v(.w, 600); h = c.v(.h, 720); self.d = c.v(.d, 560)
        x = c.v(.x, 0); wall = c.v(.wall, nil); elev = c.v(.elev, 0); fronts = c.v(.fronts, Fronts()); inserts = c.v(.inserts, [])
        sections = c.v(.sections, []); legs = c.v(.legs, true); soft = c.v(.soft, true); handles = c.v(.handles, true); label = c.v(.label, "")
        app = c.v(.app, ""); sideL = c.v(.sideL, true); sideR = c.v(.sideR, true); slide = c.v(.slide, nil)
        base = c.v(.base, nil)
    }
}

/// Sliding doors (furniture plan section 8, Stage 1b): n doors (2–4) in two tracks, each overlapping the next; each
/// door's filling in panels: "ldsp" (the front board), "mirror" or "glass" (lacobel), in a profile frame.
struct Slide: Codable, Equatable {
    var n = 2
    var panels: [String] = []
    init(_ n: Int = 2, _ panels: [String] = []) { self.n = n; self.panels = panels }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: CodingKeys.self); n = c.v(.n, 2); panels = c.v(.panels, []) }
    func panel(_ i: Int) -> String { i < panels.count ? panels[i] : "ldsp" }
}

/// What closes a box or a section: kind door, drawer, open or panel (an appliance's front); n how many.
struct Fronts: Codable, Equatable, Hashable {
    var kind = "door", n = 1
    init(_ kind: String = "door", _ n: Int = 1) { self.kind = kind; self.n = n }
    init(from d: Decoder) throws { let c = try d.container(keyedBy: CodingKeys.self); kind = c.v(.kind, "door"); n = c.v(.n, 1) }
}

/// Inside a box or a section: kind shelf, rail, drawer, trouser (pull-out rack), shoe (pull-out rack) or lift (a
/// pull-down rail); pos mm above the section's floor (its bottom edge, for blocks); qty for shelves; h for blocks.
struct Insert: Codable, Equatable, Hashable {
    var kind: String
    var pos = 0, qty = 1, h = 0
    init(_ kind: String, pos: Int = 0, qty: Int = 1, h: Int = 0) { self.kind = kind; self.pos = pos; self.qty = qty; self.h = h }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kind = c.v(.kind, "shelf"); pos = c.v(.pos, 0); qty = c.v(.qty, 1); h = c.v(.h, 0)
    }
}

/// A wardrobe section: its width (centre to centre of the dividers, the outer ones to the sides' outer faces).
struct Section: Codable, Equatable, Hashable {
    var w: Int
    var fronts = Fronts("door", 2)
    var inserts: [Insert] = []
    var lock = false
    /// A desk's knee space: no bottom, back or inside (Cabinets.swift).
    var knee = false
    /// A single door's hinge edge: "L" it opens to the left, "R" to the right; "" as usual (Wardrobe.swift hingeRight).
    var hinge = ""
    init(_ w: Int, fronts: Fronts = Fronts("door", 2), inserts: [Insert] = [], lock: Bool = false, knee: Bool = false, hinge: String = "") {
        self.w = w; self.fronts = fronts; self.inserts = inserts; self.lock = lock; self.knee = knee; self.hinge = hinge
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        w = c.v(.w, 600); fronts = c.v(.fronts, Fronts("door", 2)); inserts = c.v(.inserts, []); lock = c.v(.lock, false); knee = c.v(.knee, false)
        hinge = c.v(.hinge, "")
    }
}
