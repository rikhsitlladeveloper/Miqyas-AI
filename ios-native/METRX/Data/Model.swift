import Foundation

/*
 * The project model of the prototype (design/prototype: newProject(), workspace.js), the same shape as the Android
 * app's data/Model.kt so both apps store a project the same way. Lengths are millimetres, times are epoch ms.
 *
 * Names that start with "@" are not typed text but a strings key, so they follow the app language:
 * "@floor1" and "@floor:2" are "1-qavat" / "2-qavat", "@ws.t.bath" is "Hammom" (see Names.swift).
 *
 * Every field has a default and decoding falls back to it when a key is missing, so older saved projects still load
 * after fields are added.
 */

extension KeyedDecodingContainer {
    /// The value under k, or d when it is missing or unreadable.
    func v<T: Decodable>(_ k: Key, _ d: T) -> T { ((try? decodeIfPresent(T.self, forKey: k)) ?? nil) ?? d }
}

typealias Ms = Int64

func nowMs() -> Ms { Ms(Date().timeIntervalSince1970 * 1000) }

struct Location: Codable, Equatable {
    var lat: Double, lng: Double, acc: Int, ts: Ms
}

struct Project: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var customer = ""
    var phone = ""              // 9 local digits, no +998
    var address = ""
    var location: Location? = nil
    var currency = "UZS"
    var precision = 0
    var reportLang = "uz"
    var stage = "measure"       // measure, estimate, quote, work, done
    var floors: [Workspace] = []
    var rooms: [Room] = []
    var estimate = Estimate()
    var quotes: [Quote] = []
    var reportRooms: [String: Bool] = [:]   // room id -> in the report (default yes)
    var reportViews: [String: Bool] = [:]   // 3D view id -> in the report (default yes)
    var reportNotes = ""                    // the report's own note (prototype p.report.notes)
    var created: Ms = 0
    var edited: Ms = 0
    /// "build" (a builder's project), "furniture" (a furniture order), "tiler" or another trade; older projects are builders'.
    var industry = "build"
    /// Furniture: the price agreed with the customer in the smallest unit, "" until the order is approved.
    var agreed = ""
    var payments: [Payment] = []
    /// Furniture orders: the kitchens, wardrobes… designed for it (furniture plan section 6.1).
    var furniture: [Furniture] = []
    /// Furniture orders: how the customer price is worked out, and the lead time (furniture plan section 6.7).
    var fprice = FPrice()
    /// Furniture orders: when the order was approved (0: not yet), and an install date set by hand (0: worked out).
    var approvedAt: Ms = 0
    var install: Ms = 0
    /// Furniture orders: what the customer wants (kitchen, wardrobe, other), nil until chosen ("Nima kerak?").
    var want: [String]? = nil
    /// Furniture orders: the name follows the furniture ("Oshxona — Akmal") until the maker renames it.
    var autoName = false
    /// Tilers' orders: the tile layouts (Tiles/Tiles.swift), and each room's tray, bath and waterproofing.
    var tiles: [TileLayout] = []
    var troom: [TileRoom] = []
    /// Electricians' orders: the devices, the panel, the rooms' settings and the rooms typed by size (Elec/Elec.swift).
    var elec = ElecOrder()
    /// Plumbers' orders: the fixtures, outlets, riser, the rooms' settings and the rooms typed by size (Plumb/Plumb.swift).
    var plumb = PlumbOrder()
    /// Windows-and-doors orders: the windows and doors filling the rooms' openings, and those without a room (Win/Win.swift).
    var win = WinOrder()
    /// Furniture orders (Advanced): when the parts were cut and the offcuts kept as remnants (0: not yet).
    var cutAt: Ms = 0
    /// Furniture orders: the design style preset new pieces start with (Furniture/Core/PieceLook.swift DESIGN_PRESETS;
    /// "" none, and then not written, as Android leaves it out).
    var fstyle = ""
    /// Furniture orders (Advanced): the customer's PDF shows the three price options, Ekonom, Standart and Premium
    /// (Furniture/Core/PriceTiers.swift); written only when on, as Android leaves it out.
    var tri = false
    /// An older version's "Namuna — oshxona" sample order: read only so it can be deleted (UX/SampleOrder.swift purge).
    var sample = false
    /// Furniture orders: the progress steps passed that the order itself does not show (UX upgrades section 2): "design"
    /// once the designer's main button was used, "price" once the price was looked at; written only when set.
    var flow: [String] = []

    var isFurniture: Bool { industry == "furniture" }
    /// A tiler's order (its own app: layouts in 3D, like the furniture maker's).
    var isTiler: Bool { industry == "tiler" }
    /// An electrician's order (its own app: devices, circuits and cable routes in 3D).
    var isElec: Bool { industry == "elec" }
    /// A plumber's order (its own app: fixtures, pipes and heating in 3D).
    var isPlumb: Bool { industry == "plumb" }
    /// A windows-and-doors order (its own app: products from a gallery fitted in the openings, in 3D).
    var isWin: Bool { industry == "win" }

    init(id: String, name: String, customer: String = "", phone: String = "", address: String = "", location: Location? = nil,
         currency: String = "UZS", reportLang: String = "uz", created: Ms = 0, edited: Ms = 0) {
        self.id = id; self.name = name; self.customer = customer; self.phone = phone; self.address = address
        self.location = location; self.currency = currency; self.reportLang = reportLang; self.created = created; self.edited = edited
    }

    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = c.v(.name, "")
        customer = c.v(.customer, ""); phone = c.v(.phone, ""); address = c.v(.address, ""); location = c.v(.location, nil)
        currency = c.v(.currency, "UZS"); precision = c.v(.precision, 0); reportLang = c.v(.reportLang, "uz"); stage = c.v(.stage, "measure")
        floors = c.v(.floors, []); rooms = c.v(.rooms, []); estimate = c.v(.estimate, Estimate()); quotes = c.v(.quotes, [])
        reportRooms = c.v(.reportRooms, [:]); reportViews = c.v(.reportViews, [:]); reportNotes = c.v(.reportNotes, "")
        created = c.v(.created, 0); edited = c.v(.edited, 0)
        industry = c.v(.industry, "build"); agreed = c.v(.agreed, ""); payments = c.v(.payments, [])
        furniture = c.v(.furniture, []); fprice = c.v(.fprice, FPrice())
        approvedAt = c.v(.approvedAt, 0); install = c.v(.install, 0); want = c.v(.want, nil); autoName = c.v(.autoName, false)
        tiles = c.v(.tiles, []); troom = c.v(.troom, []); elec = c.v(.elec, ElecOrder())
        plumb = c.v(.plumb, PlumbOrder()); win = c.v(.win, WinOrder())
        cutAt = c.v(.cutAt, 0); fstyle = c.v(.fstyle, ""); tri = c.v(.tri, false)
        sample = c.v(.sample, false); flow = c.v(.flow, [])
    }

    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, name, customer, phone, address, location, currency, precision, reportLang, stage, floors, rooms, estimate, quotes
        case reportRooms, reportViews, reportNotes, created, edited, industry, agreed, payments, furniture, fprice, approvedAt, install
        case want, autoName, tiles, troom, elec, plumb, win, cutAt, fstyle, tri, sample, flow
    }
    /// The synthesized form, with fstyle and tri written only when set (an order without them saves as before).
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(name, forKey: .name); try c.encode(customer, forKey: .customer)
        try c.encode(phone, forKey: .phone); try c.encode(address, forKey: .address); try c.encodeIfPresent(location, forKey: .location)
        try c.encode(currency, forKey: .currency); try c.encode(precision, forKey: .precision); try c.encode(reportLang, forKey: .reportLang)
        try c.encode(stage, forKey: .stage); try c.encode(floors, forKey: .floors); try c.encode(rooms, forKey: .rooms)
        try c.encode(estimate, forKey: .estimate); try c.encode(quotes, forKey: .quotes); try c.encode(reportRooms, forKey: .reportRooms)
        try c.encode(reportViews, forKey: .reportViews); try c.encode(reportNotes, forKey: .reportNotes); try c.encode(created, forKey: .created)
        try c.encode(edited, forKey: .edited); try c.encode(industry, forKey: .industry); try c.encode(agreed, forKey: .agreed)
        try c.encode(payments, forKey: .payments); try c.encode(furniture, forKey: .furniture); try c.encode(fprice, forKey: .fprice)
        try c.encode(approvedAt, forKey: .approvedAt); try c.encode(install, forKey: .install); try c.encodeIfPresent(want, forKey: .want)
        try c.encode(autoName, forKey: .autoName); try c.encode(tiles, forKey: .tiles); try c.encode(troom, forKey: .troom)
        try c.encode(elec, forKey: .elec); try c.encode(plumb, forKey: .plumb); try c.encode(win, forKey: .win); try c.encode(cutAt, forKey: .cutAt)
        if !fstyle.isEmpty { try c.encode(fstyle, forKey: .fstyle) }
        if tri { try c.encode(tri, forKey: .tri) }
        if sample { try c.encode(sample, forKey: .sample) }
        if !flow.isEmpty { try c.encode(flow, forKey: .flow) }
    }
}

