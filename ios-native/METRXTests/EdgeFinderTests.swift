import XCTest
import UIKit
@testable import METRX

/// Photo edge measuring (Android EdgeFinderTest and MarkupTest): the edge finder on the shared test photos (edges/,
/// cases in edge-cases.json, both from the Android test resources), snapping, the rectangle's sides, and the editor's
/// letters, zoom and loupe.
final class EdgeFinderTests: XCTestCase {
    private func url(_ name: String, _ ext: String, _ dir: String? = nil) -> URL {
        Bundle(for: EdgeFinderTests.self).url(forResource: name, withExtension: ext, subdirectory: dir)!
    }

    /// A test photo as the app sees it: shrunk to the finder's size, grey, results in item units (1000 wide).
    private func detect(_ file: String) -> PhotoEdges {
        let parts = file.split(separator: ".").map(String.init)
        let img = UIImage(contentsOfFile: url(parts[0], parts[1], "edges").path)!
        let cg = img.cgImage!
        let (g, w, h) = greyPixels(img)!
        return EdgeFinder.find(g, w, h, 1000, 1000 * Float(cg.height) / Float(cg.width))
    }

    private lazy var photos: [[String: Any]] = {
        let root = try! JSONSerialization.jsonObject(with: Data(contentsOf: url("edge-cases", "json"))) as! [String: Any]
        return root["photos"] as! [[String: Any]]
    }()
    private func pt(_ a: Any) -> (Float, Float) { let v = a as! [NSNumber]; return (v[0].floatValue, v[1].floatValue) }
    private func near(_ a: (Float, Float), _ b: (Float, Float), _ tol: Float) -> Bool { hypotf(a.0 - b.0, a.1 - b.1) <= tol }
    private func f(_ a: Any) -> Float { (a as! NSNumber).floatValue }

    func testFindsTheEdgesCornersAndRectangleOfEachPhoto() {
        for c in photos {
            let file = c["file"] as! String, tol = f(c["tol"]!)
            let e = detect(file)
            let r = c["edges"] as! [Int]
            XCTAssertTrue((r[0]...r[1]).contains(e.segs.count), "\(file): \(e.segs.count) edges")
            for p in c["corners"] as! [Any] { XCTAssertTrue(e.corners.contains { near(($0.x, $0.y), pt(p), tol) }, "\(file): corner \(pt(p))") }
            guard c.keys.contains("rect") else { continue }
            guard let want = c["rect"] as? [Any] else { XCTAssertNil(e.rect, "\(file): no rectangle"); continue }
            guard let got = e.rect else { XCTFail("\(file): a rectangle"); continue }
            XCTAssertEqual(got.pts.count, 4)
            for p in want { XCTAssertTrue(got.pts.contains { near($0, pt(p), tol) }, "\(file): rectangle corner \(pt(p)) in \(got.pts)") }
        }
    }

    func testLineEndsSnapToCornersFirstThenEdges() {
        for c in photos {
            let file = c["file"] as! String, sn = c["snaps"] as! [[String: Any]]
            if sn.isEmpty { continue }
            let e = detect(file)
            for s in sn {
                let at = pt(s["at"]!), rr = s["r"] as! [NSNumber], to = pt(s["to"]!)
                let got = edgeSnap(e, at.0, at.1, rr[0].floatValue, rr[1].floatValue)
                let kind = got.snap == nil ? "free" : (got.snap!.corner ? "corner" : "edge")
                XCTAssertEqual(kind, s["kind"] as! String, "\(file) at \(at)")
                XCTAssertTrue(near((got.x, got.y), to, 6), "\(file) at \(at): \(got.x),\(got.y)")
            }
        }
    }

    func testBothEndsOnOneEdgeLockTheLineAlongIt() {
        let c = photos.first { $0["lock"] != nil }!, lk = c["lock"] as! [String: Any], rr = lk["r"] as! [NSNumber]
        let rc = rr[0].floatValue, re = rr[1].floatValue
        let e = detect(c["file"] as! String)
        let a = pt(lk["a"]!), b = pt(lk["b"]!)
        let sa = edgeSnap(e, a.0, a.1, rc, re), sb = edgeSnap(e, b.0, b.1, rc, re)
        guard let shared = sharedEdge(sa.snap, sb.snap) else { return XCTFail("the front corners share the front edge") }
        let (la, lb) = lockAlong(e, sa, sb), s = e.segs[shared]
        // both ends lie on the edge's line
        func off(_ x: Float, _ y: Float) -> Float { abs((x - s.x1) * (s.y2 - s.y1) - (y - s.y1) * (s.x2 - s.x1)) / s.len }
        XCTAssertEqual(off(la.x, la.y), 0, accuracy: 0.01); XCTAssertEqual(off(lb.x, lb.y), 0, accuracy: 0.01)
        // a free end does not lock
        let free = edgeSnap(e, 500, 250, rc, re)
        let (fa, fb) = lockAlong(e, sa, free)
        XCTAssertEqual(fa, sa); XCTAssertEqual(fb, free)
    }

