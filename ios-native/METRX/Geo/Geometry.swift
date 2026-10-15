import Foundation

/*
 * Room geometry and the rules for typed values, ported from the Android app's geo/Geometry.kt (itself from the
 * prototype). All lengths are millimetres (Int), areas mm² (Int64). Plan y points down; walls run clockwise.
 * Part 2 needs the rectangle only (the project numbers); drawn rooms come with the room editor in part 3.
 */

enum LenUnit { case m, cm }

enum Geo {
    /// Limits of a typed dimension, mm (prototype DIM_MAX).
    static let DIM_MAX: [String: Int] = ["A": 100_000, "B": 100_000, "H": 20_000, "T": 2_000]
    static func dimMax(_ k: String) -> Int { DIM_MAX[k] ?? 100_000 }

    static func decMark(_ en: Bool) -> String { en ? "." : "," }

    /// Length as the prototype's fmtLen: metres with 2 decimals (3 when the mm need it), or centimetres with 0 or 1.
    static func fmtLen(_ mm: Int?, _ unit: LenUnit = .m, _ en: Bool = false, full: Bool = false) -> String {
        guard let mm else { return "?" }
        let s = unit == .cm ? String(format: "%.\(full || mm % 10 != 0 ? 1 : 0)f", Double(mm) / 10)
                            : String(format: "%.\(full ? 3 : mm % 10 != 0 ? 3 : 2)f", Double(mm) / 1000)
        return s.replacingOccurrences(of: ".", with: decMark(en))
    }

    /// Area mm² as m² with 2 decimals.
    static func fmtArea(_ mm2: Int64?, _ en: Bool = false) -> String {
        guard let mm2 else { return "?" }
        return String(format: "%.2f", Double(mm2) / 1e6).replacingOccurrences(of: ".", with: decMark(en))
    }

    /// One wall, clockwise; dimKey holds its length; derived walls (rect C and D) copy A and B.
    struct Wall { let id: String; let corner: Int; let len: Int?; let dimKey: String; let derived: Bool; let p0: Pt; let p1: Pt }

    /// The walls of a room (prototype roomWalls). Rect: A, B measured; C = A, D = B.
    static func walls(_ r: Room, _ snap: Bool = true) -> [Wall] {
        let a = r.dim("A"), b = r.dim("B")
        let L = Double(a.v ?? a.pending?.mm ?? 5000), W = Double(b.v ?? b.pending?.mm ?? 4000)
        return [
            Wall(id: "A", corner: 1, len: a.v, dimKey: "A", derived: false, p0: Pt(x: 0, y: 0), p1: Pt(x: L, y: 0)),
            Wall(id: "B", corner: 2, len: b.v, dimKey: "B", derived: false, p0: Pt(x: L, y: 0), p1: Pt(x: L, y: W)),
            Wall(id: "C", corner: 3, len: a.v, dimKey: "A", derived: true, p0: Pt(x: L, y: W), p1: Pt(x: 0, y: W)),
            Wall(id: "D", corner: 4, len: b.v, dimKey: "B", derived: true, p0: Pt(x: 0, y: W), p1: Pt(x: 0, y: 0)),
        ]
    }

    /// The measurements the builder takes, in order (prototype hmDimKeys): the non-derived walls, then the height.
    static func stepKeys(_ r: Room, _ snap: Bool = true) -> [String] {
        var seen: [String] = []
        for w in walls(r, snap) where !w.derived && !seen.contains(w.dimKey) { seen.append(w.dimKey) }
        return seen + ["H"]
    }

    struct Areas { let floor: Int64; let perim: Int64; let gross: Int64?; let open: Int64?; let net: Int64? }

    /// Floor, perimeter, wall areas from confirmed values only (prototype areas()); nil until the floor is known.
    static func areas(_ r: Room, _ snap: Bool = true) -> Areas? {
        guard let L = r.dim("A").v, let W = r.dim("B").v else { return nil }
        let floor = Int64(L) * Int64(W), perim = 2 * Int64(L + W)
        guard let H = r.dim("H").v else { return Areas(floor: floor, perim: perim, gross: nil, open: nil, net: nil) }
        let gross = perim * Int64(H)
        let open = r.openings.reduce(Int64(0)) { $0 + Int64($1.w) * Int64($1.h) }
        return Areas(floor: floor, perim: perim, gross: gross, open: open, net: gross - open)
    }
}
