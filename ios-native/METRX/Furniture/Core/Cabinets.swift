import Foundation

/*
 * More furniture types (furniture plan Stage 2; Android furniture/Cabinets.kt; CabinetsTests): living room (TV unit,
 * shelving, sideboard), bedroom and other (dresser, nightstand, vanity, hallway, desk). Each is a cabinet on the
 * wardrobe's engine: one carcass split into sections with doors, drawers, shelves and rails, so the designer, the
 * parts, the hardware, the price, the 3D and the documents are the same. The sizes are defaults for the makers to check.
 */

/// The types, by group: living room, then bedroom and other, then the gallery's later ones (22 Oct 2026) by room.
let LIVING_TYPES = ["tv", "shelving", "sideboard"]
let BEDROOM_TYPES = ["dresser", "nightstand", "vanity", "hallway", "desk"]
let MORE_TYPES = ["pantry", "tvBed", "shelfW", "shelvesW", "shoe", "hallW", "kidsW", "toys", "bookcase", "officeC", "sinkV", "mirrorC", "penal"]
let CASE_TYPES = LIVING_TYPES + BEDROOM_TYPES + MORE_TYPES

/// Cabinets that hang on the wall: their bottom TypeSize.elev above the floor.
let HUNG_TYPES: Set<String> = ["shelfW", "shelvesW", "mirrorC"]

/// Bathroom pieces: moisture-resistant board by default; a vanity and a tall cabinet stand on legs or hang.
let BATH_TYPES: Set<String> = ["sinkV", "mirrorC", "penal", "washer"]
let MOUNT_TYPES: Set<String> = ["sinkV", "penal"]

/// A type's usual size, width × height (legs included) × depth, mm, and whether it stands on legs (else on a plinth); a
/// hung one's bottom elev above the floor (its h the carcass alone).
struct TypeSize: Equatable {
    let w: Int, h: Int, d: Int, legs: Bool
    var elev = 0
    init(w: Int, h: Int, d: Int, legs: Bool, elev: Int = 0) { self.w = w; self.h = h; self.d = d; self.legs = legs; self.elev = elev }
}

func typeSize(_ type: String) -> TypeSize {
    switch type {
    case "tv": return TypeSize(w: 1800, h: 500, d: 450, legs: true)
    case "shelving": return TypeSize(w: 1200, h: 2000, d: 350, legs: false)
    case "sideboard": return TypeSize(w: 1600, h: 850, d: 450, legs: true)
    case "dresser": return TypeSize(w: 1000, h: 850, d: 450, legs: true)
    case "nightstand": return TypeSize(w: 450, h: 500, d: 400, legs: true)
    // a dressing table: drawers beside a knee space, its mirror on the wall above (Pieces.swift)
    case "vanity": return TypeSize(w: 1000, h: 750, d: 450, legs: true)
    case "hallway": return TypeSize(w: 1200, h: 2000, d: 400, legs: false)
    case "desk": return TypeSize(w: 1200, h: 750, d: 600, legs: true)
    case "pantry": return TypeSize(w: 600, h: 2100, d: 600, legs: true)
    case "tvBed": return TypeSize(w: 1200, h: 550, d: 400, legs: true)
    case "shelfW": return TypeSize(w: 1000, h: 300, d: 250, legs: false, elev: 1500)
    case "shelvesW": return TypeSize(w: 1600, h: 700, d: 300, legs: false, elev: 1300)
    case "shoe": return TypeSize(w: 800, h: 1000, d: 300, legs: true)
    case "hallW": return TypeSize(w: 600, h: 2100, d: 400, legs: false)
    case "kidsW": return TypeSize(w: 1000, h: 1800, d: 500, legs: false)
    case "toys": return TypeSize(w: 1000, h: 900, d: 350, legs: false)
    case "bookcase": return TypeSize(w: 800, h: 2000, d: 350, legs: false)
    case "officeC": return TypeSize(w: 900, h: 2000, d: 450, legs: false)
    case "sinkV": return TypeSize(w: 800, h: 850, d: 450, legs: true)
    case "mirrorC": return TypeSize(w: 600, h: 700, d: 150, legs: false, elev: 1250)
    case "penal": return TypeSize(w: 400, h: 1800, d: 300, legs: true)
    default: return TypeSize(w: 1000, h: 2200, d: W_DEPTH, legs: false)
    }
}

/// n drawers filling a section ih high inside. Their faces are seen, set in the carcass: g apart and g from the bottom
/// and the top, as the doors' gap.
private func drawers(_ n0: Int, _ ih: Int, _ g: Int) -> [Insert] {
    // a low cabinet takes fewer drawers: each keeps about 100 mm, all inside
    let n = min(n0, max(1, (ih + 20) / 100))
    let h = max(80, (ih - g * (n + 1)) / n)
    return (0..<n).map { Insert("drawer", pos: g + $0 * (h + g), h: h) }
}

