import XCTest
@testable import METRX

/// The order location's fix rules (founder decisions, 27 Oct 2026; UX/GpsRules.swift): the best reading wins, done by
/// itself at ±20 m, the best one after 30 s, a failure only with none, and a recent accurate cached fix as the first value.
final class GpsRulesTests: XCTestCase {
    private let now = 1_800_000_000.0

    private func s(_ acc: Double, age: Double = 0, cached: Bool = false, lat: Double = 41.3111, lng: Double = 69.2797) -> GpsSample {
        GpsSample(lat: lat, lng: lng, acc: acc, at: now - age, cached: cached)
    }

    // best-fix choice

    func testTheFirstRealReadingIsTheBest() {
        XCTAssertEqual(GpsRules.pick(nil, s(65), now: now), s(65))
    }

    func testASmallerAccuracyWinsAndAWorseOneIsKept() {
        XCTAssertEqual(GpsRules.pick(s(65), s(12), now: now)?.acc, 12)
        XCTAssertEqual(GpsRules.pick(s(12), s(40), now: now)?.acc, 12)
    }

    func testAtTheSameAccuracyALiveReadingBeatsTheCachedOneAndANewerAnOlder() {
        let p = GpsRules.pick(s(30, cached: true), s(30), now: now)
        XCTAssertEqual(p?.cached, false)
        XCTAssertEqual(GpsRules.pick(s(30), s(30, cached: true), now: now)?.cached, false)
        XCTAssertEqual(GpsRules.pick(s(30, age: 5), s(30, age: 1), now: now)?.at, now - 1)
    }

    func testInvalidReadingsNeverWin() {
        XCTAssertEqual(GpsRules.pick(s(50), s(-1), now: now)?.acc, 50)
        XCTAssertNil(GpsRules.pick(nil, s(0), now: now))
        XCTAssertNil(GpsRules.pick(nil, s(.infinity), now: now))
        XCTAssertNil(GpsRules.pick(nil, s(10, lat: 0, lng: 0), now: now))
        XCTAssertNil(GpsRules.pick(nil, s(10, lat: 95), now: now))
    }

    func testAStaleBestGivesWayToAnyRealReading() {
        let p = GpsRules.pick(s(8, age: 200), s(60), now: now)
        XCTAssertEqual(p?.acc, 60)
    }

    func testTheKeptFixHasWholeMetresAndItsOwnTime() {
        let l = s(12.6, age: 3).loc
        XCTAssertEqual(l.acc, 13)
        XCTAssertEqual(l.ts, Ms((now - 3) * 1000))
        XCTAssertEqual(s(0.3).loc.acc, 1)
    }

    // stop rules

    func testItWaitsWithNothingOrAPoorFixInsideThe30Seconds() {
        XCTAssertEqual(GpsRules.next(best: nil, elapsed: 2), .wait)
        XCTAssertEqual(GpsRules.next(best: s(65), elapsed: 10), .wait)
        XCTAssertEqual(GpsRules.next(best: s(21), elapsed: 29.9), .wait)
    }

    func testItStopsByItselfAt20MetresOrBetter() {
        XCTAssertEqual(GpsRules.next(best: s(20), elapsed: 1), .stop)
        XCTAssertEqual(GpsRules.next(best: s(4), elapsed: 0), .stop)
    }

    func testACachedFixNeverEndsTheSearchByItself() {
        XCTAssertEqual(GpsRules.next(best: s(5, cached: true), elapsed: 1), .wait)
        XCTAssertEqual(GpsRules.next(best: s(5, cached: true), elapsed: 30), .stop)
    }

    func testAfter30SecondsTheBestIsKeptAndOnlyNoneFails() {
        XCTAssertEqual(GpsRules.next(best: s(85), elapsed: 30), .stop)
        XCTAssertEqual(GpsRules.next(best: nil, elapsed: 30), .fail)
        XCTAssertEqual(GpsRules.next(best: nil, elapsed: 45), .fail)
    }

    func testAnApproximatePlaceIsTakenAtItsFirstLiveReading() {
        XCTAssertEqual(GpsRules.next(best: s(1800), elapsed: 1, reduced: true), .stop)
        XCTAssertEqual(GpsRules.next(best: s(1800, cached: true), elapsed: 1, reduced: true), .wait)
    }

    // freshness

    func testACachedFixUnder2MinutesAndAccurateIsUsable() {
        XCTAssertTrue(GpsRules.cacheUsable(s(40, age: 30, cached: true), now: now))
        XCTAssertTrue(GpsRules.cacheUsable(s(100, age: 119, cached: true), now: now))
    }

    func testAnOldOrInaccurateCachedFixIsNot() {
        XCTAssertFalse(GpsRules.cacheUsable(s(40, age: 121, cached: true), now: now))
        XCTAssertFalse(GpsRules.cacheUsable(s(101, age: 10, cached: true), now: now))
        XCTAssertFalse(GpsRules.cacheUsable(s(-1, age: 10, cached: true), now: now))
    }

    func testAFewSecondsFromTheFutureAreJitterButMoreIsNotFresh() {
        XCTAssertTrue(GpsRules.fresh(s(10, age: -3), now: now))
        XCTAssertFalse(GpsRules.fresh(s(10, age: -60), now: now))
    }
}
