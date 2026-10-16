import SwiftUI

private let KIND_IC = ["room": "room", "drawing": "pen", "photo": "camera", "note": "note"]

/// A workspace: its rooms, then drawings, photos and notes, as cards (prototype PAGES.space).
struct SpaceScreen: View {
    let app: AppModel
    let pid: String
    let wid: String

    var body: some View {
        if let p = Store.shared.get(pid), let w = p.floors.first(where: { $0.id == wid }) {
            let items = w.items.sorted { $0.created > $1.created }
            let blank = items.isEmpty && !p.rooms.contains { $0.floorId == w.id }
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        BackLink(text: dn(p.name)) { app.pop() }
                        Spacer()
                        GlassIconButton("more", "menu") { app.sheet = .spaceMenu(pid: p.id, wid: w.id) }.accessibilityIdentifier("space.menu")
                    }
                    .padding(.leading, 8).padding(.trailing, 12).frame(minHeight: 64)
                    HStack(spacing: 12) {
                        MIcon(wsIcon(w.type), G.cobalt, 22, 2).frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 0) {
                            T(floorName(w), ui(24, 700, G.ink, lh: 1.15, ls: -0.01), lines: 1)
                            let typeName = tr("ws.t." + w.type)
                            T(floorName(w) == typeName ? tr("ws.one") : typeName, ui(13, 400, G.ink2))
                        }
                    }
                    .padding(.horizontal, 36).padding(.bottom, 10)
                    let wsRooms = p.rooms.filter { $0.floorId == w.id }.sorted { $0.created > $1.created }
                    if !wsRooms.isEmpty { WsNums(rooms: wsRooms) }
                    if blank {
                        VStack(spacing: 8) {
                            BlankSheet().padding(.bottom, 6)
                            T(tr("ws.blankT"), ui(18, 600, G.ink, lh: 1.4), align: .center)
                            T(tr("ws.blankB"), ui(14.5, 400, G.ink2, lh: 1.4), align: .center)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.top, 64)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                if !wsRooms.isEmpty {
                                    Section1(title: tr("ws.secRooms"), n: wsRooms.count) {
                                        // the dashed add tile closes the rooms grid when there is nothing else
                                        let cells: [Room?] = wsRooms + (items.isEmpty ? [nil] : [])
                                        ForEach(0..<((cells.count + 1) / 2), id: \.self) { r in
                                            HStack(spacing: 12) {
                                                ForEach(0..<2, id: \.self) { c in
                                                    let i = r * 2 + c
                                                    if i < cells.count {
                                                        if let rm = cells[i] { RoomCard(app: app, p: p, r: rm) }
                                                        else { AddTile { app.sheet = .addItem(pid: p.id, wid: w.id, step: "root") } }
                                                    } else { Color.clear.frame(maxWidth: .infinity) }
                                                }
                                            }
                                        }
                                    }
                                }
                                if !items.isEmpty {
                                    Section1(title: tr("ws.secOther"), n: items.count) {
                                        // two cards a row; the dashed "Qo‘shish" tile comes last
                                        let cells: [Item?] = items + [nil]
                                        ForEach(0..<((cells.count + 1) / 2), id: \.self) { r in
                                            HStack(spacing: 12) {
                                                ForEach(0..<2, id: \.self) { c in
                                                    let i = r * 2 + c
                                                    if i < cells.count {
                                                        if let it = cells[i] { ItemCard(app: app, p: p, w: w, it: it) }
                                                        else { AddTile { app.sheet = .addItem(pid: p.id, wid: w.id, step: "root") } }
                                                    } else { Color.clear.frame(maxWidth: .infinity) }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16).padding(.top, 2).padding(.bottom, 104)
                        }
                    }
                }
                if blank && app.sheet == nil {
                    // the dashed arrow from the empty state to the add button
                    Canvas { ctx, size in
                        var c = ctx; let k = size.width / 96; c.scaleBy(x: k, y: k)
                        let st = StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [6, 6])
                        c.stroke(SVGPath.path("M6 6C20 50 46 66 82 70"), with: .color(Color.white.opacity(0.8)), style: st)
                        c.stroke(SVGPath.path("M72 60l12 10-14 6"), with: .color(Color.white.opacity(0.8)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                    .frame(width: 96, height: 80)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .offset(x: -3, y: -54)
                    .accessibilityHidden(true)
                    HStack(spacing: 6) { MIcon("plus", .white, 22, 2.4); T(tr("ws.add"), ui(15, 600, .white)) }
                        .padding(.leading, 16).padding(.trailing, 20).frame(height: 54)
                        .background(Capsule().fill(G.cobalt))
                        .boxShadow(Color(argb: 0x591C4BD1), blur: 20, y: 8)
                        .pressable(0.96) { app.sheet = .addItem(pid: p.id, wid: w.id, step: "root") }
                        .padding(.trailing, 15).padding(.bottom, 16)
                        .accessibilityIdentifier("space.add")
                }
            }
        }
    }
}

private struct Section1<Content: View>: View {
    let title: String
    let n: Int
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) { T(title, ui(15.5, 600)); CountPill(n: n) }.padding(.horizontal, 2)
            VStack(spacing: 12) { content }
        }
    }
}

