import SwiftUI

/*
 * The plumber's sheets (Android ui/plumb/PlumbScreens.kt, sheets part): a new room, a fixture (a new one's type, or a
 * placed one's wall, place, width, cabinet and outlet heights), a loose outlet, a room's settings (kind, doors, pipe
 * between the doors, underfloor heating, radiators, the riser here), the pipe system, the prices, and a room typed by
 * size.
 */

struct PlumbSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .pNewRoom, .pFix, .pPoint, .pRoomSet, .pSystem, .pPrices, .pFree: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .pNewRoom(let pid): PSNewRoomSheet(app: app, pid: pid)
        case .pFix(let pid, let rid, let fid, let wall):
            if fid == nil { PSFixNewSheet(app: app, pid: pid, rid: rid, wall: wall) } else { PSFixEditSheet(app: app, pid: pid, rid: rid, fid: fid ?? "") }
        case .pPoint(let pid, let rid, let ptId, let wall):
            if ptId == nil { PSPointNewSheet(app: app, pid: pid, rid: rid, wall: wall) } else { PSPointEditSheet(app: app, pid: pid, rid: rid, ptId: ptId ?? "") }
        case .pRoomSet(let pid, let rid): PSRoomSetSheet(app: app, pid: pid, rid: rid)
        case .pSystem(let pid): PSSystemSheet(app: app, pid: pid)
        case .pPrices(let pid): PSPricesSheet(app: app, pid: pid)
        case .pFree(let pid, let fid): PSFreeSheet(app: app, pid: pid, fid: fid)
        default: EmptyView()
        }
    }
}

/// Keeps what can be typed in a length field: digits and one decimal mark, at most n characters.
private func psLenText(_ b: Binding<String>, _ n: Int) -> Binding<String> {
    Binding(get: { b.wrappedValue }, set: { v in b.wrappedValue = String(v.filter { $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }.prefix(n)) })
}

/// A typed offset in mm (zero allowed; nil when empty or unreadable).
private func psOff(_ s: String, _ unit: LenUnit) -> Int? {
    if s.trimmingCharacters(in: .whitespaces).isEmpty { return nil }
    return Geo.parseDec(s, Geo.unitDecimals(unit)).value.map { Int($0) }
}

/// A row with a title, a line under it and a switch.
private struct PSSwitchRow: View {
    let title: String
    var sub: String? = nil
    let on: Bool
    let action: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15, 700))
                if let sub { T(sub, ui(12, 400, G.ink2, lh: 1.3)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GSwitch(on: on)
        }
        .padding(.horizontal, 14).frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.7)))
        .pressable(0.98, action)
        .accessibilityAddTraits(.isButton)
    }
}

/// The walls of room c as chips, wall the one chosen.
private struct PSWallChips: View {
    let c: PCtx
    let wall: String
    let pick: (String) -> Void
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(c.g.walls.map(\.id), id: \.self) { id in FChip(label: tr("tl.wallN", ["w": id]), on: id == wall) { pick(id) } }
        }
    }
}

/* ---------------- a new room ---------------- */

private enum PSNF: Hashable { case name }

private struct PSNewRoomSheet: View {
    let app: AppModel
    let pid: String
    @State private var kind: String
    @State private var name: String
    @FocusState private var focus: PSNF?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        _kind = State(initialValue: "bath")
        _name = State(initialValue: PSNewRoomSheet.nameFor("bath", Store.shared.get(pid)))
    }
    static func nameFor(_ k: String, _ p: Project?) -> String {
        guard let p else { return tr(pKindKey(k)) }
        return nextName(p, pKindKey(k))
    }
    var body: some View {
        let p = Store.shared.get(pid)
        GlassSheet(tr("fo.addRoom"), onClose: { app.sheet = nil }) {
            T(tr("fr.type"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach(P_KINDS, id: \.self) { k in FChip(label: tr(pKindKey(k)), on: k == kind) { kind = k; name = PSNewRoomSheet.nameFor(k, p) } }
            }
            GField(label: tr("fr.name"), value: $name, placeholder: tr(pKindKey(kind)), error: name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("nr.nameReq") : nil,
                   showError: true, focus: $focus, me: .name, submit: .done, onSubmit: create)
                .onChange(of: name) { _, n in if n.count > NAME_MAX { name = String(n.prefix(NAME_MAX)) } }
        } footer: {
            GBtn(tr("fo.drawRoom"), enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, create).accessibilityIdentifier("sx.roomCreate")
        }
    }
    private func create() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, app.once() else { return }
        // a suggested name is kept as its key, so it follows the language
        let rid = addPlumbRoom(pid, kind, suggestedName(n, pKindKey(kind)))
        app.sheet = nil
        openRoom(app, pid, rid)
    }
}

/* ---------------- a fixture ---------------- */

