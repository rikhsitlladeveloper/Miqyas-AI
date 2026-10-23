import SwiftUI

/*
 * The electrician's sheets (Android ui/elec/ElecScreens.kt, sheets part): a new room, a device (a new one's type, or a
 * placed one's type, wall, place, height, power and own line), a room's settings, how the cable runs, the prices, and a
 * room typed by size.
 */

struct ElecSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .eNewRoom, .eDev, .eRoomSet, .eMethod, .ePrices, .eFree: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .eNewRoom(let pid): ENewRoomSheet(app: app, pid: pid)
        case .eDev(let pid, let rid, let did, let wall):
            if did == nil { EDevNewSheet(app: app, pid: pid, rid: rid, wall: wall) } else { EDevEditSheet(app: app, pid: pid, rid: rid, did: did ?? "") }
        case .eRoomSet(let pid, let rid): ERoomSetSheet(app: app, pid: pid, rid: rid)
        case .eMethod(let pid): EMethodSheet(app: app, pid: pid)
        case .ePrices(let pid): EPricesSheet(app: app, pid: pid)
        case .eFree(let pid, let fid): EFreeSheet(app: app, pid: pid, fid: fid)
        default: EmptyView()
        }
    }
}

/// Keeps what can be typed in a length field: digits and one decimal mark, at most n characters.
private func lenText(_ b: Binding<String>, _ n: Int) -> Binding<String> {
    Binding(get: { b.wrappedValue }, set: { v in b.wrappedValue = String(v.filter { $0.isASCII && ($0.isNumber || $0 == "," || $0 == ".") }.prefix(n)) })
}

private func digitText(_ b: Binding<String>, _ n: Int) -> Binding<String> {
    Binding(get: { b.wrappedValue }, set: { v in b.wrappedValue = String(v.filter { $0.isASCII && $0.isNumber }.prefix(n)) })
}

/* ---------------- a new room ---------------- */

private enum ENF: Hashable { case name }

private struct ENewRoomSheet: View {
    let app: AppModel
    let pid: String
    @State private var kind: String
    @State private var name: String
    @FocusState private var focus: ENF?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        let p = Store.shared.get(pid)
        let k = (p?.floors.isEmpty ?? true) ? "hall" : "kitchen"
        _kind = State(initialValue: k)
        _name = State(initialValue: ENewRoomSheet.nameFor(k, p))
    }
    static func nameFor(_ k: String, _ p: Project?) -> String {
        guard let p else { return tr(eKindKey(k)) }
        return nextName(p, eKindKey(k))
    }
    var body: some View {
        let p = Store.shared.get(pid)
        GlassSheet(tr("fo.addRoom"), onClose: { app.sheet = nil }) {
            T(tr("fr.type"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach(KINDS, id: \.self) { k in FChip(label: tr(eKindKey(k)), on: k == kind) { kind = k; name = ENewRoomSheet.nameFor(k, p) } }
            }
            let blank = name.trimmingCharacters(in: .whitespaces).isEmpty
            GField(label: tr("fr.name"), value: $name, placeholder: tr(eKindKey(kind)), error: blank ? tr("nr.nameReq") : nil, showError: true,
                   focus: $focus, me: .name, submit: .done, onSubmit: create)
        } footer: {
            GBtn(tr("fo.drawRoom"), enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, create).accessibilityIdentifier("el.roomCreate")
        }
        .onChange(of: name) { _, n in if n.count > NAME_MAX { name = String(n.prefix(NAME_MAX)) } }
    }
    private func create() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, app.once() else { return }
        // a suggested name is kept as its key, so it follows the language
        let rid = addElecRoom(pid, kind, suggestedName(n, eKindKey(kind)))
        app.sheet = nil
        openRoom(app, pid, rid)
    }
}

/* ---------------- a device ---------------- */

