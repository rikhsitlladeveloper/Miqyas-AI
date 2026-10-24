import SwiftUI

/// The room editor's sheets (Android EditorSheets.kt).
struct EditorSheet: View {
    let app: AppModel
    let sheet: Sheet
    var body: some View {
        switch sheet {
        case .newRoom(let pid, let wid): NewRoomSheet(app: app, pid: pid, wid: wid)
        case .measure(let pid, let rid, let k): MeasureSheet(app: app, pid: pid, rid: rid, k: k)
        case .addOpening(let pid, let rid): AddOpeningSheet(app: app, pid: pid, rid: rid)
        case .openingForm(let pid, let rid, let oid, let type, let wall): OpeningSheet(app: app, pid: pid, rid: rid, oid: oid, type0: type, wall0: wall)
        case .featureForm(let pid, let rid, let fid, let type): FeatureSheet(app: app, pid: pid, rid: rid, fid: fid, type0: type)
        case .roomInfo(let pid, let rid): RoomInfoSheet(app: app, pid: pid, rid: rid)
        case .roomRename(let pid, let rid): RenameSheet(app: app, pid: pid, rid: rid)
        case .tray(let pid, let rid): TraySheet(app: app, pid: pid, rid: rid)
        case .roomMenu(let pid, let rid): RoomMenuSheet(app: app, pid: pid, rid: rid)
        case .roomMove(let pid, let rid): RoomMoveSheet(app: app, pid: pid, rid: rid)
        case .wallAdd(let pid, let rid, let wall): WallAddSheet(app: app, pid: pid, rid: rid, wall: wall)
        default: EmptyView()
        }
    }
    static func handles(_ s: Sheet) -> Bool {
        switch s {
        case .newRoom, .measure, .addOpening, .openingForm, .featureForm, .roomInfo, .roomRename, .tray, .roomMenu, .roomMove, .wallAdd: return true
        default: return false
        }
    }
}

/// A number field like the prototype's .box.num: condensed 19/600 digits, a unit after them, the phone's decimal keys.
struct NumField<F: Hashable>: View {
    let label: String?
    @Binding var value: String
    let suffix: String
    let error: String?
    let showError: Bool
    let focus: FocusState<F?>.Binding
    let me: F
    var id: String? = nil

    var body: some View {
        let focused = focus.wrappedValue == me
        let bad = showError && error != nil
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            if let label { T(label, ui(15, 700), lines: 2) }
            HStack(spacing: 6) {
                TextField("", text: $value)
                    .font(num(19, 600).font).foregroundColor(G.ink)
                    .keyboardType(.decimalPad)
                    .focused(focus, equals: me)
                    .padding(.vertical, 10)
                    .accessibilityLabel(label ?? suffix)
                    .accessibilityIdentifier(id ?? "num")
                T(suffix, ui(15, 400, G.ink2))
            }
            .padding(.horizontal, 17)
            .frame(minHeight: 56)
            .background(shape.fill(G.glass(0.6)))
            .overlay(shape.strokeBorder(bad ? G.err : focused ? G.cobalt : G.rim, lineWidth: focused || bad ? 2 : 1))
            .background(shape.inset(by: -2).stroke(focused ? (bad ? G.err : G.cobalt).opacity(0.12) : .clear, lineWidth: 4))
            .contentShape(shape)
            .onTapGesture { focus.wrappedValue = me }
            if bad, let error {
                HStack(alignment: .top, spacing: 6) { MIcon("alert", G.err, 18, 2); T(error, ui(13.5, 500, G.err)) }
            }
        }
    }
}

private func close() { AppModel.shared.sheet = nil }

private struct Warn: View {
    let icon: String
    let text: String
    var red = false
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            MIcon(icon, red ? G.err : PC.amber, 18, 2)
            T(text, ui(13.5, 500, red ? G.err : PC.amber, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(red ? G.errWash : G.amberWash))
    }
}

private struct Note: View {
    let text: String
    var body: some View { HStack(alignment: .top, spacing: 8) { MIcon("info", G.ink2, 17, 2); T(text, ui(13, 400, G.ink2, lh: 1.4)) } }
}

/* ---------------- a new room: name and shape (prototype SHEETS.newRoom) ---------------- */

private enum NF: Hashable { case name }

/// The longest name a room, a workspace or a product takes: a longer one does not fit the plan, the cards or the PDF.
let NAME_MAX = 40

private struct NewRoomSheet: View {
    let app: AppModel
    let pid: String
    let wid: String
    @State private var name = ""
    @State private var loaded = false
    @State private var roomN = 1
    @FocusState private var focus: NF?

