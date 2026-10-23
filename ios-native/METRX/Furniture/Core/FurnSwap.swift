import Foundation

/*
 * "Change for all" (bazis ideas, 23 Oct 2026; Android furniture/Swap.kt): the fronts' board or the handles of every
 * piece of an order in one tap; the screen keeps the pieces as they were for Undo. Unit-tested (BazisTests).
 */

/// No handles at all: the fronts open by a push latch.
let NO_HANDLES = "none"

/// Every piece of fs with front as its fronts' board (nil: as it was) and handle as its handles (a hardware id;
/// NO_HANDLES none; nil: as they were). Room-less pieces and pieces in rooms alike; empty ones stay as they are.
func swapAll(_ fs: [Furniture], front: String? = nil, handle: String? = nil) -> [Furniture] {
    fs.map { f in
        var g = f
        if let front { g.mats.front = front }
        if let handle {
            let on = handle != NO_HANDLES
            if on { g.handle = handle }
            g.modules = g.modules.map { m in
                if m.type == "gap" && m.app != "dishwasher" { return m }
                var x = m; x.handles = on
                return x
            }
        }
        return g
    }
}

/// The fronts' board all of fs share, or nil when they differ (or there are none).
func commonFront(_ fs: [Furniture]) -> String? {
    let all = Set(fs.map { $0.mats.front })
    return all.count == 1 ? all.first : nil
}

/// The handles all of fs share: a hardware id, "" the usual one, NO_HANDLES; nil when they differ.
func commonHandle(_ fs: [Furniture]) -> String? {
    let built = fs.filter { f in f.modules.contains { $0.type != "gap" } }
    let all = Set(built.map { f in f.modules.contains { $0.handles } ? f.handle : NO_HANDLES })
    return all.count == 1 ? all.first : nil
}