/// Money received for a furniture order: amount in the smallest unit; pre marks the prepayment.
struct Payment: Codable, Equatable, Identifiable {
    var id: String
    var amount: String
    var ts: Ms
    var note = ""
    var pre = false
    init(id: String, amount: String, ts: Ms, note: String = "", pre: Bool = false) { self.id = id; self.amount = amount; self.ts = ts; self.note = note; self.pre = pre }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); amount = c.v(.amount, "0"); ts = c.v(.ts, 0); note = c.v(.note, ""); pre = c.v(.pre, false)
    }
}

/// A furniture order's stages, in order (furniture plan section 4).
let F_STAGES = ["measure", "design", "quote", "approved", "production", "installed", "paid"]

/// A workspace: a place in the project (a floor, a room, a bathroom, the yard…). Stored in Project.floors like the prototype.
struct Workspace: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var type = "floor"          // floor, room, bath, kitchen, balcony, outdoor, other
    var items: [Item] = []      // drawings, photos and notes; room plans live in Project.rooms
    var created: Ms = 0

    init(id: String, name: String, type: String = "floor", items: [Item] = [], created: Ms = 0) {
        self.id = id; self.name = name; self.type = type; self.items = items; self.created = created
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = c.v(.name, ""); type = c.v(.type, "floor"); items = c.v(.items, []); created = c.v(.created, 0)
    }
}

