import SwiftUI

/// The room editor (prototype editor.js "ed2" page with the glass room look); Android EditorScreen.
struct EditorScreen: View {
    let app: AppModel
    let pid: String
    let rid: String
    let mode: String

    private var ops: RoomOps { RoomOps.shared }

    var body: some View {
        if let p = Store.shared.get(pid), let r = p.rooms.first(where: { $0.id == rid }) {
            if mode == "3d" { Room3DScreen(app: app, p: p, r: r) } else { plan(p, r) }
        }
    }

    /// The plan page: the room's drawing, the step card and the tools.
    @ViewBuilder private func plan(_ p: Project, _ r: Room) -> some View {
        let w = p.floors.first { $0.id == r.floorId }
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en
        let _ = ops.histTick
        let f = ops.focusOf(r)
        let sel: String? = { if case .measure(_, _, let k)? = app.sheet { return k }; return f.k }()
        let selOp: String? = { if case .openingForm(_, _, let oid, _, _)? = app.sheet { return oid }; return nil }()
        ZStack {
            RoomGrid().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                    VStack(alignment: .leading, spacing: 0) {
                        T(dn(r.name), ui(20, 800, G.ink, lh: 1.2), lines: 1)
                        T(dn(p.name) + (w.map { " › " + floorName($0) } ?? ""), ui(12, 400, G.ink2), lines: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    LaserButton { app.sheet = .device }.frame(width: 44, height: 44)
                    GlassIconButton("more", tr("common.menu")) { app.sheet = .roomInfo(pid: p.id, rid: r.id) }.accessibilityIdentifier("ed.menu")
                }
                .padding(.horizontal, 16).frame(height: 64)
                ZStack(alignment: .bottom) {
                    Group {
                        if r.isPoly { PolyPlan(pid: p.id, r: r, sel: sel, selOp: selOp) }
                        else {
                            RectPlan(r: r, sel: sel, selOp: selOp, label: dn(r.name),
                                     issueOf: { ops.issue(r, $0) != nil },
                                     onWall: { ops.select(p.id, r.id, $0) },
                                     onOpening: { app.sheet = .openingForm(pid: p.id, rid: r.id, oid: $0, type: "door", wall: nil) },
                                     onDragEnd: { o, off in ops.moveOpening(p.id, r.id, o, off, o.sill) },
                                     tipText: { o, off in tr("wv.off", ["c": Geo.wallCorner(r, o.wall), "v": Geo.fmtLen(off, unit, en) + " " + unitName()]) })
                                .padding(.bottom, 60)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // the readings tray (bottom left) and undo / redo (bottom right) float over the plan
                    HStack {
                        GlassPill {
                            HStack(spacing: 8) {
                                MIcon("laser", G.cobalt, 20, 2)
                                T(tr("tr.btn"), ui(15, 700), lines: 1)
                                T("\(AppSettings.shared.readings.filter { $0.used == nil }.count)", ui(13, 800, .white)).padding(.horizontal, 9).padding(.vertical, 4).background(Capsule().fill(G.cobalt))
                            }
                            .padding(.leading, 14).padding(.trailing, 8).frame(maxHeight: .infinity)
                            .pressable(0.97) { app.sheet = .tray(pid: p.id, rid: r.id) }
                            .accessibilityIdentifier("ed.tray")
                        }
                        .padding(.leading, 12)
                        Spacer()
                        GlassPill {
                            HStack(spacing: 0) {
                                HistBtn(icon: "undo", on: ops.canUndo(r.id), label: tr("common.undo")) { ops.undo(p.id, r.id) }
                                Rectangle().fill(G.ink.opacity(0.12)).frame(width: 1, height: 20)
                                HistBtn(icon: "redo", on: ops.canRedo(r.id), label: tr("common.redo")) { ops.redo(p.id, r.id) }
                            }
                            .padding(.horizontal, 4)
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.bottom, 12)
                }
                // the plan keeps room next to the opened list; under a sheet it may shrink, so the sheet and its
                // keyboard still fit on the screen (a page taller than the screen would push the sheet's buttons
                // under the keyboard)
                .frame(minHeight: app.sheet == nil ? 170 : 0)
                StepPanel(app: app, pid: p.id, r: r, f: f)
                Tools(app: app, pid: p.id, r: r)
            }
            if !ops.tipSeen && !AppSettings.shared.editorTipOff && app.sheet == nil { EditorTip() }
        }
        .onAppear {
            if ops.panelRoom != r.id { ops.panelRoom = r.id; ops.panelOpen = false }
        }
    }
}

private struct GlassPill<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        content
            .frame(height: 44)
            .glassBlur(shape, tint: G.sheet(0.55))
            .topHighlight(shape, 1, width: 1)
            .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
            .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.12), blur: 20, y: 8))
    }
}

