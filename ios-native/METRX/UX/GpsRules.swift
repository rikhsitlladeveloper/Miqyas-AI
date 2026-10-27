import Foundation

/*
 * The order location's fix rules (founder decisions, 27 Oct 2026): best accuracy (GPS, Wi-Fi and cell together), the
 * first reading at once with "Aniqlik: ±X m", better ones for up to 30 s, done by itself at ±20 m or better; after 30 s
 * the best one so far, a failure only when there is none. The phone's last fix can be the first value when it is under
 * 2 min old and ±100 m or better; it is labelled and never ends the search by itself. Pure, so it is unit-tested
 * (METRXTests/GpsRulesTests.swift); UX/OrderLocation.swift's Gps runs it on CoreLocation.
 */

/// One reading: where, how sure (horizontal metres), when (seconds since 1970) and whether it is the phone's cached fix.
struct GpsSample: Equatable {
    var lat: Double
    var lng: Double
    var acc: Double
    var at: Double
    var cached = false

    /// What an order keeps: whole metres (at least 1) and the reading's own time.
    var loc: Location { Location(lat: lat, lng: lng, acc: max(1, Int(acc.rounded())), ts: Ms(at * 1000)) }
}

enum GpsRules {
    /// Done by itself at this accuracy or better.
    static let goodM = 20.0
    /// Keep improving this long after the search starts.
    static let maxS = 30.0
    /// A cached fix this young…
    static let freshS = 120.0
    /// …and this accurate can be the first value.
    static let cacheM = 100.0

    /// A real reading: a positive, finite accuracy and coordinates on the globe.
    static func valid(_ s: GpsSample) -> Bool {
        guard s.acc > 0, s.acc.isFinite, s.lat.isFinite, s.lng.isFinite else { return false }
        return abs(s.lat) <= 90 && abs(s.lng) <= 180 && !(s.lat == 0 && s.lng == 0)
    }

    /// Under 2 min old (a few seconds "from the future" are a clock's jitter, not a reason to drop it).
    static func fresh(_ s: GpsSample, now: Double) -> Bool {
        let age = now - s.at
        return age <= freshS && age >= -5
    }

    /// The phone's cached fix may be the instant first value.
    static func cacheUsable(_ s: GpsSample, now: Double) -> Bool {
        valid(s) && fresh(s, now: now) && s.acc <= cacheM
    }

    /// The better of the best so far and a new reading: a smaller ±m wins; at the same ±m a live reading beats a cached
    /// one and a newer one an older one; a best that went stale (over 2 min) gives way to any real reading.
    static func pick(_ cur: GpsSample?, _ new: GpsSample, now: Double) -> GpsSample? {
        guard valid(new) else { return cur }
        guard let cur, valid(cur), fresh(cur, now: now) else { return new }
        if new.acc < cur.acc { return new }
        if new.acc > cur.acc { return cur }
        if cur.cached && !new.cached { return new }
        if new.cached && !cur.cached { return cur }
        return new.at >= cur.at ? new : cur
    }

    /// What the search does next.
    enum Next: Equatable { case wait, stop, fail }

    /// elapsed: seconds since the search started; reduced: iOS gives METRX only an approximate place, which does not get
    /// better, so its first live reading is the answer.
    static func next(best: GpsSample?, elapsed: Double, reduced: Bool = false) -> Next {
        if let b = best, !b.cached {
            if b.acc <= goodM || reduced { return .stop }
        }
        if elapsed >= maxS { return best == nil ? .fail : .stop }
        return .wait
    }
}