    var body: some View {
        if let p = Store.shared.get(pid), let w = p.floors.first(where: { $0.id == wid }) {
            let err = name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("nr.nameReq") : nil
            GlassSheet(tr("nr.title"), onClose: close) {
                GField(label: tr("nr.name"), value: $name, placeholder: tr("smp.living"), error: err, showError: true, focus: $focus, me: .name,
                       submit: .done, onSubmit: { create(p, w, "rect") })
                VStack(alignment: .leading, spacing: 8) {
                    T(tr("nr.shape"), ui(15, 700))
                    ShapeRow(d: "M2 2H32V24H2Z", label: tr("nr.rect"), on: true) {}
                    ShapeRow(d: "M2 2H18V12H32V24H2Z", label: tr("nr.lshape"), on: false) { create(p, w, "lshape") }.accessibilityIdentifier("nr.lshape")
                    ShapeRow(d: "M3 22L6 3L25 6L31 19Z", label: tr("nr.sketch"), on: false) {
                        let nm = name.trimmingCharacters(in: .whitespaces)
                        if !nm.isEmpty { close(); app.push(.sketch(pid: p.id, wid: w.id, name: keptName(p, w, nm))) }
                    }
                    .accessibilityIdentifier("nr.sketch")
                }
                Note(text: tr("nr.hint"))
            } footer: {
                GBtn(tr("nr.create"), enabled: err == nil) { create(p, w, "rect") }.accessibilityIdentifier("nr.create")
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                let own = ["room", "bath", "kitchen", "balcony"].contains(w.type) && !p.rooms.contains { $0.floorId == w.id }
                roomN = p.rooms.count + 1
                name = own ? floorName(w) : tr("real.roomN", ["n": roomN])
            }
            .onChange(of: name) { _, n in if n.count > NAME_MAX { name = String(n.prefix(NAME_MAX)) } }
        }
    }

    /// The suggested name is kept as a key ("Xona 1" follows the language, as "1-qavat" does); a typed one as typed.
    private func keptName(_ p: Project, _ w: Workspace, _ typed: String) -> String {
        let own = ["room", "bath", "kitchen", "balcony"].contains(w.type) && !p.rooms.contains { $0.floorId == w.id }
        return own && typed == floorName(w) ? w.name : suggestedName(typed, "real.roomN", AppSettings.shared.lang, ["n": "\(roomN)"])
    }

    private func create(_ p: Project, _ w: Workspace, _ shape: String) {
        let typed = name.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return }
        // the suggested name is kept as a key ("Xona 1" follows the language, as "1-qavat" does); a typed one as typed
        let nm = keptName(p, w, typed)
        var r = Room(id: uid(), floorId: w.id, name: nm, created: nowMs())
        if shape == "lshape" {
            r.template = "poly"; r.shape = "poly"; r.dims = Geo.polyDims(Geo.L_SHAPE.count)
            r.poly = Poly(verts: Geo.L_SHAPE, template: "lshape", snap: AppSettings.shared.angleSnap)
        }
        Store.shared.update(p.id) { $0.rooms.append(r) }
        close()
        app.push(.editor(pid: p.id, rid: r.id, mode: "plan"))
        if shape == "lshape" { app.say("sk.created", ["n": dn(r.name)]) } else { RoomOps.shared.focus(r.id, "A") }
    }
}

private struct ShapeRow: View {
    let d: String
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 10) {
            PathIcon(d, on ? G.cobalt2 : G.ink, 30, 2, viewBox: 34)
            T(label, ui(15, on ? 600 : 500, on ? G.cobalt2 : G.ink)).frame(maxWidth: .infinity, alignment: .leading)
            MIcon(on ? "check" : "chev", on ? G.cobalt2 : G.ink, 17, 2)
        }
        .padding(.horizontal, 14).frame(minHeight: 49)
        .background(shape.fill(on ? G.cobalt.opacity(0.12) : G.glass(0.55)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: 1))
        .pressable(0.98) { if !on { action() } }
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/* ---------------- typing a measurement (prototype SHEETS.measure, manual) ---------------- */

private enum MF: Hashable { case v }