struct Check: Codable, Equatable, Identifiable {
    var id: String
    var text = ""
    var done = false
    init(id: String, text: String = "", done: Bool = false) { self.id = id; self.text = text; self.done = done }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); text = c.v(.text, ""); done = c.v(.done, false)
    }
}

/// One mark on a drawing or a photo (prototype it.els): t pen, line, dim, arrow or text; pts in the item's own
/// coordinates (1000 wide); c ink, cobalt or red; w pen width; v a length in mm with src "laser" or "manual"; txt a text mark.
struct MkEl: Codable, Equatable, Identifiable {
    var id: String
    var t: String
    var pts: [[Double]]
    var c = "ink"
    var w = 1
    var v: Int? = nil
    var src: String? = nil
    var txt: String? = nil
    init(id: String, t: String, pts: [[Double]], c: String = "ink", w: Int = 1, v: Int? = nil, src: String? = nil, txt: String? = nil) {
        self.id = id; self.t = t; self.pts = pts; self.c = c; self.w = w; self.v = v; self.src = src; self.txt = txt
    }
    init(from d: Decoder) throws {
        let k = try d.container(keyedBy: CodingKeys.self)
        id = try k.decode(String.self, forKey: .id); t = k.v(.t, "pen"); pts = k.v(.pts, []); c = k.v(.c, "ink"); w = k.v(.w, 1)
        v = k.v(.v, nil); src = k.v(.src, nil); txt = k.v(.txt, nil)
    }
}

