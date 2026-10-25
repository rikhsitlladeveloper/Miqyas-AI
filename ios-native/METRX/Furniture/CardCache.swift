import UIKit
import ImageIO

/*
 * The gallery's cards ("modern furniture 3D" part 4, 25 Oct 2026; founder: cards are snapshots of the real 3D, made
 * once and kept): what a card is made from (its key), how big it is, where the camera stands, and the cache that keeps
 * the pictures, in memory and in Caches/cards on disk. Plain UIKit, no RealityKit, so the unit tests use it all. The
 * offscreen 3D is Three/CardShots.swift, the queue that asks for the cards Furniture/GalleryCards.swift.
 */

/// Bumped whenever the cards' picture changes (camera, light, background, size): every card on disk is made again.
/// 2: modern wardrobes and the brighter studio with its grey floor (modern 3D part 5).
/// 3: beds, tables, the bar, hall panels and the vanity's basin in the modern style (part 6b, Geo/ItemsScene3D.swift).
let CARD_RENDER_VERSION = 4

/// The cards' background (the approved mockup's makeCards clear colour).
let CARD_BG = 0xE4E8F0

/// How high the card's camera looks down at the piece, radians above level (the mockup's views: polar about 1.15).
let CARD_EL = 0.42

/// A card's picture size in points and its scale. The cards are 200 : 170, as on the gallery; a weaker phone's are
/// smaller.
struct CardSpec: Equatable {
    let pt: CGSize
    let scale: CGFloat
    var pxW: Int { Int((pt.width * scale).rounded()) }
    var pxH: Int { Int((pt.height * scale).rounded()) }
}

/// The card size for a quality tier: high 300 × 255 pt, low (and the flat drawing) 220 × 187 pt, both at 2×.
func cardSpec(_ t: Quality3) -> CardSpec {
    t == .high ? CardSpec(pt: CGSize(width: 300, height: 255), scale: 2) : CardSpec(pt: CGSize(width: 220, height: 187), scale: 2)
}

/// 64-bit FNV-1a of s, the same on every launch (Swift's own hashing is seeded per launch, no good for file names).
func cardHash(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf29ce484222325
    for b in s.utf8 { h ^= UInt64(b); h = h &* 0x100000001b3 }
    return h
}

/// A short, stable signature of v: its JSON with sorted keys, hashed ("x" if it cannot be written).
func cardSig<T: Encodable>(_ v: T) -> String {
    let e = JSONEncoder()
    e.outputFormatting = [.sortedKeys]
    guard let d = try? e.encode(v), let s = String(data: d, encoding: .utf8) else { return "x" }
    return String(cardHash(s), radix: 16)
}

/// What a card's picture is made from: the model, the picture's size, the order's design style, the boards (their
/// signature), the piece's handle, the quality tier, the workshop (its signature: the units' heights and gaps) and the
/// renderer's version. Another value of any of them is another picture.
struct CardKey: Hashable {
    let model: String
    let pxW: Int, pxH: Int
    let scale: CGFloat
    let style: String
    let mats: String
    let handle: String
    let tier: String
    let ws: String
    let version: Int

    /// The file name (without its extension): readable at the front, the hash of everything at the end.
    var name: String {
        let all = [model, "\(pxW)x\(pxH)@\(scale)", style, mats, handle, tier, ws, "\(version)"].joined(separator: "|")
        let safe = String(model.map { $0.isLetter || $0.isNumber ? $0 : "_" })
        return "\(safe)-\(tier)-\(pxW)x\(pxH)-v\(version)-" + String(cardHash(all), radix: 16)
    }
}

/// The key of model's card: matsSig and wsSig are cardSig of the boards and of the workshop (worked out once for all
/// the cards).
func cardKey(_ model: String, _ spec: CardSpec, style: String, matsSig: String, handle: String, tier: Quality3, wsSig: String,
             version: Int = CARD_RENDER_VERSION) -> CardKey {
    CardKey(model: model, pxW: spec.pxW, pxH: spec.pxH, scale: spec.scale, style: style, mats: matsSig, handle: handle, tier: tier.rawValue,
            ws: wsSig, version: version)
}

/// The piece a card shows: model id at its usual sizes, in the order's design style (as addPiece would make it).
func cardPiece(_ id: String, _ ws: Workshop, _ style: String) -> Furniture? {
    guard let m = fModel(id) else { return nil }
    return styledNew(pieceOf(m, [:], ws, ""), style)
}

/// Where the card's camera looks from and how far: from direction az round the piece (Furniture/PieceView.swift's az0),
/// el above level, every corner of ext in a picture of aspect (width / height) with margin to spare, the bounds'
/// picture centred. half: half the vertical field of view. back: from the target towards the eye.
func cardAim(_ ext: [V3], az: Double, el: Double, aspect: Double, half: Double = FOV_HALF, margin: Double = 1.12) -> (tgt: V3, r: Double, back: V3) {
    let back = V3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
    guard !ext.isEmpty else { return (V3(0, 0.5, 0), 3, back) }
    let fw = back * -1, rt = fw.cross(V3(0, 1, 0)).unit, up = rt.cross(fw)
    let tv = tan(half), th = tv * max(0.2, aspect)
    var m = ext.reduce(V3(0, 0, 0)) { $0 + $1 } * (1 / Double(ext.count))
    func fitAt(_ c: V3) -> Double {
        ext.map { q in let v = q - c; return margin * max(abs(v.dot(rt)) / th, abs(v.dot(up)) / tv) - v.dot(fw) }.max() ?? 1
    }
    for _ in 0..<4 {
        let dist = fitAt(m)
        var lx = Double.greatestFiniteMagnitude, hx = -Double.greatestFiniteMagnitude
        var ly = Double.greatestFiniteMagnitude, hy = -Double.greatestFiniteMagnitude
        for q in ext {
            let v = q - m, z = max(0.05, dist + v.dot(fw))
            lx = min(lx, v.dot(rt) / z); hx = max(hx, v.dot(rt) / z); ly = min(ly, v.dot(up) / z); hy = max(hy, v.dot(up) / z)
        }
        m = m + rt * ((lx + hx) / 2 * dist) + up * ((ly + hy) / 2 * dist)
    }
    return (m, max(0.5, fitAt(m)), back)
}

