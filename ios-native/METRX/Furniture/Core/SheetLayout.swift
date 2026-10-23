import Foundation

/*
 * The sheet layout, раскрой (furniture plan section 6.5; Android furniture/SheetLayout.kt): parts on full sheets with
 * straight saw cuts edge to edge, as a panel saw does. Shelf packing, biggest first: each sheet is cut into strips
 * across its length, each strip into parts. Saw cut and edge trim are kept; parts with grain keep their length along
 * the sheet's length. Not optimal, but correct: nothing overlaps and every cut can be made.
 */

/// A part on a sheet: row its cut list line, x, y from the trimmed corner, w along the sheet's length, h across.
struct Placed: Equatable { let row: Int, x: Int, y: Int, w: Int, h: Int, turned: Bool }

/// An offcut left on a board that a saw can cut off whole: l along the sheet's length × w across, mm.
struct BoardRest: Equatable { let l: Int, w: Int; init(_ l: Int, _ w: Int) { self.l = l; self.w = w } }

/// One board the parts went on: a new sheet, or rem a remnant from the workshop's store (bazis ideas, 23 Oct 2026);
/// rest the offcuts left on it that a saw can cut off whole.
struct SheetPlan: Equatable {
    let placed: [Placed]
    var rem: Remnant? = nil
    var rest: [BoardRest] = []
}

/// One material's boards: the new sheets, what could not fit on any sheet, the waste; rems the remnants used before
/// any new sheet (only the new sheets are bought).
struct MatLayout: Equatable {
    let mat: String, sheetL: Int, sheetW: Int
    let sheets: [SheetPlan]
    let unplaced: [Int]
    var rems: [SheetPlan] = []
    var used: Int { sheets.reduce(0) { a, s in a + s.placed.reduce(0) { $0 + $1.w * $1.h } } }
    /// The share of the bought sheets that is not parts, 0 to 1.
    var waste: Double { sheets.isEmpty ? 0 : 1 - Double(used) / (Double(sheets.count) * Double(sheetL) * Double(sheetW)) }
}

private final class Strip { let y: Int, h: Int; var x = 0; init(_ y: Int, _ h: Int) { self.y = y; self.h = h } }
/// A board being filled: uL × uW usable (a sheet less its trimmed edges, a remnant whole).
private final class Stock {
    let uL: Int, uW: Int, rem: Remnant?
    var strips: [Strip] = []; var placed: [Placed] = []; var yNext = 0
    init(_ uL: Int, _ uW: Int, _ rem: Remnant? = nil) { self.uL = uL; self.uW = uW; self.rem = rem }
}

