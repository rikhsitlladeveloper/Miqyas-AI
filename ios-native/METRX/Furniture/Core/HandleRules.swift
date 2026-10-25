import Foundation

/*
 * Handles per door and per drawer, soft close per section (founder's decisions, 25 Oct 2026; Android
 * furniture/Handles.kt). Module.handles is the piece's master switch ("Tutqichsiz" in Change for all turns it off); with
 * it on, the fronts left without a handle are kept where they stay put when the box changes: a kitchen unit's or a
 * bed's in Module.noHandle, a section's doors in Section.noHandle, an open section's drawers on the drawer itself
 * (Insert.push). A front without a handle opens by a push latch, counted in the hardware; a glass door in its aluminium
 * frame never has a handle. An older order (none of these set) looks as it did: its box-wide switch is every front's
 * value. Unit-tested (HandlesTests).
 *
 * Front keys, as the 3D names them within the box: "f0".. the box's own doors or drawers (a kitchen unit, top down for
 * drawers; a dishwasher's front), "bd0".. a bed's drawers, "s0:f0".. a section's doors, "s0:d120" an open section's
 * drawer at 120 mm.
 */

/// A front that takes a handle or a push latch: its key; its section (-1: the box's own); a drawer; a glass door.
struct HFront: Equatable, Hashable {
    let key: String
    let sec: Int
    let drawer: Bool
    let glass: Bool
    init(_ key: String, _ sec: Int, _ drawer: Bool, _ glass: Bool = false) { self.key = key; self.sec = sec; self.drawer = drawer; self.glass = glass }
}

/// The fronts of m that take a handle or a push latch, as the pictures draw them (left to right, drawers top down).
func handleFronts(_ m: Module) -> [HFront] {
    if m.type == "filler" { return [] }
    if m.type == "gap" { return m.app == "dishwasher" && m.fronts.kind != "open" ? [HFront("f0", -1, false)] : [] }
    if m.type == "bed" { return bedDrawers(m, Workshop()).indices.map { HFront("bd\($0)", -1, true) } }
    if ITEM_MODS.contains(m.type) { return [] }
    if m.type == "wardrobe" {
        var out: [HFront] = []
        for (i, s) in m.sections.enumerated() {
            if s.knee { continue }
            if s.fronts.kind == "open" {
                // top down; drawers at the same height in the section's order
                let ds = s.inserts.enumerated().filter { $0.element.kind == "drawer" }
                    .sorted { $0.element.pos != $1.element.pos ? $0.element.pos > $1.element.pos : $0.offset < $1.offset }
                for d in ds { out.append(HFront("s\(i):d\(d.element.pos)", i, true)) }
            } else if m.slide != nil {
                continue
            } else if s.fronts.kind == "door" || s.fronts.kind == "drawer" {
                for j in 0..<max(0, s.fronts.n) {
                    out.append(HFront("s\(i):f\(j)", i, s.fronts.kind == "drawer", s.fronts.kind == "door" && s.face == "glass"))
                }
            }
        }
        return out
    }
    if m.fronts.kind == "door" || m.fronts.kind == "drawer" {
        let drawer = m.fronts.kind == "drawer"
        return (0..<max(0, m.fronts.n)).map { HFront("f\($0)", -1, drawer) }
    }
    return []
}

/// A section's front key split: the section and the rest ("f1", "d120"); nil for the box's own fronts.
private func hSecOf(_ key: String) -> (Int, String)? {
    guard key.hasPrefix("s"), let c = key.firstIndex(of: ":") else { return nil }
    guard let i = Int(key[key.index(after: key.startIndex)..<c]) else { return nil }
    return (i, String(key[key.index(after: c)...]))
}

/// Whether front key of m has a handle (else a push latch opens it).
func hasHandle(_ m: Module, _ key: String) -> Bool {
    if !m.handles { return false }
    guard let sk = hSecOf(key) else { return !m.noHandle.contains(key) }
    let (i, k) = sk
    guard i >= 0 && i < m.sections.count else { return false }
    let s = m.sections[i]
    if k.hasPrefix("d") {
        let pos = Int(k.dropFirst())
        return s.inserts.first(where: { $0.kind == "drawer" && $0.pos == pos })?.push != true
    }
    guard let j = Int(k.dropFirst()) else { return false }
    return !(s.fronts.kind == "door" && s.face == "glass") && !s.noHandle.contains(j)
}

/// Whether door j of section i has a handle.
func doorHandle(_ m: Module, _ i: Int, _ j: Int) -> Bool { hasHandle(m, "s\(i):f\(j)") }

/// Whether drawer x of an open section has a handle.
func drawerHandle(_ m: Module, _ x: Insert) -> Bool { m.handles && !x.push }

/// m with no exception left: every front with a handle (on) or none (the master off).
func allHandles(_ m: Module, _ on: Bool) -> Module {
    var n = m
    n.handles = on
    n.noHandle = []
    n.sections = m.sections.map { s in
        if s.noHandle.isEmpty && !s.inserts.contains(where: { $0.push }) { return s }
        var t = s
        t.noHandle = []
        t.inserts = s.inserts.map { x in var y = x; y.push = false; return y }
        return t
    }
    return n
}

/// The master on with every front listed as without a handle: as m with the master off looks.
private func hMasterOn(_ m: Module) -> Module {
    if m.handles { return m }
    var n = m
    n.handles = true
    n.noHandle = handleFronts(m).filter { $0.sec < 0 }.map(\.key)
    n.sections = m.sections.map { s in
        var t = s
        switch s.fronts.kind {
        case "open": t.inserts = s.inserts.map { x in var y = x; if x.kind == "drawer" { y.push = true }; return y }
        case "door", "drawer": t.noHandle = Array(0..<max(0, s.fronts.n))
        default: break
        }
        return t
    }
    return n
}