/// The card drawn the old way (the 2D painter, Furniture/PieceView.swift): what shows when the 3D cannot make one.
/// Safe off the main thread.
func cardPainted(_ f: Furniture, _ ws: Workshop, _ mats: [Mat], _ spec: CardSpec) -> UIImage {
    let fmt = UIGraphicsImageRendererFormat()
    fmt.scale = spec.scale
    fmt.opaque = true
    let s = pieceScene(f, ws, mats)
    return UIGraphicsImageRenderer(size: spec.pt, format: fmt).image { c in drawPiece(c.cgContext, spec.pt, s, hi: nil, az: 0, label: nil) }
}

/// img (a 3D snapshot, at the screen's scale) as a card of spec: exactly its size and scale, opaque.
func cardFit(_ img: UIImage, _ spec: CardSpec) -> UIImage {
    let fmt = UIGraphicsImageRendererFormat()
    fmt.scale = spec.scale
    fmt.opaque = true
    return UIGraphicsImageRenderer(size: spec.pt, format: fmt).image { c in
        uiColor(CARD_BG).setFill(); c.fill(CGRect(origin: .zero, size: spec.pt))
        img.draw(in: CGRect(origin: .zero, size: spec.pt))
    }
}

/// The cards made so far: in memory (NSCache) and on disk (Caches/cards/<key>.heic, or .png where HEIC cannot be
/// written). Only 3D pictures go to disk: a drawn fallback is kept in memory, so the next launch tries the 3D again.
/// Thread-safe (NSCache and the file system), so the disk is read and written off the main thread.
final class CardStore {
    static let shared = CardStore()
    let dir: URL
    private let mem = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var pruned = false

    init(dir: URL? = nil) {
        let fm = FileManager.default
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        self.dir = dir ?? base.appendingPathComponent("cards", isDirectory: true)
        mem.countLimit = 120
        try? fm.createDirectory(at: self.dir, withIntermediateDirectories: true)
    }

    /// The card in memory, if it is there.
    func memory(_ k: CardKey) -> UIImage? { mem.object(forKey: k.name as NSString) }

    /// The card from disk (kept in memory from then on), decoded ready to show.
    func disk(_ k: CardKey) -> UIImage? {
        for ext in ["heic", "png"] {
            let u = dir.appendingPathComponent(k.name + "." + ext)
            guard let d = try? Data(contentsOf: u), let img = UIImage(data: d, scale: k.scale) else { continue }
            let ready = img.preparingForDisplay() ?? img
            mem.setObject(ready, forKey: k.name as NSString)
            return ready
        }
        return nil
    }

    func get(_ k: CardKey) -> UIImage? { memory(k) ?? disk(k) }

    /// Whether the card is on disk.
    func onDisk(_ k: CardKey) -> Bool {
        let fm = FileManager.default
        return ["heic", "png"].contains { fm.fileExists(atPath: dir.appendingPathComponent(k.name + "." + $0).path) }
    }

    /// Keeps img as k's card in memory.
    func remember(_ k: CardKey, _ img: UIImage) { mem.setObject(img, forKey: k.name as NSString) }

    /// Writes img as k's card to disk (HEIC, else PNG), the oldest cards going past keep files.
    func save(_ k: CardKey, _ img: UIImage, keep: Int = 240) {
        guard let enc = CardStore.encode(img) else { return }
        try? enc.0.write(to: dir.appendingPathComponent(k.name + "." + enc.1), options: .atomic)
        lock.lock()
        let first = !pruned
        pruned = true
        lock.unlock()
        if first { prune(keep) }
    }

    /// Every card gone, in memory and on disk.
    func clear() {
        mem.removeAllObjects()
        let fm = FileManager.default
        for u in (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] { try? fm.removeItem(at: u) }
    }

    /// Only the newest keep files stay (other styles, boards and versions pile up otherwise).
    private func prune(_ keep: Int) {
        let fm = FileManager.default
        guard let all = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]), all.count > keep else { return }
        let dated = all.map { u in (u, (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        for (u, _) in dated.sorted(by: { $0.1 > $1.1 }).dropFirst(keep) { try? fm.removeItem(at: u) }
    }

    /// img as HEIC (ImageIO; the type named by its identifier, so nothing newer than iOS 11 is needed), else PNG.
    static func encode(_ img: UIImage) -> (Data, String)? {
        if let cg = img.cgImage {
            let data = NSMutableData()
            if let d = CGImageDestinationCreateWithData(data as CFMutableData, "public.heic" as CFString, 1, nil) {
                CGImageDestinationAddImage(d, cg, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
                if CGImageDestinationFinalize(d), data.length > 0 { return (data as Data, "heic") }
            }
        }
        return img.pngData().map { ($0, "png") }
    }
}