/// A new device: pick its type, then it goes on the wall shown.
private struct EDevNewSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let wall: String?
    @State private var cat = "sock"
    var body: some View {
        if let p = Store.shared.get(pid), let c = ctxOf(p, rid, AppSettings.shared.angleSnap) {
            GlassSheet(tr("el.addDev"), onClose: { app.sheet = nil }) {
                FlowLayout(spacing: 8) {
                    ForEach(CATS, id: \.self) { k in FChip(label: tr("el.cat." + k), on: k == cat) { cat = k } }
                }
                ForEach(DEV_TYPES.filter { $0.cat == cat }.map(\.id), id: \.self) { tid in row(p, c, tid) }
            }
        }
    }
    private func row(_ p: Project, _ c: ECtx, _ tid: String) -> some View {
        let ty = devType(tid)
        let sub = ty.ceil ? tr("el.onCeil") : tr("el.atH", ["h": Geo.fmtLen(usualH(tid, c.H, c.kind), .m, AppSettings.shared.lang == .en)])
        let rgb = groupDef(ty.group.isEmpty ? "low" : ty.group).rgb
        return HStack(spacing: 12) {
            DevSymbolView(t: tid, rgb: rgb, k: 3.2).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                T(tr("el.t." + tid), ui(15, 700))
                T(sub, ui(12.5, 400, G.ink2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.7)))
        .pressable(0.98) { add(p, c, tid) }
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("el.dev." + tid)
    }
    private func add(_ p: Project, _ c: ECtx, _ tid: String) {
        guard app.once() else { return }
        guard let d = newDev(c, p, tid, wall) else { app.say("el.noSpace"); return }
        updateElec(p.id) { $0.devs.append(d) }
        app.sheet = nil
        app.say("el.devAdded", ["n": tr("el.t." + tid)])
    }
}

private enum EDF: Hashable { case off, h, len, w }

