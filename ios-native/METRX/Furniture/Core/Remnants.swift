import Foundation

/*
 * Remnants (bazis ideas, 23 Oct 2026; Advanced only; Android furniture/Remnants.kt): the offcuts a cut list leaves,
 * kept in the workshop's store with their material and grain, and used before new sheets by the next order's cut list.
 * Only new sheets are bought, so the cost counts only them.
 *
 * An order "takes" the remnants its layout used when the maker says it was cut (cutDone); its own offcuts go into the
 * store then. Until another order takes them they are free; an order already cut keeps exactly what it took, also once
 * that order is deleted (the board was cut: it is gone from the store).
 */

/// A leftover piece of board: material mat, L along the grain (the sheet's length) × W across, mm; grain the material
/// has a grain; src the order it was cut from, used the order that took it ("" free), at when it was kept.
struct Remnant: Codable, Equatable, Identifiable {
    var id: String, mat: String, L: Int, W: Int
    var grain = false
    var src = ""
    var used = ""
    var at: Ms = 0
    init(_ id: String, _ mat: String, _ L: Int, _ W: Int, grain: Bool = false, src: String = "", used: String = "", at: Ms = 0) {
        self.id = id; self.mat = mat; self.L = L; self.W = W; self.grain = grain; self.src = src; self.used = used; self.at = at
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); mat = c.v(.mat, ""); L = c.v(.L, 0); W = c.v(.W, 0)
        grain = c.v(.grain, false); src = c.v(.src, ""); used = c.v(.used, ""); at = c.v(.at, 0)
    }
}

/// The smallest remnant the workshop keeps by default, each way, mm.
let REM_MIN = 300

/// The remnants order `order`'s cut list may use: once it was cut, the ones it took; before, the ones it holds and the
/// free ones from other orders. One taken by another order stays taken, even when that order was deleted.
func remnantsFor(_ all: [Remnant], _ order: String, _ cut: Bool) -> [Remnant] {
    if cut { return all.filter { $0.used == order } }
    return all.filter { r in r.used == order || (r.src != order && r.used.isEmpty) }
}

/// Whether a remnant can be thrown away from the store: only a free one (a taken one was cut by its order).
func removable(_ r: Remnant) -> Bool { r.used.isEmpty }

/// Whether order `order`'s cut can be undone: not once another order took one of its offcuts.
func canUndoCut(_ all: [Remnant], _ order: String) -> Bool { !all.contains { $0.src == order && !$0.used.isEmpty && $0.used != order } }

/// The offcuts of lays at least min mm each way, as remnants cut for order.
func offcuts(_ lays: [MatLayout], _ mats: [Mat], _ min: Int, _ order: String, _ now: Ms, _ id: () -> String) -> [Remnant] {
    var out: [Remnant] = []
    for l in lays {
        let grain = mats.first { $0.id == l.mat }?.grain ?? false
        for b in l.sheets + l.rems {
            for r in b.rest where r.l >= min && r.w >= min {
                out.append(Remnant(id(), l.mat, r.l, r.w, grain: grain, src: order, used: "", at: now))
            }
        }
    }
    return out
}

/// The store once order `order` was cut by lays: the remnants it used are its (taken), its offcuts of min mm and more
/// are added. Done again it first undoes the last time, so nothing is kept twice: an offcut of this order another order
/// already took is not added again.
func cutDone(_ all: [Remnant], _ lays: [MatLayout], _ mats: [Mat], _ order: String, _ min: Int, _ now: Ms, _ id: () -> String) -> [Remnant] {
    let base = cutUndone(all, order)
    var took = Set<String>()
    for l in lays { for b in l.rems { if let r = b.rem { took.insert(r.id) } } }
    let marked: [Remnant] = base.map { r in
        if !took.contains(r.id) { return r }
        var g = r; g.used = order
        return g
    }
    var had = base.filter { $0.src == order }
    let fresh = offcuts(lays, mats, min, order, now, id).filter { o in
        guard let i = had.firstIndex(where: { $0.mat == o.mat && $0.L == o.L && $0.W == o.W }) else { return true }
        had.remove(at: i)
        return false
    }
    return marked + fresh
}

/// The store as if order `order` had not been cut: its offcuts that nobody took go, the remnants it took are free again.
func cutUndone(_ all: [Remnant], _ order: String) -> [Remnant] {
    let kept = all.filter { !($0.src == order && $0.used.isEmpty) }
    return kept.map { r in
        if r.used != order { return r }
        var g = r; g.used = ""
        return g
    }
}
