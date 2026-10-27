import SwiftUI

private let TABS = [("rooms", "pj.t.rooms"), ("estimate", "pr.estimate"), ("quotes", "pj.t.quotes"), ("info", "pj.info")]
/// A furniture order: its price tab instead of the estimate (furniture plan section 4).
private let F_TABS = [("rooms", "fo.rooms"), ("price", "fo.price"), ("quotes", "pj.t.quotes"), ("info", "pj.info")]
// the simple furniture app: the rooms with their furniture, and who it is for
private let F_TABS_SIMPLE = [("rooms", "fo.rooms"), ("info", "pj.info")]
/// A tiler's order: its rooms with their tile layouts; the estimate and quotes in the advanced app only.
private let T_TABS = [("rooms", "fo.rooms"), ("estimate", "pr.estimate"), ("quotes", "pj.t.quotes"), ("info", "pj.info")]

/// A furniture, tiler, electrician, plumber or windows-and-doors order (the order apps).
private func isOrderApp(_ p: Project) -> Bool { p.isFurniture || p.isTiler || p.isElec || p.isPlumb || p.isWin }

/// An order of the simple furniture, tiler, electrician, plumber or windows-and-doors app: no prices, stages or quotes.
private func simpleOrder(_ p: Project) -> Bool { isOrderApp(p) && !AppSettings.shared.advanced }

/// The project page's tabs: a builder's, a furniture order's or a tiler's, the simple apps' fewer.
private func tabsOf(_ p: Project) -> [(String, String)] {
    let adv = AppSettings.shared.advanced
    if p.isTiler || p.isElec || p.isPlumb || p.isWin { return adv ? T_TABS : F_TABS_SIMPLE }
    if !p.isFurniture { return TABS }
    return adv ? F_TABS : F_TABS_SIMPLE
}

/// Project page: name, customer and stage, three numbers, four tabs (prototype project.js + glass stage 2).
struct ProjectScreen: View {
    let app: AppModel
    let id: String
    let tab: String
    var view = "list"
    var floor: String? = nil
    @Environment(\.openURL) private var openURL

    /// The pill names the page underneath: the orders list on that tab, or Home or Profile when opened from there.
    private func backLabel(_ p: Project) -> String {
        let st = app.stack
        if app.tab != .projects, st.count >= 2, st[st.count - 2] == .root { return app.tab.label }
        return isOrderApp(p) ? "fo.tab" : "tab.projects"
    }

