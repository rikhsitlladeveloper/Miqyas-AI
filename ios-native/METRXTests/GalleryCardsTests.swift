import XCTest
import UIKit
@testable import METRX

/// The gallery's cards from the real 3D (modern 3D part 4, 25 Oct 2026; Furniture/CardCache.swift,
/// Furniture/GalleryCards.swift): the cache key, the disk cache, the camera, and the drawn card when the 3D gives none.
final class GalleryCardsTests: XCTestCase {
    private let ws = Workshop()
    private var dir: URL!

    override func setUp() {
        super.setUp()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("cards-test-" + UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        super.tearDown()
    }

    private func key(model: String = "L", tier: Quality3 = .high, style: String = "twotone", mats: [Mat] = MAT_PRESETS, handle: String = "bar",
                     ws: Workshop = Workshop(), version: Int = CARD_RENDER_VERSION) -> CardKey {
        cardKey(model, cardSpec(tier), style: style, matsSig: cardSig(mats), handle: handle, tier: tier, wsSig: cardSig(ws), version: version)
    }

    /// A plain picture of spec's size.
    private func solid(_ spec: CardSpec, _ c: UIColor = .red) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = spec.scale; f.opaque = true
        return UIGraphicsImageRenderer(size: spec.pt, format: f).image { r in c.setFill(); r.fill(CGRect(origin: .zero, size: spec.pt)) }
    }

    /* ---------------- the key ---------------- */

    /// The hash is FNV-1a 64, the same on every launch (Swift's Hasher is not).
    func testHashIsStableFnv1a() {
        XCTAssertEqual(cardHash(""), 0xcbf29ce484222325)
        XCTAssertEqual(cardHash("abc"), 0xe71fa2190541574b)
    }

    /// The boards' and workshop's signatures follow what is in them, and only that.
    func testSignatureFollowsTheData() {
        XCTAssertEqual(cardSig(MAT_PRESETS), cardSig(MAT_PRESETS))
        var other = MAT_PRESETS
        other[0].rgb = "#123456"
        XCTAssertNotEqual(cardSig(other), cardSig(MAT_PRESETS))
        var w = Workshop()
        w.gap10 += 10
        XCTAssertNotEqual(cardSig(w), cardSig(Workshop()))
    }

