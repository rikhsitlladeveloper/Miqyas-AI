import XCTest
@testable import METRX

/// The client's 3D files (Joylan ideas, 26 Oct 2026; Furniture/Core/Client3D.swift, Furniture/Client3DShare.swift;
/// Android Client3DTest): the HTML fetches nothing and stays small, the USDZ is a real, aligned package and is written.
final class Client3DTests: XCTestCase {
    private let ws = Workshop()

    private func order() -> Project {
        var r = Room(id: "r", floorId: "w", name: "Oshxona")
        r.dims = ["A": Dim(v: 3400), "B": Dim(v: 2800), "H": Dim(v: 2700), "T": Dim(v: 200, src: "default")]
        r.openings = [Opening(id: "o1", type: "window", wall: "A", w: 1200, h: 1250, off: 1000, sill: 950),
                      Opening(id: "o2", type: "door", wall: "C", w: 800, h: 2050, off: 1300)]
        r.points = [SitePoint(id: "s1", t: "cold", wall: "A", off: 1600, h: 500), SitePoint(id: "s2", t: "gas", wall: "B", off: 400, h: 600)]
        var p = Project(id: "p", name: "Aliyevlar <oshxona> & \"uy\"")
        p.industry = "furniture"
        p.floors = [Workspace(id: "w", name: "Oshxona", type: "kitchen")]
        p.rooms = [r]
        let plan = akGenerate(akRoomOf(r, true), walls: ["D", "A"], layout: "L", app: AKApp(), preset: "twotone")!
        p.furniture = akFurniture(plan, r, "twotone", ws, snap: true)
        return p
    }

    private func scene(_ p: Project, _ d: Quality3 = .low) -> C3Scene {
        let s = client3DScene(p, rid: nil, ws: ws, mats: MAT_PRESETS, snap: true, detail: d)
        XCTAssertNotNil(s)
        return s!
    }

    private func info() -> C3Info {
        var i = C3Info()
        i.title = "Aliyevlar <oshxona> & \"uy\""
        i.line1 = "Oshxona 1 · 17 modul"; i.line2 = "Oshxona 3,4 × 2,8 m · 26.10.2026"
        i.price = "Taxminiy narx: 31 000 000 so‘m"
        i.master = "Usta: Sanjar"; i.phone = "+998900000000"; i.phoneShown = "+998 90 000 00 00"
        i.hint = "Aylantiring"; i.noGl = "3D yo‘q"
        return i
    }

    func testSceneHasTheRoomAndTheKitchen() {
        let p = order()
        XCTAssertEqual(c3Room(p, nil)?.id, "r")
        let s = scene(p)
        XCTAssertGreaterThan(s.meshes.count, 3)
        XCTAssertGreaterThan(s.meshes.reduce(0) { $0 + $1.polys.count }, 200)
        // the walls the kitchen stands on and the room's height
        XCTAssertEqual(s.dims.map(\.text), ["2800", "3400", "2700"])
        for m in s.meshes {
            XCTAssertEqual(m.polys.count, m.norms.count)
            // every face wound to its normal
            for (k, poly) in m.polys.enumerated() where poly.count >= 3 {
                let a = poly[1] - poly[0], b = poly[2] - poly[0]
                let n = a.cross(b)
                if n.len > 1e-9 { XCTAssertGreaterThanOrEqual(n.dot(m.norms[k]), -1e-9) }
            }
        }
    }