/// A new fixture: pick its type, then it goes on the wall shown (a radiator under a window).
private struct PSFixNewSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let wall: String?
    @State private var cat = "wet"
    var body: some View {
        if let p = Store.shared.get(pid), let c = pCtxOf(p, rid, AppSettings.shared.angleSnap) {
            GlassSheet(tr("sx.addFix"), onClose: { app.sheet = nil }) {
                FlowLayout(spacing: 8) {
                    ForEach(FIX_CATS, id: \.self) { k in FChip(label: tr("sx.cat." + k), on: k == cat) { cat = k } }
                }
                ForEach(FIX_TYPES.filter { $0.cat == cat }.map(\.id), id: \.self) { tid in row(p, c, tid) }
            }
        }
    }
    private func row(_ p: Project, _ c: PCtx, _ tid: String) -> some View {
        let ty = fixType(tid)
        let en = AppSettings.shared.lang == .en
        let sub: String = Geo.fmtLen(ty.w, .m, en) + " × " + Geo.fmtLen(ty.d, .m, en) + " " + tr("u.m")
        return HStack(spacing: 12) {
            FixSymbolView(t: tid).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                T(tr("sx.t." + tid), ui(15, 700))
                T(sub, ui(12.5, 400, G.ink2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.7)))
        .pressable(0.98) { add(p, c, tid) }
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("sx.fix." + tid)
    }
    private func spot(_ p: Project, _ c: PCtx, _ tid: String, _ have: [PlFix]) -> PlFix? {
        let liveR = liveRiser(p)
        if tid == "rad" { return placeRadiators(c, have, liveR, { uid() }).first }
        let ty = fixType(tid)
        if let w = c.wall(wall), let x = fixSpot(c, tid, w, w.len / 2, ty.w, have, liveR) {
            return newFix(uid(), tid, c, w, x)
        }
        return placeFix(tid, c, have, liveR, uid())
    }
    private func add(_ p: Project, _ c: PCtx, _ tid: String) {
        guard app.once() else { return }
        let have = p.plumb.fixes.filter { $0.roomId == c.id }
        guard let f = spot(p, c, tid, have) else { app.say("el.noSpace"); return }
        updatePlumb(p.id) { $0.fixes.append(f) }
        app.sheet = nil
        app.say("el.devAdded", ["n": tr("sx.t." + tid)])
    }
}

