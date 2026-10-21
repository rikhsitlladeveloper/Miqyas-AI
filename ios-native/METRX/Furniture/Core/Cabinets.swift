import Foundation

/*
 * More furniture types (furniture plan Stage 2; Android furniture/Cabinets.kt; CabinetsTests): living room (TV unit,
 * shelving, sideboard), bedroom and other (dresser, nightstand, vanity, hallway, desk). Each is a cabinet on the
 * wardrobe's engine: one carcass split into sections with doors, drawers, shelves and rails, so the designer, the
 * parts, the hardware, the price, the 3D and the documents are the same. The sizes are defaults for the makers to check.
 */

/// The types, by group: living room, then bedroom and other.
let LIVING_TYPES = ["tv", "shelving", "sideboard"]
let BEDROOM_TYPES = ["dresser", "nightstand", "vanity", "hallway", "desk"]
let CASE_TYPES = LIVING_TYPES + BEDROOM_TYPES

/// A type's usual size, width × height (legs included) × depth, mm, and whether it stands on legs (else on a plinth).
struct TypeSize: Equatable { let w: Int, h: Int, d: Int, legs: Bool }

func typeSize(_ type: String) -> TypeSize {
    switch type {
    case "tv": return TypeSize(w: 1800, h: 500, d: 450, legs: true)
    case "shelving": return TypeSize(w: 1200, h: 2000, d: 350, legs: false)
    case "sideboard": return TypeSize(w: 1600, h: 850, d: 450, legs: true)
    case "dresser": return TypeSize(w: 1000, h: 850, d: 450, legs: true)
    case "nightstand": return TypeSize(w: 450, h: 500, d: 400, legs: true)
    case "vanity": return TypeSize(w: 800, h: 800, d: 450, legs: true)
    case "hallway": return TypeSize(w: 1200, h: 2000, d: 400, legs: false)
    case "desk": return TypeSize(w: 1200, h: 750, d: 600, legs: true)
    default: return TypeSize(w: 1000, h: 2200, d: W_DEPTH, legs: false)
    }
}

/// n drawers filling a section ih high inside, from the bottom, 20 mm apart.
private func drawers(_ n: Int, _ ih: Int) -> [Insert] {
    let h = max(80, (ih - 20 * (n - 1)) / n)
    return (0..<n).map { Insert("drawer", pos: $0 * (h + 20), h: h) }
}

/// A new cabinet of type, w × h × d on wall at x; h is the whole height, legs included. Its sections follow the type:
/// drawers in open sections have faces in the front material; a desk's knee space has no bottom or back.
func cabinetTemplate(_ type: String, _ ws: Workshop, _ wall: String, _ x: Int, _ w: Int, _ h: Int, _ d: Int) -> Module {
    let sz = typeSize(type)
    var base = Module(id: uid(), type: "wardrobe", w: w, h: sz.legs ? h - ws.legH : h, d: d, x: x, wall: wall, legs: sz.legs)
    let ih = wardInnerH(base, ws.t)
    let open = Fronts("open", 0)
    func door(_ sw: Int) -> Fronts { Fronts("door", sw >= 600 ? 2 : 1) }
    func shelves(_ n: Int) -> [Insert] { Array(repeating: Insert("shelf"), count: n) }
    let secs: [Section]
    switch type {
    case "tv": secs = [Section(w / 3, fronts: open, inserts: drawers(2, ih)), Section(w / 3, fronts: open, inserts: [Insert("shelf", pos: ih / 2)]),
                       Section(w - 2 * (w / 3), fronts: Fronts("door", 1))]
    case "shelving": secs = Array(repeating: Section(0, fronts: open, inserts: shelves(4)), count: max(1, (w + 300) / 600))
    case "sideboard": secs = [Section(w / 2, fronts: door(w / 2), inserts: [Insert("shelf", pos: ih / 2)]), Section(w - w / 2, fronts: open, inserts: drawers(3, ih))]
    case "dresser": secs = [Section(w, fronts: open, inserts: drawers(4, ih))]
    case "nightstand": secs = [Section(w, fronts: open, inserts: drawers(2, ih))]
    case "vanity": secs = [Section(w, fronts: door(w))]
    case "hallway": secs = [Section(w / 2, fronts: Fronts("door", 1), inserts: [Insert("shoe", pos: 0)] + shelves(3)),
                            Section(w - w / 2, fronts: open, inserts: [Insert("shoe", pos: 0), Insert("rail", pos: ih - 120)])]
    case "desk": secs = [Section(min(450, w / 3), fronts: open, inserts: drawers(3, ih)), Section(w - min(450, w / 3), fronts: open, inserts: [], knee: true)]
    default: secs = [Section(w, fronts: door(w))]
    }
    let split = splitSections(w, secs.map { var s = $0; if s.w > 0 { s.lock = true }; return s }).map { var s = $0; s.lock = false; return s }
    base.sections = split.map { s in s.inserts.filter { $0.kind == "shelf" && $0.pos == 0 }.count > 1 ? spreadShelves(s, ih, ws.t) : s }
    return base
}

/// A section is a knee space when the cabinet's type leaves it empty underneath (a desk).
func hasKnee(_ m: Module) -> Bool { m.sections.contains(where: \.knee) }
