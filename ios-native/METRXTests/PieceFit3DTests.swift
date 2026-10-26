import XCTest
@testable import METRX

/// The designer's 3D of a room-less piece (Geo/PieceFit3D.swift, Cam3D's piece fit): the camera looks at the piece and
/// stands where it fills 78 % of the free band across or up, whichever is tighter; a measured room keeps its framing.
final class PieceFit3DTests: XCTestCase {
    private let ws = Workshop()
    /// The designer's picture on a big iPhone (points) and the bands the pill and the hint cover.
    private let w = 430.0, h = 606.0

    /// The eight corners of a box.
    private func corners(_ lo: V3, _ hi: V3) -> [V3] {
        var out: [V3] = []
        for x in [lo.x, hi.x] { for y in [lo.y, hi.y] { for z in [lo.z, hi.z] { out.append(V3(x, y, z)) } } }
        return out
    }

    private func frame(_ lo: V3, _ hi: V3) -> PieceFrame { PieceFrame(lo: lo, hi: hi, pts: corners(lo, hi)) }

    /// A camera of the picture's size at theta, phi, looking as aim says.
    private func camera(_ pf: PieceFrame, theta: Double, phi: Double) -> Cam3D {
        let c = Cam3D()
        c.resize(CGFloat(w), CGFloat(h))
        c.theta = theta; c.phi = phi
        let a = pieceAim(pf, theta: theta, phi: phi, w: w, h: h)
        c.tgt = a.tgt; c.r = a.r
        return c
    }

    /// How far out the piece reaches: the largest share of the band's half width and of its half height.
    private func reach(_ pf: PieceFrame, _ c: Cam3D) -> (x: Double, y: Double) {
        let band = h - pf.top - pf.bottom, mid = pf.top + band / 2
        var rx = 0.0, ry = 0.0
        for p in pf.pts {
            guard let q = c.project(p) else { XCTFail("a corner behind the camera"); return (9, 9) }
            rx = max(rx, abs(Double(q.x) - w / 2) / (w / 2))
            ry = max(ry, abs(Double(q.y) - mid) / (band / 2))
        }
        return (rx, ry)
    }

    func testAWardrobeFillsItsBandFromTheCorner() {
        let pf = frame(V3(0.2, 0, 0), V3(2.0, 2.5, 0.6))
        let c = camera(pf, theta: Double.pi / 2 + 0.75, phi: 0.95)
        let r = reach(pf, c)
        // the tighter way reaches 78 %, the other stays inside it
        XCTAssertEqual(max(r.x, r.y), PIECE_FILL, accuracy: 0.005)
        XCTAssertLessThanOrEqual(min(r.x, r.y), PIECE_FILL + 0.005)
    }

    func testAWideKitchenFillsItsBandFromAbove() {
        let pf = frame(V3(0.2, 0, 0), V3(3.6, 2.3, 2.6))
        let c = camera(pf, theta: Double.pi / 2, phi: 0.07)
        let r = reach(pf, c)
        XCTAssertEqual(max(r.x, r.y), PIECE_FILL, accuracy: 0.005)
    }

    func testTheBoxMiddleSitsInTheMiddleOfTheBand() {
        let pf = frame(V3(0.2, 0, 0), V3(2.0, 2.5, 0.6))
        let c = camera(pf, theta: Double.pi / 2 + 0.75, phi: 0.95)
        let band = h - pf.top - pf.bottom
        let q = c.project(pf.mid)!
        XCTAssertEqual(Double(q.x), w / 2, accuracy: 0.5)
        XCTAssertEqual(Double(q.y), pf.top + band / 2, accuracy: 0.5)
    }

    func testABiggerPieceStandsFurtherAway() {
        let small = pieceAim(frame(V3(0, 0, 0), V3(0.5, 0.6, 0.4)), theta: 2.3, phi: 0.95, w: w, h: h)
        let big = pieceAim(frame(V3(0, 0, 0), V3(3, 2.4, 0.6)), theta: 2.3, phi: 0.95, w: w, h: h)
        XCTAssertGreaterThan(big.r, small.r)
        XCTAssertGreaterThan(small.r, 0.3)
    }

