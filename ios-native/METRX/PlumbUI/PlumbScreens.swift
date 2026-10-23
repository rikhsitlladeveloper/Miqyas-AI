import SwiftUI

/*
 * The plumber's own app (22 Oct 2026, built like the electrician's; Android ui/plumb/PlumbScreens.kt): the Home with new
 * orders, an order's rooms with their fixtures, the next step, and in the advanced app the pipe, fittings, valves and
 * labour going into the estimate. The order's changes and shared helpers are in PlumbOps.swift, the sheets in
 * PlumbSheets.swift.
 */

private let PS_RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private let PS_ARROW = "M7 17L17 7M9 7h8v8"

private var psEn: Bool { AppSettings.shared.lang == .en }

/* ---------------- Home ---------------- */

struct PlumbHome: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        let first = s.builderName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let lines = tr("sx.lines").split(separator: "|").map(String.init)
        let orders = Store.shared.projects.filter(\.isPlumb).sorted { $0.created > $1.created }
        VStack(spacing: 0) {
            GlassHeader { app.sheet = .device }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        T(first.isEmpty ? tr("hm.hi0") : tr("hm.hi", ["n": first]), ui(34, 800, G.ink, lh: 1.1, ls: -0.02)).accessibilityAddTraits(.isHeader)
                        T(lines.isEmpty ? "" : lines[s.visit % lines.count], ui(17, 500, G.slate, lh: 1.35)).frame(maxWidth: 320, alignment: .leading)
                    }
                    .padding(.top, 18).padding(.bottom, 8)
                    newCard
                    HStack(spacing: 12) {
                        PSTile(icon: PS_RULER, title: tr("gl.meas"), sub: tr("gl.measS")) { app.push(.measure(calc: false)) }.accessibilityIdentifier("home.measure")
                        // the gallery needs an order: a new one, as on the big card
                        PSTile(icon: TAP, title: tr("el.gal"), sub: tr("sx.galS")) { app.push(.newProject(editId: nil)) }.accessibilityIdentifier("home.pGallery")
                    }
                    HStack {
                        T(tr("fo.recent"), ui(17, 800)).frame(maxWidth: .infinity, alignment: .leading)
                        if !orders.isEmpty { T(tr("fo.all"), ui(13.5, 700, G.cobalt2)).padding(.horizontal, 6).padding(.vertical, 8).pressable(0.97) { app.selectTab(.projects) } }
                    }
                    .padding(.top, 6)
                    if orders.isEmpty { T(tr("fo.noOrders"), ui(14, 400, G.ink2, lh: 1.45)) }
                    ForEach(orders.prefix(3)) { p in POrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                }
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24 + NAV_SPACE)
            }
        }
    }

    private var newCard: some View {
        let big = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return HStack(spacing: 14) {
            MIcon("plus", .white, 26, 2.4).frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.cobalt))
                .boxShadow(G.cobalt.opacity(0.4), blur: 22, y: 10)
            VStack(alignment: .leading, spacing: 2) { T(tr("fo.new"), ui(22, 800, G.ink, lh: 1.15, ls: -0.01)); T(tr("sx.newS"), ui(14, 400, G.ink2)) }
                .frame(maxWidth: .infinity, alignment: .leading)
            PathIcon(PS_ARROW, G.ink, 20, 2.2)
        }
        .padding(18)
        .glassCard(big, shadowBlur: 36, shadowY: 16, shadowAlpha: 0.15)
        .pressable(0.985) { app.push(.newProject(editId: nil)) }
        .accessibilityElement(children: .combine).accessibilityIdentifier("home.new")
    }
}

private struct PSTile: View {
    let icon: String
    let title: String
    let sub: String
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PathIcon(icon, G.cobalt, 24, 2)
            Spacer(minLength: 18)
            T(title, ui(17, 700)); T(sub, ui(12.5, 400, G.ink2))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .glassCard(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
    }
}