private struct MeasureSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let k: String
    @State private var v = ""
    @State private var touched = false
    @FocusState private var focus: MF?
    private var ops: RoomOps { RoomOps.shared }

    var body: some View {
        if let r = ops.room(pid, rid) {
            let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en
            let d = r.dim(k)
            let title = k == "H" ? tr("ed.H") : k == "T" ? tr("ed.T") : k.hasPrefix("X") ? tr("sk.diagName", ["d": k]) : tr("ed.wallLen", ["w": k])
            let parsed = Geo.lenErr(v, Geo.dimMax(k), unit, en, min: Geo.dimMin(k, r.isPoly))
            let tall = k == "H" && (parsed.value ?? 0) > Int64(Geo.H_TALL)
            GlassSheet(title, onClose: close) {
                if !ops.laserOn {
                    HStack(spacing: 10) {
                        MIcon("btoff", PC.amber, 18, 2)
                        T(tr("ms.discBody"), ui(13.5, 500, PC.amber, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                        T(tr("ms.connect"), ui(14, 700, G.cobalt)).padding(6).pressable(0.96) { app.openLaser() }
                    }
                    .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.amberWash))
                }
                // a wrong value says why as it is typed (Save stays off without a word otherwise)
                NumField(label: title, value: $v, suffix: unitName(), error: errText(parsed), showError: touched || !v.isEmpty, focus: $focus, me: .v, id: "ms.value")
                if tall { T(tr("ms.tall"), ui(13, 500, G.amberInk, lh: 1.35)) }
                T(tr("ms.hint", ["ex": Geo.fmtLen(4255, unit, en)]), ui(13, 400, G.ink2))
                T(tr("ms.current", ["v": d.v != nil ? Geo.fmtLen(d.v, unit, en, full: true) + " " + unitName() + " (" + tr(srcKey(d.src)) + ")" : tr("ms.none")]), ui(13, 400, G.ink2))
                Note(text: tr("ms.manualNote"))
                if ops.laserOn {
                    HStack(spacing: 6) { MIcon("laser", G.cobalt, 18, 2); T(tr("ms.useLaser"), ui(14, 600, G.cobalt)) }
                        .frame(minHeight: 44).pressable(0.97) { close(); ops.laser(pid, rid, k) }
                }
            } footer: {
                HStack(spacing: 8) {
                    GBtn(tr("common.cancel"), kind: .secondary, height: 44, corner: 16, fontSize: 15, close)
                    GBtn(tr("common.save"), enabled: parsed.value != nil, height: 44, corner: 16, fontSize: 15) { save(parsed) }.accessibilityIdentifier("ms.save")
                }
            }
            .onChange(of: focus) { was, now in if was == .v && now == nil { touched = true } }
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .v } }
        }
    }

    private func save(_ parsed: Parsed) {
        touched = true
        guard let mm = parsed.value else { return }
        ops.apply(pid, rid, k, Int(mm), "manual")
    }
}

/* ---------------- doors and windows ---------------- */

private struct AddOpeningSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    var body: some View {
        if let r = RoomOps.shared.room(pid, rid) {
            let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en
            GlassSheet(tr("ao.title"), onClose: close) {
                HStack(alignment: .top, spacing: 10) {
                    BigOpt(icon: "door", label: tr("op.door"), sub: nil) { app.sheet = .openingForm(pid: pid, rid: rid, oid: nil, type: "door", wall: nil) }.accessibilityIdentifier("ao.door")
                    BigOpt(icon: "window", label: tr("op.window"), sub: nil) { app.sheet = .openingForm(pid: pid, rid: rid, oid: nil, type: "window", wall: nil) }.accessibilityIdentifier("ao.window")
                    // a drawn room's plan has no place for them yet, so only rectangles get columns and niches
                    if !r.isPoly {
                        BigOpt(icon: "column", label: tr("ao.col"), sub: nil) { app.sheet = .featureForm(pid: pid, rid: rid, fid: nil, type: "column") }.accessibilityIdentifier("ao.col")
                    }
                }
                if r.isPoly {
                    Note(text: tr("ft.polyNo"))
                }
                T(tr("ao.here"), ui(13, 500, G.ink2)).padding(.top, 8)
                // columns and niches first, then the doors and windows
                if !r.features.isEmpty {
                    ListBox {
                        ForEach(Array(r.features.enumerated()), id: \.element.id) { i, f in
                            if i > 0 { Hairline() }
                            HStack(spacing: 10) {
                                MIcon("column", G.cobalt, 20, 2)
                                T(tr(f.type == "column" ? "ft.column" : "ft.niche") + ", " + tr("op.wall") + " " + f.wall, ui(15, 600)).frame(maxWidth: .infinity, alignment: .leading)
                                T(Geo.fmtLen(f.w, unit, en) + " × " + Geo.fmtLen(f.d, unit, en) + " " + unitName(), num(14.5, 600, G.ink2))
                                MIcon("chev", G.ink3, 16, 2)
                            }
                            .frame(minHeight: 56)
                            .pressable(0.99) { app.sheet = .featureForm(pid: pid, rid: rid, fid: f.id, type: f.type) }
                        }
                    }
                }
                if r.openings.isEmpty && r.features.isEmpty { T(tr("ao.none"), ui(13, 400, G.ink2)) }
                else if !r.openings.isEmpty {
                    ListBox {
                        ForEach(Array(r.openings.enumerated()), id: \.element.id) { i, o in
                            if i > 0 { Hairline() }
                            HStack(spacing: 10) {
                                MIcon(o.type, G.cobalt, 20, 2)
                                T(RoomOps.shared.opName(o) + ", " + tr("op.wall") + " " + o.wall, ui(15, 600)).frame(maxWidth: .infinity, alignment: .leading)
                                T(Geo.fmtLen(o.w, unit, en) + " × " + Geo.fmtLen(o.h, unit, en) + " " + unitName(), num(14.5, 600, G.ink2))
                                MIcon("chev", G.ink3, 16, 2)
                            }
                            .frame(minHeight: 56)
                            .pressable(0.99) { app.sheet = .openingForm(pid: pid, rid: rid, oid: o.id, type: o.type, wall: nil) }
                        }
                    }
                }
            }
        }
    }
}

