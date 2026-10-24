import XCTest
@testable import METRX

/// The radar page's pure rules (Laser/LaserLinkRules.swift; Android LinkRulesTest, the same numbers): placing lasers,
/// reading drops, counting tries, waiting.
final class LaserLinkRulesTests: XCTestCase {
    private let eps = 1e-4

    // ---- RSSI → distance from the centre ----

    func testStrongSignalSitsNearTheCentreWeakAtTheEdge() {
        XCTAssertEqual(LaserRadarMath.radius(-45), LaserRadarMath.rMin, accuracy: eps)
        XCTAssertEqual(LaserRadarMath.radius(-90), LaserRadarMath.rMax, accuracy: eps)
        XCTAssertEqual(LaserRadarMath.radius(-67.5), (LaserRadarMath.rMin + LaserRadarMath.rMax) / 2, accuracy: eps)
    }

    func testRadiusIsClampedAndMonotonic() {
        XCTAssertEqual(LaserRadarMath.radius(-20), LaserRadarMath.rMin, accuracy: eps)
        XCTAssertEqual(LaserRadarMath.radius(-110), LaserRadarMath.rMax, accuracy: eps)
        var last = 0.0
        for r in stride(from: -45, through: -90, by: -1) {
            let v = LaserRadarMath.radius(Double(r))
            XCTAssertGreaterThanOrEqual(v, last)
            last = v
        }
    }

    func testSmoothingMovesPartWayAndTakesTheFirstValueAsItIs() {
        XCTAssertEqual(LaserRadarMath.smooth(nil, -60), -60, accuracy: eps)
        let s = LaserRadarMath.smooth(-60, -80)
        XCTAssertTrue(s < -60 && s > -80)
        // many equal readings converge
        var v: Double? = nil
        for _ in 0..<40 { v = LaserRadarMath.smooth(v, -70) }
        XCTAssertEqual(v ?? 0, -70, accuracy: 0.01)
    }

    func testBarsAndWords() {
        XCTAssertEqual(LaserRadarMath.bars(-50), 4)
        XCTAssertEqual(LaserRadarMath.bars(-58), 3)
        XCTAssertEqual(LaserRadarMath.bars(-70), 2)
        XCTAssertEqual(LaserRadarMath.bars(-85), 1)
        XCTAssertEqual(LaserRadarMath.qualityKey(-58), "lr.sigGood")
        XCTAssertEqual(LaserRadarMath.qualityKey(-70), "lr.sigOk")
        XCTAssertEqual(LaserRadarMath.qualityKey(-88), "lr.sigWeak")
    }

    // ---- stable angle ----

    func testAngleIsStablePerAddressAndInRange() {
        let a = LaserRadarMath.angle("38:1F:C5:55:2E:C8")
        XCTAssertEqual(a, LaserRadarMath.angle("38:1F:C5:55:2E:C8"))
        XCTAssertEqual(a, LaserRadarMath.angle("38:1f:c5:55:2e:c8"))
        XCTAssertTrue(a >= 0 && a < 360)
        let many: [Double] = (0..<50).map { (i: Int) -> Double in
            let hex = String(i, radix: 16, uppercase: true)
            let two = hex.count < 2 ? "0" + hex : hex
            return LaserRadarMath.angle("AA:BB:CC:DD:EE:" + two)
        }
        XCTAssertTrue(many.allSatisfy { $0 >= 0 && $0 < 360 })
        XCTAssertGreaterThan(Set(many).count, 40, "addresses spread round the radar")
        // iPhone identifiers (UUID strings) land in range too
        let u = LaserRadarMath.angle("6F1C2A9E-1B7D-4C5A-9E0F-3D2B1A0C9E8F")
        XCTAssertTrue(u >= 0 && u < 360)
    }

    func testStaleLasersLeave() {
        XCTAssertFalse(LaserRadarMath.stale(1_000, 1_000 + LaserRadarMath.staleMs))
        XCTAssertTrue(LaserRadarMath.stale(1_000, 1_001 + LaserRadarMath.staleMs))
        XCTAssertFalse(LaserRadarMath.stale(0, 99_999_999), "never seen counts as fresh")
    }

    // ---- failure classification from disconnects ----

    func testAReadyLinkThatDropsIsLost() {
        XCTAssertEqual(LaserLinkRules.drop(status: 8, ready: true, gattUp: true, msSinceUp: 60_000), .lost)
        XCTAssertEqual(LaserLinkRules.drop(status: 0, ready: true, gattUp: true, msSinceUp: 100), .lost)
    }

