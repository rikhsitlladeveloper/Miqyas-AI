import Foundation

/// GSAP's eases, so the timeline reads the same as the artifact (power1 = quad, power2 = cubic, power3 = quart).
enum Ease {
    typealias F = (Double) -> Double
    static let none: F = { $0 }
    static let p1In: F = { $0 * $0 }
    static let p1Out: F = { 1 - (1 - $0) * (1 - $0) }
    static let p1InOut: F = { $0 < 0.5 ? 2 * $0 * $0 : 1 - pow(-2 * $0 + 2, 2) / 2 }
    static let p2In: F = { $0 * $0 * $0 }
    static let p2Out: F = { 1 - pow(1 - $0, 3) }
    static let p3In: F = { pow($0, 4) }
    static let p3Out: F = { 1 - pow(1 - $0, 4) }
    static let p3InOut: F = { $0 < 0.5 ? 8 * pow($0, 4) : 1 - pow(-2 * $0 + 2, 4) / 2 }
    static let sineInOut: F = { -(cos(Double.pi * $0) - 1) / 2 }
    static let expoOut: F = { $0 >= 1 ? 1 : 1 - pow(2, -10 * $0) }
    static let expoInOut: F = { x in
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        return x < 0.5 ? pow(2, 20 * x - 10) / 2 : (2 - pow(2, -20 * x + 10)) / 2
    }
    static func backOut(_ s: Double) -> F { { x in let y = x - 1; return 1 + (s + 1) * y * y * y + s * y * y } }
}

/// One animated number: a starting value and tweens that each run from wherever the value is when they start
/// (GSAP's to()), or from an explicit value (fromTo()). A zero-length tween is a set().
final class Track {
    private struct Seg { let start: Double; let dur: Double; let from: Double?; let to: Double; let ease: Ease.F }
    private let initial: Double
    private var segs: [Seg] = []
    private var froms: [Double]? = nil

    init(_ v: Double) { initial = v }

    @discardableResult func to(_ start: Double, _ dur: Double, _ to: Double, _ ease: @escaping Ease.F = Ease.p3Out) -> Track {
        segs.append(Seg(start: start, dur: dur, from: nil, to: to, ease: ease)); froms = nil; return self
    }
    @discardableResult func fromTo(_ start: Double, _ dur: Double, _ from: Double, _ to: Double, _ ease: @escaping Ease.F = Ease.p3Out) -> Track {
        segs.append(Seg(start: start, dur: dur, from: from, to: to, ease: ease)); froms = nil; return self
    }
    @discardableResult func set(_ at: Double, _ v: Double) -> Track {
        segs.append(Seg(start: at, dur: 0, from: nil, to: v, ease: Ease.none)); froms = nil; return self
    }

    private func prepare() -> [Double] {
        if let f = froms { return f }
        // stable sort by start, like Kotlin's sortBy
        segs = segs.enumerated().sorted { $0.element.start != $1.element.start ? $0.element.start < $1.element.start : $0.offset < $1.offset }.map(\.element)
        var f = [Double](repeating: 0, count: segs.count)
        for i in segs.indices { f[i] = segs[i].from ?? eval(segs[i].start, i, f) }
        froms = f
        return f
    }

    private func eval(_ t: Double, _ upto: Int, _ f: [Double]) -> Double {
        var v = initial
        for i in 0..<upto {
            let s = segs[i]
            if t < s.start { break }
            let p = s.dur <= 0 ? 1 : min(1, max(0, (t - s.start) / s.dur))
            v = f[i] + (s.to - f[i]) * s.ease(p)
        }
        return v
    }

    func callAsFunction(_ t: Double) -> Double { let f = prepare(); return eval(t, segs.count, f) }
}