private struct BigOpt: View {
    let icon: String
    let label: String
    let sub: String?
    let action: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            MIcon(icon, G.cobalt, 30, 2)
            T(label, ui(14, 600), align: .center)
            if let sub { T(sub, ui(11.5, 400, G.ink2), align: .center) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6).padding(.top, 14).padding(.bottom, 12)
        .frame(maxWidth: .infinity, minHeight: 127)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.ink.opacity(0.06)))
        .pressable(0.97, action)
    }
}

private enum OF: Hashable { case w, h, off, sill }

/// A door or window: type, wall, a small drawing of the wall, size, offset and sill (prototype SHEETS.opening).
private struct OpeningSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let oid: String?
    let type0: String
    let wall0: String?
    @State private var type = "door"
    @State private var wall = "A"
    @State private var wv = ""
    @State private var hv = ""
    @State private var offv = ""
    @State private var sillv = ""
    @State private var tried = false
    @State private var loaded = false
    @FocusState private var focus: OF?
    private var ops: RoomOps { RoomOps.shared }
    private var st: AppSettings { AppSettings.shared }

    var body: some View {
        if let r = ops.room(pid, rid) {
            let unit = st.unit, en = st.lang == .en, snap = st.angleSnap
            let edit = oid.flatMap { id in r.openings.first { $0.id == id } }
            let ws = Geo.walls(r, snap)
            let pw = Geo.lenErr(wv, Geo.dimMax("A"), unit, en), ph = Geo.lenErr(hv, Geo.dimMax("H"), unit, en)
            let po = Geo.lenErr(offv, Geo.dimMax("A"), unit, en, zeroOk: true)
            let ps = type == "window" ? Geo.lenErr(sillv, Geo.dimMax("H"), unit, en, zeroOk: true) : .ok(0)
            let o: Opening? = {
                guard let w = pw.value, let h = ph.value, let off = po.value, let sill = ps.value else { return nil }
                return Opening(id: edit?.id ?? "new", type: type, wall: wall, w: Int(w), h: Int(h), off: Int(off), sill: Int(sill))
            }()
            let iss = o.flatMap { ops.issue(r, $0) }
            let corner = Geo.wallCorner(r, wall, snap)
            let title = tr(edit != nil ? (type == "door" ? "op.door" : "op.window") : type == "door" ? "op.new.door" : "op.new.window")
            GlassSheet(title, onClose: close) {
                if edit == nil {
                    Seg(items: [("door", tr("op.door")), ("window", tr("op.window"))], cur: type) { setType($0, ws) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("op.wall"), ui(15, 700))
                    Seg(items: ws.map { ($0.id, $0.id) }, cur: wall, subs: Dictionary(uniqueKeysWithValues: ws.map { ($0.id, Geo.fmtLen($0.len, unit, en)) })) {
                        wall = $0; if edit == nil { offv = Geo.fmtField(defOff(type, $0, ws), unit, en) }
                    }
                }
                WallDiagram(o: o, L: ws.first { $0.id == wall }?.len, corner: corner, n: ws.count, bad: iss != nil)
                T(tr("op.offsetHelp", ["c": corner]), ui(13, 400, G.ink2))
                HStack(alignment: .top, spacing: 10) {
                    NumField(label: tr("op.width"), value: $wv, suffix: unitName(), error: errText(pw), showError: tried, focus: $focus, me: .w, id: "op.w")
                    NumField(label: tr("op.height"), value: $hv, suffix: unitName(), error: errText(ph), showError: tried, focus: $focus, me: .h, id: "op.h")
                }
                HStack(alignment: .top, spacing: 10) {
                    NumField(label: tr("op.offset", ["c": corner]), value: $offv, suffix: unitName(), error: errText(po), showError: tried, focus: $focus, me: .off, id: "op.off")
                    if type == "window" { NumField(label: tr("op.sill"), value: $sillv, suffix: unitName(), error: errText(ps), showError: tried, focus: $focus, me: .sill, id: "op.sill") }
                    else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
                if o != nil, let iss { Warn(icon: "alert", text: tr(iss.key, iss.vars), red: true) }
            } footer: {
                if edit?.approx == true { Warn(icon: "alert", text: tr("op.approx")) }
                HStack(spacing: 8) {
                    if let edit { GBtn(tr("common.delete"), kind: .danger, icon: "trash", height: 44, corner: 16, fontSize: 15) { ops.deleteOpening(pid, rid, edit) } }
                    else { GBtn(tr("common.cancel"), kind: .secondary, height: 44, corner: 16, fontSize: 15, close) }
                    GBtn(tr("common.save"), enabled: o != nil && iss == nil, height: 44, corner: 16, fontSize: 15) {
                        tried = true
                        guard var o, iss == nil else { return }
                        if edit == nil { o.id = uid() }
                        ops.saveOpening(pid, rid, o, isNew: edit == nil)
                    }
                    .accessibilityIdentifier("op.save")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                type = edit?.type ?? type0
                wall = edit?.wall ?? wall0 ?? (type0 == "door" ? "A" : ws.count > 2 ? ws[2].id : "A")
                wv = Geo.fmtField(edit?.w ?? (type == "door" ? st.doorW : st.winW), unit, en)
                hv = Geo.fmtField(edit?.h ?? (type == "door" ? st.doorH : st.winH), unit, en)
                offv = Geo.fmtField(edit?.off ?? defOff(type, wall, ws), unit, en)
                sillv = Geo.fmtField(edit?.sill ?? (type == "door" ? 0 : st.winSill), unit, en)
            }
        }
    }

    private func defOff(_ t: String, _ wl: String, _ ws: [Geo.Wall]) -> Int {
        if t == "door" { return 500 }
        guard let L = ws.first(where: { $0.id == wl })?.len else { return 1000 }
        return max(0, kround(Double(L - st.winW) / 2 / 10) * 10)
    }

    private func setType(_ t: String, _ ws: [Geo.Wall]) {
        guard t != type else { return }
        type = t
        let unit = st.unit, en = st.lang == .en
        wv = Geo.fmtField(t == "door" ? st.doorW : st.winW, unit, en); hv = Geo.fmtField(t == "door" ? st.doorH : st.winH, unit, en)
        offv = Geo.fmtField(defOff(t, wall, ws), unit, en); sillv = Geo.fmtField(t == "door" ? 0 : st.winSill, unit, en)
    }
}

private enum FF: Hashable { case w, d, off, sill, h }

/// A column against a wall or a niche into it: type, wall, width, depth, offset, and a niche's sill and height
/// (Android FeatureSheet).
private struct FeatureSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let fid: String?
    let type0: String
    @State private var type = "column"
    @State private var wall = "A"
    @State private var wv = ""
    @State private var dv = ""
    @State private var offv = ""
    @State private var sillv = ""
    @State private var hv = ""
    @State private var tried = false
    @State private var loaded = false
    @FocusState private var focus: FF?
    private var ops: RoomOps { RoomOps.shared }
    private var st: AppSettings { AppSettings.shared }

    var body: some View {
        if let r = ops.room(pid, rid) {
            let unit = st.unit, en = st.lang == .en, snap = st.angleSnap
            let edit = fid.flatMap { id in r.features.first { $0.id == id } }
            let ws = Geo.walls(r, snap)
            let niche = type == "niche"
            let pw = Geo.lenErr(wv, Geo.dimMax("A"), unit, en), pd = Geo.lenErr(dv, Geo.dimMax("A"), unit, en)
            let po = Geo.lenErr(offv, Geo.dimMax("A"), unit, en, zeroOk: true)
            let psl: Parsed = niche ? Geo.lenErr(sillv, Geo.dimMax("H"), unit, en, zeroOk: true) : .ok(0), ph: Parsed = niche ? Geo.lenErr(hv, Geo.dimMax("H"), unit, en) : .ok(0)
            let f: Feature? = {
                guard let w = pw.value, let d = pd.value, let off = po.value, let sill = psl.value, let h = ph.value else { return nil }
                return Feature(id: edit?.id ?? "new", type: type, wall: wall, off: Int(off), w: Int(w), d: Int(d), sill: Int(sill), h: Int(h))
            }()
            let iss = f.flatMap { Geo.featureIssue(r, $0, snap) }
            let corner = Geo.wallCorner(r, wall, snap)
            GlassSheet(tr(edit != nil ? (niche ? "ft.niche" : "ft.column") : "ao.col"), onClose: close) {
                Seg(items: [("column", tr("ft.column")), ("niche", tr("ft.niche"))], cur: type) { type = $0 }
                T(tr(niche ? "ft.nicheB" : "ft.columnB"), ui(13, 400, G.ink2, lh: 1.4))
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("op.wall"), ui(15, 700))
                    Seg(items: ws.map { ($0.id, $0.id) }, cur: wall, subs: Dictionary(uniqueKeysWithValues: ws.map { ($0.id, Geo.fmtLen($0.len, unit, en)) })) { wall = $0 }
                }
                HStack(alignment: .top, spacing: 10) {
                    NumField(label: tr("op.width"), value: $wv, suffix: unitName(), error: errText(pw), showError: tried, focus: $focus, me: .w, id: "ft.w")
                    NumField(label: tr(niche ? "ft.dIn" : "ft.dOut"), value: $dv, suffix: unitName(), error: errText(pd), showError: tried, focus: $focus, me: .d, id: "ft.d")
                }
                HStack(alignment: .top, spacing: 10) {
                    NumField(label: tr("op.offset", ["c": corner]), value: $offv, suffix: unitName(), error: errText(po), showError: tried, focus: $focus, me: .off, id: "ft.off")
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                }
                if niche {
                    HStack(alignment: .top, spacing: 10) {
                        NumField(label: tr("op.sill"), value: $sillv, suffix: unitName(), error: errText(psl), showError: tried, focus: $focus, me: .sill, id: "ft.sill")
                        NumField(label: tr("ft.h"), value: $hv, suffix: unitName(), error: errText(ph), showError: tried, focus: $focus, me: .h, id: "ft.h")
                    }
                }
                if f != nil, let iss { Warn(icon: "alert", text: tr(iss), red: true) }
            } footer: {
                HStack(spacing: 8) {
                    if let edit {
                        GBtn(tr("common.delete"), kind: .danger, icon: "trash", height: 44, corner: 16, fontSize: 15) {
                            ops.deleteFeature(pid, rid, edit)
                        }
                    }
                    else { GBtn(tr("common.cancel"), kind: .secondary, height: 44, corner: 16, fontSize: 15, close) }
                    GBtn(tr("common.save"), enabled: f != nil && iss == nil, height: 44, corner: 16, fontSize: 15) {
                        tried = true
                        guard var f, iss == nil else { return }
                        if edit == nil { f.id = uid() }
                        ops.saveFeature(pid, rid, f, isNew: edit == nil)
                    }
                    .accessibilityIdentifier("ft.save")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                type = edit?.type ?? type0
                wall = edit?.wall ?? "A"
                wv = Geo.fmtField(edit?.w ?? 400, unit, en); dv = Geo.fmtField(edit?.d ?? 300, unit, en)
                offv = Geo.fmtField(edit?.off ?? 0, unit, en)
                sillv = Geo.fmtField(edit?.sill ?? 900, unit, en); hv = Geo.fmtField(edit?.h ?? 600, unit, en)
            }
        }
    }
}