    var body: some View {
        // a furniture order: the UX upgrades' page (no tab bar, the progress, the bottom action bar)
        if let p = Store.shared.get(id), p.isFurniture {
            FOrderPage(app: app, p: p, tab: tab, view: view, floor: floor, call: { call(p) }, map: { openMap(p) })
        } else if let p = Store.shared.get(id) {
            // price and quotes are the advanced app's; a link to them opens the rooms
            let tab = simpleOrder(p) && (self.tab == "price" || self.tab == "quotes" || self.tab == "estimate") ? "rooms" : self.tab
            let withTotal = tab == "estimate" && !(p.estimate.materials.isEmpty && p.estimate.labor.isEmpty)
            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack { BackPill(text: tr(backLabel(p))) { app.pop() }; Spacer() }.padding(.leading, 8).frame(minHeight: 64)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            header(p, tab)
                            // a furniture order: what to do now, with the one button that does it
                            if p.isFurniture { NextStep(app: app, p: p) }
                            if p.isTiler { TNextStep(app: app, p: p) }
                            if p.isElec { ENextStep(app: app, p: p) }
                            if p.isPlumb { PNextStep(app: app, p: p) }
                            if p.isWin { WNextStep(app: app, p: p) }
                            switch tab {
                            case "info":
                                if p.isFurniture { FurnitureInfo(app: app, p: p) }
                                InfoTab(app: app, p: p, call: { call(p) }, map: { openMap(p) })
                            case "estimate": EstimateTab(app: app, p: p)
                            case "price": FPriceTab(app: app, p: p)
                            case "quotes": QuotesTab(app: app, p: p)
                            default:
                                if view != "list" && !p.rooms.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ViewSeg(cur: view) { app.setProjectView($0) }
                                        if view == "2d" { Plans2D(app: app, p: p) } else { Project3D(app: app, p: p, floor: floor) }
                                    }
                                    .padding(.horizontal, 20).padding(.top, 12)
                                } else if p.isFurniture { FRoomsTab(app: app, p: p) }
                                else if p.isTiler { TRoomsTab(app: app, p: p, view: view) }
                                else if p.isElec { ERoomsTab(app: app, p: p, view: view) }
                                else if p.isPlumb { PRoomsTab(app: app, p: p, view: view) }
                                else if p.isWin { WRoomsTab(app: app, p: p, view: view) }
                                else { WorkspacesTab(app: app, p: p) }
                            }
                        }
                        // the floating total leaves room for the last rows
                        .padding(.bottom, (withTotal ? 150 : 24) + NAV_SPACE)
                    }
                }
                // the total floats over the tab bar, the rows scroll above it (prototype .footer.gs-tot)
                if withTotal { EstimateTotal(app: app, p: p).bottomBar().padding(.bottom, NAV_SPACE - 12) }
            }
        }
    }

    private func call(_ p: Project) { if let u = URL(string: "tel:+998" + Phone.digits(p.phone)) { openURL(u) } }
    private func openMap(_ p: Project) {
        guard let l = p.location, let u = URL(string: "https://www.google.com/maps/search/?api=1&query=\(l.lat),\(l.lng)") else { return }
        openURL(u)
    }

    /// tab: the tab shown (a price or quotes link in the simple app shows the rooms).
    private func header(_ p: Project, _ tab: String) -> some View {
        let sub = isOrderApp(p) ? orderSub(p, ", ") : [dn(p.customer), dn(p.address)].filter { !$0.isEmpty }.joined(separator: ", ")
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            // a furniture order's other tabs: one line, so the tab's own content starts higher
            if p.isFurniture && tab != "rooms" {
                HStack(spacing: 8) {
                    T(dn(p.name), ui(17, 800, G.ink, lh: 1.2), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                    FStageChip(stage: p.stage)
                    RoundIc(icon: "more", label: tr("common.menu")) { app.sheet = .projectMenu(pid: p.id) }.accessibilityIdentifier("project.menu")
                }
                .padding(.leading, 4)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        // a furniture order's name is often long ("Kitchen and wardrobe — Akmal Yusupov"): a bit smaller, two lines
                        T(dn(p.name), ui(p.isFurniture ? 23 : 28, 800, G.ink, lh: 1.15, ls: -0.02), lines: p.isFurniture ? 2 : nil).padding(.top, 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if p.isFurniture { CallButton(p: p) }
                        else if !p.phone.isEmpty { RoundIc(icon: "phone", label: tr("pl.call")) { call(p) } }
                        // a trade's order opens the "Yo‘l" sheet (Yandex, Navigator, Google, copy)
                        if p.location != nil {
                            RoundIc(icon: "pin", label: tr(p.industry == "build" ? "loc.open" : "loc.yolA")) { if p.industry == "build" { openMap(p) } else { app.sheet = .yol(pid: p.id) } }
                        }
                        RoundIc(icon: "more", label: tr("common.menu")) { app.sheet = .projectMenu(pid: p.id) }.accessibilityIdentifier("project.menu")
                    }
                    // the simple furniture app shows no stage: with no address either, the line goes
                    if !(isOrderApp(p) && sub.isEmpty && !AppSettings.shared.advanced) {
                        HStack(spacing: 8) {
                            T(isOrderApp(p) ? sub : sub.isEmpty ? "—" : sub, ui(13.5, 400, G.ink2), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
                            if p.isFurniture { FStageChip(stage: p.stage) } else if !simpleOrder(p) { StageChip(stage: p.stage) }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            if tab == "rooms" { if p.isFurniture { FNums(p: p) } else if p.isTiler { TNums(p: p) } else if p.isElec { ENums(p: p) } else if p.isPlumb { PNums(p: p) } else if p.isWin { WNums(p: p) } else { Nums(p: p) } }
            HStack(spacing: 2) {
                ForEach(tabsOf(p), id: \.0) { k, l in
                    let on = tab == k
                    HStack(spacing: 4) {
                        T(tr(l), ui(12.5, on ? 700 : 600, on ? G.ink : G.slate), lines: 1)
                        if k == "quotes" && !p.quotes.isEmpty && !p.isFurniture {
                            T("\(p.quotes.count)", ui(11, 700, .white)).padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(G.cobalt))
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? G.glass(0.95) : .clear).boxShadow(on ? G.shade.opacity(0.12) : .clear, blur: 10, y: 3))
                    .pressable(0.97) { app.setProjectTab(k) }
                    .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                    .accessibilityIdentifier("ptab." + k)
                }
            }
            .padding(4).frame(height: 44)
            .background(Capsule().fill(G.ink.opacity(0.06)))
            .padding(.top, 12)
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)
        .background(shape.fill(G.glass(0.4)))
        .topHighlight(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.14), blur: 36, y: 16))
        .padding(.horizontal, 20).padding(.top, 6)
    }
}

