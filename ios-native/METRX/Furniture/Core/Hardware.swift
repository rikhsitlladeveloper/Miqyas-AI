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
    /// Takes key k out (Kotlin's remove): its count, nil when it had none.
    @discardableResult mutating func remove(_ k: String) -> Int? {
        guard let v = n.removeValue(forKey: k) else { return nil }
        keys.removeAll { $0 == k }
        return v
    }
    var pairs: [(String, Int)] { keys.map { ($0, n[$0]!) } }
}

/// Kinds counted in millimetres and bought by the metre.
let METRE_KINDS: Set<String> = ["rail", "slideTrack", "slideV", "slideH", "cornice", "led", "plinthK", "barRail", "gola", "ceilUnit"]
/// Kinds counted in square millimetres and bought by the m².
let AREA_KINDS: Set<String> = ["mirror", "glass", "glassShelf", "glassDoor", "frontShaker", "frontFluted", "fglass", "mirrorBronze", "mirrorGraphite",
                                "headSoft", "headTufted", "softPanel"]

/// How a kind is bought: "m", "m2" or "pcs" (the strings key fu.*).
func hwUnit(_ kind: String) -> String { METRE_KINDS.contains(kind) ? "m" : AREA_KINDS.contains(kind) ? "m2" : "pcs" }

/// A counted amount as people read it: millimetres as metres, square millimetres as m².
func hwAmount(_ kind: String, _ v: Int, _ en: Bool) -> String {
    let s: String
    if METRE_KINDS.contains(kind) { s = String(format: "%.2f m", Double(v) / 1000) }
    else if AREA_KINDS.contains(kind) { s = String(format: "%.2f m²", Double(v) / 1e6) }
    else { s = "\(v)" }
    return en ? s : s.replacingOccurrences(of: ".", with: ",")
}

/// m's hardware; edge: its piece opens by its edge (opensByEdge), a front without a handle takes no push latch.
func hardwareOf(_ m: Module, _ ws: Workshop, edge: Bool = false) -> Counts {
    var n = Counts()
    // soft close is a section's own choice (a kitchen unit's is the unit's)
    func hinge(_ sec: Int) -> String { (sec < 0 ? m.soft : softOf(m, sec)) ? "hingeSoft" : "hinge" }
    // a front without a handle opens by a push latch (HandleRules.swift), unless the piece opens by its edge
    func pull(_ key: String) { if hasHandle(m, key) { n.add("handle", 1) } else if !edge { n.add("push", 1) } }
    func fronts(_ f: Fronts, _ w: Int, _ h: Int, _ face: String = "", sec: Int = -1) {
        let fs = frontSizes(f, w, h, ws)
        func key(_ j: Int) -> String { sec < 0 ? "f\(j)" : "s\(sec):f\(j)" }
        switch f.kind {
        case "door":
            for (j, (fh, fw)) in fs.enumerated() {
                // a glass door in its frame has no handle: a push latch, as the 3D shows it
                n.add(hinge(sec), hingesFor(fh)); pull(key(j))
                // a vitrina's glass door in its frame, a mirror glued on a board door
                if face == "glass" { n.add("glassDoor", fh * fw) } else if face == "mirror" { n.add("mirror", (fh - 10) * (fw - 10)) }
            }
        case "drawer": n.add("runner", fs.count); for j in fs.indices { pull(key(j)) }
        default: break
        }
    }
    func inside(_ ins: [Insert], _ iw: Int) {
        for x in ins {
            switch x.kind {
            case "shelf": n.add("pin", 4 * x.qty)
            case "glass": n.add("pin", 4 * x.qty); n.add("glassShelf", (iw - 4) * (innerD(m) - 25) * x.qty)
            case "rail": n.add("rail", iw); n.add("railEnd", 2)
            case "drawer", "trouser", "shoe": n.add("runner", 1)
            case "lift": n.add("lift", 1)
            default: break
            }
        }
    }
    let t = ws.t
    if m.type == "filler" { return n }
    // a kitchen's space for a machine: a dishwasher's front (on the machine's own door) takes a handle or a push latch
    if m.type == "gap" { for fr in handleFronts(m) { pull(fr.key) }; return n }
    if ITEM_MODS.contains(m.type) { itemHardware(m, ws) { n.add($0, $1) }; return n }
    if m.type == "wardrobe" {
        let secs = m.sections.isEmpty ? [Section(m.w)] : m.sections
        for (i, s) in secs.enumerated() {
            if m.slide == nil { fronts(s.fronts, frontW(s), m.h - wardBase(m), s.face, sec: i) }
            inside(s.inserts, wardInner(m, secs, i, t))
            // a section's drawers (an open one's, or behind the doors) are pulled by a handle of their own, or pushed open
            for fr in handleFronts(m) where fr.sec == i && fr.key.contains(":d") { pull(fr.key) }
        }
        if let sl = m.slide {
            let n2 = min(4, max(2, sl.n))
            let (ow, _) = slideOpening(m, t), (dw, dh) = slideDoor(m, t), (pw, ph) = slidePanel(m, t)
            n.add("slideTrack", 2 * ow)            // the top and the bottom track
            n.add("slideV", 2 * dh * n2)           // two upright profiles a door
            n.add("slideH", 2 * dw * n2)           // the frame's top and bottom
            n.add("slideRoller", n2)               // one roller set a door
            for i in 0..<n2 where sl.panel(i) != "ldsp" { n.add(sl.panel(i), pw * ph) }
        }
        n.add("confirmat", 4 * (4 + 2 * (secs.count - 1)))
        if m.legs { n.add("leg", 2 * (secs.count + 1)) }
        // a hung cabinet (or one standing on another) is held by two hangers
        else if m.elev > 0 { n.add("hanger", 2) }
        if m.led { n.add("led", m.w - 2 * t); n.add("ledPsu", 1) }
    } else {
        fronts(m.fronts, m.w, m.h); inside(m.inserts, m.w - 2 * t)
        n.add("confirmat", m.type == "base" ? 24 : 16)
        if m.type == "wall" { n.add("hanger", 2) }
        if m.type != "wall" && m.legs { n.add("leg", m.w > 900 ? 6 : 4) }
    }
    return n
}

/// An order's hardware, all modules added up; a piece's design changes and adds to it (PieceLook.swift).
func hardware(_ fs: [Furniture], _ ws: Workshop) -> Counts {
    var n = Counts()
    for f in fs {
        let fws = wsOf(f, ws)
        let edge = opensByEdge(f)
        for m in f.modules {
            var h = hardwareOf(m, fws, edge: edge)
            lookSwap(f, m, &h, edge)
            for (k, v) in h.pairs { n.add(k, v) }
        }
        for (k, v) in extrasHardware(f).pairs { n.add(k, v) }
        for (k, v) in lookHardware(f, ws).pairs { n.add(k, v) }
    }
    return n
}
