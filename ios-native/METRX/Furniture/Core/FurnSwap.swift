import Foundation

/*
 * "Change for all" (bazis ideas, 23 Oct 2026; Android furniture/Swap.kt): the fronts' board or the handles of every
 * piece of an order in one tap; the screen keeps the pieces as they were for Undo. Unit-tested (BazisTests).
 */

/// No handles at all: the fronts open by a push latch.
let NO_HANDLES = "none"

/// Every piece of fs with front as its fronts' board (nil: as it was) and handle as its handles (a hardware id;
/// NO_HANDLES none; nil: as they were). Room-less pieces and pieces in rooms alike; empty ones stay as they are.
/// A handle's type keeps the doors and drawers chosen without one (HandleRules.swift); on a piece with no handle at
/// all ("Tutqichsiz" before) it puts one back on every front. A piece that opens by its edge (opensByEdge: the mirror
/// cabinet) gets none put on: a handle it was given one by one takes the new type.
func swapAll(_ fs: [Furniture], front: String? = nil, handle: String? = nil) -> [Furniture] {
    fs.map { f in
        var g = f
        if let front { g.mats.front = front }
        if let handle {
            if handle == NO_HANDLES {
                g.modules = g.modules.map { takesHandles($0) ? allHandles($0, false) : $0 }
            } else if opensByEdge(g) {
                if hasHandles(g) { g.handle = handle }
            } else {
                let bare = handleBare(g)
                g.handle = handle
                if bare { g.modules = g.modules.map { takesHandles($0) ? allHandles($0, true) : $0 } }
            }
        }
        return g
    }
}

/// A unit that can have handles: not a kitchen's space for a fridge or a cooker (a dishwasher's gap has its front).
func takesHandles(_ m: Module) -> Bool { !(m.type == "gap" && m.app != "dishwasher") }

/// Whether a piece shows a handle on any door or drawer (its spaces for a fridge or cooker do not count).
func hasHandles(_ f: Furniture) -> Bool {
    f.modules.contains { m in takesHandles(m) && m.handles && handleFronts(m).contains { hasHandle(m, $0.key) } }
}

/// The fronts' board all of fs share, or nil when they differ (or there are none).
func commonFront(_ fs: [Furniture]) -> String? {
    let all = Set(fs.map { $0.mats.front })
    return all.count == 1 ? all.first : nil
}

/// The handles all of fs share: a hardware id, "" the usual one, NO_HANDLES; nil when they differ. A piece that opens
/// by its edge (opensByEdge) is left out: it has none whatever the others have.
func commonHandle(_ fs: [Furniture]) -> String? {
    let built = fs.filter { f in !opensByEdge(f) && f.modules.contains { takesHandles($0) && !handleFronts($0).isEmpty } }
    let all = Set(built.map { f in hasHandles(f) ? f.handle : NO_HANDLES })
    return all.count == 1 ? all.first : nil
}
