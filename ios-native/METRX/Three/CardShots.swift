import UIKit
import RealityKit

/*
 * The gallery's cards made by the real 3D ("modern furniture 3D" part 4): one hidden ARView (no camera feed), the same
 * Scene3DCoordinator as the 3D page (lit looks, decor pictures, studio light, sun), loaded with one piece at a time on
 * its own floor and walls, a 3/4 camera fitting it, then snapshot(saveToHDR: false). The view sits behind everything
 * in the key window, almost transparent and out of reach of touches and VoiceOver, and goes away after a few idle
 * seconds. RealityRenderer (iOS 18, offscreen to a Metal texture) was not used: it would need the scene built a second
 * time outside the coordinator, iOS 17 still needs this way, and it is reported failing in the Simulator the UI tests
 * run in. Everything here runs on the main thread; Furniture/GalleryCards.swift asks for one card at a time, waits at
 * most a few seconds and draws the card the old way when no picture comes.
 */

/// The scene of piece f's card: the floor of its made-up room and the walls it stands on (no outlines on them, as in the
/// mockup), the piece in the lit 3D of tier.
func cardShell(_ f: Furniture, _ ws: Workshop, _ mats: [Mat], _ tier: Quality3) -> Shell3D {
    let room = freeRoom(f)
    let full = buildShell([room], single: true, snap: true)
    let fur = furniture3D([f], full.bases, ws, { id in rgbOf(mats.first { $0.id == id }?.rgb ?? "#F5F5F2") }, [],
                          tex: { id in mats.first { $0.id == id }?.tex }, mats: mats, detail: tier, ceilH: room.dim("H").v ?? 2700)
    let on = Set(f.walls.filter { $0 != ISLAND })
    let walls = full.parts.filter { $0.role == .wall && on.contains($0.wall ?? "") }
    // floorOnly keeps no wall normals: nothing is cut away, the walls behind the piece stay solid
    return full.floorOnly().plus(walls + fur.parts, fur.edges)
}

/// The scene of pieces fs in their measured room for a card: the floor, the walls they stand on (with their windows'
/// frames and glass), the pieces; the corners of the pieces' bounds (what the card frames) and the angle round them
/// (from inside the room, towards their walls; a little from one side for one wall).
func roomCardShell(_ fs: [Furniture], _ room: Room, _ ws: Workshop, _ mats: [Mat], _ tier: Quality3, snap: Bool) -> (shell: Shell3D, pts: [V3], az: Double) {
    let full = buildShell([room], single: true, snap: snap)
    let fur = furniture3D(fs, full.bases, ws, { id in rgbOf(mats.first { $0.id == id }?.rgb ?? "#F5F5F2") }, [],
                          tex: { id in mats.first { $0.id == id }?.tex }, mats: mats, detail: tier, ceilH: room.dim("H").v ?? 2700)
    var on: [String] = []
    for f in fs { for w in f.walls where w != ISLAND && !on.contains(w) { on.append(w) } }
    let bases = on.compactMap { full.bases[$0] }
    // a window's glass has no wall: the one within a wall's thickness of a wall the pieces stand on
    func nearWall(_ p: Part3) -> Bool {
        guard let f = p.faces.first, !f.pts.isEmpty else { return false }
        var c = V3(0, 0, 0)
        for q in f.pts { c = c + q }
        c = c * (1 / Double(f.pts.count))
        return bases.contains { b in
            let dx = c.x - b.ox, dz = c.z - b.oz
            let along = dx * b.ux + dz * b.uz, into = dx * b.nx + dz * b.nz
            return abs(into) < 0.35 && along > -0.1 && along < b.len + 0.1
        }
    }
    let walls = full.parts.filter { p in
        switch p.role {
        case .wall, .opening: return on.contains(p.wall ?? "")
        case .glass: return nearWall(p)
        default: return false
        }
    }
    var lo = V3(1e9, 1e9, 1e9), hi = V3(-1e9, -1e9, -1e9)
    for p in fur.parts { for f in p.faces { for q in f.pts { lo = V3(min(lo.x, q.x), min(lo.y, q.y), min(lo.z, q.z)); hi = V3(max(hi.x, q.x), max(hi.y, q.y), max(hi.z, q.z)) } } }
    if lo.x > hi.x { lo = V3(0, 0, 0); hi = V3(1, 1, 1) }
    var pts: [V3] = []
    for x in [lo.x, hi.x] { for y in [lo.y, hi.y] { for z in [lo.z, hi.z] { pts.append(V3(x, y, z)) } } }
    var nx = 0.0, nz = 0.0
    for b in bases { nx += b.nx; nz += b.nz }
    let l = hypot(nx, nz)
    let az = (l > 0.1 ? atan2(nx / l, nz / l) : 0) + (bases.count == 1 ? 0.35 : 0)
    return (full.floorOnly().plus(walls + fur.parts, fur.edges), pts, az)
}

/// The window the hidden view goes into: the key window, else the first one.
private func cardWindow() -> UIWindow? {
    let ws = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
    return ws.first { $0.isKeyWindow } ?? ws.first
}

