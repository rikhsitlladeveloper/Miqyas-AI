import SwiftUI
import RealityKit
import UIKit
import Observation

/*
 * The 3D picture (prototype mount3D / draw3D and the ux module's camera limits), drawn with RealityKit in an ARView
 * without the camera feed (iOS 17 has no non-AR RealityView). As on Android, the colours are worked out the way
 * three.js lights the prototype's Lambert walls (geo shade) and handed over as flat unlit colours, so the picture
 * matches the prototype's.
 */

let BG3D = 0xF3F6FA

func uiColor(_ rgb: Int, _ a: Double = 1) -> UIColor {
    UIColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: a)
}

private func f3(_ v: V3) -> SIMD3<Float> { SIMD3(Float(v.x), Float(v.y), Float(v.z)) }

/// Where the camera is and where it may go. One per 3D picture.
@Observable
final class Cam3D {
    @ObservationIgnored var theta = Double.pi / 2 + 0.75
    @ObservationIgnored var phi = 0.95
    @ObservationIgnored var r = 12.0
    @ObservationIgnored var tgt = V3(0, 1, 0)
    @ObservationIgnored var bounds: Bounds3? = nil
    @ObservationIgnored var rMin = 3.0
    @ObservationIgnored var rMax: Double? = nil
    @ObservationIgnored var fit: [Double]? = nil
    @ObservationIgnored var rFit: Double? = nil
    @ObservationIgnored var dims = [1.0, 1.0, 1.0]
    @ObservationIgnored var w: CGFloat = 0
    @ObservationIgnored var h: CGFloat = 0
    /// The room the view is zoomed to (several rooms).
    var focus: String? = nil
    /// Bumped on every move, so the labels follow.
    var tick = 0
    @ObservationIgnored var onMove: (() -> Void)? = nil
    /// The 3D view's own projection, once it is on screen.
    @ObservationIgnored var projector: ((V3) -> CGPoint?)? = nil
    @ObservationIgnored private var anim: Timer? = nil
    @ObservationIgnored private var shellKey: [Double]? = nil

    var aspect: Double { w > 0 && h > 0 ? Double(w / h) : 1 }

    /// A new scene: the camera starts over unless only colours changed (the prototype starts over on every rebuild).
    func load(_ s: Shell3D) {
        let key = [s.L, s.W, s.H, Double(s.parts.count)]
        if key == shellKey { return }
        shellKey = key
        stop(); focus = nil
        dims = [s.L, s.W, s.H]
        tgt = s.tgt; r = s.r
        if let t = s.theta { theta = t }
        if let p = s.phi { phi = p }
        bounds = s.bounds; rMin = s.rMin; rMax = nil; fit = s.fit; rFit = nil
        if w > 0 { applyFit() }
        moved()
    }

    func resize(_ w: CGFloat, _ h: CGFloat) {
        guard w != self.w || h != self.h else { return }
        self.w = w; self.h = h
        if fit != nil { applyFit() }
        moved()
    }

    /// The distance that shows everything depends on the shape of the picture (prototype resize3D).
    private func applyFit() {
        guard let f = fit else { return }
        r = v3Fit(f[0], f[1], f[2], aspect) * f[3]; rFit = r; rMax = r * f[4]; fit = nil
    }

    private func clamp() {
        if let b = bounds { tgt = V3(min(max(tgt.x, b.x0), max(b.x0, b.x1)), tgt.y, min(max(tgt.z, b.z0), max(b.z0, b.z1))) }
        if let m = rMax { r = min(max(r, rMin), max(rMin, m)) }
    }

    func eye() -> V3 { V3(tgt.x + r * sin(phi) * cos(theta), tgt.y + r * cos(phi), tgt.z + r * sin(phi) * sin(theta)) }

    func moved() { clamp(); onMove?(); tick &+= 1 }

    /// One finger turns the view (prototype: 0.009 per pixel).
    func rotate(_ dx: CGFloat, _ dy: CGFloat) { theta += Double(dx) * 0.009; phi = min(max(phi - Double(dy) * 0.009, 0.06), 1.5); moved() }

    /// Pinch: k is the old finger distance over the new one.
    func zoom(_ k: Double) { r = min(max(r * k, 3), 80); moved() }