/// A plumber's order in a list: its name, its fixtures; the call button.
struct POrderRow: View {
    let p: Project
    let action: () -> Void
    private var sub: String {
        let e = p.plumb
        if e.fixes.isEmpty && e.free.isEmpty { return tr("sx.noFix") }
        let fx = fixSummary(e.fixes.filter { $0.t != "manif" })
        let fr: String = e.free.isEmpty ? "" : " · " + tr("el.freeN", ["n": e.free.count])
        return fx + fr
    }
    var body: some View {
        HStack(spacing: 12) {
            PathIcon(TAP, G.cobalt, 22, 2)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) {
                T(dn(p.name), ui(15, 700), lines: 1)
                T(sub, ui(12.5, 500, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            CallButton(p: p)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/* ---------------- the order's rooms ---------------- */

struct PRoomsTab: View {
    let app: AppModel
    let p: Project
    var view = "list"
    var body: some View {
        let calc = PlumbCalcCache.shared.of(p)
        let pid = p.id
        VStack(spacing: 10) {
            if p.floors.isEmpty && p.plumb.free.isEmpty {
                T(tr("sx.empty"), ui(14.5, 400, G.ink2), align: .center).padding(22).frame(maxWidth: .infinity)
                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            }
            if !calc.ctxs.isEmpty { PSOrderCard(app: app, p: p, calc: calc) }
            // every room of each workspace (an older project may have several in one), a workspace without one once
            ForEach(wsRooms(p)) { s in PSRoomCard(app: app, p: p, w: s.w, room: s.room, several: s.several, calc: calc) }
            // rooms typed by size, without a plan
            if !p.plumb.free.isEmpty { freeCard }
            HStack(spacing: 8) {
                dashed("plus", tr("el.addKit"), "sx.addKit") { app.push(.pGallery(pid: pid)) }
                dashed("room", tr("fo.addRoom"), "sx.addRoom") { app.sheet = .pNewRoom(pid: pid) }
            }
            T(tr("el.addFree"), ui(14, 700, G.cobalt2)).padding(.horizontal, 14).padding(.vertical, 10)
                .pressable(0.97) { app.sheet = .pFree(pid: pid, fid: nil) }
                .accessibilityAddTraits(.isButton).accessibilityIdentifier("sx.addFree")
            if !p.rooms.isEmpty && view == "list" {
                GBtn(tr("pj.v2d"), kind: .secondary, icon: "room", height: 46, fontSize: 14.5) { app.setProjectView("2d") }.accessibilityIdentifier("pj.v2d")
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
        // kits chosen before a room was measured go in now that it is
        // the rooms' water and drain marks are taken in as outlets here too (not only when a room's page opens), so the
        // order's counts, its next step and the PDF have them
        .onAppear { takeInAllPlumb(pid); applyPPending(app, pid) }
        .onChange(of: p.rooms) { _, _ in takeInAllPlumb(pid); applyPPending(app, pid) }
    }

    private func takeInAllPlumb(_ pid: String) {
        guard let p = Store.shared.get(pid) else { return }
        for r in p.rooms { takeInPlumbPoints(pid, r.id) }
    }

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            T(tr("el.freeT"), ui(16, 700))
            ForEach(p.plumb.free) { f in PSFreeLine(f: f) { app.push(.pView(pid: p.id, rid: "free:" + f.id)) } }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    private func dashed(_ icon: String, _ label: String, _ id: String, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) { MIcon(icon, G.cobalt2, 20, 2.2); T(label, ui(15, 700, G.cobalt2), lines: 1) }
            .frame(maxWidth: .infinity).frame(height: 56)
            .dashedGlass(20)
            .pressable(0.98, action)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(id)
    }
}

/// A room typed by size in the order's list.
private struct PSFreeLine: View {
    let f: PlFree
    let action: () -> Void
    var body: some View {
        let size: String = Geo.fmtLen(f.L, .m, psEn) + " × " + Geo.fmtLen(f.W, .m, psEn) + U_M + " · "
        let cnt = tr("sx.freeCnt", ["n": freeCount(f), "m": Geo.fmtLen(f.link, .m, psEn)])
        let nm: String = dn(f.name).trimmingCharacters(in: .whitespaces).isEmpty ? tr(pKindKey(f.kind)) : dn(f.name)
        HStack(spacing: 10) {
            MIcon("cube", G.cobalt, 18, 2)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                T(nm, ui(14.5, 700), lines: 1)
                T(size + cnt, ui(12.5, 500, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.75)))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// One workspace of a plumber's order: its room, its fixtures, what to do next.
private struct PSRoomCard: View {
    let app: AppModel
    let p: Project
    let w: Workspace
    let room: Room?
    var several = false
    let calc: PlumbCalc
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let ready = room.map { Geo.ready3D($0, snap) } ?? false
        let fs: [PlFix] = room.map { r in p.plumb.fixes.filter { $0.roomId == r.id } } ?? []
        let er = room.map { p.plumb.room($0.id) }
        let ufh = er?.ufh ?? false
        VStack(alignment: .leading, spacing: 10) {
            head(room, ready)
            if let room, !fs.isEmpty || ufh { fixLine(room, fs, ufh) }
            if let er, !er.pend.isEmpty {
                T(tr("el.pending", ["k": er.pend.map { tr("sx.kit." + $0.kit) }.joined(separator: ", ")]), ui(12.5, 500, G.amberInk, lh: 1.35))
            }
            if let room {
                if !ready { TodoRow(label: tr("ns.measureT")) { openRoom(app, p.id, room.id) } }
                else { TodoRow(label: tr("el.addKit")) { app.push(.pGallery(pid: p.id, rid: room.id)) } }
            } else {
                TodoRow(label: tr("fo.drawRoom")) { drawTileRoom(app, p.id, w) }
            }
        }
        .padding(12)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    private func subOf(_ room: Room?, _ ready: Bool) -> String {
        let a = room?.dim("A").v, b = room?.dim("B").v, h = room?.dim("H").v
        if ready, let a, let b, room?.isPoly != true {
            let hs: String = h.map { " · h " + Geo.fmtLen($0, .m, psEn) } ?? ""
            return Geo.fmtLen(a, .m, psEn) + " × " + Geo.fmtLen(b, .m, psEn) + U_M + hs
        }
        if ready { return tr("tl.measured") }
        return tr(room != nil ? "fo.notMeasured" : "fo.notDrawn")
    }

    private func head(_ room: Room?, _ ready: Bool) -> some View {
        let sub = subOf(room, ready)
        return HStack(spacing: 12) {
            Group {
                if let room { RoomThumb(r: room).padding(4) } else { MIcon("room", G.cobalt, 24, 2) }
            }
            .frame(width: 64, height: 52)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(Theme.shared.dark ? 0.1 : 0.8)))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                T(wsRoomTitle(w, room, several), ui(16, 700), lines: 1)
                T(sub, ui(12.5, 400, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if ready {
                T("3D", ui(13, 800, G.cobalt2)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(G.cobalt.opacity(0.1)))
            }
            MIcon("chev", G.ink3, 16, 2)
        }
        .contentShape(Rectangle())
        .pressable(0.99) {
            if let room { if ready { app.push(.pView(pid: p.id, rid: room.id)) } else { openRoom(app, p.id, room.id) } }
            else { app.push(.space(pid: p.id, wid: w.id)) }
        }
    }

    private func fixLine(_ room: Room, _ fs: [PlFix], _ ufh: Bool) -> some View {
        let ws = calc.warns.filter { $0.roomId == room.id }.count
        let riserHere = calc.routes.riser?.roomId == room.id
        var title = fixSummary(fs)
        if ufh { title = (fs.isEmpty ? "" : title + " · ") + tr("sx.s.ufh") }
        return HStack(spacing: 10) {
            PathIcon(TAP, G.cobalt, 18, 2)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(14, 700), lines: 2)
                if ws > 0 { T(tr("el.warnN", ["n": ws]), ui(12.5, 600, G.amberInk)) }
                else if riserHere { T(tr("sx.riserHere"), ui(12.5, 500, G.ink2)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.75)))
        .pressable(0.985) { app.push(.pView(pid: p.id, rid: room.id)) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The order's riser, its pipe system and its warnings.
private struct PSOrderCard: View {
    let app: AppModel
    let p: Project
    let calc: PlumbCalc
    var body: some View {
        let rs = liveRiser(p)
        let rr = rs.flatMap { x in p.rooms.first { $0.id == x.roomId } }
        let riserSub: String = {
            guard let rs, let rr else { return tr("el.panelNone") }
            return pRoomName(p, rr) + " · " + tr("tl.wallN", ["w": rs.wall])
        }()
        let sysSub: String = tr("sx.sys." + p.plumb.water) + " · " + tr("sx.run." + p.plumb.run)
        VStack(spacing: 0) {
            PSLine(icon: "box", title: tr("sx.riser"), sub: riserSub) { riserTap() }
            Hairline()
            PSLine(icon: "layers", title: tr("sx.system"), sub: sysSub) { app.sheet = .pSystem(pid: p.id) }
            if !calc.warns.isEmpty {
                Hairline()
                PSLine(icon: "alert", title: tr("el.warnN", ["n": calc.warns.count]), sub: nil, warn: true) { warnTap() }
            }
        }
        .padding(.vertical, 4)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    private func riserTap() {
        if let rs = liveRiser(p) { app.push(.pView(pid: p.id, rid: rs.roomId)); return }
        if let d = defaultRiser(p, AppSettings.shared.angleSnap) {
            updatePlumb(p.id) { $0.riser = d }
            app.push(.pView(pid: p.id, rid: d.roomId)); app.say("sx.riserSet")
        } else { app.say("el.panelNeed") }
    }

    private func warnTap() {
        let first = calc.warns.first(where: { $0.roomId != nil })?.roomId
        let rid = first ?? liveRiser(p)?.roomId ?? calc.ctxs.first?.id
        if let rid { app.push(.pView(pid: p.id, rid: rid)) }
    }
}

private struct PSLine: View {
    let icon: String
    let title: String
    let sub: String?
    var warn = false
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            MIcon(icon, warn ? G.amberInk : G.ink2, 20, 2)
            T(title, ui(14.5, 700, warn ? G.amberInk : G.ink), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
            if let sub { T(sub, ui(13, 500, G.ink2), align: .trailing, lines: 2).frame(maxWidth: 190, alignment: .trailing) }
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 52)
        .contentShape(Rectangle())
        .pressable(0.99, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/* ---------------- the next step ---------------- */

/// What to do now with a plumber's order, and the one button that does it.
struct PNextStep: View {
    let app: AppModel
    let p: Project
    private struct Step { let title: String; let sub: String?; let button: String; let go: () -> Void }

    /// A measured wet room (bathroom, toilet, kitchen, utility) with nothing in it yet.
    private func isBare(_ r: Room, _ snap: Bool) -> Bool {
        if p.plumb.fixes.contains(where: { $0.roomId == r.id }) { return false }
        let pr = p.plumb.room(r.id)
        if !pr.pend.isEmpty || pr.ufh { return false }
        let kind = pr.kind.isEmpty ? (pCtxOf(p, r.id, snap)?.kind ?? "") : pr.kind
        return ["bath", "wc", "kitchen", "util"].contains(kind)
    }

    private var step: Step? {
        let s = AppSettings.shared, snap = s.angleSnap
        let pid = p.id
        let rooms: [(Workspace, Room)] = roomsByWorkspace(p)
        let undrawn = p.floors.first { w in !p.rooms.contains { $0.floorId == w.id } }
        let unmeasured = rooms.first { wr in Geo.stepKeys(wr.1, snap).contains { wr.1.dim($0).status != "conf" } }
        let bare = rooms.first { wr in isBare(wr.1, snap) }
        let made = madeBy(p, "sx.e.")
        // a typed-room-only order has no wall for a riser: it is not asked for one
        let riser = riserToPlace(p, snap)
        if p.floors.isEmpty && p.plumb.free.isEmpty {
            return Step(title: tr("el.ns.pickT"), sub: tr("sx.ns.pickS"), button: tr("ns.needB")) { app.push(.pGallery(pid: pid)) }
        }
        if let undrawn { return Step(title: tr("ns.measureT"), sub: floorName(undrawn), button: tr("fo.drawRoom")) { drawTileRoom(app, pid, undrawn) } }
        if let u = unmeasured {
            let (w, r) = u
            return Step(title: tr("ns.measureT"), sub: tr("ns.measureS", ["r": floorName(w)]), button: tr("ns.measureB")) { openRoom(app, pid, r.id) }
        }
        if let b = bare {
            let (w, r) = b
            return Step(title: tr("sx.ns.roomT", ["r": floorName(w)]), sub: tr("sx.ns.roomS"), button: tr("ns.needB")) { app.push(.pGallery(pid: pid, rid: r.id)) }
        }
        if riser != nil {
            return Step(title: tr("sx.ns.riserT"), sub: tr("sx.ns.riserS"), button: tr("el.ns.panelB")) {
                guard let cur = Store.shared.get(pid), let d = riserToPlace(cur, snap) else { return }
                updatePlumb(pid) { $0.riser = d }
                app.push(.pView(pid: pid, rid: d.roomId))
            }
        }
        if !s.advanced { return Step(title: tr("ns.shareT"), sub: tr("sx.ns.shareS"), button: tr("ns.shareB")) { app.push(.report(pid: pid, no: nil)) } }
        if !made {
            return Step(title: tr("el.ns.estT"), sub: tr("sx.ns.estS"), button: tr("trc.apply")) {
                if let cur = Store.shared.get(pid) { applyPlumbRows(app, cur) }
                app.setProjectTab("estimate")
            }
        }
        if p.quotes.isEmpty { return Step(title: tr("ns.quoteT"), sub: nil, button: tr("ns.quoteB")) { app.sheet = .issue(pid: pid) } }
        return nil
    }

    var body: some View {
        if let st = step {
            let navy = Color(argb: 0xFF0F1626)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    T(tr("ns.label"), ui(11.5, 600, Color.white.opacity(0.62)))
                    T(st.title, ui(15.5, 800, .white, lh: 1.25), lines: 2)
                    if let sub = st.sub { T(sub, ui(12.5, 500, Color.white.opacity(0.75)), lines: 2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                T(st.button, ui(14, 800, navy), align: .center, lines: 2)
                    .padding(.horizontal, 14).padding(.vertical, 13).frame(minHeight: 46).frame(maxWidth: 150)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white))
                    .pressable(0.97, st.go)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("ns.go")
            }
            .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.shared.dark ? G.blueWash : navy))
            .padding(.horizontal, 16).padding(.top, 12)
        }
    }
}

/* ---------------- the advanced app: counts and the estimate ---------------- */

/// The order page's three numbers in the advanced app: outlets, pipe, the estimate.
struct PNums: View {
    let p: Project
    var body: some View {
        if AppSettings.shared.advanced {
            let lang = AppSettings.shared.lang
            let c = PlumbCalcCache.shared.of(p).count
            let est = Money.short(p, Money.totals(p).g, lang == .en, tr("pl.mln"))
            VStack(spacing: 0) {
                Hairline()
                HStack(spacing: 12) {
                    PSCell(label: tr("sx.points"), value: "\(c.points)", unit: nil)
                    PSCell(label: tr("sx.pipe"), value: Num.fixed(c.pipeM, 0, lang), unit: tr("u.m"))
                    PSCell(label: tr("pl.est"), value: est.0, unit: est.1)
                }
                .padding(.horizontal, 4).padding(.top, 10)
            }
            .padding(.top, 11)
        }
    }
}

private struct PSCell: View {
    let label: String
    let value: String
    let unit: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            T(label, ui(11.5, 400, G.ink2), lines: 1)
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(value).st(num(17, 800)).lineLimit(1)
                if let unit { Text(" " + unit).st(ui(10.5, 600, G.ink2)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The estimate tab's card (in place of the old calculator's): what the fixtures and routes take, and the button that
/// puts it in.
struct PlumbCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let lang = AppSettings.shared.lang
        let c = PlumbCalcCache.shared.of(p).count
        let made = madeBy(p, "sx.e.")
        let can = c.points > 0 || c.ufhM > 0
        VStack(alignment: .leading, spacing: 8) {
            T(tr("sx.cardT"), ui(16, 800))
            T(tr("trc.plumb", ["n": c.points, "m": Num.fixed(c.pipeM, 1, lang)]), num(14.5, 700))
            T(tr("sx.cardB"), ui(12.5, 400, G.ink2, lh: 1.4))
            if c.points == 0 { T(tr("sx.noFix"), ui(13, 500, G.amberInk, lh: 1.4)) }
            HStack(spacing: 8) {
                GBtn(tr(made ? "trc.update" : "trc.apply"), enabled: can, height: 44, corner: 14, fontSize: 14, lines: 2) { applyPlumbRows(app, p) }
                    .accessibilityIdentifier("sx.apply")
                GBtn(tr("tl.prices"), kind: .secondary, icon: "sliders", height: 44, corner: 14, fontSize: 14, lines: 2) { app.sheet = .pPrices(pid: p.id) }
                    .accessibilityIdentifier("sx.prices")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// What the order takes, line by line (the advanced app).
struct PCountCard: View {
    let p: Project
    let c: PCount

    private func d1(_ v: Double) -> String { Num.fixed(v, 1, AppSettings.shared.lang) }

    private func pipeName(_ n: PipeNeed) -> String {
        switch n.kind {
        case "ufh": return tr("sx.c.ufh")
        case "heat": return tr("sx.c.heat", ["d": n.dia])
        default: return tr("sx.c.water", ["s": tr("sx.sys." + p.plumb.water), "d": n.dia])
        }
    }

    private func pipeValue(_ n: PipeNeed) -> String {
        let key = n.unit == "stick" ? "sx.c.sticks" : n.unit == "m" ? "sx.c.metres" : "sx.c.coils"
        return tr(key, ["m": d1(n.m), "s": d1(n.withSpare), "n": n.pieces])
    }

    private func drainValue(_ m: Double, _ bends: Int, _ tees: Int) -> String {
        d1(m) + U_M + " · " + tr("sx.c.bends", ["n": bends, "t": tees])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            T(tr("el.countT"), ui(15, 800))
            ForEach(Array(c.pipes.enumerated()), id: \.offset) { _, n in EKv(k: pipeName(n), v: pipeValue(n)) }
            if c.drain50 > 0 || c.drain110 > 0 {
                Hairline()
                if c.drain110 > 0 { EKv(k: tr("sx.c.drain", ["d": 110]), v: drainValue(c.drain110, c.bends110, c.tees110)) }
                if c.drain50 > 0 { EKv(k: tr("sx.c.drain", ["d": 50]), v: drainValue(c.drain50, c.bends50, c.tees50)) }
            }
            Hairline()
            EKv(k: tr("sx.e.elbow"), v: "\(c.elbows)")
            EKv(k: tr("sx.e.tee"), v: "\(c.tees)")
            if c.couplings > 0 { EKv(k: tr("sx.e.coup"), v: "\(c.couplings)") }
            EKv(k: tr("sx.e.plate"), v: "\(c.plates)")
            EKv(k: tr("sx.e.ball"), v: "\(c.balls)")
            if c.meters > 0 { EKv(k: tr("sx.c.riser"), v: tr("sx.c.riserV", ["n": c.meters])) }
            if c.manifolds > 0 { EKv(k: tr("sx.t.manif"), v: tr("sx.c.loops", ["n": c.loops, "m": d1(c.ufhM)])) }
            if c.chaseM > 0 { EKv(k: tr("sx.c.chase"), v: d1(c.chaseM) + U_M) }
            EKv(k: tr("sx.points"), v: "\(c.points)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }
}
