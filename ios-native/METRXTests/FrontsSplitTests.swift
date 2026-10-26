import XCTest
@testable import METRX

/// Doors and drawers that move without a rebuild (Geo/FrontMotion3D.swift; Android FrontsSplitTest): the split build,
/// each front built shut and moved by its transform, draws exactly what the full rebuild at that openness draws (the
/// same face points, normals, outlines and tap boxes), and the rest of the piece does not change while they open.
final class FrontsSplitTests: XCTestCase {
    private let ws = Workshop()
    private let rgb: (String) -> Int = { _ in 0xCDBFAE }

    private func room() -> Room {
        var r = Room(id: "r", floorId: "f", name: "Oshxona")
        r.dims = ["A": Dim(v: 3400, src: "manual"), "B": Dim(v: 2600, src: "manual"), "H": Dim(v: 2700, src: "manual"), "T": Dim(v: 200, src: "default")]
        return r
    }
    private var bases: [String: WallBasis] { buildShell([room()], single: true).bases }
    private func freeBases(_ f: Furniture) -> [String: WallBasis] { buildShell([freeRoom(f)], single: true).bases }

    /// An L kitchen as the app fills it, with a backsplash, a plinth and end panels, in design preset; style and the LED
    /// when given.
    private func kitchen(_ preset: String, style: String? = nil, led: Bool = false) -> Furniture {
        var f0 = Furniture(id: "k", kind: "kitchen", walls: ["A", "B"], layout: "L")
        f0.kx = KExtras(splash: 600, plinth: true, led: led, ends: 1, endsUp: 1)
        let f = withPreset(autoFill(f0, runsOf(f0) { ["A": 3400, "B": 2600][$0] }, ws, [], []), preset)
        guard let style else { return f }
        return withLook(f) { l in var n = l; n.style = style; return n }
    }

    private func led(_ f: Furniture) -> Furniture { withLook(f) { l in var n = l; n.led = true; return n } }

    /// The full rebuild with each front amt of the way open (the old path), or the split build.
    private func build(_ f: Furniture, _ b: [String: WallBasis], _ detail: Quality3, amt: @escaping (String) -> Double = { _ in 0 },
                       split: Bool = false, bare: Bool = false) -> Furn3D {
        furniture3D([f], b, ws, rgb, [], amt: amt, bare: bare, detail: detail, ceilH: 2700, split: split)
    }

    /* ---------------- what is drawn, as comparable keys ---------------- */

    // an odd offset keeps whole and half tenths of a millimetre off the rounding boundaries
    private func r(_ v: Double, _ k: Double = 1e4) -> Int64 { Int64((v * k + 0.2718281).rounded()) }
    private func pt(_ p: V3) -> String { "\(r(p.x)),\(r(p.y)),\(r(p.z))" }
    private func partKey(_ p: Part3) -> String { "\(p.wall ?? "-")|\(p.slab)|\(p.rgb)|\(p.op)|\(p.look?.hashValue ?? 0)" }

    private func faceKeys(_ p: Part3, _ rg: Rigid3?, _ out: inout [String]) {
        let pk = partKey(p)
        for f in p.faces {
            let n = rg?.dir(f.n) ?? f.n
            var s = pk + "|\(r(n.x, 1e3)),\(r(n.y, 1e3)),\(r(n.z, 1e3))|"
            // the same polygon may be listed from another corner (a turned round cap): start at its smallest corner,
            // keeping the winding
            var ps: [String] = []
            for q in f.pts { ps.append(pt(rg?.point(q) ?? q)) }
            var at = 0
            for i in ps.indices where ps[i] < ps[at] { at = i }
            for i in 0..<ps.count { s += ps[(at + i) % ps.count] + ";" }
            out.append(s)
        }
    }

    private func segKeys(_ e: Edges3, _ rg: Rigid3?, _ out: inout [String]) {
        var i = 0
        while i + 1 < e.segs.count {
            let a = rg?.point(e.segs[i]) ?? e.segs[i], b = rg?.point(e.segs[i + 1]) ?? e.segs[i + 1]
            // a line is the same whichever end it is listed from
            let pa = pt(a), pb = pt(b)
            out.append("\(e.wall)|\(e.rgb)|" + (pa < pb ? pa + ">" + pb : pb + ">" + pa))
            i += 2
        }
    }

