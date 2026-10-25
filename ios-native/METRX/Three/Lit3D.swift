import RealityKit
import UIKit
import Metal

/*
 * The lit 3D's materials, decor pictures and studio light ("modern furniture 3D" part 1; the approved mockup's mats() and
 * makeEnv()). A Look (Geo/Look.swift) becomes a PhysicallyBasedMaterial; the pictures come from tex/ in the app (the
 * Android app's assets/tex folder, shared through project.yml) and a missing one leaves the plain colour. Kept on the
 * 3D view's coordinator, so it runs where the rest of the RealityKit code runs.
 */

extension Scene3DCoordinator {
    /// Pictures loaded so far, by "id@px"; the ones with no file.
    private static var texLoaded: [String: TextureResource] = [:]
    private static var texMissing: Set<String> = []
    /// The studio light, made once (nil if it could not be made: RealityKit's own then).
    private static var studioMade = false
    private static var studioEnv: EnvironmentResource? = nil
    private static var studioWait: [(EnvironmentResource) -> Void] = []

    /// The material for look at opacity alpha on a phone of quality tier (high or low).
    static func litMaterial(_ look: Look, alpha: Double, tier: Quality3) -> PhysicallyBasedMaterial {
        let l = tier == .low ? look.lowered() : look
        var m = PhysicallyBasedMaterial()
        if let id = l.tex, let t = texture(id, tier.texPx) {
            m.baseColor = .init(tint: uiColor(l.texTint), texture: repeating(t))
        } else {
            m.baseColor = .init(tint: uiColor(l.rgb))
        }
        m.roughness = .init(scale: Float(min(1, max(0, l.roughness))))
        m.metallic = .init(scale: Float(min(1, max(0, l.metallic))))
        if l.clearcoat > 0 {
            m.clearcoat = .init(scale: Float(l.clearcoat))
            m.clearcoatRoughness = .init(scale: Float(l.clearcoatRoughness))
        }
        if l.emissive > 0 {
            m.emissiveColor = .init(color: uiColor(l.emissiveRgb ?? l.rgb))
            m.emissiveIntensity = Float(l.emissive)
        }
        if alpha < 1 { m.blending = .transparent(opacity: .init(floatLiteral: Float(max(0, alpha)))) }
        return m
    }

    /// A picture repeating across the surface (texture coordinates are in metres, well past 0…1), smooth when far.
    private static func repeating(_ t: TextureResource) -> MaterialParameters.Texture {
        let d = MTLSamplerDescriptor()
        d.sAddressMode = .repeat; d.tAddressMode = .repeat
        d.minFilter = .linear; d.magFilter = .linear; d.mipFilter = .linear
        d.maxAnisotropy = 4
        var x = MaterialParameters.Texture(t)
        x.sampler = MaterialParameters.Texture.Sampler(d)
        return x
    }

    /// Decor picture id at px (512 or 256; the other size, or one without a size, when that is all there is): the data's
    /// decor id goes to its file and colour (RenderTier.swift texSource, Android's table); nil when tex/ has no file for
    /// it. UIImage reads the folder's WebP pictures (iOS 14 and later).
    static func texture(_ id: String, _ px: Int) -> TextureResource? {
        let k = "\(id)@\(px)"
        if let t = texLoaded[k] { return t }
        if texMissing.contains(k) { return nil }
        let root = Bundle.main.bundleURL.appendingPathComponent("tex", isDirectory: true)
        let fm = FileManager.default
        if let src = texSource(id), fm.fileExists(atPath: root.path) {
            for name in texFiles(src.file, px) {
                let u = root.appendingPathComponent(name)
                guard fm.fileExists(atPath: u.path), let img0 = UIImage(contentsOfFile: u.path)?.cgImage else { continue }
                let img = src.tinted ? (tinted(img0, src.avg) ?? img0) : img0
                if let t = try? TextureResource.generate(from: img, options: .init(semantic: .color)) {
                    texLoaded[k] = t
                    return t
                }
            }
        }
        texMissing.insert(k)
        return nil
    }

