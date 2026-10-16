import SwiftUI

private let TABS = [("rooms", "pj.t.rooms"), ("estimate", "pr.estimate"), ("quotes", "pj.t.quotes"), ("info", "pj.info")]

/// Project page: name, customer and stage, three numbers, four tabs (prototype project.js + glass stage 2).
struct ProjectScreen: View {
    let app: AppModel
    let id: String
    let tab: String
    var view = "list"
    var floor: String? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let p = Store.shared.get(id) {
            let withTotal = tab == "estimate" && !(p.estimate.materials.isEmpty && p.estimate.labor.isEmpty)
            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack { BackPill(text: tr("tab.projects")) { app.pop() }; Spacer() }.padding(.leading, 8).frame(minHeight: 64)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            header(p)
                            switch tab {
                            case "info": InfoTab(app: app, p: p, call: { call(p) }, map: { openMap(p) })
                            case "estimate": EstimateTab(app: app, p: p)
                            case "quotes": QuotesTab(app: app, p: p)
                            default:
                                if view != "list" && !p.rooms.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ViewSeg(cur: view) { app.setProjectView($0) }
                                        if view == "2d" { Plans2D(app: app, p: p) } else { Project3D(app: app, p: p, floor: floor) }
                                    }
                                    .padding(.horizontal, 20).padding(.top, 12)
                                } else { WorkspacesTab(app: app, p: p) }
                            }
                        }
                        // the floating total leaves room for the last rows
                        .padding(.bottom, (withTotal ? 150 : 24) + NAV_SPACE)
                    }
                }
                // the total floats over the tab bar, the rows scroll above it (prototype .footer.gs-tot)
                if withTotal { EstimateTotal(app: app, p: p).padding(.bottom, NAV_SPACE - 12) }
            }
        }
    }

    private func call(_ p: Project) { if let u = URL(string: "tel:+998" + Phone.digits(p.phone)) { openURL(u) } }
    private func openMap(_ p: Project) {
        guard let l = p.location, let u = URL(string: "https://www.google.com/maps/search/?api=1&query=\(l.lat),\(l.lng)") else { return }
        openURL(u)
    }

    private func header(_ p: Project) -> some View {
        let sub = [dn(p.customer), dn(p.address)].filter { !$0.isEmpty }.joined(separator: ", ")
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    T(dn(p.name), ui(28, 800, G.ink, lh: 1.15, ls: -0.02)).padding(.top, 2).frame(maxWidth: .infinity, alignment: .leading)
                    if !p.phone.isEmpty { RoundIc(icon: "phone", label: tr("pl.call")) { call(p) } }
                    if p.location != nil { RoundIc(icon: "pin", label: tr("loc.open")) { openMap(p) } }
                    RoundIc(icon: "more", label: "menu") { app.sheet = .projectMenu(pid: p.id) }.accessibilityIdentifier("project.menu")
                }
                HStack(spacing: 8) {
                    T(sub.isEmpty ? "—" : sub, ui(13.5, 400, G.ink2), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
                    StageChip(stage: p.stage)
                }
            }
            .padding(.horizontal, 4)
            if tab == "rooms" { Nums(p: p) }
            HStack(spacing: 2) {
                ForEach(TABS, id: \.0) { k, l in
                    let on = tab == k
                    HStack(spacing: 4) {
                        T(tr(l), ui(12.5, on ? 700 : 600, on ? G.ink : G.slate), lines: 1)
                        if k == "quotes" && !p.quotes.isEmpty {
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
                cell(tr("pl.wall"), wall, st.nets > 0 ? "m²" : nil)
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
                                Text(Geo.fmtArea(nw.0, AppSettings.shared.lang == .en) + " m²").st(num(14.5, 700))
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
                Hairline()
                kv(tr("pr.location"), p.location.map { String(format: "%.5f, %.5f", $0.lat, $0.lng) } ?? tr("loc.none")) {
                    if p.location != nil { GBtn(tr("loc.open"), kind: .secondary, icon: "pin", height: 40, corner: 14, fontSize: 14, fill: false, map) }
                }
                Hairline()
                kv(tr("np.currency"), p.currency) { EmptyView() }
                Hairline()
                kv(tr("rpt.lang"), Lang.of(p.reportLang).longName) { EmptyView() }
            }
            .padding(.horizontal, 12)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
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
        if p.quotes.isEmpty {
            VStack(spacing: 10) {
                MIcon("doc", G.cobalt, 26, 2).frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt.opacity(0.12)))
                T(tr("q.emptyTitle"), ui(18, 700), align: .center)
                T(tr("q.emptyBody"), ui(14, 400, G.ink2, lh: 1.45), align: .center)
                GBtn(tr("pr.estimate"), kind: .secondary, fill: false) { app.setProjectTab("estimate") }
            }
            .padding(24).frame(maxWidth: .infinity)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            .padding(.horizontal, 20).padding(.top, 14)
        } else {
            let now = fingerprint(snapshotOf(p))
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
                            MIcon(q.fp == now ? "check" : "info", G.ink, 14, 2.2)
                            T(tr(q.fp == now ? "q.same" : "q.differs"), ui(14, 400))
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

/// Tabs that arrive in later parts say so plainly.
struct LaterTab: View {
    let icon: String
    let part: Int
    var body: some View {
        VStack(spacing: 10) {
            MIcon(icon, G.cobalt, 26, 2).frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt.opacity(0.12)))
            T(tr("nt.part", ["n": part]), ui(15, 600, G.ink2), align: .center).frame(maxWidth: 280)
        }
        .padding(24).frame(maxWidth: .infinity)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        .padding(.horizontal, 16).padding(.top, 14)
    }
}