    func testTheRectangleOffersItsLevelSideThenTheOther() {
        for c in photos {
            guard let want = c["sides"] as? [[Any]] else { continue }
            let file = c["file"] as! String, tol = f(c["tol"]!)
            let got = rectSides(detect(file).rect!)
            XCTAssertEqual(got.count, 2)
            for (i, s) in want.enumerated() {
                XCTAssertTrue(near(got[i].0, pt(s[0]), tol) && near(got[i].1, pt(s[1]), tol), "\(file) side \(i): \(got[i])")
            }
        }
    }

    func testAnEmptyOrFlatImageHasNoEdges() {
        XCTAssertEqual(EdgeFinder.find([], 0, 0, 1000, 750), .none)
        XCTAssertEqual(EdgeFinder.find([Float](repeating: 128, count: 64 * 48), 64, 48, 1000, 750).segs.count, 0)
    }

    /* ---------- the editor: letters, line ends, zoom and the loupe (part 1) ---------- */

    private let fmt = MkFmt(unit: .m, en: false, m: "m", lang: .uz)
    private let dim = MkEl(id: "d", t: "dim", pts: [[352, 112], [668, 112]], c: "red", v: 1200)
    private var photo: Item { var it = Item(id: "p", kind: "photo"); it.W = 1000; it.H = 750; it.els = [dim]; return it }
    private let view = CGRect(x: 0, y: 0, width: 400, height: 600)   // a tall view: the 1000 × 750 photo fills its width, 300 high

    func testDimensionsAreLetteredInTheOrderDrawn() {
        var two = photo; var e2 = dim; e2.id = "e"
        two.els = [dim, MkEl(id: "t", t: "text", pts: [[10, 10]], txt: "x"), e2]
        XCTAssertEqual(mkLetters(two), ["d": "A", "e": "B"])
        let plain = mkPill(dim, fmt), lettered = mkPill(dim, fmt, letter: "A")
        XCTAssertEqual(plain.midX, lettered.midX, accuracy: 0.01); XCTAssertEqual(lettered.width, plain.width + 42, accuracy: 0.01)
    }

    func testPillsKeepTheirScreenSizeWhenZoomed() {
        let p = mkPill(dim, fmt, zoom: 2)
        XCTAssertEqual(p.width, mkPill(dim, fmt).width / 2, accuracy: 0.01); XCTAssertEqual(p.height, 28, accuracy: 0.01)
        XCTAssertEqual(mkLabelAt(photo, CGPoint(x: 510, y: 112), fmt, zoom: 2)?.id, "d")
    }

    func testALineEndIsFoundNearTheFinger() {
        XCTAssertEqual(mkEndAt(photo, CGPoint(x: 660, y: 118), 20)?.1, 1)
        XCTAssertEqual(mkEndAt(photo, CGPoint(x: 350, y: 110), 20)?.1, 0)
        XCTAssertNil(mkEndAt(photo, CGPoint(x: 510, y: 112), 20))
    }

    func testZoomScalesAboutTheCentreAndPanLeavesNoGap() {
        XCTAssertEqual(mkZoomBox(view, 1, .zero), view)
        XCTAssertEqual(mkZoomBox(view, 2, CGPoint(x: 10, y: 0)), CGRect(x: -190, y: -300, width: 800, height: 1200))
        XCTAssertEqual(mkClampPan(photo, view, 1, CGPoint(x: 50, y: 50)), .zero)
        XCTAssertEqual(mkClampPan(photo, view, 2, CGPoint(x: 500, y: 80)), CGPoint(x: 200, y: 0))
    }

    func testAPinchKeepsThePhotoUnderTheFingers() {
        let c = CGPoint(x: 300, y: 300)
        let before = mkToItem(photo, mkZoomBox(view, 1, .zero), c)
        let (z, pan) = mkPinch(photo, view, 1, .zero, 2, c, .zero)
        XCTAssertEqual(z, 2, accuracy: 1e-4)
        let after = mkToItem(photo, mkZoomBox(view, z, pan), c)
        XCTAssertEqual(before.x, after.x, accuracy: 0.01); XCTAssertEqual(before.y, after.y, accuracy: 0.5)
        XCTAssertEqual(mkPinch(photo, view, 3, .zero, 3, c, .zero).0, 4, accuracy: 1e-4)
        XCTAssertEqual(mkPinch(photo, view, 1.2, .zero, 0.5, c, .zero).0, 1, accuracy: 1e-4)
    }

    func testTheLoupeSitsAboveTheFingerAndShowsItsPoint() {
        let size = CGSize(width: 400, height: 600)
        XCTAssertEqual(mkLoupeAt(CGPoint(x: 200, y: 300), size, 60, 34), CGPoint(x: 200, y: 206))
        XCTAssertEqual(mkLoupeAt(CGPoint(x: 200, y: 50), size, 60, 34), CGPoint(x: 200, y: 144))
        let s = CGPoint(x: 120, y: 250), l = CGPoint(x: 120, y: 156)
        let lb = mkLoupeBox(view, s, l, 2.5)
        let p = mkToItem(photo, view, s), q = mkToItem(photo, lb, l)
        XCTAssertEqual(p.x, q.x, accuracy: 0.01); XCTAssertEqual(p.y, q.y, accuracy: 0.01)
    }
}