/// A placed device: its type, wall, place, height, power and own line.
private struct EDevEditSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let did: String
    @State private var t: String
    @State private var wall: String?
    @State private var tOff: String
    @State private var tH: String
    @State private var tLen: String
    @State private var tW: String
    @State private var own: Bool
    @FocusState private var focus: EDF?

    init(app: AppModel, pid: String, rid: String, did: String) {
        self.app = app; self.pid = pid; self.rid = rid; self.did = did
        let s = AppSettings.shared
        let en = s.lang == .en
        let old = Store.shared.get(pid)?.elec.devs.first { $0.id == did } ?? ElecDev(id: did, t: "s1", roomId: rid)
        _t = State(initialValue: old.t)
        _wall = State(initialValue: old.wall)
        _tOff = State(initialValue: Geo.fmtField(old.onCeiling ? old.cx : old.off, s.unit, en))
        _tH = State(initialValue: Geo.fmtField(old.onCeiling ? old.cy : old.h, s.unit, en))
        _tLen = State(initialValue: old.len > 0 ? Geo.fmtField(old.len, s.unit, en) : "")
        _tW = State(initialValue: old.w > 0 ? "\(old.w)" : "")
        _own = State(initialValue: old.own)
    }

    var body: some View {
        let snap = AppSettings.shared.angleSnap
        if let p = Store.shared.get(pid), let c = ctxOf(p, rid, snap), let old = p.elec.devs.first(where: { $0.id == did }) {
            content(p, c, old)
        }
    }

    private func vals(_ old: ElecDev) -> (Int?, Int?, Int?) {
        let unit = AppSettings.shared.unit
        let vOff: Int? = tOff.trimmingCharacters(in: .whitespaces).isEmpty ? nil : Geo.parseDec(tOff, Geo.unitDecimals(unit)).value.map { Int($0) }
        let vH = parseLen(tH, unit)
        let vLen: Int? = old.t == "led" ? parseLen(tLen, unit) : 0
        return (vOff, vH, vLen)
    }

    private func errOf(_ c: ECtx, _ old: ElecDev) -> String? {
        let (vOff, vH, vLen) = vals(old)
        guard let vOff, let vH, vLen != nil else { return tr("tl.fixErr") }
        if !old.onCeiling, let wl = c.wall(wall)?.len, Double(vOff) > wl { return tr("pt.offBig") }
        if !old.onCeiling && vH > c.H { return tr("pt.hBig") }
        return nil
    }

    @ViewBuilder private func content(_ p: Project, _ c: ECtx, _ old: ElecDev) -> some View {
        let unit = AppSettings.shared.unit
        let uw = unitWord(unit)
        let ty = devType(old.t)
        let err = errOf(c, old)
        let defW: Int = { var x = old; x.w = 0; return watts(x) }()
        let kinds = DEV_TYPES.filter { $0.cat == ty.cat && $0.ceil == ty.ceil && ($0.id == "led") == (old.t == "led") }.map(\.id)
        GlassSheet(tr("el.t." + old.t), onClose: { app.sheet = nil }) {
            FlowLayout(spacing: 8) {
                ForEach(kinds, id: \.self) { x in FChip(label: tr("el.t." + x), on: x == t) { t = x } }
            }
            if !old.onCeiling {
                T(tr("tl.fixWall"), ui(15, 700))
                FlowLayout(spacing: 8) {
                    ForEach(c.g.walls.map(\.id), id: \.self) { id in FChip(label: tr("tl.wallN", ["w": id]), on: id == wall) { wall = id } }
                }
            }
            HStack(alignment: .top, spacing: 10) {
                GField(label: tr(old.onCeiling ? "el.f.x" : "el.f.off"), value: lenText($tOff, 8), placeholder: "0", focus: $focus, me: .off, labelRight: uw, decimal: true)
                    .frame(maxWidth: .infinity)
                GField(label: tr(old.onCeiling ? "el.f.y" : "el.f.h"), value: lenText($tH, 8), placeholder: "0", focus: $focus, me: .h, labelRight: uw, decimal: true)
                    .frame(maxWidth: .infinity)
            }
            if old.t == "led" {
                GField(label: tr("el.f.len"), value: lenText($tLen, 8), placeholder: "2", focus: $focus, me: .len, labelRight: uw, decimal: true)
            }
            if ty.cat != "low" && ty.cat != "box" {
                GField(label: tr("el.f.w"), value: digitText($tW, 5), placeholder: "\(defW)", focus: $focus, me: .w, labelRight: "W", number: true)
            }
            if ty.cat == "sock" { ownRow }
            if !old.onCeiling { T(tr("el.dragHint"), ui(12.5, 400, G.ink2, lh: 1.4)) }
            if let err { T(err, ui(13, 500, G.err)) }
        } footer: {
            GBtn(tr("common.save"), enabled: err == nil) { save(c, old) }.accessibilityIdentifier("el.devSave")
            GBtn(tr("common.delete"), kind: .secondary) { delete(old) }.accessibilityIdentifier("el.devDel")
        }
    }

    private var ownRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                T(tr("el.own"), ui(15, 700))
                T(tr("el.ownS"), ui(12, 400, G.ink2, lh: 1.3))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GSwitch(on: own)
        }
        .padding(.horizontal, 14).frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.7)))
        .pressable(0.98) { own.toggle() }
        .accessibilityAddTraits(.isButton)
    }

    private func save(_ c: ECtx, _ old: ElecDev) {
        guard errOf(c, old) == nil, app.once() else { return }
        let (vOff0, vH0, vLen0) = vals(old)
        guard let vOff = vOff0, let vH = vH0 else { return }
        let newT = t, newWall = wall, wv = Int(tW) ?? 0
        let isSock = devType(old.t).cat == "sock"
        let ownV = own && isSock
        updateDev(pid, old.id) { d in
            let onC = d.onCeiling
            d.t = newT
            d.wall = onC ? nil : newWall
            if onC { d.cx = vOff; d.cy = vH } else { d.off = vOff; d.h = vH }
            if let l = vLen0 { d.len = l }
            d.w = wv
            d.own = ownV
        }
        app.sheet = nil; app.say("common.save")
    }

    private func delete(_ old: ElecDev) {
        guard let devs = Store.shared.get(pid)?.elec.devs, let at = devs.firstIndex(where: { $0.id == old.id }) else { return }
        let gone = devs[at], id = old.id, p0 = pid
        updateElec(p0) { e in e.devs.removeAll { $0.id == id } }
        app.sheet = nil
        // Undo puts back only this device, where it was
        app.say("el.devDel", action: "common.undo") {
            updateElec(p0) { e in if !e.devs.contains(where: { $0.id == gone.id }) { e.devs = e.devs.putBack(gone, at: at) } }
        }
    }
}

/* ---------------- a room's settings ---------------- */

private enum ERF: Hashable { case link }

