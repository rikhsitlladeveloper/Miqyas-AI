import SwiftUI
import RealityKit
import UIKit
import Observation

/*
 * The 3D picture (prototype mount3D / draw3D and the ux module's camera limits), drawn with RealityKit in an ARView
 * without the camera feed (iOS 17 has no non-AR RealityView). Lit ("modern furniture 3D", 25 Oct 2026): every part a
 * PhysicallyBasedMaterial from its Look (Geo/Look.swift, Three/Lit3D.swift) with normals and texture coordinates, a
 * studio environment for the reflections, a warm sun with soft shadows on strong phones, thin soft outlines on the
 * furniture (Three/RenderTier.swift picks how much). The old picture stays as the flat fallback: the colours worked
 * out the way three.js lights the prototype's Lambert walls (geo shade), handed over as flat unlit colours.
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
    /// "From the corner" turns the camera back to this (a corner piece with its corner on the left is seen from the right).
    @ObservationIgnored var cornerTheta = Double.pi / 2 + 0.75
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
        // a tiler's tiles changing is not a new room: the camera stays
        let key = [s.L, s.W, s.H, Double(s.parts.filter { !$0.tile }.count)]
        if key == shellKey { return }
        shellKey = key
        stop(); focus = nil
        dims = [s.L, s.W, s.H]
        tgt = s.tgt; r = s.r
        if let t = s.theta { theta = t }
        cornerTheta = s.theta ?? .pi / 2 + 0.75
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
        if top { phi = 0.07; theta = .pi / 2 } else { phi = 0.95; theta = cornerTheta }
        tgt = V3(dims[0] / 2, dims[2] * 0.3, dims[1] / 2)
        r = rFit ?? (max(dims[0], dims[1]) * 2.2 + 2.5)
        moved()
    }

    /// The ray from the eye through point (x, y) of the picture: its start and direction (the inverse of project).
    func ray(_ x: CGFloat, _ y: CGFloat) -> (V3, V3) {
        let e = eye(), f = (tgt - e).unit
        let s = f.cross(V3(0, 1, 0)).unit, u = s.cross(f)
        let k = tan(FOV_HALF)
        let nx = 2 * Double(x) / Double(max(1, w)) - 1, ny = 1 - 2 * Double(y) / Double(max(1, h))
        return (e, (f + s * (nx * k * aspect) + u * (ny * k)).unit)
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

/// The 3D picture of shell; key changes when the rooms change (it is rebuilt then). baseKey, when given, is what the
/// walls and the floor are built from: while it stays the same, a new key rebuilds only the furniture (doors opening).
struct Scene3DView: UIViewRepresentable {
    let shell: Shell3D
    let key: String
    var baseKey: String? = nil
    let cam: Cam3D
    var shot: Shot3D? = nil
    /// A short tap with one finger (it opens a door), in points.
    var onTap: ((CGPoint) -> Void)? = nil

    func makeCoordinator() -> Scene3DCoordinator { Scene3DCoordinator() }

    func makeUIView(context: Context) -> Scene3DARView {
        let v = Scene3DARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        v.environment.background = .color(uiColor(BG3D))
        context.coordinator.attach(v, Quality3.current())
        return v
    }

    func updateUIView(_ v: Scene3DARView, context: Context) { context.coordinator.onTap = onTap; context.coordinator.update(shell, key, baseKey, cam, shot) }

    static func dismantleUIView(_ v: Scene3DARView, coordinator: Scene3DCoordinator) { coordinator.detach() }
}

final class Scene3DCoordinator: NSObject, UIGestureRecognizerDelegate {
    /// A part on screen: its look (in the flat picture, Look(rgb: its lit colour)); its own opacity is the look's alpha.
    private struct Prim { let e: ModelEntity; let look: Look; let role: Role3; let group: Int; let wall: String?; var alpha: Double = -1 }
    /// An outline: its colour and own opacity (the soft furniture lines are faint).
    private struct LineP { let e: ModelEntity; let group: Int; let wall: String; let rgb: Int; let op: Double; var alpha: Double = -1 }
    private struct MatKey: Hashable { let look: Look; let alpha: Double }
    private weak var view: Scene3DARView?
    private var cam: Cam3D?
    private let anchor = AnchorEntity(world: .zero)
    private let camera = PerspectiveCamera()
    private let content = Entity()
    /// The warm sun of the lit picture (mockup: #FFF0DE from above the front corner).
    private let sun = DirectionalLight()
    private var tier: Quality3 = .high
    private var lit: Bool { tier != .flat }
    private var mats: [MatKey: RealityKit.Material] = [:]
    private var key: String? = nil
    private var baseKey: String? = nil
    private var prims: [Prim] = []
    private var lines: [LineP] = []
    private var shell: Shell3D?
    var onTap: ((CGPoint) -> Void)? = nil

    func attach(_ v: Scene3DARView, _ q: Quality3) {
        view = v
        tier = q
        setLight(v)
        camera.camera.fieldOfViewInDegrees = 40
        if #available(iOS 18.0, *) { camera.camera.fieldOfViewOrientation = .vertical }
        camera.camera.near = 0.1
        anchor.addChild(camera); anchor.addChild(content)
        if lit { anchor.addChild(sun) }
        v.scene.addAnchor(anchor)
        v.onLayout = { [weak self] s in self?.cam?.resize(s.width, s.height) }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 2; pan.delegate = self
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        pinch.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTapped(_:)))
        tap.delegate = self
        v.addGestureRecognizer(pan); v.addGestureRecognizer(pinch); v.addGestureRecognizer(tap)
    }

    func detach() { cam?.onMove = nil; cam?.projector = nil; cam?.stop() }

    /// The view's light for the tier. high: HDR with tone mapping, the studio's reflections, grounding shadows; low: the
    /// same studio a little brighter, no HDR and no shadows; flat: none (unlit colours), as before.
    private func setLight(_ v: Scene3DARView) {
        switch tier {
        case .flat:
            v.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR, .disableGroundingShadows, .disableCameraGrain,
                               .disableAREnvironmentLighting]
            return
        case .high: v.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain]
        case .low: v.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain, .disableHDR, .disableGroundingShadows]
        }
        Scene3DCoordinator.studio { [weak v] env in v?.environment.lighting.resource = env }
        v.environment.lighting.intensityExponent = tier == .high ? 0.25 : 0.5
        var c = DirectionalLightComponent()
        c.color = uiColor(0xFFF0DE)
        c.intensity = tier == .high ? 1500 : 1900
        sun.light = c
    }

    /// The sun over the scene's middle from the shell's light direction; soft shadows on the high tier (iOS 18: there the
    /// walls can be kept from casting them, see shadowRules).
    private func placeSun(_ s: Shell3D) {
        guard lit else { return }
        let t = V3(s.tgt.x, 0.6, s.tgt.z)
        sun.look(at: f3(t), from: f3(t + s.light.unit * 10), relativeTo: nil)
        sun.shadow = nil
        guard tier == .high else { return }
        if #available(iOS 18.0, *) {
            let reach = min(40, max(8, s.r * 1.6 + max(s.L, s.W)))
            sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: Float(reach), depthBias: 1.5)
        }
    }

    /// Who casts shadows (iOS 18): not the walls, openings or glass (a wall between the sun and the room would darken it;
    /// a see-through wall must not); the furniture also drops a soft grounding shadow on the high tier.
    private func shadowRules(_ e: ModelEntity, _ role: Role3, _ look: Look) {
        guard tier == .high else { return }
        if #available(iOS 18.0, *) {
            if role == .wall || role == .opening || role == .glass || look.alpha < 1 {
                e.components.set(DynamicLightShadowComponent(castsShadow: false))
            } else if role == .furn {
                e.components.set(GroundingShadowComponent(castsShadow: true))
            }
        }
    }

    /// The material of look at opacity a: lit (made once per look and opacity) or the flat colour.
    private func material(_ look: Look, _ a: Double) -> RealityKit.Material {
        if !lit { return mat(look.rgb, a) }
        let k = MatKey(look: look, alpha: a)
        if let m = mats[k] { return m }
        let m = Scene3DCoordinator.litMaterial(look, alpha: a, tier: tier)
        mats[k] = m
        return m
    }

    func update(_ s: Shell3D, _ k: String, _ bk: String?, _ c: Cam3D, _ shot: Shot3D?) {
        if cam !== c {
            cam = c
            c.projector = { [weak self] p in
                guard let v = self?.view else { return nil }
                return v.project(f3(p))
            }
        }
        if k != key {
            // the same walls and floor: only the furniture is built again
            let onlyFurn = bk != nil && bk == baseKey && shell != nil
            key = k; baseKey = bk
            if onlyFurn { rebuildFurn(s) } else { build(s) }
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
        addParts(s.parts, s.light)
        addEdges(s.edges)
        addGrid(s)
        placeSun(s)
    }

    /// The furniture taken out and built again from s; the walls, the floor and the grid stay as they are.
    private func rebuildFurn(_ s: Shell3D) {
        for p in prims where p.role == .furn { p.e.removeFromParent() }
        prims.removeAll { $0.role == .furn }
        for l in lines where l.wall.hasPrefix("furn ") { l.e.removeFromParent() }
        lines.removeAll { $0.wall.hasPrefix("furn ") }
        shell = s
        addParts(s.parts.filter { $0.role == .furn }, s.light)
        addEdges(s.edges.filter { $0.wall.hasPrefix("furn ") })
    }

    /// A face's triangles, counter-clockwise seen from its outside, its corners numbered from base.
    private func triangles(_ f: Face3, _ base: UInt32, _ idx: inout [UInt32]) {
        let tris = f.tris ?? (1..<max(1, f.pts.count - 1)).flatMap { [0, $0, $0 + 1] }
        var t = 0
        while t + 2 < tris.count {
            let a = f.pts[tris[t]], b = f.pts[tris[t + 1]], cc = f.pts[tris[t + 2]]
            if (b - a).cross(cc - a).dot(f.n) >= 0 { idx += [base + UInt32(tris[t]), base + UInt32(tris[t + 1]), base + UInt32(tris[t + 2])] }
            else { idx += [base + UInt32(tris[t]), base + UInt32(tris[t + 2]), base + UInt32(tris[t + 1])] }
            t += 3
        }
    }

    /// Faces: lit, one entity per part (a wall's furniture in one look); flat, one per part and lit colour.
    private func addParts(_ parts: [Part3], _ light: V3) {
        for p in parts where !p.faces.isEmpty {
            if !lit { addFlat(p, light); continue }
            let look = p.look ?? roleLook(p.role, p.rgb, p.op, tile: p.tile)
            guard let m = litMesh(p.faces, look) else { continue }
            let e = ModelEntity(mesh: m, materials: [material(look, look.alpha)])
            shadowRules(e, p.role, look)
            content.addChild(e)
            prims.append(Prim(e: e, look: look, role: p.role, group: p.group, wall: p.wall))
        }
    }

    /// The faces with their normals and texture coordinates (metres along the grain over the look's repeat).
    private func litMesh(_ faces: [Face3], _ look: Look) -> MeshResource? {
        var pos: [SIMD3<Float>] = [], nrm: [SIMD3<Float>] = [], uvs: [SIMD2<Float>] = [], idx: [UInt32] = []
        for f in faces {
            let base = UInt32(pos.count)
            pos += f.pts.map(f3)
            nrm += Array(repeating: f3(f.n), count: f.pts.count)
            uvs += faceUVs(f, look).map { SIMD2<Float>(Float($0.x), Float($0.y)) }
            triangles(f, base, &idx)
        }
        guard !idx.isEmpty else { return nil }
        var d = MeshDescriptor(name: "m")
        d.positions = MeshBuffers.Positions(pos)
        d.normals = MeshBuffers.Normals(nrm)
        d.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
        d.primitives = .triangles(idx)
        return try? MeshResource.generate(from: [d])
    }

    /// The flat picture's part: one entity per lit colour.
    private func addFlat(_ p: Part3, _ light: V3) {
        var byColor: [Int: [Face3]] = [:]
        var order: [Int] = []
        for f in p.faces {
            let c = shade(p.slab && f.n.y > 0.9 ? slabTop(p.rgb) : p.rgb, f.n, light)
            if byColor[c] == nil { order.append(c) }
            byColor[c, default: []].append(f)
        }
        for c in order {
            var pos: [SIMD3<Float>] = [], idx: [UInt32] = []
            for f in byColor[c]! {
                let base = UInt32(pos.count)
                pos += f.pts.map(f3)
                triangles(f, base, &idx)
            }
            guard let m = mesh(pos, idx) else { continue }
            let e = ModelEntity(mesh: m, materials: [mat(c, p.op)])
            content.addChild(e)
            prims.append(Prim(e: e, look: Look(rgb: c, alpha: p.op), role: p.role, group: p.group, wall: p.wall))
        }
    }

    /// The outlines: thin bars. The walls' stay dark; the furniture's, in the lit picture, are thin and faint (mockup
    /// finalize: #1B2230 at 12–16 %), the worktops' light.
    private func addEdges(_ edges: [Edges3]) {
        for ed in edges where !ed.segs.isEmpty {
            let soft = lit && ed.wall.hasPrefix("furn ")
            let slab = ed.rgb == SLAB_LINE
            let w = soft ? 0.0045 : 0.012
            let rgb = soft && !slab ? 0x1B2230 : ed.rgb
            let op: Double = !soft ? 1 : slab ? 0.5 : tier == .low ? 0.16 : 0.13
            var pos: [SIMD3<Float>] = [], idx: [UInt32] = []
            var i = 0
            // a faint bar drawn from both sides would show twice as dark: only its outside then
            while i + 1 < ed.segs.count { bar(&pos, &idx, ed.segs[i], ed.segs[i + 1], w, both: !soft); i += 2 }
            guard let m = mesh(pos, idx) else { continue }
            let e = ModelEntity(mesh: m, materials: [mat(rgb, op)])
            // outlines cast no shadows
            if lit { if #available(iOS 18.0, *) { e.components.set(DynamicLightShadowComponent(castsShadow: false)) } }
            content.addChild(e)
            lines.append(LineP(e: e, group: ed.group, wall: ed.wall, rgb: rgb, op: op))
        }
    }

    private func addGrid(_ s: Shell3D) {
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

    /// A segment as a thin square bar, both windings (seen from any side), or only its outside (both false).
    private func bar(_ pos: inout [SIMD3<Float>], _ idx: inout [UInt32], _ a: V3, _ b: V3, _ w: Double, both: Bool = true) {
        let d = (b - a).unit
        if (b - a).len < 1e-6 { return }
        let ref = abs(d.y) < 0.9 ? V3(0, 1, 0) : V3(1, 0, 0)
        let u = d.cross(ref).unit * (w / 2), v = d.cross(u).unit * (w / 2)
        let base = UInt32(pos.count)
        for p in [a, b] { for o in [u + v, u - v, V3(0, 0, 0) - u - v, v - u] { pos.append(f3(p + o)) } }
        for k in 0..<4 {
            let k1 = (k + 1) % 4
            let q: [UInt32] = [base + UInt32(k), base + UInt32(k1), base + 4 + UInt32(k1), base + UInt32(k), base + 4 + UInt32(k1), base + 4 + UInt32(k)]
            // q faces into the bar; the reversed triangles face out
            if both { idx += q }
            idx += [q[0], q[2], q[1], q[3], q[5], q[4]]
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
        // the wall facing the eye goes see-through, its doors and windows with it; the furniture on it stays solid
        for i in prims.indices {
            let p = prims[i], f = facing(p.group, p.wall), op = p.look.alpha
            let a: Double = p.role == .wall ? (f ? 0.14 : 1) : p.role == .opening ? (f ? min(0.12, op) : op) : op
            if a != p.alpha { prims[i].alpha = a; p.e.model?.materials = [material(p.look, a)] }
        }
        for i in lines.indices {
            let l = lines[i], a = l.op * (facing(l.group, l.wall) ? 0.35 : 1)
            if a != l.alpha { lines[i].alpha = a; l.e.model?.materials = [mat(l.rgb, a)] }
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

    @objc private func onTapped(_ g: UITapGestureRecognizer) {
        guard let v = view, g.state == .ended else { return }
        onTap?(g.location(in: v))
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
    /// What the walls and floor are built from (see Scene3DView): nil rebuilds everything on a new key.
    var baseKey: String? = nil
    let cam: Cam3D
    var shot: Shot3D? = nil
    var points: [V3] = []
    var label: (Int) -> AnyView = { _ in AnyView(EmptyView()) }
    var onTap: ((CGPoint) -> Void)? = nil
    @ViewBuilder var overlay: Overlay

    var body: some View {
        ZStack {
            Scene3DView(shell: shell, key: key, baseKey: baseKey, cam: cam, shot: shot, onTap: onTap)
            let _ = cam.tick
            // kept inside the picture, under the buttons along its top (a wall letter must not sit on the tabs above or under a button)
            GeometryReader { geo in
                ForEach(points.indices, id: \.self) { i in
                    if let p = cam.project(points[i]) { label(i).position(lbl3DAt(p, geo.size)) }
                }
            }
            .clipped()
            overlay
        }
        .background(Color(uiColor: uiColor(BG3D)))
    }
}

/// Where a label's centre goes: its point, kept inside a picture of size s (a margin at the sides and the bottom, the
/// buttons' band along the top).
private func lbl3DAt(_ p: CGPoint, _ s: CGSize) -> CGPoint {
    let hw: CGFloat = 16, hh: CGFloat = 14, pad: CGFloat = 4, top: CGFloat = 56
    let x = min(max(p.x, pad + hw), max(pad + hw, s.width - pad - hw))
    let yLo = min(top + hh, max(hh, s.height - hh))
    let y = min(max(p.y, yLo), max(top + hh, s.height - pad - hh))
    return CGPoint(x: x, y: y)
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
