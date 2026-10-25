import Foundation

/*
 * The rest of the furniture in the modern 3D ("modern furniture 3D" part 6b, 25 Oct 2026; the approved mockup's
 * buildBed, b.front, b.handle): what the item engine (Furniture/Core/Items.swift) builds, in the lit style. A bed's
 * upholstered headboard in the look's fabric (vertical channels, carriage tufting with buttons, square panels), the soft
 * wall panel behind it with its wood cap and LED, real slats (rising with a lift-up base), the mattress, linen, duvet,
 * a runner and pillows as soft rounded boxes, round legs in the handle colour or a hidden black base; a bunk or loft
 * bed's soft rungs, or with the look's metal (PieceLook.legs) a ladder of round tubes in the handle colour; a table's or
 * bar counter's top with a soft edge (round corners when set), its metal legs or frame in
 * the handle colour; a bar's front in the piece's front style and its round foot rail; a hall panel in the front style
 * with its tinted mirror and metal coat hooks; a vanity's white ceramic bowl and its tap in the handle colour. The
 * boards stay where Items.swift puts them, so the cut list and the picture agree. A weak phone (detail .low) skips the
 * bedding's detail, the tufting's puffs and the glow; the 2D drawings (detail .flat) keep boxes only, the wall panel and
 * the hidden base as boxes too (a gallery card fits its picture round them). The gorka and the big table are
 * Geo/GorkaScene3D.swift's. Plain Swift, unit-tested (ItemsScene3DTests). Sizes in millimetres unless a frame's (metres).
 */

/* ---------------- rules (plain, unit-tested) ---------------- */

/// A soft pad of upholstery: a0…a1 along, y0…y1 up, mm.
struct SoftPad: Equatable {
    let a0: Double, a1: Double, y0: Double, y1: Double
}

/// How far a headboard's upholstery stands out of its board, mm.
let HEAD_PAD = 60.0
/// The soft wall panel's thickness, mm (its size by the rule the price uses too: Core/PieceLook.swift bedPanelSpan,
/// PANEL_Y0, PANEL_Y1, PANEL_OUT).
let PANEL_D = 40.0

/// The bedding's cloth (mockup FAB_ALL): white linen, an off-white duvet.
let IT_LINEN = lookFlat(Look.fabric(0xF2EFEA), 0xF2EFEA)
let IT_DUVET = lookFlat(Look.fabric(0xECE7DF), 0xECE7DF)
/// A bed's hidden base: black, matte.
let IT_BASE = lookFlat(Look.matte(0x111215, 0.55), 0x1E293B)
/// A basin's white ceramic: glazed, under a clear coat.
let IT_CERAMIC = lookFlat(Look(rgb: 0xF7F6F3, roughness: 0.12, clearcoat: 1, clearcoatRoughness: 0.04), 0xF4F3F0)

/// rgb mixed with white, k of the way (0…1).
func itMix(_ rgb: Int, _ k: Double) -> Int {
    func c(_ s: Int) -> Int { let v = Double((rgb >> s) & 0xFF); return Int((v + (255 - v) * k).rounded()) }
    return (c(16) << 16) | (c(8) << 8) | c(0)
}

/// The mockup's sheen over cloth of colour rgb: its colour lifted towards white (a velvet's more), weaker on a weave
/// than on velvet (sheen 0.45 and 1 in the mockup: the tint darker).
func itSheen(_ rgb: Int, velvet: Bool) -> Int {
    let s = itMix(rgb, velvet ? 0.5 : 0.3), k = velvet ? 1.0 : 0.45
    func c(_ sh: Int) -> Int { Int((Double((s >> sh) & 0xFF) * k).rounded()) }
    return (c(16) << 16) | (c(8) << 8) | c(0)
}

/// A fabric look a little lighter (the soft wall panel's, the cushions'; mockup fabric2): its colour, tint, flat
/// colour and sheen mixed with white k of the way.
func itLighter(_ l: Look, _ k: Double) -> Look {
    var x = l
    x.rgb = itMix(l.rgb, k); x.texTint = itMix(l.texTint, k)
    if let f = l.flat { x.flat = itMix(f, k) }
    if let s = l.sheen { x.sheen = itMix(s, k * 0.5) }
    return x
}

/// The pads a headboard style lays over a0…a1 × y0…y1 (mockup soft()): "vertical" upright channels about 150 wide (at
/// least three), "panels" squares about 440 × 420, "tufted" one slab (its buttons tuftButtons, its puffs tuftPuffs); ""
/// a plain board: none.
func softPads(_ style: String, _ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double) -> [SoftPad] {
    let w = a1 - a0, h = y1 - y0
    guard w > 40, h > 40 else { return [] }
    switch style {
    case "vertical":
        let n = max(3, Int((w / 150).rounded())), s = w / Double(n)
        return (0..<n).map { i in SoftPad(a0: a0 + Double(i) * s + 2, a1: a0 + Double(i + 1) * s - 2, y0: y0, y1: y1) }
    case "panels":
        let c = max(2, Int((w / 440).rounded())), r = max(1, Int((h / 420).rounded()))
        let cw = w / Double(c), rh = h / Double(r)
        var out: [SoftPad] = []
        for i in 0..<c {
            for j in 0..<r {
                out.append(SoftPad(a0: a0 + Double(i) * cw + 3, a1: a0 + Double(i + 1) * cw - 3, y0: y0 + Double(j) * rh + 3, y1: y0 + Double(j + 1) * rh - 3))
            }
        }
        return out
    case "tufted": return [SoftPad(a0: a0, a1: a1, y0: y0, y1: y1)]
    default: return []
    }
}