    /// Two fingers move the view across the floor (prototype v3Pan); dx, dy in points.
    func pan(_ dx: CGFloat, _ dy: CGFloat) {
        let hh = h > 0 ? Double(h) : 400
        let k = 2 * r * tan(FOV_HALF) / hh, kf = k / max(0.35, cos(phi)), th = theta
        let x = Double(dx), y = Double(dy)
        tgt = V3(tgt.x - sin(th) * x * k - cos(th) * y * kf, tgt.y, tgt.z + cos(th) * x * k - sin(th) * y * kf)
        moved()
    }

    /// "From above" and "From the corner": back to the middle at the start distance (prototype preset + ux).
    func preset(top: Bool) {
        stop()
        if top { phi = 0.07; theta = .pi / 2 } else { phi = 0.95; theta = .pi / 2 + 0.75 }
        tgt = V3(dims[0] / 2, dims[2] * 0.3, dims[1] / 2)
        r = rFit ?? (max(dims[0], dims[1]) * 2.2 + 2.5)
        moved()
    }

    /// Where a point appears in the picture, in points; nil behind the camera.
    func project(_ p: V3) -> CGPoint? {
        guard w > 0, h > 0 else { return nil }
        let e = eye(), f = (tgt - e).unit
        if (p - e).dot(f) <= 0.1 { return nil }
        if let projector { return projector(p) }
        let s = f.cross(V3(0, 1, 0)).unit, u = s.cross(f), d = p - e, zc = d.dot(f)
        let fy = 1 / tan(FOV_HALF), fx = fy / aspect
        let nx = fx * d.dot(s) / zc, ny = fy * d.dot(u) / zc
        return CGPoint(x: (nx + 1) / 2 * Double(w), y: (1 - ny) / 2 * Double(h))
    }

    func stop() { anim?.invalidate(); anim = nil }

    /// Moves the camera smoothly to a room or back to all of them (prototype v3Go: 340 ms, easing out).
    func go(_ t: V3, _ r1: Double, _ th: Double? = nil, _ ph: Double? = nil) {
        stop()
        let t0 = tgt, r0 = r, th0 = theta, ph0 = phi
        let start = Date()
        anim = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] tm in
            guard let self else { tm.invalidate(); return }
            let k = min(1, Date().timeIntervalSince(start) / 0.34)
            let e = 1 - pow(1 - k, 3)
            self.tgt = V3(t0.x + (t.x - t0.x) * e, t0.y + (t.y - t0.y) * e, t0.z + (t.z - t0.z) * e); self.r = r0 + (r1 - r0) * e
            if let th, let ph { self.theta = th0 + (th - th0) * e; self.phi = ph0 + (ph - ph0) * e }
            self.moved()
            if k >= 1 { self.stop() }
        }
    }
}

/// Hands the picture to "Add to report" (the 3D view's own snapshot, without the labels).
final class Shot3D {
    var grab: (@escaping (UIImage?) -> Void) -> Void = { $0(nil) }
    func take(_ done: @escaping (UIImage?) -> Void) { grab(done) }
}

/// The ARView, telling its size to the camera.
final class Scene3DARView: ARView {
    var onLayout: ((CGSize) -> Void)? = nil
    override func layoutSubviews() { super.layoutSubviews(); onLayout?(bounds.size) }
}

/// The 3D picture of shell; key changes when the rooms change (it is rebuilt then).
struct Scene3DView: UIViewRepresentable {
    let shell: Shell3D
    let key: String
    let cam: Cam3D
    var shot: Shot3D? = nil

    func makeCoordinator() -> Scene3DCoordinator { Scene3DCoordinator() }

    func makeUIView(context: Context) -> Scene3DARView {
        let v = Scene3DARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        v.environment.background = .color(uiColor(BG3D))
        v.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR, .disableGroundingShadows, .disableCameraGrain,
                           .disableAREnvironmentLighting]
        context.coordinator.attach(v)
        return v
    }

    func updateUIView(_ v: Scene3DARView, context: Context) { context.coordinator.update(shell, key, cam, shot) }

    static func dismantleUIView(_ v: Scene3DARView, coordinator: Scene3DCoordinator) { coordinator.detach() }
}

