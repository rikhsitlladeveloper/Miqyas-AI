import Foundation

/*
 * The gorka's and the big dining table's 3D in the lit style (modern 3D part 6a; the approved mockup's buildGorka;
 * Android geo/Gorka3D.kt): what Furniture3D.swift draws over a gorka's boxes (LED strips up its glass towers, under the
 * floating base and the bridge; dishes on the glass shelves; the neoclassic cornice), and the TV panel and the big table
 * drawn here whole (the panel's stone slab, wood slats or mouldings with a black-glass TV and its faintly lit screen;
 * the table's stone-look or wood top, its legs, the upholstered chairs in the look's fabric, a bowl, a vase and a
 * linear pendant). The towers themselves (glass doors in their frames, glass shelves) are the wardrobe engine's, as on
 * every iPhone wardrobe (Geo/Wardrobe3D.swift). Each box is in its wall's frame, mm; equal looks become one part. The
 * small decor (dishes, books, vases, the pendant) is left out on a weak phone (decor false). Plain Swift, unit-tested
 * (GorkaScene3DTests).
 */

/// A box of these: a0…a1 along the wall, y0…y1 up, n0…n1 out from it, mm. Drawn in look (its own), else in the
/// piece's look of key (Geo/Look.swift pieceLooks: "led", "bglass", "top", "accent", "legs", "handle", "frontUp"), else
/// in the piece's board of role (carcass or front; part its name in the parts list, lit up from there). line its
/// outline; turned rotN degrees in the wall's plane (an upright plate) or rotY about the upright (a bowl) round its middle.
struct GuestBox {
    let a0: Double, a1: Double, y0: Double, y1: Double, n0: Double, n1: Double
    var look: Look? = nil
    var key: String? = nil
    var role = "front"
    var part = ""
    var line = false
    var rotN = 0.0
    var rotY = 0.0
    init(_ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double, _ n0: Double, _ n1: Double, look: Look? = nil, key: String? = nil,
         role: String = "front", part: String = "", line: Bool = false, rotN: Double = 0, rotY: Double = 0) {
        self.a0 = a0; self.a1 = a1; self.y0 = y0; self.y1 = y1; self.n0 = n0; self.n1 = n1
        self.look = look; self.key = key; self.role = role; self.part = part; self.line = line; self.rotN = rotN; self.rotY = rotY
    }
}

/// What these add to a module (own false: drawn over its usual boxes) or draw instead of it (own true).
struct GuestScene {
    let own: Bool
    let boxes: [GuestBox]
}

/// The TV's screen: dark, faintly lit.
let GK_TV_SCREEN = lookFlat(Look(rgb: 0x1D2A3E, roughness: 0.08, clearcoat: 1, clearcoatRoughness: 0.02, emissive: 0.45), 0x1D2A3E)
/// Porcelain (dishes, vases).
let GK_PORCELAIN = lookFlat(Look(rgb: 0xF4F2EE, roughness: 0.25, clearcoat: 0.6, clearcoatRoughness: 0.1), 0xF4F2EE)
/// Books on the TV base; the slats' dark backing.
private let GK_BOOKS: [Look] = [Look.matte(0x2E3A52, 0.7), Look.matte(0xD8CDBB, 0.7), Look.matte(0x7A2E2E, 0.7)]
private let GK_SLAT_BACK = Look.matte(0x1B1C1F, 0.8)
/// Walnut, the wood of the slats and the chairs' legs when the piece has no wood accent.
let GK_WALNUT = lookFlat(Look.wood(0x634330, "walnut"), 0x634330)

/// The wood of the slats and of the chairs' board legs: the look's wood accent, walnut without one.
private func gkWood(_ f: Furniture) -> (look: Look?, key: String?) {
    if (f.look?.accent ?? "").isEmpty { return (look: GK_WALNUT, key: nil) }
    return (look: nil, key: "accent")
}

/// The chairs' upholstery in the look's fabric (PieceLook.swift lookOf "fabric"): boucle, a weave or velvet.
func gkFabricLook(_ f: Furniture) -> Look {
    let s = lookOf(f, nil, "fabric")
    let c = rgbOf(s.rgb)
    var l = Look.fabric(c, s.tex ?? "fabric")
    if s.finish == "velvet" { l.roughness = 0.55; l.clearcoat = 0.15; l.clearcoatRoughness = 0.4 }
    // the mockup's sheen over the cloth (Geo/ItemsScene3D.swift itSheen; a weak phone has none)
    l.sheen = itSheen(c, velvet: s.finish == "velvet")
    return lookFlat(l, c)
}