private struct HistBtn: View {
    let icon: String
    let on: Bool
    let label: String
    let action: () -> Void
    var body: some View {
        MIcon(icon, on ? G.ink : PC.offIcon, 20, 2).frame(width: 44, height: 42)
            .pressable(0.94, label: label) { if on { action() } }
            .accessibilityIdentifier("ed." + icon)
    }
}

/// The room's 3D page, on the same page as the plan (prototype A.mode).
func open3D(_ pid: String, _ rid: String) { RoomOps.shared.mode(pid, rid, "3d") }

/* ---------------- the bottom panel: the step card, and the full list when opened ---------------- */

private struct StepPanel: View {
    let app: AppModel
    let pid: String
    let r: Room
    let f: RoomOps.Focus
    @State private var drag: CGFloat = 0
    private var ops: RoomOps { RoomOps.shared }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        VStack(spacing: 0) {
            // the grab handle: tap to open or close, or pull
            RoundedRectangle(cornerRadius: 3).fill(Theme.shared.dark ? Color(argb: 0xFF3A4256) : Color(argb: 0xFFC3CAD8)).frame(width: 48, height: 5)
                .frame(maxWidth: .infinity).frame(height: 30).contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeOut(duration: 0.28)) { ops.panelOpen.toggle() } }
                .gesture(DragGesture(minimumDistance: 6).onEnded { v in
                    withAnimation(.easeOut(duration: 0.28)) {
                        if v.translation.height < -56 { ops.panelOpen = true } else if v.translation.height > 56 { ops.panelOpen = false }
                    }
                })
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(Text(tr(ops.panelOpen ? "ed2.hide" : "ed2.all")))
            VStack(alignment: .leading, spacing: 0) {
                if r.isPoly { PolyHint(pid: pid, r: r) }
                StepCard(app: app, pid: pid, r: r, f: f)
                if ops.panelOpen {
                    ScrollView {
                        VStack(spacing: 0) { Hairline(); FullList(app: app, pid: pid, r: r, f: f) }.padding(.top, 12)
                    }
                    // it gives way to the plan on small screens (the plan keeps at least 170 pt)
                    .frame(maxHeight: 380)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 14)
        }
        .glassBlur(shape, tint: G.sheet(0.55))
        .topHighlight(shape, 0.95)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.1), blur: 30, y: -10))
        .padding(.horizontal, 12).padding(.bottom, 10)
    }
}

private struct StepCard: View {
    let app: AppModel
    let pid: String
    let r: Room
    let f: RoomOps.Focus
    private var ops: RoomOps { RoomOps.shared }