    private func boxKey(_ p: Pick) -> String {
        let o = pt(p.box.o), a = pt(p.box.a), b = pt(p.box.b), c = pt(p.box.c)
        return "\(p.key)|\(o)|\(a)|\(b)|\(c)"
    }

    private struct Scene { let faces: [String]; let segs: [String]; let picks: [String] }

    /// What the full rebuild draws.
    private func whole(_ d: Furn3D) -> Scene {
        var faces: [String] = [], segs: [String] = [], picks: [String] = []
        for p in d.parts { faceKeys(p, nil, &faces) }
        for e in d.edges { segKeys(e, nil, &segs) }
        for p in d.picks { picks.append(boxKey(p)) }
        return Scene(faces: faces.sorted(), segs: segs.sorted(), picks: picks.sorted())
    }

    /// What the 3D draws from the split build with the fronts amt open: the rest as built, each front moved by its
    /// transform, a drawer's box only while it is out; the tap boxes where the fronts are (picksAt).
    private func moved(_ d: Furn3D, _ amt: (String) -> Double) -> Scene {
        var faces: [String] = [], segs: [String] = [], picks: [String] = []
        for p in d.parts { faceKeys(p, nil, &faces) }
        for e in d.edges { segKeys(e, nil, &segs) }
        for fr in d.fronts {
            let k = amt(fr.key), rg = fr.at(k)
            for p in fr.parts { faceKeys(p, rg, &faces) }
            for e in fr.edges { segKeys(e, rg, &segs) }
            if k > 0 {
                for p in fr.inner { faceKeys(p, rg, &faces) }
                for e in fr.innerEdges { segKeys(e, rg, &segs) }
            }
        }
        for p in d.picksAt(amt) { picks.append(boxKey(p)) }
        return Scene(faces: faces.sorted(), segs: segs.sorted(), picks: picks.sorted())
    }

    /// The first place two sorted lists differ (nil: the same).
    private func firstDiff(_ a: [String], _ b: [String]) -> String? {
        if a.count != b.count { return "\(a.count) vs \(b.count)" }
        for i in a.indices where a[i] != b[i] { return a[i] + "  vs  " + b[i] }
        return nil
    }

    private func assertSame(_ what: String, _ a: Scene, _ b: Scene, file: StaticString = #filePath, line: UInt = #line) {
        let f = firstDiff(a.faces, b.faces), s = firstDiff(a.segs, b.segs), p = firstDiff(a.picks, b.picks)
        XCTAssertNil(f, "\(what) faces: \(f ?? "")", file: file, line: line)
        XCTAssertNil(s, "\(what) outlines: \(s ?? "")", file: file, line: line)
        XCTAssertNil(p, "\(what) tap boxes: \(p ?? "")", file: file, line: line)
    }

    private func keySum(_ k: String) -> Int {
        var s = 0
        for c in k.utf8 { s += Int(c) }
        return s
    }

    /// Shut, half open, open and two mixes.
    private var mixes: [(String) -> Double] {
        let sum = keySum
        let a: (String) -> Double = { _ in 0 }
        let b: (String) -> Double = { _ in 0.5 }
        let c: (String) -> Double = { _ in 1 }
        let d: (String) -> Double = { k in [0.0, 0.3, 1.0][sum(k) % 3] }
        let e: (String) -> Double = { k in [0.01, 0.7][sum(k) % 2] }
        return [a, b, c, d, e]
    }

    /// f split and moved matches the full rebuild with every front shut, half open, open and in a mix; the rest of the
    /// split build is the same whatever is open (it reads no openness).
    private func check(_ id: String, _ f: Furniture, _ b: [String: WallBasis], _ detail: Quality3, file: StaticString = #filePath, line: UInt = #line) {
        let split = build(f, b, detail, split: true)
        var fk = Set<String>()
        for fr in split.fronts { fk.insert(fr.key) }
        XCTAssertEqual(Set(split.keys), fk, "\(id): every key a front", file: file, line: line)
        XCTAssertFalse(split.fronts.isEmpty, "\(id): has fronts", file: file, line: line)
        for (i, amt) in mixes.enumerated() {
            assertSame("\(id) \(detail) mix \(i)", whole(build(f, b, detail, amt: amt)), moved(split, amt), file: file, line: line)
        }
        // the rest stays put: the split build's parts are those whatever is open
        let again = build(f, b, detail, amt: { _ in 1 }, split: true)
        var n0 = 0, n1 = 0
        for p in split.parts { n0 += p.faces.count }
        for p in again.parts { n1 += p.faces.count }
        XCTAssertEqual(split.parts.count, again.parts.count, "\(id): static parts", file: file, line: line)
        XCTAssertEqual(n0, n1, "\(id): static faces", file: file, line: line)
        // and opening a front leaves the static parts' faces where they are
        assertSame("\(id) static", whole(Furn3D(parts: split.parts, edges: split.edges, picks: split.picks, keys: split.keys)),
                   whole(Furn3D(parts: again.parts, edges: again.edges, picks: again.picks, keys: again.keys)), file: file, line: line)
    }