    /// The same inputs give the same file name; each input changed gives another one.
    func testKeyNamesEveryInput() {
        XCTAssertEqual(key().name, key().name)
        XCTAssertEqual(key(), key())
        var boards = MAT_PRESETS
        boards[0].tex = "walnut"
        var w = Workshop()
        w.t = w.t == 16 ? 18 : 16
        let names = [key(), key(model: "U"), key(tier: .low), key(style: "neo"), key(style: ""), key(mats: boards), key(handle: GOLA),
                     key(ws: w), key(version: CARD_RENDER_VERSION + 1)].map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "\(names)")
    }

    /// The name is a plain file name: the model in front, no path characters.
    func testKeyNameIsAFileName() {
        let n = key(model: "cornerW").name
        XCTAssertTrue(n.hasPrefix("cornerW-high-600x510-v\(CARD_RENDER_VERSION)-"), n)
        XCTAssertFalse(n.contains("/") || n.contains(":") || n.contains(" "), n)
    }

    /// Cards are 200 : 170 like the gallery's; a weaker phone's are smaller.
    func testSpecByTier() {
        let hi = cardSpec(.high), lo = cardSpec(.low)
        XCTAssertGreaterThan(hi.pxW, lo.pxW)
        for s in [hi, lo] { XCTAssertEqual(Double(s.pt.width / s.pt.height), 200.0 / 170.0, accuracy: 0.01) }
        XCTAssertEqual(cardSpec(.flat), lo)
    }

    /// The card's piece is the model in the order's style, as addPiece would make it.
    func testCardPieceTakesTheOrderStyle() {
        XCTAssertEqual(cardPiece("L", ws, "neo")?.look?.preset, "neo")
        XCTAssertNotNil(cardPiece("L", ws, ""))
        XCTAssertNil(cardPiece("no-such-model", ws, ""))
        XCTAssertNotEqual(cardPiece("I", ws, "gola")?.handle, cardPiece("I", ws, "twotone")?.handle)
    }

    /* ---------------- the camera ---------------- */

    /// Every corner of the piece is inside the picture, with the margin left round it.
    func testAimFitsEveryCorner() {
        guard let f = cardPiece("L", ws, "") else { return XCTFail("no L kitchen") }
        let s = pieceScene(f, ws, MAT_PRESETS)
        let aspect = 300.0 / 255.0
        let a = cardAim(s.ext, az: s.az0, el: CARD_EL, aspect: aspect)
        let eye = a.tgt + a.back * a.r
        let fw = a.back * -1, rt = fw.cross(V3(0, 1, 0)).unit, up = rt.cross(fw)
        let tv = tan(FOV_HALF), th = tv * aspect
        var most = 0.0
        for q in s.ext {
            let d = q - eye, z = d.dot(fw)
            XCTAssertGreaterThan(z, 0.1)
            let k = max(abs(d.dot(rt)) / z / th, abs(d.dot(up)) / z / tv)
            XCTAssertLessThanOrEqual(k, 1.0)
            most = max(most, k)
        }
        // and it fills the picture: not a small piece in the middle
        XCTAssertGreaterThan(most, 0.8)
    }

    /* ---------------- the disk cache ---------------- */

    func testStoreKeepsAPictureOnDisk() {
        let k = key(), spec = cardSpec(.high)
        let a = CardStore(dir: dir)
        XCTAssertNil(a.get(k))
        a.save(k, solid(spec))
        XCTAssertTrue(a.onDisk(k))
        // another launch: nothing in memory, the file read back at the card's size
        let b = CardStore(dir: dir)
        XCTAssertNil(b.memory(k))
        let img = b.get(k)
        XCTAssertNotNil(img)
        XCTAssertEqual(Double(img?.size.width ?? 0), Double(spec.pt.width), accuracy: 1)
        XCTAssertNotNil(b.memory(k))
        b.clear()
        XCTAssertFalse(b.onDisk(k))
    }

    /* ---------------- the fallback ---------------- */

    @MainActor private func waitFor(_ pics: CardPics, _ id: String) async {
        for _ in 0..<200 where pics.pics[id] == nil { try? await Task.sleep(nanoseconds: 50_000_000) }
    }

    /// The 3D gives no picture: the card is drawn, kept in memory only, so the next launch tries the 3D again.
    @MainActor func testDrawnWhenThe3DFails() async {
        let store = CardStore(dir: dir)
        let pics = CardPics(render: { _, _, _, done in done(nil) }, store: store, timeout: 2, ids: ["nightstand"])
        pics.use(ws, MAT_PRESETS, "", tier: .high)
        await waitFor(pics, "nightstand")
        XCTAssertNotNil(pics.pics["nightstand"])
        guard let k = pics.key("nightstand") else { return XCTFail("no key") }
        XCTAssertFalse(store.onDisk(k))
        XCTAssertNotNil(store.memory(k))
    }

    /// The 3D never answers: after the time-out the card is drawn all the same.
    @MainActor func testDrawnWhenThe3DNeverAnswers() async {
        let store = CardStore(dir: dir)
        let pics = CardPics(render: { _, _, _, _ in }, store: store, timeout: 0.3, ids: ["dresser"])
        pics.use(ws, MAT_PRESETS, "", tier: .low)
        await waitFor(pics, "dresser")
        XCTAssertNotNil(pics.pics["dresser"])
    }

    /// Two failures in a row: the rest of the session's cards are drawn without asking the 3D.
    @MainActor func testStopsAskingAfterTwoFailures() async {
        var asked = 0
        let pics = CardPics(render: { _, _, _, done in asked += 1; done(nil) }, store: CardStore(dir: dir), timeout: 2, ids: ["dresser", "nightstand", "vanity"])
        pics.use(ws, MAT_PRESETS, "", tier: .high)
        await waitFor(pics, "dresser"); await waitFor(pics, "nightstand"); await waitFor(pics, "vanity")
        XCTAssertEqual(pics.pics.count, 3)
        XCTAssertEqual(asked, 2)
        XCTAssertTrue(pics.broken)
    }

    /// The flat tier never asks the 3D: its cards are the drawing.
    @MainActor func testFlatTierIsDrawn() async {
        var asked = 0
        let pics = CardPics(render: { _, _, _, done in asked += 1; done(nil) }, store: CardStore(dir: dir), timeout: 2, ids: ["nightstand"])
        pics.use(ws, MAT_PRESETS, "", tier: .flat)
        await waitFor(pics, "nightstand")
        XCTAssertNotNil(pics.pics["nightstand"])
        XCTAssertEqual(asked, 0)
    }

    /// A 3D picture is kept on disk, at the card's size, and a later gallery finds it there without asking the 3D.
    @MainActor func test3DPictureIsKept() async {
        let store = CardStore(dir: dir)
        let red = solid(CardSpec(pt: CGSize(width: 150, height: 128), scale: 3))
        let pics = CardPics(render: { _, _, _, done in done(red) }, store: store, timeout: 2, ids: ["nightstand"])
        pics.use(ws, MAT_PRESETS, "neo", tier: .high)
        await waitFor(pics, "nightstand")
        let img = pics.pics["nightstand"]
        XCTAssertNotNil(img)
        XCTAssertEqual(Double(img?.size.width ?? 0), Double(cardSpec(.high).pt.width), accuracy: 1)
        guard let k = pics.key("nightstand") else { return XCTFail("no key") }
        // the file is written in the background (HEIC encoding is slow on a busy CI simulator): give it up to 15 s
        for _ in 0..<300 where !store.onDisk(k) { try? await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(store.onDisk(k))
        var asked = 0
        let later = CardPics(render: { _, _, _, done in asked += 1; done(nil) }, store: CardStore(dir: dir), timeout: 2, ids: ["nightstand"])
        later.use(ws, MAT_PRESETS, "neo", tier: .high)
        await waitFor(later, "nightstand")
        XCTAssertNotNil(later.pics["nightstand"])
        XCTAssertEqual(asked, 0)
    }

    /// Another style is another set of cards (the old ones kept for going back).
    @MainActor func testStyleChangeMakesNewCards() async {
        let store = CardStore(dir: dir)
        let pics = CardPics(render: { _, _, _, done in done(nil) }, store: store, timeout: 2, ids: ["nightstand"])
        pics.use(ws, MAT_PRESETS, "neo", tier: .high)
        await waitFor(pics, "nightstand")
        let a = pics.key("nightstand")
        pics.use(ws, MAT_PRESETS, "dark", tier: .high)
        let b = pics.key("nightstand")
        XCTAssertNotEqual(a, b)
        await waitFor(pics, "nightstand")
        XCTAssertNotNil(pics.pics["nightstand"])
        if let a { XCTAssertNotNil(store.memory(a)) }
    }
}