    func testHtmlFetchesNothingAndStaysSmall() {
        let s = scene(order())
        let h = client3DHtml(s, info())
        XCTAssertFalse(h.lowercased().contains("http://"))
        XCTAssertFalse(h.lowercased().contains("https://"))
        XCTAssertFalse(h.contains("src=\""))
        XCTAssertLessThan(h.utf8.count, C3_HTML_MAX)
        XCTAssertTrue(h.hasPrefix("<!doctype html>"))
        XCTAssertTrue(h.contains("METRX"))
        XCTAssertTrue(h.contains("Aliyevlar &lt;oshxona&gt; &amp; &quot;uy&quot;"))
        XCTAssertFalse(h.contains("<oshxona>"))
        XCTAssertTrue(h.contains("tel:+998900000000"))
        XCTAssertTrue(h.contains("Taxminiy narx"))
        XCTAssertTrue(h.contains("2800"))
        // without the price, the phone and the dimensions
        var i = info()
        i.price = nil; i.phone = nil; i.dims = false
        let h2 = client3DHtml(s, i)
        XCTAssertFalse(h2.contains("Taxminiy narx"))
        XCTAssertFalse(h2.contains("tel:"))
        XCTAssertTrue(h2.contains("d:[]"))
        // the way the app makes it, with the settings and the order's language
        let h3 = client3DHtmlFor(order(), AppSettings.shared, rid: nil)
        XCTAssertNotNil(h3)
        XCTAssertFalse(h3!.lowercased().contains("http:") || h3!.lowercased().contains("https:"))
        XCTAssertLessThan(h3!.utf8.count, C3_HTML_MAX)
    }

    func testUsdzPackage() {
        let s = scene(order())
        let usda = client3DUsda(s)
        XCTAssertTrue(usda.hasPrefix("#usda 1.0"))
        XCTAssertTrue(usda.contains("metersPerUnit = 1"))
        XCTAssertTrue(usda.contains("upAxis = \"Y\""))
        XCTAssertTrue(usda.contains("UsdPreviewSurface"))
        let z = client3DUsdz(s)
        XCTAssertEqual(Array(z.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
        // the layer's data starts on a 64-byte boundary, stored as it is
        let nameLen = Int(z[26]) | Int(z[27]) << 8, extraLen = Int(z[28]) | Int(z[29]) << 8
        let at = 30 + nameLen + extraLen
        XCTAssertEqual(at % 64, 0)
        XCTAssertEqual(String(data: z.subdata(in: 30..<(30 + nameLen)), encoding: .utf8), "model.usda")
        XCTAssertEqual(String(data: z.subdata(in: at..<(at + 9)), encoding: .utf8), "#usda 1.0")
        XCTAssertEqual(c3Crc32(Data("123456789".utf8)), 0xCBF43926)
        // several files: each one aligned
        let zz = c3Zip([("a.usda", Data("x".utf8)), ("b.png", Data(repeating: 7, count: 100))])
        var off = 0
        for _ in 0..<2 {
            let n = Int(zz[off + 26]) | Int(zz[off + 27]) << 8, e = Int(zz[off + 28]) | Int(zz[off + 29]) << 8
            let size = Int(zz[off + 18]) | Int(zz[off + 19]) << 8
            XCTAssertEqual((off + 30 + n + e) % 64, 0)
            off += 30 + n + e + size
        }
    }

    /// The files written to the phone: the USDZ exists and is not empty, the HTML next to it.
    func testFilesAreWritten() throws {
        let s = scene(order())
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("c3test-" + uid() + ".usdz")
        XCTAssertTrue(c3WriteUsdz(s, u))
        let size = try FileManager.default.attributesOfItem(atPath: u.path)[.size] as? NSNumber
        XCTAssertGreaterThan(size?.intValue ?? 0, 1000)
        try? FileManager.default.removeItem(at: u)
        let urls = client3DFiles(order(), AppSettings.shared, rid: nil, usdz: true, html: true)
        XCTAssertEqual(urls.map(\.pathExtension), ["usdz", "html"])
        for url in urls {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let n = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
            XCTAssertGreaterThan(n, 0)
        }
        XCTAssertTrue(urls[0].lastPathComponent.hasSuffix("_3D.usdz"))
    }

    func testEscapes() {
        XCTAssertEqual(c3Esc("a<b>&\"'"), "a&lt;b&gt;&amp;&quot;&#39;")
        XCTAssertEqual(c3Js("</script>\n\""), "\"\\u003c/script\\u003e\\n\\\"\"")
        XCTAssertEqual(c3FileBase("Aliyevlar oshxonasi"), "Aliyevlar_oshxonasi_3D")
        XCTAssertEqual(c3FileBase("  "), "METRX_3D")
    }
}