/// The workspace's own totals: net wall, floor, measurements confirmed ("+?" while some rooms lack values).
private struct WsNums: View {
    let rooms: [Room]
    var body: some View {
        let t = totals()
        HStack(spacing: 8) {
            NumTile(label: tr("pl.wall"), value: t.0, unit: "m²")
            NumTile(label: tr("ws.floor"), value: t.1, unit: "m²")
            NumTile(label: tr("pl.meas"), value: t.2, unit: nil)
        }
        .padding(.horizontal, 16).padding(.bottom, 12)
    }
    private func totals() -> (String, String, String) {
        let en = AppSettings.shared.lang == .en, snap = AppSettings.shared.angleSnap
        var net: Int64 = 0, nn = 0, fl: Int64 = 0, fn = 0, need = 0, conf = 0
        for r in rooms {
            if let a = Geo.areas(r, snap) { fl += a.floor; fn += 1; if let n = a.net { net += n; nn += 1 } }
            let ks = Geo.stepKeys(r, snap); need += ks.count; conf += ks.filter { r.dim($0).status == "conf" }.count
        }
        func v(_ sum: Int64, _ n: Int) -> String { n > 0 ? Geo.fmtArea(sum, en) + (n < rooms.count ? " +?" : "") : "?" }
        return (v(net, nn), v(fl, fn), need > 0 ? "\(conf)/\(need)" : "—")
    }
}

private struct NumTile: View {
    let label: String
    let value: String
    let unit: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            T(label, ui(11.5, 400, G.ink2), lines: 1)
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(value).st(num(17, 800)).lineLimit(1)
                if let unit, value != "?" && value != "—" { T(" " + unit, ui(11, 600, G.ink2)) }
            }
        }
        .padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(G.glass(0.45)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
    }
}

/// A room plan card: a small plan with its sizes, the kind, the name and the next step or the net wall area.
private struct RoomCard: View {
    let app: AppModel
    let p: Project
    let r: Room
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let nx = RoomOps.shared.next(r)
        let c: Color = nx.cls == "ok" ? (Theme.shared.dark ? G.green : Color(argb: 0xFF15803D)) : nx.cls == "recv" ? G.amberInk : nx.cls == "bad" ? G.err : G.ink2
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                RoomThumb(r: r, detailed: true).padding(.top, 8).frame(maxWidth: .infinity).frame(height: 129).background(Color.white)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) { MIcon("room", G.ink3, 15, 2); T(tr("it.k.room"), ui(12, 400, G.ink3), lines: 1) }
                    T(dn(r.name), ui(14.5, 600, G.ink, lh: 1.25), lines: 1)
                    HStack(spacing: 4) { MIcon(nx.icon, c, 13, 2.2); T(nx.text, ui(12.5, 400, c), lines: 1) }
                }
                .padding(.leading, 10).padding(.trailing, 42).padding(.top, 8).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture { app.push(.editor(pid: p.id, rid: r.id, mode: "plan")) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("room.card")
            MIcon("more", G.ink, 18, 2).frame(width: 44, height: 44).pressable(0.95, label: "menu") { app.sheet = .roomMenu(pid: p.id, rid: r.id) }
                .padding(.bottom, 4)
                .accessibilityIdentifier("room.menu")
        }
        .overlay(alignment: .topLeading) {
            if p.reportRooms[r.id] != false {
                Text("PDF").st(num(10.5, 600, .white, ls: 0.06)).padding(.horizontal, 6).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(argb: 0xCC0E1C36))).padding(8)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 205)
        .clipShape(shape)
        .glassCard(shape, shadowBlur: 24, shadowY: 10, shadowAlpha: 0.1)
    }
}