/// The gorka's or the big table's 3D for module m of f (its frame's x already in m); nil for any other.
func guestScene(_ f: Furniture, _ m: Module, _ ws: Workshop, decor: Bool = true) -> GuestScene? {
    if m.type == TV_PANEL { return GuestScene(own: true, boxes: tvPanel(f, m, ws)) }
    if m.type == "table" && (m.opt?.seats ?? 0) > 0 { return GuestScene(own: true, boxes: bigTable(f, m, ws, decor)) }
    if f.type == "gorka" && m.type == "wardrobe" {
        let b = gorkaBox(f, m, ws, decor)
        return b.isEmpty ? nil : GuestScene(own: false, boxes: b)
    }
    return nil
}

/// A board of an item at x0 along the wall: in look or the piece's look of key, else in its role's board.
private func gkBoard(_ b: Board, _ x0: Int, look: Look? = nil, key: String? = nil) -> GuestBox {
    GuestBox(Double(x0 + b.a0), Double(x0 + b.a1), Double(b.y0), Double(b.y1), Double(b.n0), Double(b.n1), look: look, key: key,
             role: b.role == "carcass" ? "carcass" : "front", part: b.key, line: true)
}

/// A disc dd across and th thick as three turned squares: upright in the wall's plane (upright) or lying flat.
private func gkDisc(_ out: inout [GuestBox], _ ca: Double, _ cy: Double, _ cn: Double, _ dd: Double, _ th: Double, _ upright: Bool, _ look: Look) {
    let s = dd * 0.8
    for r in [0.0, 30.0, 60.0] {
        if upright { out.append(GuestBox(ca - s / 2, ca + s / 2, cy - s / 2, cy + s / 2, cn - th / 2, cn + th / 2, look: look, rotN: r)) }
        else { out.append(GuestBox(ca - s / 2, ca + s / 2, cy - th / 2, cy + th / 2, cn - s / 2, cn + s / 2, look: look, rotY: r)) }
    }
}

/// What goes over a gorka's box: its LED strips, the dishes on a tower's shelves, the cornice on a tower or the bridge.
func gorkaBox(_ f: Furniture, _ m: Module, _ ws: Workshop, _ decor: Bool) -> [GuestBox] {
    guard let r = gorkaRoles(f) else { return [] }
    var out: [GuestBox] = []
    let t = Double(ws.t)
    let x0 = Double(m.x), x1 = x0 + Double(m.w)
    let sl = m.sideL ? t : 0, sr = m.sideR ? t : 0
    let led = f.look?.led == true
    let yb = Double(m.elev + wardBase(m)), yt = Double(m.elev + m.h)
    let di = Double(innerD(m))
    let dd = Double(m.d), e = Double(m.elev)
    let tower = r.ups.contains { $0.id == m.id }
    if tower {
        // the light up each side of the glass box, at its front
        if led {
            out.append(GuestBox(x0 + sl + 4, x0 + sl + 12, yb + t, yt - t, di - 40, di - 32, key: "led"))
            out.append(GuestBox(x1 - sr - 12, x1 - sr - 4, yb + t, yt - t, di - 40, di - 32, key: "led"))
        }
        if decor && m.sections.count == 1 { gkDishes(&out, m, x0 + sl, x1 - sr, yb + t, yt - t, t) }
    } else if m.id == r.base?.id {
        if led { out.append(GuestBox(x0 + 40, x1 - 40, e - 6, e, dd - 60, dd - 48, key: "led")) }
        // a vase and a few books on the base
        if decor && m.w >= 900 {
            out.append(GuestBox(x0 + 250, x0 + 350, yt, yt + 220, dd / 2 - 50, dd / 2 + 50, look: GK_PORCELAIN))
            for (i, b) in GK_BOOKS.enumerated() {
                let k = Double(i)
                out.append(GuestBox(x1 - 420 + k * 30, x1 - 394 + k * 30, yt, yt + 200 + k * 15, dd / 2 - 80, dd / 2 + 80, look: b))
            }
        }
    } else if m.id == r.bridge?.id {
        if led { out.append(GuestBox(x0 + 30, x1 - 30, e - 7, e, dd - 60, dd - 48, key: "led")) }
    }
    // the neoclassic cornice: three stepped mouldings over each tower and the bridge, in the upper fronts' board (as an
    // iPhone wardrobe's cornice, Geo/Wardrobe3D.swift crownOver)
    if f.look?.crown == "cornice" && (tower || m.id == r.bridge?.id) {
        out.append(GuestBox(x0 - 5, x1 + 5, yt, yt + 22, 0, dd + 10, key: "frontUp", line: true))
        out.append(GuestBox(x0 - 15, x1 + 15, yt + 22, yt + 58, 0, dd + 26, key: "frontUp", line: true))
        out.append(GuestBox(x0 - 25, x1 + 25, yt + 58, yt + 76, 0, dd + 38, key: "frontUp", line: true))
    }
    return out
}