/// The step of a tufted headboard's lattice: its buttons every 80 mm across and up, every other one (mockup st / 2).
let TUFT_STEP = 80.0

/// The lattice of a tufted pad a0…a1 × y0…y1: the button rows' places across (xs) and up (ys), 80 apart from 80 in,
/// none closer than 40 to an edge.
private func tuftGrid(_ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double) -> (xs: [Double], ys: [Double]) {
    var xs: [Double] = [], ys: [Double] = []
    var x = a0 + TUFT_STEP
    while x < a1 - 40 { xs.append(x); x += TUFT_STEP }
    var y = y0 + TUFT_STEP
    while y < y1 - 40 { ys.append(y); y += TUFT_STEP }
    return (xs, ys)
}

/// A tufted pad's buttons (mockup): at every other place of its lattice, a diamond pattern; (a, y) mm.
func tuftButtons(_ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double) -> [SoftPad] {
    let g = tuftGrid(a0, a1, y0, y1)
    var out: [SoftPad] = []
    for (i, x) in g.xs.enumerated() { for (j, y) in g.ys.enumerated() where (i + j) % 2 == 0 { out.append(SoftPad(a0: x, a1: x, y0: y, y1: y)) } }
    return out
}

/// A tufted pad's puffs: the diamonds between its buttons, each with a button at its four corners (their middles).
func tuftPuffs(_ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double) -> [SoftPad] {
    let g = tuftGrid(a0, a1, y0, y1)
    guard g.xs.count >= 3, g.ys.count >= 3 else { return [] }
    var out: [SoftPad] = []
    for i in 1..<(g.xs.count - 1) {
        for j in 1..<(g.ys.count - 1) where (i + j) % 2 == 1 { out.append(SoftPad(a0: g.xs[i], a1: g.xs[i], y0: g.ys[j], y1: g.ys[j])) }
    }
    return out
}

/// The soft wall panel behind bed m whose left end is x0 along a wall wallLen long, moved into the room by pose (mm):
/// the price's own rule (Core/PieceLook.swift bedPanelReach, bedPanelSpan; Android Look.kt), in the bed's own frame
/// (its left end at 0); nil where none is drawn.
func softPanelSpan(_ m: Module, _ pose: Pose?, _ x0: Double, _ wallLen: Double) -> SoftPad? {
    guard let r = bedPanelReach(pose, x0, wallLen), let s = bedPanelSpan(m, r.lo, r.hi) else { return nil }
    return SoftPad(a0: s.a0, a1: s.a1, y0: s.y0, y1: s.y1)
}

/// The wall panel's pads behind a headboard of style head (mockup: square panels behind channels, tufting or a plain
/// board, upright channels behind square panels), cut back over the headboard 0…W up to hb: a pad behind it starts 4 mm
/// over it, or goes when less than 60 is left.
func panelPads(_ head: String, _ span: SoftPad, _ W: Double, _ hb: Double) -> [SoftPad] {
    softPads(head == "panels" ? "vertical" : "panels", span.a0, span.a1, span.y0, span.y1).compactMap { p in
        guard p.a1 > 0 && p.a0 < W && p.y0 < hb else { return p }
        let y0 = hb + 4
        return p.y1 - y0 >= 60 ? SoftPad(a0: p.a0, a1: p.a1, y0: y0, y1: p.y1) : nil
    }
}

/// What a bed stands on in the 3D: "legs" round metal legs in the handle colour (a plain bed made before the design,
/// or with PieceLook.legs), "base" a hidden black base set in under its frame (a plain bed with a design: the mockup's
/// floating bed), "box" its sides reach the floor (drawers, a lift-up base) or not a bed.
func bedFoot(_ m: Module, _ look: PieceLook?) -> String {
    guard m.type == "bed", (m.opt ?? ItemOpt()).bed == "legs" else { return "box" }
    guard let l = look else { return "legs" }
    return l.legs ? "legs" : "base"
}

/// A table's or bar counter's top edge, rounded this much (mm): a 38 mm worktop's 6, a board's 3.
func topEdgeR(_ th: Double) -> Double { th >= 30 ? 6 : 3 }

/* ---------------- shapes ---------------- */

/// Points q with the ones next to each other that are the same (within 0.1 µm) left out, first and last too.
private func itClean(_ q: [V3]) -> [V3] {
    var out: [V3] = []
    for p in q {
        if let l = out.last, (l - p).len <= 1e-7 { continue }
        out.append(p)
    }
    if out.count > 1, let f = out.first, let l = out.last, (f - l).len <= 1e-7 { out.removeLast() }
    return out
}

extension FBuilder {
    /// A face of corners q (the repeated ones dropped; nothing left of a face that has shrunk to a line).
    func itFace(_ part: Part3, _ q: [V3], _ inner: V3) {
        let c = itClean(q)
        if c.count >= 3 { face(part, c, inner) }
    }

