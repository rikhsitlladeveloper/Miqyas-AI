import Foundation

/*
 * The sheet layout, раскрой (furniture plan section 6.5; Android furniture/SheetLayout.kt): parts on full sheets with
 * straight saw cuts edge to edge, as a panel saw does. Shelf packing, biggest first: each sheet is cut into strips
 * across its length, each strip into parts. Saw cut and edge trim are kept; parts with grain keep their length along
 * the sheet's length. Not optimal, but correct: nothing overlaps and every cut can be made.
 */

/// A part on a sheet: row its cut list line, x, y from the trimmed corner, w along the sheet's length, h across.
struct Placed: Equatable { let row: Int, x: Int, y: Int, w: Int, h: Int, turned: Bool }

struct SheetPlan: Equatable { let placed: [Placed] }

/// One material's sheets: what went where, what could not fit on any sheet, and the waste.
struct MatLayout: Equatable {
    let mat: String, sheetL: Int, sheetW: Int
    let sheets: [SheetPlan]
    let unplaced: [Int]
    var used: Int { sheets.reduce(0) { a, s in a + s.placed.reduce(0) { $0 + $1.w * $1.h } } }
    /// The share of the bought sheets that is not parts, 0 to 1.
    var waste: Double { sheets.isEmpty ? 0 : 1 - Double(used) / (Double(sheets.count) * Double(sheetL) * Double(sheetW)) }
}

private final class Strip { let y: Int, h: Int; var x = 0; init(_ y: Int, _ h: Int) { self.y = y; self.h = h } }
private final class PSheet { var strips: [Strip] = []; var placed: [Placed] = []; var yNext = 0 }

/// Lays out the cut list rows that use material mat (sheet sheetL × sheetW). Each of a line's pieces is placed on its
/// own; grain lines may not turn.
func layout(_ rows: [CutRow], _ mat: String, _ sheetL: Int, _ sheetW: Int, _ kerf: Int, _ trim: Int) -> MatLayout {
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
    var sheets: [PSheet] = [], unplaced: [Int] = []
    func orient(_ p: Piece) -> [(Int, Int)] {
        var o: [(Int, Int)] = []
        if p.a <= uL && p.b <= uW { o.append((p.a, p.b)) }
        if !p.grain && p.b <= uL && p.a <= uW && p.a != p.b { o.append((p.b, p.a)) }
        return o
    }
    // the first of the lowest, as Kotlin's minByOrNull
    func lowest<T>(_ xs: [T], _ f: (T) -> Int) -> T? { var best: T? = nil, bv = 0; for x in xs { let v = f(x); if best == nil || v < bv { best = x; bv = v } }; return best }
    for p in order {
        let os = orient(p)
        if os.isEmpty { unplaced.append(p.row); continue }
        var done = false
        // an existing strip it fits in, the lowest waste of height first
        for s in sheets {
            let fits = s.strips.flatMap { st in os.filter { $0.1 <= st.h && st.x + $0.0 <= uL }.map { (st, $0) } }
            if let (st, o) = lowest(fits, { $0.0.h - $0.1.1 }) {
                s.placed.append(Placed(row: p.row, x: st.x, y: st.y, w: o.0, h: o.1, turned: o.0 != p.a))
                st.x += o.0 + kerf; done = true; break
            }
            // a new strip on this sheet: the orientation with the lower height
            let o = lowest(os, { $0.1 })!
            if s.yNext + o.1 <= uW {
                let st = Strip(s.yNext, o.1); s.strips.append(st); s.yNext += o.1 + kerf
                s.placed.append(Placed(row: p.row, x: 0, y: st.y, w: o.0, h: o.1, turned: o.0 != p.a))
                st.x = o.0 + kerf; done = true; break
            }
        }
        if !done {
            let s = PSheet(); sheets.append(s)
            let o = lowest(os, { $0.1 })!
            let st = Strip(0, o.1); s.strips.append(st); s.yNext = o.1 + kerf
            s.placed.append(Placed(row: p.row, x: 0, y: 0, w: o.0, h: o.1, turned: o.0 != p.a)); st.x = o.0 + kerf
        }
    }
    return MatLayout(mat: mat, sheetL: sheetL, sheetW: sheetW, sheets: sheets.map { SheetPlan(placed: $0.placed) }, unplaced: unplaced)
}

/// Layouts for every material of the cut list that comes in sheets (banding is bought by the metre).
func layouts(_ rows: [CutRow], _ mats: [Mat], _ ws: Workshop) -> [MatLayout] {
    var ids: [String] = []
    for r in rows where !ids.contains(r.mat) { ids.append(r.mat) }
    return ids.map { id in
        let m = mats.first { $0.id == id }
        return layout(rows, id, (m?.l ?? 0) > 0 ? m!.l : ws.sheetL, (m?.w ?? 0) > 0 ? m!.w : ws.sheetW, ws.kerf, ws.trim)
    }
}