/// A placed fixture: its wall, place, width (a radiator), cabinet (a basin) and its outlets' heights.
private struct PSFixEditSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let fid: String
    @State private var wall: String
    @State private var tOff: String
    @State private var tW: String
    @State private var cab: Bool
    @State private var hs: [String]
    @FocusState private var focus: String?

    init(app: AppModel, pid: String, rid: String, fid: String) {
        self.app = app; self.pid = pid; self.rid = rid; self.fid = fid
        let s = AppSettings.shared
        let en = s.lang == .en
        let old = Store.shared.get(pid)?.plumb.fixes.first { $0.id == fid } ?? PlFix(id: fid, t: "wc", roomId: rid, wall: "A", off: 0)
        _wall = State(initialValue: old.wall)
        _tOff = State(initialValue: Geo.fmtField(old.off, s.unit, en))
        _tW = State(initialValue: Geo.fmtField(fixW(old), s.unit, en))
        _cab = State(initialValue: old.opt == "cab")
        _hs = State(initialValue: old.pts.map { Geo.fmtField($0.h, s.unit, en) })
    }

    var body: some View {
        let snap = AppSettings.shared.angleSnap
        if let p = Store.shared.get(pid), let c = pCtxOf(p, rid, snap), let old = p.plumb.fixes.first(where: { $0.id == fid }) {
            content(c, old)
        }
    }

    private func heights() -> [Int?] {
        let unit = AppSettings.shared.unit
        return hs.map { parseLen($0, unit) }
    }

    private func errOf(_ c: PCtx, _ old: PlFix) -> String? {
        let unit = AppSettings.shared.unit
        guard let vOff = psOff(tOff, unit), let vW = parseLen(tW, unit) else { return tr("tl.fixErr") }
        let vH = heights()
        if vH.contains(where: { $0 == nil }) { return tr("tl.fixErr") }
        // a radiator of two sections at least (and no wider than its wall)
        let wl = c.wall(wall)?.len
        if old.t == "rad" && (vW < 2 * SEC_MM || (wl.map { Double(vW) > $0 } ?? false)) { return tr("sx.radMin", ["a": 2 * SEC_MM]) }
        if let wl, Double(vOff) > wl { return tr("pt.offBig") }
        if vH.contains(where: { ($0 ?? 0) > c.H }) { return tr("pt.hBig") }
        return nil
    }

    @ViewBuilder private func content(_ c: PCtx, _ old: PlFix) -> some View {
        let err = errOf(c, old)
        GlassSheet(tr("sx.t." + old.t), onClose: { app.sheet = nil }) {
            T(tr("tl.fixWall"), ui(15, 700))
            PSWallChips(c: c, wall: wall) { wall = $0 }
            sizes(old)
            if old.t == "rad" { T(radLine(c, old), ui(12.5, 400, G.ink2, lh: 1.4)) }
            if old.t == "bs" || old.t == "bsm" {
                PSSwitchRow(title: tr("sx.s.vanity"), sub: tr("sx.s.vanityS"), on: cab) { cab.toggle() }
            }
            if old.t != "rad" && !old.pts.isEmpty { outlets(old) }
            T(tr("sx.dragHint"), ui(12.5, 400, G.ink2, lh: 1.4))
            if let err { T(err, ui(13, 500, G.err)) }
        } footer: {
            GBtn(tr("common.save"), enabled: err == nil) { save(c, old) }.accessibilityIdentifier("sx.fixSave")
            GBtn(tr("common.delete"), kind: .secondary) { delete(old) }.accessibilityIdentifier("sx.fixDel")
        }
    }

    private func radLine(_ c: PCtx, _ old: PlFix) -> String {
        let need = radSections(c.areaM2) * SEC_W
        return tr("sx.radW", ["w": radWatts(old), "n": need])
    }

    private func sizes(_ old: PlFix) -> some View {
        let uw = unitWord(AppSettings.shared.unit)
        return HStack(alignment: .top, spacing: 10) {
            GField(label: tr("sx.f.off"), value: psLenText($tOff, 8), placeholder: "1", focus: $focus, me: "off", labelRight: uw, decimal: true)
                .frame(maxWidth: .infinity)
            if old.t == "rad" {
                GField(label: tr("sx.f.w"), value: psLenText($tW, 8), placeholder: "0,6", focus: $focus, me: "w", labelRight: uw, decimal: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func usualLine(_ old: PlFix) -> String {
        let en = AppSettings.shared.lang == .en
        let parts = fixType(old.t).pts.map { tr("sx.o." + $0.t) + " " + Geo.fmtLen($0.h, .m, en) }
        return tr("sx.usualH", ["h": parts.joined(separator: ", ")])
    }

    private func outlets(_ old: PlFix) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            T(tr("sx.outlets"), ui(15, 700))
            ForEach(Array(old.pts.enumerated()), id: \.offset) { i, q in outletRow(i, q) }
            T(usualLine(old), ui(12.5, 400, G.ink2, lh: 1.4))
        }
    }

    private func outletRow(_ i: Int, _ q: FixPt) -> some View {
        let uw = unitWord(AppSettings.shared.unit)
        let label: String = tr("sx.o." + q.t) + (q.d > 0 ? " \(q.d)" : "")
        let text = Binding(get: { i < hs.count ? hs[i] : "" }, set: { v in
            if i < hs.count { hs[i] = String(v.filter { $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }.prefix(8)) }
        })
        return HStack(spacing: 10) {
            PtSymbolView(t: q.t).frame(width: 20, height: 20)
            T(label, ui(14, 600)).frame(maxWidth: .infinity, alignment: .leading)
            GField(label: tr("el.f.h"), value: text, placeholder: "\(q.h)", focus: $focus, me: "h\(i)", labelRight: uw, decimal: true)
                .frame(maxWidth: 150)
        }
    }

    private func save(_ c: PCtx, _ old: PlFix) {
        guard errOf(c, old) == nil, app.once() else { return }
        let unit = AppSettings.shared.unit
        guard let vOff = psOff(tOff, unit), let vW = parseLen(tW, unit) else { return }
        let vH = heights()
        let newWall = wall, cabOn = cab
        updateFix(pid, old.id) { f in
            f.wall = newWall
            f.off = vOff
            f.opt = (f.t == "bs" || f.t == "bsm") && cabOn ? "cab" : ""
            if f.t == "rad" && vW != fixW(f) {
                f = resizeFix(f, vW)
            } else {
                for i in f.pts.indices where i < vH.count {
                    if let h = vH[i] { f.pts[i].h = h }
                }
            }
        }
        app.sheet = nil; app.say("common.save")
    }

    private func delete(_ old: PlFix) {
        guard let fixes = Store.shared.get(pid)?.plumb.fixes, let at = fixes.firstIndex(where: { $0.id == old.id }) else { return }
        let gone = fixes[at], id = old.id, p0 = pid
        updatePlumb(p0) { e in e.fixes.removeAll { $0.id == id } }
        app.sheet = nil
        // Undo puts back only this fixture, where it was
        app.say("sx.fixDel", action: "common.undo") {
            updatePlumb(p0) { e in if !e.fixes.contains(where: { $0.id == gone.id }) { e.fixes = e.fixes.putBack(gone, at: at) } }
        }
    }
}

/* ---------------- a loose outlet ---------------- */

/// A new loose outlet: pick its kind, then it goes in the middle of the wall shown at its usual height.
private struct PSPointNewSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let wall: String?
    var body: some View {
        if let p = Store.shared.get(pid), let c = pCtxOf(p, rid, AppSettings.shared.angleSnap) {
            GlassSheet(tr("sx.addPt"), onClose: { app.sheet = nil }) {
                ForEach(PT_KINDS, id: \.self) { k in row(p, c, k) }
            }
        }
    }
    private func row(_ p: Project, _ c: PCtx, _ k: String) -> some View {
        let sub = tr("el.atH", ["h": Geo.fmtLen(usualPtH(k), .m, AppSettings.shared.lang == .en)])
        return HStack(spacing: 12) {
            PtSymbolView(t: k).frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                T(tr("sx.o." + k), ui(15, 700))
                T(sub, ui(12.5, 400, G.ink2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.7)))
        .pressable(0.98) { add(p, c, k) }
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("sx.pt." + k)
    }
    private func add(_ p: Project, _ c: PCtx, _ k: String) {
        guard app.once() else { return }
        let w = c.wall(wall) ?? c.g.walls[0]
        let q = PlPoint(id: uid(), t: k, roomId: c.id, wall: w.id, off: tInt(w.len / 2), h: usualPtH(k), d: k == "drain" ? 50 : 0)
        updatePlumb(p.id) { $0.points.append(q) }
        app.sheet = nil
        app.say("el.devAdded", ["n": tr("sx.o." + k)])
    }
}