    /// An item's frame at x0 along wall w (its back's left end), metres: tilted th about the line across it at py up and
    /// pn out (mm; a lift-up base rising, as Furniture3D.swift tilts its boards).
    func itFrame(_ w: WallBasis, _ x0: Int, _ th: Double = 0, _ py: Double = 0, _ pn: Double = 0) -> FFrame {
        let up = V3(0, 1, 0), c = cos(th), s = sin(th)
        let u2: V3 = w.dir(0, -s) + up * c
        let n2: V3 = w.dir(0, c) + up * s
        let pv = w.at(Double(x0) / 1000, py / 1000, pn / 1000)
        return FFrame(o: pv - u2 * (py / 1000) - n2 * (pn / 1000), e: w.dir(1, 0), u: u2, n: n2)
    }

    /// A soft box round its middle c, half sizes hx, hy, hz along the unit axes ax, ay, az (metres), every edge and corner
    /// rounded r (mockup soft boxes): quarter circles of 3 steps (2 on a weak phone). A plain box in the 2D drawings or
    /// when r is next to nothing. No outline.
    func softBox(_ part: Part3, _ c: V3, _ ax: V3, _ ay: V3, _ az: V3, _ hx: Double, _ hy: Double, _ hz: Double, _ r0: Double) {
        guard hx > 1e-5, hy > 1e-5, hz > 1e-5 else { return }
        let r = min(r0, hx, hy, hz)
        if !fancy || r < 0.0005 {
            obb(part, Obb(o: c - ax * hx - ay * hy - az * hz, a: ax * (2 * hx), b: ay * (2 * hy), c: az * (2 * hz)), false)
            return
        }
        let k = detail == .high ? 3 : 2
        let ix = hx - r, iy = hy - r, iz = hz - r
        // round the upright (x, z) in four quarters, each with its own corner of the inner box; bottom up in two halves
        var cols: [(ct: Double, st: Double, sx: Double, sz: Double)] = []
        for q in 0..<4 {
            let sx: Double = q == 0 || q == 3 ? 1 : -1, sz: Double = q < 2 ? 1 : -1
            for j in 0...k { let t = (Double(q) + Double(j) / Double(k)) * .pi / 2; cols.append((cos(t), sin(t), sx, sz)) }
        }
        var rows: [(cp: Double, sp: Double, sy: Double)] = []
        for j in 0...k { let t = -Double.pi / 2 + Double(j) / Double(k) * .pi / 2; rows.append((cos(t), sin(t), -1)) }
        for j in 0...k { let t = Double(j) / Double(k) * .pi / 2; rows.append((cos(t), sin(t), 1)) }
        func pt(_ i: Int, _ j: Int) -> V3 {
            let rw = rows[i], cl = cols[j]
            let px: Double = cl.sx * ix + r * rw.cp * cl.ct
            let py: Double = rw.sy * iy + r * rw.sp
            let pz: Double = cl.sz * iz + r * rw.cp * cl.st
            return c + ax * px + ay * py + az * pz
        }
        let nc = cols.count
        for i in 0..<(rows.count - 1) {
            for j in 0..<nc {
                let j2 = (j + 1) % nc
                itFace(part, [pt(i, j), pt(i, j2), pt(i + 1, j2), pt(i + 1, j)], c)
            }
        }
        // the flat bottom and top between the four corners
        let firsts = (0..<4).map { $0 * (k + 1) }
        itFace(part, firsts.map { pt(0, $0) }, c)
        itFace(part, firsts.map { pt(rows.count - 1, $0) }, c)
    }

    /// A soft box a0…a1 along, y0…y1 up, n0…n1 out of frame f (mm), rounded r mm.
    func softIn(_ part: Part3, _ f: FFrame, _ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double, _ n0: Double, _ n1: Double, _ r: Double) {
        let c = f.at((a0 + a1) / 2000, (y0 + y1) / 2000, (n0 + n1) / 2000)
        softBox(part, c, f.e, f.u, f.n, (a1 - a0) / 2000, (y1 - y0) / 2000, (n1 - n0) / 2000, r / 1000)
    }

