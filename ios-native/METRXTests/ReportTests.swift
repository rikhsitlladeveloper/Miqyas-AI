import XCTest
import PDFKit
@testable import METRX

/// The report (Android ReportTest): what changes the fingerprint and what does not, the quote total, the file name,
/// and the PDF itself: one page per report page, text kept as text.
@MainActor
final class ReportTests: XCTestCase {
    private func project() -> Project {
        var p = Project(id: "rt", name: "Yangi uy", customer: "Ali Valiyev", phone: "901112233", address: "Chilonzor 9")
        var r = Room(id: "r1", floorId: "f1", name: "Mehmonxona")
        r.dims["A"] = Dim(v: 5000, src: "manual"); r.dims["B"] = Dim(v: 4000, src: "manual"); r.dims["H"] = Dim(v: 3000, src: "manual")
        r.openings = [Opening(id: "o1", type: "door", wall: "A", w: 900, h: 2100, off: 500), Opening(id: "o2", type: "window", wall: "C", w: 1200, h: 1500, off: 1900, sill: 900)]
        p.floors = [Workspace(id: "f1", name: "@floor1")]
        p.rooms = [r]
        p.estimate.materials = [Row(id: "m1", name: "Bo‘yoq", unit: "@u.pcs", qty: "12", price: "50000"), Row(id: "m2", name: "Laminat", unit: "@u.m2", qty: "22", price: "120000")]
        p.estimate.labor = [Row(id: "l1", name: "Ish haqi", amount: "1000000")]
        return p
    }

    func testFingerprint() {
        var p = project()
        let a = fingerprint(snapshotOf(p))
        p.stage = "quote"; p.edited = 99
        XCTAssertEqual(fingerprint(snapshotOf(p)), a, "the stage and edit time are not part of the report")
        p.estimate.labor[0].amount = "1000001"
        XCTAssertNotEqual(fingerprint(snapshotOf(p)), a, "an estimate change is")
        p = project(); p.rooms[0].dims["A"] = Dim(v: 5010)
        XCTAssertNotEqual(fingerprint(snapshotOf(p)), a, "a measurement change is")
        p = project(); p.reportLang = "ru"
        XCTAssertNotEqual(fingerprint(snapshotOf(p)), a, "the report language is")
    }

    func testQuoteTotalAndName() {
        let p = project()
        let q = freezeQuote(p, snapshotOf(p), 1, 1_760_000_000_000)
        XCTAssertEqual(q.total, "4240000")
        XCTAssertEqual(q.no, 1)
        XCTAssertEqual(pdfName("Yangi uy", "Taklif №2"), "Yangi_uy_Taklif_2.pdf")
    }

    func testPdf() throws {
        let p = project()
        let pages = reportPages(snapshotOf(p), draft: true, meta: nil, image: { _ in nil })
        XCTAssertGreaterThanOrEqual(pages.count, 2)
        let url = try XCTUnwrap(pdfFile(pages, "test.pdf"))
        let doc = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertEqual(doc.pageCount, pages.count)
        let text = (doc.string ?? "").replacingOccurrences(of: "\u{00A0}", with: " ")
        XCTAssertTrue(text.contains("Mehmonxona"), "the text reads back from the PDF")
        XCTAssertTrue(text.contains("4 240 000"), "the grand total is on the estimate page")
        XCTAssertNotNil(pageImage(pages[0], width: 300))
    }
}