/// A segmented control (prototype .seg.wide) with an optional small value under each label.
struct Seg: View {
    let items: [(String, String)]
    let cur: String
    var subs: [String: String] = [:]
    /// 2: a long label (table legs, the top's board) wraps instead of being cut
    var lines = 1
    let onPick: (String) -> Void
    var body: some View {
        // more than four items (a drawn room's walls) scroll sideways instead of squeezing
        if items.count > 4 {
            ScrollView(.horizontal, showsIndicators: false) { cells(scroll: true).padding(3) }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            cells(scroll: false)
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
        }
    }

    private func cells(scroll: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.0) { k, label in
                let on = k == cur
                VStack(spacing: 0) {
                    T(label, ui(lines > 1 ? 13 : 14, on ? 600 : 500, on ? G.ink : G.ink2), align: .center, lines: lines)
                    if let s = subs[k] { T(s, num(11.5, 400, on ? G.ink : G.ink2), lines: 1) }
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
                .frame(minWidth: scroll ? 56 : nil, maxWidth: scroll ? nil : .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? G.glass(0.9) : .clear))
                .pressable(0.97) { onPick(k) }
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("seg." + k)
            }
        }
    }
}

/// The wall as a line from its start corner, the opening in place and an arrow for the offset (prototype .minidia, 320 × 54).
private struct WallDiagram: View {
    let o: Opening?
    let L: Int?
    let corner: Int
    let n: Int
    let bad: Bool
    var body: some View {
        Canvas { ctx, size in
            var c = ctx; Fit(size, 320, 54).apply(&c)
            c.line(PC.ink, CGPoint(x: 20, y: 30), CGPoint(x: 300, y: 30), 6)
            c.disc(PC.cob, 5, CGPoint(x: 20, y: 30))
            c.text("\(corner)", CGPoint(x: 20, y: 13), .ui, 11, 600, PC.cob)
            c.text("\(corner % max(1, n) + 1)", CGPoint(x: 300, y: 13), .ui, 11, 400, PC.ink3)
            if let o {
                let sx = 280 / CGFloat(L ?? 5000)
                let x = 20 + CGFloat(o.off) * sx, w = max(2, CGFloat(o.w) * sx)
                let r = CGRect(x: x, y: 25, width: w, height: 10)
                c.fill(Path(r), with: .color(PC.white)); c.stroke(Path(r), with: .color(bad ? PC.red : PC.cob), lineWidth: 1.5)
                c.line(PC.cob, CGPoint(x: 20, y: 46), CGPoint(x: x, y: 46), 1.2)
                c.line(PC.cob, CGPoint(x: x - 5, y: 43), CGPoint(x: x, y: 46), 1.2); c.line(PC.cob, CGPoint(x: x - 5, y: 49), CGPoint(x: x, y: 46), 1.2)
            }
        }
        .padding(6)
        .frame(height: 74)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/* ---------------- room information (prototype SHEETS.roomInfo) ---------------- */

private struct RoomInfoSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    private var ops: RoomOps { RoomOps.shared }
    var body: some View {
        if let r = ops.room(pid, rid) {
            let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en, snap = AppSettings.shared.angleSnap, m = unitName()
            let a = Geo.areas(r, snap)
            let H = r.dim("H").v
            let n = Geo.unconfCount(r, snap)
            let vol: String = {
                guard let a, let H else { return "—" }
                let s = String(format: "%.2f", Double(a.floor) * Double(H) / 1e9)
                return (en ? s : s.replacingOccurrences(of: ".", with: ",")) + " " + tr("u.m3")
            }()
            GlassSheet(dn(r.name), onClose: close) {
                ListBox {
                    Kv(label: tr("rp.floorArea"), value: a.map { Geo.fmtArea($0.floor, en) + " " + tr("u.m2") } ?? "—")
                    Hairline(); Kv(label: tr("rp.perim"), value: a.map { Geo.fmtLen(Int($0.perim), unit, en) + " " + m } ?? "—")
                    Hairline(); Kv(label: tr("ri.height"), value: H.map { Geo.fmtLen($0, unit, en) + " " + m } ?? "—")
                    Hairline(); Kv(label: tr("rp.gross"), value: a?.gross.map { Geo.fmtArea($0, en) + " " + tr("u.m2") } ?? "—")
                    Hairline(); Kv(label: tr("rp.openings"), value: a?.open.map { Geo.fmtArea($0, en) + " " + tr("u.m2") } ?? "—")
                    Hairline(); Kv(label: tr("rp.net"), value: a?.net.map { Geo.fmtArea($0, en) + " " + tr("u.m2") } ?? "—")
                    Hairline(); Kv(label: tr("ri.volume"), value: vol, bold: true)
                }
                if n > 0 && a != nil { Warn(icon: "clock", text: tr("rp.prov", ["n": n])) }
                T(tr("rp.conv") + " " + tr("ri.volNote"), ui(12.5, 400, G.ink2, lh: 1.4))
                ListBox {
                    ActionRow(icon: "edit", label: tr("ri.rename")) { app.sheet = .roomRename(pid: pid, rid: rid) }
                    Hairline()
                    ActionRow(icon: "walls", label: tr("ri.walls")) { close(); app.push(.wallView(pid: pid, rid: rid, wall: Geo.walls(r, snap).first!.id)) }
                    if !r.isPoly { Hairline(); ActionRow(icon: "redo", label: tr("ri.rotate")) { ops.rotate(pid, rid) } }
                    Hairline()
                    ActionRow(icon: "trash", label: tr("ri.delete"), danger: true) { ops.deleteRoom(pid, rid) }.accessibilityIdentifier("ri.delete")
                }
            }
        }
    }
}

private struct Kv: View {
    let label: String
    let value: String
    var bold = false
    var body: some View {
        HStack {
            T(label, ui(14, bold ? 700 : 400)).frame(maxWidth: .infinity, alignment: .leading)
            T(value, num(15, bold ? 700 : 600))
        }
        .padding(.vertical, 6).frame(minHeight: 44)
    }
}

private struct RenameSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    @State private var v = ""
    @State private var loaded = false
    @FocusState private var focus: NF?
    var body: some View {
        if let r = RoomOps.shared.room(pid, rid) {
            let err = v.trimmingCharacters(in: .whitespaces).isEmpty ? tr("nr.nameReq") : nil
            // an unchanged name that was a key stays a key, so it still follows the language
            let name = v.trimmingCharacters(in: .whitespaces) == dn(r.name) ? r.name : v
            GlassSheet(tr("room.rename"), onClose: close) {
                GField(label: tr("nr.name"), value: $v, error: err, showError: true, focus: $focus, me: .name, submit: .done, onSubmit: { if err == nil { RoomOps.shared.rename(pid, rid, name) } })
            } footer: {
                GBtn(tr("common.save"), enabled: err == nil) { RoomOps.shared.rename(pid, rid, name) }
            }
            .onChange(of: v) { _, n in if n.count > NAME_MAX { v = String(n.prefix(NAME_MAX)) } }
            .onAppear {
                guard !loaded else { return }
                loaded = true; v = dn(r.name)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .name }
            }
        }
    }
}

