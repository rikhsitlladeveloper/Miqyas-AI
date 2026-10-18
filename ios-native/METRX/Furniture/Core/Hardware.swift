import Foundation

/*
 * Hardware counting (furniture plan section 6.6; Android furniture/Hardware.kt). Keys are Hw.kinds; "rail" is counted
 * in millimetres of rail. Every rule is a default for the founder's furniture makers to check.
 */

/// Counts by key in the order the keys first come (Swift's dictionaries have no order of their own).
struct Counts: Equatable {
    private(set) var keys: [String] = []
    private(set) var n: [String: Int] = [:]
    subscript(_ k: String) -> Int? { n[k] }
    mutating func add(_ k: String, _ v: Int) { if v <= 0 { return }; if n[k] == nil { keys.append(k) }; n[k, default: 0] += v }
    var pairs: [(String, Int)] { keys.map { ($0, n[$0]!) } }
}

func hardwareOf(_ m: Module, _ ws: Workshop) -> Counts {
    var n = Counts()
    let hinge = m.soft ? "hingeSoft" : "hinge"
    func fronts(_ f: Fronts, _ w: Int, _ h: Int) {
        let fs = frontSizes(f, w, h, ws)
        switch f.kind {
        case "door": for (fh, _) in fs { n.add(hinge, hingesFor(fh)); if m.handles { n.add("handle", 1) } }
        case "drawer": n.add("runner", fs.count); if m.handles { n.add("handle", fs.count) }
        default: break
        }
    }
    func inside(_ ins: [Insert], _ iw: Int) {
        for x in ins {
            switch x.kind {
            case "shelf": n.add("pin", 4 * x.qty)
            case "rail": n.add("rail", iw); n.add("railEnd", 2)
            case "drawer", "trouser", "shoe": n.add("runner", 1)
            case "lift": n.add("lift", 1)
            default: break
            }
        }
    }
    let t = ws.t
    if m.type == "gap" || m.type == "filler" { return n }
    if m.type == "wardrobe" {
        let secs = m.sections.isEmpty ? [Section(m.w)] : m.sections
        for (i, s) in secs.enumerated() { fronts(s.fronts, s.w, m.h - wardBase(m)); inside(s.inserts, wardInner(m, secs, i, t)) }
        n.add("confirmat", 4 * (4 + 2 * (secs.count - 1)))
        if m.legs { n.add("leg", 2 * (secs.count + 1)) }
    } else {
        fronts(m.fronts, m.w, m.h); inside(m.inserts, m.w - 2 * t)
        n.add("confirmat", m.type == "base" ? 24 : 16)
        if m.type == "wall" { n.add("hanger", 2) }
        if m.type != "wall" && m.legs { n.add("leg", m.w > 900 ? 6 : 4) }
    }
    return n
}

/// An order's hardware, all modules added up.
func hardware(_ fs: [Furniture], _ ws: Workshop) -> Counts {
    var n = Counts()
    for f in fs { for m in f.modules { for (k, v) in hardwareOf(m, ws).pairs { n.add(k, v) } } }
    return n
}