/// The dashed sheet of paper on an empty workspace (88 × 104).
private struct BlankSheet: View {
    var body: some View {
        Canvas { ctx, size in
            var c = ctx; let k = size.width / 88; c.scaleBy(x: k, y: k)
            let body = SVGPath.path("M8 6h52l20 20v72H8z")
            c.fill(body, with: .color(G.solid))
            let dash = StrokeStyle(lineWidth: 2, dash: [5, 4])
            c.stroke(body, with: .color(Color(argb: 0xFFC3CEDF)), style: dash)
            c.stroke(SVGPath.path("M60 6v20h20"), with: .color(Color(argb: 0xFFC3CEDF)), style: dash)
        }
        .frame(width: 88, height: 104)
        .accessibilityHidden(true)
    }
}

/// A card for a note (its text and checklist), a drawing or a photo (its picture with the marks).
private struct ItemCard: View {
    let app: AppModel
    let p: Project
    let w: Workspace
    let it: Item
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    if it.kind == "note" {
                        if !it.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { T(dn(it.text), ui(12.5, 400, G.ink2, lh: 1.35), lines: 4) }
                        if !it.checks.isEmpty {
                            HStack(spacing: 4) {
                                MIcon("boxok", G.cobalt, 15, 2)
                                T(tr("it.items", ["d": it.checks.filter(\.done).count, "n": it.checks.count]), ui(12.5, 600, G.cobalt))
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12).padding(.top, 32).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading).frame(height: 129)
                .background { if it.kind != "note" { MarkThumb(it: it) } }
                .background(it.kind == "note" ? G.noteWash : it.kind == "photo" ? Color(argb: 0xFF0E1C36) : Color.white)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) { MIcon(KIND_IC[it.kind] ?? "note", G.ink3, 15, 2); T(tr("it.k." + it.kind), ui(12, 400, G.ink3), lines: 1) }
                    T(itemName(it), ui(14.5, 600, G.ink, lh: 1.25), lines: 1)
                    T(fmtDate(it.edited > 0 ? it.edited : it.created), ui(12.5, 400, G.ink2))
                }
                .padding(.leading, 10).padding(.trailing, 42).padding(.top, 8).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture { if it.kind == "note" { app.push(.note(pid: p.id, wid: w.id, iid: it.id)) } else { app.push(.markup(pid: p.id, iid: it.id)) } }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("item." + it.kind)
            MIcon("more", G.ink, 18, 2).frame(width: 44, height: 44).pressable(0.95, label: "menu") { app.sheet = .itemMenu(pid: p.id, wid: w.id, iid: it.id) }
                .padding(.bottom, 4)
        }
        .overlay(alignment: .topLeading) {
            if it.inReport {
                Text("PDF").st(num(10.5, 600, .white, ls: 0.06)).padding(.horizontal, 6).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(argb: 0xCC0E1C36))).padding(8)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 205)
        .clipShape(shape)
        .glassCard(shape, shadowBlur: 24, shadowY: 10, shadowAlpha: 0.1)
    }
}

private struct AddTile: View {
    let action: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            MIcon("plus", .white, 24, 2.4).frame(width: 52, height: 52).background(Circle().fill(G.cobalt)).boxShadow(G.cobalt.opacity(0.35), blur: 22, y: 10)
            T(tr("gl.add"), ui(15, 700, G.cobalt2))
        }
        .frame(maxWidth: .infinity).frame(height: 205)
        .dashedGlass(24)
        .pressable(0.98, action)
        .accessibilityIdentifier("space.addTile")
    }
}

/* ---------------- Note: a title, text and a checklist (prototype PAGES.note) ---------------- */