final class Scene3DCoordinator: NSObject, UIGestureRecognizerDelegate {
    private struct Prim { let e: ModelEntity; let rgb: Int; let op: Double; let role: Role3; let group: Int; let wall: String?; var alpha: Double = -1 }
    private struct LineP { let e: ModelEntity; let group: Int; let wall: String; var alpha: Double = -1 }
    private weak var view: Scene3DARView?
    private var cam: Cam3D?
    private let anchor = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let content = Entity()
    private var key: String? = nil
    private var prims: [Prim] = []
    private var lines: [LineP] = []
    private var shell: Shell3D?

    func attach(_ v: Scene3DARView) {
        view = v
        camera.camera.fieldOfViewInDegrees = 40
        if #available(iOS 18.0, *) { camera.camera.fieldOfViewOrientation = .vertical }
        camera.camera.near = 0.1
        anchor.addChild(camera); anchor.addChild(content)
        v.scene.addAnchor(anchor)
        v.onLayout = { [weak self] s in self?.cam?.resize(s.width, s.height) }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 2; pan.delegate = self
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.delegate = self
        v.addGestureRecognizer(pan); v.addGestureRecognizer(pinch)
    }

    func detach() { cam?.onMove = nil; cam?.projector = nil; cam?.stop() }

    func update(_ s: Shell3D, _ k: String, _ c: Cam3D, _ shot: Shot3D?) {
        if cam !== c {
            cam = c
            c.projector = { [weak self] p in
                guard let v = self?.view else { return nil }
                return v.project(f3(p))
            }
        }
        if k != key {
            key = k
            build(s)
            camera.camera.far = Float(s.far)
            c.onMove = { [weak self] in self?.push() }
            c.load(s)
            if let v = view, v.bounds.width > 0 { c.resize(v.bounds.width, v.bounds.height) }
            push()
        }
        shot?.grab = { [weak self] done in
            guard let v = self?.view else { done(nil); return }
            v.snapshot(saveToHDR: false) { done($0) }
        }
    }

    private func push() {
        guard let c = cam else { return }
        let e = c.eye()
        camera.look(at: f3(c.tgt), from: f3(e), relativeTo: nil)
        cutaway(e, c.phi)
    }

    /* ---------------- materials and meshes ---------------- */

    /// A flat colour, shown exactly as given: without tone mapping, which darkens the prototype's colours unevenly
    /// (iOS 18 and newer; on iOS 17 the picture comes out a little darker).
    private func mat(_ rgb: Int, _ a: Double) -> UnlitMaterial {
        var m: UnlitMaterial
        if #available(iOS 18.0, *) { m = UnlitMaterial(applyPostProcessToneMap: false); m.color = .init(tint: uiColor(rgb)) }
        else { m = UnlitMaterial(color: uiColor(rgb)) }
        if a < 1 { m.blending = .transparent(opacity: .init(floatLiteral: Float(a))) }
        return m
    }

    private func mesh(_ pos: [SIMD3<Float>], _ idx: [UInt32]) -> MeshResource? {
        guard !idx.isEmpty else { return nil }
        var d = MeshDescriptor(name: "m")
        d.positions = MeshBuffers.Positions(pos)
        d.primitives = .triangles(idx)
        return try? MeshResource.generate(from: [d])
    }

