import Foundation

/*
 * The tiles in 3D (Android tiles/Mesh.kt): every piece at its true place on the room's floor and walls in front of a
 * joint-coloured backing, the cut pieces a shade off, the skirting, and the tray and bath. Pieces of one colour on one
 * wall go into one part, so the whole room is a few dozen meshes (an old phone stays smooth), and a wall's tiles fade
 * with the wall when it faces the camera.
 */

/// Most pieces drawn in one picture: past it a surface is drawn as one slab of its tile, without joints.
let MAX_DRAWN = 7000

/// How far in front of its surface a tile sits, and its joints' backing, metres.
private let TILE_OFF = 0.004
private let GROUT_OFF = 0.0022

/// The joints' colour for a tile: light grey for light tiles, dark grey for dark ones.
func groutOf(_ rgb: Int) -> Int { lum(rgb) > 0.45 ? 0xBEBCB6 : 0x3E3F42 }

func lum(_ rgb: Int) -> Double {
    let r = Double((rgb >> 16) & 255), g = Double((rgb >> 8) & 255), b = Double(rgb & 255)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255
}

private func channel(_ v: Double) -> Int { min(255, max(0, tInt(v))) }

func mixRgb(_ a: Int, _ b: Int, _ k: Double) -> Int {
    func c(_ s: Int) -> Int { channel(Double((a >> s) & 255) * (1 - k) + Double((b >> s) & 255) * k) }
    return (c(16) << 16) | (c(8) << 8) | c(0)
}

func scaleRgb(_ a: Int, _ k: Double) -> Int {
    func c(_ s: Int) -> Int { channel(Double((a >> s) & 255) * k) }
    return (c(16) << 16) | (c(8) << 8) | c(0)
}

/// A cut piece's shade: the tile's colour turned a little amber, so cuts show on light and dark tiles alike.
func cutRgb(_ rgb: Int, _ k: Double = 0.3) -> Int { mixRgb(rgb, 0xE0812F, k) }

/// The tile's colour for one tile of a drawn look: wood planks and concrete vary from tile to tile, marble a little.
func toneOf(_ look: TileLook, _ seed: Int) -> Int {
    let ks: [Double]
    switch look.kind {
    case "w": ks = [1.0, 0.9, 1.06, 0.95]
    case "k": ks = [1.0, 0.94, 1.05]
    case "m": ks = [1.0, 0.975, 1.015]
    default: return look.rgb
    }
    return scaleRgb(look.rgb, ks[tFloorMod(seed &* 7 &+ (seed >> 3), ks.count)])
}

/// The look of a piece of layout l: the main one or the second.
func lookFor(_ l: TileLayout, _ prod: Int) -> TileLook { lookOf(prod == 0 ? l.look : l.look2) }

/// The drawing's joint: at least 4 mm so a 1–2 mm joint still shows from across the room (the tiles keep their true pitch).
func drawInset(_ l: TileLayout) -> Double { max(0, (4.0 - Double(l.joint)) / 2) }

/// Parts keyed by wall and colour as they fill.
private final class TileParts {
    var keys: [String] = []
    var map: [String: Part3] = [:]
    func of(_ wall: String?, _ rgb: Int, _ role: Role3) -> Part3 {
        let k = "\(wall ?? "-")|\(rgb)|\(role)"
        if let p = map[k] { return p }
        let p = Part3(0, wall, role, rgb, 1, tile: true)
        map[k] = p; keys.append(k)
        return p
    }
    var parts: [Part3] { keys.compactMap { map[$0] } }
}

private func tFace(_ p: Part3, _ fr: TFrame, _ poly: [V2], _ off: Double) {
    if poly.count < 3 { return }
    var pts: [V3] = []
    pts.reserveCapacity(poly.count)
    for q in poly { pts.append(fr.at(q.x, q.y, off)) }
    p.faces.append(Face3(n: fr.n, pts: pts))
}

