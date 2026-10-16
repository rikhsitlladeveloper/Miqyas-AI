import XCTest
@testable import METRX

/// The estimate's arithmetic (Android MoneyTest): no sum is rounded by floating point, the prototype's typing rules,
/// half-up rounding and the display of amounts.
final class MoneyTests: XCTestCase {
    private func project(_ mats: [(String, String)], _ labor: [String]) -> Project {
        var p = Project(id: "t", name: "Test")
        p.estimate.materials = mats.enumerated().map { i, m in Row(id: "m\(i)", name: "M", unit: "@u.pcs", qty: m.0, price: m.1) }
        p.estimate.labor = labor.enumerated().map { i, a in Row(id: "l\(i)", name: "L", amount: a) }
        return p
    }

    /// BUILD_PLAN: paint 12 × 50 000, flooring 22 × 120 000, labour 1 000 000 → 4 240 000 so'm.
    func testBuildPlanTotal() {
        let t = Money.totals(project([("12", "50000"), ("22", "120000")], ["1000000"]))
        XCTAssertEqual(t.m, 3_240_000)
        XCTAssertEqual(t.l, 1_000_000)
        XCTAssertEqual(t.g, 4_240_000)
        XCTAssertEqual(Money.str(t.g, 0, false), "4 240 000")
        XCTAssertEqual(Money.short(project([("12", "50000"), ("22", "120000")], ["1000000"]), t.g, false, "mln").0, "4,24")
    }

    func testTypingRules() {
        XCTAssertEqual(Money.parse("4,25", 3), .ok(4250))
        XCTAssertEqual(Money.parse("4.25", 3), .ok(4250))
        XCTAssertEqual(Money.parse("120 000", 0), .ok(120_000))
        XCTAssertEqual(Money.parse("", 0), .empty)
        XCTAssertEqual(Money.parse("abc", 0), .format)
        XCTAssertEqual(Money.parse(",", 3), .format)
        XCTAssertEqual(Money.parse("-5", 0), .negative)
        XCTAssertEqual(Money.parse("1.5", 0), .precision(0))
        XCTAssertEqual(Money.parse("1.2345", 3), .precision(3))
        XCTAssertEqual(Money.canon("120 000"), "120000")
        XCTAssertEqual(Money.canon("4,50"), "4.50")
        XCTAssertEqual(Money.canon("007"), "7")
        XCTAssertEqual(Money.canon("5."), "5")
    }

    func testHalfUp() {
        XCTAssertEqual(Money.line("0.001", "500", 0), 1)      // 0.5 → 1
        XCTAssertEqual(Money.line("0.001", "499", 0), 0)      // 0.499 → 0
        XCTAssertEqual(Money.withSpare("150,06"), "165.066")
        // the wall area with 10 % spare at 120 000 a square metre
        XCTAssertEqual(Money.line(Money.withSpare("150,06"), "120000", 0), 19_807_920)
        // no floating point: a large amount stays exact
        XCTAssertEqual(Money.line("123456.789", "987654321", 0), Decimal(string: "121932631112635")!)
    }

    func testDisplay() {
        XCTAssertEqual(Money.str(18_000_000, 0, false), "18 000 000")
        XCTAssertEqual(Money.str(18_000_000, 0, true), "18,000,000")
        XCTAssertEqual(Money.str(1850, 2, false), "18,50")
        XCTAssertEqual(Money.str(5, 2, true), "0.05")
        XCTAssertEqual(Money.num("1500.5", false), "1 500,5")
        XCTAssertEqual(Money.num("1500", true), "1,500")
    }
}