    func testADropRightAfterConnectingIsQuick() {
        XCTAssertEqual(LaserLinkRules.drop(status: 19, ready: false, gattUp: true, msSinceUp: 300), .quick)
        XCTAssertEqual(LaserLinkRules.drop(status: 0, ready: false, gattUp: true, msSinceUp: LaserLinkRules.quickMs), .quick)
        XCTAssertEqual(LaserLinkRules.drop(status: 0, ready: false, gattUp: true, msSinceUp: LaserLinkRules.quickMs + 1), .noAnswer)
    }

    func testRefusalStatusesBeforeConnectingAreRefusalsOthersAreNoAnswer() {
        for s in [133, 8, 257] {
            XCTAssertEqual(LaserLinkRules.drop(status: s, ready: false, gattUp: false, msSinceUp: -1), .refused)
        }
        XCTAssertEqual(LaserLinkRules.drop(status: 62, ready: false, gattUp: false, msSinceUp: -1), .noAnswer)
        XCTAssertEqual(LaserLinkRules.drop(status: 0, ready: false, gattUp: false, msSinceUp: -1), .noAnswer)
    }

    func testBusyOnlyAfterALinkWasEstablished() {
        // two quick refusals before any "connected": never quick, so never counted towards busy
        for _ in 0..<2 { XCTAssertEqual(LaserLinkRules.drop(status: 133, ready: false, gattUp: false, msSinceUp: -1), .refused) }
        // two drops right after "connected": quick, and the second is busy
        let quick: [LaserDrop] = (1...2).map { _ in LaserLinkRules.drop(status: 133, ready: false, gattUp: true, msSinceUp: 200) }
        XCTAssertTrue(quick.allSatisfy { $0 == .quick })
        XCTAssertTrue(LaserLinkRules.isBusy(quick.count))
    }

    func testRefusalsAndFailedDiscoveriesAreRetriedOnceForTheBuilder() {
        XCTAssertTrue(LaserLinkRules.softRetry(1, user: true))
        XCTAssertFalse(LaserLinkRules.softRetry(2, user: true))
        // a background try is not retried at once: its plan tries again later
        XCTAssertFalse(LaserLinkRules.softRetry(1, user: false))
    }

    // ---- service discovery ----

    func testAFailedDiscoveryIsRetriedNeverNotALaser() {
        XCTAssertEqual(LaserLinkRules.discovery(status: 133, services: 0, sps: false), .retry)
        XCTAssertEqual(LaserLinkRules.discovery(status: 129, services: 5, sps: false), .retry)
        XCTAssertEqual(LaserLinkRules.discovery(status: 133, services: 5, sps: true), .retry)
        // "success" with nothing in it (a stale GATT cache) says nothing about the device either
        XCTAssertEqual(LaserLinkRules.discovery(status: 0, services: 0, sps: false), .retry)
    }

    func testNotALaserOnlyAfterADiscoveryThatWorked() {
        XCTAssertEqual(LaserLinkRules.discovery(status: 0, services: 4, sps: false), .notLaser)
        XCTAssertEqual(LaserLinkRules.discovery(status: 0, services: 4, sps: true), .ok)
    }

    // ---- background tries ----

    func testBackgroundTriesStopAfterFiveOrThreeWithTheRadarOpen() {
        XCTAssertFalse(LaserLinkRules.bgCapped(LaserLinkRules.bgTries - 1, radarOpen: false))
        XCTAssertTrue(LaserLinkRules.bgCapped(LaserLinkRules.bgTries, radarOpen: false))
        XCTAssertFalse(LaserLinkRules.bgCapped(2, radarOpen: true))
        XCTAssertTrue(LaserLinkRules.bgCapped(LaserLinkRules.radarBgTries, radarOpen: true))
        XCTAssertLessThan(LaserLinkRules.radarBgTries, LaserLinkRules.bgTries)
        XCTAssertEqual(LaserLinkRules.bgTries, 5)
        XCTAssertEqual(LaserLinkRules.radarBgTries, 3)
    }

    func testTheFallbackScanKnowsTheRememberedLaserByIdentifierOrName() {
        let addr = "38:1F:C5:55:2E:C8"
        XCTAssertTrue(LaserLinkRules.sameLaser(savedAddr: addr, savedName: "ZB-08", addr: addr, name: nil))
        XCTAssertTrue(LaserLinkRules.sameLaser(savedAddr: addr, savedName: "ZB-08", addr: addr.lowercased(), name: "ZB-08"))
        // a new identifier with the same name: learned again
        XCTAssertTrue(LaserLinkRules.sameLaser(savedAddr: addr, savedName: "ZB-08", addr: "11:22:33:44:55:66", name: " zb-08 "))
        // another laser, or no name to go by
        XCTAssertFalse(LaserLinkRules.sameLaser(savedAddr: addr, savedName: "ZB-08", addr: "11:22:33:44:55:66", name: "ZB-10"))
        XCTAssertFalse(LaserLinkRules.sameLaser(savedAddr: addr, savedName: "ZB-08", addr: "11:22:33:44:55:66", name: nil))
        XCTAssertFalse(LaserLinkRules.sameLaser(savedAddr: addr, savedName: nil, addr: "11:22:33:44:55:66", name: "ZB-08"))
        // iPhone identifiers (UUIDs) work the same way
        let id = UUID().uuidString
        XCTAssertTrue(LaserLinkRules.sameLaser(savedAddr: id, savedName: nil, addr: id.lowercased(), name: nil))
    }