/// A room's settings: what room it is, the door its cable comes in by, the panel's room's door it leaves by and the cable
/// between them.
private struct ERoomSetSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    @State private var tLink: String
    @FocusState private var focus: ERF?
    init(app: AppModel, pid: String, rid: String) {
        self.app = app; self.pid = pid; self.rid = rid
        let s = AppSettings.shared
        let er = Store.shared.get(pid)?.elec.room(rid) ?? ElecRoom(roomId: rid)
        _tLink = State(initialValue: Geo.fmtField(er.link, s.unit, s.lang == .en))
    }
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        if let p = Store.shared.get(pid), let c = ctxOf(p, rid, snap) {
            content(p, c, snap)
        }
    }
    @ViewBuilder private func content(_ p: Project, _ c: ECtx, _ snap: Bool) -> some View {
        let er = p.elec.room(rid)
        let pn = livePanel(p)
        let pc = pn.flatMap { ctxOf(p, $0.roomId, snap) }
        let unit = AppSettings.shared.unit
        GlassSheet(tr("el.roomSet"), onClose: { app.sheet = nil }) {
            T(tr("fr.type"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach(KINDS, id: \.self) { k in FChip(label: tr(eKindKey(k)), on: k == c.kind) { updateERoom(pid, rid) { $0.kind = k } } }
            }
            if c.doors.count > 1 {
                T(tr("el.door"), ui(15, 700))
                FlowLayout(spacing: 8) {
                    ForEach(Array(c.doors.enumerated()), id: \.offset) { i, o in
                        FChip(label: tr("el.doorN", ["i": i + 1, "w": o.wall]), on: c.entry?.id == o.id) { updateERoom(pid, rid) { $0.door = o.id } }
                    }
                }
            }
            if let pn, let pc, pn.roomId != rid {
                if pc.doors.count > 1 {
                    let cur = exitDoor(pc, pn, er)
                    T(tr("el.pdoor", ["r": dn(pc.room.name)]), ui(15, 700))
                    FlowLayout(spacing: 8) {
                        ForEach(Array(pc.doors.enumerated()), id: \.offset) { i, o in
                            FChip(label: tr("el.doorN", ["i": i + 1, "w": o.wall]), on: cur?.id == o.id) { updateERoom(pid, rid) { $0.pdoor = o.id } }
                        }
                    }
                }
                GField(label: tr("el.link"), value: lenText($tLink, 7), placeholder: "1", focus: $focus, me: .link, labelRight: unitWord(unit), decimal: true)
                T(tr("el.linkS"), ui(12.5, 400, G.ink2, lh: 1.4))
            }
            if pn?.roomId != rid {
                GBtn(tr("el.panelMove"), kind: .secondary, icon: "box") {
                    let d = panelIn(c, p.elec.devs.filter { $0.roomId == rid })
                    updateElec(pid) { $0.panel = d }
                    app.sheet = nil; app.say("el.panelSet")
                }
            }
            GBtn(tr("el.marks"), kind: .secondary, icon: "pin") {
                let wid = c.g.walls.first?.id ?? "A"
                app.sheet = nil
                app.push(.wallView(pid: pid, rid: rid, wall: wid))
            }
            if p.elec.devs.contains(where: { $0.roomId == rid }) {
                GBtn(tr("el.clear"), kind: .danger) { clear() }
            }
        } footer: {
            GBtn(tr("common.save")) { save() }.accessibilityIdentifier("el.roomSave")
        }
    }
    private func save() {
        if let v = parseLen(tLink, AppSettings.shared.unit) { updateERoom(pid, rid) { $0.link = min(v, 100_000) } }
        app.sheet = nil; app.say("common.save")
    }
    private func clear() {
        guard let before = Store.shared.get(pid)?.elec else { return }
        let p0 = pid, r0 = rid
        let devs = before.devs.filter { $0.roomId == r0 }, kits = before.room(r0).kits
        updateElec(p0) { e in
            e.devs.removeAll { $0.roomId == r0 }
            for i in e.rooms.indices where e.rooms[i].roomId == r0 { e.rooms[i].kits = [] }
        }
        app.sheet = nil
        // Undo puts back only this room's devices and kits
        app.say("el.cleared", action: "common.undo") {
            updateElec(p0) { e in
                let back = devs.filter { d in !e.devs.contains { $0.id == d.id } }
                e.devs += back
                for i in e.rooms.indices where e.rooms[i].roomId == r0 { e.rooms[i].kits = kits }
            }
        }
    }
}

/* ---------------- how the cable runs ---------------- */