/// m with front key given a handle (on) or a push latch; the other fronts stay as they look.
func withHandle(_ m: Module, _ key: String, _ on: Bool) -> Module {
    if hasHandle(m, key) == on { return m }
    var x = hMasterOn(m)
    guard let sk = hSecOf(key) else {
        if on { x.noHandle = x.noHandle.filter { $0 != key } }
        else if !x.noHandle.contains(key) { x.noHandle.append(key) }
        return x
    }
    let (i, k) = sk
    guard i >= 0 && i < x.sections.count else { return x }
    var s = x.sections[i]
    if k.hasPrefix("d") {
        let pos = Int(k.dropFirst())
        if let at = s.inserts.firstIndex(where: { $0.kind == "drawer" && $0.pos == pos }) { s.inserts[at].push = !on }
    } else {
        guard let j = Int(k.dropFirst()) else { return x }
        s.noHandle = on ? s.noHandle.filter { $0 != j } : Array(Set(s.noHandle + [j])).sorted()
    }
    x.sections[i] = s
    return x
}

/// m with front key's handle the other way.
func toggleHandle(_ m: Module, _ key: String) -> Module { withHandle(m, key, !hasHandle(m, key)) }

/// How many of m's fronts have a handle, and how many open by a push latch.
func handleSplit(_ m: Module) -> (on: Int, off: Int) {
    let fr = handleFronts(m)
    let a = fr.filter { hasHandle(m, $0.key) }.count
    return (a, fr.count - a)
}

/// A section's doors with their stale choices dropped: after a change of its fronts the door numbers mean other doors.
func frontsChanged(_ old: Section, _ new: Section) -> Section {
    if old.fronts == new.fronts || new.noHandle.isEmpty { return new }
    var n = new
    n.noHandle = old.fronts.kind == new.fronts.kind ? new.noHandle.filter { $0 < new.fronts.n } : []
    return n
}

/// A kitchen unit (or another box's own fronts) with its stale choices dropped after its fronts changed.
func frontsChanged(_ old: Module, _ new: Module) -> Module {
    if old.fronts == new.fronts || new.noHandle.isEmpty { return new }
    var n = new
    if old.fronts.kind == new.fronts.kind {
        n.noHandle = new.noHandle.filter { k in !k.hasPrefix("f") || (Int(k.dropFirst()) ?? 0) < new.fronts.n }
    } else {
        n.noHandle = new.noHandle.filter { !$0.hasPrefix("f") }
    }
    return n
}

/* ---------------- soft close ---------------- */

/// Whether section i's doors close softly: its own choice, else the box's.
func softOf(_ m: Module, _ i: Int) -> Bool {
    guard i >= 0 && i < m.sections.count else { return m.soft }
    return m.sections[i].soft ?? m.soft
}

/// m with section i's soft close set to on (back to following the box when that is the box's).
func withSoft(_ m: Module, _ i: Int, _ on: Bool) -> Module {
    guard i >= 0 && i < m.sections.count else { return m }
    var n = m
    n.sections[i].soft = on == m.soft ? nil : on
    return n
}

/// m with every section closing as on: the box's value, no section of its own.
func softAll(_ m: Module, _ on: Bool) -> Module {
    var n = m
    n.soft = on
    n.sections = m.sections.map { s in var t = s; t.soft = nil; return t }
    return n
}

/* ---------------- a piece built again ---------------- */

/// A front's place that survives a rebuild (an open section's drawers by their order from the top, the rest by key),
/// and its key.
private func hOrdKeys(_ m: Module) -> [(String, String)] {
    let fr = handleFronts(m)
    return fr.map { f -> (String, String) in
        guard f.drawer && f.key.contains(":d") else { return (f.key, f.key) }
        let same = fr.filter { $0.sec == f.sec && $0.key.contains(":d") }
        return ("s\(f.sec):d#\(same.firstIndex(of: f) ?? -1)", f.key)
    }
}

/// A piece of several boxes built again (n) from f: no handles at all stays so; otherwise each box (in order) keeps
/// its fronts without a handle where they still are, and its soft close.
func keepFrontChoices(_ f: Furniture, _ n: Furniture) -> Furniture {
    let olds = f.modules.filter { takesHandles($0) }
    let bare = handleBare(f)
    var k = 0
    var r = n
    r.modules = n.modules.map { m2 -> Module in
        if !takesHandles(m2) { return m2 }
        if bare { return allHandles(m2, false) }
        let at = k
        k += 1
        guard at < olds.count else { return m2 }
        let m1 = olds[at]
        var out = softAll(m2, m1.soft)
        for i in out.sections.indices { out.sections[i].soft = i < m1.sections.count ? m1.sections[i].soft : nil }
        var newKeys: [String: String] = [:]
        for (o, key) in hOrdKeys(out) { newKeys[o] = key }
        let off = hOrdKeys(m1).filter { !hasHandle(m1, $0.1) }.compactMap { newKeys[$0.0] }
        if !m1.handles && off.count == handleFronts(m1).count { out = allHandles(out, false) }
        else { for key in off { out = withHandle(out, key, false) } }
        return out
    }
    return r
}

/// A piece that has fronts but not one handle (the whole of it "Tutqichsiz"; Android isBare).
func handleBare(_ f: Furniture) -> Bool {
    f.modules.contains { takesHandles($0) && !handleFronts($0).isEmpty } && !hasHandles(f)
}
