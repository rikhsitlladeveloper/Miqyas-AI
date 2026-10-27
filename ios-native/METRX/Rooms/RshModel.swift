import SwiftUI
import Observation

/*
 * Adding a room, the same way in every trade (room-shapes build spec §2, approved mockup design/room-shapes/mockup.html;
 * Android ui/rooms/RoomFlow.kt and RshGeo.kt): the trade's own sheet asks the room's type and name, then this flow asks
 * its shape (8 picture cards, Ko‘zgu / Burish), one size per step on a plan drawn to scale (or a free sketch: every wall
 * plus an optional diagonal), the height, the doors, windows, water, sewer and gas, and shows a summary; "Xonani ochish"
 * makes the room and opens the editor. This file: the draft, its link to the geometry (Geo/RoomShapes.swift,
 * Geo/ShapeRoom.swift), the errors in words and making the room.
 */

/// An opening being added: stage "wall" (pick it on the plan) or "num" (its sizes, sub the one asked).
struct OpEdit: Equatable {
    var kind: OpKind
    var stage = "wall"
    var wall = -1
    var sub = 0
    var vals: [OpField: Int] = [:]
    var input = ""
    var fresh = false
    var err: String? = nil
}

/// A room being added: where it goes (trade decides how it is made) and everything asked so far.
@Observable
final class RshDraft {
    let key: String
    let pid: String
    /// furniture, tiler, elec, plumb, win, build (into the builder's workspace wid) or into (the first room of the
    /// existing workspace wid).
    let trade: String
    /// The trade's room type.
    let kind: String
    let name: String
    let wid: String?
    /// A room-less furniture piece that goes into the room once it is made.
    let fid: String?
    /// shape, sketch, walls, height, ops, summary
    var screen = "shape"
    var shape = "rect"
    var mir = false
    var rot = 0
    /// The asked values by their index, mm.
    var vals: [Int: Int] = [:]
    /// The asked value being typed (for a free sketch, the step after the last wall is the diagonal).
    var step = 0
    var input = ""
    var fresh = false
    var err: String? = nil
    var sk: FreeSketch? = nil
    var diag: Int? = nil
    var height: Int
    var hIn = ""
    var hFresh = true
    var hErr: String? = nil
    var ops: [ShapeOpening] = []
    var op: OpEdit? = nil
    /// A step opened from the summary: its button reads "Saqlash" and goes back there.
    var ret = false
    /// +1 for each laser or voice value (the field's green flash); the voice's words and the value it replaced.
    var flash = 0
    var heard: (before: String, words: String)? = nil
    /// The laser button is waiting for a reading.
    var busy = false

    init(key: String, pid: String, trade: String, kind: String, name: String, wid: String?, fid: String?, h0: Int) {
        self.key = key; self.pid = pid; self.trade = trade; self.kind = kind; self.name = name; self.wid = wid; self.fid = fid; self.height = h0
    }
}

/// The flows in progress, by key (kept while their page is open, also while the laser radar is on top).
enum RshDrafts {
    static var map: [String: RshDraft] = [:]
    static func get(_ k: String) -> RshDraft? { map[k] }
}

/// Starts the flow for a room the trade's sheet named (see RshDraft.trade); fid: a room-less furniture piece that goes
/// into the room once it is made.
func startRoomShape(_ app: AppModel, _ pid: String, trade: String, kind: String, name: String, wid: String? = nil, fid: String? = nil) {
    let d = RshDraft(key: uid(), pid: pid, trade: trade, kind: kind, name: name, wid: wid, fid: fid, h0: AppSettings.shared.lastRoomH)
    RshDrafts.map[d.key] = d
    app.push(.roomShape(pid: pid, key: d.key))
}

/// The lengths a wall may be, and the height, mm (build spec "Limits").
let RSH_WALL_MIN = SHAPE_WALL_MIN
let RSH_WALL_MAX = SHAPE_WALL_MAX
let RSH_H_MIN = SHAPE_HEIGHT_MIN
let RSH_H_MAX = SHAPE_HEIGHT_MAX

/// The flow's unit: a furniture maker's own (mm by default), the others' app unit (AppSettings.unit follows the trade).
func rshUnit(_ d: RshDraft) -> LenUnit { AppSettings.shared.unit }

var rshEn: Bool { AppSettings.shared.lang == .en }

/// "3 400" mm or "3,4" m: a length in the flow's unit, without the unit word.
func lenWords(_ mm: Int, _ unit: LenUnit) -> String { unit == .mm ? fmtMm(Double(mm)) : Geo.fmtLen(mm, unit, rshEn) }

/// "3 400", the mockup's fmt (a thin no-break space between thousands).
func fmtMm(_ v: Double) -> String {
    let n = Int(abs(v).rounded())
    var s = String(n), out = ""
    while s.count > 3 { out = "\u{00A0}" + String(s.suffix(3)) + out; s = String(s.dropLast(3)) }
    return s + out
}