    /* ---------------- the pieces ---------------- */

    func testKitchensInEveryPresetMovedMatchTheFullRebuild() {
        for pr in DESIGN_PRESETS {
            let k = kitchen(pr.id)
            check("kitchen \(pr.id)", k, bases, .high)
            check("kitchen \(pr.id) low", k, bases, .low)
        }
        check("kitchen neo fluted", kitchen("neo", style: "fluted"), bases, .high)
        check("kitchen gloss led", kitchen("gloss", led: true), bases, .high)
        check("kitchen twotone flat", kitchen("twotone"), bases, .flat)
    }

    func testKupeLedWardrobesRacksAndLiftBedsToo() {
        let kupe = led(withPreset(pieceOf(fModel("s3")!, ["w": 2400, "h": 2600, "d": 620], ws, "Kupe"), "twotone", fresh: true))
        let hinged = led(withPreset(pieceOf(fModel("h3")!, ["w": 1500, "h": 2400, "d": 600], ws, "Shkaf"), "neo", fresh: true))
        let lift = withPreset(pieceOf(fModel("bed")!, ["bt": 2], ws, "Karavot"), "twotone", fresh: true)
        let hall = withPreset(pieceOf(fModel("hallway")!, [:], ws, "hall"), "twotone", fresh: true)
        for (id, f) in [("kupe", kupe), ("hinged", hinged), ("lift", lift), ("hall", hall)] {
            let b = freeBases(f)
            check(id, f, b, .high)
            check("\(id) low", f, b, .low)
            check("\(id) flat", f, b, .flat)
        }
        // the lift-up base is a front turning 38°; a hallway's shoe rack is a front that pulls out
        let ls = build(lift, freeBases(lift), .high, split: true)
        XCTAssertTrue(ls.fronts.contains { $0.key.hasSuffix(":lift") && abs($0.motion.angle - 38 * Double.pi / 180) < 1e-12 })
        let hs = build(hall, freeBases(hall), .high, split: true)
        XCTAssertTrue(hs.fronts.contains { $0.key.contains(":r") && $0.motion.angle == 0 })
        // the kupe's doors slide (no turn)
        let ks = build(kupe, freeBases(kupe), .high, split: true)
        XCTAssertTrue(ks.fronts.contains { $0.key.contains(":slide") && $0.motion.angle == 0 && $0.motion.shift.len > 0.3 })
        // seeing inside: no doors, drawer fronts or sliding doors at all (only a rack still pulls out), the drawers' boxes
        // shut in the rest
        for f in [hinged, kupe] {
            let fb = freeBases(f)
            let bareS = build(f, fb, .high, split: true, bare: true)
            for fr in bareS.fronts { XCTAssertTrue(fr.key.contains(":r"), fr.key) }
            assertSame("bare", whole(build(f, fb, .high, bare: true)), moved(bareS) { _ in 0 })
            assertSame("bare open", whole(build(f, fb, .high, amt: { _ in 1 }, bare: true)), moved(bareS) { _ in 1 })
        }
    }

    func testEveryGalleryPieceMovedMatchesTheFullRebuild() {
        for (_, ids) in GALLERY {
            for id in ids {
                let base = pieceOf(fModel(id)!, [:], ws, id)
                let b = freeBases(base)
                let split = build(base, b, .high, split: true)
                // a piece with nothing to open has nothing to move
                if split.keys.isEmpty { XCTAssertTrue(split.fronts.isEmpty, id); continue }
                check("\(id) flat", base, b, .flat)
                check("\(id) twotone", withPreset(base, "twotone", fresh: true), b, .high)
            }
        }
    }

