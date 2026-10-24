import Foundation

/*
 * The pure rules behind the laser's radar page (Main/LaserRadar.swift) and RealLaser (Android laser/LinkRules.kt, the
 * same numbers): where a laser sits on the radar, what a disconnect means, when a run of failures becomes "busy" or
 * "3 tries", how long to wait before the next try. No CoreBluetooth here (unit-tested in LaserLinkRulesTests).
 */

/// Why a connection the builder asked for did not come up (or went away): each has its own card on the radar page.
enum LaserFail: Equatable {
    /// No answer within LaserLinkRules.answerMs (laser off or too far).
    case timeout
    /// The laser drops the link at once, again and again: most likely another phone holds it.
    case busy
    /// Connected, but it has no SPS service: not a laser METRX can read.
    case notLaser
    /// Bluetooth was turned off while connecting.
    case btOff
    /// iOS refused the Bluetooth permission.
    case permission
}

/// What one disconnect during a try means (Android DropKind).
enum LaserDrop: Equatable {
    /// The link was up and ready: it went away (laser off or out of range).
    case lost
    /// Dropped at once (right after connecting, or a refusal): counted towards LaserFail.busy.
    case quick
    /// Anything else before the link was ready: treated like no answer.
    case noAnswer
}

enum LaserLinkRules {
    /// A try that has had no "connected" for this long has failed (the founder's laser answers in ~0.2 s).
    static let answerMs: Int64 = 10_000
    /// A drop this soon after "connected" is a quick drop.
    static let quickMs: Int64 = 2_000
    /// Android's GATT statuses for a refusal at once (133 GATT_ERROR, 8 CONN_TIMEOUT, 257 FAILURE); iOS gives none, its
    /// didFailToConnect is taken as a refusal directly.
    static let quickStatuses: Set<Int> = [133, 8, 257]
    /// This many quick drops in one try: "busy" (the first one is retried by itself).
    static let busyAfter = 2
    /// This many failed tries in a row: the help list instead of the single reason.
    static let manyAfter = 3
    /// The radar page's countdown after the link is lost, before the app connects again by itself.
    static let lostWaitMs: Int64 = 4_000
    /// The pause before a quick drop is retried.
    static let quickRetryMs: Int64 = 800
    /// The pauses between background reconnects, growing (seconds).
    private static let backoffS: [Int64] = [2, 4, 8, 15, 30, 45, 60]

    static func drop(status: Int, ready: Bool, gattUp: Bool, msSinceUp: Int64) -> LaserDrop {
        if ready { return .lost }
        if gattUp && msSinceUp >= 0 && msSinceUp <= quickMs { return .quick }
        if !gattUp && quickStatuses.contains(status) { return .quick }
        return .noAnswer
    }

    static func isBusy(_ quickDrops: Int) -> Bool { quickDrops >= busyAfter }

    /// After streak failed tries in a row, the help list replaces the fixable reasons (not "not a laser" and the like).
    static func showMany(_ fail: LaserFail, _ streak: Int) -> Bool {
        (fail == .timeout || fail == .busy) && streak >= manyAfter
    }

    /// The pause before background try number attempt (0 first); the radar page, open, never waits longer than its countdown.
    static func backoffMs(_ attempt: Int, radarOpen: Bool) -> Int64 {
        let i = min(max(attempt, 0), backoffS.count - 1)
        let d = backoffS[i] * 1000
        return radarOpen ? min(d, lostWaitMs) : d
    }

    /// Whole seconds left until at (rounded up) and how much of total has passed (0…1).
    static func countdown(now: Int64, at: Int64, total: Int64) -> (secs: Int, done: Double) {
        let left = max(at - now, 0)
        let s = Int((left + 999) / 1000)
        let p: Double = total <= 0 ? 1 : min(max(1 - Double(left) / Double(total), 0), 1)
        return (s, p)
    }
}

/// Where a laser sits on the radar: angle from its identifier (stable), distance from its signal.
enum LaserRadarMath {
    /// −45 dBm sits nearest the centre, −90 dBm at the edge.
    static let near: Double = -45
    static let far: Double = -90
    /// Distance from the centre as a part of the radar's radius (just outside the phone disc … the outer ring).
    static let rMin: Double = 0.52
    static let rMax: Double = 0.92
    /// A laser not heard for this long leaves the radar.
    static let staleMs: Int64 = 20_000

    static func radius(_ rssi: Double) -> Double {
        let t = min(max((near - rssi) / (near - far), 0), 1)
        return rMin + t * (rMax - rMin)
    }

    /// Degrees 0…360 (0 = right, clockwise on screen), the same for one address every time (FNV-1a over UTF-16, as Android).
    static func angle(_ address: String) -> Double {
        var h: UInt32 = 0x811C_9DC5
        for c in address.uppercased().utf16 {
            h ^= UInt32(c)
            h = h &* 0x0100_0193
        }
        return Double(h % 3600) / 10
    }

    /// Signal bars 1…4.
    static func bars(_ rssi: Int) -> Int {
        if rssi > -55 { return 4 }
        if rssi > -65 { return 3 }
        if rssi > -78 { return 2 }
        return 1
    }

    /// The word for the signal (string key).
    static func qualityKey(_ rssi: Int) -> String {
        switch bars(rssi) {
        case 4, 3: return "lr.sigGood"
        case 2: return "lr.sigOk"
        default: return "lr.sigWeak"
        }
    }

    /// A smoothed signal: each new reading moves the old value by k (the first one is taken as it is).
    static func smooth(_ prev: Double?, _ next: Int, k: Double = 0.35) -> Double {
        guard let prev else { return Double(next) }
        return prev + (Double(next) - prev) * k
    }

    static func stale(_ seenAt: Int64, _ now: Int64) -> Bool { seenAt > 0 && now - seenAt > staleMs }
}
