import Foundation

/*
 * How a surface looks in the lit 3D ("modern furniture 3D" part 1, 25 Oct 2026; the approved mockup's mats()): one
 * description per material, read by the renderer (Three/Scene3D.swift) as a PhysicallyBasedMaterial. Plain data, no
 * RealityKit, so the builders and the tests use it too. The plain (unlit) picture and the 2D drawings keep using the
 * colour `flatRgb`.
 */

struct Look: Hashable {
    /// The base colour (sRGB 0xRRGGBB): the tint when there is no texture or its file is missing.
    var rgb: Int
    /// 0 a mirror-smooth surface, 1 fully matte.
    var roughness: Double = 0.7
    /// 0 a board, plastic or stone; 1 bare metal.
    var metallic: Double = 0
    /// A clear lacquer over the surface (gloss acrylic, a polished worktop): its strength and how smooth it is.
    var clearcoat: Double = 0
    var clearcoatRoughness: Double = 0.03
    /// A picture under tex/ (oak_light, walnut, marble_white…): its id without size or extension; nil a plain colour.
    var tex: String? = nil
    /// The colour the picture is multiplied by (white keeps its own colours).
    var texTint: Int = 0xFFFFFF
    /// Metres covered by one repeat of the picture along the grain (u) and across it (v; nil the same).
    var uvScale: Double = 1
    var uvScaleV: Double? = nil
    /// The picture's grain runs up it rather than across it: u and v swap.
    var texRot: Bool = false
    /// Light given off (an LED strip): its strength (0 none) and colour (nil the base colour).
    var emissive: Double = 0
    var emissiveRgb: Int? = nil
    /// 1 solid; less is see-through (glass).
    var alpha: Double = 1
    /// The colour of the plain picture (unlit fallback, 2D drawings); nil the base colour.
    var flat: Int? = nil

    var flatRgb: Int { flat ?? rgb }
    var glows: Bool { emissive > 0 }

    /* ---------------- the kinds of surface (values from the mockup) ---------------- */

    /// A matte board or painted surface.
    static func matte(_ rgb: Int, _ r: Double = 0.8) -> Look { Look(rgb: rgb, roughness: r) }
    /// Half gloss (a laminated wall panel, a satin front).
    static func satin(_ rgb: Int) -> Look { Look(rgb: rgb, roughness: 0.42, clearcoat: 0.3, clearcoatRoughness: 0.2) }
    /// High-gloss acrylic: a smooth surface under a clear coat.
    static func gloss(_ rgb: Int) -> Look { Look(rgb: rgb, roughness: 0.06, clearcoat: 1, clearcoatRoughness: 0.015) }
    /// Metal: steel, chrome (r about 0.05), brushed (0.3), gold.
    static func metal(_ rgb: Int, _ r: Double = 0.24) -> Look { Look(rgb: rgb, roughness: r, metallic: 1) }
    /// A wood decor with its grain picture, one repeat per 1.2 m.
    static func wood(_ rgb: Int, _ tex: String?, _ r: Double = 0.6) -> Look { Look(rgb: rgb, roughness: r, tex: tex, uvScale: 1.2) }
    /// Stone or a stone-look worktop: polished under a light coat; a slab picture 3.2 × 1.6 m.
    static func stone(_ rgb: Int, _ tex: String? = nil, dark: Bool = false) -> Look {
        Look(rgb: rgb, roughness: dark ? 0.2 : 0.17, clearcoat: 0.6, clearcoatRoughness: 0.1, tex: tex, uvScale: 3.2, uvScaleV: 1.6)
    }
    /// Cloth (a mattress, upholstery): matte, its weave repeating every 35 cm and tinted by the cloth's colour.
    static func fabric(_ rgb: Int, _ tex: String? = "fabric") -> Look { Look(rgb: rgb, roughness: 0.93, tex: tex, texTint: rgb, uvScale: 0.35) }
    /// Glass: clear (alpha about 0.2, r 0.02) or frosted (alpha about 0.55, r 0.3).
    static func glass(_ rgb: Int, _ alpha: Double, _ r: Double = 0.02) -> Look { Look(rgb: rgb, roughness: r, clearcoat: r < 0.1 ? 1 : 0, alpha: alpha) }
    /// A silver mirror.
    static func mirror(_ rgb: Int) -> Look { Look(rgb: rgb, roughness: 0.04, metallic: 1) }
    /// An LED strip, glowing.
    static func led(_ rgb: Int, _ glow: Int, _ strength: Double = 1.6) -> Look { Look(rgb: rgb, roughness: 0.35, emissive: strength, emissiveRgb: glow) }

