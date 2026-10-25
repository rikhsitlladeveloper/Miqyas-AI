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

    /// The framed box's and the boards' shares of the card's tighter side, and where the boards fall (-1 to 1).
    private func shares(_ s: PieceScene, _ tier: Quality3) -> (fit: Double, piece: Double, span: [Double]) {
        let spec = cardSpec(tier)
        let aspect = Double(spec.pt.width / spec.pt.height)
        let a = cardAim(s.cardExt, piece: s.ext, az: s.az0, el: CARD_EL, aspect: aspect)
        let fit = cardShare(s.cardExt, at: a.tgt, dist: a.r, back: a.back, aspect: aspect, half: FOV_HALF)
        let piece = cardShare(s.ext, at: a.tgt, dist: a.r, back: a.back, aspect: aspect, half: FOV_HALF)
        let span = cardSpan(s.ext, at: a.tgt, dist: a.r, back: a.back, aspect: aspect, half: FOV_HALF) ?? [9, 9, 9, 9]
        return (fit, piece, span)
    }

    private func scene(_ id: String) -> PieceScene? {
        guard let f = cardPiece(id, ws, "") else { return nil }
        return pieceScene(f, ws, MAT_PRESETS)
    }

    /// The coffee table, the desk, the mirror cabinet, an L kitchen and a kupe (26 Oct 2026): the framed box (the boards,
    /// the floor under them, the wall behind) takes 70–82% of the card's tighter side, the boards inside with room round.
    func testSmallLowAndBigPiecesGetTheSameRoom() {
        for id in ["coffee", "desk", "mirrorC", "L", "s2"] {
            for t in [Quality3.high, Quality3.low] {
                guard let s = scene(id) else { XCTFail("no \(id)"); continue }
                let r = shares(s, t)
                print("card \(id) \(t): framed box \(r.fit), boards \(r.piece)")
                XCTAssertGreaterThanOrEqual(r.fit, 0.70, "\(id) \(t)")
                XCTAssertLessThanOrEqual(r.fit, 0.82, "\(id) \(t)")
                for v in r.span { XCTAssertLessThan(abs(v), 0.9, "\(id) \(t) \(r.span)") }
            }
        }
    }

    /// Every gallery model: the framed box takes CARD_FILL (more only where the boards alone would be too small), the
    /// boards never under CARD_PIECE_MIN and all in the picture.
    func testEveryModelIsFramed() {
        for (_, ids) in GALLERY {
            for id in ids {
                guard let s = scene(id) else { continue }
                let r = shares(s, .high)
                print("card \(id): framed box \(r.fit), boards \(r.piece)")
                XCTAssertGreaterThanOrEqual(r.piece, CARD_PIECE_MIN - 0.005, id)
                XCTAssertGreaterThanOrEqual(r.fit, CARD_FILL - 0.005, id)
                XCTAssertTrue(r.fit <= CARD_FILL + 0.005 || r.piece <= CARD_PIECE_MIN + 0.005, "\(id) \(r.fit)")
                for v in r.span { XCTAssertLessThan(abs(v), 0.95, "\(id) \(r.span)") }
            }
        }
    }

    /// A 400 mm-tall nightstand still reads well: its wall's 300 mm above it would leave it small, so the camera comes in
    /// until the boards take CARD_PIECE_MIN of the card.
    func testASmallNightstandStillReadsWell() {
        guard let m = fModel("nightstand"), let usual = scene("nightstand") else { return XCTFail("no nightstand") }
        let low = pieceScene(pieceOf(m, ["h": 400], ws, ""), ws, MAT_PRESETS)
        var top = 0.0
        for q in low.ext { top = max(top, q.y) }
        XCTAssertEqual(top, 0.4, accuracy: 0.03)
        for s in [usual, low] {
            for t in [Quality3.high, Quality3.low] {
                let r = shares(s, t)
                print("card nightstand \(t): framed box \(r.fit), boards \(r.piece)")
                XCTAssertGreaterThanOrEqual(r.piece, CARD_PIECE_MIN - 0.005)
                XCTAssertGreaterThanOrEqual(r.fit, CARD_FILL - 0.005)
                for v in r.span { XCTAssertLessThan(abs(v), 0.9, "\(r.span)") }
            }
        }
    }

    /// The same 3/4 angle and height as before: only how far off and where it looks change.
    func testAimKeepsTheAngle() {
        guard let s = scene("desk") else { return XCTFail("no desk") }
        let a = cardAim(s.cardExt, piece: s.ext, az: s.az0, el: CARD_EL, aspect: 300.0 / 255.0)
        XCTAssertEqual(asin(a.back.y), CARD_EL, accuracy: 1e-9)
        XCTAssertEqual(atan2(a.back.x, a.back.z), s.az0, accuracy: 1e-9)
        XCTAssertGreaterThan(a.r, 0.5)
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