/// A placed loose outlet: its kind, a drain's diameter, its wall, place and height.
private struct PSPointEditSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let ptId: String
    @State private var t: String
    @State private var wall: String
    @State private var tOff: String
    @State private var tH: String
    @State private var d: Int
    @FocusState private var focus: String?

    init(app: AppModel, pid: String, rid: String, ptId: String) {
        self.app = app; self.pid = pid; self.rid = rid; self.ptId = ptId
        let s = AppSettings.shared
        let en = s.lang == .en
        let old = Store.shared.get(pid)?.plumb.points.first { $0.id == ptId } ?? PlPoint(id: ptId, t: "cold", roomId: rid, wall: "A", off: 0, h: 550)
        _t = State(initialValue: old.t)
        _wall = State(initialValue: old.wall)
        _tOff = State(initialValue: Geo.fmtField(old.off, s.unit, en))
        _tH = State(initialValue: Geo.fmtField(old.h, s.unit, en))
        _d = State(initialValue: old.d >= 100 ? 110 : 50)
    }

    var body: some View {
        let snap = AppSettings.shared.angleSnap
        if let p = Store.shared.get(pid), let c = pCtxOf(p, rid, snap), let old = p.plumb.points.first(where: { $0.id == ptId }) {
            content(c, old)
        }
    }

    private func errOf(_ c: PCtx) -> String? {
        let unit = AppSettings.shared.unit
        guard let vOff = psOff(tOff, unit), let vH = parseLen(tH, unit) else { return tr("tl.fixErr") }
        if let wl = c.wall(wall)?.len, Double(vOff) > wl { return tr("pt.offBig") }
        if vH > c.H { return tr("pt.hBig") }
        return nil
    }

    @ViewBuilder private func content(_ c: PCtx, _ old: PlPoint) -> some View {
        let err = errOf(c)
        let uw = unitWord(AppSettings.shared.unit)
        GlassSheet(tr("sx.o." + old.t), onClose: { app.sheet = nil }) {
            FlowLayout(spacing: 8) {
                ForEach(PT_KINDS, id: \.self) { k in FChip(label: tr("sx.o." + k), on: k == t) { t = k } }
            }
            if t == "drain" {
                FlowLayout(spacing: 8) {
                    ForEach([50, 110], id: \.self) { v in FChip(label: "Ø \(v)", on: d == v) { d = v } }
                }
            }
            T(tr("tl.fixWall"), ui(15, 700))
            PSWallChips(c: c, wall: wall) { wall = $0 }
            HStack(alignment: .top, spacing: 10) {
                GField(label: tr("el.f.off"), value: psLenText($tOff, 8), placeholder: "0", focus: $focus, me: "off", labelRight: uw, decimal: true)
                    .frame(maxWidth: .infinity)
                GField(label: tr("el.f.h"), value: psLenText($tH, 8), placeholder: "0", focus: $focus, me: "h", labelRight: uw, decimal: true)
                    .frame(maxWidth: .infinity)
            }
            if old.from != nil { T(tr("sx.fromMark"), ui(12.5, 400, G.ink2, lh: 1.4)) }
            T(tr("sx.ptDrag"), ui(12.5, 400, G.ink2, lh: 1.4))
            if let err { T(err, ui(13, 500, G.err)) }
        } footer: {
            GBtn(tr("common.save"), enabled: err == nil) { save(c, old) }.accessibilityIdentifier("sx.ptSave")
            GBtn(tr("common.delete"), kind: .secondary) { delete(old) }.accessibilityIdentifier("sx.ptDel")
        }
    }

    private func save(_ c: PCtx, _ old: PlPoint) {
        guard errOf(c) == nil, app.once() else { return }
        let unit = AppSettings.shared.unit
        guard let vOff = psOff(tOff, unit), let vH = parseLen(tH, unit) else { return }
        let nt = t, nw = wall
        let nd = t == "drain" ? d : 0
        updatePt(pid, old.id) { q in
            q.t = nt; q.wall = nw; q.off = vOff; q.h = vH; q.d = nd
        }
        app.sheet = nil; app.say("common.save")
    }

    private func delete(_ old: PlPoint) {
        guard let pts = Store.shared.get(pid)?.plumb.points, let at = pts.firstIndex(where: { $0.id == old.id }) else { return }
        let gone = pts[at], id = old.id, p0 = pid
        updatePlumb(p0) { e in e.points.removeAll { $0.id == id } }
        app.sheet = nil
        // Undo puts back only this outlet, where it was
        app.say("el.devDel", action: "common.undo") {
            updatePlumb(p0) { e in if !e.points.contains(where: { $0.id == gone.id }) { e.points = e.points.putBack(gone, at: at) } }
        }
    }
}

/* ---------------- a room's settings ---------------- */

private enum PSRF: Hashable { case link }