private struct RoundIc: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View { GlassIconButton(icon, label, iconSize: 18, action) }
}

/// The project stage as a coloured chip (prototype .pc-st).
struct StageChip: View {
    let stage: String
    var body: some View {
        let (bg, fg): (Color, Color) = stage == "measure" ? (G.amberWash, G.amberInk)
            : stage == "done" ? (Color(argb: 0x2416A34A), Theme.shared.dark ? G.green : Color(argb: 0xFF15803D))
            : (G.cobalt.opacity(0.12), G.cobalt2)
        T(tr("stage." + stage), ui(12, 600, fg), lines: 1).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(bg))
    }
}

/// "Devor, sof · O‘lchangan · Smeta" — the three numbers a brickmason prices by.
private struct Nums: View {
    let p: Project
    var body: some View {
        let st = stats(p)
        let en = AppSettings.shared.lang == .en
        let wall = p.rooms.isEmpty ? "—" : st.nets == 0 ? "?" : Geo.fmtArea(st.net, en) + (st.nets < p.rooms.count ? " +?" : "")
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 0) {
                cell(tr("pl.wall"), wall, st.nets > 0 ? tr("u.m2") : nil)
                vline
                cell(tr("pl.meas"), st.need > 0 ? "\(st.conf)/\(st.need)" : "—", nil).padding(.leading, 12)
                vline
                let est = Money.short(p, Money.totals(p).g, en, tr("pl.mln"))
                cell(tr("pl.est"), est.0, est.1).padding(.leading, 12)
            }
            .padding(.horizontal, 4).padding(.top, 10)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 11)
    }
    private var vline: some View { Rectangle().fill(G.ink.opacity(0.08)).frame(width: 1).padding(.vertical, 2) }
    private func cell(_ label: String, _ value: String, _ unit: String?) -> some View {
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

/* ---------------- Workspaces tab ---------------- */

private struct WorkspacesTab: View {
    let app: AppModel
    let p: Project
    var body: some View {
        if p.floors.isEmpty {
            VStack(spacing: 10) {
                EmptyWorkspaces()
                T(tr("ws.emptyT"), ui(19, 700, G.ink, lh: 1.4), align: .center)
                T(tr("ws.emptyB"), ui(14.5, 400, G.ink2, lh: 1.4), align: .center).padding(.bottom, 6)
                GBtn(tr("ws.create"), icon: "plus") { app.sheet = .newSpace(pid: p.id, editWid: nil) }.accessibilityIdentifier("ws.create")
            }
            .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            .padding(.horizontal, 16).padding(.top, 14)
        } else {
            VStack(spacing: 10) {
                ForEach(p.floors) { w in
                    HStack(spacing: 12) {
                        Group {
                            if let r0 = p.rooms.first(where: { $0.floorId == w.id }) { RoomThumb(r: r0).padding(3) }
                            else { MIcon(wsIcon(w.type), G.cobalt, 26, 2) }
                        }
                        .frame(width: 66, height: 52)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(G.ink.opacity(0.06)))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            T(floorName(w), ui(15.5, 600), lines: 1)
                            let c = wsCounts(p, w)
                            T(c.isEmpty ? tr("ws.empty") : c, ui(12.5, 400, G.ink2, lh: 1.3), lines: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        let nw = wsNet(p, w)
                        if nw.1 > 0 {
                            VStack(alignment: .trailing) {
                                Text(Geo.fmtArea(nw.0, AppSettings.shared.lang == .en) + " " + tr("u.m2")).st(num(14.5, 700))
                                T(tr("pj.wsNet"), ui(11.5, 400, G.ink2))
                            }
                        }
                        MIcon("chev", G.ink3, 18, 2)
                    }
                    .padding(.leading, 10).padding(.trailing, 8).padding(.vertical, 10)
                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
                    .pressable(0.985) { app.push(.space(pid: p.id, wid: w.id)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }
                if !p.rooms.isEmpty {
                    HStack(spacing: 8) {
                        GBtn(tr("pj.v2d"), kind: .secondary, icon: "room", height: 48, fontSize: 15) { app.setProjectView("2d") }.accessibilityIdentifier("pj.v2d")
                        GBtn(tr("pj.v3d"), kind: .secondary, icon: "cube", height: 48, fontSize: 15) { app.setProjectView("3d") }.accessibilityIdentifier("pj.v3d")
                    }
                }
                HStack(spacing: 8) { MIcon("plus", G.cobalt2, 22, 2.2); T(tr("gl.addWs"), ui(16, 700, G.cobalt2)) }
                    .frame(maxWidth: .infinity).frame(height: 64)
                    .dashedGlass(24)
                    .pressable(0.98) { app.sheet = .newSpace(pid: p.id, editWid: nil) }
                    .accessibilityIdentifier("ws.add")
            }
            .padding(.horizontal, 16).padding(.top, 12)
        }
    }
}

/// The two-sheet drawing of the empty Workspaces tab (prototype .ws-empty svg, 120 × 84).
private struct EmptyWorkspaces: View {
    var body: some View {
        Canvas { ctx, size in
            var c = ctx; let k = size.width / 120; c.scaleBy(x: k, y: k)
            let back = Path(roundedRect: CGRect(x: 8, y: 10, width: 64, height: 48), cornerRadius: 6)
            c.fill(back, with: .color(Theme.shared.dark ? G.blueWash : Color(argb: 0xFFEAF0FE)))
            c.stroke(back, with: .color(Color(argb: 0xFF1C4BD1)), lineWidth: 2)
            let front = Path(roundedRect: CGRect(x: 48, y: 26, width: 64, height: 48), cornerRadius: 6)
            c.fill(front, with: .color(G.solid)); c.stroke(front, with: .color(G.ink), lineWidth: 2)
            func line(_ a: CGPoint, _ b: CGPoint, _ col: Color, _ w: CGFloat) { var p = Path(); p.move(to: a); p.addLine(to: b); c.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: w, lineCap: .round)) }
            line(CGPoint(x: 60, y: 44), CGPoint(x: 100, y: 44), Color(argb: 0xFF5F6B82), 2)
            line(CGPoint(x: 60, y: 54), CGPoint(x: 86, y: 54), Color(argb: 0xFF5F6B82), 2)
            c.fill(Path(ellipseIn: CGRect(x: 85, y: 55, width: 26, height: 26)), with: .color(Color(argb: 0xFF1C4BD1)))
            line(CGPoint(x: 98, y: 62), CGPoint(x: 98, y: 74), .white, 2.4)
            line(CGPoint(x: 92, y: 68), CGPoint(x: 104, y: 68), .white, 2.4)
        }
        .frame(width: 120, height: 84)
        .accessibilityHidden(true)
    }
}

/* ---------------- Details tab ---------------- */

private struct InfoTab: View {
    let app: AppModel
    let p: Project
    let call: () -> Void
    let map: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                kv(tr("pr.customer"), dn(p.customer).isEmpty ? "—" : dn(p.customer)) { EmptyView() }
                Hairline()
                kv(tr("pr.phone"), p.phone.isEmpty ? tr("pj.noPhone") : Phone.format(p.phone)) {
                    if !p.phone.isEmpty { GBtn(tr("pl.call"), kind: .secondary, icon: "phone", height: 40, corner: 14, fontSize: 14, fill: false, call) }
                }
                Hairline()
                kv(tr("pr.address"), dn(p.address).isEmpty ? "—" : dn(p.address)) { EmptyView() }
                // a builder's project keeps its location row; the trades' orders have their own card below (room-shapes spec §1)
                if p.industry == "build" {
                    Hairline()
                    kv(tr("pr.location"), p.location.map { String(format: "%.5f, %.5f", $0.lat, $0.lng) } ?? tr("loc.none")) {
                        if p.location != nil { GBtn(tr("loc.open"), kind: .secondary, icon: "pin", height: 40, corner: 14, fontSize: 14, fill: false, map) }
                    }
                }
                // the simple furniture app has no prices, so no currency either
                if !simpleOrder(p) {
                    Hairline()
                    kv(tr("np.currency"), p.currency) { EmptyView() }
                }
                Hairline()
                kv(tr("rpt.lang"), Lang.of(p.reportLang).longName) { EmptyView() }
            }
            .padding(.horizontal, 12)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            if p.industry != "build" { LocInfoCard(app: app, p: p) }
            GBtn(tr("pj.edit"), kind: .secondary, icon: "edit") { app.push(.newProject(editId: p.id)) }.accessibilityIdentifier("pj.edit")
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }
    private func kv<E: View>(_ label: String, _ value: String, @ViewBuilder _ extra: () -> E) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) { T(label, ui(12.5, 400, G.ink2)); T(value, ui(15.5, 500)) }
                .frame(maxWidth: .infinity, alignment: .leading)
            extra()
        }
        .padding(.vertical, 8).frame(minHeight: 60)
    }
}