    private func build(_ s: Shell3D) {
        content.children.removeAll()
        prims = []; lines = []; shell = s
        // faces: one entity per piece and lit colour
        for p in s.parts where !p.faces.isEmpty {
            var byColor: [Int: [Face3]] = [:]
            var order: [Int] = []
            for f in p.faces {
                let c = shade(p.rgb, f.n, s.light)
                if byColor[c] == nil { order.append(c) }
                byColor[c, default: []].append(f)
            }
            for c in order {
                var pos: [SIMD3<Float>] = [], idx: [UInt32] = []
                for f in byColor[c]! {
                    let base = UInt32(pos.count)
                    pos += f.pts.map(f3)
                    let tris = f.tris ?? (1..<max(1, f.pts.count - 1)).flatMap { [0, $0, $0 + 1] }
                    var t = 0
                    while t + 2 < tris.count {
                        let a = f.pts[tris[t]], b = f.pts[tris[t + 1]], cc = f.pts[tris[t + 2]]
                        // counter-clockwise seen from the face's outside
                        if (b - a).cross(cc - a).dot(f.n) >= 0 { idx += [base + UInt32(tris[t]), base + UInt32(tris[t + 1]), base + UInt32(tris[t + 2])] }
                        else { idx += [base + UInt32(tris[t]), base + UInt32(tris[t + 2]), base + UInt32(tris[t + 1])] }
                        t += 3
                    }
                }
                guard let m = mesh(pos, idx) else { continue }
                let e = ModelEntity(mesh: m, materials: [mat(c, p.op)])
                content.addChild(e)
                prims.append(Prim(e: e, rgb: c, op: p.op, role: p.role, group: p.group, wall: p.wall))
            }
        }
        // the dark wall outlines: thin bars
        for ed in s.edges where !ed.segs.isEmpty {
            var pos: [SIMD3<Float>] = [], idx: [UInt32] = []
            var i = 0
            while i + 1 < ed.segs.count { bar(&pos, &idx, ed.segs[i], ed.segs[i + 1], 0.012); i += 2 }
            guard let m = mesh(pos, idx) else { continue }
            let e = ModelEntity(mesh: m, materials: [mat(WALL_INK, 1)])
            content.addChild(e)
            lines.append(LineP(e: e, group: ed.group, wall: ed.wall))
        }
        // the floor grid (three.js GridHelper: the middle lines darker)
        let half = s.gridSize / 2, step = s.gridSize / Double(max(1, s.gridDiv)), center = s.gridDiv % 2 == 0 ? s.gridDiv / 2 : -1
        var mp: [SIMD3<Float>] = [], mi: [UInt32] = [], rp: [SIMD3<Float>] = [], ri: [UInt32] = []
        for i in 0...s.gridDiv {
            let k = -half + Double(i) * step, y = -0.002
            let a1 = V3(s.gridCx - half, y, s.gridCz + k), b1 = V3(s.gridCx + half, y, s.gridCz + k)
            let a2 = V3(s.gridCx + k, y, s.gridCz - half), b2 = V3(s.gridCx + k, y, s.gridCz + half)
            if i == center { flat(&mp, &mi, a1, b1, 0.012); flat(&mp, &mi, a2, b2, 0.012) }
            else { flat(&rp, &ri, a1, b1, 0.01); flat(&rp, &ri, a2, b2, 0.01) }
        }
        if let m = mesh(rp, ri) { content.addChild(ModelEntity(mesh: m, materials: [mat(0xDCE4F0, 1)])) }
        if let m = mesh(mp, mi) { content.addChild(ModelEntity(mesh: m, materials: [mat(0xC3CEDF, 1)])) }
    }

    /// A segment as a thin square bar, both windings (seen from any side).
    private func bar(_ pos: inout [SIMD3<Float>], _ idx: inout [UInt32], _ a: V3, _ b: V3, _ w: Double) {
        let d = (b - a).unit
        if (b - a).len < 1e-6 { return }
        let ref = abs(d.y) < 0.9 ? V3(0, 1, 0) : V3(1, 0, 0)
        let u = d.cross(ref).unit * (w / 2), v = d.cross(u).unit * (w / 2)
        let base = UInt32(pos.count)
        for p in [a, b] { for o in [u + v, u - v, V3(0, 0, 0) - u - v, v - u] { pos.append(f3(p + o)) } }
        for k in 0..<4 {
            let k1 = (k + 1) % 4
            let q: [UInt32] = [base + UInt32(k), base + UInt32(k1), base + 4 + UInt32(k1), base + UInt32(k), base + 4 + UInt32(k1), base + 4 + UInt32(k)]
            idx += q; idx += [q[0], q[2], q[1], q[3], q[5], q[4]]
        }
    }

    /// A segment on the floor as a flat strip facing up.
    private func flat(_ pos: inout [SIMD3<Float>], _ idx: inout [UInt32], _ a: V3, _ b: V3, _ w: Double) {
        let d = (b - a).unit, n = V3(-d.z, 0, d.x) * (w / 2)
        let base = UInt32(pos.count)
        pos += [f3(a + n), f3(b + n), f3(b - n), f3(a - n)]
        idx += [base, base + 2, base + 1, base, base + 3, base + 2, base, base + 1, base + 2, base, base + 2, base + 3]
    }