/// Dishes on a tower's floor and shelves (a0…a1 inside, y0…y1 its floor to its top): plates and cups, bowls and a teapot, a vase on top.
private func gkDishes(_ out: inout [GuestBox], _ m: Module, _ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double, _ t: Double) {
    if a1 - a0 < 300 { return }
    let cx = (a0 + a1) / 2
    let boards = m.sections[0].inserts.filter { $0.kind == "glass" || $0.kind == "shelf" }
    let shelves: [Double] = boards.map { (x: Insert) -> Double in y0 + Double(x.pos) + (x.kind == "glass" ? 6.0 : t) }.sorted()
    let levels: [Double] = [y0] + shelves
    for (i, y) in levels.enumerated() {
        let room = (i + 1 < levels.count ? levels[i + 1] : y1) - y
        if room < 160 { continue }
        if i == levels.count - 1 {
            out.append(GuestBox(cx - 55, cx + 55, y, y + min(280, room - 40), 140, 250, look: GK_PORCELAIN))
        } else if i % 2 == 0 {
            // three plates standing at the back, two cups in front of them
            let dd = min(220, room - 30)
            for (dx, k) in [(-120.0, 0.9), (0.0, 1.0), (120.0, 0.9)] { gkDisc(&out, cx + dx, y + dd * k / 2 + 2, 50, dd * k, 8, true, GK_PORCELAIN) }
            for dx in [-100.0, 100.0] { out.append(GuestBox(cx + dx - 35, cx + dx + 35, y, y + 75, 200, 270, look: GK_PORCELAIN)) }
        } else {
            // a stack of two bowls and a teapot
            gkDisc(&out, cx - 100, y + 30, 170, 180, 60, false, GK_PORCELAIN)
            gkDisc(&out, cx - 100, y + 82, 170, 160, 44, false, GK_PORCELAIN)
            if room > 220 { out.append(GuestBox(cx + 30, cx + 160, y, y + 120, 120, 250, look: GK_PORCELAIN)) }
        }
    }
}

/// A kitchen vitrina's glass shelves (Kitchen.swift glassDoors), mm above the floor of the shelf's underside: spaced
/// evenly in the box as its board shelves would be (the 3D's kitchen unit).
func vitrinaShelves(_ m: Module, _ t: Int) -> [Double] {
    let n = m.inserts.filter { $0.kind == "glass" }.reduce(0) { $0 + $1.qty }
    guard n > 0 else { return [] }
    return (1...n).map { k in Double(m.elev) + Double(m.h - t) * Double(k) / Double(n + 1) }
}

/// The dishes in a kitchen vitrina (mockup buildKitchen): plates standing at the back of its floor (up to three, 170 mm
/// apart) and cups on its first glass shelf (up to four, 130 mm apart), each where there is room. The light tier has none.
func vitrinaDishes(_ m: Module, _ t: Int) -> [GuestBox] {
    var out: [GuestBox] = []
    let il = Double(m.x + t), iw = Double(m.w - 2 * t)
    if iw < 250 { return out }
    let cx = il + iw / 2
    let floor = Double(m.elev + t), top = Double(m.elev + m.h - t)
    let ys = vitrinaShelves(m, t)
    let room = (ys.first ?? top) - floor
    if room >= 160 {
        let dd = min(200, room - 40), np = min(3, max(1, Int((iw - 40) / 170)))
        for i in 0..<np { gkDisc(&out, cx + (Double(i) - Double(np - 1) / 2) * 170, floor + dd / 2 + 2, 50, dd, 8, true, GK_PORCELAIN) }
    }
    if let y = ys.first {
        let ys0 = y + 6, up = (ys.count > 1 ? ys[1] : top) - ys0
        if up >= 110 {
            let nc = min(4, max(1, Int((iw - 40) / 130)))
            for i in 0..<nc {
                let c = cx + (Double(i) - Double(nc - 1) / 2) * 130
                out.append(GuestBox(c - 35, c + 35, ys0, ys0 + 75, 115, 185, look: GK_PORCELAIN))
            }
        }
    }
    return out
}

