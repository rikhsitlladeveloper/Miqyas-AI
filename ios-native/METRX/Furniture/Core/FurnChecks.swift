import Foundation

/*
 * The order's one "Check" list before the design is sent (bazis ideas, 23 Oct 2026; Android furniture/Checks.kt):
 * every piece's problems in one place, each tappable to open its piece. The board rules are here; what needs the room
 * (fit on the walls, doors that hit, the designers' own checks) comes in from the screen. Unit-tested (BazisTests).
 */

/// One problem of the order: piece fid; level err or warn; key its text with vars; mid the module, if one.
struct OrderIssue: Equatable, Hashable {
    let fid: String, level: String, key: String
    var vars: [String: AnyHashable] = [:]
    var mid: String? = nil
    init(_ fid: String, _ level: String, _ key: String, _ vars: [String: AnyHashable] = [:], _ mid: String? = nil) {
        self.fid = fid; self.level = level; self.key = key; self.vars = vars; self.mid = mid
    }
}

/// The longest shelf a board of t mm carries without bending, mm, when nothing holds it in the middle: 1000 for 16 mm
/// board (the wardrobe designer's own rule), 1100 for 18 mm and thicker.
func shelfSpanMax(_ t: Int) -> Int { t >= 18 ? 1100 : 1000 }

/// A shelf in a section iw mm wide inside (the shelf is 2 mm shorter) bends on board of t mm: the designer's and the Check list's one rule.
func shelfTooLong(_ iw: Int, _ t: Int) -> Bool { iw - 2 > shelfSpanMax(t) }

/// The board rules of one piece: a part bigger than the sheet, a drawer deeper than its box, a shelf too long to carry.
func boardIssues(_ f: Furniture, _ ws0: Workshop, _ mats: [Mat]) -> [OrderIssue] {
    let ws = wsOf(f, ws0)
    var out: [OrderIssue] = []
    // a part that fits no sheet of its material (the price counts a sheet of its own for it)
    let rows = cutList([f], ws)
    for l in layouts(rows, mats, ws) {
        var seen = Set<Int>()
        for i in l.unplaced where !seen.contains(i) {
            seen.insert(i)
            let r = rows[i]
            let sl = l.sheetL - 2 * ws.trim, sw = l.sheetW - 2 * ws.trim
            let vars: [String: AnyHashable] = ["p": r.p.key, "l": r.cutL, "w": r.cutW, "sl": sl, "sw": sw]
            out.append(OrderIssue(f.id, "err", "bz.ck.sheet", vars))
        }
    }
    let t = ws.t
    let span = shelfSpanMax(t)
    for m in f.modules {
        switch m.type {
        case "wardrobe":
            let dIn = innerD(m)
            for (i, s) in m.sections.enumerated() {
                if s.knee { continue }
                let iw = wardInner(m, m.sections, i, t)
                let rl = runnerLen(dIn)
                if s.inserts.contains(where: { $0.kind == "drawer" }) && rl > dIn - 10 {
                    out.append(OrderIssue(f.id, "err", "bz.ck.drawer", ["s": i + 1, "r": rl, "v": dIn], m.id))
                }
                if s.inserts.contains(where: { $0.kind == "shelf" }) && shelfTooLong(iw, t) {
                    out.append(OrderIssue(f.id, "warn", "bz.ck.shelf", ["s": i + 1, "v": iw - 2, "t": t, "max": span], m.id))
                }
            }
        case "base", "wall", "tall":
            let rl = runnerLen(m.d)
            if m.fronts.kind == "drawer" && rl > m.d - 10 {
                out.append(OrderIssue(f.id, "err", "bz.ck.drawer", ["s": 1, "r": rl, "v": m.d], m.id))
            }
            let sw = m.w - 2 * t - 2
            if m.inserts.contains(where: { $0.kind == "shelf" }) && sw > span {
                out.append(OrderIssue(f.id, "warn", "bz.ck.shelf", ["s": 1, "v": sw, "t": t, "max": span], m.id))
            }
        default: break
        }
    }
    return out
}

/// Every problem of the order's pieces fs, errors first: the board rules and what extra adds for a piece (its fit on
/// its walls, doors that hit, its designer's checks). A problem said twice is said once.
func orderChecks(_ fs: [Furniture], _ ws: Workshop, _ mats: [Mat], _ extra: (Furniture) -> [OrderIssue] = { _ in [] }) -> [OrderIssue] {
    var all: [OrderIssue] = []
    for f in fs where !f.modules.isEmpty {
        var seen = Set<OrderIssue>()
        for i in boardIssues(f, ws, mats) + extra(f) where !seen.contains(i) {
            seen.insert(i)
            all.append(i)
        }
    }
    // errors first, otherwise as found (a stable sort, as Kotlin's sortedBy)
    let errs = all.filter { $0.level == "err" }
    let rest = all.filter { $0.level != "err" }
    return errs + rest
}
