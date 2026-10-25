import Foundation

/*
 * The shared furniture core's data (design/furniture/FURNITURE_PLAN.md, section 6; Android furniture/FModel.kt). Every
 * designer (kitchen, wardrobe, later living room and bedroom) produces Furniture with Modules; the core turns them into
 * parts, a cut list, a sheet layout, hardware and a cost. Lengths are millimetres. Every field has a default so older
 * orders still load, and the JSON is the Android app's. Fields added later that are written only when set (Module.noHandle,
 * Insert.push, Section.noHandle and soft; Android @EncodeDefault NEVER) keep an older order's saved form, and so an
 * issued quote's fingerprint, as it was.
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
    /// Corner pieces without a room: "L" the corner at the left end of the main wall (made-up walls D, A), "" at the right.
    var hand = ""
    /// The handles' hardware id for the whole piece ("Change for all"); "" the workshop's usual handle; GOLA a kitchen's
    /// Gola profile instead of handles; LONG_V long verticals (PieceLook.swift longHandleIds).
    var handle = ""
    /// The design: front style, handle colour, crown, legs, mirror tint, bed fabric… (PieceLook.swift); nil: as before
    /// 25 Oct 2026, and then not written (Android @EncodeDefault NEVER).
    var look: PieceLook? = nil
    init(id: String, kind: String, name: String = "", roomId: String? = nil, walls: [String] = [], modules: [Module] = [], mats: FMats = FMats(),
         created: Ms = 0, layout: String = "I", ws: String = "", free: FreeSize? = nil, model: String = "", keep: Bool = false, kx: KExtras? = nil, type: String = "",
         pose: Pose? = nil, baseH: Int? = nil, hand: String = "", handle: String = "", look: PieceLook? = nil) {
        self.id = id; self.kind = kind; self.name = name; self.roomId = roomId; self.walls = walls; self.modules = modules; self.mats = mats
        self.created = created; self.layout = layout; self.ws = ws; self.free = free; self.model = model; self.keep = keep; self.kx = kx; self.type = type
        self.pose = pose; self.baseH = baseH; self.hand = hand; self.handle = handle; self.look = look
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); kind = c.v(.kind, "kitchen"); name = c.v(.name, ""); roomId = c.v(.roomId, nil)
        walls = c.v(.walls, []); modules = c.v(.modules, []); mats = c.v(.mats, FMats()); created = c.v(.created, 0)
        layout = c.v(.layout, "I"); ws = c.v(.ws, "")
        free = c.v(.free, nil); model = c.v(.model, ""); keep = c.v(.keep, false); kx = c.v(.kx, nil); type = c.v(.type, "")
        pose = c.v(.pose, nil); baseH = c.v(.baseH, nil); hand = c.v(.hand, ""); handle = c.v(.handle, "")
        look = c.v(.look, nil)
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

/// Material ids (from the workshop's list) for the carcass, the fronts and the back panel; a kitchen's upper fronts
/// frontUp (two-tone; nil: as front), its worktop top (nil: "wt38") and backsplash splash (nil: the list's first
/// backsplash, as before 25 Oct 2026). The three new ones are written only when set (nil is left out, as Android leaves
/// them out).
struct FMats: Codable, Equatable {
    var carcass = "ldsp16w", front = "ldsp16k", back = "hdf3"
    var frontUp: String? = nil
    var top: String? = nil
    var splash: String? = nil
    init(carcass: String = "ldsp16w", front: String = "ldsp16k", back: String = "hdf3", frontUp: String? = nil, top: String? = nil, splash: String? = nil) {
        self.carcass = carcass; self.front = front; self.back = back; self.frontUp = frontUp; self.top = top; self.splash = splash
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        carcass = c.v(.carcass, "ldsp16w"); front = c.v(.front, "ldsp16k"); back = c.v(.back, "hdf3")
        frontUp = c.v(.frontUp, nil); top = c.v(.top, nil); splash = c.v(.splash, nil)
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case carcass, front, back, frontUp, top, splash }
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(carcass, forKey: .carcass); try c.encode(front, forKey: .front); try c.encode(back, forKey: .back)
        try c.encodeIfPresent(frontUp, forKey: .frontUp); try c.encodeIfPresent(top, forKey: .top); try c.encodeIfPresent(splash, forKey: .splash)
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
    /// Soft-close hinges; a wardrobe's section can differ (Section.soft).
    var soft = true
    /// The piece's handles at all ("Tutqichsiz" in Change for all turns it off); the fronts left without one are in
    /// noHandle and on the sections (HandleRules.swift).
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
    /// An LED strip along the top inside (a vitrina's).
    var led = false
    /// A board-built piece that is not a cabinet (bed, table, bar counter, mirror panel, mirror): its options (Items.swift).
    var opt: ItemOpt? = nil
    /// The box's own fronts without a handle (a push latch opens them): "f0".. a kitchen unit's doors or drawers, "bd0"..
    /// a bed's drawers (HandleRules.swift).
    var noHandle: [String] = []
    init(id: String, type: String, w: Int, h: Int, d: Int, x: Int = 0, wall: String? = nil, elev: Int = 0, fronts: Fronts = Fronts(), inserts: [Insert] = [],
         sections: [Section] = [], legs: Bool = true, soft: Bool = true, handles: Bool = true, label: String = "", app: String = "", sideL: Bool = true, sideR: Bool = true,
         slide: Slide? = nil, base: Int? = nil, led: Bool = false, opt: ItemOpt? = nil, noHandle: [String] = []) {
        self.id = id; self.type = type; self.w = w; self.h = h; self.d = d; self.x = x; self.wall = wall; self.elev = elev; self.fronts = fronts
        self.inserts = inserts; self.sections = sections; self.legs = legs; self.soft = soft; self.handles = handles; self.label = label; self.app = app
        self.sideL = sideL; self.sideR = sideR; self.slide = slide; self.base = base; self.led = led; self.opt = opt; self.noHandle = noHandle
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); type = c.v(.type, "base"); w = c.v(.w, 600); h = c.v(.h, 720); self.d = c.v(.d, 560)
        x = c.v(.x, 0); wall = c.v(.wall, nil); elev = c.v(.elev, 0); fronts = c.v(.fronts, Fronts()); inserts = c.v(.inserts, [])
        sections = c.v(.sections, []); legs = c.v(.legs, true); soft = c.v(.soft, true); handles = c.v(.handles, true); label = c.v(.label, "")
        app = c.v(.app, ""); sideL = c.v(.sideL, true); sideR = c.v(.sideR, true); slide = c.v(.slide, nil)
        base = c.v(.base, nil); led = c.v(.led, false); opt = c.v(.opt, nil); noHandle = c.v(.noHandle, [])
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case id, type, w, h, d, x, wall, elev, fronts, inserts, sections, legs, soft, handles, label, app, sideL, sideR, slide, base, led, opt, noHandle }
    /// The synthesized form, with noHandle written only when set.
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(type, forKey: .type); try c.encode(w, forKey: .w); try c.encode(h, forKey: .h); try c.encode(d, forKey: .d)
        try c.encode(x, forKey: .x); try c.encodeIfPresent(wall, forKey: .wall); try c.encode(elev, forKey: .elev); try c.encode(fronts, forKey: .fronts)
        try c.encode(inserts, forKey: .inserts); try c.encode(sections, forKey: .sections); try c.encode(legs, forKey: .legs); try c.encode(soft, forKey: .soft)
        try c.encode(handles, forKey: .handles); try c.encode(label, forKey: .label); try c.encode(app, forKey: .app)
        try c.encode(sideL, forKey: .sideL); try c.encode(sideR, forKey: .sideR); try c.encodeIfPresent(slide, forKey: .slide)
        try c.encodeIfPresent(base, forKey: .base); try c.encode(led, forKey: .led); try c.encodeIfPresent(opt, forKey: .opt)
        if !noHandle.isEmpty { try c.encode(noHandle, forKey: .noHandle) }
    }
}

/// A bed's, a table's, a bar counter's or a mirror panel's few options (Items.swift). Sizes are the module's own: across
/// (Module.w), out from the wall (Module.d) and up (Module.h).
struct ItemOpt: Codable, Equatable, Hashable {
    /// Beds: "legs" plain on legs, "drawers" drawers under, "lift" a lift-up base over a storage box.
    var bed = "legs"
    /// Beds: the mattress, mm; the headboard's top above the floor.
    var mw = 1600, ml = 2000, hb = 1000
    /// Tables: "board" panel legs, "metal4" four straight metal legs, "frame" a metal frame.
    var legs = "board"
    /// Tables and bar counters: the top of "ldsp" (the front board) or "wt" (worktop board); rounded corners.
    var top = "ldsp", round = false
    /// Bunk and loft beds: the ladder at the "L" or "R" end of the front; a loft bed's space under it: "desk", "ward" or "open".
    var ladder = "R", under = "desk"
    /// Mirror panels: coat hooks, a hat shelf on top, the mirror's size (0: none).
    var hooks = 5, shelf = true, mirW = 0, mirH = 0
    /// Bar counters: open shelves on the kitchen side, the top's overhang on the seating side, a footrest.
    var shelves = true, over = 300, foot = true
    /// The big dining table (Gorka.swift): the seats it is laid for, 10 or 12 (0: an ordinary table).
    var seats = 0
    /// A gorka's TV panel (Gorka.swift): its facing ("stone", "slats", "mould") and the TV it holds, inches.
    var panel = ""
    var tv = 0
    init(bed: String = "legs", mw: Int = 1600, ml: Int = 2000, hb: Int = 1000, legs: String = "board", top: String = "ldsp", round: Bool = false,
         ladder: String = "R", under: String = "desk", hooks: Int = 5, shelf: Bool = true, mirW: Int = 0, mirH: Int = 0,
         shelves: Bool = true, over: Int = 300, foot: Bool = true, seats: Int = 0, panel: String = "", tv: Int = 0) {
        self.bed = bed; self.mw = mw; self.ml = ml; self.hb = hb; self.legs = legs; self.top = top; self.round = round
        self.ladder = ladder; self.under = under; self.hooks = hooks; self.shelf = shelf; self.mirW = mirW; self.mirH = mirH
        self.shelves = shelves; self.over = over; self.foot = foot
        self.seats = seats; self.panel = panel; self.tv = tv
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        bed = c.v(.bed, "legs"); mw = c.v(.mw, 1600); ml = c.v(.ml, 2000); hb = c.v(.hb, 1000); legs = c.v(.legs, "board")
        top = c.v(.top, "ldsp"); round = c.v(.round, false); ladder = c.v(.ladder, "R"); under = c.v(.under, "desk")
        hooks = c.v(.hooks, 5); shelf = c.v(.shelf, true); mirW = c.v(.mirW, 0); mirH = c.v(.mirH, 0)
        shelves = c.v(.shelves, true); over = c.v(.over, 300); foot = c.v(.foot, true)
        seats = c.v(.seats, 0); panel = c.v(.panel, ""); tv = c.v(.tv, 0)
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case bed, mw, ml, hb, legs, top, round, ladder, under, hooks, shelf, mirW, mirH, shelves, over, foot, seats, panel, tv }
    /// The synthesized form, with the big table's and the TV panel's fields written only when set (Android @EncodeDefault NEVER).
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(bed, forKey: .bed); try c.encode(mw, forKey: .mw); try c.encode(ml, forKey: .ml); try c.encode(hb, forKey: .hb)
        try c.encode(legs, forKey: .legs); try c.encode(top, forKey: .top); try c.encode(round, forKey: .round)
        try c.encode(ladder, forKey: .ladder); try c.encode(under, forKey: .under); try c.encode(hooks, forKey: .hooks)
        try c.encode(shelf, forKey: .shelf); try c.encode(mirW, forKey: .mirW); try c.encode(mirH, forKey: .mirH)
        try c.encode(shelves, forKey: .shelves); try c.encode(over, forKey: .over); try c.encode(foot, forKey: .foot)
        if seats != 0 { try c.encode(seats, forKey: .seats) }
        if !panel.isEmpty { try c.encode(panel, forKey: .panel) }
        if tv != 0 { try c.encode(tv, forKey: .tv) }
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
    /// A drawer of an open section without a handle: a push latch opens it (HandleRules.swift).
    var push = false
    init(_ kind: String, pos: Int = 0, qty: Int = 1, h: Int = 0, push: Bool = false) {
        self.kind = kind; self.pos = pos; self.qty = qty; self.h = h; self.push = push
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        kind = c.v(.kind, "shelf"); pos = c.v(.pos, 0); qty = c.v(.qty, 1); h = c.v(.h, 0); push = c.v(.push, false)
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case kind, pos, qty, h, push }
    /// The synthesized form, with push written only when set.
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(kind, forKey: .kind); try c.encode(pos, forKey: .pos); try c.encode(qty, forKey: .qty); try c.encode(h, forKey: .h)
        if push { try c.encode(push, forKey: .push) }
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
    /// A corner unit's blind part: this many mm at the right end of the front have no door (the other arm closes them).
    var blind = 0
    /// The doors' face: "" the front board, "mirror" a mirror on the board, "glass" glass in an aluminium frame (a vitrina's).
    var face = ""
    /// The doors (0 the left one) without a handle: a push latch opens them (HandleRules.swift).
    var noHandle: [Int] = []
    /// Soft-close hinges on this section's doors; nil: as the box (Module.soft).
    var soft: Bool? = nil
    init(_ w: Int, fronts: Fronts = Fronts("door", 2), inserts: [Insert] = [], lock: Bool = false, knee: Bool = false, hinge: String = "",
         blind: Int = 0, face: String = "", noHandle: [Int] = [], soft: Bool? = nil) {
        self.w = w; self.fronts = fronts; self.inserts = inserts; self.lock = lock; self.knee = knee; self.hinge = hinge
        self.blind = blind; self.face = face; self.noHandle = noHandle; self.soft = soft
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        w = c.v(.w, 600); fronts = c.v(.fronts, Fronts("door", 2)); inserts = c.v(.inserts, []); lock = c.v(.lock, false); knee = c.v(.knee, false)
        hinge = c.v(.hinge, ""); blind = c.v(.blind, 0); face = c.v(.face, "")
        noHandle = c.v(.noHandle, []); soft = c.v(.soft, nil)
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case w, fronts, inserts, lock, knee, hinge, blind, face, noHandle, soft }
    /// The synthesized form, with noHandle and soft written only when set.
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(w, forKey: .w); try c.encode(fronts, forKey: .fronts); try c.encode(inserts, forKey: .inserts); try c.encode(lock, forKey: .lock)
        try c.encode(knee, forKey: .knee); try c.encode(hinge, forKey: .hinge); try c.encode(blind, forKey: .blind); try c.encode(face, forKey: .face)
        if !noHandle.isEmpty { try c.encode(noHandle, forKey: .noHandle) }
        try c.encodeIfPresent(soft, forKey: .soft)
    }
}

/// The width the section's doors (or drawers) cover: all of it but a corner unit's blind part.
func frontW(_ s: Section) -> Int { max(0, s.w - s.blind) }