/// The issued quotes, newest first, each saying whether the draft still matches it.
private struct QuotesTab: View {
    let app: AppModel
    let p: Project
    var body: some View {
        if p.isFurniture { FIssueBar(app: app, p: p) }
        if p.quotes.isEmpty && p.isFurniture {
            EmptyView()
        } else if p.quotes.isEmpty {
            VStack(spacing: 10) {
                MIcon("doc", G.cobalt, 26, 2).frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt.opacity(0.12)))
                T(tr("q.emptyTitle"), ui(18, 700), align: .center)
                T(tr(p.isFurniture ? "fd.qEmpty" : "q.emptyBody"), ui(14, 400, G.ink2, lh: 1.45), align: .center)
                GBtn(tr(p.isFurniture ? "fo.price" : "pr.estimate"), kind: .secondary, fill: false) { app.setProjectTab(p.isFurniture ? "price" : "estimate") }
            }
            .padding(24).frame(maxWidth: .infinity)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            .padding(.horizontal, 20).padding(.top, 14)
        } else {
            let now = snapshotOf(p)
            let en = AppSettings.shared.lang == .en
            VStack(spacing: 10) {
                ForEach(p.quotes.reversed(), id: \.no) { q in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 0) {
                            T(tr("q.no", ["n": q.no]), ui(17, 600)).frame(maxWidth: .infinity, alignment: .leading)
                            MIcon("lock", G.ink2, 14, 2); T(" " + tr("q.issued"), ui(13.5, 400, G.ink2))
                        }
                        T(fmtDate(q.ts) + ", " + fmtTime(q.ts) + ". " + tr("q.lang", ["l": Lang.of(q.sn.lang).longName]), ui(13.5, 400, G.ink2, lh: 1.35))
                        T(tr("q.rooms", ["n": q.sn.rooms.count]), ui(13.5, 400, G.ink2))
                        Hairline().padding(.top, 6)
                        HStack {
                            T(tr("es.grand"), ui(14, 400)).frame(maxWidth: .infinity, alignment: .leading)
                            T(Money.str(Decimal(string: q.total) ?? 0, q.sn.precision, en) + " " + Money.cur(q.sn.currency), ui(14, 700))
                        }
                        .padding(.top, 6)
                        Hairline().padding(.top, 6)
                        HStack(spacing: 6) {
                            MIcon(sameAsQuote(now, q.fp) ? "check" : "info", G.ink, 14, 2.2)
                            T(tr(sameAsQuote(now, q.fp) ? "q.same" : "q.differs"), ui(14, 400))
                        }
                        .padding(.top, 6)
                    }
                    .padding(14)
                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
                    .pressable(0.985) { app.push(.report(pid: p.id, no: q.no)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("quote.card")
                }
            }
            .padding(.horizontal, 20).padding(.top, 12)
        }
    }
}

