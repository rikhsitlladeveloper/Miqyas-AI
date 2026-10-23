import SwiftUI

/*
 * The windows-and-doors maker's own app (22 Oct 2026, built like the plumber's; Android ui/win/WinScreens.kt): the Home
 * with new orders, an order's rooms with their openings and the products filling them, the next step, and in the
 * advanced app the parts and labour going into the estimate, priced from a list per profile system. The order's changes
 * and shared helpers are in WinOps.swift, the sheets in WinSheets.swift.
 */

private let WN_RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private let WN_ARROW = "M7 17L17 7M9 7h8v8"

private var wnEn: Bool { AppSettings.shared.lang == .en }

/* ---------------- Home ---------------- */

struct WinHome: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        let first = s.builderName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let lines = tr("dw.lines").split(separator: "|").map(String.init)
        let orders = Store.shared.projects.filter(\.isWin).sorted { $0.created > $1.created }
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
                        WNTile(icon: WN_RULER, title: tr("gl.meas"), sub: tr("gl.measS")) { app.push(.measure(calc: false)) }.accessibilityIdentifier("home.measure")
                        // the gallery needs an order: a new one, as on the big card
                        WNTile(icon: W_WINDOW_ICON, title: tr("dw.gal"), sub: tr("dw.galS")) { app.push(.newProject(editId: nil)) }.accessibilityIdentifier("home.wGallery")
                    }
                    HStack {
                        T(tr("fo.recent"), ui(17, 800)).frame(maxWidth: .infinity, alignment: .leading)
                        if !orders.isEmpty { T(tr("fo.all"), ui(13.5, 700, G.cobalt2)).padding(.horizontal, 6).padding(.vertical, 8).pressable(0.97) { app.selectTab(.projects) } }
                    }
                    .padding(.top, 6)
                    if orders.isEmpty { T(tr("fo.noOrders"), ui(14, 400, G.ink2, lh: 1.45)) }
                    ForEach(orders.prefix(3)) { p in WOrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
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
            VStack(alignment: .leading, spacing: 2) { T(tr("fo.new"), ui(22, 800, G.ink, lh: 1.15, ls: -0.01)); T(tr("dw.newS"), ui(14, 400, G.ink2)) }
                .frame(maxWidth: .infinity, alignment: .leading)
            PathIcon(WN_ARROW, G.ink, 20, 2.2)
        }
        .padding(18)
        .glassCard(big, shadowBlur: 36, shadowY: 16, shadowAlpha: 0.15)
        .pressable(0.985) { app.push(.newProject(editId: nil)) }
        .accessibilityElement(children: .combine).accessibilityIdentifier("home.new")
    }
}