/// How the cable runs in the order: in wall chases, in corrugated pipe over the ceiling, or in a surface channel; the spare.
private struct EMethodSheet: View {
    let app: AppModel
    let pid: String
    var body: some View {
        if let p = Store.shared.get(pid) {
            let spare = p.elec.spare ?? CABLE_SPARE
            GlassSheet(tr("el.method"), onClose: { app.sheet = nil }) {
                ForEach(METHODS, id: \.self) { m in row(m, p.elec.method == m) }
                if AppSettings.shared.advanced {
                    T(tr("el.spare"), ui(15, 700))
                    FlowLayout(spacing: 8) {
                        ForEach([5, 10, 15, 20], id: \.self) { v in FChip(label: "\(v) %", on: spare == v) { updateElec(pid) { $0.spare = v } } }
                    }
                }
            }
        }
    }
    private func row(_ m: String, _ on: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 10) {
            ZStack {
                Circle().fill(on ? G.cobalt : G.ink.opacity(0.12)).frame(width: 20, height: 20)
                if on { Circle().fill(Color.white).frame(width: 8, height: 8) }
            }
            VStack(alignment: .leading, spacing: 1) {
                T(tr("el.m." + m), ui(15, 700, on ? G.cobalt2 : G.ink))
                T(tr("el.m." + m + "S"), ui(12.5, 400, G.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 60)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.75)))
        .pressable(0.98) { updateElec(pid) { $0.method = m } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("el.m." + m)
    }
}

/* ---------------- the prices ---------------- */

/// One price of the electrician's: its key, unit, and how it is read from and written into the settings.
private struct EPField {
    let key: String
    let unit: String
    let get: (TradeSet) -> String
    let set: (inout TradeSet, String) -> Void
}

private let E_PRICE_FIELDS: [EPField] = [
    EPField(key: "pCab15", unit: "/m", get: { $0.pCab15 }, set: { t, v in t.pCab15 = v }),
    EPField(key: "pCable", unit: "/m", get: { $0.pCable }, set: { t, v in t.pCable = v }),
    EPField(key: "pCab6", unit: "/m", get: { $0.pCab6 }, set: { t, v in t.pCab6 = v }),
    EPField(key: "pUtp", unit: "/m", get: { $0.pUtp }, set: { t, v in t.pUtp = v }),
    EPField(key: "pSocket", unit: "", get: { $0.pSocket }, set: { t, v in t.pSocket = v }),
    EPField(key: "pSwitch", unit: "", get: { $0.pSwitch }, set: { t, v in t.pSwitch = v }),
    EPField(key: "pLight", unit: "", get: { $0.pLight }, set: { t, v in t.pLight = v }),
    EPField(key: "pLow", unit: "", get: { $0.pLow }, set: { t, v in t.pLow = v }),
    EPField(key: "pBox", unit: "", get: { $0.pBox }, set: { t, v in t.pBox = v }),
    EPField(key: "pJBox", unit: "", get: { $0.pJBox }, set: { t, v in t.pJBox = v }),
    EPField(key: "pBreaker", unit: "", get: { $0.pBreaker }, set: { t, v in t.pBreaker = v }),
    EPField(key: "pRcd", unit: "", get: { $0.pRcd }, set: { t, v in t.pRcd = v }),
    EPField(key: "pMain", unit: "", get: { $0.pMain }, set: { t, v in t.pMain = v }),
    EPField(key: "pPanelM", unit: "", get: { $0.pPanelM }, set: { t, v in t.pPanelM = v }),
    EPField(key: "pConduit", unit: "/m", get: { $0.pConduit }, set: { t, v in t.pConduit = v }),
    EPField(key: "pChan", unit: "/m", get: { $0.pChan }, set: { t, v in t.pChan = v }),
    EPField(key: "lPoint", unit: "", get: { $0.lPoint }, set: { t, v in t.lPoint = v }),
    EPField(key: "lChase", unit: "/m", get: { $0.lChase }, set: { t, v in t.lChase = v }),
    EPField(key: "lMetre", unit: "/m", get: { $0.lMetre }, set: { t, v in t.lMetre = v }),
    EPField(key: "lPanel", unit: "", get: { $0.lPanel }, set: { t, v in t.lPanel = v })
]