/// A room's settings: what room it is, its doors and the pipe between them, its underfloor heating, its radiators, the
/// riser here.
private struct PSRoomSetSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    @State private var tLink: String
    @FocusState private var focus: PSRF?
    init(app: AppModel, pid: String, rid: String) {
        self.app = app; self.pid = pid; self.rid = rid
        let s = AppSettings.shared
        let er = Store.shared.get(pid)?.plumb.room(rid) ?? PlRoom(roomId: rid)
        _tLink = State(initialValue: Geo.fmtField(er.link, s.unit, s.lang == .en))
    }
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        if let p = Store.shared.get(pid), let c = pCtxOf(p, rid, snap) {
            content(p, c, snap)
        }
    }

    @ViewBuilder private func content(_ p: Project, _ c: PCtx, _ snap: Bool) -> some View {
        let er = p.plumb.room(rid)
        let rs = liveRiser(p)
        let rc = rs.flatMap { pCtxOf(p, $0.roomId, snap) }
        GlassSheet(tr("el.roomSet"), onClose: { app.sheet = nil }) {
            T(tr("fr.type"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach(P_KINDS, id: \.self) { k in FChip(label: tr(pKindKey(k)), on: k == c.kind) { updatePRoom(pid, rid) { $0.kind = k } } }
            }
            if c.doors.count > 1 { doors(c) }
            if let rs, let rc, rs.roomId != rid { riserDoors(c, rc) }
            heat(p, c, er)
            buttons(p, c, rs)
        } footer: {
            GBtn(tr("common.save")) { save() }.accessibilityIdentifier("sx.roomSave")
        }
    }

    private func doors(_ c: PCtx) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            T(tr("sx.door"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach(Array(c.doors.enumerated()), id: \.offset) { i, o in
                    FChip(label: tr("el.doorN", ["i": i + 1, "w": o.wall]), on: c.entry?.id == o.id) { updatePRoom(pid, rid) { $0.door = o.id } }
                }
            }
        }
    }

    private func riserDoors(_ c: PCtx, _ rc: PCtx) -> some View {
        let cur = pExitDoor(rc, c)
        return VStack(alignment: .leading, spacing: 10) {
            if rc.doors.count > 1 {
                T(tr("sx.pdoor", ["r": dn(rc.room.name)]), ui(15, 700))
                FlowLayout(spacing: 8) {
                    ForEach(Array(rc.doors.enumerated()), id: \.offset) { i, o in
                        FChip(label: tr("el.doorN", ["i": i + 1, "w": o.wall]), on: cur?.id == o.id) { updatePRoom(pid, rid) { $0.pdoor = o.id } }
                    }
                }
            }
            GField(label: tr("sx.link"), value: psLenText($tLink, 7), placeholder: "1", focus: $focus, me: .link, labelRight: unitWord(AppSettings.shared.unit), decimal: true)
            T(tr("sx.linkS"), ui(12.5, 400, G.ink2, lh: 1.4))
        }
    }

    private func heat(_ p: Project, _ c: PCtx, _ er: PlRoom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            T(tr("sx.s.heat"), ui(15, 700))
            PSSwitchRow(title: tr("sx.s.ufh"), sub: tr("sx.s.ufhS"), on: er.ufh) { toggleUfh(p, c, er) }
            if er.ufh {
                FlowLayout(spacing: 8) {
                    ForEach([100, 150, 200], id: \.self) { v in
                        FChip(label: tr("sx.s.stepV", ["n": v / 10]), on: er.step == v) { updatePRoom(pid, rid) { $0.step = v } }
                    }
                }
            }
        }
    }

    private func toggleUfh(_ p: Project, _ c: PCtx, _ er: PlRoom) {
        let on = !er.ufh
        updatePRoom(pid, rid) { $0.ufh = on }
        if on && !p.plumb.fixes.contains(where: { $0.t == "manif" }) {
            let have = p.plumb.fixes.filter { $0.roomId == rid }
            if let m = placeFix("manif", c, have, p.plumb.riser, uid()) { updatePlumb(pid) { $0.fixes.append(m) } }
        }
    }

    @ViewBuilder private func buttons(_ p: Project, _ c: PCtx, _ rs: PlRiser?) -> some View {
        if !p.plumb.fixes.contains(where: { $0.roomId == rid && $0.t == "rad" }) {
            GBtn(tr("sx.radPut"), kind: .secondary, icon: "plus") { putRadiators(p, c, rs) }
        }
        if rs?.roomId != rid {
            GBtn(tr("sx.riserMove"), kind: .secondary, icon: "box") {
                var d = riserIn(c, p.plumb.fixes)
                d.hot = rs?.hot ?? true
                updatePlumb(pid) { $0.riser = d }
                app.sheet = nil; app.say("sx.riserSet")
            }
        }
        GBtn(tr("sx.marks"), kind: .secondary, icon: "pin") {
            let wid = c.g.walls.first?.id ?? "A"
            app.sheet = nil
            app.push(.wallView(pid: pid, rid: rid, wall: wid))
        }
        if p.plumb.fixes.contains(where: { $0.roomId == rid }) || p.plumb.points.contains(where: { $0.roomId == rid }) {
            GBtn(tr("sx.clear"), kind: .danger) { clear() }
        }
    }

    private func putRadiators(_ p: Project, _ c: PCtx, _ rs: PlRiser?) {
        let got = placeRadiators(c, p.plumb.fixes.filter { $0.roomId == rid }, rs, { uid() })
        if got.isEmpty { app.say("el.noSpace"); return }
        updatePlumb(pid) { $0.fixes += got }
        app.sheet = nil
        app.say("sx.radDone", ["n": got.count])
    }

    private func save() {
        if let v = parseLen(tLink, AppSettings.shared.unit) { updatePRoom(pid, rid) { $0.link = min(v, 100_000) } }
        app.sheet = nil; app.say("common.save")
    }

    private func clear() {
        guard let before = Store.shared.get(pid)?.plumb else { return }
        let p0 = pid, r0 = rid
        let fixes = before.fixes.filter { $0.roomId == r0 }
        let pts = before.points.filter { $0.roomId == r0 && $0.from == nil }
        let kits = before.room(r0).kits, ufh = before.room(r0).ufh
        updatePlumb(p0) { e in
            e.fixes.removeAll { $0.roomId == r0 }
            e.points.removeAll { $0.roomId == r0 && $0.from == nil }
            for i in e.rooms.indices where e.rooms[i].roomId == r0 { e.rooms[i].kits = []; e.rooms[i].ufh = false }
        }
        app.sheet = nil
        // Undo puts back only this room's fixtures, outlets, kits and underfloor heating
        app.say("el.cleared", action: "common.undo") {
            updatePlumb(p0) { e in
                let fb = fixes.filter { f in !e.fixes.contains { $0.id == f.id } }
                let pb = pts.filter { q in !e.points.contains { $0.id == q.id } }
                e.fixes += fb
                e.points += pb
                for i in e.rooms.indices where e.rooms[i].roomId == r0 { e.rooms[i].kits = kits; e.rooms[i].ufh = ufh }
            }
        }
    }
}