/// A surface less its holes, as convex pieces (what the joints' backing covers).
func backingOf(_ s: Surf) -> [[V2]] {
    var out: [[V2]] = []
    for part in convexParts(s.outline) {
        var acc: [[V2]] = [part]
        for h in s.holes { acc = acc.flatMap { polySubtract($0, h) } }
        out += acc
    }
    return out
}

/// The pieces of laid into ps; a surface past the budget left0 (pieces) as one slab. Returns what is left.
private func addLaid(_ ps: TileParts, _ l: TileLayout, _ laid: Laid, _ left0: Int) -> Int {
    var left = left0
    var bySurf: [Int: [TPiece]] = [:]
    for pc in laid.pieces { bySurf[pc.s, default: []].append(pc) }
    for (si, s) in laid.surfs.enumerated() {
        let role: Role3 = s.kind == "floor" ? .floor : .opening
        let pcs = bySurf[si] ?? []
        let main = lookFor(l, s.alt ? 1 : 0)
        let backing = backingOf(s)
        if pcs.count > left || laid.tooMany.contains(si) {
            // too many to draw: the surface in its tile's colour
            for poly in backing { tFace(ps.of(s.wall, main.rgb, role), s.frame, poly, TILE_OFF) }
            continue
        }
        left -= pcs.count
        for poly in backing { tFace(ps.of(s.wall, groutOf(main.rgb), role), s.frame, poly, GROUT_OFF) }
        for pc in pcs {
            let lk = lookFor(l, pc.prod)
            let rgb = pc.cut ? cutRgb(lk.rgb) : toneOf(lk, pc.seed)
            let part = ps.of(s.wall, rgb, role)
            for poly in pc.polys { tFace(part, s.frame, poly, TILE_OFF) }
        }
    }
    return left
}

/// A box over a footprint fp (scene points at the floor) up to h metres.
private func tileBox(_ p: Part3, _ fp: [V3], _ h: Double) {
    if fp.isEmpty { return }
    p.faces.append(Face3(n: V3(0, 1, 0), pts: fp.map { V3($0.x, h, $0.z) }))
    var cx = 0.0, cz = 0.0
    for q in fp { cx += q.x; cz += q.z }
    cx /= Double(fp.count); cz /= Double(fp.count)
    let n = fp.count
    for i in 0..<n {
        let a = fp[i], b = fp[(i + 1) % n]
        var nx = b.z - a.z, nz = -(b.x - a.x)
        let l = hypot(nx, nz)
        if l <= 0 { continue }
        nx /= l; nz /= l
        if ((a.x + b.x) / 2 - cx) * nx + ((a.z + b.z) / 2 - cz) * nz < 0 { nx = -nx; nz = -nz }
        p.faces.append(Face3(n: V3(nx, 0, nz), pts: [a, b, V3(b.x, h, b.z), V3(a.x, h, a.z)]))
    }
}

/// The skirting of layout l in its tile: pieces l.b long, l.skirt high, along its runs.
private func addSkirt(_ ps: TileParts, _ l: TileLayout, _ runs: [TRun]) {
    if runs.isEmpty { return }
    let lk = lookOf(l.look)
    let tb = Double(l.b), sk = Double(l.skirt)
    let pitch = tb + Double(l.joint), gap = max(Double(l.joint), 4.0)
    for r in runs {
        var a = r.a0
        var k = 0
        while a < r.a1 - 1 {
            let e = min(a + tb, r.a1)
            let rgb = e - a < tb - 1 ? cutRgb(lk.rgb) : toneOf(lk, k)
            let p = ps.of(r.wall, rgb, .opening)
            tFace(p, r.frame, [V2(a + gap / 2, 0), V2(e - gap / 2, 0), V2(e - gap / 2, sk), V2(a + gap / 2, sk)], 0.009)
            a += pitch; k += 1
        }
    }
}