/// The readings tray: readings taken on the Measure page (or here, with the laser) wait to be given to a wall.
private struct TraySheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    var body: some View {
        let st = AppSettings.shared, en = st.lang == .en
        let rs = Array(st.readings.reversed())
        let r = RoomOps.shared.room(pid, rid)
        let targets = (r.map { Geo.stepKeys($0, st.angleSnap) } ?? []) + ["T"]
        GlassSheet(tr("tr.title"), onClose: close) {
            T(tr("tr.body"), ui(14, 400, G.ink2, lh: 1.45))
            if st.laser == .connected {
                GBtn(tr("ms.simPress"), kind: .secondary, icon: "laser") { RoomOps.shared.trayReading(pid, rid) }.accessibilityIdentifier("tr.laser")
            } else {
                HStack(spacing: 8) {
                    MIcon("btoff", G.amberInk, 18, 2)
                    T(tr("ms.discBody"), ui(13.5, 500, G.ink, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
                    T(tr("ms.connect"), ui(14, 700, G.cobalt)).padding(.horizontal, 8).frame(minHeight: 44).pressable(0.96) { app.openLaser() }
                }
                .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.amberWash))
            }
            if rs.isEmpty { T(tr("tr.empty"), ui(14, 500, G.ink2, lh: 1.45)) }
            ForEach(rs) { x in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(Geo.fmtLen(x.mm, st.unit, en, full: true) + " " + unitName()).st(num(20, 600)).frame(maxWidth: .infinity, alignment: .leading)
                        T(tr(x.src == "manual" ? "src.manual" : "src.sim"), ui(12.5, 500, G.ink2))
                    }
                    if let used = x.used {
                        HStack(spacing: 4) { MIcon("check", G.green, 14, 2.4); T(tr("tr.used", ["d": used]), ui(13, 400, G.ink2)) }
                    } else {
                        FlowLayout(spacing: 6) {
                            T(tr("tr.assign"), ui(13, 400, G.ink2)).frame(minHeight: 40)
                            ForEach(targets, id: \.self) { k in
                                T(k == "H" ? tr("ed.Hs") : k == "T" ? tr("ed.Ts") : k, ui(14, 600)).padding(.horizontal, 12).frame(minHeight: 40)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.glass(0.7)))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                                    .pressable(0.97) { RoomOps.shared.assignReading(pid, rid, x.id, k); app.sheet = nil }
                                    .accessibilityIdentifier("tr." + k)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.6)))
            }
        }
    }
}