    /// Walls between the camera and the room's middle become see-through (prototype draw3D).
    private func cutaway(_ eye: V3, _ phi: Double) {
        guard let s = shell else { return }
        let top = phi < 0.35
        func facing(_ g: Int, _ w: String?) -> Bool {
            guard !top, let w, g < s.groups.count, let n = s.groups[g].normals[w] else { return false }
            let gp = s.groups[g], dx = eye.x - gp.cx, dz = eye.z - gp.cz
            return dx * n.0 + dz * n.1 > 0.4 * hypot(dx, dz)
        }
        for i in prims.indices {
            let p = prims[i], f = facing(p.group, p.wall)
            let a: Double = p.role == .wall ? (f ? 0.14 : 1) : p.role == .opening ? (f ? min(0.12, p.op) : p.op) : p.op
            if a != p.alpha { prims[i].alpha = a; p.e.model?.materials = [mat(p.rgb, a)] }
        }
        for i in lines.indices {
            let l = lines[i], a = facing(l.group, l.wall) ? 0.35 : 1
            if a != l.alpha { lines[i].alpha = a; l.e.model?.materials = [mat(WALL_INK, a)] }
        }
    }

    /* ---------------- fingers ---------------- */

    /// Turning, moving and pinching go together; the page around the picture does not scroll with them.
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { o.view === view }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        guard let v = view, let c = cam else { return }
        if g.state == .began { c.stop() }
        let t = g.translation(in: v)
        g.setTranslation(.zero, in: v)
        if g.numberOfTouches >= 2 { c.pan(t.x, t.y) } else { c.rotate(t.x, t.y) }
    }

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        guard let c = cam, g.scale > 0 else { return }
        c.zoom(1 / Double(g.scale)); g.scale = 1
    }
}

/// The picture with labels placed at points of it, each centred on its point.
struct Scene3D<Overlay: View>: View {
    let shell: Shell3D
    let key: String
    let cam: Cam3D
    var shot: Shot3D? = nil
    var points: [V3] = []
    var label: (Int) -> AnyView = { _ in AnyView(EmptyView()) }
    @ViewBuilder var overlay: Overlay

    var body: some View {
        ZStack {
            Scene3DView(shell: shell, key: key, cam: cam, shot: shot)
            let _ = cam.tick
            ForEach(points.indices, id: \.self) { i in
                if let p = cam.project(points[i]) { label(i).position(p) }
            }
            overlay
        }
        .background(Color(uiColor: uiColor(BG3D)))
    }
}

/// A wall letter or a room name over the picture (prototype .three .lbl).
struct Lbl3D: View {
    let text: String
    var body: some View {
        T(text, ui(12, 600, Color(argb: 0xFF0F172A)), lines: 1)
            .padding(.horizontal, 6).frame(minWidth: 24, minHeight: 24)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(Color(argb: 0xFF0F172A), lineWidth: 1.33))
            .fixedSize()
            .allowsHitTesting(false)
    }
}

/// A room name that zooms to the room (ux .lbl.go); on while the view is on that room. The touch area reaches past it.
struct RoomLbl3D: View {
    let text: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        T(text, ui(12.5, 700, on ? .white : Color(argb: 0xFF0F172A)), lines: 1)
            .padding(.horizontal, 10).frame(minHeight: 28)
            .background(Capsule().fill(on ? G.cobalt : Color.white))
            .overlay(Capsule().strokeBorder(on ? G.cobalt : Color(argb: 0xFF0F172A), lineWidth: 1.33))
            .boxShadow(Color(argb: 0x1F101828), blur: 8, y: 2)
            .padding(.horizontal, 4).padding(.vertical, 9)
            .fixedSize()
            .pressable(0.96, action)
            .accessibilityIdentifier("v3.room")
    }
}

/// The round white pill on the picture: "Add to report" (ux .v3-shot) and "All" (.v3-all).
struct ShotPill: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        HStack(spacing: 7) { MIcon(icon, G.cobalt, 18, 2); T(label, ui(13.5, 700), lines: 1) }
            .padding(.leading, 12).padding(.trailing, 15).frame(height: 42)
            .background(Capsule().fill(G.sheet(0.55)))
            .boxShadow(Color(argb: 0x24101828), blur: 10, y: 2)
            .pressable(0.97, action)
    }
}