/// A drawing, a photo or a note inside a workspace. A drawing or photo is W × H units with its marks; a photo's picture
/// is the JPEG file src in the app's storage ("photos/<id>.jpg") and may carry a caption.
struct Item: Codable, Equatable, Identifiable {
    var id: String
    var kind: String            // drawing, photo, note
    var name = ""
    var text = ""
    var checks: [Check] = []
    var rep: Bool? = nil        // in the report; nil = the kind's default (notes no, the rest yes)
    var created: Ms = 0
    var edited: Ms = 0
    var els: [MkEl] = []
    var src: String? = nil
    var W = 1000
    var H = 0
    var caption = ""

    var inReport: Bool { rep ?? (kind != "note") }
    /// The height in item units (prototype it.H || (photo ? 750 : 1300)).
    var hh: Int { H > 0 ? H : kind == "photo" ? 750 : 1300 }

    init(id: String, kind: String, name: String = "", rep: Bool? = nil, created: Ms = 0, edited: Ms = 0) {
        self.id = id; self.kind = kind; self.name = name; self.rep = rep; self.created = created; self.edited = edited
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); kind = c.v(.kind, "note"); name = c.v(.name, ""); text = c.v(.text, "")
        checks = c.v(.checks, []); rep = c.v(.rep, nil); created = c.v(.created, 0); edited = c.v(.edited, 0)
        els = c.v(.els, []); src = c.v(.src, nil); W = c.v(.W, 1000); H = c.v(.H, 0); caption = c.v(.caption, "")
    }
}

/// A reading waiting for the builder's confirmation (prototype dims[k].pending): from the real laser ("laser"), the simulator ("sim") or typed.
struct Pending: Codable, Equatable {
    var mm: Int
    var src = "sim"
    var from: String? = nil
    init(mm: Int, src: String = "sim", from: String? = nil) { self.mm = mm; self.src = src; self.from = from }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        mm = c.v(.mm, 0); src = c.v(.src, "sim"); from = c.v(.from, nil)
    }
}

/// One measurement in mm. v is the confirmed value; pending an unconfirmed reading. Status: pending → "recv",
/// v → "conf", else "unset" (prototype dimStatus). src: "sim" (laser), "manual" (typed), "default" (thickness only).
struct Dim: Codable, Equatable {
    var v: Int? = nil
    var src: String? = nil
    var pending: Pending? = nil
    var status: String { pending != nil ? "recv" : v != nil ? "conf" : "unset" }
    init(v: Int? = nil, src: String? = nil, pending: Pending? = nil) { self.v = v; self.src = src; self.pending = pending }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        v = c.v(.v, nil); src = c.v(.src, nil); pending = c.v(.pending, nil)
    }
}