/// A furniture order's Quotes tab starts with issuing the next quote at today's price, and looking at the PDF first.
private struct FIssueBar: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let st = AppSettings.shared
        let fs = p.furniture.filter { !$0.modules.isEmpty }
        VStack(spacing: 8) {
            if fs.isEmpty {
                T(tr("fp.empty"), ui(14, 400, G.ink2, lh: 1.45), align: .center).padding(20).frame(maxWidth: .infinity)
                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            } else {
                let price = priceOf(fs, p.fprice, st.workshop, st.mats, st.hws).price
                // a new quote only when something changed since the last one: otherwise it would be the same quote again
                let changed = p.quotes.last.map { $0.fp != fingerprint(snapshotOf(p)) } ?? true
                if changed {
                    GBtn(tr("fo.issueN", ["n": p.quotes.count + 1, "v": shortStr(p, price)]), icon: "lock") { app.sheet = .issue(pid: p.id) }.accessibilityIdentifier("fo.issue")
                }
                GBtn(tr("fo.preview"), kind: .secondary, icon: "doc", height: 46, fontSize: 14.5) { app.push(.report(pid: p.id, no: nil)) }
            }
        }
        .padding(.horizontal, 20).padding(.top, 12)
    }
}

/* ---------------- a furniture order (UX upgrades 26 Oct 2026, sections 1–4) ---------------- */