/// Lays out the cut list rows that use material mat (sheet sheetL × sheetW). Each of a line's pieces is placed on its
/// own; grain lines may not turn. The remnants rems of this material are filled first, the smallest first (their
/// length runs along the grain like a sheet's); then new sheets.
func layout(_ rows: [CutRow], _ mat: String, _ sheetL: Int, _ sheetW: Int, _ kerf: Int, _ trim: Int, _ rems: [Remnant] = []) -> MatLayout {
    let uL = sheetL - 2 * trim, uW = sheetW - 2 * trim
    struct Piece { let row: Int, a: Int, b: Int, grain: Bool }   // a: along the grain / length
    var pieces: [Piece] = []
    for (i, r) in rows.enumerated() where r.mat == mat { for _ in 0..<r.p.qty { pieces.append(Piece(row: i, a: r.cutL, b: r.cutW, grain: r.p.grain)) } }
    // the tallest strip height each piece would need, biggest first (a stable sort, as Kotlin's)
    func up(_ p: Piece) -> Int { p.grain ? p.b : min(p.a, p.b) }
    let order = pieces.enumerated().sorted { x, y in
        let a = x.element, b = y.element
        if up(a) != up(b) { return up(a) > up(b) }
        if max(a.a, a.b) != max(b.a, b.b) { return max(a.a, a.b) > max(b.a, b.b) }
        return x.offset < y.offset
    }.map(\.element)
    // the remnants of this material, the smallest first (a stable sort, as Kotlin's sortedBy)
    let mine = rems.filter { $0.mat == mat && $0.L > 0 && $0.W > 0 }
    let remBoards: [Stock] = mine.enumerated().sorted { x, y in
        let ax = x.element.L * x.element.W, ay = y.element.L * y.element.W
        if ax != ay { return ax < ay }
        return x.offset < y.offset
    }.map { Stock($0.element.L, $0.element.W, $0.element) }
    var sheets: [Stock] = [], unplaced: [Int] = []
    func orient(_ p: Piece, _ l: Int, _ w: Int) -> [(Int, Int)] {
        var o: [(Int, Int)] = []
        if p.a <= l && p.b <= w { o.append((p.a, p.b)) }
        if !p.grain && p.b <= l && p.a <= w && p.a != p.b { o.append((p.b, p.a)) }
        return o
    }
    // the first of the lowest, as Kotlin's minByOrNull
    func lowest<T>(_ xs: [T], _ f: (T) -> Int) -> T? { var best: T? = nil, bv = 0; for x in xs { let v = f(x); if best == nil || v < bv { best = x; bv = v } }; return best }
    for p in order {
        if orient(p, uL, uW).isEmpty { unplaced.append(p.row); continue }
        var done = false
        // an existing strip it fits in, the lowest waste of height first; remnants before the sheets
        for s in remBoards + sheets {
            let os = orient(p, s.uL, s.uW)
            if os.isEmpty { continue }
            let sl = s.uL
            let fits = s.strips.flatMap { st in os.filter { $0.1 <= st.h && st.x + $0.0 <= sl }.map { (st, $0) } }
            if let (st, o) = lowest(fits, { $0.0.h - $0.1.1 }) {
                s.placed.append(Placed(row: p.row, x: st.x, y: st.y, w: o.0, h: o.1, turned: o.0 != p.a))
                st.x += o.0 + kerf; done = true; break
            }
            // a new strip on this board: the orientation with the lower height
            let o = lowest(os, { $0.1 })!
            if s.yNext + o.1 <= s.uW {
                let st = Strip(s.yNext, o.1); s.strips.append(st); s.yNext += o.1 + kerf
                s.placed.append(Placed(row: p.row, x: 0, y: st.y, w: o.0, h: o.1, turned: o.0 != p.a))
                st.x = o.0 + kerf; done = true; break
            }
        }
        if !done {
            let s = Stock(uL, uW); sheets.append(s)
            let o = lowest(orient(p, uL, uW), { $0.1 })!
            let st = Strip(0, o.1); s.strips.append(st); s.yNext = o.1 + kerf
            s.placed.append(Placed(row: p.row, x: 0, y: 0, w: o.0, h: o.1, turned: o.0 != p.a)); st.x = o.0 + kerf
        }
    }
    // what is left on a board, as a panel saw cuts it: the end of each strip, and the whole width under the last strip
    func rest(_ b: Stock) -> [BoardRest] {
        var all: [BoardRest] = b.strips.map { BoardRest(max(0, b.uL - $0.x), $0.h) }
        all.append(BoardRest(b.uL, max(0, b.uW - b.yNext)))
        let kept = all.filter { $0.l > 0 && $0.w > 0 }
        // biggest first, a stable sort as Kotlin's sortedByDescending
        return kept.enumerated().sorted { x, y in
            let ax = x.element.l * x.element.w, ay = y.element.l * y.element.w
            if ax != ay { return ax > ay }
            return x.offset < y.offset
        }.map(\.element)
    }
    func plan(_ b: Stock) -> SheetPlan { SheetPlan(placed: b.placed, rem: b.rem, rest: rest(b)) }
    return MatLayout(mat: mat, sheetL: sheetL, sheetW: sheetW, sheets: sheets.map(plan), unplaced: unplaced,
                     rems: remBoards.filter { !$0.placed.isEmpty }.map(plan))
}

/// Layouts for every material of the cut list that comes in sheets (banding is bought by the metre); the store's rems first.
func layouts(_ rows: [CutRow], _ mats: [Mat], _ ws: Workshop, _ rems: [Remnant] = []) -> [MatLayout] {
    var ids: [String] = []
    for r in rows where !ids.contains(r.mat) { ids.append(r.mat) }
    return ids.map { id in
        let m = mats.first { $0.id == id }
        return layout(rows, id, (m?.l ?? 0) > 0 ? m!.l : ws.sheetL, (m?.w ?? 0) > 0 ? m!.w : ws.sheetW, ws.kerf, ws.trim, rems)
    }
}