    /// A board of the workshop's list: its decor picture when it has one (wood, or stone for a stone decor), else a plain
    /// colour in its finish ("matte", "satin", "gloss").
    static func board(_ rgb: Int, _ tex: String?, finish: String = "matte", r: Double = 0.8) -> Look {
        if let t = tex, !t.isEmpty { return texIsStone(t) ? stone(rgb, t, dark: lum(rgb) < 0.3) : wood(rgb, t, finish == "gloss" ? 0.35 : 0.6) }
        switch finish {
        case "gloss": return gloss(rgb)
        case "satin": return satin(rgb)
        default: return matte(rgb, r)
        }
    }

    /// The look on a weak phone (mockup "low"): no clear coat, metal and mirrors duller, nothing glossier than 0.28 (a
    /// gloss without reflections to show reads as plastic).
    func lowered() -> Look {
        var l = self
        l.clearcoat = 0
        if l.metallic > 0.5 { l.metallic = 0.35; l.roughness = max(0.32, l.roughness) }
        else if l.alpha >= 1 { l.roughness = max(0.28, l.roughness) }
        return l
    }
}

/// A stone (or stone-look) picture rather than wood.
/// (Brightness: lum in Tiles/Mesh.swift.)
func texIsStone(_ id: String) -> Bool { ["marble", "onyx", "stone", "granite", "quartz", "terrazzo"].contains { id.hasPrefix($0) } }

/* ---------------- the furniture's materials ---------------- */

private let LK_METAL = 0xC5CBD4
private let LK_DARK = 0x1E293B
private let LK_HANDLE = 0x4B5563
private let LK_WHITE = 0xE8EAEE
private let LK_MIRROR = 0xC9D3DD
private let LK_GLASS = 0x8FA9C4
private let LK_CLEAR = 0xBFD8E8
private let LK_MATTRESS = 0xF1F3F6
private let LK_LAMEL = 0xD9C29A
private let LK_LED = 0xFFF3C4
/// A part lit up from the parts list.
let LK_HI = 0xF59E0B

/// What the furniture builder (Geo/Furniture3D.swift) draws each of its material keys in. rgb and tex give a workshop
/// board's colour and decor picture by its id (Mat.rgb, Mat.tex). The keys: carcass, front, back (the piece's boards),
/// top (worktop wt38), splash (splash6), metal, handle, mirror, glass (a sliding door's frosted panel), clear (a
/// vitrina's glass), led, mattress, lamel, dark (black glass of a hob or oven), white (fridge, basin), hi.
func furnLooks(_ m: FMats, _ rgb: (String) -> Int, _ tex: (String) -> String?) -> [String: Look] {
    let ids = [m.carcass, m.front, m.back, "wt38", "splash6"]
    let c = ids.map { rgb($0) }, t = ids.map { tex($0) }
    let carcass = lookFlat(Look.board(c[0], t[0], r: 0.7), c[0]), front = lookFlat(Look.board(c[1], t[1], r: 0.8), c[1])
    let back = lookFlat(Look.board(c[2], t[2], r: 0.85), c[2])
    let top = lookFlat(t[3] == nil ? Look(rgb: c[3], roughness: 0.28, clearcoat: 0.5, clearcoatRoughness: 0.12) : Look.board(c[3], t[3]), c[3])
    let splash = lookFlat(t[4] == nil ? Look.satin(c[4]) : Look.board(c[4], t[4]), c[4])
    return [
        "carcass": carcass, "front": front, "back": back, "top": top, "splash": splash,
        "metal": lookFlat(.metal(0xCDD0D4, 0.24), LK_METAL),
        "handle": lookFlat(Look(rgb: 0x3A3F47, roughness: 0.42, metallic: 0.55), LK_HANDLE),
        "mirror": lookFlat(.mirror(LK_MIRROR), LK_MIRROR),
        "glass": lookFlat(.glass(0xEAF2F0, 0.55, 0.3), LK_GLASS),
        "clear": lookFlat(.glass(0xF2F7F6, 0.22), LK_CLEAR),
        "led": lookFlat(.led(LK_LED, 0xFFD39A), LK_LED),
        "mattress": lookFlat(.fabric(LK_MATTRESS), LK_MATTRESS),
        "lamel": lookFlat(.wood(LK_LAMEL, "oak_light"), LK_LAMEL),
        "dark": lookFlat(Look(rgb: 0x15171B, roughness: 0.05, clearcoat: 1, clearcoatRoughness: 0.02), LK_DARK),
        "white": lookFlat(Look(rgb: 0xF4F3F0, roughness: 0.18, clearcoat: 1), LK_WHITE),
        "hi": Look(rgb: LK_HI, roughness: 0.5, emissive: 0.25)
    ]
}