/// The hidden 3D that takes the cards' pictures. Main thread only.
final class CardRenderer {
    static let shared = CardRenderer()
    private var view: Scene3DARView? = nil
    private var coord: Scene3DCoordinator? = nil
    private var tier: Quality3? = nil
    private var size: CGSize = .zero
    private let cam = Cam3D()
    private var made = Date.distantPast
    private var studioReady = false
    private var n = 0
    private var idle: DispatchWorkItem? = nil

    /// Takes f's card (the workshop ws, the boards mats) at spec in the lit 3D of tier; done gets the picture, or nil
    /// when there is no window or the tier is the flat one. done may never be called (the app in the background): the
    /// caller waits only so long.
    func render(_ f: Furniture, _ ws: Workshop, _ mats: [Mat], _ spec: CardSpec, _ tier: Quality3, _ done: @escaping (UIImage?) -> Void) {
        guard tier != .flat, ensure(spec, tier) != nil, coord != nil else { done(nil); return }
        let shell = cardShell(f, ws, mats, tier)
        // the camera of the 2D card's angle (PieceView pieceScene az0), a little from above, the piece with its floor and
        // wall framed with the same room round it as every card (CardCache.swift cardAim)
        let ps = pieceScene(f, ws, mats)
        let aim = cardAim(ps.cardExt, piece: ps.ext, az: ps.az0, el: CARD_EL, aspect: Double(spec.pt.width / max(1, spec.pt.height)))
        shoot(shell, aim.tgt, aim.r, ps.az0, done)
    }

    /// Takes the card of pieces fs standing in their measured room (the auto kitchen's style cards, Furniture/
    /// AutoKitchenScreen.swift): the room's floor and the walls they stand on with their windows, seen from inside the
    /// room, the pieces filling the card. done as render's.
    func renderRoom(_ fs: [Furniture], _ room: Room, _ ws: Workshop, _ mats: [Mat], _ spec: CardSpec, _ tier: Quality3, snap: Bool,
                    _ done: @escaping (UIImage?) -> Void) {
        guard tier != .flat, ensure(spec, tier) != nil, coord != nil else { done(nil); return }
        let rc = roomCardShell(fs, room, ws, mats, tier, snap: snap)
        let aim = cardAim(rc.pts, piece: rc.pts, az: rc.az, el: CARD_EL, aspect: Double(spec.pt.width / max(1, spec.pt.height)))
        shoot(rc.shell, aim.tgt, aim.r, rc.az, done)
    }

    /// The scene in the hidden view, the camera at tgt from r away and az round, a picture to done once it is drawn.
    private func shoot(_ shell: Shell3D, _ tgt: V3, _ r: Double, _ az: Double, _ done: @escaping (UIImage?) -> Void) {
        guard let co = coord else { done(nil); return }
        n += 1
        co.update(shell, "card\(n)", nil, cam, nil)
        cam.stop()
        cam.bounds = nil; cam.rMin = 0.2; cam.rMax = nil
        cam.tgt = tgt; cam.r = r
        cam.phi = Double.pi / 2 - CARD_EL
        cam.theta = atan2(cos(az), sin(az))
        cam.moved()
        idleLater()
        // a few frames for the new meshes and pictures; longer for a new view and until the studio light is in
        let wait = Date().timeIntervalSince(made) < 1 || !studioReady ? 0.6 : 0.18
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let v = self?.view else { done(nil); return }
            v.snapshot(saveToHDR: false) { img in done(img) }
        }
    }

    /// The hidden view for tier at spec's size, made (again) when needed; nil without a window.
    private func ensure(_ spec: CardSpec, _ t: Quality3) -> Scene3DARView? {
        if let v = view, tier == t, v.window != nil {
            if size != spec.pt { v.frame = CGRect(origin: .zero, size: spec.pt); size = spec.pt }
            return v
        }
        drop()
        guard let win = cardWindow() else { return nil }
        let v = Scene3DARView(frame: CGRect(origin: .zero, size: spec.pt), cameraMode: .nonAR, automaticallyConfigureSession: false)
        v.environment.background = .color(uiColor(CARD_BG))
        v.contentScaleFactor = spec.scale
        v.isUserInteractionEnabled = false
        v.alpha = 0.02
        v.isAccessibilityElement = false
        v.accessibilityElementsHidden = true
        win.insertSubview(v, at: 0)
        let c = Scene3DCoordinator()
        c.attach(v, t)
        view = v; coord = c; tier = t; size = spec.pt; made = Date()
        // iOS 17 has no studio light of its own making (Lit3D.swift): nothing to wait for there
        if #unavailable(iOS 18.0) { studioReady = true }
        Scene3DCoordinator.studio { [weak self] _ in self?.studioReady = true }
        return v
    }

    /// The view goes after a few seconds with no card to take (its GPU memory with it).
    private func idleLater() {
        idle?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.drop() }
        idle = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: w)
    }

    /// The hidden view taken away.
    func drop() {
        idle?.cancel(); idle = nil
        coord?.detach()
        view?.removeFromSuperview()
        view = nil; coord = nil; tier = nil; size = .zero
    }
}
