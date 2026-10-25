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
/// 5: every piece framed with the same room round it (cardAim, 26 Oct 2026).
let CARD_RENDER_VERSION = 5

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

/*
 * The cards' framing (26 Oct 2026, as the approved mockup's "Galereya kartalari"), the same rule in both apps (Android:
 * ui/three/CardCache.kt cardFrame): the camera keeps its 3/4 angle and height, and stands as far off as makes what the
 * card shows of the piece (its boards with the floor patch under them and the walls behind them, PieceScene.cardExt)
 * take CARD_FILL of the card's width or height, whichever is tighter, that picture centred. Two clamps: never so far
 * that the boards alone take less than CARD_PIECE_MIN, never so near that the card shows less than CARD_MIN_VIEW m top
 * to bottom at the aim (so the smallest pieces are not blown up past a nightstand).
 */

/// The share of the card's tighter side the framed piece takes.
let CARD_FILL = 0.78

/// The least share of the card's tighter side the boards alone take (a small piece, its wall high above it).
let CARD_PIECE_MIN = 0.58

/// The least height the card shows at the aim, metres.
let CARD_MIN_VIEW = 0.75

/// The camera's way to the eye from az round and el above level.
func cardBack(_ az: Double, _ el: Double) -> V3 { V3(sin(az) * cos(el), sin(el), cos(az) * cos(el)) }

/// Where pts fall in a picture of aspect (width / height) seen from at + back × dist, half the vertical field of view's
/// half: the lowest and highest x and y, each from -1 to 1 across the picture; nil when one is behind the eye.
func cardSpan(_ pts: [V3], at: V3, dist: Double, back: V3, aspect: Double, half: Double) -> [Double]? {
    let fw = back * -1
    let rt = fw.cross(V3(0, 1, 0)).unit
    let up = rt.cross(fw)
    let tv = tan(half)
    let th = tv * aspect
    var o = [Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude]
    for q in pts {
        let v = q - at
        let z = dist + v.dot(fw)
        if z < 0.05 { return nil }
        let x = v.dot(rt) / z / th
        let y = v.dot(up) / z / tv
        o[0] = min(o[0], x); o[1] = max(o[1], x); o[2] = min(o[2], y); o[3] = max(o[3], y)
    }
    return o
}

/// The share of the picture's tighter side pts take (cardSpan); 99 when one is behind the eye.
func cardShare(_ pts: [V3], at: V3, dist: Double, back: V3, aspect: Double, half: Double) -> Double {
    guard let s = cardSpan(pts, at: at, dist: dist, back: back, aspect: aspect, half: half) else { return 99 }
    return max((s[1] - s[0]) / 2, (s[3] - s[2]) / 2)
}

/// How far off the camera stands for pts to take share of the picture (cardShare falls as it goes back).
private func cardDistFor(_ pts: [V3], _ at: V3, _ back: V3, _ aspect: Double, _ half: Double, _ share: Double) -> Double {
    var lo = 0.05, hi = 200.0
    for _ in 0..<60 {
        let m = (lo + hi) / 2
        if cardShare(pts, at: at, dist: m, back: back, aspect: aspect, half: half) > share { lo = m } else { hi = m }
    }
    return hi
}

/// The aim moved across until pts' picture is centred, at share of the picture each time.
private func cardCentred(_ pts: [V3], _ start: V3, _ back: V3, _ aspect: Double, _ half: Double, _ share: Double) -> V3 {
    let fw = back * -1
    let rt = fw.cross(V3(0, 1, 0)).unit
    let up = rt.cross(fw)
    let tv = tan(half)
    let th = tv * aspect
    var m = start
    for _ in 0..<6 {
        let d = cardDistFor(pts, m, back, aspect, half, share)
        guard let s = cardSpan(pts, at: m, dist: d, back: back, aspect: aspect, half: half) else { break }
        m = m + rt * ((s[0] + s[1]) / 2 * th * d) + up * ((s[2] + s[3]) / 2 * tv * d)
    }
    return m
}

/// The middle of pts' bounds.
private func cardMid(_ pts: [V3]) -> V3 {
    var lo = V3(Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude)
    var hi = V3(-Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude, -Double.greatestFiniteMagnitude)
    for q in pts {
        lo = V3(min(lo.x, q.x), min(lo.y, q.y), min(lo.z, q.z))
        hi = V3(max(hi.x, q.x), max(hi.y, q.y), max(hi.z, q.z))
    }
    return (lo + hi) * 0.5
}

/// Where the card's camera looks (tgt) and how far from it it stands (r), by the rule above: fit what the card frames
/// (PieceScene.cardExt), piece the boards' bounds (PieceScene.ext), seen from az round the piece (PieceView.swift's az0)
/// and el above level, in a picture of aspect (width / height); half: half the vertical field of view. back: from the
/// target towards the eye.
func cardAim(_ fit: [V3], piece: [V3], az: Double, el: Double, aspect: Double, half: Double = FOV_HALF) -> (tgt: V3, r: Double, back: V3) {
    let back = cardBack(az, el)
    let pts = fit.isEmpty ? piece : fit
    guard !pts.isEmpty else { return (V3(0, 0.5, 0), 3, back) }
    let a = max(0.2, aspect)
    var at = cardCentred(pts, cardMid(pts), back, a, half, CARD_FILL)
    var d = cardDistFor(pts, at, back, a, half, CARD_FILL)
    // the boards alone too small (a small piece, its wall high above it): nearer, the boards centred
    if !piece.isEmpty && cardShare(piece, at: at, dist: d, back: back, aspect: a, half: half) < CARD_PIECE_MIN {
        at = cardCentred(piece, cardMid(piece), back, a, half, CARD_PIECE_MIN)
        d = cardDistFor(piece, at, back, a, half, CARD_PIECE_MIN)
    }
    // a very small piece: not nearer than shows CARD_MIN_VIEW top to bottom
    d = max(d, CARD_MIN_VIEW / (2 * tan(half)))
    return (at, d, back)
}

/// The card drawn the old way (the 2D painter, Furniture/PieceView.swift): what shows when the 3D cannot make one.
/// Safe off the main thread.
func cardPainted(_ f: Furniture, _ ws: Workshop, _ mats: [Mat], _ spec: CardSpec) -> UIImage {
    let fmt = UIGraphicsImageRendererFormat()
    fmt.scale = spec.scale
    fmt.opaque = true
    let s = pieceScene(f, ws, mats)
    return UIGraphicsImageRenderer(size: spec.pt, format: fmt).image { c in drawPiece(c.cgContext, spec.pt, s, hi: nil, az: 0, label: nil, card: true) }
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