/// A door or window. Offset from the wall's start corner, clockwise, to the near edge; sill from the floor (doors 0).
struct Opening: Codable, Equatable, Identifiable {
    var id: String
    var type: String            // door, window
    var wall: String            // A, B, C, D (or a polygon wall letter)
    var w: Int, h: Int, off: Int
    var sill = 0
    var offDrag = false         // position set by dragging: approximate until saved from its sheet
    var sillDrag = false
    /// The style (room-editor mockup v2, Rooms/ReCatalog.swift RE_STYLES; Android Opening.style): a door's single, double,
    /// slide, arch, glass, balcony or fold; a window's single, double, triple, fort, pano or balcony. "" an older opening
    /// (a door single, a window double). A balcony block (door or window style "balcony") is one opening from the
    /// floor: w in all, h the door's height (the window's top is level with it), dw the door part's width and wh the
    /// window's height; its sill stays 0.
    var style = ""
    var dw = 0
    var wh = 0
    /// A door's threshold, mm (0, 20, 40).
    var thr = 0
    /// How it opens, seen from inside: a door's inL, inR, outL, outR; a window's L, R or T (fortochka). "" the usual.
    var sw = ""
    var approx: Bool { offDrag || sillDrag }
    /// A balcony block: a door and a window side by side.
    var balcony: Bool { style == "balcony" && dw > 0 }
    /// The wall it takes away, mm²: a balcony block's door part plus its window part.
    var area: Int64 { balcony ? Int64(dw) * Int64(h) + Int64(max(0, w - dw)) * Int64(min(wh, h)) : Int64(w) * Int64(h) }
    /// A balcony block drawn as its door and its window (the plans that know only doors and windows), else itself; the
    /// parts keep its id, so a tap still selects the block.
    var drawnParts: [Opening] {
        guard balcony else { return [self] }
        var d = self
        d.type = "door"; d.w = dw; d.style = ""; d.dw = 0; d.wh = 0
        var w = self
        w.type = "window"; w.off = off + dw; w.w = max(0, self.w - dw); w.h = min(wh, h); w.sill = max(0, h - min(wh, h))
        w.style = ""; w.dw = 0; w.wh = 0
        return [d, w]
    }
    /// The holes it makes in its wall (along it from the wall's start corner): a balcony block's door part (at the start)
    /// and window part (level with the door's top), else itself.
    var holes: [(off: Int, w: Int, sill: Int, h: Int, door: Bool)] {
        if balcony { return [(off, dw, 0, h, true), (off + dw, max(0, w - dw), max(0, h - min(wh, h)), min(wh, h), false)] }
        return [(off, w, sill, h, type == "door")]
    }
    init(id: String, type: String, wall: String, w: Int, h: Int, off: Int, sill: Int = 0) {
        self.id = id; self.type = type; self.wall = wall; self.w = w; self.h = h; self.off = off; self.sill = sill
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); type = c.v(.type, "door"); wall = c.v(.wall, "A")
        w = c.v(.w, 900); h = c.v(.h, 2100); off = c.v(.off, 0); sill = c.v(.sill, 0)
        offDrag = c.v(.offDrag, false); sillDrag = c.v(.sillDrag, false)
        style = c.v(.style, ""); dw = c.v(.dw, 0); wh = c.v(.wh, 0); thr = c.v(.thr, 0); sw = c.v(.sw, "")
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case id, type, wall, w, h, off, sill, offDrag, sillDrag, style, dw, wh, thr, sw }
    /// The new fields are written only when set, so an older opening saves as before (Android EncodeDefault.NEVER).
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(type, forKey: .type); try c.encode(wall, forKey: .wall)
        try c.encode(w, forKey: .w); try c.encode(h, forKey: .h); try c.encode(off, forKey: .off); try c.encode(sill, forKey: .sill)
        try c.encode(offDrag, forKey: .offDrag); try c.encode(sillDrag, forKey: .sillDrag)
        if !style.isEmpty { try c.encode(style, forKey: .style) }
        if dw != 0 { try c.encode(dw, forKey: .dw) }
        if wh != 0 { try c.encode(wh, forKey: .wh) }
        if thr != 0 { try c.encode(thr, forKey: .thr) }
        if !sw.isEmpty { try c.encode(sw, forKey: .sw) }
    }
}

struct Pt: Codable, Equatable { var x: Double; var y: Double }

struct Diag: Codable, Equatable { var id: String; var a: Int; var b: Int }

/// A drawn room: corners in mm keeping the sketch's proportions (not the measured shape), clockwise, first corner top-left.
struct Poly: Codable, Equatable {
    var verts: [Pt]
    var diags: [Diag] = []
    var template = "sketch"
    /// The 90°/45° snap the room was drawn with, so changing the setting later does not re-solve it (nil: a room saved
    /// before this was kept, filled in with the setting when it loads).
    var snap: Bool? = nil
    init(verts: [Pt], diags: [Diag] = [], template: String = "sketch", snap: Bool? = nil) {
        self.verts = verts; self.diags = diags; self.template = template; self.snap = snap
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        verts = c.v(.verts, []); diags = c.v(.diags, []); template = c.v(.template, "sketch"); snap = c.v(.snap, nil)
    }
}

struct View3D: Codable, Equatable, Identifiable { var id: String; var img: String; var ts: Ms }