/// A furniture order inside the app: no tab bar; Back and the order's name (two lines, never cut), the progress
/// Xona → Mebel → Dizayn → Narx → PDF and the price under it; two tabs, Mebel and Ma'lumot (with the client and the
/// 7 production stages; Advanced also has Narx and Takliflar); a bottom bar with the one next-step button and Undo.
private struct FOrderPage: View {
    let app: AppModel
    let p: Project
    let tab: String
    let view: String
    let floor: String?
    let call: () -> Void
    let map: () -> Void

    var body: some View {
        let adv = AppSettings.shared.advanced
        let tabs: [(String, String)] = adv ? [("rooms", "ux.tFurn"), ("price", "fo.price"), ("quotes", "pj.t.quotes"), ("info", "pj.info")]
                                           : [("rooms", "ux.tFurn"), ("info", "pj.info")]
        let tab = tabs.contains { $0.0 == self.tab } ? self.tab : "rooms"
        let act = mainAction(app, p)
        VStack(spacing: 0) {
            UXTop {
                UXTopBar(title: dn(p.name), sub: orderSub(p, " · ").isEmpty ? tr("ux.order") : orderSub(p, " · "), badge: p.sample, back: { app.pop() }) {
                    CallButton(p: p)
                    GlassIconButton("more", tr("common.menu"), iconSize: 18) { app.sheet = .projectMenu(pid: p.id) }.accessibilityIdentifier("project.menu")
                }
                OrderProgress(app: app, p: p).padding(.horizontal, 10)
                HStack(spacing: 8) {
                    OrderPriceLine(p: p)
                    Spacer(minLength: 0)
                    if adv { FStageChip(stage: p.stage) }
                    InstallChip(p: p)
                }
                .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 10)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 2) {
                        ForEach(tabs, id: \.0) { k, l in
                            let on = tab == k
                            T(tr(l), ui(14, on ? 800 : 600, on ? G.ink : G.slate), lines: 1)
                                .padding(.horizontal, 4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? G.glass(0.95) : .clear).boxShadow(on ? G.shade.opacity(0.12) : .clear, blur: 10, y: 3))
                                .pressable(0.97) { Haptic.tick(); app.setProjectTab(k) }
                                .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                                .accessibilityIdentifier("ptab." + k)
                        }
                    }
                    .padding(4).frame(height: 46)
                    .background(Capsule().fill(G.ink.opacity(0.06)))
                    .padding(.horizontal, 20).padding(.top, 12)
                    switch tab {
                    case "info":
                        // the client first, then the 7 production stages (Advanced changes them here)
                        InfoTab(app: app, p: p, call: call, map: map)
                        FurnitureInfo(app: app, p: p)
                        if !adv { FStagesView(p: p) }
                    case "price": FPriceTab(app: app, p: p)
                    case "quotes": QuotesTab(app: app, p: p)
                    default:
                        if view != "list" && !p.rooms.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ViewSeg(cur: view) { app.setProjectView($0) }
                                if view == "2d" { Plans2D(app: app, p: p) } else { Project3D(app: app, p: p, floor: floor) }
                            }
                            .padding(.horizontal, 20).padding(.top, 12)
                        } else {
                            if p.furniture.isEmpty { FEmptyCard() }
                            FRoomsTab(app: app, p: p)
                        }
                    }
                }
                .padding(.bottom, 24)
            }
            ActionBar(label: act.label, icon: act.icon, undoOn: app.undoCount > 0, undo: { app.undoLast() }, main: act.go, coach: "order")
        }
    }
}