/// The 3D parts of the room's layouts ls (the order's all decide the lining up and the skirting), and its tray and bath.
func tileParts(_ ls: [TileLayout], _ g: TRoomGeo, _ all: [TileLayout], _ cap: Int = MAX_DRAWN) -> [Part3] {
    let ps = TileParts()
    var left = cap
    let fl = floorLayout(all, g.room.id)
    for l in ls {
        let floorOf: TileLayout? = fl?.id != l.id ? fl : nil
        left = addLaid(ps, l, layRoom(l, g, floorOf, drawInset(l)), left)
        addSkirt(ps, l, skirtRuns(l, g, all))
    }
    for f in g.fixes {
        guard let fp = footprint(g, f) else { continue }
        // a bath's front is tiled when a layout covers it, so it stands just behind its tiles
        tileBox(ps.of(nil, f.type == "bath" ? 0xF7F7F4 : 0xF1F2F0, .furn), fp.map { g.scene($0) }, Double(f.h) / 1000)
    }
    return ps.parts
}

/* ---------------- a surface without a room ---------------- */

/// The made-up room a typed surface is shown in: the floor alone, or the wall (a backsplash over a worktop).
private func tilePanelRoom(_ p: TPanel) -> Room {
    let floor = p.kind == "floor"
    let h = floor ? 2400 : p.b + (p.kind == "apron" ? APRON_H0 + 300 : 0)
    var r = Room(id: "panel", floorId: "", name: "")
    r.dims = ["A": Dim(v: p.a), "B": Dim(v: floor ? p.b : 1400), "H": Dim(v: h), "T": Dim(v: 120, src: "default")]
    r.floorColor = "#DDE2E8"
    return r
}

/// The 3D of a layout without a room: a flat floor, or a wall panel (a backsplash over a worktop), with its real tiles.
func panelScene(_ l: TileLayout, _ cap: Int = MAX_DRAWN) -> Shell3D? {
    guard let p = l.panel else { return nil }
    if p.a <= 0 || p.b <= 0 { return nil }
    let base = buildShell([tilePanelRoom(p)], single: true)
    let thick = 0.12
    let shell: Shell3D
    if p.kind == "floor" {
        shell = base.floorOnly()
    } else {
        let parts = base.parts.filter { $0.role == .floor || ($0.wall == "A" && $0.role == .wall) }
        let edges = base.edges.filter { $0.wall == "A" }
        let groups = base.groups.map { Group3(cx: $0.cx, cz: $0.cz, normals: [:]) }
        shell = Shell3D(parts: parts, edges: edges, groups: groups, labels: [], rooms3: nil, L: base.L, W: base.W, H: base.H, tgt: base.tgt, r: base.r,
                        theta: base.theta, phi: base.phi, bounds: base.bounds, rMin: base.rMin, fit: base.fit, gridSize: base.gridSize, gridDiv: base.gridDiv,
                        gridCx: base.gridCx, gridCz: base.gridCz, light: base.light, far: base.far, bases: base.bases)
    }
    let y0 = p.kind == "apron" ? Double(APRON_H0) / 1000 : 0
    let frame = p.kind == "floor" ? TFrame(V3(thick, 0, 0), V3(1, 0, 0), V3(0, 0, 1), V3(0, 1, 0)) : TFrame(V3(thick, y0, 0), V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1))
    guard let s = panelSurf(l, frame) else { return nil }
    let ps = TileParts()
    _ = addLaid(ps, l, layAll(l, [s], nil, nil, drawInset(l)), cap)
    if p.kind == "apron" {
        // the worktop and the units under it
        let x1 = thick + Double(p.a) / 1000
        let fp = [V3(thick, 0, 0), V3(x1, 0, 0), V3(x1, 0, 0.6), V3(thick, 0, 0.6)]
        tileBox(ps.of(nil, 0xF4F4F2, .furn), fp, y0 - 0.04)
        let top = Part3(0, nil, .furn, 0x8A7560, 1, tile: true)
        tileBox(top, fp, y0)
        // only the worktop's top band: lift its faces onto the units
        top.faces = top.faces.map { f in Face3(n: f.n, pts: f.pts.map { q in V3(q.x, q.y > 0 ? y0 : y0 - 0.04, q.z) }) }
        return shell.plus(ps.parts + [top], [])
    }
    return shell.plus(ps.parts, [])
}