/* ---------------- the pipe system ---------------- */

private enum PSYF: Hashable { case wc, dr }

/// The order's pipe: the water system, how the water and the heating run, the riser's hot water, the rules' limits, the
/// spare.
private struct PSSystemSheet: View {
    let app: AppModel
    let pid: String
    @State private var tWc: String
    @State private var tDr: String
    @FocusState private var focus: PSYF?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        let s = AppSettings.shared
        let pl = Store.shared.get(pid)?.plumb ?? PlumbOrder()
        _tWc = State(initialValue: Geo.fmtField(pl.wcMax, s.unit, s.lang == .en))
        _tDr = State(initialValue: Geo.fmtField(pl.drainMax, s.unit, s.lang == .en))
    }
    var body: some View {
        if let p = Store.shared.get(pid) {
            let pl = p.plumb
            GlassSheet(tr("sx.system"), onClose: { app.sheet = nil }) {
                ForEach(WATERS, id: \.self) { w in
                    PSRadio(title: tr("sx.sys." + w), sub: tr("sx.sys." + w + "S"), on: pl.water == w) { updatePlumb(pid) { $0.water = w } }
                }
                T(tr("sx.runT"), ui(15, 700))
                FlowLayout(spacing: 8) {
                    ForEach(RUNS, id: \.self) { r in FChip(label: tr("sx.run." + r), on: pl.run == r) { updatePlumb(pid) { $0.run = r } } }
                }
                T(tr("sx.hrunT"), ui(15, 700))
                FlowLayout(spacing: 8) {
                    ForEach(RUNS, id: \.self) { r in FChip(label: tr("sx.run." + r), on: pl.hrun == r) { updatePlumb(pid) { $0.hrun = r } } }
                }
                if let rs = pl.riser {
                    PSSwitchRow(title: tr("sx.riserHot"), sub: tr("sx.riserHotS"), on: rs.hot) { updatePlumb(pid) { o in o.riser?.hot.toggle() } }
                }
                limits
                if AppSettings.shared.advanced { spare(pl) }
            } footer: {
                GBtn(tr("common.save")) { save() }.accessibilityIdentifier("sx.sysSave")
            }
        }
    }

    private var limits: some View {
        let uw = unitWord(AppSettings.shared.unit)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                GField(label: tr("sx.wcMax"), value: psLenText($tWc, 7), placeholder: "1", focus: $focus, me: .wc, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
                GField(label: tr("sx.drainMax"), value: psLenText($tDr, 7), placeholder: "3", focus: $focus, me: .dr, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
            }
            T(tr("sx.rulesS"), ui(12.5, 400, G.ink2, lh: 1.4))
        }
    }

    private func spare(_ pl: PlumbOrder) -> some View {
        let cur = pl.spare ?? PIPE_SPARE
        return VStack(alignment: .leading, spacing: 10) {
            T(tr("sx.spare"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach([5, 10, 15, 20], id: \.self) { v in FChip(label: "\(v) %", on: cur == v) { updatePlumb(pid) { $0.spare = v } } }
            }
        }
    }

    private func save() {
        let unit = AppSettings.shared.unit
        let a = parseLen(tWc, unit), b = parseLen(tDr, unit)
        updatePlumb(pid) { e in
            e.wcMax = eClampI(a ?? e.wcMax, 200, 20000)
            e.drainMax = eClampI(b ?? e.drainMax, 500, 50000)
        }
        app.sheet = nil; app.say("common.save")
    }
}

/// A choice with a title, a line under it and a round mark.
private struct PSRadio: View {
    let title: String
    let sub: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(on ? G.cobalt : G.ink.opacity(0.12)).frame(width: 20, height: 20)
                if on { Circle().fill(Color.white).frame(width: 8, height: 8) }
            }
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15, 700, on ? G.cobalt2 : G.ink))
                T(sub, ui(12.5, 400, G.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 60)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.75)))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

/* ---------------- the prices ---------------- */

/// One price of the plumber's: its key, unit, and how it is read from and written into the settings.
private struct PSPField {
    let key: String
    let unit: String
    let get: (TradeSet) -> String
    let set: (inout TradeSet, String) -> Void
}

