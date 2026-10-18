import XCTest
@testable import METRX

/// Furniture orders (Android OrdersTest, CalcTest sheets): stages, the prepayment, payments, what customers owe, and the
/// sheets tool of the Measure page.
final class FurnitureTests: XCTestCase {
    private func order(_ stage: String = "quote") -> Project { var p = Project(id: "p1", name: "Oshxona"); p.industry = "furniture"; p.stage = stage; return p }

    func testApprovingRecordsPriceAndPrepayment() {
        let p = approve(order(), 32_067_100, halfOf(32_067_100), 1)
        XCTAssertEqual(p.stage, "approved")
        XCTAssertEqual(orderMoney(p).paid, 16_033_550)
        XCTAssertEqual(orderMoney(p).left, 16_033_550)
        XCTAssertEqual(p.payments.count, 1); XCTAssertTrue(p.payments[0].pre)
    }

    func testHalfRoundsHalfUp() {
        XCTAssertEqual(halfOf(32_067_100), 16_033_550)
        XCTAssertEqual(halfOf(11), 6)
    }

    func testApprovingIsNotAPlainNextStep() {
        XCTAssertEqual(nextStage(order("quote")).stage, "quote")
        XCTAssertEqual(nextStage(order("measure")).stage, "design")
        XCTAssertEqual(nextStage(order("production")).stage, "installed")
    }

    func testLastPaymentOfAnInstalledOrderMakesItPaid() {
        var p = approve(order(), 1000, 500, 1)
        p = nextStage(nextStage(p))                     // production, installed
        XCTAssertEqual(p.stage, "installed")
        p = addPayment(p, 500, "", 2)
        XCTAssertEqual(p.stage, "paid")
        XCTAssertEqual(orderMoney(p).left, 0)
        // taking that payment away again puts the order back to installed
        p = removePayment(p, p.payments.last!.id)
        XCTAssertEqual(p.stage, "installed")
    }

    func testPaidInProductionGoesStraightToPaid() {
        var p = nextStage(approve(order(), 1000, 1000, 1))
        XCTAssertEqual(p.stage, "production")
        p = nextStage(p)                                 // installed with nothing left → paid
        XCTAssertEqual(p.stage, "paid")
    }

    func testOwedCountsApprovedOrdersOnly() {
        var design = order("design"); design.id = "a"; design.agreed = "999"
        var o = order(); o.id = "b"
        let approved = approve(o, 1000, 400, 1)
        var builder = Project(id: "c", name: "Uy"); builder.agreed = "5000"; builder.stage = "work"
        let (sum, n) = owed([design, approved, builder])
        XCTAssertEqual(sum, 600); XCTAssertEqual(n, 1)
    }

    func testNoPriceMeansNothingLeft() {
        XCTAssertNil(orderMoney(order()).left)
        var p = Project(id: "x", name: "y"); p.stage = "estimate"
        XCTAssertEqual(fStage(p), 0)
    }

    func testOldProjectsAreBuildersAndOrdersKeepTheirMoney() throws {
        let old = try JSONDecoder().decode(Project.self, from: Data(#"{"id":"o","name":"Uy"}"#.utf8))
        XCTAssertEqual(old.industry, "build"); XCTAssertFalse(old.isFurniture)
        let p = approve(order(), 1000, 500, 1)
        let back = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back, p)
    }

    func testSheetsForASurface() {
        // a whole sheet with no waste is one sheet; 15 % waste on top of it needs a second one (the Android cases)
        XCTAssertEqual(sheetsFor(2800 * 2070, waste: 0), 1)
        XCTAssertEqual(sheetsFor(2800 * 2070), 2)
        // 3,00 × 2,00 m = 6 m², +15 % = 6,9 m² over 5,796 m² sheets → 2
        XCTAssertEqual(sheetsFor(3000 * 2000), 2)
        XCTAssertEqual(sheetsFor(1000 * 1000), 1)
    }
}