    var body: some View {
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en, snap = AppSettings.shared.angleSnap
        let keys = ops.measureKeys(r)
        let k = f.k
        VStack(alignment: .leading, spacing: 10) {
            switch f.kind {
            case "ok":
                let a = Geo.areas(r, snap)
                HStack(spacing: 12) {
                    MIcon("check", PC.okGreen, 22, 2.4).frame(width: 42, height: 42).background(Circle().fill(G.green.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 0) {
                        T(tr("ed2.done"), ui(16, 800), lines: 2)
                        if let a {
                            T(a.net != nil ? tr("ed2.sum", ["f": Geo.fmtArea(a.floor, en), "w": Geo.fmtArea(a.net, en)]) : tr("ed2.sumNoH", ["f": Geo.fmtArea(a.floor, en)]), ui(12.5, 400, G.ink2))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    AllPill()
                }
                // a furniture order's room is ready: the next step is its kitchen or wardrobe, for this room
                let pr = Store.shared.get(pid)
                let addFurn = pr.map { p in p.isFurniture && !p.furniture.contains { $0.roomId == r.id || $0.ws == r.floorId } } ?? false
                // measured for a room-less piece: it goes in now
                let waiting = app.placeAfter.flatMap { pa in pa.rid == r.id ? pr?.furniture.first { $0.id == pa.fid && $0.roomId == nil } : nil }
                if let waiting {
                    GBtn(tr("fz.placeN", ["n": dn(waiting.name)]), icon: waiting.kind == "kitchen" ? "kitchen" : "board", height: 50, fontSize: 15.5) {
                        app.placeAfter = nil; app.replaceTop(.fPlace(pid: pid, fid: waiting.id, rid: r.id))
                    }
                    .accessibilityIdentifier("ed.placeN")
                } else if addFurn, let pr {
                    let kind = roomKind(pr.floors.first { $0.id == r.floorId })
                    GBtn(tr(kind == "kitchen" ? "fo.addK" : "fo.addW"), icon: kind == "kitchen" ? "kitchen" : "board", height: 50, fontSize: 15.5) {
                        app.push(.fGallery(pid: pid, rid: r.id))
                    }
                    .accessibilityIdentifier("ed.addFurn")
                }
                HStack(spacing: 8) {
                    CardBtn(label: tr("ed.tb.walls"), icon: "walls", primary: false) { app.push(.wallView(pid: pid, rid: r.id, wall: Geo.walls(r, snap).first!.id)) }
                    // with the furniture button above, 3D steps back so there is one main button
                    CardBtn(label: tr("gs.3d"), icon: "cube", primary: !addFurn && waiting == nil) { open3D(pid, r.id) }
                }
            case "bad":
                if let o = f.issue {
                    let iss = ops.issue(r, o)
                    HStack(spacing: 10) {
                        MIcon("alert", G.err, 20, 2)
                        T(iss.map { tr($0.key, $0.vars) } ?? "", ui(13.5, 500, G.err, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                        T(tr("ed.fix"), ui(14, 700, G.err)).padding(8)
                            .pressable(0.96) { app.sheet = .openingForm(pid: pid, rid: r.id, oid: o.id, type: o.type, wall: nil) }
                    }
                    .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.errWash))
                }
            case "badFt":
                if let x = f.ft {
                    let iss = Geo.featureIssue(r, x, snap)
                    HStack(spacing: 10) {
                        MIcon("alert", G.err, 20, 2)
                        T(tr("ft." + x.type) + ": " + (iss.map { tr($0) } ?? ""), ui(13.5, 500, G.err, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                        T(tr("ed.fix"), ui(14, 700, G.err)).padding(8)
                            .pressable(0.96) { app.sheet = .featureForm(pid: pid, rid: r.id, fid: x.id, type: x.type) }
                    }
                    .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.errWash))
                }
                footer(keys, k)
            default:
                if let k { measureCard(k, unit, en) }
                footer(keys, k)
            }
        }
    }

    @ViewBuilder private func measureCard(_ k: String, _ unit: LenUnit, _ en: Bool) -> some View {
        let d = r.dim(k)
        let name = ops.dimLabel(k)
        let small: String = {
            switch f.kind {
            case "recv": return tr(d.pending?.from == "quick" ? "ed2.fromQuick" : "ed2.fromLaser", ["w": name])
            case "again": return tr("ed2.re", ["w": name])
            case "conf": return name + ", " + tr("src." + (d.src ?? "manual"))
            default: return tr("ed2.next", ["w": name])
            }
        }()
        let vtxt = f.kind == "recv" ? Geo.fmtLen(d.pending?.mm, unit, en, full: true) : f.kind == "conf" ? Geo.fmtLen(d.v, unit, en) : "?"
        let vcol = f.kind == "recv" ? PC.amber : f.kind == "conf" ? G.ink : G.ink3
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                T(small, ui(13, 400, G.ink2), lines: 1)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(vtxt).st(num(34, 600, vcol, ls: -0.01)).accessibilityIdentifier("ed.value")
                    T(unitName(), num(13, 500, G.ink2))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            switch f.kind {
            case "recv": StatusPill(text: tr("ed2.unconf"), bg: G.amberWash, fg: PC.amber, icon: "clock")
            case "conf": StatusPill(text: tr("ed2.confirmed"), bg: Theme.shared.dark ? G.greenWash : Color(argb: 0xFFE6F4EF), fg: Theme.shared.dark ? G.green : Color(argb: 0xFF0B7A5A), icon: "check")
            case "again":
                HStack(spacing: 5) { MIcon("x", G.ink2, 14, 2); T(tr("common.cancel"), ui(12.5, 600, G.ink2)) }
                    .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(G.ink.opacity(0.06)))
                    .pressable(0.96) { ops.cancelAgain() }
            default: StatusPill(text: tr("ed2.notMeasured"), bg: G.ink.opacity(0.06), fg: G.ink2, icon: nil)
            }
        }
        if f.kind == "again" { T(tr("ed2.cur", ["v": Geo.fmtLen(d.v, .m, en)]), ui(13, 400, G.ink2)) }
        if f.kind == "unset" || f.kind == "again" {
            if ops.laserOn { T(tr("ed2.pressLaser"), ui(13, 400, G.ink2)) }
            else { HStack(spacing: 6) { MIcon("btoff", G.ink2, 16, 2); T(tr("ed2.noLaser"), ui(13, 400, G.ink2)) } }
        }
        HStack(spacing: 8) {
            switch f.kind {
            case "recv":
                CardBtn(label: tr("ed2.again"), icon: "laser", primary: false) { ops.againReading(pid, r.id, k) }
                CardBtn(label: tr("ed2.confirm"), icon: "check", primary: true) { ops.confirm(pid, r.id, k) }.accessibilityIdentifier("ed.confirm")
            case "conf":
                CardBtn(label: tr("ed2.edit"), icon: "edit", primary: false) { app.sheet = .measure(pid: pid, rid: r.id, k: k) }
                CardBtn(label: tr("ed2.remeasure"), icon: "laser", primary: true) { ops.remeasure(pid, r.id, k) }
            default:
                CardBtn(label: tr("ed2.manual"), icon: "kbd", primary: false) { app.sheet = .measure(pid: pid, rid: r.id, k: k) }.accessibilityIdentifier("ed.manual")
                if ops.laserOn { CardBtn(label: tr("ed2.getLaser"), icon: "laser", primary: true) { ops.laser(pid, r.id, k) }.accessibilityIdentifier("ed.laser") }
                else { CardBtn(label: tr("ed2.dev"), icon: "bt", primary: true) { app.sheet = .device } }
            }
        }
    }

    /// What comes next and the button that opens the full list.
    private func footer(_ keys: [String], _ k: String?) -> some View {
        let open = keys.filter { r.dim($0).status != "conf" && $0 != k }
        let t = !open.isEmpty ? tr("ed2.left", ["w": ops.dimLabel(open[0]), "n": open.count]) : f.kind == "unset" || f.kind == "recv" ? tr("ed2.last") : ""
        return HStack {
            T(t, ui(13, 400, G.ink2), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
            AllPill()
        }
        .frame(minHeight: 44)
    }
}

private struct AllPill: View {
    var body: some View {
        let open = RoomOps.shared.panelOpen
        HStack(spacing: 4) {
            PathIcon(open ? "M6 9.5l6 6 6-6" : "M6 14.5l6-6 6 6", G.cobalt, 16, 2.2)
            T(tr(open ? "ed2.hide" : "ed2.all"), ui(13, 600, G.cobalt), lines: 1)
        }
        .padding(.leading, 9).padding(.trailing, 14).frame(minHeight: 44)
        .background(Capsule().fill(G.cobalt.opacity(0.12)))
        .pressable(0.96) { withAnimation(.easeOut(duration: 0.28)) { RoomOps.shared.panelOpen.toggle() } }
        .accessibilityIdentifier("ed.all")
    }
}

private struct StatusPill: View {
    let text: String
    let bg: Color
    let fg: Color
    let icon: String?
    var body: some View {
        HStack(spacing: 5) {
            if let icon { MIcon(icon, fg, 14, 2.2) }
            T(text, ui(12.5, 600, fg), lines: 1)
        }
        .padding(.horizontal, 10).padding(.vertical, 5).background(Capsule().fill(bg))
    }
}

/// The step card's buttons: 52 pt pills; the main one blue (glass.css .gs-room .ed2-acts).
struct CardBtn: View {
    let label: String
    let icon: String
    let primary: Bool
    let action: () -> Void
    var body: some View {
        let shape = Capsule()
        HStack(spacing: 8) {
            MIcon(icon, primary ? .white : G.cobalt, 18, 2.2)
            // two lines rather than cut off with a large font or a long word
            T(label, ui(15, 700, primary ? .white : G.ink), align: .center, lines: 2)
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(shape.fill(primary ? G.cobalt : G.glass(0.65)))
        .overlay { if !primary { shape.strokeBorder(G.rim, lineWidth: 1) } }
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(primary ? Color(argb: 0x38374FDD) : G.shade.opacity(0.08), blur: primary ? 18 : 16, y: primary ? 8 : 6))
        .pressable(0.98, action)
    }
}

/// The opened panel: every measurement, the wall areas table, doors and windows (prototype ed2List).
private struct FullList: View {
    let app: AppModel
    let pid: String
    let r: Room
    let f: RoomOps.Focus
    private var ops: RoomOps { RoomOps.shared }

    var body: some View {
        let unit = AppSettings.shared.unit, en = AppSettings.shared.lang == .en, snap = AppSettings.shared.angleSnap
        VStack(alignment: .leading, spacing: 14) {
            Sect(title: tr("ed2.meas")) {
                ForEach(ops.measureKeys(r), id: \.self) { k in
                    let d = r.dim(k), st = d.status, on = f.k == k
                    HStack(spacing: 10) {
                        T(k, num(13, 700, on ? .white : G.ink)).frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? G.cobalt : G.ink.opacity(0.06)))
                        VStack(alignment: .leading, spacing: 0) {
                            T(ops.dimLabel(k), ui(14.5, 600))
                            T(st == "recv" ? tr("ed2.st.recv") : st == "unset" ? tr("ed2.notMeasured") : tr("ed2.confirmed") + ", " + tr("src." + (d.src ?? "manual")), ui(12.5, 400, G.ink2))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        T(st == "recv" ? Geo.fmtLen(d.pending?.mm, unit, en, full: true) : st == "conf" ? Geo.fmtLen(d.v, unit, en) : "?",
                          num(15.5, 600, st == "recv" ? PC.amber : st == "conf" ? G.ink : G.ink3))
                        switch st {
                        case "recv": SmallBtn(label: tr("ed2.confirm"), primary: true) { ops.confirm(pid, r.id, k) }
                        case "unset": SmallBtn(label: tr("ed2.measure"), primary: false) { ops.focus(r.id, k) }
                        default: MIcon("check", PC.okGreen, 18, 2.4)
                        }
                    }
                    .padding(.vertical, 6).frame(minHeight: 52)
                    .contentShape(Rectangle())
                    .onTapGesture { if st == "conf" { ops.focus(r.id, k) } }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("row." + k)
                }
            }
            Sect(title: tr("ed2.walls")) {
                if let H = r.dim("H").v {
                    let ws = Geo.walls(r, snap)
                    let stats = ws.map { w in Geo.wallStats(w.len, H, r.openings.filter { $0.wall == w.id }) }
                    HStack(spacing: 0) {
                        T(tr("ed2.colWall"), ui(12, 500, G.ink3)).frame(maxWidth: .infinity, alignment: .leading)
                        T(tr("ed2.colGross"), ui(12, 500, G.ink3)).frame(width: 66, alignment: .trailing)
                        T(tr("ed2.colOpen"), ui(12, 500, G.ink3)).frame(width: 58, alignment: .trailing)
                        T(tr("ed2.colNet"), ui(12, 500, G.ink3)).frame(width: 66, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    ForEach(Array(ws.enumerated()), id: \.offset) { i, wl in
                        let s = stats[i]
                        Hairline()
                        HStack(spacing: 0) {
                            T(wl.id + (wl.derived && !r.isPoly ? " =" : ""), num(14, 600)).frame(maxWidth: .infinity, alignment: .leading)
                            T(s.gross.map { Geo.fmtArea($0, en) } ?? "?", num(14, 500)).frame(width: 66, alignment: .trailing)
                            T(s.open > 0 ? Geo.fmtArea(s.open, en) : "—", num(14, 500, G.ink2)).frame(width: 58, alignment: .trailing)
                            T(s.net.map { Geo.fmtArea($0, en) } ?? "?", num(14, 700)).frame(width: 66, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                    }
                    // the sides of columns and niches add wall to paint: their own row, so the total is the room's net area
                    let extra: Int64 = r.features.isEmpty || !stats.allSatisfy({ $0.gross != nil }) ? 0
                        : (Geo.areas(r, snap)?.gross).map { (g: Int64) -> Int64 in g - stats.reduce(Int64(0)) { $0 + ($1.gross ?? 0) } } ?? 0
                    if extra != 0 {
                        Hairline()
                        HStack(spacing: 0) {
                            T(tr("ao.col"), ui(14, 600)).frame(maxWidth: .infinity, alignment: .leading)
                            T(Geo.fmtArea(extra, en), num(14, 500)).frame(width: 66, alignment: .trailing)
                            T("—", num(14, 500, G.ink2)).frame(width: 58, alignment: .trailing)
                            T(Geo.fmtArea(extra, en), num(14, 700)).frame(width: 66, alignment: .trailing)
                        }
                        .padding(.vertical, 8)
                    }
                    if stats.allSatisfy({ $0.gross != nil }) {
                        HStack(spacing: 0) {
                            T(tr("ed2.total"), ui(14, 700)).padding(.leading, 4).frame(maxWidth: .infinity, alignment: .leading)
                            T(Geo.fmtArea(stats.reduce(0) { $0 + $1.gross! } + extra, en), num(14, 600)).frame(width: 66, alignment: .trailing)
                            T(Geo.fmtArea(stats.reduce(0) { $0 + $1.open }, en), num(14, 600, G.ink2)).frame(width: 58, alignment: .trailing)
                            T(Geo.fmtArea(stats.reduce(0) { $0 + ($1.net ?? 0) } + extra, en), num(14, 800)).frame(width: 66, alignment: .trailing)
                        }
                        .padding(.vertical, 8).background(RoundedRectangle(cornerRadius: 8).fill(G.ink.opacity(0.05)))
                    }
                } else {
                    T(tr("ed2.needH"), ui(13, 400, G.ink2)).padding(.vertical, 6)
                }
            }
            Sect(title: tr("ed2.ops")) {
                ForEach(r.openings) { o in
                    HStack(spacing: 10) {
                        MIcon(o.type, G.ink, 18, 2).frame(width: 30, height: 30).background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(G.ink.opacity(0.06)))
                        VStack(alignment: .leading, spacing: 0) {
                            T(ops.opName(o) + ", " + tr("op.wall") + " " + o.wall, ui(14.5, 600))
                            T(tr("wv.off", ["c": Geo.wallCorner(r, o.wall, snap), "v": (o.approx ? "≈ " : "") + Geo.fmtLen(o.off, unit, en) + " " + unitName()]), ui(12.5, 400, o.approx ? PC.amber : G.ink2))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        T(Geo.fmtLen(o.w, unit, en) + " × " + Geo.fmtLen(o.h, unit, en), num(15.5, 600))
                        MIcon("chev", G.ink3, 16, 2)
                    }
                    .padding(.vertical, 6).frame(minHeight: 52)
                    .pressable(0.99) { app.sheet = .openingForm(pid: pid, rid: r.id, oid: o.id, type: o.type, wall: nil) }
                }
                HStack(spacing: 6) { MIcon("plus", G.cobalt, 18, 2.2); T(tr("ed2.add"), ui(14, 600, G.cobalt)) }
                    .frame(minHeight: 44)
                    .pressable(0.97) { app.sheet = .addOpening(pid: pid, rid: r.id) }
            }
        }
        .padding(.top, 12)
    }
}

private struct Sect<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            T(title, ui(12, 600, G.ink3, ls: 0.05)).padding(.bottom, 4)
            content
        }
    }
}

private struct SmallBtn: View {
    let label: String
    let primary: Bool
    let action: () -> Void
    var body: some View {
        T(label, ui(13, 600, primary ? .white : G.ink), lines: 1)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(primary ? G.cobalt : G.ink.opacity(0.06)))
            .pressable(0.96, action)
    }
}

/* ---------------- the tools row: Plan, Walls, Openings, 3D ---------------- */

private struct Tools: View {
    let app: AppModel
    let pid: String
    let r: Room
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 33, style: .continuous)
        HStack(spacing: 4) {
            Tool(icon: "room", label: tr("ed2.plan"), on: true) {}
            Tool(icon: "walls", label: tr("ed.tb.walls"), on: false) { app.push(.wallView(pid: pid, rid: r.id, wall: Geo.walls(r, AppSettings.shared.angleSnap).first!.id)) }
                .accessibilityIdentifier("ed.walls")
            Tool(icon: "door", label: tr("ed.tb.openings"), on: false) { app.sheet = .addOpening(pid: pid, rid: r.id) }
                .accessibilityIdentifier("ed.openings")
            Tool(icon: "cube", label: "3D", on: false) { open3D(pid, r.id) }
                .accessibilityIdentifier("ed.3d")
        }
        .padding(6).frame(height: 66)
        .glassBlur(shape, tint: G.sheet(0.5))
        .topHighlight(shape, 0.95)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.1), blur: 30, y: -10))
        .padding(.horizontal, 12).padding(.bottom, 12)
    }
}