    func testADoorTurnsAboutItsHingeAndADrawerPullsStraightOut() {
        let k = kitchen("twotone"), b = bases
        let split = build(k, b, .high, split: true)
        guard let door = split.fronts.first(where: { $0.motion.angle > 0 && $0.key.hasSuffix(":f0") }) else { return XCTFail("no door") }
        // the hinge line stays where it is, at any openness
        for t in [0.0, 0.5, 1.0] {
            let p = door.at(t).point(door.motion.pivot)
            XCTAssertTrue((p - door.motion.pivot).len < 1e-12, "\(t)")
            let q = door.motion.pivot + V3(0, 0.7, 0)
            XCTAssertTrue((door.at(t).point(q) - q).len < 1e-12, "\(t)")
        }
        // fully open it turns the door's 90° (beside a wall or a neighbour) about the vertical
        XCTAssertEqual(door.motion.angle, Double.pi / 2, accuracy: 1e-12)
        XCTAssertEqual(abs(door.motion.axis.y), 1, accuracy: 1e-12)
        // its tap box at 0, half and fully open: the full rebuild's corners there
        guard let shut = door.picks.first else { return XCTFail("no tap box") }
        for t in [0.0, 0.5, 1.0] {
            let full = build(k, b, .high, amt: { $0 == door.key ? t : 0 })
            guard let old = full.picks.first(where: { $0.key == door.key }) else { XCTFail("no old box"); continue }
            let a = old.box.corners(), c = door.at(t).obb(shut.box).corners()
            for i in a.indices { XCTAssertTrue((a[i] - c[i]).len < 1e-9, "\(t): \(a[i]) vs \(c[i])") }
        }
        // a dresser's drawer: straight out of its front, no turn, half as far half open; its box only while it is out
        let dr = withPreset(pieceOf(fModel("dresser")!, [:], ws, "dresser"), "twotone", fresh: true)
        let db = freeBases(dr)
        let ds = build(dr, db, .high, split: true)
        guard let drawer = ds.fronts.first(where: { $0.motion.angle == 0 && !$0.inner.isEmpty }), let box = drawer.picks.first else {
            return XCTFail("no drawer")
        }
        let out = drawer.at(1).t
        XCTAssertTrue(out.len > 0.2 && abs(out.y) < 1e-12)
        XCTAssertEqual(abs(out.unit.dot(box.box.c.unit)), 1, accuracy: 1e-9)
        XCTAssertTrue((drawer.at(0.5).t - out * 0.5).len < 1e-12)
        for t in [0.0, 0.5, 1.0] {
            let full = build(dr, db, .high, amt: { $0 == drawer.key ? t : 0 })
            guard let old = full.picks.first(where: { $0.key == drawer.key }) else { XCTFail("no old box"); continue }
            let a = old.box.corners(), c = drawer.at(t).obb(box.box).corners()
            for i in a.indices { XCTAssertTrue((a[i] - c[i]).len < 1e-9, "\(t): \(a[i]) vs \(c[i])") }
        }
        // a tap finds a door where it is drawn now: straight at its middle from in front it is hit shut; open, the full
        // rebuild's pick and the split one's agree
        let mid = shut.box.o + (shut.box.a + shut.box.b + shut.box.c) * 0.5
        let outN = shut.box.c.unit
        let eye = mid + outN * 3, dir = outN * -1
        XCTAssertEqual(split.pick(eye, dir, amt: { _ in 0 }), door.key)
        for t in [0.0, 0.5, 1.0] {
            let amt: (String) -> Double = { $0 == door.key ? t : 0 }
            XCTAssertEqual(build(k, b, .high, amt: amt).pick(eye, dir), split.pick(eye, dir, amt: amt), "\(t)")
        }
    }

    /// The motion's transform is the one RealityKit is given: the same rotation as Rodrigues' (right-handed).
    func testTheMotionTurnsRightHanded() {
        let m = FrontMotion.turn(V3(1, 0, 2), V3(0, 1, 0), Double.pi / 2)
        // about +y by 90°: +x goes to −z
        let p = m.at(1).point(V3(2, 0, 2))
        XCTAssertTrue((p - V3(1, 0, 1)).len < 1e-12, "\(p)")
        let half = m.at(0.5).dir(V3(1, 0, 0))
        XCTAssertTrue((half - V3(0.5.squareRoot(), 0, -(0.5.squareRoot()))).len < 1e-12, "\(half)")
        let s = FrontMotion.move(V3(0, 0, 0.3)).at(0.5)
        XCTAssertTrue((s.point(V3(1, 1, 1)) - V3(1, 1, 1.15)).len < 1e-12)
    }
}