/// A new cabinet of type, w × h × d on wall at x; h is the whole height, legs included. Its sections follow the type:
/// drawers in open sections have faces in the front material; a desk's knee space has no bottom or back.
func cabinetTemplate(_ type: String, _ ws: Workshop, _ wall: String, _ x: Int, _ w: Int, _ h: Int, _ d: Int) -> Module {
    let sz = typeSize(type)
    // a hung cabinet has neither legs nor a plinth: its sides end at its bottom
    var base = Module(id: uid(), type: "wardrobe", w: w, h: sz.legs ? h - ws.legH : h, d: d, x: x, wall: wall, elev: sz.elev, legs: sz.legs,
                      base: sz.elev > 0 ? 0 : nil)
    let ih = wardInnerH(base, ws.t)
    let g = ws.gap10 / 10
    let open = Fronts("open", 0)
    func door(_ sw: Int) -> Fronts { Fronts("door", sw >= 600 ? 2 : 1) }
    func shelves(_ n: Int) -> [Insert] { Array(repeating: Insert("shelf"), count: n) }
    let secs: [Section]
    switch type {
    case "tv": secs = [Section(w / 3, fronts: open, inserts: drawers(2, ih, g)), Section(w / 3, fronts: open, inserts: [Insert("shelf", pos: ih / 2)]),
                       Section(w - 2 * (w / 3), fronts: Fronts("door", 1))]
    case "shelving": secs = Array(repeating: Section(0, fronts: open, inserts: shelves(4)), count: max(1, (w + 300) / 600))
    case "sideboard": secs = [Section(w / 2, fronts: door(w / 2), inserts: [Insert("shelf", pos: ih / 2)]), Section(w - w / 2, fronts: open, inserts: drawers(3, ih, g))]
    case "dresser": secs = [Section(w, fronts: open, inserts: drawers(4, ih, g))]
    case "nightstand": secs = [Section(w, fronts: open, inserts: drawers(2, ih, g))]
    case "vanity": secs = [Section(min(450, w * 2 / 5), fronts: open, inserts: drawers(4, ih, g)), Section(w - min(450, w * 2 / 5), fronts: open, inserts: [], knee: true)]
    case "hallway": secs = [Section(w / 2, fronts: Fronts("door", 1), inserts: [Insert("shoe", pos: 0)] + shelves(3)),
                            // the open side: a bench to sit on over the shoe rack (its top about 480 from the floor), coats on a rail above
                            Section(w - w / 2, fronts: open, inserts: [Insert("shoe", pos: 0), Insert("shelf", pos: 480 - PLINTH - 2 * ws.t), Insert("rail", pos: ih - 120)])]
    case "desk": secs = [Section(min(450, w / 3), fronts: open, inserts: drawers(3, ih, g)), Section(w - min(450, w / 3), fronts: open, inserts: [], knee: true)]
    case "pantry", "penal": secs = [Section(w, fronts: Fronts("door", 1), inserts: shelves(5))]
    case "tvBed": secs = [Section(w / 2, fronts: open, inserts: [Insert("shelf", pos: ih / 2)]), Section(w - w / 2, fronts: open, inserts: drawers(2, ih, g))]
    case "shelfW": secs = [Section(w / 2, fronts: open), Section(w - w / 2, fronts: open)]
    // three open boxes, their shelves at a staggered height
    case "shelvesW": secs = [Section(w / 3, fronts: open, inserts: [Insert("shelf", pos: ih / 3)]), Section(w / 3, fronts: open, inserts: [Insert("shelf", pos: ih * 2 / 3)]),
                             Section(w - 2 * (w / 3), fronts: open, inserts: [Insert("shelf", pos: ih / 3)])]
    case "shoe", "bookcase": secs = [Section(w, fronts: door(w), inserts: shelves(type == "shoe" ? 3 : 5))]
    case "hallW": secs = [Section(w, fronts: Fronts("door", 1), inserts: [Insert("rail", pos: ih - 380), Insert("shelf", pos: ih - 310)])]
    // a child reaches the rail at about 1200 from the floor
    case "kidsW":
        let rail = min(ih - 380, 1100)
        secs = [Section(w / 2, fronts: Fronts("door", 1), inserts: [Insert("rail", pos: rail), Insert("shelf", pos: rail + 70)]),
                Section(w - w / 2, fronts: Fronts("door", 1), inserts: shelves(4))]
    case "toys": secs = [Section(w / 3, fronts: open, inserts: [Insert("shelf", pos: ih / 2)]), Section(w / 3, fronts: open, inserts: drawers(2, ih, g)),
                         Section(w - 2 * (w / 3), fronts: open, inserts: [Insert("shelf", pos: ih / 2)])]
    case "officeC": secs = [Section(w / 2, fronts: Fronts("door", 1), inserts: shelves(4)),
                            Section(w - w / 2, fronts: Fronts("door", 1), inserts: drawers(3, min(ih, 600), g) + [Insert("shelf", pos: 0), Insert("shelf", pos: 0)])]
    case "sinkV": secs = [Section(w, fronts: door(w))]
    case "mirrorC": secs = [Section(w, fronts: Fronts("door", w >= 500 ? 2 : 1), inserts: shelves(2), face: "mirror")]
    default: secs = [Section(w, fronts: door(w))]
    }
    let split = splitSections(w, secs.map { var s = $0; if s.w > 0 { s.lock = true }; return s }).map { var s = $0; s.lock = false; return s }
    base.sections = split.map { s in s.inserts.filter { $0.kind == "shelf" && $0.pos == 0 }.count > 1 ? spreadShelves(s, ih, ws.t) : s }
    // a mirror cabinet over a basin has no handles: it opens by its edge
    base.handles = type != "mirrorC"
    return base
}

/// A section is a knee space when the cabinet's type leaves it empty underneath (a desk).
func hasKnee(_ m: Module) -> Bool { m.sections.contains(where: \.knee) }