private struct Tool: View {
    let icon: String
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        let bubble = RoundedRectangle(cornerRadius: 27, style: .continuous)
        VStack(spacing: 3) {
            MIcon(icon, on ? G.cobalt2 : G.slate, 22, 2)
            T(label, ui(11, on ? 700 : 600, on ? G.cobalt2 : G.slate), lines: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(bubble.fill(on ? G.glass(0.9) : .clear))
        .background(bubble.fill(Color.black.opacity(0.001)).boxShadow(on ? G.shade.opacity(0.12) : .clear, blur: 12, y: 4))
        .pressable(0.96, action)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }
}

/* ---------------- the first-time tip (prototype hint.editor) ---------------- */

private struct EditorTip: View {
    @State private var dont = false
    private func ok() { RoomOps.shared.tipSeen = true; if dont { AppSettings.shared.hideEditorTip() } }
    var body: some View {
        ZStack {
            G.scrim.ignoresSafeArea().onTapGesture {}
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    T(tr("hint.title"), ui(13, 700, G.cobalt)).frame(maxWidth: .infinity, alignment: .leading)
                    MIcon("x", G.ink2, 20, 2).frame(width: 40, height: 40).pressable(0.94, label: tr("common.close"), ok)
                }
                // a wall with an unconfirmed reading and a finger tapping it
                Canvas { ctx, size in
                    let y = size.height * 0.62
                    ctx.line(PC.ink, CGPoint(x: size.width * 0.12, y: y), CGPoint(x: size.width * 0.88, y: y), 8)
                    let pill = Path(roundedRect: CGRect(x: size.width / 2 - 34, y: y - 40, width: 68, height: 26), cornerRadius: 13)
                    ctx.fill(pill, with: .color(G.amberWash)); ctx.stroke(pill, with: .color(PC.amber), lineWidth: 1.5)
                    ctx.disc(G.cobalt.opacity(0.25), 16, CGPoint(x: size.width / 2 + 40, y: y + 4))
                    ctx.disc(G.cobalt, 6, CGPoint(x: size.width / 2 + 40, y: y + 4))
                }
                .frame(height: 96)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.shared.dark ? Color(argb: 0xFF10141E) : Color(argb: 0xFFF1F4FB)))
                T(tr("hint.editor.t"), ui(18, 800))
                T(tr("hint.editor.b"), ui(14.5, 400, G.ink2, lh: 1.45))
                HStack(spacing: 10) { MIcon(dont ? "boxok" : "box", G.cobalt, 22, 2); T(tr("hint.dont"), ui(14, 500)) }
                    .padding(.vertical, 4)
                    .pressable(0.98) { dont.toggle() }
                    .accessibilityAddTraits(dont ? [.isSelected] : [])
                GBtn(tr("hint.ok"), ok).accessibilityIdentifier("tip.ok")
            }
            .padding(18)
            .frame(maxWidth: 360)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(G.sheet(0.96)))
            .padding(24)
        }
        .transition(.opacity)
    }
}