/// The electrician's prices, one set for all orders: cable, devices, boxes, breakers, the panel and the labour.
private struct EPricesSheet: View {
    let app: AppModel
    let pid: String?
    @State private var texts: [String]
    @FocusState private var focus: String?
    init(app: AppModel, pid: String?) {
        self.app = app; self.pid = pid
        let t0 = AppSettings.shared.trade
        _texts = State(initialValue: E_PRICE_FIELDS.map { $0.get(t0) })
    }
    var body: some View {
        GlassSheet(tr("tl.prices"), onClose: { app.sheet = nil }) {
            ForEach(Array(stride(from: 0, to: E_PRICE_FIELDS.count, by: 2)), id: \.self) { i in
                HStack(alignment: .top, spacing: 10) {
                    field(i)
                    if i + 1 < E_PRICE_FIELDS.count { field(i + 1) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
            T(tr("el.pricesNote"), ui(12.5, 400, G.ink2, lh: 1.4))
        } footer: {
            GBtn(tr("common.save")) { save() }.accessibilityIdentifier("el.pricesSave")
        }
    }
    private func field(_ i: Int) -> some View {
        let f = E_PRICE_FIELDS[i]
        let text = Binding(get: { i < texts.count ? texts[i] : "" }, set: { v in
            if i < texts.count { texts[i] = String(v.filter { $0.isASCII && $0.isNumber }.prefix(12)) }
        })
        return GField(label: tr("el.p." + f.key), value: text, placeholder: "0", focus: $focus, me: f.key, labelRight: f.unit.isEmpty ? nil : unitText(f.unit), number: true, id: "elf." + f.key)
            .frame(maxWidth: .infinity)
    }
    private func save() {
        var t = AppSettings.shared.trade
        for (i, f) in E_PRICE_FIELDS.enumerated() where i < texts.count {
            let v = texts[i].trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { f.set(&t, v) }
        }
        AppSettings.shared.setTradeSet(t)
        app.sheet = nil
        if let id = pid, let pr = Store.shared.get(id), madeBy(pr, "el.e.") { applyElecRows(app, pr) }
        else { app.say("common.save") }
    }
}

/* ---------------- a room typed by size ---------------- */

private enum EFF: Hashable { case name, l, w, h, link }

/// A room typed by size: its name and kind, length, width and height, and how many points of each kind.
private struct EFreeSheet: View {
    let app: AppModel
    let pid: String
    let fid: String?
    private let start: ElecFree
    private let isNew: Bool
    @State private var kind: String
    @State private var name: String
    @State private var tl: String
    @State private var tw: String
    @State private var th: String
    @State private var tk: String
    @State private var cnt: [Int]
    @FocusState private var focus: EFF?
    private static let KEYS = ["sock", "sw", "light", "low", "power"]

    init(app: AppModel, pid: String, fid: String?) {
        self.app = app; self.pid = pid; self.fid = fid
        let s = AppSettings.shared
        let en = s.lang == .en
        let old = fid.flatMap { id in Store.shared.get(pid)?.elec.free.first { $0.id == id } }
        let st = old ?? ElecFree(id: uid(), name: "@" + eKindKey("bed"), kind: "bed")
        start = st; isNew = old == nil
        _kind = State(initialValue: st.kind)
        // a kind's own name is kept as its key, so it follows the language
        _name = State(initialValue: dn(st.name))
        _tl = State(initialValue: Geo.fmtField(st.L, s.unit, en))
        _tw = State(initialValue: Geo.fmtField(st.W, s.unit, en))
        _th = State(initialValue: Geo.fmtField(st.H, s.unit, en))
        _tk = State(initialValue: Geo.fmtField(st.link, s.unit, en))
        _cnt = State(initialValue: [st.sock, st.sw, st.light, st.low, st.power])
    }

    private func sizes() -> (Int, Int, Int, Int)? {
        let unit = AppSettings.shared.unit
        guard let L = parseLen(tl, unit), let W = parseLen(tw, unit), let H = parseLen(th, unit), let K = parseLen(tk, unit) else { return nil }
        if !(1000...30000).contains(L) || !(1000...30000).contains(W) || !(2000...6000).contains(H) { return nil }
        return (L, W, H, K)
    }

    var body: some View {
        let unit = AppSettings.shared.unit
        let uw = unitWord(unit)
        let ok = sizes() != nil
        GlassSheet(tr(isNew ? "el.addFree" : "el.freeEdit"), onClose: { app.sheet = nil }) {
            T(tr("el.freeB"), ui(13, 400, G.ink2, lh: 1.4))
            FlowLayout(spacing: 8) {
                ForEach(KINDS, id: \.self) { k in FChip(label: tr(eKindKey(k)), on: k == kind) { pickKind(k) } }
            }
            GField(label: tr("fr.name"), value: $name, placeholder: tr(eKindKey(kind)), focus: $focus, me: .name)
                .onChange(of: name) { _, n in if n.count > NAME_MAX { name = String(n.prefix(NAME_MAX)) } }
            HStack(alignment: .top, spacing: 8) {
                GField(label: tr("tl.pa"), value: lenText($tl, 7), placeholder: "4", focus: $focus, me: .l, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
                GField(label: tr("tl.pbW"), value: lenText($tw, 7), placeholder: "3", focus: $focus, me: .w, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
                GField(label: tr("tl.pbH"), value: lenText($th, 7), placeholder: "2,7", focus: $focus, me: .h, labelRight: uw, decimal: true).frame(maxWidth: .infinity)
            }
            ForEach(0..<EFreeSheet.KEYS.count, id: \.self) { i in
                HStack {
                    T(tr("el.fc." + EFreeSheet.KEYS[i]), ui(15, 600)).frame(maxWidth: .infinity, alignment: .leading)
                    EStepper(v: i < cnt.count ? cnt[i] : 0) { v in if i < cnt.count { cnt[i] = min(max(v, 0), 40) } }
                }
                .frame(minHeight: 52)
            }
            GField(label: tr("el.link"), value: lenText($tk, 7), placeholder: "4", focus: $focus, me: .link, labelRight: uw, decimal: true)
            if !ok { T(tr("el.freeErr"), ui(13, 500, G.err)) }
        } footer: {
            GBtn(tr("common.save"), enabled: ok) { save() }.accessibilityIdentifier("el.freeSave")
            if !isNew { GBtn(tr("common.delete"), kind: .secondary) { delete() }.accessibilityIdentifier("el.freeDel") }
        }
    }

    /// The name as stored: the start's own when unchanged, a kind's name as its key, a typed one as typed.
    private func keptName() -> String {
        let t = name.trimmingCharacters(in: .whitespaces)
        if t == dn(start.name) { return start.name }
        if t == tr(eKindKey(kind)) { return "@" + eKindKey(kind) }
        return t
    }

    private func pickKind(_ k: String) {
        if name.trimmingCharacters(in: .whitespaces).isEmpty || name == tr(eKindKey(kind)) { name = tr(eKindKey(k)) }
        kind = k
    }

    private func save() {
        guard let sz = sizes(), app.once() else { return }
        var f = start
        f.name = keptName(); f.kind = kind
        f.L = sz.0; f.W = sz.1; f.H = sz.2; f.link = sz.3
        if cnt.count >= 5 { f.sock = cnt[0]; f.sw = cnt[1]; f.light = cnt[2]; f.low = cnt[3]; f.power = cnt[4] }
        let fx = f, fresh = isNew, p0 = pid
        updateElec(p0) { e in
            if fresh { e.free.append(fx) } else if let i = e.free.firstIndex(where: { $0.id == fx.id }) { e.free[i] = fx }
        }
        app.sheet = nil
        if fresh { app.push(.eView(pid: p0, rid: "free:" + fx.id)) }
        app.say("common.save")
    }

    private func delete() {
        let id = start.id, p0 = pid
        updateElec(p0) { e in e.free.removeAll { $0.id == id } }
        app.sheet = nil
        app.popTo { if case .project(let pid, _, _, _) = $0 { return pid == p0 }; return false }
        app.say("el.freeDel")
    }
}

/// − n + : a count typed with two buttons.
struct EStepper: View {
    let v: Int
    let onSet: (Int) -> Void
    var body: some View {
        HStack(spacing: 6) {
            T("−", ui(20, 700)).frame(width: 44, height: 44).background(Circle().fill(G.ink.opacity(0.06)))
                .pressable(0.95, label: "−") { onSet(v - 1) }
            T("\(v)", num(17, 800), align: .center).frame(minWidth: 28)
            MIcon("plus", G.ink, 18, 2.2).frame(width: 44, height: 44).background(Circle().fill(G.ink.opacity(0.06)))
                .pressable(0.95, label: "+") { onSet(v + 1) }
        }
    }
}