/// A room plan (prototype newRoom()). Rectangle: dims A (length, walls A and C), B (width, walls B and D), H (height),
/// T (wall thickness, 200 by default, only used to draw). Polygon: one dim per wall letter plus H, T and diagonals X1….
struct Room: Codable, Equatable, Identifiable {
    var id: String
    var floorId: String
    var name: String
    var template = "rect"
    var shape = "rect"          // rect, poly
    var dims: [String: Dim] = ["A": Dim(), "B": Dim(), "H": Dim(), "T": Dim(v: 200, src: "default")]
    var openings: [Opening] = []
    var poly: Poly? = nil
    var rot = 0                 // plan turned in 90° steps
    var views: [View3D] = []
    var wallColor = "#ECE8E1"
    var floorColor = "#C49A6C"
    var created: Ms = 0
    /// Furniture orders: sockets, switches, pipes and the gas meter on the walls (furniture plan section 5).
    var points: [SitePoint] = []
    /// Columns and niches (room editor).
    var features: [Feature] = []
    /// Each wall's own thickness, mm, by wall id (room-editor mockup v2 "Qalinlik"; Android Room.thick); a wall not in
    /// it has T (200).
    var thick: [String: Int] = [:]

    func dim(_ k: String) -> Dim { dims[k] ?? Dim() }
    /// Wall id's thickness, mm.
    func thickOf(_ id: String) -> Int { thick[id] ?? dims["T"]?.v ?? 200 }
    var isPoly: Bool { shape == "poly" && (poly?.verts.count ?? 0) >= 3 }

    init(id: String, floorId: String, name: String, created: Ms = 0) { self.id = id; self.floorId = floorId; self.name = name; self.created = created }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); floorId = c.v(.floorId, ""); name = c.v(.name, "")
        template = c.v(.template, "rect"); shape = c.v(.shape, "rect")
        dims = c.v(.dims, ["A": Dim(), "B": Dim(), "H": Dim(), "T": Dim(v: 200, src: "default")])
        openings = c.v(.openings, []); poly = c.v(.poly, nil); rot = c.v(.rot, 0); views = c.v(.views, [])
        wallColor = c.v(.wallColor, "#ECE8E1"); floorColor = c.v(.floorColor, "#C49A6C"); created = c.v(.created, 0)
        points = c.v(.points, []); features = c.v(.features, []); thick = c.v(.thick, [:])
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, floorId, name, template, shape, dims, openings, poly, rot, views, wallColor, floorColor, created, points, features, thick
    }
    /// The synthesized form, with thick written only when set (a room without it saves as before).
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(floorId, forKey: .floorId); try c.encode(name, forKey: .name)
        try c.encode(template, forKey: .template); try c.encode(shape, forKey: .shape); try c.encode(dims, forKey: .dims)
        try c.encode(openings, forKey: .openings); try c.encodeIfPresent(poly, forKey: .poly); try c.encode(rot, forKey: .rot)
        try c.encode(views, forKey: .views); try c.encode(wallColor, forKey: .wallColor); try c.encode(floorColor, forKey: .floorColor)
        try c.encode(created, forKey: .created); try c.encode(points, forKey: .points); try c.encode(features, forKey: .features)
        if !thick.isEmpty { try c.encode(thick, forKey: .thick) }
    }
}

/// A column against a wall or a niche into it (room editor "Ustun / nisha"; Android data/Model.kt Feature): type column
/// or niche; off from the wall's start corner to its near edge; w along the wall; d into the room (column) or into the
/// wall (niche); a niche's sill from the floor and h height (0: up to the ceiling). Columns are full height.
struct Feature: Codable, Equatable, Identifiable {
    var id: String, type: String, wall: String
    var off: Int, w: Int, d: Int
    var sill = 0, h = 0
    init(id: String, type: String, wall: String, off: Int, w: Int, d: Int, sill: Int = 0, h: Int = 0) {
        self.id = id; self.type = type; self.wall = wall; self.off = off; self.w = w; self.d = d; self.sill = sill; self.h = h
    }
    init(from dec: Decoder) throws {
        let c = try dec.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); type = c.v(.type, "column"); wall = c.v(.wall, "A")
        off = c.v(.off, 0); w = c.v(.w, 400); d = c.v(.d, 300); sill = c.v(.sill, 0); h = c.v(.h, 0)
    }
}