    // ---- redrawing the radar ----

    func testADeviceIsRedrawnAtMostTwiceASecondUnlessItReallyChanged() {
        let a = LzFound(id: UUID(), name: "ZB-08", rssi: -60, laser: true, avg: -60, seen: 1_000)
        func with(_ f: (inout LzFound) -> Void) -> LzFound { var d = a; f(&d); return d }
        XCTAssertTrue(LaserRadarMath.publish(shown: nil, next: a, now: 1_000))
        XCTAssertFalse(LaserRadarMath.publish(shown: a, next: with { $0.rssi = -61; $0.avg = -60.4; $0.seen = 1_200 }, now: 1_200))
        XCTAssertTrue(LaserRadarMath.publish(shown: a, next: with { $0.avg = -60.4; $0.seen = 1_500 }, now: 1_500))
        XCTAssertTrue(LaserRadarMath.publish(shown: a, next: with { $0.avg = -62; $0.seen = 1_100 }, now: 1_100))
        XCTAssertTrue(LaserRadarMath.publish(shown: a, next: with { $0.laser = false; $0.seen = 1_100 }, now: 1_100))
        XCTAssertTrue(LaserRadarMath.publish(shown: a, next: with { $0.name = "ZB-09"; $0.seen = 1_100 }, now: 1_100))
    }

    func testOneQuickDropIsRetriedTheSecondIsBusy() {
        XCTAssertFalse(LaserLinkRules.isBusy(1))
        XCTAssertTrue(LaserLinkRules.isBusy(2))
        XCTAssertTrue(LaserLinkRules.isBusy(3))
    }

    // ---- attempt counting and backoff ----

    func testThreeFailedTriesShowTheHelpListForFixableReasonsOnly() {
        XCTAssertFalse(LaserLinkRules.showMany(.timeout, 2))
        XCTAssertTrue(LaserLinkRules.showMany(.timeout, 3))
        XCTAssertTrue(LaserLinkRules.showMany(.busy, 4))
        XCTAssertFalse(LaserLinkRules.showMany(.notLaser, 5))
        XCTAssertFalse(LaserLinkRules.showMany(.btOff, 3))
        XCTAssertFalse(LaserLinkRules.showMany(.permission, 3))
    }

    func testBackoffGrowsThenStaysAndTheOpenRadarCapsIt() {
        let waits: [Int64] = (0...9).map { LaserLinkRules.backoffMs($0, radarOpen: false) }
        XCTAssertEqual(waits[0], 2_000)
        for i in 1..<waits.count { XCTAssertGreaterThanOrEqual(waits[i], waits[i - 1]) }
        XCTAssertEqual(waits.last, 60_000)
        XCTAssertEqual(LaserLinkRules.backoffMs(0, radarOpen: true), 2_000)
        XCTAssertEqual(LaserLinkRules.backoffMs(6, radarOpen: true), LaserLinkRules.lostWaitMs)
        XCTAssertEqual(LaserLinkRules.backoffMs(-3, radarOpen: false), 2_000)
    }

    func testCountdownRoundsUpAndFillsTheBar() {
        let a = LaserLinkRules.countdown(now: 0, at: 4_000, total: 4_000)
        XCTAssertEqual(a.secs, 4); XCTAssertEqual(a.done, 0, accuracy: eps)
        XCTAssertEqual(LaserLinkRules.countdown(now: 1_001, at: 4_000, total: 4_000).secs, 3)
        XCTAssertEqual(LaserLinkRules.countdown(now: 2_000, at: 4_000, total: 4_000).done, 0.5, accuracy: eps)
        let d = LaserLinkRules.countdown(now: 5_000, at: 4_000, total: 4_000)
        XCTAssertEqual(d.secs, 0); XCTAssertEqual(d.done, 1, accuracy: eps)
        XCTAssertEqual(LaserLinkRules.countdown(now: 0, at: 0, total: 0).done, 1, accuracy: eps)
    }
}