/// The TV panel: its board, the facing over it (stone, slats or mouldings), the TV.
func tvPanel(_ f: Furniture, _ m: Module, _ ws: Workshop) -> [GuestBox] {
    var out: [GuestBox] = []
    let t = Double(ws.t)
    let o = m.opt ?? ItemOpt()
    for b in itemBoards(m, ws) { out.append(gkBoard(b, m.x)) }
    let x0 = Double(m.x), x1 = x0 + Double(m.w), e = Double(m.elev), top = e + Double(m.h)
    let fc = Double(GK_FACING)
    switch o.panel {
    case "slats":
        // wood slats about 45 mm apart over a dark backing (the accent wood; walnut without one)
        let wood = gkWood(f)
        out.append(GuestBox(x0, x1, e, top, t, t + 4, look: GK_SLAT_BACK))
        let n = max(1, Int((Double(m.w) / 45).rounded()))
        let s = Double(m.w) / Double(n)
        for i in 0..<n {
            out.append(GuestBox(x0 + Double(i) * s + 6, x0 + Double(i + 1) * s - 6, e, top, t, t + fc, look: wood.look, key: wood.key))
        }
    case "mould":
        // a moulded frame set in from the panel's edges, in the fronts' board
        let i = 60.0, b = 40.0, d = t + 14
        out.append(GuestBox(x0 + i, x1 - i, top - i - b, top - i, t, d, part: "gk.panel", line: true))
        out.append(GuestBox(x0 + i, x1 - i, e + i, e + i + b, t, d, part: "gk.panel", line: true))
        out.append(GuestBox(x0 + i, x0 + i + b, e + i + b, top - i - b, t, d, part: "gk.panel", line: true))
        out.append(GuestBox(x1 - i - b, x1 - i, e + i + b, top - i - b, t, d, part: "gk.panel", line: true))
    default:
        // a slab in the worktop's stone look
        out.append(GuestBox(x0, x1, e, top, t, t + fc - 2, key: "top", line: true))
    }
    // the TV on the panel, no wider than it less 40 mm, its middle about 1210 from the floor
    let (tw0, th0) = tvSize(o.tv > 0 ? o.tv : 65)
    let k = min(1.0, (Double(m.w) - 40) / Double(tw0))
    let tw = Double(tw0) * k, th = Double(th0) * k
    let cx = (x0 + x1) / 2
    let cy = min(e + min(Double(m.h), 1160) / 2 + 10, top - th / 2 - 20)
    let n0 = t + fc
    out.append(GuestBox(cx - tw / 2 - 10, cx + tw / 2 + 10, cy - th / 2 - 10, cy + th / 2 + 10, n0, n0 + 28, key: "bglass"))
    out.append(GuestBox(cx - tw / 2, cx + tw / 2, cy - th / 2, cy + th / 2, n0 + 28, n0 + 29.5, look: GK_TV_SCREEN))
    return out
}

/// The big table: its top in the stone or wood look, its legs, the chairs round it; with decor a bowl, a vase and the pendant over it.
func bigTable(_ f: Furniture, _ m: Module, _ ws: Workshop, _ decor: Bool) -> [GuestBox] {
    var out: [GuestBox] = []
    for b in itemBoards(m, ws) {
        switch b.role {
        case "top": out.append(gkBoard(b, m.x, key: "top"))
        case "metal": out.append(gkBoard(b, m.x, key: "legs"))
        default: out.append(gkBoard(b, m.x))
        }
    }
    let x0 = Double(m.x), H = Double(m.h), D = Double(m.d)
    let fabric = gkFabricLook(f)
    // the chairs' legs: metal with metal table legs, else the wood accent (walnut without one)
    let wood = gkWood(f)
    var legs: (look: Look?, key: String?) = (look: nil, key: "legs")
    if m.opt?.legs == "board" { legs = wood }
    for c in chairPlaces(m) { gkChair(&out, x0 + Double(c.a), Double(c.n), c.face, fabric, legs) }
    if decor {
        let cx = x0 + Double(m.w) / 2, cn = D / 2
        gkDisc(&out, cx - 200, H + 40, cn, 280, 80, false, GK_PORCELAIN)
        out.append(GuestBox(cx + 300, cx + 400, H, H + 300, cn - 50, cn + 50, look: GK_PORCELAIN))
        // a linear pendant 900 over the top, on two short wires (the room has no ceiling to hang them from, and a
        // gallery card fits its picture round every box)
        out.append(GuestBox(cx - 800, cx + 800, H + 900, H + 932, cn - 30, cn + 30, key: "handle", line: true))
        out.append(GuestBox(cx - 780, cx + 780, H + 896, H + 900, cn - 20, cn + 20, key: "led"))
        for dx in [-700.0, 700.0] { out.append(GuestBox(cx + dx - 1.5, cx + dx + 1.5, H + 932, H + 1250, cn - 1.5, cn + 1.5, key: "bglass")) }
    }
    return out
}