/// Something on a wall the furniture must keep clear of: t socket, switch, cold, hot, sewer, gas or meter. off from
/// the wall's start corner and h from the floor, both to its centre, mm. d a pipe's diameter or the meter's width,
/// mh the meter's height; src "manual" or "sim" (the laser).
struct SitePoint: Codable, Equatable, Identifiable {
    var id: String
    var t: String
    var wall: String
    var off: Int
    var h: Int
    var d = 0
    var mh = 0
    var src = "manual"
    /// The style (room-editor mockup v2, Rooms/ReCatalog.swift RE_STYLES: a socket's one, two, three, usb or power…);
    /// "" the kind's first one. The kinds now also include boiler, rad, ac, vent and panel.
    var style = ""
    /// A radiator's or an air conditioner's width, mm (0: not given).
    var pw = 0
    init(id: String, t: String, wall: String, off: Int, h: Int, d: Int = 0, mh: Int = 0, src: String = "manual", style: String = "", pw: Int = 0) {
        self.id = id; self.t = t; self.wall = wall; self.off = off; self.h = h; self.d = d; self.mh = mh; self.src = src
        self.style = style; self.pw = pw
    }
    init(from dd: Decoder) throws {
        let c = try dd.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); t = c.v(.t, "socket"); wall = c.v(.wall, "A"); off = c.v(.off, 0); h = c.v(.h, 0)
        d = c.v(.d, 0); mh = c.v(.mh, 0); src = c.v(.src, "manual"); style = c.v(.style, ""); pw = c.v(.pw, 0)
    }
    // spelled out: with both init(from:) and encode(to:) written by hand Swift makes no CodingKeys
    enum CodingKeys: String, CodingKey { case id, t, wall, off, h, d, mh, src, style, pw }
    /// style and pw are written only when set, so an older point saves as before (Android EncodeDefault.NEVER).
    func encode(to e: Encoder) throws {
        var c = e.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id); try c.encode(t, forKey: .t); try c.encode(wall, forKey: .wall); try c.encode(off, forKey: .off)
        try c.encode(h, forKey: .h); try c.encode(d, forKey: .d); try c.encode(mh, forKey: .mh); try c.encode(src, forKey: .src)
        if !style.isEmpty { try c.encode(style, forKey: .style) }
        if pw != 0 { try c.encode(pw, forKey: .pw) }
    }
}

struct Estimate: Codable, Equatable {
    var materials: [Row] = []
    var labor: [Row] = []
    init(materials: [Row] = [], labor: [Row] = []) { self.materials = materials; self.labor = labor }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        materials = c.v(.materials, []); labor = c.v(.labor, [])
    }
}

struct Row: Codable, Equatable, Identifiable {
    var id: String
    var name = "", unit = "", qty = "", price = "", amount = ""
    init(id: String, name: String = "", unit: String = "", qty: String = "", price: String = "", amount: String = "") {
        self.id = id; self.name = name; self.unit = unit; self.qty = qty; self.price = price; self.amount = amount
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); name = c.v(.name, ""); unit = c.v(.unit, ""); qty = c.v(.qty, "")
        price = c.v(.price, ""); amount = c.v(.amount, "")
    }
}

/// An issued quote: the report as it was, frozen (prototype p.quotes[]). total is the grand total in the smallest unit, as text.
struct Quote: Codable, Equatable { var no: Int; var ts: Ms; var sn: Snap; var fp: String; var total: String }

/// What the PDF shows that the builder can switch off (prototype S.settings.pdf).
struct PdfParts: Codable, Equatable {
    var plan = true, dims = true, views = true, estimate = true, sign = true
    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        plan = c.v(.plan, true); dims = c.v(.dims, true); views = c.v(.views, true); estimate = c.v(.estimate, true); sign = c.v(.sign, true)
    }
}

/// A room as it goes into the report: its 3D views already filtered, and its workspace's name in the report language.
struct SnapRoom: Codable, Equatable { var room: Room; var floorLabel: String }

/// A drawing, photo or note from a workspace, chosen for the report (prototype sn.extras).
struct SnapExtra: Codable, Equatable {
    var id: String, kind: String, name: String, ws: String
    var text = ""
    var checks: [Check] = []
    var edited: Ms = 0
    var els: [MkEl] = []
    var src: String? = nil
    var W = 1000, H = 0
    var caption = ""
}

