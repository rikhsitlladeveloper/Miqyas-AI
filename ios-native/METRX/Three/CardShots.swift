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
        guard tier != .flat, ensure(spec, tier) != nil, let co = coord else { done(nil); return }
        n += 1
        let shell = cardShell(f, ws, mats, tier)
        co.update(shell, "card\(n)", nil, cam, nil)
        // the camera of the 2D card's angle (PieceView pieceScene az0), a little from above, the piece with its floor and
        // wall framed with the same room round it as every card (CardCache.swift cardAim)
        let ps = pieceScene(f, ws, mats)
        let aim = cardAim(ps.cardExt, piece: ps.ext, az: ps.az0, el: CARD_EL, aspect: Double(spec.pt.width / max(1, spec.pt.height)))
        cam.stop()
        cam.bounds = nil; cam.rMin = 0.2; cam.rMax = nil
        cam.tgt = aim.tgt; cam.r = aim.r
        cam.phi = Double.pi / 2 - CARD_EL
        cam.theta = atan2(cos(ps.az0), sin(ps.az0))
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