/// look drawn in the plain picture (and the 2D drawings) in colour flat.
func lookFlat(_ look: Look, _ flat: Int) -> Look { var l = look; l.flat = flat; return l }

/// The look of a part that has none of its own (walls, floors, openings, a trade's pieces): its colour, matte walls,
/// a floor a little smoother, see-through glass.
func roleLook(_ role: Role3, _ rgb: Int, _ op: Double, tile: Bool) -> Look {
    // a trade's pieces (tiles, devices, pipes): half gloss, wherever they are
    if tile { return Look(rgb: rgb, roughness: 0.35, clearcoat: 0.3, clearcoatRoughness: 0.2, alpha: op) }
    switch role {
    case .wall: return Look(rgb: rgb, roughness: 0.92, alpha: op)
    case .floor: return Look(rgb: rgb, roughness: 0.6, alpha: op)
    case .glass: return Look(rgb: rgb, roughness: 0.05, clearcoat: 1, alpha: op)
    case .opening: return Look(rgb: rgb, roughness: 0.5, alpha: op)
    case .furn: return Look(rgb: rgb, roughness: 0.6, alpha: op)
    }
}

/* ---------------- texture coordinates ---------------- */

/// The directions on a face with normal n along which its picture runs: u along grain (the board's long side, lying in
/// the face) and v across it, so that u, v and n turn the right way (the picture is not mirrored seen from outside). A
/// face without a grain: a level face along x, an upright one along the horizontal.
func uvAxes(_ n: V3, _ grain: V3?) -> (V3, V3) {
    var u = V3(0, 0, 0)
    if let g = grain {
        let gp = g - n * g.dot(n)
        if gp.len > 1e-6 && gp.len > 0.5 * g.len { u = gp.unit }
    }
    if u.len < 0.5 {
        if abs(n.y) > 0.7 { u = (V3(1, 0, 0) - n * n.x).unit } else { u = V3(0, 1, 0).cross(n).unit }
    }
    return (u, n.cross(u).unit)
}

/// The texture coordinates of a face's corners for look: metres along the grain and across it divided by the look's
/// repeat (the picture's grain along u unless texRot). Measured from the scene's origin, so boards side by side carry on
/// the same grain.
func faceUVs(_ f: Face3, _ look: Look) -> [SIMD2<Double>] {
    let (u, v) = uvAxes(f.n, f.grain)
    let su = max(1e-6, look.uvScale), sv = max(1e-6, look.uvScaleV ?? look.uvScale)
    return f.pts.map { p in
        let a = p.dot(u), b = p.dot(v)
        return look.texRot ? SIMD2(b / sv, a / su) : SIMD2(a / su, b / sv)
    }
}

/// The grain of each face of a box with edges a, b, c, as the faces are made (a×b twice, c×b twice, a×c twice): the box's
/// longest edge where it lies in the face, else the face's longer edge (an end of a board).
func boxGrains(_ a: V3, _ b: V3, _ c: V3) -> [V3] {
    let la = a.len, lb = b.len, lc = c.len
    let long = la >= lb && la >= lc ? a : lb >= lc ? b : c
    func g(_ e1: V3, _ e2: V3) -> V3 {
        if e1 == long || e2 == long { return long.unit }
        return (e1.len >= e2.len ? e1 : e2).unit
    }
    let ab = g(a, b), cb = g(c, b), ac = g(a, c)
    return [ab, ab, cb, cb, ac, ac]
}