/// Everything the report pages are drawn from (prototype snapshotOf). A draft builds one each time; a quote keeps its own.
struct Snap: Codable, Equatable {
    var name: String
    var customer = "", phone = "", address = ""
    var location: Location? = nil
    var currency = "UZS"
    var precision = 0
    var unit = "m", lang = "uz", notes = ""
    var builderName = "", builderPhone = ""
    var pdf = PdfParts()
    var rooms: [SnapRoom] = []
    var estimate = Estimate()
    var extras: [SnapExtra] = []
    /// Furniture orders: the furniture, the materials it uses (names and colours), the price lines and terms.
    var furniture: [Furniture] = []
    var fmats: [Mat] = []
    var flines: [SnapLine] = []
    var ftotal = ""
    var fprepay = 50, fdays = 0, finst = 0
    var fhandles = ""
    var fws: Workshop? = nil
    /// The angle snap the plans and areas are worked out with (AppSettings.angleSnap), kept with a quote.
    var snap = true
    /// What the plans show in a room's middle (AppSettings.roomLabel), kept with a quote: "both", "name", "area" or "none".
    var roomLabel = "both"
    /// Electricians' orders: the devices, panel and rooms' settings (each room's kind filled in), for the wiring pages.
    var elec: ElecOrder? = nil
    /// Plumbers' orders: the fixtures, outlets, riser and rooms' settings (each room's kind filled in), for the plumbing pages.
    var plumb: PlumbOrder? = nil
    /// Windows-and-doors orders: the products, for the drawings; winPrice each product's price (the advanced app's, else empty).
    var win: WinOrder? = nil
    var winPrice: [String: Int64] = [:]
    /// The order's trade ("build", "tiler", "elec", "plumb", "win"; "" an older quote): the maker's word and the notes in the PDF.
    var industry = ""
    /// Rooms left out of the report: a trade's circuits, pipes and windows are still worked out with them, but not drawn.
    var calcRooms: [SnapRoom] = []
    /// Tilers' orders: the tile layouts and each room's tray, bath and waterproofing, for the layout drawings.
    var tiles: [TileLayout]? = nil
    var troom: [TileRoom] = []
}

extension Snap {
    // quotes issued before furniture orders load with the furniture fields empty
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        name = c.v(.name, ""); customer = c.v(.customer, ""); phone = c.v(.phone, ""); address = c.v(.address, ""); location = c.v(.location, nil)
        currency = c.v(.currency, "UZS"); precision = c.v(.precision, 0); unit = c.v(.unit, "m"); lang = c.v(.lang, "uz"); notes = c.v(.notes, "")
        builderName = c.v(.builderName, ""); builderPhone = c.v(.builderPhone, ""); pdf = c.v(.pdf, PdfParts()); rooms = c.v(.rooms, [])
        estimate = c.v(.estimate, Estimate()); extras = c.v(.extras, [])
        furniture = c.v(.furniture, []); fmats = c.v(.fmats, []); flines = c.v(.flines, []); ftotal = c.v(.ftotal, "")
        fprepay = c.v(.fprepay, 50); fdays = c.v(.fdays, 0); finst = c.v(.finst, 0); fhandles = c.v(.fhandles, ""); fws = c.v(.fws, nil)
        snap = c.v(.snap, true); roomLabel = c.v(.roomLabel, "both"); elec = c.v(.elec, nil); plumb = c.v(.plumb, nil)
        win = c.v(.win, nil); winPrice = c.v(.winPrice, [:])
        industry = c.v(.industry, ""); calcRooms = c.v(.calcRooms, []); tiles = c.v(.tiles, nil); troom = c.v(.troom, [])
    }
}

/// A line of a furniture order's price in the customer's PDF: key a furniture id or "deliver".
struct SnapLine: Codable, Equatable { var key: String; var amount: String }

/// A reading on the Measure page: src "laser" (the real ZB-08), "sim" (the simulator) or "manual"; used says where it went (a wall or the height).
struct Reading: Codable, Equatable, Identifiable { var id: String; var n: Int; var mm: Int; var ts: Ms; var src: String; var used: String? = nil }

/// Short random ids like the prototype's uid().
func uid() -> String {
    let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    return String((0..<9).map { _ in chars.randomElement()! })
}
