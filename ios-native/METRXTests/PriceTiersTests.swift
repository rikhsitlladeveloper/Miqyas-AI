import XCTest
@testable import METRX

/// The three price options (Joylan ideas, 26 Oct 2026; Furniture/Core/PriceTiers.swift; Android PriceTiersTest, the
/// same cases): what each tier swaps, their order on a typical kitchen, the quote's lines and the saved order's JSON.
final class PriceTiersTests: XCTestCase {
    private let ws = Workshop()

    private func kitchen(_ preset: String) -> Furniture {
        var f = newFreeKitchen("Oshxona 1", "L", "L", [3000, 2400], 0, 2700, ws)
        f.id = "k"
        return withPreset(f, preset, fresh: true, ws: ws)
    }

    private func prices(_ f: Furniture, _ fp: FPrice = FPrice()) -> [String: Decimal] {
        var out: [String: Decimal] = [:]
        for t in tierPrices([f], fp, ws, MAT_PRESETS, HW_PRESETS) { out[t.tier] = t.price }
        return out
    }

    func testStandardIsAsDesigned() {
        let f = kitchen("twotone")
        XCTAssertEqual(tierFurniture(f, "std"), f)
        XCTAssertEqual(prices(f)["std"], priceOf([f], FPrice(), ws, MAT_PRESETS, HW_PRESETS).price)
    }

    func testEkonomSwaps() {
        let f = kitchen("twotone")
        XCTAssertEqual(f.mats.front, "ag_graphite"); XCTAssertEqual(f.mats.frontUp, "ag_white")
        let e = tierFurniture(f, "eko")
        XCTAssertEqual(e.mats.front, "ldsp18a")
        XCTAssertEqual(e.mats.frontUp, "ldsp16w")
        XCTAssertEqual(e.mats.top, "wt38")
        XCTAssertEqual(e.mats.splash, "splash6")
        XCTAssertTrue(e.modules.allSatisfy { !$0.soft })
        XCTAssertEqual(e.look?.style, "flat")
        XCTAssertEqual(e.modules.map(\.w), f.modules.map(\.w))
        XCTAssertEqual(e.modules.map(\.x), f.modules.map(\.x))
        // a Gola kitchen gets bar handles; a wood worktop stays wood
        let g = tierFurniture(kitchen("gola"), "eko")
        XCTAssertEqual(g.mats.front, "ldsp16k")
        XCTAssertEqual(g.handle, "")
        XCTAssertEqual(g.mats.top, "wt38c")
        // the neoclassic: flat fronts, chrome for gold, a bar for the knob, no cornice
        let n = tierFurniture(kitchen("neo"), "eko")
        XCTAssertEqual(n.mats.front, "ldsp16w")
        XCTAssertEqual(n.look?.style, "flat")
        XCTAssertEqual(n.look?.hcol, "chrome")
        XCTAssertEqual(n.handle, "")
        XCTAssertEqual(n.kx?.cornice, false)
        // a wood decor front stays
        XCTAssertEqual(ekoBoard("wd_halifax"), "wd_halifax")
        XCTAssertEqual(ekoBoard("mdf18"), "ldsp16w")
    }

    func testPremiumSwaps() {
        let p = tierFurniture(kitchen("twotone"), "pre")
        XCTAssertEqual(p.mats.front, "ag_graphite")
        XCTAssertEqual(p.mats.frontUp, "ag_white")
        XCTAssertEqual(p.mats.top, "wt20m")
        // the backsplash in the worktop's stone (spStone*, by the m²), as Android
        XCTAssertEqual(p.mats.splash, "spStoneM")
        XCTAssertEqual(p.kx?.led, true)
        XCTAssertTrue(p.modules.allSatisfy { $0.soft })
        // matte fronts become MDF enamel; a wood worktop becomes onyx stone
        let g = tierFurniture(kitchen("gola"), "pre")
        XCTAssertEqual(g.mats.front, "en_cashmere")
        XCTAssertEqual(g.mats.top, "wt20o")
        XCTAssertEqual(preBoard("ldsp16k", gloss: false), "en_cashmere")
        XCTAssertEqual(preBoard("wd_walnut", gloss: true), "wd_walnut")
        XCTAssertEqual(g.mats.splash, "spStoneO")
        // the plain anthracite worktop becomes dark quartz
        var plain = kitchen("twotone"); plain.mats.top = "wt38"
        let d = tierFurniture(plain, "pre")
        XCTAssertEqual(d.mats.top, "wt20d"); XCTAssertEqual(d.mats.splash, "spStoneD")
        // only Premium prices its hinges and runners at the Blum-type items
        let hws = tierHws(HW_PRESETS, "pre")
        XCTAssertEqual(usualHw(hws, "hingeSoft")?.id, "hingeBlum"); XCTAssertEqual(usualHw(hws, "runner")?.id, "runnerBlum")
        XCTAssertEqual(usualHw(tierHws(HW_PRESETS, "std"), "hingeSoft")?.id, "hingeSoft")
        XCTAssertTrue(MAT_PRESETS.contains { $0.id == "spStoneD" && $0.byArea })
    }

    /// On a typical kitchen Ekonom < Standart < Premium, by the margin and by the running metre alike.
    func testOrderOnATypicalKitchen() {
        for id in ["twotone", "gola", "wood"] {
            let f = kitchen(id)
            let m = prices(f)
            XCTAssertLessThan(m["eko"]!, m["std"]!, id)
            XCTAssertLessThan(m["std"]!, m["pre"]!, id)
            let r = prices(f, FPrice(mode: "run"))
            XCTAssertEqual(r["std"], priceOf([f], FPrice(mode: "run"), ws, MAT_PRESETS, HW_PRESETS).price)
            XCTAssertLessThan(r["eko"]!, r["std"]!, id)
            XCTAssertLessThan(r["std"]!, r["pre"]!, id)
        }
        XCTAssertEqual(tierPct(110, 100), 10)
        XCTAssertEqual(tierPct(80, 100), -20)
    }

    /// The quote keeps the three prices as price lines of their own, only when the order asks for them.
    func testQuoteLines() {
        var p = Project(id: "p", name: "T")
        p.industry = "furniture"
        p.furniture = [kitchen("twotone")]
        let off = furnSnap(Snap(name: "T"), p, ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertFalse(off.flines.contains(where: isTierLine))
        p.tri = true
        let on = furnSnap(Snap(name: "T"), p, ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(on.flines.filter(isTierLine).map(\.key), ["pt.eko", "pt.std", "pt.pre"])
        XCTAssertEqual(on.flines.first { $0.key == "pt.std" }?.amount, on.ftotal)
        XCTAssertEqual(on.flines.filter { !isTierLine($0) }, off.flines)
        XCTAssertEqual(fingerprint(on), fingerprint(off))
    }

    /// An order saved before the tiers keeps its JSON; tri is written only when on.
    func testJsonRoundTrip() throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        var p = Project(id: "p", name: "T")
        p.industry = "furniture"
        p.furniture = [kitchen("gloss")]
        let old = String(data: try enc.encode(p), encoding: .utf8)!
        XCTAssertFalse(old.contains("\"tri\""))
        let back = try JSONDecoder().decode(Project.self, from: Data(old.utf8))
        XCTAssertFalse(back.tri)
        XCTAssertEqual(String(data: try enc.encode(back), encoding: .utf8), old)
        p.tri = true
        let now = String(data: try enc.encode(p), encoding: .utf8)!
        XCTAssertTrue(now.contains("\"tri\":true"))
        XCTAssertTrue(try JSONDecoder().decode(Project.self, from: Data(now.utf8)).tri)
    }
}