private let PS_PRICE_FIELDS: [PSPField] = [
    PSPField(key: "pX20", unit: "/m", get: { $0.pX20 }, set: { t, v in t.pX20 = v }),
    PSPField(key: "pX25", unit: "/m", get: { $0.pX25 }, set: { t, v in t.pX25 = v }),
    PSPField(key: "pX32", unit: "/m", get: { $0.pX32 }, set: { t, v in t.pX32 = v }),
    PSPField(key: "pHeat", unit: "/m", get: { $0.pHeat }, set: { t, v in t.pHeat = v }),
    PSPField(key: "pUfh", unit: "/m", get: { $0.pUfh }, set: { t, v in t.pUfh = v }),
    PSPField(key: "pD50", unit: "/m", get: { $0.pD50 }, set: { t, v in t.pD50 = v }),
    PSPField(key: "pD110", unit: "/m", get: { $0.pD110 }, set: { t, v in t.pD110 = v }),
    PSPField(key: "pDBend", unit: "", get: { $0.pDBend }, set: { t, v in t.pDBend = v }),
    PSPField(key: "pDTee", unit: "", get: { $0.pDTee }, set: { t, v in t.pDTee = v }),
    PSPField(key: "pElbow", unit: "", get: { $0.pElbow }, set: { t, v in t.pElbow = v }),
    PSPField(key: "pTee", unit: "", get: { $0.pTee }, set: { t, v in t.pTee = v }),
    PSPField(key: "pCoup", unit: "", get: { $0.pCoup }, set: { t, v in t.pCoup = v }),
    PSPField(key: "pPlate", unit: "", get: { $0.pPlate }, set: { t, v in t.pPlate = v }),
    PSPField(key: "pBall", unit: "", get: { $0.pBall }, set: { t, v in t.pBall = v }),
    PSPField(key: "pMainV", unit: "", get: { $0.pMainV }, set: { t, v in t.pMainV = v }),
    PSPField(key: "pMeter", unit: "", get: { $0.pMeter }, set: { t, v in t.pMeter = v }),
    PSPField(key: "pFilter", unit: "", get: { $0.pFilter }, set: { t, v in t.pFilter = v }),
    PSPField(key: "pManif", unit: "", get: { $0.pManif }, set: { t, v in t.pManif = v }),
    PSPField(key: "lPPt", unit: "", get: { $0.lPPt }, set: { t, v in t.lPPt = v }),
    PSPField(key: "lPFix", unit: "", get: { $0.lPFix }, set: { t, v in t.lPFix = v }),
    PSPField(key: "lPM", unit: "/m", get: { $0.lPM }, set: { t, v in t.lPM = v }),
    PSPField(key: "lPRad", unit: "", get: { $0.lPRad }, set: { t, v in t.lPRad = v }),
    PSPField(key: "lPChase", unit: "/m", get: { $0.lPChase }, set: { t, v in t.lPChase = v })
]