/// An upholstered chair with its middle ca, cn looking face (+n, -n, +a, -a): its seat, back and four legs.
private func gkChair(_ out: inout [GuestBox], _ ca: Double, _ cn: Double, _ face: String, _ fabric: Look, _ legs: (look: Look?, key: String?)) {
    let h = 220.0
    out.append(GuestBox(ca - h, ca + h, 420, 495, cn - h, cn + h, look: fabric))
    for da in [-180.0, 180.0] {
        for dn in [-180.0, 180.0] { out.append(GuestBox(ca + da - 11, ca + da + 11, 0, 420, cn + dn - 11, cn + dn + 11, look: legs.look, key: legs.key)) }
    }
    switch face {
    case "+n": out.append(GuestBox(ca - 210, ca + 210, 495, 980, cn - h, cn - h + 55, look: fabric))
    case "-n": out.append(GuestBox(ca - 210, ca + 210, 495, 980, cn + h - 55, cn + h, look: fabric))
    case "+a": out.append(GuestBox(ca - h, ca - h + 55, 495, 980, cn - 210, cn + 210, look: fabric))
    default: out.append(GuestBox(ca + h - 55, ca + h, 495, 980, cn - 210, cn + 210, look: fabric))
    }
}

/* ---------------- drawing them ---------------- */

extension FBuilder {
    /// The part of a look of its own (one for each wall and look, as p's): see-through when the look is.
    func lookPart(_ l: Look) -> Part3 {
        let w = wall == ISLAND ? nil : wall
        let key = FStore.K(wall: w, look: l)
        if let x = st.parts[key] { return x }
        let x = Part3(0, w, .furn, l.flatRgb, l.alpha < 1 ? 0.38 : 1, look: l)
        st.parts[key] = x; st.order.append(key)
        return x
    }

    /// The boxes of Geo/GorkaScene3D.swift on wall frame w.
    func guestBoxes(_ w: WallBasis, _ xs: [GuestBox]) { for x in xs { guestBox(w, x) } }

    /// A box of Geo/GorkaScene3D.swift: in its own look, the piece's look of its key or its role's board; turned round its middle.
    func guestBox(_ w: WallBasis, _ x: GuestBox) {
        let part: Part3
        if let l = x.look { part = lookPart(l) } else if let k = x.key { part = p(k) } else { part = role(x.role, x.part) }
        if x.rotN == 0 && x.rotY == 0 { box(w, part, x.a0, x.a1, x.y0, x.y1, x.n0, x.n1, x.line); return }
        let ax = w.dir(1, 0), nx = w.dir(0, 1), upV = V3(0, 1, 0)
        var a = ax, y = upV, n = nx
        if x.rotN != 0 {
            let r = x.rotN * .pi / 180
            a = ax * cos(r) + upV * sin(r); y = upV * cos(r) - ax * sin(r)
        }
        if x.rotY != 0 {
            let r = x.rotY * .pi / 180
            let a2 = a * cos(r) + nx * sin(r)
            n = nx * cos(r) - a * sin(r); a = a2
        }
        let sa = (x.a1 - x.a0) / 1000, sy = (x.y1 - x.y0) / 1000, sn = (x.n1 - x.n0) / 1000
        guard sa > 1e-4, sy > 1e-4, sn > 1e-4 else { return }
        let c = w.at((x.a0 + x.a1) / 2000, (x.y0 + x.y1) / 2000, (x.n0 + x.n1) / 2000)
        let o: V3 = c - a * (sa / 2) - y * (sy / 2) - n * (sn / 2)
        obb(part, Obb(o: o, a: a * sa, b: y * sy, c: n * sn), x.line)
    }
}