    /// A level top a0…a1 along, n0…n1 out of frame f, y0…y1 up (mm): its plan a rectangle with corners rounded R (0
    /// square), its edge rounded e all round (quarter circles of 3 steps, 2 on a weak phone); line: its outline at the
    /// top and bottom of its edge (light on a worktop's slab).
    func softTop(_ part: Part3, _ f: FFrame, _ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double, _ n0: Double, _ n1: Double,
                 _ R0: Double, _ e0: Double, _ line: Bool) {
        let W = a1 - a0, D = n1 - n0, H = y1 - y0
        guard W > 2, D > 2, H > 0.5 else { return }
        let e = max(0, min(e0, H / 2 - 0.05, W / 4, D / 4))
        let R = max(0, min(R0, W / 2 - 0.5, D / 2 - 0.5))
        let k = detail == .high ? 3 : 2
        let m = R > 0 ? (detail == .high && R >= 60 ? 6 : 3) : 0
        // the edge's profile bottom up: how far in, how high
        var prof: [(d: Double, y: Double)] = []
        if e > 0.2 {
            for i in 0...k { let t = -Double.pi / 2 + Double(i) / Double(k) * .pi / 2; prof.append((e - e * cos(t), y0 + e + e * sin(t))) }
            for i in 0...k { let t = Double(i) / Double(k) * .pi / 2; prof.append((e - e * cos(t), y1 - e + e * sin(t))) }
        } else {
            prof = [(0, y0), (0, y1)]
        }
        func ring(_ d: Double, _ y: Double) -> [V3] {
            let rr = max(0, R - d), ins = max(R, d)
            let cs: [(Double, Double, Double)] = [(a0 + ins, n0 + ins, Double.pi), (a1 - ins, n0 + ins, 1.5 * Double.pi),
                                                  (a1 - ins, n1 - ins, 0), (a0 + ins, n1 - ins, 0.5 * Double.pi)]
            var out: [V3] = []
            for (ca, cn, s) in cs {
                for j in 0...m {
                    let t = s + (m == 0 ? 0 : Double(j) / Double(m) * .pi / 2)
                    out.append(f.at((ca + rr * cos(t)) / 1000, y / 1000, (cn + rr * sin(t)) / 1000))
                }
            }
            return out
        }
        let rings = prof.map { ring($0.d, $0.y) }
        let inner = f.at((a0 + a1) / 2000, (y0 + y1) / 2000, (n0 + n1) / 2000)
        let np = rings[0].count
        for i in 0..<(rings.count - 1) {
            for j in 0..<np {
                let j2 = (j + 1) % np
                itFace(part, [rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]], inner)
            }
        }
        itFace(part, rings[0], inner)
        itFace(part, rings[rings.count - 1], inner)
        guard line else { return }
        let ed = part.slab ? slabEdges : edges
        // the rings at full size: where the soft edge meets its upright band (the top and bottom of a square edge)
        for (i, pr) in prof.enumerated() where pr.d < 1e-6 {
            let rg = itClean(rings[i])
            for j in 0..<rg.count { ed.segs.append(rg[j]); ed.segs.append(rg[(j + 1) % rg.count]) }
        }
    }

    /// The part an item's board of role r named key is drawn in (as Furniture3D.swift itemPart).
    func itPart(_ r: String, _ key: String) -> Part3 {
        switch r {
        case "carcass": return role("carcass", key)
        case "top", "metal", "white", "mattress", "lamel", "mirror": return p(r)
        default: return role("front", key)
        }
    }

    /// The part board b of item m is drawn in: a bunk's or loft bed's ladder and guards in the wood accent (else the
    /// fronts', as the parts list cuts them: Core/CutList.swift partMat); a board the parts list lights up stays lit.
    func itPartOf(_ m: Module, _ b: Board) -> Part3 {
        let base = itPart(b.role, b.key)
        guard accentPart(m, b.key), accentOn else { return base }
        if hi != nil && base === p("hi") { return base }
        return p("accent")
    }

    /// A board of an item as it is, in frame f (its outline when it is a part or a mirror); in part when given.
    func itBoard(_ f: FFrame, _ b: Board, _ part: Part3? = nil) {
        fbox(part ?? itPart(b.role, b.key), f, Double(b.a0) / 1000, Double(b.y0) / 1000, Double(b.n0) / 1000,
             Double(b.a1 - b.a0) / 1000, Double(b.y1 - b.y0) / 1000, Double(b.n1 - b.n0) / 1000, !b.key.isEmpty || b.role == "mirror")
    }

    /* ---------------- the items ---------------- */

    /// An item in the lit 3D (FBuilder.item, detail high or low): its boards bs on wall frame w, a lift-up base tilted th
    /// about the line at pivotY up and pivotN out (mm). The picks and a bed's drawers are FBuilder.item's.
    func itemLit(_ w: WallBasis, _ m: Module, _ bs: [Board], _ th: Double, _ pivotY: Double, _ pivotN: Double) {
        let f = itFrame(w, m.x)
        let lf = th > 1e-6 ? itFrame(w, m.x, th, pivotY, pivotN) : f
        switch m.type {
        case "bed", "bunk", "loft": bedLit(w, m, bs, f, lf)
        case "table", "bar": tableLit(m, bs, f)
        case "hooks", "mirror": panelLit(bs, f)
        default: for b in bs { itBoard(f, b) }
        }
    }

    /// What the 2D drawings add to an item (detail .flat), as boxes: a bed's hidden base and its soft wall panel.
    func itemFlatExtras(_ w: WallBasis, _ m: Module) {
        let f = itFrame(w, m.x)
        if bedFoot(m, design) == "base" { bedBase(f, m) }
        if m.type == "bed" && design?.panel == true { wallPanel(w, m, f) }
    }

    /* ---------------- beds ---------------- */

    /// A bed, a bunk or a loft bed: its boards, the headboard's upholstery, the slats, the mattress and its bedding (in lf,
    /// the frame that rises with a lift-up base), its legs or hidden base, the soft wall panel; a bunk's or loft bed's
    /// ladder of round metal tubes when its look shows metal (Core/PieceLook.swift metalLadder; Android Items3D.kt bunk3D).
    private func bedLit(_ w: WallBasis, _ m: Module, _ bs: [Board], _ f: FFrame, _ lf: FFrame) {
        let bed = m.type == "bed"
        let metal = design?.legs == true && (m.type == "bunk" || m.type == "loft")
        let foot = bedFoot(m, design)
        let head = bed ? (design?.head ?? "") : ""
        let T = Double(t)
        // the bedding's pillows lean on the headboard's upholstery, or its board
        let back = T + (head.isEmpty ? 0 : HEAD_PAD)
        let pillows = bs.filter { $0.role == "white" }
        for b in bs {
            let bf = b.lift ? lf : f
            switch b.role {
            case "lamel": slats(bf, b, bed)
            case "mattress": bedding(bf, b, pillows.filter { $0.y0 == b.y1 }, bed, back)
            case "white": break
            case "metal": if foot == "legs" { bedLeg(f, b) }
            default:
                // a metal ladder's stringers and rungs as tubes (a board the parts list lights up stays lit)
                if metal && LADDER_KEYS.contains(b.key) {
                    let base = itPart(b.role, b.key)
                    ladderTube(f, b, hi != nil && base === p("hi") ? base : p("legs"))
                    continue
                }
                // the rungs of a ladder soft-edged; the rest as they are (a bunk's ladder and guards in the wood accent)
                let part = itPartOf(m, b)
                if b.key == "fp.rung" { softIn(part, f, Double(b.a0), Double(b.a1), Double(b.y0), Double(b.y1), Double(b.n0), Double(b.n1), 6) }
                else { itBoard(f, b, part) }
                if b.key == "fp.headboard" && !head.isEmpty { headboard(f, b, Double(m.h), head) }
            }
        }
        if foot == "base" { bedBase(f, m) }
        if bed && design?.panel == true { wallPanel(w, m, f) }
    }

    /// A metal ladder's board b as a round tube in part (Android Items3D.kt bunk3D): a stringer upright on its centre line,
    /// 16 mm round; a rung across at its middle, 12 mm round, 4 mm into each stringer.
    private func ladderTube(_ f: FFrame, _ b: Board, _ part: Part3) {
        let ca = Double(b.a0 + b.a1) / 2000, cn = Double(b.n0 + b.n1) / 2000, cy = Double(b.y0 + b.y1) / 2000
        if b.key == "fp.ladder" { tube(part, f.at(ca, Double(b.y0) / 1000, cn), f.at(ca, Double(b.y1) / 1000, cn), 0.016) }
        else { tube(part, f.at(Double(b.a0 - 4) / 1000, cy, cn), f.at(Double(b.a1 + 4) / 1000, cy, cn), 0.012) }
    }

    /// A bed's round leg (its board b: a metal square from the floor up to the frame), tapering down, in the legs' look.
    private func bedLeg(_ f: FFrame, _ b: Board) {
        let ca = Double(b.a0 + b.a1) / 2000, cn = Double(b.n0 + b.n1) / 2000
        tube(p("legs"), f.at(ca, 0, cn), f.at(ca, Double(b.y1) / 1000, cn), 0.012, 0.017)
    }

    /// A plain bed's hidden base: black, set in 150 under its frame's sides and 200 from its foot, up to its frame.
    private func bedBase(_ f: FFrame, _ m: Module) {
        let T = Double(t), W = Double(m.w), D = Double(m.d)
        let yb = Double(max(0, m.h - 260))
        guard yb > 10, W > 400, D > 600 else { return }
        fbox(p("bedBase"), f, 0.15, 0, (T + 40) / 1000, (W - 300) / 1000, (yb - 2) / 1000, (D - T - 240) / 1000)
    }

    /// The upholstery over a headboard's board b above the frame (its top at H): the look's fabric in its style, HEAD_PAD
    /// out of the board; a tufted one's buttons and, on a strong phone, its puffs between them.
    private func headboard(_ f: FFrame, _ b: Board, _ H: Double, _ style: String) {
        let a0 = Double(b.a0) + 10, a1 = Double(b.a1) - 10, y0 = max(H, Double(b.y0)), y1 = Double(b.y1) - 6
        let T = Double(t), fab = p("fabric")
        let pads = softPads(style, a0, a1, y0, y1)
        if style != "tufted" {
            for q in pads { softIn(fab, f, q.a0, q.a1, q.y0, q.y1, T, T + HEAD_PAD, min(HEAD_PAD * 0.48, (q.a1 - q.a0) * 0.45, 35)) }
            return
        }
        guard let q = pads.first else { return }
        let front = T + HEAD_PAD - 14
        softIn(fab, f, q.a0, q.a1, q.y0, q.y1, T, front, 30)
        if detail == .high {
            // diamonds turned 45° between the buttons, bulging 12 mm out of the slab
            let s2 = 0.5.squareRoot(), ax: V3 = f.e * s2 + f.u * s2, ay: V3 = f.u * s2 - f.e * s2
            let h = TUFT_STEP * s2 / 1000 - 0.004
            for c in tuftPuffs(q.a0, q.a1, q.y0, q.y1) {
                softBox(fab, f.at(c.a0 / 1000, c.y0 / 1000, (front - 1) / 1000), ax, ay, f.n, h, h, 0.013, 0.012)
            }
        }
        for c in tuftButtons(q.a0, q.a1, q.y0, q.y1) {
            tube(fab, f.at(c.a0 / 1000, c.y0 / 1000, (front - 2) / 1000), f.at(c.a0 / 1000, c.y0 / 1000, (front + 4) / 1000), 0.007, n: 8)
        }
    }

    /// Slats over the slats' board b (in its frame): two bearers along the bed and the slats across them, 63 wide
    /// every 100 (mockup's lamellas); long: along n (a bed), else along a (a bunk's or loft's).
    private func slats(_ f: FFrame, _ b: Board, _ long: Bool) {
        let lm = p("lamel")
        let a0 = Double(b.a0), a1 = Double(b.a1), y0 = Double(b.y0), y1 = Double(b.y1), n0 = Double(b.n0), n1 = Double(b.n1)
        func bx(_ x0: Double, _ x1: Double, _ ya: Double, _ yb: Double, _ z0: Double, _ z1: Double) {
            fbox(lm, f, x0 / 1000, ya / 1000, z0 / 1000, (x1 - x0) / 1000, (yb - ya) / 1000, (z1 - z0) / 1000)
        }
        if long {
            bx(a0, a0 + 40, y0, y1 - 8, n0, n1); bx(a1 - 40, a1, y0, y1 - 8, n0, n1)
            var n = n0 + 20
            while n + 63 <= n1 - 10 { bx(a0 + 10, a1 - 10, y1 - 8, y1, n, n + 63); n += 100 }
        } else {
            bx(a0, a1, y0, y1 - 8, n0, n0 + 40); bx(a0, a1, y0, y1 - 8, n1 - 40, n1)
            var a = a0 + 20
            while a + 63 <= a1 - 10 { bx(a, a + 63, y1 - 8, y1, n0 + 10, n1 - 10); a += 100 }
        }
    }

    /// A mattress (board b, in its frame) and what lies on it, pil its pillows' boards: a soft mattress; on a strong phone
    /// the duvet over its foot end, a bed's runner across it, the pillows soft (a bed's leaning on the headboard, its front
    /// at back, a lighter cushion before each); on a weak phone the pillows plain. long: the bed runs along n (a bed).
    private func bedding(_ f: FFrame, _ b: Board, _ pil: [Board], _ long: Bool, _ back: Double) {
        let a0 = Double(b.a0), a1 = Double(b.a1), y0 = Double(b.y0), top = Double(b.y1), n0 = Double(b.n0), n1 = Double(b.n1)
        softIn(p("mattress"), f, a0, a1, y0, top, n0, n1, 35)
        guard detail == .high else {
            for q in pil { fbox(p("linen"), f, Double(q.a0) / 1000, Double(q.y0) / 1000, Double(q.n0) / 1000, Double(q.a1 - q.a0) / 1000, Double(q.y1 - q.y0) / 1000, Double(q.n1 - q.n0) / 1000) }
            return
        }
        if long {
            softIn(p("duvet"), f, a0 - 12, a1 + 12, top - 55, top + 45, n0 + (n1 - n0) * 0.36, n1 + 14, 40)
            if n1 - n0 > 1200 { softIn(p("fabric"), f, a0 - 16, a1 + 16, top - 62, top + 58, n1 - 470, n1 - 120, 28) }
            for q in pil { leaningPillow(f, Double(q.a0), Double(q.a1), top, back) }
        } else {
            // a bunk's or a loft's: its pillow at one end, the duvet over the rest
            let low = pil.first.map { Double($0.a0) - a0 < a1 - Double($0.a1) } ?? true
            if let q = pil.first {
                softIn(p("linen"), f, Double(q.a0) + 10, Double(q.a1) - 10, top - 15, Double(q.y1) - 10, Double(q.n0), Double(q.n1), 45)
                if low { softIn(p("duvet"), f, Double(q.a1) + 30, a1 + 10, top - 50, top + 40, n0, n1, 35) }
                else { softIn(p("duvet"), f, a0 - 10, Double(q.a0) - 30, top - 50, top + 40, n0, n1, 35) }
            } else {
                softIn(p("duvet"), f, a0 - 10, a1 + 10, top - 50, top + 40, n0, n1, 35)
            }
        }
    }

    /// A bed's pillow a0…a1 across it on a mattress whose top is top, standing up and leaning back on the headboard (its
    /// face at back), and a cushion of the lighter fabric leaning on it (mm).
    private func leaningPillow(_ f: FFrame, _ a0: Double, _ a1: Double, _ top: Double, _ back: Double) {
        // half its width hw, thickness ht and height hd, tipped phi from lying flat; its back no nearer than nb, its
        // bottom sunk 20 into the mattress; rounded r
        func lean(_ part: Part3, _ ca: Double, _ hw: Double, _ ht: Double, _ hd: Double, _ phi: Double, _ nb: Double, _ r: Double) {
            let c = cos(phi), s = sin(phi)
            let ay: V3 = f.u * c + f.n * s, az: V3 = f.n * c - f.u * s
            let cn = nb + ht * s + hd * c, cy = top - 20 + ht * c + hd * s
            softBox(part, f.at(ca / 1000, cy / 1000, cn / 1000), f.e, ay, az, hw / 1000, ht / 1000, hd / 1000, r / 1000)
        }
        let ca = (a0 + a1) / 2, hw = (a1 - a0) / 2 - 10
        guard hw > 60 else { return }
        lean(p("linen"), ca, hw, 70, 200, 1.2, back + 8, 60)
        lean(p("fabric2"), ca, hw * 0.62, 55, 165, 1.05, back + 158, 45)
    }

    /// The soft wall panel behind bed m (its frame f on wall w): pads of the lighter fabric (panelPads), the wood
    /// accent's cap over them and the LED on it; on a strong phone its glow up the wall. Boxes in the 2D drawings.
    private func wallPanel(_ w: WallBasis, _ m: Module, _ f: FFrame) {
        let o = m.opt ?? ItemOpt()
        let W = Double(m.w), hb = Double(max(o.hb, m.h + 100))
        guard let span = softPanelSpan(m, piecePose, Double(m.x), w.len * 1000) else { return }
        let fab = p("fabric2")
        for q in panelPads(design?.head ?? "", span, W, hb) {
            if fancy { softIn(fab, f, q.a0, q.a1, q.y0, q.y1, 0, PANEL_D, min(PANEL_D * 0.48, 30)) }
            else { fbox(fab, f, q.a0 / 1000, q.y0 / 1000, 0, (q.a1 - q.a0) / 1000, (q.y1 - q.y0) / 1000, PANEL_D / 1000) }
        }
        let a0 = span.a0 - (span.a0 < -1 ? 20 : 0), a1 = span.a1 + (span.a1 > W + 1 ? 20 : 0), y = span.y1
        fbox(p("accent"), f, a0 / 1000, y / 1000, 0, (a1 - a0) / 1000, 0.03, 0.07, true)
        fbox(p("led"), f, (a0 + 10) / 1000, (y + 30) / 1000, 0.05, (a1 - a0 - 20) / 1000, 0.006, 0.012)
        guard fancy && detail == .high else { return }
        // its light up the wall: three faint planes, the brightest at the bottom (mockup glow, upwards)
        let g = p("glow"), A0 = (a0 + 10) / 1000, A1 = (a1 - 10) / 1000, Y0 = (y + 36) / 1000
        for (k, fr) in [1.0, 0.62, 0.3].enumerated() {
            let n = (0.6 + Double(k)) / 1000, Y1 = Y0 + 0.6 * fr
            face(g, [f.at(A0, Y0, n), f.at(A1, Y0, n), f.at(A1, Y1, n), f.at(A0, Y1, n)], f.at((A0 + A1) / 2, (Y0 + Y1) / 2, n - 0.01), f.e)
        }
    }

    /* ---------------- tables, the bar counter ---------------- */

    /// A table or bar counter: its top one slab over its layers with a soft edge (its corners round when set), in the
    /// worktop's decor or the front board; metal legs and rails round (a frame's square tube), in the handle colour; a
    /// bar's front in the piece's front style; the rest as they are.
    private func tableLit(_ m: Module, _ bs: [Board], _ f: FFrame) {
        let o = m.opt ?? ItemOpt()
        let tops = bs.filter { $0.role == "top" || $0.key == "fp.top" || $0.key == "fp.topR" }
        if let b0 = tops.first {
            let y0 = Double(tops.map(\.y0).min() ?? b0.y0), y1 = Double(tops.map(\.y1).max() ?? b0.y1)
            softTop(itPart(b0.role, b0.key), f, Double(b0.a0), Double(b0.a1), y0, y1, Double(b0.n0), Double(b0.n1), Double(b0.round), topEdgeR(y1 - y0), true)
        }
        let square = m.type == "table" && o.legs == "frame"
        for b in bs where !tops.contains(b) {
            if b.role == "metal" { itMetal(f, b, square) }
            else if b.key == "fp.barFront" {
                let fr = FFrame(o: f.at(Double(b.a0) / 1000, Double(b.y0) / 1000, Double(b.n0) / 1000), e: f.e, u: f.u, n: f.n)
                frontBody(itPart(b.role, b.key), fr, Double(b.a1 - b.a0) / 1000, Double(b.y1 - b.y0) / 1000, Double(t) / 1000)
            } else { itBoard(f, b) }
        }
    }

    /// A metal board in the legs' look (the handle colour, steel without one): a round tube along its longest side, or
    /// a square one (square: a table's frame).
    private func itMetal(_ f: FFrame, _ b: Board, _ square: Bool) {
        let lg = p("legs")
        let sa = Double(b.a1 - b.a0), sy = Double(b.y1 - b.y0), sn = Double(b.n1 - b.n0)
        if square {
            fbox(lg, f, Double(b.a0) / 1000, Double(b.y0) / 1000, Double(b.n0) / 1000, sa / 1000, sy / 1000, sn / 1000)
            return
        }
        let ca = Double(b.a0 + b.a1) / 2000, cy = Double(b.y0 + b.y1) / 2000, cn = Double(b.n0 + b.n1) / 2000
        if sy >= sa && sy >= sn { tube(lg, f.at(ca, Double(b.y0) / 1000, cn), f.at(ca, Double(b.y1) / 1000, cn), min(sa, sn) / 2000) }
        else if sa >= sn { tube(lg, f.at(Double(b.a0) / 1000, cy, cn), f.at(Double(b.a1) / 1000, cy, cn), min(sy, sn) / 2000) }
        else { tube(lg, f.at(ca, cy, Double(b.n0) / 1000), f.at(ca, cy, Double(b.n1) / 1000), min(sa, sy) / 2000) }
    }

    /* ---------------- hall panels, mirrors ---------------- */

    /// A hall panel (its board in the piece's front style, the mirror and coat hooks on its face, the hat shelf on
    /// brackets) or a mirror on the wall: the mirror in its tint, framed in the handle colour when there is one.
    private func panelLit(_ bs: [Board], _ f: FFrame) {
        let T = Double(t)
        var zf = T
        if let pb = bs.first(where: { $0.key == "fp.panel" }) {
            let fr = FFrame(o: f.at(Double(pb.a0) / 1000, Double(pb.y0) / 1000, Double(pb.n0) / 1000), e: f.e, u: f.u, n: f.n)
            zf = Double(pb.n0) + frontBody(itPart(pb.role, pb.key), fr, Double(pb.a1 - pb.a0) / 1000, Double(pb.y1 - pb.y0) / 1000, T / 1000) * 1000
        }
        let hasPanel = bs.contains { $0.key == "fp.panel" }
        for b in bs where b.key != "fp.panel" {
            switch b.role {
            case "mirror": mirrorPane(f, b, hasPanel ? zf - Double(b.n0) : 0)
            case "metal":
                if b.n1 - b.n0 > 100 { fbox(p("legs"), f, Double(b.a0) / 1000, Double(b.y0) / 1000, Double(b.n0) / 1000, Double(b.a1 - b.a0) / 1000, Double(b.y1 - b.y0) / 1000, Double(b.n1 - b.n0) / 1000) }
                else { coatHook(f, Double(b.a0 + b.a1) / 2, Double(b.y1), zf) }
            default: itBoard(f, b)
            }
        }
    }

    /// A mirror's pane (board b moved dz out), its outline; a slim frame round it in the handle colour when the design has one.
    private func mirrorPane(_ f: FFrame, _ b: Board, _ dz: Double) {
        let a0 = Double(b.a0) / 1000, y0 = Double(b.y0) / 1000, n0 = (Double(b.n0) + dz) / 1000
        let W = Double(b.a1 - b.a0) / 1000, H = Double(b.y1 - b.y0) / 1000, D = Double(b.n1 - b.n0) / 1000
        fbox(p("mirror"), f, a0, y0, n0, W, H, D, true)
        guard !(design?.hcol ?? "").isEmpty, W > 0.06, H > 0.06 else { return }
        let fr = p("frame"), s = 0.012, d = D + 0.004
        fbox(fr, f, a0 - s, y0 - s, n0, s, H + 2 * s, d); fbox(fr, f, a0 + W, y0 - s, n0, s, H + 2 * s, d)
        fbox(fr, f, a0, y0 - s, n0, W, s, d); fbox(fr, f, a0, y0 + H, n0, W, s, d)
    }

    /// A metal coat hook at a along, its top at top, on the face zf out (mm): a round rose, an arm out and down, its tip
    /// turned up with a ball on it, in the legs' look (the handle colour, steel without one).
    private func coatHook(_ f: FFrame, _ a: Double, _ top: Double, _ zf: Double) {
        let lg = p("legs"), x = a / 1000
        func q(_ y: Double, _ z: Double) -> V3 { f.at(x, y / 1000, z / 1000) }
        let y = top - 22
        tube(lg, q(y, zf), q(y, zf + 7), 0.011)
        tube(lg, q(y, zf + 7), q(y - 22, zf + 48), 0.0045, n: 8)
        tube(lg, q(y - 22, zf + 48), q(y + 4, zf + 56), 0.0045, n: 8)
        tube(lg, q(y + 4, zf + 56), q(y + 11, zf + 58), 0.0068, n: 8)
    }

    /* ---------------- the bathroom ---------------- */

    /// A vanity's basin (Furniture3D.swift basin) in the lit 3D: a round white ceramic bowl bw × bd at most (mm), its
    /// middle mid along and n0 + bd / 2 out, on the vanity's top; its drain; a tall tap behind it in the handle colour
    /// (chrome without one), its spout over the bowl, its lever on top.
    func basinLit(_ w: WallBasis, _ mid: Double, _ top: Double, _ n0: Double, _ bw: Double, _ bd: Double) {
        let R = min(bw, bd) / 2000 - 0.005, H = 0.13
        guard R > 0.08 else { return }
        let cn = n0 + bd / 2
        let prof: [(Double, Double)] = [(0, 0), (R * 0.5, 0), (R * 0.66, 0.012), (R * 0.9, 0.06), (R, H), (R - 0.008, H), (R * 0.86, 0.062),
                                        (R * 0.6, 0.024), (R * 0.3, 0.018), (0, 0.017)]
        lathe(p("ceramic"), w.at(mid / 1000, top / 1000, cn / 1000), V3(0, 1, 0), prof, n: detail == .high ? 28 : 16)
        tube(p("chrome"), w.at(mid / 1000, (top + 17) / 1000, cn / 1000), w.at(mid / 1000, (top + 19.5) / 1000, cn / 1000), 0.019, n: 12)
        let tp = p("tap")
        let tn = max(25, cn - R * 1000 - 45)
        func q(_ y: Double, _ n: Double) -> V3 { w.at(mid / 1000, y / 1000, n / 1000) }
        tube(tp, q(top, tn), q(top + 30, tn), 0.024)
        tube(tp, q(top + 30, tn), q(top + 300, tn), 0.013)
        let ne = cn - R * 250
        tube(tp, q(top + 290, tn), q(top + 290, ne), 0.011)
        tube(tp, q(top + 290, ne), q(top + 262, ne), 0.011)
        box(w, tp, mid - 7, mid + 7, top + 300, top + 312, tn - 55, tn + 6)
    }
}