/// A room card's menu (prototype SHEETS.itemMenu for rooms).
private struct RoomMenuSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    var body: some View {
        if let p = Store.shared.get(pid), let r = p.rooms.first(where: { $0.id == rid }) {
            let rep = p.reportRooms[r.id] != false
            GlassSheet(dn(r.name), onClose: close) {
                ListBox {
                    ActionRow(icon: "edit", label: tr("it.rename")) { app.sheet = .roomRename(pid: pid, rid: rid) }
                    Hairline()
                    ActionRow(icon: "layers", label: tr("it.move")) { app.sheet = .roomMove(pid: pid, rid: rid) }
                    Hairline()
                    ActionRow(icon: "copy", label: tr("it.dup")) {
                        var copy = r
                        copy.id = uid(); copy.name = tr("room.copy", ["n": dn(r.name)]); copy.created = nowMs(); copy.views = []
                        copy.openings = r.openings.map { var o = $0; o.id = uid(); return o }
                        Store.shared.update(pid) { $0.rooms.append(copy) }
                        close(); app.say("op.added", ["o": dn(copy.name)])
                    }
                    Hairline()
                    ActionRow(icon: "doc", label: tr("it.report"), action: { Store.shared.update(pid) { $0.reportRooms[r.id] = !rep } }) { GSwitch(on: rep) }
                    Hairline()
                    ActionRow(icon: "trash", label: tr("it.del"), danger: true) { RoomOps.shared.deleteRoom(pid, rid) }
                }
            }
        }
    }
}