/// A value as the field shows it: digits in mm, "3,4" in m.
func rshFieldText(_ mm: Int, _ unit: LenUnit) -> String { unit == .mm ? String(mm) : Geo.fmtField(mm, unit, rshEn) }

/// A typed size: the distance and the sill may be 0 (in the corner, on the floor), so "0" reads as 0 for them.
func rshParse(_ s: String, _ unit: LenUnit, zeroOk: Bool = false) -> Int? {
    let t = s.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return nil }
    if zeroOk && t.allSatisfy({ $0 == "0" || $0 == "," || $0 == "." }) { return 0 }
    return parseLen(t, unit)
}

/* ---------------- the geometry ---------------- */

/// The draft's shape as the geometry takes it; a free card not drawn yet is a rectangle until it is.
func specOf(_ d: RshDraft) -> ShapeSpec {
    let sh = RoomShape.of(d.shape) ?? .rect
    if sh == .free && d.sk == nil { return ShapeSpec(.rect) }
    return ShapeSpec(sh, mirror: d.mir, turns: d.rot, sketch: sh == .free ? d.sk : nil)
}

func rshAsks(_ d: RshDraft) -> [ShapeAsk] { asks(specOf(d)) }

private func valsList(_ d: RshDraft, _ vals: [Int: Int]) -> [Int?] { (0..<rshAsks(d).count).map { vals[$0] } }

/// The plan for vals (the asked values typed so far; the others take their defaults), with the editor's wall letters.
struct RGeo {
    let g: ShapeGeo
    let letters: [String]
    func letter(_ i: Int?) -> String { i.flatMap { $0 >= 0 && $0 < letters.count ? letters[$0] : nil } ?? "?" }
}

func rshGeo(_ d: RshDraft, _ vals: [Int: Int]? = nil) -> RGeo {
    let spec = specOf(d)
    let vs = valsList(d, vals ?? d.vals)
    let g = shapeGeometry(spec, vs)
    // the room's own letters (ShapeRoom.wallIds) once it closes; worked out the same way while it does not
    let letters: [String]
    if g.ok, let sr = shapeToRoom(spec, vs, height: d.height, id: "x", floorId: "x", name: "x") { letters = sr.wallIds }
    else { letters = shapeWallIds(spec, g.walls.count) }
    return RGeo(g: g, letters: letters)
}

/// What stops "Keyingi" on walls step st with vals (this step's value in), in words; nil when it may go on.
func rshStepErr(_ d: RshDraft, _ vals: [Int: Int], _ st: Int) -> String? {
    stepError(specOf(d), valsList(d, vals), st, editingOne: d.ret).map { rshErrText(d, $0) }
}

/// The free sketch's diagonal: the corner it goes to, the length the walls give, and what is wrong with v.
func rshDiagK(_ d: RshDraft) -> Int { diagonalCorner(specOf(d)) }
func rshDiagLen(_ d: RshDraft) -> Double {
    let g = shapeGeometry(specOf(d), valsList(d, d.vals))
    return g.corners.count > rshDiagK(d) ? expectedDiagonal(g) : 3000
}
func rshDiagErr(_ d: RshDraft, _ v: Int?) -> String? { diagonalError(specOf(d), valsList(d, d.vals), v).map { rshErrText(d, $0) } }

/// The fields an opening asks, with their labels (rsh.f.*).
func opFieldKey(_ kind: OpKind, _ f: OpField) -> String {
    switch f {
    case .dist: return "rsh.f.dist"
    case .width: return kind == .door ? "rsh.f.doorW" : "rsh.f.winW"
    case .height: return kind == .door ? "rsh.f.doorH" : "rsh.f.winH"
    case .sill: return "rsh.f.sill"
    }
}

/// The value an opening's field starts from on its wall (the default, shrunk to fit).
func rshOpHint(_ d: RshDraft, _ op: OpEdit) -> Int {
    let g = shapeGeometry(specOf(d), valsList(d, d.vals))
    let f = opAsks(op.kind)[op.sub]
    guard op.wall >= 0, op.wall < g.walls.count else { return f.def }
    return opHint(g, d.height, op.kind, op.wall, f.field, dist: op.vals[.dist] ?? 0, w: op.vals[.width] ?? 0, h: op.vals[.height] ?? 0)
}

/// What is wrong with v typed into the opening's field being asked, in words.
func rshOpErr(_ d: RshDraft, _ op: OpEdit, _ v: Int?) -> String? {
    let g = shapeGeometry(specOf(d), valsList(d, d.vals))
    let f = opAsks(op.kind)[op.sub].field
    guard let e = opFieldError(g, d.height, op.kind, op.wall, f, v, dist: op.vals[.dist] ?? 0, w: op.vals[.width] ?? 0, h: op.vals[.height] ?? 0) else { return nil }
    if e.code == .outOfRange && f == .height {
        let unit = rshUnit(d)
        return tr("rsh.e.opH", ["a": lenWords(300, unit), "b": lenWords(d.height, unit), "u": unitWord(unit)])
    }
    return rshErrText(d, e)
}