    func testTheFrameOfAWardrobeIsItsOwnBox() {
        let f = newFreeWardrobe("Shkaf", "h2", 1000, 2200, 600, false, "door", ws)
        let fur = furniture3D([f], buildShell([freeRoom(f)], single: true).bases, ws, { _ in 0xCDBFAE }, [], split: true)
        guard let pf = pieceFrame(fur) else { XCTFail("no frame"); return }
        XCTAssertEqual(pf.hi.y - pf.lo.y, 2.2, accuracy: 0.2)
        XCTAssertGreaterThan(pf.lo.y, -0.05)
        // the doors are in it: the front is as deep as the wardrobe, not only its carcass
        XCTAssertEqual(pf.hi.z - pf.lo.z, 0.6, accuracy: 0.1)
        XCTAssertFalse(pf.pts.isEmpty)
    }

    func testTheCameraStartsOnThePieceAndComesBackToIt() {
        var r = Room(id: "free-x", floorId: "f", name: "x")
        r.dims = ["A": Dim(v: 3800, src: "manual"), "B": Dim(v: 2600, src: "manual"), "H": Dim(v: 2700, src: "manual"), "T": Dim(v: 200, src: "default")]
        let room = buildShell([r], single: true).floorOnly()
        let pf = frame(V3(0.3, 0, 0), V3(1.3, 2.2, 0.6))
        let c = Cam3D()
        c.resize(CGFloat(w), CGFloat(h))
        c.load(room.framing(pf))
        let a = pieceAim(pf, theta: c.theta, phi: c.phi, w: w, h: h)
        XCTAssertEqual(c.r, a.r, accuracy: 1e-6)
        XCTAssertEqual((c.tgt - a.tgt).len, 0, accuracy: 1e-6)
        // the room's middle is not where it looks
        XCTAssertGreaterThan((c.tgt - room.tgt).len, 0.5)
        // a pinch stays within its limits, nearer than the rooms' 3 m for a piece this small
        c.zoom(0.01)
        XCTAssertLessThan(c.r, a.r)
        XCTAssertGreaterThan(c.r, 0.1)
        c.zoom(100)
        XCTAssertLessThanOrEqual(c.r, a.r * 1.6 + 1 + 1e-6)
        // turned and moved, "From the corner" frames it the same again
        c.rotate(80, 30); c.pan(40, 20)
        c.preset(top: false)
        let b = pieceAim(pf, theta: c.theta, phi: c.phi, w: w, h: h)
        XCTAssertEqual(c.r, b.r, accuracy: 1e-6)
        XCTAssertEqual((c.tgt - b.tgt).len, 0, accuracy: 1e-6)
        // "From above" fits it from above
        c.preset(top: true)
        let t = pieceAim(pf, theta: c.theta, phi: c.phi, w: w, h: h)
        XCTAssertEqual(c.r, t.r, accuracy: 1e-6)
    }

    func testAMeasuredRoomKeepsItsRoomFraming() {
        var r = Room(id: "r", floorId: "f", name: "Oshxona")
        r.dims = ["A": Dim(v: 3400, src: "manual"), "B": Dim(v: 2600, src: "manual"), "H": Dim(v: 2700, src: "manual"), "T": Dim(v: 200, src: "default")]
        let s = buildShell([r], single: true)
        let c = Cam3D()
        c.resize(CGFloat(w), CGFloat(h))
        c.load(s)
        XCTAssertNil(c.piece)
        XCTAssertEqual((c.tgt - s.tgt).len, 0, accuracy: 1e-9)
        XCTAssertEqual(c.r, v3Fit(s.fit[0], s.fit[1], s.fit[2], w / h) * s.fit[3], accuracy: 1e-9)
    }
}