private struct RoomMoveSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    var body: some View {
        if let p = Store.shared.get(pid), let r = p.rooms.first(where: { $0.id == rid }) {
            let others = p.floors.filter { $0.id != r.floorId }
            GlassSheet(tr("it.moveT"), onClose: close) {
                if others.isEmpty { T(tr("it.moveNone"), ui(14, 400, G.ink2, lh: 1.4)).padding(.bottom, 8) }
                else {
                    ListBox {
                        ForEach(Array(others.enumerated()), id: \.element.id) { i, to in
                            if i > 0 { Hairline() }
                            ActionRow(icon: wsIcon(to.type), label: floorName(to), action: {
                                Store.shared.update(pid) { pr in if let k = pr.rooms.firstIndex(where: { $0.id == r.id }) { pr.rooms[k].floorId = to.id } }
                                close(); app.say("it.moved", ["n": dn(r.name), "w": floorName(to)])
                            }) { MIcon("chev", G.ink3, 18, 2) }
                        }
                    }
                }
            }
        }
    }
}

/// Add on one wall (prototype SHEETS.wvAdd): a door or a window with the default sizes.
private struct WallAddSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let wall: String
    var body: some View {
        let st = AppSettings.shared, unit = st.unit, en = st.lang == .en
        GlassSheet(tr("wv.add"), onClose: close) {
            T(tr("wv.onWall", ["w": wall]), ui(13.5, 400, G.ink2, lh: 1.4))
            ListBox {
                ActionRow(icon: "door", label: tr("op.door") + "  ·  " + Geo.fmtLen(st.doorW, unit, en) + " × " + Geo.fmtLen(st.doorH, unit, en),
                          action: { app.sheet = .openingForm(pid: pid, rid: rid, oid: nil, type: "door", wall: wall) }) { MIcon("chev", G.ink3, 18, 2) }
                Hairline()
                ActionRow(icon: "window", label: tr("op.window") + "  ·  " + Geo.fmtLen(st.winW, unit, en) + " × " + Geo.fmtLen(st.winH, unit, en),
                          action: { app.sheet = .openingForm(pid: pid, rid: rid, oid: nil, type: "window", wall: wall) }) { MIcon("chev", G.ink3, 18, 2) }
                // furniture orders mark sockets and pipes too (furniture plan section 5)
                if Store.shared.get(pid)?.isFurniture == true {
                    Hairline()
                    ActionRow(icon: "plus", label: tr("pt.add") + "  ·  " + tr("pt.addRow"),
                              action: { app.sheet = .pointForm(pid: pid, rid: rid, wall: wall, id: nil) }) { MIcon("chev", G.ink3, 18, 2) }
                        .accessibilityIdentifier("wa.point")
                }
            }
        }
    }
}
