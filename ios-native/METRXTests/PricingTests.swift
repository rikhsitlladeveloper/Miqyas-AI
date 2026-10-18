import XCTest
@testable import METRX

/// The customer price (furniture plan section 6.7; Android PricingTest): margin, per running metre, fixed; profit;
/// module labels for the pack; the snapshot and quote of a furniture order.
final class PricingTests: XCTestCase {
    private let ws = Workshop()
    private var kitchen: Furniture {
        let f0 = Furniture(id: "k", kind: "kitchen", name: "Oshxona 1", walls: ["A", "B"], layout: "L")
        return autoFill(f0, runsOf(f0) { ["A": 3400, "B": 2600][$0] }, ws, [], [])
    }
    private var ward: Furniture { Furniture(id: "w", kind: "wardrobe", name: "Shkaf 1", walls: ["D"], modules: [wardrobeTemplate(ws, "D", 10, 2400, 2500, builtIn: true)]) }

    func testMarginPricesEachPieceAndTheDelivery() {
        let k = kitchen, fs = [k, ward]
        let p = priceOf(fs, FPrice(), ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(p.lines.map(\.key), ["k", "w", "deliver"])
        XCTAssertEqual(p.lines[0].amount, withMargin(costOf([k], ws, MAT_PRESETS, HW_PRESETS, order: false).total, 30))
        XCTAssertEqual(p.lines[2].amount, withMargin(1_500_000 + 300_000, 30))
        XCTAssertEqual(p.price, p.lines.reduce(Decimal(0)) { $0 + $1.amount })
        XCTAssertEqual(p.profit, p.price - p.cost.total)
        XCTAssertGreaterThan(p.profit, 0)
    }

    func testKitchensByTheRunningMetre() {
        let k = kitchen, fs = [k, ward]
        let p = priceOf(fs, FPrice(mode: "run", rRun: "4400000", rTall: "1000000"), ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(runMm(k), 5400)                                       // 3400 on A + 2000 on B (the corner is A's)
        XCTAssertEqual(p.lines[0].amount, Decimal(5_400 * 4_400_000 / 1000))  // no tall units in this kitchen
        XCTAssertEqual(p.lines[1].amount, priceOf(fs, FPrice(), ws, MAT_PRESETS, HW_PRESETS).lines[1].amount)   // the wardrobe by the margin
    }

    func testAFixedPriceAndALoss() {
        let p = priceOf([kitchen, ward], FPrice(mode: "fixed", fixed: "10 000 000"), ws, MAT_PRESETS, HW_PRESETS)
        XCTAssertEqual(p.price, 10_000_000); XCTAssertTrue(p.lines.isEmpty)
        XCTAssertLessThan(p.profit, 0); XCTAssertLessThan(p.profitPct10, 0)
        let c = Cost(lines: [CostLine(group: "lab", key: "x", qty: 1, unit: "order", price: 769, amount: 769, missing: false)], layouts: [], rows: [])
        XCTAssertEqual(Priced(cost: c, price: 1000, lines: []).profitPct10, 231)
    }

    func testModulesGetReadableLabels() {
        let l = labelled([kitchen, ward])
        let a = l[0].modules.filter { $0.wall == "A" }
        XCTAssertEqual(a.first { !isUpper($0) }?.label, "A1")
        XCTAssertTrue(a.filter(isUpper).allSatisfy { $0.label.hasPrefix("A") && Int($0.label.dropFirst())! > 6 })   // the upper row after the lower one
        XCTAssertEqual(l[1].modules.map(\.label), ["Sh1"])
    }

    func testAFurnitureQuoteCarriesItsPriceAndOldQuotesStillLoad() throws {
        var p = Project(id: "p", name: "Oshxona")
        p.industry = "furniture"; p.furniture = [kitchen]
        let s = AppSettings.shared
        let sn = furnSnap(snapshotOf(p), p, s.workshop, s.mats, s.hws)
        XCTAssertEqual(sn.furniture.count, 1)
        XCTAssertEqual(sn.ftotal, Money.digits(priceOf([kitchen], p.fprice, s.workshop, s.mats, s.hws).price))
        XCTAssertTrue(sn.fmats.contains { $0.id == "wt38" })
        XCTAssertFalse(furniturePages(sn, draft: true, meta: nil, image: { _ in nil }).isEmpty)
        let pr = priceOf(sn.furniture, p.fprice, s.workshop, s.mats, s.hws)
        XCTAssertGreaterThan(workshopPages(sn, s.workshop, s.mats, s.hws, pr, "margin").count, 2)
        // a quote saved before furniture orders has none of the new fields
        let old = #"{"name":"Uy","rooms":[],"estimate":{"materials":[],"labor":[]},"extras":[]}"#
        let back = try JSONDecoder().decode(Snap.self, from: Data(old.utf8))
        XCTAssertEqual(back.name, "Uy"); XCTAssertTrue(back.furniture.isEmpty); XCTAssertEqual(back.fprepay, 50)
        // a builder's fingerprint does not change with the furniture fields
        var b = Project(id: "b", name: "Uy")
        b.estimate = Estimate()
        XCTAssertFalse(fingerprint(snapshotOf(b)).contains("furniture"))
    }
}