private struct WNTile: View {
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

/// A windows-and-doors order in a list: its name, its products; the call button.
struct WOrderRow: View {
    let p: Project
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            PathIcon(W_WINDOW_ICON, G.cobalt, 22, 2)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) {
                T(dn(p.name), ui(15, 700), lines: 1)
                T(wSummary(p.win.items), ui(12.5, 500, G.ink2), lines: 2)
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

struct WRoomsTab: View {
    let app: AppModel
    let p: Project
    var view = "list"
    var body: some View {
        let calc = WinCalcCache.shared.of(p)
        let pid = p.id
        let free = p.win.items.filter { !$0.inRoom }
        VStack(spacing: 10) {
            if p.floors.isEmpty && p.win.items.isEmpty {
                T(tr("dw.empty"), ui(14.5, 400, G.ink2), align: .center).padding(22).frame(maxWidth: .infinity)
                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            }
            if !p.win.items.isEmpty { WNOrderCard(app: app, p: p, calc: calc) }
            // every room of each workspace (an older project may have several in one), a workspace without one once
            ForEach(wsRooms(p)) { s in WNRoomCard(app: app, p: p, w: s.w, room: s.room, several: s.several, calc: calc) }
            if !free.isEmpty { freeCard(free, calc) }
            HStack(spacing: 8) {
                dashed("plus", tr("dw.addItem"), "dw.addItem") { app.push(.wGallery(pid: pid)) }
                dashed("room", tr("fo.addRoom"), "dw.addRoom") { app.sheet = .wNewRoom(pid: pid) }
            }
            if !p.rooms.isEmpty && view == "list" {
                GBtn(tr("pj.v2d"), kind: .secondary, icon: "room", height: 46, fontSize: 14.5) { app.setProjectView("2d") }.accessibilityIdentifier("pj.v2d")
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
        .onAppear { refitWin(pid) }
        .onChange(of: p.rooms) { _, _ in refitWin(pid) }
    }

    private func freeCard(_ free: [WinItem], _ calc: WinCalc) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            T(tr("dw.freeT"), ui(16, 700))
            ForEach(free) { f in WNFreeLine(f: f, warn: calc.warns.contains { $0.target == f.id }) { app.push(.wDesign(pid: p.id, iid: f.id)) } }
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

/// A product without a room in the order's list.
private struct WNFreeLine: View {
    let f: WinItem
    let warn: Bool
    let action: () -> Void
    var body: some View {
        let sub: String = wSizeText(f.w, f.h) + " · " + tr("dw.qtyN", ["n": f.qty]) + (warn ? " · " + tr("dw.hasWarn") : "")
        HStack(spacing: 10) {
            PathIcon(W_WINDOW_ICON, G.cobalt, 18, 2)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                T(wItemTitle(f), ui(14.5, 700), lines: 1)
                T(sub, ui(12.5, 500, warn ? G.amberInk : G.ink2), lines: 1)
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

/// One workspace of a windows-and-doors order: its room, its products, what to do next.
private struct WNRoomCard: View {
    let app: AppModel
    let p: Project
    let w: Workspace
    let room: Room?
    var several = false
    let calc: WinCalc
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let ready = room.map { Geo.ready3D($0, snap) } ?? false
        let items: [WinItem] = room.map { r in p.win.items.filter { $0.roomId == r.id } } ?? []
        VStack(alignment: .leading, spacing: 10) {
            head(room, ready)
            if let room, !items.isEmpty { itemLine(room, items) }
            todo(room, ready, items)
        }
        .padding(12)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    @ViewBuilder private func todo(_ room: Room?, _ ready: Bool, _ items: [WinItem]) -> some View {
        if let room {
            let empty = room.openings.filter { o in !items.contains { $0.opening == o.id } }.count
            if !ready { TodoRow(label: tr("ns.measureT")) { openRoom(app, p.id, room.id) } }
            else if room.openings.isEmpty { TodoRow(label: tr("dw.addOps")) { openRoom(app, p.id, room.id) } }
            else if empty > 0 { TodoRow(label: tr("dw.fillN", ["n": empty])) { app.push(.wGallery(pid: p.id, rid: room.id)) } }
        } else {
            TodoRow(label: tr("fo.drawRoom")) { drawTileRoom(app, p.id, w) }
        }
    }

    private func subOf(_ room: Room?, _ ready: Bool) -> String {
        let a = room?.dim("A").v, b = room?.dim("B").v
        let ops = room?.openings.count ?? 0
        if ready, let a, let b, room?.isPoly != true {
            return Geo.fmtLen(a, .m, wnEn) + " × " + Geo.fmtLen(b, .m, wnEn) + U_M + " · " + tr("dw.opsN", ["n": ops])
        }
        if ready { return tr("tl.measured") + " · " + tr("dw.opsN", ["n": ops]) }
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
            if let room { if ready { app.push(.wView(pid: p.id, rid: room.id)) } else { openRoom(app, p.id, room.id) } }
            else { app.push(.space(pid: p.id, wid: w.id)) }
        }
    }

    private func itemLine(_ room: Room, _ items: [WinItem]) -> some View {
        let ws = calc.warns.filter { $0.roomId == room.id }.count
        let names = items.map { tr("dw.k." + $0.kind) }.joined(separator: ", ")
        return HStack(spacing: 10) {
            PathIcon(W_WINDOW_ICON, G.cobalt, 18, 2)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                T(wSummary(items), ui(14, 700), lines: 2)
                if ws > 0 { T(tr("el.warnN", ["n": ws]), ui(12.5, 600, G.amberInk)) }
                else { T(names, ui(12.5, 500, G.ink2), lines: 1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.75)))
        .pressable(0.985) { app.push(.wView(pid: p.id, rid: room.id)) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The order's fitting gap and its warnings.
private struct WNOrderCard: View {
    let app: AppModel
    let p: Project
    let calc: WinCalc
    var body: some View {
        VStack(spacing: 0) {
            WNLine(icon: "layers", title: tr("dw.gap"), sub: tr("dw.gapV", ["n": p.win.gap])) { app.sheet = .wGap(pid: p.id) }
            if !calc.warns.isEmpty {
                Hairline()
                WNLine(icon: "alert", title: tr("el.warnN", ["n": calc.warns.count]), sub: nil, warn: true) { warnTap() }
            }
        }
        .padding(.vertical, 4)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    private func warnTap() {
        guard let w = calc.warns.first else { return }
        if let id = w.target, p.win.item(id) != nil { app.push(.wDesign(pid: p.id, iid: id)); return }
        if let rid = w.roomId { app.push(.wView(pid: p.id, rid: rid)) }
    }
}

struct WNLine: View {
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

/// What to do now with a windows-and-doors order, and the one button that does it.
struct WNextStep: View {
    let app: AppModel
    let p: Project
    private struct Step { let title: String; let sub: String?; let button: String; let go: () -> Void }

    /// A room with an opening no product fills yet.
    private func unfilledRoom(_ r: Room, _ snap: Bool) -> Bool {
        if wCtxOf(p, r.id, snap) == nil { return false }
        return r.openings.contains { o in !p.win.items.contains { $0.roomId == r.id && $0.opening == o.id } }
    }

    private var step: Step? {
        let s = AppSettings.shared, snap = s.angleSnap
        let pid = p.id
        let rooms: [(Workspace, Room)] = roomsByWorkspace(p)
        let undrawn = p.floors.first { w in !p.rooms.contains { $0.floorId == w.id } }
        let unmeasured = rooms.first { wr in Geo.stepKeys(wr.1, snap).contains { wr.1.dim($0).status != "conf" } }
        let noOps = rooms.first { wr in wr.1.openings.isEmpty && !p.win.items.contains { $0.roomId == wr.1.id } }
        let unfilled = rooms.first { wr in unfilledRoom(wr.1, snap) }
        let made = madeBy(p, "dw.e.")
        if p.floors.isEmpty && p.win.items.isEmpty {
            return Step(title: tr("dw.ns.pickT"), sub: tr("dw.ns.pickS"), button: tr("ns.needB")) { app.push(.wGallery(pid: pid)) }
        }
        if let undrawn { return Step(title: tr("ns.measureT"), sub: floorName(undrawn), button: tr("fo.drawRoom")) { drawTileRoom(app, pid, undrawn) } }
        if let u = unmeasured {
            let (w, r) = u
            return Step(title: tr("ns.measureT"), sub: tr("ns.measureS", ["r": floorName(w)]), button: tr("ns.measureB")) { openRoom(app, pid, r.id) }
        }
        if let n = noOps {
            let (w, r) = n
            return Step(title: tr("dw.ns.opsT", ["r": floorName(w)]), sub: tr("dw.ns.opsS"), button: tr("ns.measureB")) { openRoom(app, pid, r.id) }
        }
        if let u = unfilled {
            let (w, r) = u
            return Step(title: tr("dw.ns.fillT", ["r": floorName(w)]), sub: tr("dw.ns.fillS"), button: tr("ns.needB")) { app.push(.wGallery(pid: pid, rid: r.id)) }
        }
        if !s.advanced { return Step(title: tr("ns.shareT"), sub: tr("dw.ns.shareS"), button: tr("ns.shareB")) { app.push(.report(pid: pid, no: nil)) } }
        if !made {
            return Step(title: tr("el.ns.estT"), sub: tr("dw.ns.estS"), button: tr("trc.apply")) {
                if let cur = Store.shared.get(pid) { applyWinRows(app, cur) }
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

/// The order page's three numbers in the advanced app: products, m² of windows, the estimate.
struct WNums: View {
    let p: Project
    var body: some View {
        if AppSettings.shared.advanced {
            let lang = AppSettings.shared.lang
            let c = WinCalcCache.shared.of(p).count
            let est = Money.short(p, Money.totals(p).g, lang == .en, tr("pl.mln"))
            VStack(spacing: 0) {
                Hairline()
                HStack(spacing: 12) {
                    WNCell(label: tr("dw.pieces"), value: "\(c.pieces)", unit: nil)
                    WNCell(label: tr("dw.area"), value: Num.fixed(c.winM2, 1, lang), unit: tr("tu.m2"))
                    WNCell(label: tr("pl.est"), value: est.0, unit: est.1)
                }
                .padding(.horizontal, 4).padding(.top, 10)
            }
            .padding(.top, 11)
        }
    }
}

private struct WNCell: View {
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

/// The estimate tab's card (in place of the old calculator's): what the products take, and the button that puts it in.
struct WinCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let lang = AppSettings.shared.lang
        let c = WinCalcCache.shared.of(p).count
        let made = madeBy(p, "dw.e.")
        VStack(alignment: .leading, spacing: 8) {
            T(tr("dw.cardT"), ui(16, 800))
            T(tr("dw.cardN", ["n": c.pieces, "a": Num.fixed(c.winM2, 1, lang)]), num(14.5, 700))
            T(tr("dw.cardB"), ui(12.5, 400, G.ink2, lh: 1.4))
            if c.pieces == 0 { T(tr("dw.none"), ui(13, 500, G.amberInk, lh: 1.4)) }
            HStack(spacing: 8) {
                GBtn(tr(made ? "trc.update" : "trc.apply"), enabled: c.pieces > 0, height: 44, corner: 14, fontSize: 14, lines: 2) { applyWinRows(app, p) }
                    .accessibilityIdentifier("dw.apply")
                GBtn(tr("tl.prices"), kind: .secondary, icon: "sliders", height: 44, corner: 14, fontSize: 14, lines: 2) { app.sheet = .wPrices(pid: p.id) }
                    .accessibilityIdentifier("dw.prices")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// What products take, line by line (the advanced app); price their price when known.
struct WCountCard: View {
    let title: String
    let c: WCount
    let price: Double?

    private func d1(_ v: Double) -> String { Num.fixed(v, 1, AppSettings.shared.lang) }
    private func d2(_ v: Double) -> String { Num.fixed(v, 2, AppSettings.shared.lang) }

    private func hwLine(_ sc: WSysCount) -> String {
        var parts: [String] = []
        for k in ["turn", "tilt", "tt", "slide"] {
            if let n = sc.hw[k] { parts.append(tr("dw.t." + k) + " \(n)") }
        }
        return parts.joined(separator: ", ")
    }

    private var glassLine: String {
        var parts: [String] = []
        if c.glass1 > 0 { parts.append(tr("dw.g.1") + " " + d2(c.glass1)) }
        if c.glass2 > 0 { parts.append(tr("dw.g.2") + " " + d2(c.glass2)) }
        return parts.joined(separator: ", ") + U_M2
    }

    private var priceLine: String {
        let v = tInt(eMathRoundP(price ?? 0))
        return Money.num(String(v), AppSettings.shared.lang == .en) + " " + AppSettings.shared.currency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            T(title, ui(15, 800))
            ForEach(W_PROFILES.filter { c.sys[$0] != nil }, id: \.self) { s in sysLines(s) }
            if c.glassM2 > 0 { EKv(k: tr("dw.c.glass"), v: glassLine) }
            if c.panel > 0 { EKv(k: tr("dw.t.panel"), v: d2(c.panel) + U_M2) }
            if c.lamM > 0 { EKv(k: tr("dw.c.lam"), v: d1(c.lamM) + U_M) }
            ForEach(c.doors.keys.sorted(), id: \.self) { k in
                let v = c.doors[k] ?? (0, 0)
                EKv(k: tr("dw.k." + k), v: tr("dw.c.doorV", ["n": v.0, "a": d2(v.1)]))
            }
            if c.sillM > 0 { EKv(k: tr("dw.x.sill"), v: d1(c.sillM) + U_M) }
            if c.dripM > 0 { EKv(k: tr("dw.x.drip"), v: d1(c.dripM) + U_M) }
            if c.revealM2 > 0 { EKv(k: tr("dw.x.reveals"), v: d2(c.revealM2) + U_M2) }
            if c.nets > 0 { EKv(k: tr("dw.x.net"), v: "\(c.nets)") }
            if c.handles > 0 { EKv(k: tr("dw.x.handles"), v: "\(c.handles)") }
            if price != nil {
                Hairline()
                EKv(k: tr("dw.c.price"), v: priceLine)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }

    @ViewBuilder private func sysLines(_ s: String) -> some View {
        if let sc = c.sys[s] {
            EKv(k: tr("dw.c.profile", ["s": tr("dw.p." + s)]), v: tr("dw.c.profV", ["f": d1(sc.frameM), "t": d1(sc.sashM), "m": d1(sc.mullM)]))
            if !sc.hw.isEmpty { EKv(k: tr("dw.c.hw"), v: hwLine(sc)) }
        }
    }
}