/// The plumber's prices, one set for all orders: pipe, drains, fittings, valves, meters and the labour.
private struct PSPricesSheet: View {
    let app: AppModel
    let pid: String?
    @State private var texts: [String]
    @FocusState private var focus: String?
    init(app: AppModel, pid: String?) {
        self.app = app; self.pid = pid
        let t0 = AppSettings.shared.trade
        _texts = State(initialValue: PS_PRICE_FIELDS.map { $0.get(t0) })
    }
    var body: some View {
        GlassSheet(tr("tl.prices"), onClose: { app.sheet = nil }) {
            ForEach(Array(stride(from: 0, to: PS_PRICE_FIELDS.count, by: 2)), id: \.self) { i in
                HStack(alignment: .top, spacing: 10) {
                    field(i)
                    if i + 1 < PS_PRICE_FIELDS.count { field(i + 1) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
            T(tr("sx.pricesNote"), ui(12.5, 400, G.ink2, lh: 1.4))
        } footer: {
            GBtn(tr("common.save")) { save() }.accessibilityIdentifier("sx.pricesSave")
        }
    }
    private func field(_ i: Int) -> some View {
        let f = PS_PRICE_FIELDS[i]
        let text = Binding(get: { i < texts.count ? texts[i] : "" }, set: { v in
            if i < texts.count { texts[i] = String(v.filter { $0.isASCII && $0.isNumber }.prefix(12)) }
        })
        return GField(label: tr("sx.p." + f.key), value: text, placeholder: "0", focus: $focus, me: f.key, labelRight: f.unit.isEmpty ? nil : unitText(f.unit), number: true, id: "sxf." + f.key)
            .frame(maxWidth: .infinity)
    }
    private func save() {
        var t = AppSettings.shared.trade
        for (i, f) in PS_PRICE_FIELDS.enumerated() where i < texts.count {
            let v = texts[i].trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { f.set(&t, v) }
        }
        AppSettings.shared.setTradeSet(t)
        app.sheet = nil
        if let id = pid, let pr = Store.shared.get(id), madeBy(pr, "sx.e.") { applyPlumbRows(app, pr) }
        else { app.say("common.save") }
    }
}

/* ---------------- a room typed by size ---------------- */

private enum PSFF: Hashable { case name, l, w, h, link }

/// A room typed by size: its name and kind, length, width and height, how many of each fixture, the heating and the
/// pipe to the riser.
private struct PSFreeSheet: View {
    let app: AppModel
    let pid: String
    let fid: String?
    private let start: PlFree
    private let isNew: Bool
    @State private var kind: String
    @State private var name: String
    @State private var tl: String
    @State private var tw: String
    @State private var th: String
    @State private var tk: String
    @State private var cnt: [Int]
    @State private var ufh: Bool
    @State private var small: Bool
    @State private var cabin: Bool
    @FocusState private var focus: PSFF?
    private static let KEYS = ["wc", "bs", "bath", "sh", "sink", "wm", "dw", "wh", "gb", "rad", "tr"]

    init(app: AppModel, pid: String, fid: String?) {
        self.app = app; self.pid = pid; self.fid = fid
        let s = AppSettings.shared
        let en = s.lang == .en
        let old = fid.flatMap { id in Store.shared.get(pid)?.plumb.free.first { $0.id == id } }
        let st = old ?? PlFree(id: uid(), name: "@" + pKindKey("bath"), kind: "bath")
        start = st; isNew = old == nil
        _kind = State(initialValue: st.kind)
        // a kind's own name is kept as its key, so it follows the language
        _name = State(initialValue: dn(st.name))
        _tl = State(initialValue: Geo.fmtField(st.L, s.unit, en))
        _tw = State(initialValue: Geo.fmtField(st.W, s.unit, en))
        _th = State(initialValue: Geo.fmtField(st.H, s.unit, en))
        _tk = State(initialValue: Geo.fmtField(st.link, s.unit, en))
        // an older room shows the choices its kit made (towel rail, hand basin, cabin)
        let kit0 = pWithKit(st)
        _cnt = State(initialValue: [st.wc, st.basin, st.bath, st.shower, st.sink, st.wm, st.dw, st.wh, st.gb, st.rad, kit0.tr])
        _ufh = State(initialValue: st.ufh)
        _small = State(initialValue: kit0.small)
        _cabin = State(initialValue: kit0.cabin)
    }

    private func sizes() -> (Int, Int, Int, Int)? {
        let unit = AppSettings.shared.unit
        guard let L = parseLen(tl, unit), let W = parseLen(tw, unit), let H = parseLen(th, unit), let K = parseLen(tk, unit) else { return nil }
        if !(800...30000).contains(L) || !(800...30000).contains(W) || !(2000...6000).contains(H) { return nil }
        return (L, W, H, K)
    }

    var body: some View {
        let ok = sizes() != nil
        GlassSheet(tr(isNew ? "el.addFree" : "el.freeEdit"), onClose: { app.sheet = nil }) {
            T(tr("sx.freeB"), ui(13, 400, G.ink2, lh: 1.4))
            FlowLayout(spacing: 8) {
                ForEach(P_KINDS, id: \.self) { k in FChip(label: tr(pKindKey(k)), on: k == kind) { pickKind(k) } }
            }
            GField(label: tr("fr.name"), value: $name, placeholder: tr(pKindKey(kind)), focus: $focus, me: .name)
                .onChange(of: name) { _, n in if n.count > NAME_MAX { name = String(n.prefix(NAME_MAX)) } }
            dims
            ForEach(0..<PSFreeSheet.KEYS.count, id: \.self) { i in countRow(i) }
            PSSwitchRow(title: tr("sx.s.ufh"), on: ufh) { ufh.toggle() }
            GField(label: tr("sx.freeLink"), value: psLenText($tk, 7), placeholder: "3", focus: $focus, me: .link, labelRight: unitWord(AppSettings.shared.unit), decimal: true)
            if !ok { T(tr("sx.freeErr"), ui(13, 500, G.err)) }
        } footer: {
            GBtn(tr("common.save"), enabled: ok) { save() }.accessibilityIdentifier("sx.freeSave")
            if !isNew { GBtn(tr("common.delete"), kind: .secondary) { delete() }.accessibilityIdentifier("sx.freeDel") }
        }
    }

    private var dims: some View {
        let uw = unitWord(AppSettings.shared.unit)
        return HStack(alignment: .top, spacing: 8) {
            GField(label: tr("tl.pa"), value: psLenText($tl, 7), placeholder: "2,5", focus: $focus, me: .l, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
            GField(label: tr("tl.pbW"), value: psLenText($tw, 7), placeholder: "2", focus: $focus, me: .w, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
            GField(label: tr("tl.pbH"), value: psLenText($th, 7), placeholder: "2,7", focus: $focus, me: .h, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private func countRow(_ i: Int) -> some View {
        let k = PSFreeSheet.KEYS[i]
        HStack {
            T(tr("sx.t." + k), ui(15, 600)).frame(maxWidth: .infinity, alignment: .leading)
            EStepper(v: i < cnt.count ? cnt[i] : 0) { v in if i < cnt.count { cnt[i] = min(max(v, 0), 6) } }
        }
        .frame(minHeight: 52)
        // the basins as hand basins (cold only), the showers as cabins
        if k == "bs" && cnt.count > 1 && cnt[1] > 0 { PSSwitchRow(title: tr("sx.t.bsm"), on: small) { small.toggle() } }
        if k == "sh" && cnt.count > 3 && cnt[3] > 0 { PSSwitchRow(title: tr("sx.t.cab"), on: cabin) { cabin.toggle() } }
    }

    /// The name as stored: the start's own when unchanged, a kind's name as its key, a typed one as typed.
    private func keptName() -> String {
        let t = name.trimmingCharacters(in: .whitespaces)
        if t == dn(start.name) { return start.name }
        if t == tr(pKindKey(kind)) { return "@" + pKindKey(kind) }
        return t
    }

    private func pickKind(_ k: String) {
        if name.trimmingCharacters(in: .whitespaces).isEmpty || name == tr(pKindKey(kind)) { name = tr(pKindKey(k)) }
        kind = k
    }

    private func save() {
        guard let sz = sizes(), app.once() else { return }
        var f = start
        f.name = keptName(); f.kind = kind
        f.L = sz.0; f.W = sz.1; f.H = sz.2; f.link = sz.3
        if cnt.count >= 11 {
            f.wc = cnt[0]; f.basin = cnt[1]; f.bath = cnt[2]; f.shower = cnt[3]; f.sink = cnt[4]
            f.wm = cnt[5]; f.dw = cnt[6]; f.wh = cnt[7]; f.gb = cnt[8]; f.rad = cnt[9]; f.tr = cnt[10]
        }
        f.ufh = ufh; f.small = small; f.cabin = cabin; f.kept = true
        let fx = f, fresh = isNew, p0 = pid
        updatePlumb(p0) { e in
            if fresh { e.free.append(fx) } else if let i = e.free.firstIndex(where: { $0.id == fx.id }) { e.free[i] = fx }
        }
        app.sheet = nil
        if fresh { app.push(.pView(pid: p0, rid: "free:" + fx.id)) }
        app.say("common.save")
    }

    private func delete() {
        let id = start.id, p0 = pid
        updatePlumb(p0) { e in e.free.removeAll { $0.id == id } }
        app.sheet = nil
        app.popTo { if case .project(let pid, _, _, _) = $0 { return pid == p0 }; return false }
        app.say("el.freeDel")
    }
}