    /// img recoloured so its average colour becomes avg (sRGB; each channel scaled, kept within white): Halifax tobacco
    /// from the Halifax picture, dark oak from the wenge one, as Android does it.
    private static func tinted(_ img: CGImage, _ avg: Int?) -> CGImage? {
        let w = img.width, h = img.height
        guard let avg, w > 0, h > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        c.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = c.data else { return nil }
        let px = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var sum = [0.0, 0.0, 0.0]
        for i in 0..<(w * h) { for k in 0..<3 { sum[k] += Double(px[i * 4 + k]) } }
        let want = [Double(avg >> 16 & 0xFF), Double(avg >> 8 & 0xFF), Double(avg & 0xFF)]
        let mul = (0..<3).map { k in want[k] / max(1, sum[k] / Double(w * h)) }
        for i in 0..<(w * h) {
            for k in 0..<3 {
                let v = Double(px[i * 4 + k]) * mul[k]
                px[i * 4 + k] = UInt8(min(255, max(0, v.rounded())))
            }
        }
        return c.makeImage()
    }

    /// The studio the reflections and the soft light come from (mockup makeEnv): light walls, a bright ceiling with light
    /// strips, two bright windows, a darker warm floor, a few dark pieces for the gloss to mirror.
    /// Made once, off the first call (the SDK's equirectangular init may be async); [done] gets it as soon as it is ready.
    static func studio(_ done: @escaping (EnvironmentResource) -> Void) {
        if let e = studioEnv { done(e); return }
        studioWait.append(done)
        if studioMade { return }
        studioMade = true
        // iOS 17: the old generate() is gone from the SDK and the new init is iOS 18+; RealityKit's own light is used there
        guard #available(iOS 18.0, *), let cg = studioImage(512, 256) else { return }
        Task { @MainActor in
            guard let e = try? await EnvironmentResource(equirectangular: cg) else { return }
            studioEnv = e
            let w = studioWait; studioWait = []
            w.forEach { $0(e) }
        }
    }

    /// The studio as an equirectangular picture w × h (top: straight up).
    private static func studioImage(_ w: Int, _ h: Int) -> CGImage? {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1; f.opaque = true
        let W = CGFloat(w), H = CGFloat(h)
        let img = UIGraphicsImageRenderer(size: CGSize(width: W, height: H), format: f).image { r in
            let c = r.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            func band(_ y0: CGFloat, _ y1: CGFloat, _ a: Int, _ b: Int) {
                guard let g = CGGradient(colorsSpace: space, colors: [uiColor(a).cgColor, uiColor(b).cgColor] as CFArray, locations: [0, 1]) else { return }
                c.saveGState(); c.clip(to: CGRect(x: 0, y: y0 * H, width: W, height: (y1 - y0) * H))
                c.drawLinearGradient(g, start: CGPoint(x: 0, y: y0 * H), end: CGPoint(x: 0, y: y1 * H), options: [])
                c.restoreGState()
            }
            func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ rgb: Int) {
                c.setFillColor(uiColor(rgb).cgColor); c.fill(CGRect(x: x0 * W, y: y0 * H, width: (x1 - x0) * W, height: (y1 - y0) * H))
            }
            // ceiling, walls, floor
            band(0, 0.24, 0xF6F3EE, 0xEAE6DF)
            band(0.24, 0.5, 0xC9C3BA, 0xB7B1A8)
            band(0.5, 0.56, 0xB7B1A8, 0x8A7A69)
            band(0.56, 1, 0x7A6A5A, 0x4A3B2E)
            // light strips across the ceiling
            for y in [0.05, 0.11, 0.17] as [CGFloat] { rect(0, y, 1, y + 0.018, 0xFFFFFF) }
            // windows, a little warm
            rect(0.08, 0.28, 0.30, 0.50, 0xFFFDF7); rect(0.56, 0.30, 0.68, 0.50, 0xFBF8F1); rect(0.84, 0.32, 0.90, 0.48, 0xF3EFE7)
            // dark pieces in the room
            rect(0.36, 0.47, 0.50, 0.58, 0x2B2D31); rect(0.72, 0.40, 0.77, 0.60, 0x6B5240); rect(0.93, 0.44, 0.99, 0.58, 0x8C8278)
        }
        return img.cgImage
    }
}