private enum NoteF: Hashable { case title, text, check(String) }

struct NoteScreen: View {
    let app: AppModel
    let pid: String
    let wid: String
    let iid: String
    @State private var title = ""
    @State private var text = ""
    @State private var checkTexts: [String: String] = [:]
    @State private var loaded = false
    @FocusState private var focus: NoteF?

    private func change(_ f: (inout Item) -> Void) {
        Store.shared.update(pid) { pr in
            guard let wi = pr.floors.firstIndex(where: { $0.id == wid }), let ii = pr.floors[wi].items.firstIndex(where: { $0.id == iid }) else { return }
            f(&pr.floors[wi].items[ii]); pr.floors[wi].items[ii].edited = nowMs()
        }
    }

    var body: some View {
        if let p = Store.shared.get(pid), let w = p.floors.first(where: { $0.id == wid }), let it = w.items.first(where: { $0.id == iid }) {
            let done = it.checks.filter(\.done).count
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back")) { focus = nil; app.pop() }.padding(.leading, 6)
                    BarTitle(title: tr("it.k.note"), sub: floorName(w))
                    GlassIconButton("more", "menu") { app.sheet = .itemMenu(pid: p.id, wid: w.id, iid: it.id) }
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GField(label: tr("nt.title"), value: Binding(get: { title }, set: { v in title = v; change { $0.name = v.trimmingCharacters(in: .whitespaces) } }),
                               placeholder: tr("nt.titlePh"), focus: $focus, me: .title, onSubmit: { focus = .text })
                        GField(label: tr("nt.text"), value: Binding(get: { text }, set: { v in text = v; change { $0.text = v } }),
                               placeholder: tr("nt.textPh"), focus: $focus, me: .text, multiline: true)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                T(tr("nt.list"), ui(15, 700)).frame(maxWidth: .infinity, alignment: .leading)
                                if !it.checks.isEmpty { T(tr("it.items", ["d": done, "n": it.checks.count]), ui(13, 500, G.ink3)) }
                            }
                            ForEach(it.checks) { c in
                                HStack(spacing: 2) {
                                    MIcon(c.done ? "boxok" : "box", G.cobalt, 22, 2).frame(width: 44, height: 44)
                                        .pressable(0.95, label: c.done ? "✓" : "☐") { change { x in if let k = x.checks.firstIndex(where: { $0.id == c.id }) { x.checks[k].done.toggle() } } }
                                    GField(label: nil, value: Binding(get: { checkTexts[c.id] ?? dn(c.text) }, set: { v in
                                        checkTexts[c.id] = v; change { x in if let k = x.checks.firstIndex(where: { $0.id == c.id }) { x.checks[k].text = v } }
                                    }), placeholder: tr("nt.itemPh"), focus: $focus, me: .check(c.id), submit: .done, onSubmit: { focus = nil }, done: c.done)
                                    MIcon("x", G.ink2, 20, 2).frame(width: 44, height: 44)
                                        .pressable(0.95, label: tr("common.delete")) { change { x in x.checks.removeAll { $0.id == c.id } } }
                                }
                            }
                            GBtn(tr("nt.add"), kind: .secondary, icon: "plus", height: 44, corner: 12, fontSize: 14, fill: false) {
                                let c = Check(id: uid()); change { $0.checks.append(c) }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focus = .check(c.id) }
                            }
                            .accessibilityIdentifier("note.addCheck")
                        }
                        HStack(spacing: 12) {
                            MIcon("doc", G.cobalt, 20, 2).frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.12)))
                            T(tr("it.report"), ui(15.5, 500)).frame(maxWidth: .infinity, alignment: .leading)
                            GSwitch(on: it.inReport).padding(.trailing, 8)
                        }
                        .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 8).frame(minHeight: 56)
                        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
                        .pressable(0.99) { change { $0.rep = !$0.inReport } }
                        .accessibilityAddTraits(.isToggle)
                    }
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                title = dn(it.name); text = dn(it.text)
                // a fresh note starts with the cursor in its title
                if it.name.isEmpty && it.text.isEmpty && it.checks.isEmpty { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = .title } }
            }
        }
    }
}