/// "Hali mebel yo‘q": the bottom button opens the 3D gallery.
private struct FEmptyCard: View {
    var body: some View {
        VStack(spacing: 8) {
            MIcon("cube", G.cobalt, 28, 2).frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt.opacity(0.12)))
            T(tr("ux.noFurnT"), ui(17, 800), align: .center)
            T(tr("ux.noFurnB"), ui(13.5, 400, G.ink2, lh: 1.45), align: .center)
            MIcon("arrow", G.ink3, 18, 2).rotationEffect(.degrees(90))
        }
        .padding(20).frame(maxWidth: .infinity)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        .padding(.horizontal, 16).padding(.top, 12)
    }
}

/// The simple app's look at the 7 production stages (read only; Advanced changes them in FurnitureInfo).
private struct FStagesView: View {
    let p: Project
    var body: some View {
        let k = fStage(p)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                T(tr("ux.stagesT"), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T("\(k + 1) / \(F_STAGES.count)", ui(12.5, 600, G.ink3))
            }
            .padding(.bottom, 4)
            ForEach(Array(F_STAGES.enumerated()), id: \.offset) { i, st in
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(i < k ? G.cobalt : .clear)
                        Circle().strokeBorder(i <= k ? G.cobalt : G.ink3.opacity(0.35), lineWidth: 2)
                        if i < k { MIcon("check", .white, 12, 3) } else { T("\(i + 1)", ui(11.5, 800, i == k ? G.cobalt2 : G.ink3)) }
                    }
                    .frame(width: 24, height: 24)
                    T(tr("fs." + st), ui(14, i == k ? 800 : 500, i > k ? G.ink3 : G.ink))
                }
                .frame(minHeight: 32)
            }
            T(tr("ux.stagesNote"), ui(12.5, 400, G.ink2, lh: 1.4)).padding(.top, 4)
        }
        .padding(14)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        .padding(.horizontal, 16).padding(.top, 12)
    }
}