/// An error in the maker's words, lengths in the flow's unit and the editor's wall letters.
func rshErrText(_ d: RshDraft, _ e: ShapeError) -> String {
    let unit = rshUnit(d)
    let u = unitWord(unit)
    func len(_ x: Double?) -> String { lenWords(Int((x ?? 0).rounded()), unit) + " " + u }
    let geo = rshGeo(d)
    func wl(_ i: Int?) -> String { geo.letter(i ?? 0) }
    func signed(_ x: Double?) -> String { ((x ?? 0) < 0 ? "−" : "") + len(abs(x ?? 0)) }
    switch e.code {
    case .outOfRange:
        let r = tr("rsh.range", ["a": lenWords(Int((e.min ?? 0).rounded()), unit), "b": lenWords(Int((e.limit ?? 0).rounded()), unit), "u": u])
        return tr("rsh.e.enter", ["r": r])
    case .cutDNotShorter: return tr("rsh.e.cutD", ["v": len(e.limit), "d": wl(3), "a": wl(0)])
    case .cutBNotShorter: return tr("rsh.e.cutB", ["v": len(e.limit), "b": wl(1), "e": wl(4)])
    case .cutNoCut: return tr("rsh.e.cut", ["a": wl(0), "b": wl(1), "d": wl(3), "e": wl(4)])
    case .bayNotFit: return tr("rsh.e.bayFit", ["v": len(e.value), "l": len(e.limit), "a": wl(0), "g": wl(6)])
    case .bayTooDeep: return tr("rsh.e.bayDeep")
    case .notClosed: return tr("rsh.e.open", ["v": len(e.value)])
    case .wallNegative: return tr("rsh.e.neg", ["w": wl(e.wall), "v": signed(e.value)])
    case .wallsCross: return tr("rsh.e.cross")
    case .diagMismatch: return tr("rsh.e.diag", ["v": len(e.limit)])
    case .empty: return tr("rsh.e.num")
    case .opPastWall: return tr("rsh.e.long", ["w": wl(e.wall), "l": len(e.limit)])
    case .opNotFit: return tr("rsh.e.fit", ["s": len(e.value), "l": len(e.limit)])
    case .opAboveCeiling: return tr("rsh.e.sill", ["s": len(e.value), "l": len(e.limit)])
    }
}

/* ---------------- making the room ---------------- */

/// The room the flow made, into the trade's fresh base room (its id, workspace, name and date kept).
func rshRoom(_ base: Room, _ d: RshDraft) -> Room {
    let made = shapeToRoom(specOf(d), valsList(d, d.vals), height: d.height, id: base.id, floorId: base.floorId, name: base.name,
                           created: base.created, diagonal: d.diag, openings: d.ops, angleSnap: AppSettings.shared.angleSnap)
    return made?.room ?? base
}

/// Makes the room as its trade does, with the flow's shape, sizes, height and openings; returns its id.
private func makeRoom(_ app: AppModel, _ d: RshDraft) -> String? {
    guard let p = Store.shared.get(d.pid) else { return nil }
    let rid: String
    switch d.trade {
    case "furniture": rid = addFurnRoom(d.pid, d.kind, d.name)
    case "tiler": rid = addTileRoom(d.pid, d.kind, d.name)
    case "elec": rid = addElecRoom(d.pid, d.kind, d.name)
    case "plumb": rid = addPlumbRoom(d.pid, d.kind, d.name)
    case "win": rid = addWinRoom(d.pid, d.name)
    default:
        guard let w = p.floors.first(where: { $0.id == d.wid }) else { return nil }
        let r = Room(id: uid(), floorId: w.id, name: d.name, created: nowMs())
        Store.shared.update(d.pid) { $0.rooms.append(r) }
        rid = r.id
    }
    Store.shared.update(d.pid) { pr in pr.rooms = pr.rooms.map { $0.id == rid ? rshRoom($0, d) : $0 } }
    if let fid = d.fid { app.placeAfter = (rid, fid) }
    AppSettings.shared.keepRoomH(d.height)
    return rid
}

/// "Xonani ochish": the room is made, the editor opens, and a toast offers Undo (which takes the room back out).
func finishRoom(_ app: AppModel, _ d: RshDraft) {
    guard app.once(), let before = Store.shared.get(d.pid) else { return }
    guard let rid = makeRoom(app, d) else { return }
    RshDrafts.map[d.key] = nil
    app.replaceTop(.editor(pid: d.pid, rid: rid, mode: "plan"))
    let pid = d.pid
    app.act("rsh.added", ["n": dn(d.name)]) {
        Store.shared.update(pid) { p in
            p.floors = before.floors; p.rooms = before.rooms; p.elec = before.elec; p.plumb = before.plumb; p.troom = before.troom
        }
        if AppModel.shared.placeAfter?.rid == rid { AppModel.shared.placeAfter = nil }
        AppModel.shared.dropMissing()
    }
}
